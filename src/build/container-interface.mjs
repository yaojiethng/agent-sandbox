// src/build/container-interface.mjs
// The container interface, read once and served to every check that needs it.
//
// `src/build/container-interface.json` declares the interface. This module is
// its only reader: the checks call it rather than parsing the manifest
// themselves, so there is one parse, one derivation and one resolution rule.
// The truth the manifest claims is the provider dockerfiles' `COPY`, `ENV`,
// `WORKDIR` and `CMD` lines and the entrypoint's provisioning, and
// `scripts/check_container_layout.sh` holds them equal in both directions.
//
// Two halves of the manifest need different treatment. The `image`, `provision`
// and `env` rows describe the container, and their truth is the dockerfiles.
// The `session` and `cells` rows describe what an agent reads: the session rows
// are the environment every surface is read from, and a cell is one instruction
// surface whose folder set is derived from the image and provision rows rather
// than declared a second time.
//
// A source directory can land in more than one place, and does: the provider
// config is copied to `/opt/workflow/agent/config/` by a `COPY` line, and the
// entrypoint copies that template into `$AGENT_HOME/` at every start. Both
// destinations exist in the container, so the map carries both and a consumer
// accepts any of them. `sources_of` inverts the relation the same way.
//
// CLI:
//   node container-interface.mjs pairs   [--root DIR]  TSV: layer, provider, source, destination
//   node container-interface.mjs session [--root DIR]  one session path per line
//   node container-interface.mjs check   [--root DIR]  findings, one per line; exit 1 on any
//
// A missing or unparseable manifest, and a missing dockerfile, are findings
// rather than empty results, so a broken input never reads as a clean run.

import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join } from "node:path";

const MANIFEST_REL = "src/build/container-interface.json";
const PROVIDERS_REL = "src/reasoning/providers";
const ENTRYPOINT_REL = "src/reasoning/entrypoint.sh";
const DOCKERFILE_NAME = "provider.dockerfile";
// The agent tree the images place prompts, skills and the config template in.
// It is the namespace the coverage check reads: a destination under it is
// either a declared cell or the provision template, and anything else is a
// surface the image carries with nobody declaring what loads it.
const INSTRUCTION_TREE = "/opt/workflow/agent/";
const SETTINGS_REL = "src/reasoning/providers/pi/config/agent/settings.json";
const SETTINGS_ROOTS = ["prompts", "skills"];

// provider_names ROOT -- the provider directories that carry a dockerfile,
// sorted. The set is read from the tree rather than declared, so a new provider
// is reported as a manifest gap instead of being silently unseen.
export function provider_names(root) {
  const dir = join(root, PROVIDERS_REL);
  let names;
  try {
    names = readdirSync(dir);
  } catch {
    return [];
  }
  return names
    .filter((name) => {
      try {
        return statSync(join(dir, name, DOCKERFILE_NAME)).isFile();
      } catch {
        return false;
      }
    })
    .sort();
}

export function dockerfile_path(root, provider) {
  return join(root, PROVIDERS_REL, provider, DOCKERFILE_NAME);
}

// parse_copies FILE -- the `COPY` lines that send one path to another, as
// { source, destination }. A `COPY` with more than two arguments, or with a
// flag, is not a layout statement and is skipped here; the equality check
// reports it as a line the manifest does not carry.
export function parse_copies(file) {
  const rows = [];
  for (const line of read_lines(file)) {
    const match = /^COPY\s+(\S+)\s+(\S+)\s*$/.exec(line);
    if (match) rows.push({ source: match[1], destination: match[2] });
  }
  return rows;
}

// parse_envs FILE -- the `ENV NAME=VALUE` lines, as { name, value }.
export function parse_envs(file) {
  const rows = [];
  for (const line of read_lines(file)) {
    const match = /^ENV\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line);
    if (match) rows.push({ name: match[1], value: match[2].trim() });
  }
  return rows;
}

function read_lines(file) {
  try {
    return readFileSync(file, "utf8").split("\n");
  } catch {
    return [];
  }
}

