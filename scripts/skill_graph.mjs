#!/usr/bin/env node
// scripts/skill_graph.mjs
//
// The provenance graph for the skill artifacts: where each copy came from, what
// links across a boundary, and which copies no longer match.
//
// A diagnostic, not a wire contract. Its readers are an agent auditing a copy,
// locating a skill, or exploring what a change reaches, and the operator reading
// the render. So a question it cannot answer is a finding in the graph, never a
// silent pass: a missing manifest, a row that reaches no root, a link whose
// target root is absent. Nothing validates the JSON as a format, and no gate
// runs --check, because it compares this tree with an image built from an earlier
// commit.
//
// Evidence -> buildGraph() -> graph JSON -> toMermaid() -> Pele -> SVG
//
// CLI:
//   node scripts/skill_graph.mjs --json
//   node scripts/skill_graph.mjs --mermaid
//   node scripts/skill_graph.mjs --check
//   node scripts/skill_graph.mjs --evidence FILE [--json|--mermaid|--check]
//
// --check exits 1 on a finding from the graph or on drift: a copy that no longer
// matches what it was made from is the fact the check exists for. The renderer
// renders drift and fails only on a graph finding, so a diff is inspected before
// it blocks. An unknown image digest is a warning.
//
// The graph is intentionally a focus view: artifact roots and the target
// artifacts of cross-boundary links, not all 58 skills.

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, posix, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  LAYERS,
  discoverSkillDirs,
  inside,
  isDirectory,
  layerRoots,
  markdownFiles,
  markdownLinks,
  walkFiles,
} from "./skill_layers.mjs";

// The graph's subject is the repository this script belongs to, not the shell's
// working directory: a check run from a subdirectory would otherwise collect no
// roots and report clean over nothing.
const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const IMAGE_DIGEST = process.env.SKILL_GRAPH_IMAGE_DIGEST || null;

const NAMESPACE_ORDER = ["repo", "image", "host"];

function sha256(data) {
  return createHash("sha256").update(data).digest("hex");
}

