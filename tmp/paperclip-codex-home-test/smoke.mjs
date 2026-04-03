import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleUrl = pathToFileURL("C:/Users/Damian/AppData/Local/npm-cache/_npx/43414d9b790239bb/node_modules/@paperclipai/adapter-codex-local/dist/server/codex-home.js").href;
const { prepareManagedCodexHome } = await import(moduleUrl);

const root = "C:/labs/Felix Playbook/tmp/paperclip-codex-home-test";
const sourceHome = path.join(root, "shared-codex");
const paperclipHome = path.join(root, "paperclip-home");
await fs.mkdir(sourceHome, { recursive: true });
await fs.writeFile(path.join(sourceHome, "auth.json"), JSON.stringify({ ok: true }), "utf8");
await fs.writeFile(path.join(sourceHome, "config.toml"), "model = \"gpt-5.3-codex\"\n", "utf8");
const env = {
  CODEX_HOME: sourceHome,
  PAPERCLIP_HOME: paperclipHome,
  PAPERCLIP_INSTANCE_ID: "default"
};
const targetHome = await prepareManagedCodexHome(env, async () => {}, "company-test");
const authPath = path.join(targetHome, "auth.json");
const stat = await fs.lstat(authPath);
const content = await fs.readFile(authPath, "utf8");
console.log(JSON.stringify({ targetHome, authPath, isSymbolicLink: stat.isSymbolicLink(), content }));