// load_manifest ROOT -- the parsed manifest, or undefined when it is absent or
// does not parse. The caller turns undefined into a finding.
export function load_manifest(root) {
  try {
    return JSON.parse(readFileSync(join(root, MANIFEST_REL), "utf8"));
  } catch {
    return undefined;
  }
}

// manifest_rows MANIFEST NAME -- the rows of one layer, always an array.
export function manifest_rows(manifest, name) {
  const rows = manifest && manifest[name];
  return Array.isArray(rows) ? rows : [];
}

// source_roots ROOT KIND -- the repository directories whose payload seeds a
// cell whose runtime path is that kind's root, deduplicated. `kind` is the
// folder name the loader scans, `skills` or `prompts`. A gate that resolves an
// instruction by name reads its subjects here, so a new root is declared once.
export function source_roots(root, kind) {
  const manifest = load_manifest(root) || {};
  const suffix = "/" + kind + "/";
  const out = [];
  for (const cell of manifest_rows(manifest, "cells")) {
    if (typeof cell.runtime_path !== "string" || !cell.runtime_path.endsWith(suffix)) continue;
    const sources = Array.isArray(cell.sources) ? cell.sources : [];
    for (const source of sources) out.push(String(source).replace(/\/+$/, ""));
  }
  return [...new Set(out)];
}

// home_of MANIFEST PROVIDER -- the provider's `$AGENT_HOME` value, or empty.
export function home_of(manifest, provider) {
  const row = manifest_rows(manifest, "env").find(
    (entry) => entry.provider === provider && entry.name === "AGENT_HOME",
  );
  return row ? row.value : "";
}

// resolve_home MANIFEST PROVIDER REF -- a provision row's `home` reference
// resolved to an absolute path. `$AGENT_HOME/` becomes the provider's home with
// a trailing slash, so a file beneath the template keeps the same suffix.
export function resolve_home(manifest, provider, ref) {
  const home = home_of(manifest, provider);
  if (!home) return "";
  const suffix = ref.replace(/^\$AGENT_HOME/, "");
  return home + suffix;
}

// pairs ROOT -- every repository-directory to image-directory pair a consumer
// may need, as { layer, provider, source, destination }. The `image` layer is
// the `COPY` destinations; the `provision` layer is the entrypoint's copy of
// the config template into the provider home.
export function pairs(root) {
  const manifest = load_manifest(root);
  if (!manifest) return [];
  const out = [];
  for (const row of manifest_rows(manifest, "image")) {
    out.push({
      layer: "image",
      provider: row.provider,
      source: row.source,
      destination: row.destination,
    });
  }
  for (const row of manifest_rows(manifest, "provision")) {
    const destination = resolve_home(manifest, row.provider, row.home);
    if (destination) {
      out.push({
        layer: "provision",
        provider: row.provider,
        source: row.source,
        destination,
      });
    }
  }
  return out;
}

// copy_destinations ROOT -- the `image` layer rows, keyed for the check that
// asks what destination a source directory has in each provider's image.
export function copy_destinations(root, source) {
  return pairs(root)
    .filter((row) => row.layer === "image" && row.source === source)
    .map((row) => row.destination);
}

// session_paths MANIFEST -- the paths a session reads whatever surface it is
// reading from, in declaration order. They describe the environment rather than
// a surface, so no cell restates them and the two AGENTS.md layer tables
// partition them.
export function session_paths(manifest) {
  return manifest_rows(manifest, "session").map((row) => row.path);
}

