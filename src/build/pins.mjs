// src/build/pins.mjs
// The build-input pin check. Every input the build reads carries a pin at the
// strictest form its class supports, and src/build/pins.json records what that
// pin resolved to. The check is the derive-and-diff: it reads the pins back out
// of the Dockerfiles and lockfiles and fails when the two disagree.
//
// Two halves, two costs. The local half reads the tree and blocks; it runs in
// the lint umbrella and in front of every build. The remote half re-resolves
// against the registries and reports drift, because a republished artifact is
// information rather than a broken build.

import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";
import { gunzipSync } from "node:zlib";
import { spawnSync } from "node:child_process";

const PINS_REL = "src/build/pins.json";
const BASE_DOCKERFILE = "src/reasoning/base.dockerfile";
const RUNTIMES_DOCKERFILE = "src/reasoning/runtimes.dockerfile";
const REGISTRY_DIR = "src/reasoning/registry";
// The suites the base image's apt reads. A pin resolved from `bookworm` alone
// is not the version apt installs: a security update lands in
// `bookworm-security` first, and its dependency moves with it. Pinning the
// older pair makes the set unsatisfiable, which is a broken build rather than
// a recorded drift.
export const DEBIAN_SUITES = [
  { suite: "bookworm", url: "https://deb.debian.org/debian/dists/bookworm/main/binary-amd64/Packages.xz" },
  { suite: "bookworm-updates", url: "https://deb.debian.org/debian/dists/bookworm-updates/main/binary-amd64/Packages.xz" },
  { suite: "bookworm-security", url: "https://deb.debian.org/debian-security/dists/bookworm-security/main/binary-amd64/Packages.xz" },
];

// compare_debian_versions A B -- the ordering dpkg uses: epoch, then upstream,
// then revision, with `~` sorting before everything and a digit run compared as
// a number. Returns -1, 0 or 1.
export function compare_debian_versions(a, b) {
  const split = (version) => {
    const colon = version.indexOf(":");
    const epoch = colon === -1 ? 0 : Number(version.slice(0, colon));
    const rest = colon === -1 ? version : version.slice(colon + 1);
    const dash = rest.lastIndexOf("-");
    return {
      epoch,
      upstream: dash === -1 ? rest : rest.slice(0, dash),
      revision: dash === -1 ? "" : rest.slice(dash + 1),
    };
  };

  const order = (c) => {
    if (c === "~") return -1;
    if (/[0-9]/.test(c)) return 0;
    if (/[A-Za-z]/.test(c)) return c.charCodeAt(0);
    return c.charCodeAt(0) + 256;
  };

  const compare_part = (left, right) => {
    let i = 0;
    let j = 0;
    while (i < left.length || j < right.length) {
      let first_diff = 0;
      while ((i < left.length && !/[0-9]/.test(left[i])) || (j < right.length && !/[0-9]/.test(right[j]))) {
        const l = i < left.length && !/[0-9]/.test(left[i]) ? order(left[i]) : 0;
        const r = j < right.length && !/[0-9]/.test(right[j]) ? order(right[j]) : 0;
        if (l !== r) return l < r ? -1 : 1;
        if (i < left.length && !/[0-9]/.test(left[i])) i += 1;
        if (j < right.length && !/[0-9]/.test(right[j])) j += 1;
      }
      while (i < left.length && left[i] === "0") i += 1;
      while (j < right.length && right[j] === "0") j += 1;
      while (i < left.length && /[0-9]/.test(left[i]) && j < right.length && /[0-9]/.test(right[j])) {
        if (first_diff === 0) first_diff = left.charCodeAt(i) - right.charCodeAt(j);
        i += 1;
        j += 1;
      }
      if (i < left.length && /[0-9]/.test(left[i])) return 1;
      if (j < right.length && /[0-9]/.test(right[j])) return -1;
      if (first_diff !== 0) return first_diff < 0 ? -1 : 1;
    }
    return 0;
  };

  const left = split(a);
  const right = split(b);
  if (left.epoch !== right.epoch) return left.epoch < right.epoch ? -1 : 1;
  const upstream = compare_part(left.upstream, right.upstream);
  if (upstream !== 0) return upstream;
  return compare_part(left.revision, right.revision);
}

