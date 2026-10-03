import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = join(root, "site");
const moonbitModule = join(root, "_build", "js", "debug", "build", "web_api", "web_api.js");
const files = ["index.html", "styles.css", "app.js", "simulation-worker.js"];

if (resolve(output) !== resolve(root, "site") || !resolve(output).startsWith(resolve(root) + sep)) {
  throw new Error("Refusing to replace output outside the repository site directory.");
}
await readFile(moonbitModule);
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await Promise.all(files.map((file) => cp(join(root, "web", file), join(output, file))));
await cp(moonbitModule, join(output, "moonsim.js"));
await writeFile(join(output, "package.json"), '{"type":"module"}\n');
console.log(`Built MoonSim Web Lab into ${output}`);