// instruction_reach ROOT REPO_PATH -- the reach the cell that declares a file
// grants it, or null when no cell declares the file. `image` is every prefix a
// link may target in the image's path space: the instruction roots the cells
// declare, the session paths every surface reads, and the cell's own reachable
// rows. `repo` is the cell's reachable rows as repository paths, the paths its
// files read with the repository tree present. `$AGENT_HOME` stays literal and
// is also expanded with each provider's home, because a cell writes the
// variable and the image resolves it.
export function instruction_reach(root, repoPath) {
  const manifest = load_manifest(root);
  if (!manifest) return null;
  const cells = manifest_rows(manifest, "cells");
  const cell = cells.find((row) =>
    (row.sources || []).some((source) => repoPath.startsWith(source)),
  );
  if (!cell) return null;
  const homes = manifest_rows(manifest, "env")
    .filter((row) => row.name === "AGENT_HOME")
    .map((row) => row.value);
  const variants = (path) => [path, ...homes.map((home) => path.replace(/^\$AGENT_HOME/, home))];
  const reachable = (cell.reachable || []).map((row) => row.path);
  const image = [
    ...cells.map((row) => row.runtime_path).filter((path) => path && path !== "none"),
    ...session_paths(manifest),
    ...reachable,
  ].flatMap(variants);
  return { cell, image, repo: reachable };
}

// check_cells ROOT MANIFEST PROVIDERS FINDINGS -- the declared instruction
// surfaces checked against the artefacts and against the rules each carries.
// A cell's folder set is derived from the `image` and `provision` rows, so a
// `COPY` line added to an instruction root with no cell is a finding rather
// than an undeclared surface. `runtime_path: none` means no image carries the
// surface, and such a cell may name no image path at all: a surface that
// travels with a project must not assume the container it is read in. A runtime
// path inside a `session` row is read from the project tree, and the provider's
// settings record must name it.
function check_cells(root, manifest, providers, findings) {
  const cells = manifest_rows(manifest, "cells");
  const images = manifest_rows(manifest, "image");
  const provisions = manifest_rows(manifest, "provision");
  const session = session_paths(manifest);
  const root_keys = settings_root_keys(root);
  const roots = root_keys === null ? null : SETTINGS_ROOTS.flatMap((key) => root_keys[key]);

  if (cells.length === 0) {
    findings.push("cells: the manifest declares no instruction surface");
    return;
  }
  if (roots === null) {
    findings.push(`${SETTINGS_REL}: missing or does not parse; cannot check a prompt or skill root`);
  }

  const claimed_sources = new Map();
  const claimed_paths = new Map();
  for (const [index, cell] of cells.entries()) {
    const where = `cells[${index}]`;
    if (!Array.isArray(cell.sources) || cell.sources.length === 0) {
      findings.push(`${where}: declares no source folder`);
      continue;
    }
    for (const source of cell.sources) {
      if (!source.endsWith("/")) {
        findings.push(`${where}: source '${source}' has no trailing slash`);
      }
      if (claimed_sources.has(source)) {
        findings.push(`${where}: source '${source}' is already declared by cells[${claimed_sources.get(source)}]`);
      } else {
        claimed_sources.set(source, index);
      }
    }
    if (cell.runtime_path !== "none") {
      if (claimed_paths.has(cell.runtime_path)) {
        findings.push(`${where}: runtime path '${cell.runtime_path}' is already declared by cells[${claimed_paths.get(cell.runtime_path)}]`);
      } else {
        claimed_paths.set(cell.runtime_path, index);
      }
    }
    if (typeof cell.loader !== "string" || cell.loader.trim() === "") {
      findings.push(`${where}: declares no loader`);
    }
    if (cell.provider !== undefined && !providers.includes(cell.provider)) {
      findings.push(`${where}: names provider '${cell.provider}', which carries no dockerfile`);
    }
    check_reachable(where, cell, findings);
    check_scoping(where, cell, providers, findings);
    check_surface(where, cell, images, provisions, roots, root, session, findings);
  }

  // Every destination in the agent tree is a declared surface or the template
  // the entrypoint seeds the agent home from. Anything else ships with nobody
  // declaring what loads it.
  const declared = new Set(
    cells.map((cell) => normalize_dir(cell.runtime_path)).filter((path) => path.startsWith(INSTRUCTION_TREE)),
  );
  for (const row of images) {
    const destination = normalize_dir(row.destination);
    if (!destination.startsWith(INSTRUCTION_TREE)) continue;
    if (declared.has(destination)) continue;
    if (provisions.some((entry) => normalize_dir(entry.template) === destination)) continue;
    findings.push(
      `image: ${row.provider} sends '${row.source}' to '${row.destination}', which no cell declares and no provision row seeds from`,
    );
  }

  // One source, one destination. A folder the images send to two places has no
  // single runtime path, so no cell can declare it, and the surface would
  // differ by provider with only the loader prose recording that.
  const by_source = new Map();
  for (const row of images) {
    const key = normalize_dir(row.source);
    if (!by_source.has(key)) by_source.set(key, new Set());
    by_source.get(key).add(normalize_dir(row.destination));
  }
  for (const [source, destinations] of by_source) {
    if (destinations.size > 1) {
      findings.push(
        `image: '${source}' lands at ${[...destinations].sort().join(', ')}; one source has one runtime path`,
      );
    }
  }

  check_names(root, manifest, root_keys, findings);
}