// highest -- the record apt would install: the greatest version across the
// suites, with the suite it came from kept for the report.
export function highest(candidates) {
  let best = null;
  for (const candidate of candidates) {
    if (!best || compare_debian_versions(candidate.version, best.version) > 0) best = candidate;
  }
  return best;
}

// xz -- Debian's security archive publishes Packages.xz and no Packages.gz, so
// the remote half needs an xz decompressor. There is no honest silent skip: a
// suite left unread is the exact failure that pinned an unsatisfiable set.
function xz(argv, input) {
  const result = spawnSync(argv[0], argv.slice(1).flat(), { input, maxBuffer: 1 << 28 });
  if (result.status !== 0) throw new Error(argv.join(" ") + ": " + String(result.stderr || "").trim());
  return result.stdout;
}

function decompress_xz(raw) {
  const lzma = ["-c", "import lzma,sys; sys.stdout.buffer.write(lzma.decompress(sys.stdin.buffer.read()))"];
  const attempts = [
    ["xz", ["-dc"]],
    ["unxz", ["-c"]],
    ["python3", lzma],
    ["python", lzma],
    ["python3.11", lzma],
  ];
  for (const argv of attempts) {
    try {
      return xz(argv, raw).toString("utf8");
    } catch {
      continue;
    }
  }
  throw new Error(
    "Debian publishes Packages.xz and no decompressor is on PATH (tried xz, unxz, python3, python, python3.11)",
  );
}

async function fetch_packages(url) {
  const raw = Buffer.from(await fetch(url).then((r) => r.arrayBuffer()));
  if (url.endsWith(".gz")) return gunzipSync(raw).toString("utf8");
  return decompress_xz(raw);
}

export const APT_PACKAGES = [
  "ca-certificates",
  "curl",
  "fd-find",
  "git",
  "jq",
  "ripgrep",
  "rsync",
  "shellcheck",
];

export const NPM_INPUTS = [
  {
    input: "npm:markdownlint-cli2",
    package: "markdownlint-cli2",
    dir: `${REGISTRY_DIR}/markdownlint-cli2`,
    dockerfile: BASE_DOCKERFILE,
    frozen_flag: null,
  },
  {
    input: "npm:pi",
    package: "@earendil-works/pi-coding-agent",
    dir: `${REGISTRY_DIR}/pi`,
    dockerfile: RUNTIMES_DOCKERFILE,
    frozen_flag: "--ignore-scripts",
  },
];

const URL_INPUTS = [
  { input: "hadolint", dockerfile: BASE_DOCKERFILE },
  { input: "uv", dockerfile: BASE_DOCKERFILE },
  { input: "opencode", dockerfile: RUNTIMES_DOCKERFILE },
];

function read(root, rel) {
  return readFileSync(join(root, rel), "utf8");
}

export function load_pins(root) {
  try {
    return JSON.parse(read(root, PINS_REL));
  } catch {
    return null;
  }
}

export function pin_of(pins, input) {
  const rows = Array.isArray(pins?.pins) ? pins.pins : [];
  return rows.find((row) => row.input === input) || null;
}

function url_input_facts(text, input) {
  const version = new RegExp(`^ARG\\s+${input.toUpperCase()}_VERSION=(\\S+)$`, "m").exec(text);
  const sha256 = new RegExp(`^ARG\\s+${input.toUpperCase()}_SHA256=([0-9a-f]{64})$`, "m").exec(text);
  if (!version) return null;
  return { version: version[1], sha256: sha256 ? sha256[1] : null };
}

