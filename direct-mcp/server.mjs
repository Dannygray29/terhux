#!/data/data/com.termux/files/usr/bin/node
import http from "node:http";
import crypto from "node:crypto";
import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";

const HOST = process.env.TERHUX_MCP_HOST || "127.0.0.1";
const PORT = Number(process.env.TERHUX_MCP_PORT || 8787);
const TOKEN = process.env.TERHUX_MCP_TOKEN || "";
const HOME = os.homedir();
const MAX_BODY = 1024 * 1024;
const VERSION = "2025-03-26";

if (TOKEN.length < 32) {
  console.error("Refusing to start: set TERHUX_MCP_TOKEN to a random secret of at least 32 characters.");
  process.exit(1);
}

const tools = [
  { name: "termux_status", description: "Return basic Termux runtime status.", inputSchema: { type: "object", properties: {}, additionalProperties: false } },
  { name: "termux_run", description: "Run a shell command in Termux as the phone owner. Only call for work the user has authorized. Commands have a 120-second limit; output is capped.", inputSchema: { type: "object", properties: { command: { type: "string", minLength: 1, maxLength: 12000 }, cwd: { type: "string", description: "Optional working directory, absolute or relative to Termux home." }, timeout_seconds: { type: "integer", minimum: 1, maximum: 120 } }, required: ["command"], additionalProperties: false } },
  { name: "termux_read_file", description: "Read a UTF-8 text file under the Termux home directory (max 256 KiB).", inputSchema: { type: "object", properties: { path: { type: "string", minLength: 1, maxLength: 2000 } }, required: ["path"], additionalProperties: false } },
  { name: "termux_list_files", description: "List files in a directory under the Termux home directory.", inputSchema: { type: "object", properties: { path: { type: "string", maxLength: 2000 } }, additionalProperties: false } }
];