// check_reachable WHERE CELL FINDINGS -- the rows the cell adds to the session
// environment. `always` is the session's condition, so a cell that repeats it
// is restating the environment rather than adding to it.
function check_reachable(where, cell, findings) {
  const rows = cell.reachable;
  if (rows === undefined) return;
  if (!Array.isArray(rows)) {
    findings.push(`${where}: reachable is not a list`);
    return;
  }
  for (const row of rows) {
    for (const field of ["path", "holds", "condition"]) {
      if (typeof row[field] !== "string" || row[field].trim() === "") {
        findings.push(`${where}: a reachable row declares no ${field}`);
      }
    }
    if (row.condition === "always") {
      findings.push(`${where}: reachable row '${row.path}' carries 'always', which the session rows already declare`);
    }
  }
}

// check_scoping WHERE CELL PROVIDERS FINDINGS -- the two rules a cell's own row
// carries. A surface no image carries names no image path. A surface that
// belongs to no single provider names none.
function check_scoping(where, cell, providers, findings) {
  if (cell.runtime_path === "none") {
    for (const value of strings_of(cell)) {
      if (/\/opt\/|\$AGENT_HOME/.test(value)) {
        findings.push(`${where}: a surface no image carries names the image path in '${value}'`);
      }
    }
  }
  if (cell.provider === undefined && typeof cell.loader === "string") {
    for (const provider of providers) {
      if (new RegExp(`\\b${provider}\\b`, "i").test(cell.loader)) {
        findings.push(`${where}: a surface that belongs to no provider names '${provider}' in its loader`);
      }
    }
  }
}

// check_surface WHERE CELL IMAGES PROVISIONS ROOTS ROOT SESSION FINDINGS -- the
// cell's runtime path against the artefacts that implement it. The folder set is
// derived rather than trusted: an `/opt` path is a `COPY` destination, a
// `$AGENT_HOME` path is the provision template with the home prefix removed,
// and `none` is a folder no `COPY` line sends anywhere, directly or inside a
// copied tree. An `/opt` path is also a prompt or skill root in the provider's
// settings record, because a path the image carries and the agent cannot load
// is the failure this check exists for. A path inside a `session` row is read
// from the project tree, so no `COPY` line sends it and the provider whose
// launch command names it must carry it there.
function check_surface(where, cell, images, provisions, roots, root, session, findings) {
  const runtime = cell.runtime_path;
  const declared = cell.sources.map(normalize_dir);

  if (runtime === "none") {
    check_no_copy(where, runtime, declared, images, findings);
    return;
  }

  if (runtime.startsWith("/opt/")) {
    const derived = images.filter((row) => normalize_dir(row.destination) === normalize_dir(runtime)).map((row) => normalize_dir(row.source));
    compare_sources(where, declared, derived, findings);
    if (roots !== null && !roots.includes(runtime.replace(/\/+$/, ""))) {
      findings.push(`${where}: runtime path '${runtime}' is not a root in ${SETTINGS_REL}`);
    }
    return;
  }

  if (runtime.startsWith("$AGENT_HOME/")) {
    const provision = provisions.find((row) => runtime.startsWith(row.home));
    if (!provision) {
      findings.push(`${where}: runtime path '${runtime}' sits in no provision row's home`);
      return;
    }
    const remainder = runtime.slice(provision.home.length);
    compare_sources(where, declared, [normalize_dir(provision.source) + remainder], findings);
    return;
  }

  const session_path = session.find((path) => normalize_dir(runtime).startsWith(normalize_dir(path)));
  if (session_path) {
    check_project_surface(where, cell, declared, images, root, findings);
    return;
  }

  findings.push(`${where}: runtime path '${runtime}' is neither an /opt path, a $AGENT_HOME path, a session path, nor 'none'`);
}