// dockerfile_facts -- the pin literals the Dockerfiles carry, keyed by the same
// input ids the pins file uses. A literal the check cannot parse is absent
// rather than empty, so a missing pin reads as missing rather than as matched.
export function dockerfile_facts(root) {
  const base = read(root, BASE_DOCKERFILE);
  const runtimes = read(root, RUNTIMES_DOCKERFILE);
  const facts = {};

  const from = /^FROM\s+(\S+)$/m.exec(base);
  if (from) {
    const at = from[1].indexOf("@");
    facts["base-image"] = {
      image: at === -1 ? from[1] : from[1].slice(0, at),
      digest: at === -1 ? null : from[1].slice(at + 1),
    };
  }

  const install = /apt-get install[\s\S]*?rm -rf \/var\/lib\/apt\/lists/.exec(base);
  if (install) {
    for (const name of APT_PACKAGES) {
      const hit = new RegExp(`(?:^|\\s)${name}=([^\\s\\\\]+)`).exec(install[0]);
      if (hit) facts[`apt:${name}`] = { version: hit[1] };
    }
  }

  for (const spec of URL_INPUTS) {
    const fact = url_input_facts(spec.dockerfile === BASE_DOCKERFILE ? base : runtimes, spec.input);
    if (fact) facts[spec.input] = fact;
  }

  const python = /uv python install\s+(\S+)/.exec(base);
  if (python) facts.python = { version: python[1] };

  for (const spec of NPM_INPUTS) {
    let lock;
    try {
      lock = JSON.parse(read(root, `${spec.dir}/package-lock.json`));
    } catch {
      continue;
    }
    const entry = lock.packages?.[`node_modules/${spec.package}`];
    facts[spec.input] = {
      version: entry?.version || null,
      integrity: entry?.integrity || null,
      lockfile: `${spec.dir}/package-lock.json`,
    };
  }

  return facts;
}

function lockfile_findings(root, spec, findings) {
  let lock;
  try {
    lock = JSON.parse(read(root, `${spec.dir}/package-lock.json`));
  } catch {
    findings.push(`${spec.dir}: no package-lock.json to install frozen from`);
    return;
  }
  if (lock.lockfileVersion !== 3) {
    findings.push(`${spec.dir}/package-lock.json: lockfileVersion ${lock.lockfileVersion}, not 3`);
  }
  const declared = Object.entries(lock.packages || {}).filter(([path]) => path !== "");
  const missing = declared.filter(([, row]) => !row.integrity);
  if (missing.length > 0) {
    findings.push(
      `${spec.dir}/package-lock.json: ${missing.length} resolved package(s) carry no integrity hash`,
    );
  }
  if (!declared.some(([path]) => path === `node_modules/${spec.package}`)) {
    findings.push(`${spec.dir}/package-lock.json: does not resolve ${spec.package}`);
  }

  const text = read(root, spec.dockerfile);
  if (!new RegExp(`COPY\\s+${spec.dir}/\\s`).test(text)) {
    findings.push(`${spec.input}: ${spec.dockerfile} does not copy ${spec.dir}/ into the build`);
  }
  const install = new RegExp(
    `COPY\\s+${spec.dir}/[\\s\\S]{0,400}?npm ci${spec.frozen_flag ? " " + spec.frozen_flag : ""}`,
  );
  if (!install.test(text)) {
    findings.push(
      `${spec.input}: ${spec.dockerfile} does not install it with npm ci${spec.frozen_flag ? " " + spec.frozen_flag : ""}`,
    );
  }
}

