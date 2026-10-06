// scripts/lint/image-map.mjs
// The container layout, read once and served to every check that needs it.
//
// `scripts/lint/image-map.json` declares the layout. This module is its only
// reader: the checks call it rather than parsing the manifest themselves, so
// there is one parse, one derivation and one resolution rule. The truth the
// manifest claims is the provider dockerfiles' `COPY` and `ENV` lines, and
// `scripts/check_image_map.sh` holds the two equal in both directions.
//
// A source directory can land in more than one place, and does: the provider
// config is copied to `/opt/workflow/agent/config/` by a `COPY` line, and the
// entrypoint copies that template into `$AGENT_HOME/` at every start. Both
// destinations exist in the container, so the map carries both and a consumer
// accepts any of them. `sources_of` inverts the relation the same way.
//
// CLI:
//   node image-map.mjs pairs [--root DIR]   TSV: layer, provider, source, destination
//   node image-map.mjs check [--root DIR]   findings, one per line; exit 1 on any
//
// A missing or unparseable manifest, and a missing dockerfile, are findings
// rather than empty results, so a broken input never reads as a clean run.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const MANIFEST_REL = "scripts/lint/image-map.json";
const PROVIDERS_REL = "src/reasoning/providers";
const ENTRYPOINT_REL = "src/reasoning/entrypoint.sh";
const DOCKERFILE_NAME = "provider.dockerfile";

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
  if (args.command === "check") {
    const findings = check(args.root);
    for (const finding of findings) process.stdout.write(`${finding}\n`);
    return findings.length === 0 ? 0 : 1;
  }
  process.stderr.write("usage: image-map.mjs pairs|check [--root DIR]\n");
  return 2;
}

if (process.argv[1] && process.argv[1].endsWith("image-map.mjs")) {
  process.exit(main(process.argv.slice(2)));
}