// check_no_copy WHERE KIND DECLARED IMAGES FINDINGS -- no `COPY` line may send a
// declared source into an image, directly or as part of a copied tree. A
// surface that travels with the project is read from where the project is, and
// a `none` surface ships nowhere at all, so either way an image copying it
// would be a second copy with no owner. KIND names the runtime path the cell
// declares, for the finding's text.
function check_no_copy(where, kind, declared, images, findings) {
  for (const source of declared) {
    const copied = images.find((row) => normalize_dir(row.source) === source);
    const inside = images.find((row) => source.startsWith(normalize_dir(row.source)));
    if (copied) {
      findings.push(`${where}: runtime path '${kind}' while ${copied.provider} copies '${source}' to '${copied.destination}'`);
    } else if (inside) {
      findings.push(`${where}: runtime path '${kind}' while ${inside.provider} copies '${inside.source}', which contains '${source}'`);
    }
  }
}

// check_project_surface WHERE CELL DECLARED IMAGES ROOT FINDINGS -- a surface
// read from the project tree the session mounts. No image row may send its
// source anywhere, and the provider's settings record must name the path in its
// `prompts` key: a root the record does not name is declared and never loaded,
// and nothing reports the loss. A path the record does not name is also skipped
// silently when it is absent, which is why the record is the carrier rather
// than a launch flag that reports every project without the folder.
function check_project_surface(where, cell, declared, images, root, findings) {
  const runtime = cell.runtime_path;
  check_no_copy(where, "the project tree", declared, images, findings);

  if (cell.provider === undefined) {
    findings.push(`${where}: runtime path '${runtime}' is in the project tree, but the cell names no provider whose settings record reads it`);
    return;
  }

  const keys = settings_root_keys(root);
  if (keys === null) {
    // A missing record is reported once, by check_cells, so it is not restated
    // here as a cell that the record does not name.
    return;
  }
  if (!keys.prompts.includes(strip_dir(runtime))) {
    findings.push(`${where}: ${SETTINGS_REL} names no '${strip_dir(runtime)}' in its prompts key, so nothing loads '${runtime}'`);
  }
}

// compare_sources WHERE DECLARED DERIVED FINDINGS -- the two sets, each
// direction named, because which side to fix is the whole finding.
function compare_sources(where, declared, derived, findings) {
  for (const source of declared) {
    if (!derived.includes(source)) {
      findings.push(`${where}: declares source '${source}', which no image row sends to this runtime path`);
    }
  }
  for (const source of derived) {
    if (!declared.includes(source)) {
      findings.push(`${where}: the image sends '${source}' to this runtime path, which the cell does not declare`);
    }
  }
}

// strings_of VALUE -- every string inside a cell row, so a rule about what a
// row may name reads the whole row rather than one field.
function strings_of(value) {
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) return value.flatMap(strings_of);
  if (value && typeof value === "object") return Object.values(value).flatMap(strings_of);
  return [];
}

// settings_root_keys ROOT -- the prompt and skill roots the provider's settings
// enables, by key, or null when the record is absent or does not parse. A root
// is enabled either by the key's own list or by a package entry whose
// conventional subdirectory it is: that is how a module's payload reaches the
// settings without the settings naming each of its folders. A missing record is
// a finding, not an empty list, so it never reads as agreement.
export function settings_root_keys(root) {
  let settings;
  try {
    settings = JSON.parse(readFileSync(join(root, SETTINGS_REL), "utf8"));
  } catch {
    return null;
  }
  const packages = (Array.isArray(settings.packages) ? settings.packages : [])
    .filter((entry) => typeof entry === "string" && entry.startsWith("/"))
    .map(strip_dir);
  const out = {};
  for (const key of SETTINGS_ROOTS) {
    const named = (Array.isArray(settings[key]) ? settings[key] : []).map(strip_dir);
    const conventional = packages.map((entry) => entry + "/" + key);
    out[key] = [...new Set([...named, ...conventional])];
  }
  return out;
}