// check -- the local half. Every input has a pin row, the Dockerfile literal is
// the one the pins file recorded, and every registry package installs frozen
// from a committed lockfile with integrity hashes.
export function check(root) {
  const findings = [];
  const pins = load_pins(root);
  if (!pins) return [`${PINS_REL}: missing or does not parse`];

  const facts = dockerfile_facts(root);
  const expected = [
    "base-image",
    ...APT_PACKAGES.map((name) => `apt:${name}`),
    ...URL_INPUTS.map((spec) => spec.input),
    "python",
    ...NPM_INPUTS.map((spec) => spec.input),
  ];

  for (const input of expected) {
    const pin = pin_of(pins, input);
    if (!pin) {
      findings.push(`${input}: no pin row in ${PINS_REL}`);
      continue;
    }
    const fact = facts[input];
    if (!fact) {
      findings.push(`${input}: no pin literal in the Dockerfile for this check to read`);
      continue;
    }
    if (pin.class === "base-image" && (!fact.digest || fact.digest !== pin.resolved?.digest)) {
      findings.push(
        `${input}: the Dockerfile resolves ${fact.digest || "no digest"}; the pin records ${pin.resolved?.digest}`,
      );
    }
    if (pin.class === "apt" && fact.version !== pin.resolved?.version) {
      findings.push(
        `${input}: the Dockerfile requests ${fact.version}; the pin records ${pin.resolved?.version}`,
      );
    }
    if (pin.class === "url-artifact") {
      if (fact.version !== pin.requested) {
        findings.push(
          `${input}: the Dockerfile requests ${fact.version}; the pin records ${pin.requested}`,
        );
      }
      if (!fact.sha256 || fact.sha256 !== pin.resolved?.sha256) {
        findings.push(
          `${input}: the RUN verifies ${fact.sha256 || "no checksum"}; the pin records ${pin.resolved?.sha256}`,
        );
      }
    }
    if (pin.class === "uv-resolved" && fact.version !== pin.resolved?.version) {
      findings.push(
        `${input}: the Dockerfile requests ${fact.version}; the pin records ${pin.resolved?.version}`,
      );
    }
    if (pin.class === "registry-package" && fact.version !== pin.requested) {
      findings.push(
        `${input}: the lockfile resolves ${fact.version}; the pin records ${pin.requested}`,
      );
    }
  }

  for (const spec of NPM_INPUTS) lockfile_findings(root, spec, findings);

  for (const row of pins.pins || []) {
    if (!row.input || !row.class || !row.resolved || !row.move) {
      findings.push(
        `${row.input || "?"}: a pin row carries an input, a class, a resolved artifact and a way to move it`,
      );
    }
  }

  return findings;
}

async function fetch_text(url) {
  const response = await fetch(url, { redirect: "follow" });
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  return response.text();
}

async function resolve_base_image(tag) {
  const [repo, reference] = tag.split(":");
  const { token } = await fetch(
    `https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/${repo}:pull`,
  ).then((r) => r.json());
  const response = await fetch(
    `https://registry-1.docker.io/v2/library/${repo}/manifests/${reference}`,
    {
      method: "HEAD",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept:
          "application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json",
      },
    },
  );
  return {
    digest: response.headers.get("docker-content-digest"),
    media_type: (response.headers.get("content-type") || "").split(";")[0],
  };
}

async function resolve_apt() {
  const out = {};
  for (const spec of DEBIAN_SUITES) {
    const text = await fetch_packages(spec.url);
    for (const block of text.split("\n\n")) {
      const name = /^Package: (.+)$/m.exec(block);
      if (!name || !APT_PACKAGES.includes(name[1])) continue;
      const version = /^Version: (.+)$/m.exec(block);
      const sha = /^SHA256: (.+)$/m.exec(block);
      if (!version || !sha) continue;
      (out[name[1]] ||= []).push({ suite: spec.suite, version: version[1], deb_sha256: sha[1] });
    }
  }
  const resolved = {};
  for (const [name, candidates] of Object.entries(out)) resolved[name] = highest(candidates);
  return resolved;
}

async function resolve_sha256(url) {
  const hit = /^([0-9a-f]{64})/m.exec(await fetch_text(url));
  if (!hit) throw new Error(`${url}: no sha256 in the publisher's file`);
  return hit[1];
}

async function resolve_npm(pkg, version) {
  const body = await fetch(
    `https://registry.npmjs.org/${encodeURIComponent(pkg)}/${version}`,
  ).then((r) => r.json());
  return body.dist?.integrity || null;
}

const CHECKSUM_URL = {
  hadolint: (version) =>
    `https://github.com/hadolint/hadolint/releases/download/${version}/hadolint-Linux-x86_64.sha256`,
  uv: (version) =>
    `https://github.com/astral-sh/uv/releases/download/${version}/uv-x86_64-unknown-linux-gnu.tar.gz.sha256`,
};

// An artifact whose publisher ships no checksum file is hashed where it is
// served, so the remote half reads the same bytes the build verifies.
const ARTIFACT_URL = {
  opencode: (version) =>
    `https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-${version}.tgz`,
};

