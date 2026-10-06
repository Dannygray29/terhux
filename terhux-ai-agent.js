#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoDir = path.join(process.env.HOME || "", "terhux", "repo");
const inboxDir = path.join(repoDir, "ai-inbox");
const outboxDir = path.join(repoDir, "ai-outbox");
const taskDir = path.join(repoDir, "tasks");

for (const dir of [inboxDir, outboxDir, taskDir]) fs.mkdirSync(dir, { recursive: true });

const ALLOWED_ACTIONS = new Set([
  "project-inspect",
  "file-read",
  "file-write",
  "file-write-b64",
  "npm-test",
  "npm-build",
  "git-status",
  "git-diff"
]);

function usage() {
  console.log("Terhux AI Agent");
  console.log("");
  console.log("Environment:");
  console.log("  TERHUX_AI_BASE_URL   OpenAI-compatible /chat/completions endpoint");
  console.log("  TERHUX_AI_API_KEY    API key");
  console.log("  TERHUX_AI_MODEL      model name");
  console.log("  TERHUX_AI_POLL_SECONDS  polling interval (default 5)");
  console.log("");
  console.log("Usage:");
  console.log("  node terhux-ai-agent.js plan <project> <goal>");
  console.log("  node terhux-ai-agent.js run <project> <goal> [max-iterations]");
  console.log("  node terhux-ai-agent.js status <run-id>");
  console.log("  node terhux-ai-agent.js stop <run-id>");
}

function makeId(prefix) {
  return prefix + "-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function readKv(file) {
  const out = {};
  if (!fs.existsSync(file)) return out;
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    const i = line.indexOf("=");
    if (i > 0) out[line.slice(0, i)] = line.slice(i + 1);
  }
  return out;
}

function writeRunState(runId, values) {
  const file = path.join(taskDir, runId + ".agent");
  const previous = readKv(file);
  const merged = { ...previous, ...values, UPDATED: Math.floor(Date.now() / 1000) };
  fs.writeFileSync(file, Object.entries(merged).map(([k, v]) => k + "=" + String(v).replace(/\r?\n/g, " ")).join("\n") + "\n");
}

function getRunState(runId) {
  return readKv(path.join(taskDir, runId + ".agent"));
}

async function askModel(prompt) {
  const base = process.env.TERHUX_AI_BASE_URL;
  const key = process.env.TERHUX_AI_API_KEY;
  const model = process.env.TERHUX_AI_MODEL;
  if (!base || !key || !model) {
    throw new Error("Set TERHUX_AI_BASE_URL, TERHUX_AI_API_KEY and TERHUX_AI_MODEL.");
  }

  const system = [
    "You are the planning/evaluation layer for Terhux, a multi-project Android/Termux execution bridge.",
    "You never execute commands yourself.",
    "Return exactly one JSON object.",
    "Required keys: done, summary, action, path, content, reason, next_goal.",
    "done must be true when the requested goal is complete; otherwise false.",
    "When done is true, action/path/content may be empty strings.",
    "Allowed actions: project-inspect, file-read, file-write, file-write-b64, npm-test, npm-build, git-status, git-diff.",
    "Never request arbitrary shell commands, package-manager installs, credential access, or destructive operations.",
    "Keep file paths relative to the selected project and never use .. path traversal.",
    "Prefer inspection before modification and tests after modification.",
    "Only propose one next action at a time."
  ].join(" ");

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
        { role: "system", content: system },
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
  if (typeof plan.done !== "boolean") throw new Error("AI response missing boolean 'done'.");
  if (typeof plan.action !== "string") throw new Error("AI response missing 'action'.");
  if (!ALLOWED_ACTIONS.has(plan.action) && !plan.done) {
    throw new Error("AI proposed a disallowed action: " + plan.action);
  }
  return plan;
}