// strip_dir PATH -- a root as the settings record writes it, with no trailing
// slash, which is the form a cell's runtime path is compared against.
function strip_dir(path) {
  return path.replace(/\/+$/, "");
}

// settings_roots ROOT -- the same roots as one list, which is what a cell is
// checked against.
function settings_roots(root) {
  const keys = settings_root_keys(root);
  return keys === null ? null : SETTINGS_ROOTS.flatMap((key) => keys[key]);
}

// entry_names DIR KIND -- the names a root holds. A prompt is a Markdown file
// and a skill is a directory holding `SKILL.md`, read from the source folder the
// image copies, so the check sees what the loader will see.
function entry_names(dir, kind) {
  const names = [];
  const walk = (current) => {
    let entries;
    try {
      entries = readdirSync(current);
    } catch {
      return;
    }
    for (const entry of entries) {
      const full = join(current, entry);
      let stat;
      try {
        stat = statSync(full);
      } catch {
        continue;
      }
      if (stat.isDirectory()) {
        if (kind === "skills" && existsSync(join(full, "SKILL.md"))) names.push(entry);
        walk(full);
      } else if (kind === "prompts" && entry.endsWith(".md")) {
        names.push(entry);
      }
    }
  };
  walk(dir);
  return names;
}

// check_names ROOT MANIFEST KEYS FINDINGS -- no two roots under one settings key
// may hold the same name. The loader resolves one of the two and ignores the
// other, and nothing reports the loser. A module enabled beside the harness
// payload is where that happens, and the failure carries no signal of its own.
function check_names(root, manifest, keys, findings) {
  if (keys === null) return;
  const cells = manifest_rows(manifest, "cells");
  for (const key of SETTINGS_ROOTS) {
    const seen = new Map();
    for (const runtime of keys[key]) {
      const cell = cells.find((row) => normalize_dir(row.runtime_path) === normalize_dir(runtime));
      if (!cell) continue;
      for (const source of cell.sources) {
        for (const name of entry_names(join(root, source), key)) {
          if (seen.has(name)) {
            findings.push(
              `${key}: '${name}' is held by '${seen.get(name)}' and by '${cell.runtime_path}'; one shadows the other`,
            );
          } else {
            seen.set(name, cell.runtime_path);
          }
        }
      }
    }
  }
}

// check ROOT -- findings against the provider dockerfiles. The manifest and the
// `COPY` and `ENV` lines must hold the same set in both directions: a row no
// line carries is a finding, and a line no row carries is a finding.
export function check(root) {
  const findings = [];
  const manifest = load_manifest(root);
  if (!manifest) {
    return [`${MANIFEST_REL}: missing or does not parse`];
  }

  const providers = provider_names(root);
  if (providers.length === 0) {
    return [`${PROVIDERS_REL}: no provider dockerfile to check the manifest against`];
  }

  const copies = [];
  const envs = [];
  for (const provider of providers) {
    const file = dockerfile_path(root, provider);
    for (const row of parse_copies(file)) copies.push({ provider, ...row });
    for (const row of parse_envs(file)) envs.push({ provider, ...row });
  }

  // A provider the manifest does not mention at all would otherwise pass, with
  // every one of its lines reported as an unlisted row.
  for (const provider of providers) {
    const named = [...manifest_rows(manifest, "image"), ...manifest_rows(manifest, "env")]
      .some((row) => row.provider === provider);
    if (!named) findings.push(`${PROVIDERS_REL}/${provider}: no manifest row names this provider`);
  }

  findings.push(...compare("image", manifest_rows(manifest, "image"), copies, copy_key));
  findings.push(...compare("env", manifest_rows(manifest, "env"), envs, env_key));

  const entrypoint = read_lines(join(root, ENTRYPOINT_REL))
    .find((line) => /^PROVISION_TEMPLATE=/.test(line));
  const template = entrypoint ? entrypoint.slice("PROVISION_TEMPLATE=".length).replace(/^"|"$/g, "") : "";

  for (const row of manifest_rows(manifest, "provision")) {
    const image = manifest_rows(manifest, "image").find(
      (entry) => entry.provider === row.provider && entry.source === row.source,
    );
    if (!image) {
      findings.push(`provision: ${row.provider} declares source '${row.source}', which no image row carries`);
    } else if (image.destination !== row.template) {
      findings.push(
        `provision: ${row.provider} names template '${row.template}', the image row sends '${row.source}' to '${image.destination}'`,
      );
    }
    if (!home_of(manifest, row.provider)) {
      findings.push(`provision: ${row.provider} names no AGENT_HOME env row, so '${row.home}' resolves to nothing`);
    }
    if (template && normalize_dir(template) !== normalize_dir(row.template)) {
      findings.push(
        `${ENTRYPOINT_REL}: PROVISION_TEMPLATE reads '${template}', the manifest names '${row.template}'`,
      );
    }
  }

  if (!template) findings.push(`${ENTRYPOINT_REL}: no PROVISION_TEMPLATE line`);

  check_cells(root, manifest, providers, findings);

  return findings;
}

