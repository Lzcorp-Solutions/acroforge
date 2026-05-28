import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const docsRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(docsRoot, "..");
const versionPath = path.join(repoRoot, "lib/acroforge/version.rb");
const outPath = path.join(docsRoot, ".vitepress/generated/version.json");
const packageJsonPath = path.join(docsRoot, "package.json");

const source = await readFile(versionPath, "utf8");
const match = source.match(/VERSION\s*=\s*["']([^"']+)["']/);

if (!match) {
  throw new Error(`Could not parse VERSION from ${versionPath}`);
}

const version = match[1];

await mkdir(path.dirname(outPath), { recursive: true });
await writeFile(outPath, `${JSON.stringify({ version }, null, 2)}\n`, "utf8");

const pkg = JSON.parse(await readFile(packageJsonPath, "utf8"));
if (pkg.version !== version) {
  pkg.version = version;
  await writeFile(packageJsonPath, `${JSON.stringify(pkg, null, 2)}\n`, "utf8");
}

// The README is static GitHub markdown — it can't interpolate like the
// VitePress pages, so pin its `acroforge_version:` example line here instead.
const readmePath = path.join(repoRoot, "README.md");
const readme = await readFile(readmePath, "utf8");
const updatedReadme = readme.replace(
  /(acroforge_version:\s*)\d+\.\d+\.\d+/,
  `$1${version}`
);
if (updatedReadme !== readme) {
  await writeFile(readmePath, updatedReadme, "utf8");
}
