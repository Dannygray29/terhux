#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoDir = path.join(process.env.HOME || "", "terhux", "repo");
const inboxDir = path.join(repoDir, "ai-inbox");
const outboxDir = path.join(repoDir, "ai-outbox");
fs.mkdirSync(inboxDir, { recursive: true });
fs.mkdirSync(outboxDir, { recursive: true });

function usage() {
  console.log("Terhux AI Agent adapter");
  console.log("");
  console.log("Environment:");
  console.log("  TERHUX_AI_BASE_URL   OpenAI-compatible /chat/completions endpoint");
  console.log("  TERHUX_AI_API_KEY    API key");
  console.log("  TERHUX_AI_MODEL      model name");
  console.log("");
  console.log("Usage:");
  console.log("  node terhux-ai-agent.js plan <project> <goal>");
  console.log("  node terhux-ai-agent.js status <request-id>");
}

function id() {
  return "ai-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8);
}

async function askModel(prompt) {
  const base = process.env.TERHUX_AI_BASE_URL;
  const key = process.env.TERHUX_AI_API_KEY;
  const model = process.env.TERHUX_AI_MODEL;
  if (!base || !key || !model) {
    throw new Error("Set TERHUX_AI_BASE_URL, TERHUX_AI_API_KEY and TERHUX_AI_MODEL.");
  }
  const res = await fetch(base.replace(/\/$/, "") + "/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer " + key
    },
    body: JSON.stringify({
      model,
      temperature: 0.1,
      messages: [
        {
          role: "system",
          content: "You are the planning layer for Terhux, a multi-project Android/Termux execution bridge. Do not execute commands. Return exactly one JSON object with keys: action, path, content, reason. Allowed actions: project-inspect, file-read, file-write, file-write-b64, npm-test, npm-build, git-status, git-diff. Never request arbitrary shell commands. Keep file paths relative to the selected project."
        },
        { role: "user", content: prompt }
      ]
    })
  });
  if (!res.ok) throw new Error("AI HTTP " + res.status + ": " + await res.text());
  const data = await res.json();
  const text = data?.choices?.[0]?.message?.content;
  if (!text) throw new Error("AI response did not contain message content.");
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) throw new Error("AI response was not valid JSON: " + text);
  const plan = JSON.parse(match[0]);
  const allowed = new Set(["project-inspect","file-read","file-write","file-write-b64","npm-test","npm-build","git-status","git-diff"]);
  if (!allowed.has(plan.action)) throw new Error("AI proposed a disallowed action: " + plan.action);
  return plan;
}

async function main() {
  const [cmd, project, ...goalParts] = process.argv.slice(2);
  if (cmd !== "plan" || !project || goalParts.length === 0) {
    usage();
    process.exit(2);
  }
  const goal = goalParts.join(" ");
  const requestId = id();
  const prompt = "Project: " + project + "\nGoal: " + goal + "\nChoose the safest next Terhux action. If inspection is needed, choose project-inspect first.";
  const plan = await askModel(prompt);

  const request = {
    id: requestId,
    project,
    goal,
    plan,
    status: "PENDING_APPROVAL",
    created: new Date().toISOString()
  };
  const taskDir = path.join(repoDir, "tasks");
  const commandDir = path.join(repoDir, "commands");
  fs.mkdirSync(taskDir, { recursive: true });
  fs.mkdirSync(commandDir, { recursive: true });
  const state = [
    "ID=" + requestId,
    "PROJECT=" + project,
    "ACTION=" + plan.action,
    "STATUS=QUEUED",
    "APPROVAL=PENDING",
    "CREATED=" + Math.floor(Date.now() / 1000)
  ].join("\\n") + "\\n";
  const pending = [
    "ACTION=" + plan.action,
    "PROJECT=" + project,
    plan.path ? "PATH=" + plan.path : "",
    plan.content ? "CONTENT=" + plan.content : "",
    "APPROVED=false"
  ].filter(Boolean).join("\\n") + "\\n";
  fs.writeFileSync(path.join(taskDir, requestId + ".state"), state);
  fs.writeFileSync(path.join(taskDir, requestId + ".pending"), pending);
  fs.writeFileSync(path.join(inboxDir, requestId + ".json"), JSON.stringify(request, null, 2));
  fs.writeFileSync(path.join(outboxDir, requestId + ".json"), JSON.stringify(request, null, 2));
  console.log(JSON.stringify(request, null, 2));
  console.log("\\nApproval required: ./terhux-task.sh approve " + requestId);
}

main().catch(err => {
  console.error("Terhux AI Agent error:", err.message);
  process.exit(1);
});
