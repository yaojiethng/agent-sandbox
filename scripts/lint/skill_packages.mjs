#!/usr/bin/env node
// scripts/lint/skill_packages.mjs
//
// The package-manifest gate: `.agents/registry/packages.json` parses, names at
// least one package, and every entry carries a source, a scope and a reason.
//
// Scope is the manifest alone. The difference against what is installed is a
// runtime report, `node scripts/skill_packages.mjs`, because the installed state
// exists only inside a container that has the image. A gate that read it would
// fail on a maintainer's checkout for a reason that is not a defect.
//
// Test seam: SKILL_PACKAGES_SCAN_ROOT points the gate at a fixture root.
//
// Exit codes: 0 = no finding, 1 = findings or the manifest cannot be read.

import { existsSync } from "node:fs";
import { join, resolve } from "node:path";

import { MANIFEST_REL, readManifest } from "../skill_packages.mjs";

const ROOT = resolve(process.env.SKILL_PACKAGES_SCAN_ROOT || ".");
const FINDINGS = [];

if (!existsSync(join(ROOT, MANIFEST_REL))) {
  FINDINGS.push(`${MANIFEST_REL}: missing`);
} else {
  const { entries, error } = readManifest(ROOT);
  if (error) {
    FINDINGS.push(error);
  } else if (entries.length === 0) {
    FINDINGS.push(`${MANIFEST_REL}: names no package, so the drift check has nothing to compare`);
  } else {
    const seen = new Set();
    for (const [index, entry] of entries.entries()) {
      const where = `${MANIFEST_REL}: packages[${index}]`;
      if (!entry || typeof entry !== "object") {
        FINDINGS.push(`${where}: must be an object`);
        continue;
      }
      if (typeof entry.source !== "string" || entry.source.trim() === "") {
        FINDINGS.push(`${where}: needs a 'source', the pin as the operator wrote it`);
        continue;
      }
      if (entry.scope !== "user" && entry.scope !== "project") {
        FINDINGS.push(`${where}: 'scope' must be user or project`);
      }
      if (typeof entry.why !== "string" || entry.why.trim() === "") {
        FINDINGS.push(`${where}: needs a 'why', the reason the package is asked for`);
      }
      if (seen.has(entry.source)) {
        FINDINGS.push(`${where}: '${entry.source}' is named twice`);
      }
      seen.add(entry.source);
    }
  }
}

if (FINDINGS.length > 0) {
  for (const finding of FINDINGS) console.error(finding);
  console.error(`skill packages: ${FINDINGS.length} finding(s)`);
  process.exit(1);
}

console.log(`skill packages: clean`);