// treeHash -- the directory's content identity: sorted relative path + file hash.
function treeHash(dir) {
  if (!isDirectory(dir)) return null;
  const rows = walkFiles(dir)
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

// discoverSkills -- the layer's skill roots as graph nodes. pi's no-recurse rule
// is skill_layers.mjs's; this adds the node's identity.
function discoverSkills(dir, rootPath, out = []) {
  for (const skillDir of discoverSkillDirs(dir)) {
    const rel = relative(dir, skillDir).split(sep).join("/");
    out.push({
      name: frontmatterName(join(skillDir, "SKILL.md")),
      path: posix.join(rootPath, rel),
      sha256: treeHash(skillDir),
    });
  }
  return out;
}

function parseLinks(raw, file, rootPath, rootId, skills, repoRoot, resolves) {
  const absoluteRoot = isAbsolute(rootPath) ? rootPath : join(repoRoot, rootPath);
  const rel = relative(absoluteRoot, file).split(sep).join("/");
  if (rel.startsWith("..")) return [];
  const filePath = posix.join(rootPath, rel);
  const sourceSkill =
    skills
      .filter((skill) => filePath === skill.path || filePath.startsWith(`${skill.path}/`))
      .sort((a, b) => b.path.length - a.path.length)[0]?.name || null;
  const links = [];
  for (const link of raw) {
    const target = link.target;
    if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
    // A relative target is judged by the layer boundary rules; an absolute or
    // home-rooted one is kept only when a declared root resolves it, so a moved
    // destination moves the links written to it instead of dropping them.
    if ((target.startsWith("/") || target.startsWith("$")) && !resolves(target)) continue;
    links.push({
      fromRoot: rootId,
      fromSkill: sourceSkill,
      file: rel,
      target,
      line: link.line,
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

// rootDefs -- one repository root per layer, the image root each layer's payload
// occupies, and the provider home the image seeds. The layer table owns which
// directory is a layer; the manifest's image rows own the destinations; the
// session's environment owns the provider home.
function rootId(layer, namespace) {
  return `${namespace}:${layer.name}`;
}

function rootDefs(declared) {
  const defs = LAYERS.map((layer) => ({
    id: rootId(layer, "repo"),
    namespace: "repo",
    layer: layer.name,
    path: layer.source,
  }));
  for (const namespace of ["image", "host"]) {
    for (const layer of LAYERS) {
      const root = declared[namespace].get(layer.name);
      if (root) defs.push({ id: rootId(layer, namespace), namespace, layer: layer.name, path: root.path });
    }
  }
  return defs;
}

function absoluteOf(definition, repoRoot) {
  return isAbsolute(definition.path) ? definition.path : join(repoRoot, definition.path);
}

export function collectEvidence(root = REPO) {
  const repoRoot = resolve(root);
  const declared = layerRoots(repoRoot);
  const defs = rootDefs(declared);
  const findings = [...declared.findings];
  const warnings = [];
  const roots = [];
  for (const definition of defs) {
    const absolute = absoluteOf(definition, repoRoot);
    if (!isDirectory(absolute)) {
      const message = `root: ${definition.id} is missing at ${definition.path}`;
      if (definition.namespace === "host") warnings.push(message);
      else findings.push(message);
      continue;
    }
    roots.push({
      ...definition,
      sha256: treeHash(absolute),
      skills: discoverSkills(absolute, definition.path),
    });
  }

  // resolves TARGET -- whether a declared root holds an absolute or home-rooted
  // target. The manifest owns the destinations; this only asks them.
  const resolves = (target) => {
    const expanded = target.startsWith("$AGENT_HOME/") && declared.agentHome
      ? target.replace("$AGENT_HOME", declared.agentHome)
      : target;
    if (!expanded.startsWith("/")) return false;
    return roots.some((entry) => inside(expanded, absoluteOf(entry, repoRoot)));
  };

  const links = [];
  for (const rootDef of roots) {
    for (const file of markdownFiles(absoluteOf(rootDef, repoRoot))) {
      const raw = markdownLinks(file);
      // A home-rooted link whose home the manifest does not resolve is reported
      // rather than dropped: the target exists and the declaration does not.
      if (!declared.agentHome && raw.some((link) => link.target.startsWith("$AGENT_HOME/"))) {
        findings.push(`link: ${relative(repoRoot, file)} targets \$AGENT_HOME, whose home the manifest does not resolve`);
      }
      links.push(...parseLinks(raw, file, rootDef.path, rootDef.id, rootDef.skills, repoRoot, resolves));
    }
  }

  const rootIds = new Set(roots.map((entry) => entry.id));
  const build = [];
  // A copy edge is a manifest row: the repository root a layer is read from and
  // the image root the same payload occupies. A row that reaches a layer but
  // whose root is absent from the tree is reported, not skipped.
  for (const layer of LAYERS) {
    const imageRoot = declared.image.get(layer.name);
    const from = rootId(layer, "repo");
    const to = rootId(layer, "image");
    if (!imageRoot) continue;
    if (!rootIds.has(from) || !rootIds.has(to)) continue;
    build.push({
      kind: "copy",
      from,
      to,
      evidence: `container-interface.json: ${imageRoot.row.source} -> ${imageRoot.row.destination}`,
    });
  }
  for (const layer of LAYERS) {
    const hostRoot = declared.host.get(layer.name);
    const from = rootId(layer, "image");
    const to = rootId(layer, "host");
    if (!hostRoot || !rootIds.has(from) || !rootIds.has(to)) continue;
    build.push({
      kind: "seed",
      from,
      to,
      evidence: `container-interface.json: provision ${hostRoot.row.provider} -> ${hostRoot.path}`,
    });
  }

  return {
    repo: {
      root: repoRoot,
      commit: git(repoRoot, ["rev-parse", "HEAD"]) || "unknown",
      dirty: git(repoRoot, ["status", "--porcelain"]).length > 0,
    },
    image: {
      digest: IMAGE_DIGEST,
    },
    agentHome: declared.agentHome,
    roots,
    links,
    build,
    findings,
    warnings,
  };
}

function rootVersion(root, evidence) {
  if (root.namespace === "repo") {
    return `repo:${evidence.repo.commit}${evidence.repo.dirty ? ":dirty" : ""}`;
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
    id: `skill:${root.id}:${relativeToRoot(root.path, skill.path)}`,
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
  const repoRoot = evidence.repo?.root || ".";
  const absoluteOf = (path) => (isAbsolute(path) ? path : join(repoRoot, path));
  let target = link.target;
  if (target.startsWith("$AGENT_HOME/")) {
    target = target.replace("$AGENT_HOME", evidence.agentHome);
  }
  if (!target.startsWith("/")) {
    // Joining, not resolving: a repository-relative target must not be resolved
    // against the process's working directory.
    target = posix.normalize(posix.join(posix.dirname(posix.join(root.path, link.file)), target));
  }
  // One resolver: a root holds the target when the same normalisation says so,
  // whichever form the target and the root path were written in.
  const absolute = absoluteOf(target);
  const candidates = roots
    .filter((entry) => inside(absolute, absoluteOf(entry.path)))
    .sort((a, b) => b.path.length - a.path.length);
  const targetRoot = candidates[0] || null;
  if (!targetRoot) return { target, targetRoot: null, targetSkill: null };
  const skills = targetRoot.skills
    .filter((skill) => inside(absolute, absoluteOf(skill.path)))
    .sort((a, b) => b.path.length - a.path.length);
  return { target, targetRoot, targetSkill: skills[0] || null };
}

// The three edge kinds, each constructed with the fields its kind needs, so a
// link without its expression or a comparison edge that disagrees with its
// hashes cannot be written at all.
function linkEdge(sourceId, target, link, resolution) {
  return {
    kind: "link",
    from: `root:${sourceId}`,
    to: target.id,
    expression: link.target,
    sourceSkill: link.fromSkill || "(root)",
    targetSkill: resolution.skill,
    sourceFile: link.file,
    line: link.line,
    resolution: resolution.namespace,
    evidence: `${sourceId}:${link.file}:${link.line}`,
    count: 1,
  };
}

function compareEdge(from, to) {
  return {
    kind: from.sha256 === to.sha256 ? "same-content" : "drift",
    from: from.id,
    to: to.id,
    evidence: `sha256:${from.sha256} / ${to.sha256}`,
  };
}

function buildEdge(step, from, to) {
  return { kind: step.kind, from: `root:${from.id}`, to: `root:${to.id}`, evidence: step.evidence };
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

// relativeToRoot -- a skill's path inside its layer root. A skill is the same
// skill in two copies when this is equal, whatever the frontmatter says.
function relativeToRoot(rootPath, skillPath) {
  return skillPath.slice(rootPath.length).replace(/^\/+/, "");
}



export function buildGraph(evidence) {
  const findings = [...(evidence.findings || [])];
  const nodes = new Map();
  const edges = new Map();
  const roots = evidence.roots || [];
  const rootById = new Map(roots.map((root) => [root.id, root]));
  // The peer a copy is compared with is the declared build relation: a
  // repository root is compared with the copy made from it, and every other root
  // with the copy it was made from. A bundle that declares no build edge
  // declares no peer.
  const copiedTo = new Map();
  const copiedFrom = new Map();
  for (const step of evidence.build || []) {
    if (step.kind === "copy") copiedTo.set(step.from, step.to);
    copiedFrom.set(step.to, step.from);
  }
  const peerOf = (root) =>
    rootById.get((root.namespace === "repo" ? copiedTo : copiedFrom).get(root.id)) || null;
  for (const root of roots) addNode(nodes, nodeForRoot(root, evidence));

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

    const peer = peerOf(resolved.targetRoot);
    if (peer) {
      const peerSkill = resolved.targetSkill
        ? peer.skills.find(
            (skill) =>
              relativeToRoot(peer.path, skill.path) ===
              relativeToRoot(resolved.targetRoot.path, resolved.targetSkill.path),
          )
        : null;
      if (resolved.targetSkill && !peerSkill) {
        // A skill the peer copy does not hold is a fact about the copy, not a
        // comparison: hashing a skill tree against a layer tree would report
        // drift for every such skill and mean nothing.
        findings.push(`copy: ${peer.namespace} ${peer.layer} does not hold skill '${resolved.targetSkill.name}'`);
      } else {
        const peerNode = peerSkill ? nodeForSkill(peer, peerSkill, evidence) : nodeForRoot(peer, evidence);
        addNode(nodes, peerNode);
        addEdge(edges, compareEdge(targetNode, peerNode));
      }
    }

    const linkKey = `link|${sourceRoot.id}|${targetNode.id}|${link.fromSkill || "(root)"}`;
    const existingLink = edges.get(linkKey);
    if (existingLink) {
      existingLink.count++;
    } else {
      edges.set(
        linkKey,
        linkEdge(sourceRoot.id, targetNode, link, {
          namespace: resolved.targetRoot.namespace,
          skill: resolved.targetSkill?.name || "(root)",
        }),
      );
    }
  }

  for (const build of evidence.build || []) {
    const from = rootById.get(build.from);
    const to = rootById.get(build.to);
    if (!from || !to) {
      findings.push(`build: ${build.kind} '${build.from}' -> '${build.to}' names a missing root`);
      continue;
    }
    addEdge(edges, buildEdge(build, from, to));
    addEdge(edges, compareEdge(nodes.get(`root:${from.id}`), nodes.get(`root:${to.id}`)));
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
    warnings: evidence.warnings || [],
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
  const warnings = [...(graph.warnings || [])];
  const drifts = (graph.edges || []).filter((edge) => edge.kind === "drift");
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
  console.log("usage: node scripts/skill_graph.mjs [--json|--mermaid|--check] [--evidence FILE] [--root DIR]");
}

async function main() {
  const args = process.argv.slice(2);
  let evidenceFile = process.env.SKILL_GRAPH_EVIDENCE || null;
  let root = REPO;
  let mode = "json";
  for (let index = 0; index < args.length; index++) {
    if (args[index] === "--json") mode = "json";
    else if (args[index] === "--mermaid") mode = "mermaid";
    else if (args[index] === "--check") mode = "check";
    else if (args[index] === "--evidence") evidenceFile = args[++index] || "";
    else if (args[index] === "--root") root = resolve(args[++index] || "");
    else if (args[index] === "--help" || args[index] === "-h") {
      usage();
      return 0;
    } else {
      console.error(`skill graph: unknown argument '${args[index]}'`);
      return 2;
    }
  }
  const evidence = evidenceFile ? readEvidence(evidenceFile) : collectEvidence(root);
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