function createPendingTask(taskId, project, plan, goal) {
  const stateFile = path.join(taskDir, taskId + ".state");
  const pendingFile = path.join(taskDir, taskId + ".pending");
  if (fs.existsSync(stateFile) || fs.existsSync(pendingFile)) {
    throw new Error("Task already exists: " + taskId);
  }

  const state = [
    "ID=" + taskId,
    "PROJECT=" + project,
    "ACTION=" + plan.action,
    "STATUS=QUEUED",
    "APPROVAL=PENDING",
    "CREATED=" + Math.floor(Date.now() / 1000)
  ].join("\n") + "\n";

  const pending = [
    "ACTION=" + plan.action,
    "PROJECT=" + project,
    plan.path ? "PATH=" + plan.path : "",
    plan.content ? "CONTENT=" + plan.content : "",
    "APPROVED=false"
  ].filter(Boolean).join("\n") + "\n";

  fs.writeFileSync(stateFile, state);
  fs.writeFileSync(pendingFile, pending);

  const request = {
    id: taskId,
    project,
    goal,
    plan,
    status: "PENDING_APPROVAL",
    created: new Date().toISOString()
  };
  fs.writeFileSync(path.join(inboxDir, taskId + ".json"), JSON.stringify(request, null, 2));
  fs.writeFileSync(path.join(outboxDir, taskId + ".json"), JSON.stringify(request, null, 2));
}

function readResult(taskId) {
  const file = path.join(repoDir, "results", taskId + ".result");
  if (!fs.existsSync(file)) return null;
  const raw = fs.readFileSync(file, "utf8");
  const lines = raw.split(/\r?\n/);
  const result = {};
  let section = null;
  for (const line of lines) {
    if (line === "STDOUT_BEGIN") { section = "STDOUT"; result.STDOUT = ""; continue; }
    if (line === "STDOUT_END") { section = null; continue; }
    if (line === "STDERR_BEGIN") { section = "STDERR"; result.STDERR = ""; continue; }
    if (line === "STDERR_END") { section = null; continue; }
    if (section) result[section] += line + "\n";
    else {
      const i = line.indexOf("=");
      if (i > 0) result[line.slice(0, i)] = line.slice(i + 1);
    }
  }
  for (const key of ["STDOUT", "STDERR"]) {
    if (result[key]) result[key] = result[key].slice(-12000);
  }
  return result;
}

async function planOnce(project, goal, context, runId) {
  const prompt = [
    "Terhux run: " + runId,
    "Project: " + project,
    "Original goal: " + goal,
    "",
    context
  ].join("\n");

  const plan = await askModel(prompt);
  const taskId = makeId("ai-task");

  if (plan.done) return { plan, taskId: null };

  createPendingTask(taskId, project, plan, goal);
  return { plan, taskId };
}