async function resolve_artifact_sha256(url) {
  const body = Buffer.from(await fetch(url, { redirect: "follow" }).then((r) => r.arrayBuffer()));
  return createHash("sha256").update(body).digest("hex");
}

// bump -- re-resolve every remotely resolvable input and report what moved. The
// pins file is written only with --write, so a bump is reviewed before it lands.
export async function bump(root, { write }) {
  const pins = load_pins(root);
  if (!pins) throw new Error(`${PINS_REL}: missing or does not parse`);
  const drift = [];

  const base = pin_of(pins, "base-image");
  const base_now = await resolve_base_image(base.requested);
  if (base_now.digest && base_now.digest !== base.resolved.digest) {
    drift.push({ input: "base-image", was: base.resolved.digest, now: base_now.digest });
    base.resolved = { ...base.resolved, ...base_now };
  }

  const apt_now = await resolve_apt();
  for (const name of APT_PACKAGES) {
    const pin = pin_of(pins, `apt:${name}`);
    const now = apt_now[name];
    if (!now) {
      drift.push({ input: `apt:${name}`, was: pin.resolved.version, now: "not in the index" });
      continue;
    }
    if (now.version !== pin.resolved.version || now.deb_sha256 !== pin.resolved.deb_sha256) {
      drift.push({ input: `apt:${name}`, was: pin.resolved.version, now: `${now.version} (${now.suite})` });
    }
    pin.resolved = now;
  }

  for (const spec of URL_INPUTS) {
    const pin = pin_of(pins, spec.input);
    const now = ARTIFACT_URL[spec.input]
      ? await resolve_artifact_sha256(ARTIFACT_URL[spec.input](pin.requested))
      : await resolve_sha256(CHECKSUM_URL[spec.input](pin.requested));
    if (now !== pin.resolved.sha256) {
      drift.push({ input: spec.input, was: pin.resolved.sha256, now });
      pin.resolved = { ...pin.resolved, sha256: now };
    }
  }

  for (const spec of NPM_INPUTS) {
    const pin = pin_of(pins, spec.input);
    const now = await resolve_npm(spec.package, pin.requested);
    if (now && now !== pin.resolved.integrity) {
      drift.push({ input: spec.input, was: pin.resolved.integrity, now });
      pin.resolved = { ...pin.resolved, integrity: now };
    }
  }

  if (write) {
    pins.resolved_at = new Date().toISOString().slice(0, 10);
    writeFileSync(join(root, PINS_REL), `${JSON.stringify(pins, null, 2)}\n`);
  }
  return drift;
}

// report -- what each input carries now, for the bump's output and the host run.
export function report(pins) {
  const rows = (pins.pins || []).map((row) => [
    row.input,
    row.requested,
    row.resolved?.digest ||
      row.resolved?.sha256 ||
      row.resolved?.lockfile ||
      row.resolved?.version ||
      "",
    row.class,
  ]);
  const input_width = Math.max(4, ...rows.map((row) => row[0].length));
  const requested_width = Math.max(9, ...rows.map((row) => row[1].length));
  return rows
    .map(
      (row) =>
        `${row[0].padEnd(input_width)}  ${row[1].padEnd(requested_width)}  ${row[2]}  (${row[3]})`,
    )
    .join("\n");
}

// CLI: `check`, `bump` and `report`, each taking --root and bump taking --write.
if (process.argv[1] && process.argv[1].endsWith("pins.mjs")) {
  const args = process.argv.slice(2);
  const command = args[0];
  const root_index = args.indexOf("--root");
  const root = root_index === -1 ? process.cwd() : args[root_index + 1];
  const write = args.includes("--write");

  if (command === "check") {
    const findings = check(root);
    if (findings.length === 0) process.exit(0);
    for (const finding of findings) console.log(finding);
    process.exit(1);
  } else if (command === "bump") {
    const drift = await bump(root, { write });
    if (drift.length === 0) process.exit(0);
    for (const row of drift) console.log(`${row.input}: ${row.was} -> ${row.now}`);
    process.exit(0);
  } else if (command === "report") {
    console.log(report(load_pins(root)));
    process.exit(0);
  } else {
    console.error(`pins: unknown command: ${command}`);
    process.exit(2);
  }
}
