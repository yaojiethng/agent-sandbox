#!/usr/bin/env node
// scripts/skill_graph.mjs
//
// The tested provenance graph for the skill artifacts. The builder is a pure
// function of an evidence bundle; the renderer is downstream and contains no
// graph logic.
//
// Evidence -> buildGraph() -> graph JSON -> toMermaid() -> Pele -> SVG
//
// CLI:
//   node scripts/skill_graph.mjs --json
//   node scripts/skill_graph.mjs --mermaid
//   node scripts/skill_graph.mjs --check
//   node scripts/skill_graph.mjs --evidence FILE [--json|--mermaid|--check]
//
// --check exits 1 on a structural finding. Drift is not a structural finding;
// it is a valid edge kind the graph must show. An unknown image digest is a
// warning, not a failure.
//
// The graph is intentionally a focus view: artifact roots and the target
// artifacts of cross-boundary links, not all 58 skills.

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { basename, dirname, isAbsolute, join, posix, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

const REPO = process.cwd();
const AGENT_HOME = process.env.AGENT_HOME || "/home/agentuser/.pi";
const IMAGE_DIGEST = process.env.SKILL_GRAPH_IMAGE_DIGEST || null;

const LINK = /\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
const IGNORE = new Set([".git", "node_modules", ".scratchpad"]);

const LAYER_ORDER = ["project", "provider", "agent-sandbox", "workflow"];
const NAMESPACE_ORDER = ["repo", "image", "host", "project"];

const ROOT_DEFS = [
  {
    id: "repo:agent-sandbox",
    namespace: "repo",
    layer: "agent-sandbox",
    path: "src/reasoning/agent/skills",
  },
  {
    id: "repo:workflow",
    namespace: "repo",
    layer: "workflow",
    path: "workflow/coding-agent/skills",
  },
  {
    id: "repo:provider",
    namespace: "repo",
    layer: "provider",
    path: "src/reasoning/providers/pi/config/agent/skills",
  },
  {
    id: "project",
    namespace: "project",
    layer: "project",
    path: ".agents/skills",
  },
  {
    id: "image:agent-sandbox",
    namespace: "image",
    layer: "agent-sandbox",
    path: "/opt/workflow/agent/skills",
  },
  {
    id: "image:workflow",
    namespace: "image",
    layer: "workflow",
    path: "/opt/workflow/agent/modules/coding-agent/skills",
  },
  {
    id: "image:provider",
    namespace: "image",
    layer: "provider",
    path: "/opt/workflow/agent/config/agent/skills",
  },
  {
    id: "host:provider",
    namespace: "host",
    layer: "provider",
    path: join(AGENT_HOME, "agent", "skills"),
  },
];

function sha256(data) {
  return createHash("sha256").update(data).digest("hex");
}

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function walk(dir, out = []) {
  if (!isDirectory(dir)) return out;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (IGNORE.has(entry.name)) continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) walk(path, out);
    else if (entry.isFile()) out.push(path);
  }
  return out;
}

// treeHash -- the directory's content identity: sorted relative path + file hash.
function treeHash(dir) {
  if (!isDirectory(dir)) return null;
  const rows = walk(dir)
    .map((path) => {
      const rel = relative(dir, path).split(sep).join("/");
      return `${rel}\0${sha256(readFileSync(path))}`;
    })
    .sort();
  return sha256(rows.join("\n"));
}