// normalize_dir PATH -- a directory path with exactly one trailing slash, so a
// declaration and a `COPY` line that differ only in the slash compare equal.
function normalize_dir(path) {
  return path.replace(/\/+$/, "") + "/";
}

function copy_key(row) {
  return `${row.provider}\t${row.source}\t${row.destination}`;
}

function env_key(row) {
  return `${row.provider}\t${row.name}\t${row.value}`;
}

// compare LAYER DECLARED DERIVED KEY -- the two sets against each other, with
// the direction named, so a reader knows which side to fix.
function compare(layer, declared, derived, key) {
  const findings = [];
  const declared_keys = new Set(declared.map(key));
  const derived_keys = new Set(derived.map(key));

  for (const row of declared) {
    if (!derived_keys.has(key(row))) {
      findings.push(`${layer}: the manifest declares '${key(row)}', which the dockerfiles do not carry`);
    }
  }
  for (const row of derived) {
    if (!declared_keys.has(key(row))) {
      findings.push(`${layer}: ${PROVIDERS_REL}/${row.provider}/${DOCKERFILE_NAME} carries '${key(row)}', which the manifest does not declare`);
    }
  }
  return findings;
}

function parse_args(argv) {
  const args = { command: "", root: process.cwd() };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--root") {
      args.root = argv[i + 1];
      i += 1;
    } else if (!args.command) {
      args.command = argv[i];
    }
  }
  return args;
}

function main(argv) {
  const args = parse_args(argv);
  if (args.command === "pairs") {
    for (const row of pairs(args.root)) {
      process.stdout.write(`${row.layer}\t${row.provider}\t${row.source}\t${row.destination}\n`);
    }
    return 0;
  }
  if (args.command === "session") {
    const paths = session_paths(load_manifest(args.root) || {});
    for (const path of paths) process.stdout.write(`${path}\n`);
    return paths.length === 0 ? 1 : 0;
  }
  if (args.command === "roots") {
    const kind = argv[argv.indexOf("--kind") + 1];
    if (kind !== "skills" && kind !== "prompts") {
      process.stderr.write("roots needs --kind skills|prompts\n");
      return 2;
    }
    const dirs = source_roots(args.root, kind);
    for (const dir of dirs) process.stdout.write(`${dir}\n`);
    return dirs.length === 0 ? 1 : 0;
  }
  if (args.command === "check") {
    const findings = check(args.root);
    for (const finding of findings) process.stdout.write(`${finding}\n`);
    return findings.length === 0 ? 0 : 1;
  }
  process.stderr.write(
    "usage: container-interface.mjs pairs|session|roots|check [--root DIR] [--kind skills|prompts]\n",
  );
  return 2;
}

if (process.argv[1] && process.argv[1].endsWith("container-interface.mjs")) {
  process.exit(main(process.argv.slice(2)));
}
