import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleUrl = pathToFileURL("C:/Users/Damian/AppData/Local/npm-cache/_npx/43414d9b790239bb/node_modules/@paperclipai/adapter-utils/dist/server-utils.js").href;
const { ensurePaperclipSkillSymlink } = await import(moduleUrl);

const root = "C:/labs/Felix Playbook/tmp/paperclip-skill-injection-test";
const source = path.join(root, "source-skill");
const target = path.join(root, "workspace-skills", "source-skill");
await fs.mkdir(path.join(source, "references"), { recursive: true });
await fs.mkdir(path.dirname(target), { recursive: true });
await fs.writeFile(path.join(source, "SKILL.md"), "# Test Skill\n", "utf8");
await fs.writeFile(path.join(source, "references", "notes.md"), "hello\n", "utf8");
const error = new Error("operation not permitted");
error.code = "EPERM";
const result = await ensurePaperclipSkillSymlink(source, target, async () => { throw error; });
const stat = await fs.lstat(target);
const skill = await fs.readFile(path.join(target, "SKILL.md"), "utf8");
const ref = await fs.readFile(path.join(target, "references", "notes.md"), "utf8");
console.log(JSON.stringify({ result, isSymbolicLink: stat.isSymbolicLink(), skill: skill.trim(), ref: ref.trim() }));