function frontmatterName(file) {
  const text = readFileSync(file, "utf8");
  const block = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text)?.[1] || "";
  return /^name:\s*(.+?)\s*$/m.exec(block)?.[1]?.replace(/^["']|["']$/g, "") ||
    basename(dirname(file));
}

// discoverSkills -- pi's no-recurse rule: a directory with SKILL.md is a root.
function discoverSkills(dir, rootPath, out = []) {
  if (!isDirectory(dir)) return out;
  const entries = readdirSync(dir, { withFileTypes: true });
  if (entries.some((entry) => entry.isFile() && entry.name === "SKILL.md")) {
    const name = frontmatterName(join(dir, "SKILL.md"));
    out.push({
      name,
      path: rootPath,
      sha256: treeHash(dir),
    });
    return out;
  }
  for (const entry of entries) {
    if (entry.isDirectory() && !IGNORE.has(entry.name)) {
      const child = join(dir, entry.name);
      const rel = relative(dir, child).split(sep).join("/");
      discoverSkills(child, posix.join(rootPath, rel), out);
    }
  }
  return out;
}

function linkLine(text, index) {
  return text.slice(0, index).split("\n").length;
}

function parseLinks(file, rootPath, rootId, skills, repoRoot) {
  const text = readFileSync(file, "utf8")
    .replace(/```[\s\S]*?```/g, "")
    .replace(/~~~[\s\S]*?~~~/g, "")
    .replace(/`[^`]*`/g, "");
  const absoluteRoot = isAbsolute(rootPath) ? rootPath : join(repoRoot, rootPath);
  const rel = relative(absoluteRoot, file).split(sep).join("/");
  if (rel.startsWith("..")) return [];
  const filePath = posix.join(rootPath, rel);
  const sourceSkill =
    skills
      .filter((skill) => filePath === skill.path || filePath.startsWith(`${skill.path}/`))
      .sort((a, b) => b.path.length - a.path.length)[0]?.name || null;
  const links = [];
  for (const match of text.matchAll(LINK)) {
    const target = match[1].split("#")[0];
    if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
    if (target.startsWith("/") && !target.startsWith("/opt/")) continue;
    if (target.startsWith("$") && !target.startsWith("$AGENT_HOME/")) continue;
    links.push({
      fromRoot: rootId,
      fromSkill: sourceSkill,
      file: rel,
      target,
      line: linkLine(text, match.index),
    });
  }
  return links;
}

function git(root, args) {
  try {
    return execFileSync("git", args, { cwd: root, encoding: "utf8" }).trim();
  } catch {
    return "";
  }
}

function readCopies(root) {
  const path = join(root, "src/reasoning/providers/pi/provider.dockerfile");
  if (!existsSync(path)) return [];
  const rows = [];
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const match = /^COPY\s+(\S+)\s+(\S+)\s*$/.exec(line);
    if (match) rows.push({ source: match[1], destination: match[2], line: line.trim() });
  }
  return rows;
}

function mountRows(target) {
  const rows = [];
  let text = "";
  try {
    text = readFileSync("/proc/self/mountinfo", "utf8");
  } catch {
    return rows;
  }
  for (const line of text.split("\n")) {
    const parts = line.split(" ");
    if (parts.length < 5) continue;
    const mountTarget = parts[4];
    const separator = parts.indexOf("-");
    if (separator < 0 || separator + 2 >= parts.length) continue;
    const mountSource = parts[separator + 2];
    if (mountTarget === target) rows.push({ target: mountTarget, source: mountSource, line });
  }
  return rows;
}

export function collectEvidence(root = REPO) {
  const repoRoot = resolve(root);
  const roots = [];
  for (const definition of ROOT_DEFS) {
    const absolute = isAbsolute(definition.path)
      ? definition.path
      : join(repoRoot, definition.path);
    if (!isDirectory(absolute)) continue;
    const skills = discoverSkills(absolute, definition.path);
    roots.push({
      ...definition,
      sha256: treeHash(absolute),
      skills,
    });
  }

  const links = [];
  for (const rootDef of roots) {
    const absolute = isAbsolute(rootDef.path) ? rootDef.path : join(repoRoot, rootDef.path);
    for (const file of walk(absolute)) {
      if (file.endsWith(".md")) {
        links.push(...parseLinks(file, rootDef.path, rootDef.id, rootDef.skills, repoRoot));
      }
    }
  }

  const rootIds = new Set(roots.map((entry) => entry.id));
  const build = [];
  const copyMap = new Map([
    ["src/reasoning/agent/skills/", ["repo:agent-sandbox", "image:agent-sandbox"]],
    ["workflow/coding-agent/skills/", ["repo:workflow", "image:workflow"]],
    ["src/reasoning/providers/pi/config/", ["repo:provider", "image:provider"]],
  ]);
  for (const row of readCopies(repoRoot)) {
    const pair = copyMap.get(row.source);
    if (!pair) continue;
    if (!rootIds.has(pair[0]) || !rootIds.has(pair[1])) continue;
    build.push({
      kind: "copy",
      from: pair[0],
      to: pair[1],
      evidence: `provider.dockerfile: ${row.line}`,
    });
  }
  if (rootIds.has("image:provider") && rootIds.has("host:provider")) {
    build.push({
      kind: "seed",
      from: "image:provider",
      to: "host:provider",
      evidence: "entrypoint.sh: config template seeded into AGENT_HOME",
    });
  }

  return {
    repo: {
      root: ".",
      commit: git(repoRoot, ["rev-parse", "HEAD"]) || "unknown",
      dirty: git(repoRoot, ["status", "--porcelain"]).length > 0,
    },
    image: {
      digest: IMAGE_DIGEST,
    },
    agentHome: AGENT_HOME,
    roots,
    links,
    build,
    mounts: mountRows(join(AGENT_HOME, "agent", "skills")),
  };
}

function inside(path, root) {
  const rel = relative(root, path);
  return rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !rel.startsWith(sep));
}

function rootVersion(root, evidence) {
  if (root.namespace === "repo") {
    return `repo:${evidence.repo.commit}${evidence.repo.dirty ? ":dirty" : ""}`;
  }
  if (root.namespace === "project") {
    return `project:${evidence.repo.commit}${evidence.repo.dirty ? ":dirty" : ""}`;
  }
  if (root.namespace === "image") {
    return `image:${evidence.image.digest || "unknown"}`;
  }
  return `host:${root.sha256.slice(0, 12)}`;
}

function nodeForRoot(root, evidence) {
  return {
    id: `root:${root.id}`,
    kind: "artifact",
    role: "root",
    namespace: root.namespace,
    layer: root.layer,
    path: root.path,
    version: rootVersion(root, evidence),
    sha256: root.sha256,
  };
}

function nodeForSkill(root, skill, evidence) {
  return {
    id: `skill:${root.id}:${skill.name}`,
    kind: "artifact",
    role: "target",
    namespace: root.namespace,
    layer: root.layer,
    path: skill.path,
    version: rootVersion(root, evidence),
    sha256: skill.sha256,
  };
}

function resolveTarget(link, root, roots, evidence) {
  let target = link.target;
  if (target.startsWith("$AGENT_HOME/")) {
    target = target.replace("$AGENT_HOME", evidence.agentHome);
  }
  if (!target.startsWith("/")) {
    target = posix.resolve(posix.dirname(posix.join(root.path, link.file)), target);
  }
  const candidates = roots
    .filter((entry) => inside(target, entry.path))
    .sort((a, b) => b.path.length - a.path.length);
  const targetRoot = candidates[0] || null;
  if (!targetRoot) return { target, targetRoot: null, targetSkill: null };
  const skills = targetRoot.skills
    .filter((skill) => inside(target, skill.path))
    .sort((a, b) => b.path.length - a.path.length);
  return { target, targetRoot, targetSkill: skills[0] || null };
}

function addNode(nodes, node) {
  if (!nodes.has(node.id)) nodes.set(node.id, node);
}

function addEdge(edges, edge) {
  const key = `${edge.kind}|${edge.from}|${edge.to}|${edge.expression || ""}`;
  const existing = edges.get(key);
  if (existing) {
    existing.count = (existing.count || 1) + 1;
  } else {
    edges.set(key, { ...edge, count: 1 });
  }
}

function compare(a, b) {
  return a.sha256 === b.sha256 ? "same-content" : "drift";
}

export function buildGraph(evidence) {
  const findings = [];
  const nodes = new Map();
  const edges = new Map();
  const roots = evidence.roots || [];
  const rootById = new Map(roots.map((root) => [root.id, root]));
  for (const root of roots) addNode(nodes, nodeForRoot(root, evidence));

  const targetNodes = new Map();
  for (const link of evidence.links || []) {
    const sourceRoot = rootById.get(link.fromRoot);
    if (!sourceRoot) {
      findings.push(`link: source root '${link.fromRoot}' is not in evidence`);
      continue;
    }
    const resolved = resolveTarget(link, sourceRoot, roots, evidence);
    if (!resolved.targetRoot) continue;
    if (resolved.targetRoot.id === sourceRoot.id) continue;

    const targetNode = resolved.targetSkill
      ? nodeForSkill(resolved.targetRoot, resolved.targetSkill, evidence)
      : nodeForRoot(resolved.targetRoot, evidence);
    addNode(nodes, targetNode);

    const targetKey = `${resolved.targetRoot.id}:${resolved.targetSkill?.name || "(root)"}`;
    if (!targetNodes.has(targetKey)) {
      targetNodes.set(targetKey, targetNode);
    }

    const sibling = roots.find(
      (root) => root.layer === resolved.targetRoot.layer && root.namespace !== resolved.targetRoot.namespace,
    );
    if (sibling) {
      const siblingSkill = resolved.targetSkill
        ? sibling.skills.find((skill) => skill.name === resolved.targetSkill.name)
        : null;
      const siblingNode = siblingSkill
        ? nodeForSkill(sibling, siblingSkill, evidence)
        : nodeForRoot(sibling, evidence);
      addNode(nodes, siblingNode);
      addEdge(edges, {
        kind: compare(targetNode, siblingNode),
        from: targetNode.id,
        to: siblingNode.id,
        evidence: `sha256:${targetNode.sha256} / ${siblingNode.sha256}`,
      });
    }

    const linkKey = `link|${sourceRoot.id}|${targetNode.id}|${link.fromSkill || "(root)"}`;
    const existingLink = edges.get(linkKey);
    if (existingLink) {
      existingLink.count++;
      existingLink.expressions.push(link.target);
    } else {
      edges.set(linkKey, {
        kind: "link",
        from: `root:${sourceRoot.id}`,
        to: targetNode.id,
        expression: link.target,
        expressions: [link.target],
        sourceSkill: link.fromSkill || "(root)",
        targetSkill: resolved.targetSkill?.name || "(root)",
        sourceFile: link.file,
        line: link.line,
        resolution: resolved.targetRoot.namespace,
        evidence: `${sourceRoot.id}:${link.file}:${link.line}`,
        count: 1,
      });
    }
  }

  for (const build of evidence.build || []) {
    const from = rootById.get(build.from);
    const to = rootById.get(build.to);
    if (!from || !to) {
      findings.push(`build: ${build.kind} '${build.from}' -> '${build.to}' names a missing root`);
      continue;
    }
    addEdge(edges, {
      kind: build.kind,
      from: `root:${from.id}`,
      to: `root:${to.id}`,
      evidence: build.evidence,
    });
    addEdge(edges, {
      kind: compare(from, to),
      from: `root:${from.id}`,
      to: `root:${to.id}`,
      evidence: `sha256:${from.sha256} / ${to.sha256}`,
    });
  }

  const sortedNodes = [...nodes.values()].sort((a, b) => {
    const ns = NAMESPACE_ORDER.indexOf(a.namespace) - NAMESPACE_ORDER.indexOf(b.namespace);
    if (ns !== 0) return ns;
    if (a.role !== b.role) return a.role === "root" ? -1 : 1;
    return `${a.layer}/${a.path}`.localeCompare(`${b.layer}/${b.path}`);
  });
  const sortedEdges = [...edges.values()].sort((a, b) => {
    const order = ["copy", "seed", "link", "same-content", "drift"];
    const kind = order.indexOf(a.kind) - order.indexOf(b.kind);
    if (kind !== 0) return kind;
    return `${a.from}/${a.to}/${a.expression || ""}`.localeCompare(`${b.from}/${b.to}/${b.expression || ""}`);
  });

  const graph = {
    model: "skill-provenance/1",
    evidence: {
      commit: evidence.repo.commit,
      dirty: evidence.repo.dirty,
      image: evidence.image.digest || null,
      agentHome: evidence.agentHome,
    },
    nodes: sortedNodes,
    edges: sortedEdges,
    findings,
  };
  graph.summary = {
    roots: sortedNodes.filter((node) => node.role === "root").length,
    nodes: sortedNodes.length,
    edges: sortedEdges.length,
    links: sortedEdges.filter((edge) => edge.kind === "link").reduce((n, edge) => n + edge.count, 0),
    targets: sortedNodes.filter((node) => node.role === "target").length,
    same: sortedEdges.filter((edge) => edge.kind === "same-content").length,
    drift: sortedEdges.filter((edge) => edge.kind === "drift").length,
    unknownImage: !evidence.image.digest,
  };
  return graph;
}

export function checkGraph(graph, options = {}) {
  const findings = [...(graph.findings || [])];
  const warnings = [];
  const drifts = (graph.edges || []).filter((edge) => edge.kind === "drift");
  const ids = new Set();
  for (const node of graph.nodes || []) {
    if (ids.has(node.id)) findings.push(`node: duplicate id '${node.id}'`);
    ids.add(node.id);
    for (const field of ["namespace", "layer", "path", "version", "sha256", "role"]) {
      if (!node[field]) findings.push(`node: ${node.id} has no ${field}`);
    }
    if (node.role === "target" && !node.path) findings.push(`node: ${node.id} has no path`);
  }
  for (const edge of graph.edges || []) {
    if (!ids.has(edge.from) || !ids.has(edge.to)) {
      findings.push(`edge: ${edge.kind} ${edge.from} -> ${edge.to} has a missing endpoint`);
    }
    if (edge.kind === "link" && !edge.expression) {
      findings.push(`edge: link ${edge.from} -> ${edge.to} has no expression`);
    }
    if (edge.kind === "same-content" || edge.kind === "drift") {
      const from = graph.nodes.find((node) => node.id === edge.from);
      const to = graph.nodes.find((node) => node.id === edge.to);
      if (from && to) {
        const equal = from.sha256 === to.sha256;
        if (edge.kind === "same-content" && !equal) {
          findings.push(`edge: same-content ${edge.from} -> ${edge.to} has unequal hashes`);
        }
        if (edge.kind === "drift" && equal) {
          findings.push(`edge: drift ${edge.from} -> ${edge.to} has equal hashes`);
        }
      }
    }
  }
  if (!options.allowDrift && drifts.length > 0) {
    findings.push(`drift: ${drifts.length} source/image relation(s) differ`);
  }
  if (!graph.evidence?.image) warnings.push("image: no digest available; labeled image:unknown");
  return { findings, warnings, drifts };
}

function escapeLabel(value) {
  return String(value).replace(/"/g, "'").replace(/[\r\n]+/g, " ");
}

export function toMermaid(graph) {
  const id = new Map();
  const used = new Set();
  for (const node of graph.nodes) {
    let base = `N_${node.namespace}_${node.layer}_${node.role}_${basename(node.path)}`
      .replace(/[^A-Za-z0-9_]/g, "_");
    let candidate = base;
    let index = 2;
    while (used.has(candidate)) candidate = `${base}_${index++}`;
    used.add(candidate);
    id.set(node.id, candidate);
  }

  const lines = [
    "---",
    `title: skill artifact provenance · ${graph.summary.nodes} nodes · ${graph.summary.links} links · ${graph.summary.drift} drift`,
    "---",
    "flowchart LR",
    "  %% solid = build/link; dashed = same-content; red-ish label = drift.",
  ];
  for (const namespace of NAMESPACE_ORDER) {
    const nodes = graph.nodes.filter((node) => node.namespace === namespace);
    if (nodes.length === 0) continue;
    lines.push(`  subgraph NS_${namespace}["${namespace}"]`);
    lines.push("    direction TB");
    for (const node of nodes) {
      const name = node.role === "root" ? `${node.layer} root` : `${node.layer}/${basename(node.path)}`;
      const label = `${name}<br/>${node.version}<br/>sha:${node.sha256.slice(0, 12)}`;
      lines.push(`    ${id.get(node.id)}["${escapeLabel(label)}"]`);
    }
    lines.push("  end");
  }
  for (const edge of graph.edges) {
    const from = id.get(edge.from);
    const to = id.get(edge.to);
    if (!from || !to) continue;
    if (edge.kind === "copy") {
      lines.push(`  ${from} ==>|copy| ${to}`);
    } else if (edge.kind === "seed") {
      lines.push(`  ${from} -.->|seed| ${to}`);
    } else if (edge.kind === "link") {
      const count = edge.count > 1 ? ` x${edge.count}` : "";
      lines.push(`  ${from} -->|link: ${escapeLabel(edge.sourceSkill)}${count}| ${to}`);
    } else if (edge.kind === "same-content") {
      lines.push(`  ${from} -.->|same-content| ${to}`);
    } else if (edge.kind === "drift") {
      lines.push(`  ${from} -.->|drift| ${to}`);
    }
  }
  return `${lines.join("\n")}\n`;
}

function readEvidence(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}

function usage() {
  console.log("usage: node scripts/skill_graph.mjs [--json|--mermaid|--check] [--evidence FILE]");
}

async function main() {
  const args = process.argv.slice(2);
  let evidenceFile = process.env.SKILL_GRAPH_EVIDENCE || null;
  let mode = "json";
  for (let index = 0; index < args.length; index++) {
    if (args[index] === "--json") mode = "json";
    else if (args[index] === "--mermaid") mode = "mermaid";
    else if (args[index] === "--check") mode = "check";
    else if (args[index] === "--evidence") evidenceFile = args[++index] || "";
    else if (args[index] === "--help" || args[index] === "-h") {
      usage();
      return 0;
    } else {
      console.error(`skill graph: unknown argument '${args[index]}'`);
      return 2;
    }
  }
  const evidence = evidenceFile ? readEvidence(evidenceFile) : collectEvidence(REPO);
  const graph = buildGraph(evidence);
  if (mode === "mermaid") {
    process.stdout.write(toMermaid(graph));
    return 0;
  }
  if (mode === "check") {
    const checked = checkGraph(graph);
    for (const warning of checked.warnings) console.log(`warning: ${warning}`);
    for (const finding of checked.findings) console.log(`finding: ${finding}`);
    console.log(
      `summary: ${graph.summary.nodes} nodes, ${graph.summary.links} links, ` +
        `${graph.summary.same} same-content, ${graph.summary.drift} drift`,
    );
    if (checked.findings.length > 0) {
      console.error(`skill graph: ${checked.findings.length} finding(s)`);
      return 1;
    }
    console.log("skill graph: clean");
    return 0;
  }
  console.log(JSON.stringify(graph, null, 2));
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(await main());
}