function safePath(input = ".") {
  const full = path.resolve(HOME, input);
  if (full !== HOME && !full.startsWith(HOME + path.sep)) throw new Error("Path must remain inside Termux home.");
  return full;
}
function result(text, isError = false) {
  return { content: [{ type: "text", text: String(text).slice(0, 24000) }], ...(isError ? { isError: true } : {}) };
}
function auth(req) {
  const value = req.headers.authorization || "";
  const supplied = value.startsWith("Bearer ") ? value.slice(7) : "";
  const a = Buffer.from(supplied);
  const b = Buffer.from(TOKEN);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
async function readBody(req) {
  let data = "";
  for await (const chunk of req) {
    data += chunk;
    if (Buffer.byteLength(data) > MAX_BODY) throw new Error("Request too large.");
  }
  return JSON.parse(data || "{}");
}
async function callTool(name, args = {}) {
  if (name === "termux_status") {
    return result(JSON.stringify({ ok: true, platform: process.platform, arch: process.arch, node: process.version, home: HOME, cwd: process.cwd(), time: new Date().toISOString() }, null, 2));
  }
  if (name === "termux_read_file") {
    const p = safePath(args.path);
    const stat = await fs.stat(p);
    if (!stat.isFile()) throw new Error("Path is not a file.");
    if (stat.size > 256 * 1024) throw new Error("File exceeds 256 KiB limit.");
    return result(await fs.readFile(p, "utf8"));
  }
  if (name === "termux_list_files") {
    const p = safePath(args.path || ".");
    const entries = await fs.readdir(p, { withFileTypes: true });
    return result(entries.map(e => (e.isDirectory() ? "DIR  " : e.isSymbolicLink() ? "LINK " : "FILE ") + e.name).join("\n") || "(empty)");
  }
  if (name === "termux_run") {
    if (typeof args.command !== "string" || !args.command.trim()) throw new Error("command is required.");
    const cwd = safePath(args.cwd || ".");
    const timeout = Math.min(120, Math.max(1, Number(args.timeout_seconds || 60)));
    return await new Promise(resolve => {
      const child = spawn("bash", ["-lc", args.command], { cwd, env: { ...process.env, HOME }, stdio: ["ignore", "pipe", "pipe"] });
      let stdout = "", stderr = "", done = false;
      const cap = 24000;
      const timer = setTimeout(() => { child.kill("SIGTERM"); setTimeout(() => child.kill("SIGKILL"), 1500).unref(); }, timeout * 1000);
      const collect = (which, chunk) => {
        if (which === "out") stdout = (stdout + chunk.toString()).slice(-cap);
        else stderr = (stderr + chunk.toString()).slice(-cap);
      };
      child.stdout.on("data", c => collect("out", c));
      child.stderr.on("data", c => collect("err", c));
      child.on("error", e => { if (!done) { done = true; clearTimeout(timer); resolve(result(e.message, true)); } });
      child.on("close", (code, signal) => {
        if (done) return;
        done = true; clearTimeout(timer);
        resolve(result("exit_code=" + code + (signal ? " signal=" + signal : "") + "\n--- stdout ---\n" + stdout + "\n--- stderr ---\n" + stderr, code !== 0));
      });
    });
  }
  throw new Error("Unknown tool: " + name);
}
const server = http.createServer(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  if (req.url === "/health" && req.method === "GET") {
    res.writeHead(200, { "content-type": "application/json" }); res.end(JSON.stringify({ ok: true, service: "terhux-direct-mcp" })); return;
  }
  if (req.url !== "/mcp" || req.method !== "POST") {
    res.writeHead(404, { "content-type": "application/json" }); res.end(JSON.stringify({ error: "not found" })); return;
  }
  if (!auth(req)) { res.writeHead(401, { "content-type": "application/json", "www-authenticate": "Bearer" }); res.end(JSON.stringify({ error: "unauthorized" })); return; }
  try {
    const message = await readBody(req);
    if (!message || typeof message.method !== "string") throw new Error("Invalid JSON-RPC message.");
    const id = message.id;
    const reply = (body, status = 200) => { res.writeHead(status, { "content-type": "application/json" }); res.end(JSON.stringify(body)); };
    if (message.jsonrpc !== "2.0") { reply({ jsonrpc: "2.0", id: id ?? null, error: { code: -32600, message: "Invalid Request" } }, 400); return; }
    if (message.method === "notifications/initialized" || message.method.startsWith("notifications/")) { res.writeHead(202); res.end(); return; }
    if (message.method === "initialize") {
      reply({ jsonrpc: "2.0", id, result: { protocolVersion: VERSION, capabilities: { tools: { listChanged: false } }, serverInfo: { name: "terhux-termux", version: "1.0.0" }, instructions: "Executes commands on the owner's Termux phone. Use only for user-authorized work. The shell runs with the owner's permissions." } }); return;
    }
    if (message.method === "ping") { reply({ jsonrpc: "2.0", id, result: {} }); return; }
    if (message.method === "tools/list") { reply({ jsonrpc: "2.0", id, result: { tools } }); return; }
    if (message.method === "tools/call") {
      const name = message.params?.name;
      try { reply({ jsonrpc: "2.0", id, result: await callTool(name, message.params?.arguments || {}) }); }
      catch (e) { reply({ jsonrpc: "2.0", id, result: result(e?.message || String(e), true) }); }
      return;
    }
    reply({ jsonrpc: "2.0", id: id ?? null, error: { code: -32601, message: "Method not found" } }, 404);
  } catch (e) {
    res.writeHead(400, { "content-type": "application/json" }); res.end(JSON.stringify({ error: e?.message || String(e) }));
  }
});
server.listen(PORT, HOST, () => console.log("Terhux direct MCP listening on " + HOST + ":" + PORT));
process.on("SIGTERM", () => server.close(() => process.exit(0)));
process.on("SIGINT", () => server.close(() => process.exit(0)));