async function runAgent(project, goal, maxIterations) {
  const runId = makeId("run");
  const limit = Math.max(1, Math.min(50, Number(maxIterations) || 10));

  writeRunState(runId, {
    ID: runId,
    PROJECT: project,
    STATUS: "PLANNING",
    GOAL: goal,
    ITERATION: 0,
    MAX_ITERATIONS: limit,
    CURRENT_TASK: "",
    CREATED: Math.floor(Date.now() / 1000)
  });

  let context = "No action has been taken yet. Inspect the project if necessary before changing anything.";

  for (let iteration = 1; iteration <= limit; iteration++) {
    const state = getRunState(runId);
    if (state.STATUS === "STOPPED") return;

    writeRunState(runId, { STATUS: "PLANNING", ITERATION: iteration });

    let result;
    try {
      result = await planOnce(project, goal, context, runId);
    } catch (err) {
      writeRunState(runId, { STATUS: "FAILED", ERROR: err.message });
      return;
    }

    if (result.plan.done) {
      writeRunState(runId, {
        STATUS: "DONE",
        CURRENT_TASK: "",
        SUMMARY: result.plan.summary || "Goal completed."
      });
      console.log(JSON.stringify({ runId, status: "DONE", plan: result.plan }, null, 2));
      return;
    }

    const taskId = result.taskId;
    writeRunState(runId, {
      STATUS: "WAITING_APPROVAL",
      CURRENT_TASK: taskId,
      ACTION: result.plan.action
    });

    console.log("AI proposed task: " + taskId);
    console.log("Approval required: ./terhux-task.sh approve " + taskId);

    while (true) {
      await sleep(Number(process.env.TERHUX_AI_POLL_SECONDS || 5) * 1000);
      const runState = getRunState(runId);
      if (runState.STATUS === "STOPPED") {
        console.log("AI run stopped: " + runId);
        return;
      }

      const taskState = readKv(path.join(taskDir, taskId + ".state"));
      if (taskState.STATUS === "REJECTED" || taskState.APPROVAL === "REJECTED") {
        writeRunState(runId, { STATUS: "FAILED", ERROR: "Task rejected: " + taskId });
        return;
      }
      if (taskState.STATUS === "CANCELLED") {
        writeRunState(runId, { STATUS: "FAILED", ERROR: "Task cancelled: " + taskId });
        return;
      }

      const resultFile = path.join(repoDir, "results", taskId + ".result");
      if (!fs.existsSync(resultFile)) continue;

      const execution = readResult(taskId);
      const status = execution?.STATUS || taskState.STATUS || "ERROR";
      writeRunState(runId, { STATUS: "EVALUATING" });

      context = [
        "Previous AI plan:",
        JSON.stringify(result.plan),
        "",
        "Execution status: " + status,
        "Exit code: " + (execution?.EXIT_CODE || taskState.EXIT_CODE || "unknown"),
        "",
        "STDOUT:",
        execution?.STDOUT || "(none)",
        "",
        "STDERR:",
        execution?.STDERR || "(none)",
        "",
        "Evaluate the result against the original goal. If incomplete or failed, choose the safest next action. If complete, set done=true."
      ].join("\n");

      break;
    }
  }

  writeRunState(runId, { STATUS: "FAILED", ERROR: "Maximum iterations reached." });
  console.log("Maximum iterations reached for " + runId);
}

async function main() {
  const [cmd, ...args] = process.argv.slice(2);

  if (cmd === "plan") {
    const [project, ...goalParts] = args;
    if (!project || goalParts.length === 0) { usage(); process.exit(2); }
    const goal = goalParts.join(" ");
    const taskId = makeId("ai-task");
    const plan = await askModel("Project: " + project + "\nGoal: " + goal + "\nChoose the safest next Terhux action. If inspection is needed, choose project-inspect first.");
    if (plan.done) {
      console.log(JSON.stringify({ status: "DONE", plan }, null, 2));
      return;
    }
    createPendingTask(taskId, project, plan, goal);
    console.log(JSON.stringify({ id: taskId, project, goal, plan, status: "PENDING_APPROVAL" }, null, 2));
    console.log("\nApproval required: ./terhux-task.sh approve " + taskId);
    return;
  }

  if (cmd === "run") {
    const [project, ...rest] = args;
    if (!project || rest.length === 0) { usage(); process.exit(2); }
    const maybeLimit = rest[rest.length - 1];
    const hasLimit = /^\d+$/.test(maybeLimit);
    const maxIterations = hasLimit ? Number(maybeLimit) : 10;
    const goal = (hasLimit ? rest.slice(0, -1) : rest).join(" ");
    await runAgent(project, goal, maxIterations);
    return;
  }

  if (cmd === "status") {
    const runId = args[0];
    if (!runId) { usage(); process.exit(2); }
    console.log(JSON.stringify(getRunState(runId), null, 2));
    return;
  }

  if (cmd === "stop") {
    const runId = args[0];
    if (!runId) { usage(); process.exit(2); }
    const state = getRunState(runId);
    if (!state.ID) { console.error("Run not found: " + runId); process.exit(1); }
    writeRunState(runId, { STATUS: "STOPPED" });
    console.log("Stopped AI run: " + runId);
    return;
  }

  usage();
  process.exit(2);
}

main().catch(err => {
  console.error("Terhux AI Agent error:", err.message);
  process.exit(1);
});
