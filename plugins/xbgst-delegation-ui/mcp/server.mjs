#!/usr/bin/env node

import { spawn } from "node:child_process";
import { readFile, realpath, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SERVER_NAME = "xbgst-delegation";
const SERVER_VERSION = "1.0.0";
const UI_URI = "ui://xbgst/delegation.html";
const UI_MIME = "text/html;profile=mcp-app";
const UI_PATH = fileURLToPath(new URL("../ui/delegation.html", import.meta.url));
const XASK_BIN = process.env.XASK_BIN || "xask";

const PROVIDERS = new Set(["chatgpt", "grok", "token-plan", "local"]);
const EFFORTS = new Set(["low", "medium", "high", "xhigh", "max", "ultra"]);
const SUBSTRATES = new Set(["stock", "sekhmet"]);
const TIERS = new Set(["default", "fast"]);
const MODEL_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$/;
const GODSPEED_SUFFIX = "| godspeed";
const GODSPEED_TAIL_RE = /(?:\s*\|\s*godspeed)+\s*$/iu;
const MAX_TASK_CHARS = 32_768;
const MAX_OUTPUT_BYTES = boundedInteger(process.env.XASK_MCP_MAX_OUTPUT_BYTES, 1_048_576, 16_384, 4_194_304);
const CATALOG_TIMEOUT_MS = boundedInteger(process.env.XASK_MCP_CATALOG_TIMEOUT_MS, 15_000, 1_000, 60_000);
const PLAN_TIMEOUT_MS = boundedInteger(process.env.XASK_MCP_PLAN_TIMEOUT_MS, 30_000, 1_000, 120_000);
const DISPATCH_TIMEOUT_MS = boundedInteger(process.env.XASK_MCP_DISPATCH_TIMEOUT_MS, 600_000, 1_000, 900_000);

let uiHtmlPromise;

function boundedInteger(raw, fallback, min, max) {
  const parsed = Number.parseInt(raw ?? "", 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function assertOnlyKeys(value, allowed) {
  if (!plainObject(value)) throw new Error("arguments must be an object");
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) throw new Error(`unknown argument '${key}'`);
  }
}

function requiredString(value, label, maxLength) {
  if (typeof value !== "string") throw new Error(`${label} must be a string`);
  if (value.includes("\0")) throw new Error(`${label} cannot contain NUL bytes`);
  if (!value.trim()) throw new Error(`${label} cannot be empty`);
  if (value.length > maxLength) throw new Error(`${label} exceeds ${maxLength} characters`);
  return value;
}

function enumValue(value, label, allowed, fallback) {
  const resolved = value === undefined ? fallback : value;
  if (typeof resolved !== "string" || !allowed.has(resolved)) {
    throw new Error(`${label} must be one of: ${[...allowed].join(", ")}`);
  }
  return resolved;
}

function canonicalGodspeedTask(value) {
  const withoutTerminalMarkers = value.trimEnd().replace(GODSPEED_TAIL_RE, "").trimEnd();
  if (!withoutTerminalMarkers) {
    throw new Error("task must contain delegation content before '| godspeed'");
  }
  const task = `${withoutTerminalMarkers} ${GODSPEED_SUFFIX}`;
  if (task.length > MAX_TASK_CHARS) {
    throw new Error(`task exceeds ${MAX_TASK_CHARS} characters after adding '${GODSPEED_SUFFIX}'`);
  }
  return task;
}

async function validatedWorkingDirectory(value) {
  if (value === undefined) return undefined;
  const candidate = requiredString(value, "workingDirectory", 4_096);
  if (!path.isAbsolute(candidate)) throw new Error("workingDirectory must be an absolute path");
  let resolved;
  let details;
  try {
    resolved = await realpath(candidate);
    details = await stat(resolved);
  } catch {
    throw new Error("workingDirectory must name an existing directory");
  }
  if (!details.isDirectory()) throw new Error("workingDirectory must name an existing directory");
  return resolved;
}

function terminateChild(child) {
  if (!child.pid) return;
  try {
    if (process.platform !== "win32") process.kill(-child.pid, "SIGTERM");
    else child.kill("SIGTERM");
  } catch {
    try { child.kill("SIGTERM"); } catch { /* already gone */ }
  }
}

function forceKillChild(child) {
  if (!child.pid) return;
  try {
    if (process.platform !== "win32") process.kill(-child.pid, "SIGKILL");
    else child.kill("SIGKILL");
  } catch {
    try { child.kill("SIGKILL"); } catch { /* already gone */ }
  }
}

function runXask(argv, { cwd, timeoutMs }) {
  return new Promise((resolve) => {
    const child = spawn(XASK_BIN, argv, {
      cwd,
      env: process.env,
      shell: false,
      detached: process.platform !== "win32",
      stdio: ["ignore", "pipe", "pipe"],
    });

    const stdout = [];
    const stderr = [];
    let capturedBytes = 0;
    let timedOut = false;
    let outputLimitHit = false;
    let spawnError;
    let finished = false;
    let forceTimer;

    const capture = (target, chunk) => {
      if (outputLimitHit) return;
      const remaining = MAX_OUTPUT_BYTES - capturedBytes;
      if (remaining > 0) {
        const slice = chunk.length <= remaining ? chunk : chunk.subarray(0, remaining);
        target.push(slice);
        capturedBytes += slice.length;
      }
      if (chunk.length > remaining) {
        outputLimitHit = true;
        terminateChild(child);
        forceTimer = setTimeout(() => forceKillChild(child), 2_000);
      }
    };

    child.stdout.on("data", (chunk) => capture(stdout, chunk));
    child.stderr.on("data", (chunk) => capture(stderr, chunk));
    child.once("error", (error) => { spawnError = error; });

    const timeout = setTimeout(() => {
      timedOut = true;
      terminateChild(child);
      forceTimer = setTimeout(() => forceKillChild(child), 2_000);
    }, timeoutMs);

    child.once("close", (code, signal) => {
      if (finished) return;
      finished = true;
      clearTimeout(timeout);
      clearTimeout(forceTimer);
      resolve({
        code,
        signal,
        stdout: Buffer.concat(stdout).toString("utf8"),
        stderr: Buffer.concat(stderr).toString("utf8"),
        timedOut,
        outputLimitHit,
        spawnError,
      });
    });
  });
}

function executionError(prefix, result) {
  if (result.spawnError) return `${prefix}: could not start xask (${result.spawnError.code || "spawn failed"})`;
  if (result.timedOut) return `${prefix}: xask exceeded the time limit`;
  if (result.outputLimitHit) return `${prefix}: xask exceeded the ${MAX_OUTPUT_BYTES}-byte output limit`;
  const detail = result.stderr.trim() || result.stdout.trim() || `exit ${result.code}`;
  return `${prefix}: ${detail}`;
}

function parseJsonOutput(result, label) {
  if (result.spawnError || result.timedOut || result.outputLimitHit || result.code !== 0) {
    throw new Error(executionError(label, result));
  }
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(`${label}: xask returned invalid JSON`);
  }
}

function validateCatalog(catalog) {
  if (!plainObject(catalog) || !Array.isArray(catalog.providers) || !Array.isArray(catalog.models)) {
    throw new Error("xask catalog has an unsupported shape");
  }
  return catalog;
}

async function loadCatalog(cwd) {
  const result = await runXask(["catalog", "--json"], { cwd, timeoutMs: CATALOG_TIMEOUT_MS });
  return validateCatalog(parseJsonOutput(result, "catalog failed"));
}

function findProvider(catalog, providerId) {
  return catalog.providers.find((provider) => plainObject(provider) && provider.id === providerId);
}

function findModel(catalog, providerId, modelId) {
  return catalog.models.find((model) => plainObject(model)
    && model.provider === providerId
    && model.model_id === modelId);
}

function validateSelection(raw, catalog, { requireAvailable = false } = {}) {
  const provider = enumValue(raw.provider, "provider", PROVIDERS);
  const model = requiredString(raw.model, "model", 128);
  if (!MODEL_ID_RE.test(model)) throw new Error("model contains unsupported characters");
  const effort = enumValue(raw.effort, "effort", EFFORTS);
  const substrate = enumValue(raw.substrate, "substrate", SUBSTRATES, "stock");
  const tier = enumValue(raw.tier, "tier", TIERS, "default");
  const rawTask = requiredString(raw.task, "task", MAX_TASK_CHARS);
  const godspeed = raw.godspeed === undefined ? true : raw.godspeed;
  if (typeof godspeed !== "boolean") throw new Error("godspeed must be a boolean");
  if (!godspeed) {
    throw new Error("godspeed=false is unsupported: every xask delegation must load directive.md with --gs");
  }
  const task = canonicalGodspeedTask(rawTask);

  const providerEntry = findProvider(catalog, provider);
  if (!providerEntry) throw new Error(`provider '${provider}' is not present in the xask catalog`);
  const modelEntry = findModel(catalog, provider, model);
  if (!modelEntry) throw new Error(`model '${model}' is not registered for provider '${provider}'`);

  const supportedEfforts = Array.isArray(modelEntry.supported_efforts) ? modelEntry.supported_efforts : [];
  if (!supportedEfforts.includes(effort)) {
    throw new Error(`effort '${effort}' is not supported by '${model}'`);
  }
  const serviceTiers = Array.isArray(modelEntry.service_tiers) ? modelEntry.service_tiers : ["default"];
  if (!serviceTiers.includes(tier)) throw new Error(`tier '${tier}' is not supported by '${model}'`);

  const transports = Array.isArray(providerEntry.transports) ? providerEntry.transports : ["stock"];
  if (!transports.includes(substrate)) {
    throw new Error(`substrate '${substrate}' is not supported by provider '${provider}'`);
  }
  if (substrate === "sekhmet" && provider !== "chatgpt") {
    throw new Error("the sekhmet substrate is available only for chatgpt");
  }
  if (plainObject(modelEntry.substrate_available) && modelEntry.substrate_available[substrate] === false) {
    throw new Error(`substrate '${substrate}' is not available for '${model}'`);
  }
  if (requireAvailable && (providerEntry.available === false || modelEntry.available === false)) {
    throw new Error(`'${model}' is not available in the current xask runtime`);
  }

  return { provider, model, effort, substrate, tier, task, godspeed };
}

function selectionArgv(selection, { plan = false } = {}) {
  const argv = [];
  if (plan) argv.push("plan");
  argv.push(
    "--provider", selection.provider,
    "--substrate", selection.substrate,
    "--model-id", selection.model,
    "--effort", selection.effort,
    "--service-tier", selection.tier,
  );
  argv.push("--gs");
  if (plan) argv.push("--json");
  argv.push("--", selection.task);
  return argv;
}

function publicRequest(selection, workingDirectory) {
  return {
    provider: selection.provider,
    model: selection.model,
    effort: selection.effort,
    substrate: selection.substrate,
    tier: selection.tier,
    godspeed: selection.godspeed,
    ...(workingDirectory ? { workingDirectory } : {}),
  };
}

const selectionProperties = {
  provider: {
    type: "string",
    enum: [...PROVIDERS],
    description: "Provider route from the live xask catalog.",
  },
  model: {
    type: "string",
    minLength: 1,
    maxLength: 128,
    description: "Exact model_id from xask_catalog.",
  },
  effort: {
    type: "string",
    enum: [...EFFORTS],
    description: "Reasoning effort supported by the selected model.",
  },
  substrate: {
    type: "string",
    enum: [...SUBSTRATES],
    default: "stock",
    description: "Execution substrate. Sekhmet is available only for compatible ChatGPT routes.",
  },
  tier: {
    type: "string",
    enum: [...TIERS],
    default: "default",
    description: "Service tier advertised by the selected model.",
  },
  task: {
    type: "string",
    minLength: 1,
    maxLength: MAX_TASK_CHARS,
    description: "Delegation task passed to xask as one literal argument.",
  },
  godspeed: {
    type: "boolean",
    const: true,
    default: true,
    description: "Required invariant: load canonical Godspeed directive.md with --gs; the server also makes the task end exactly once with '| godspeed'.",
  },
  workingDirectory: {
    type: "string",
    minLength: 1,
    maxLength: 4_096,
    description: "Optional existing absolute directory in which xask runs.",
  },
};

const widgetMeta = {
  ui: { resourceUri: UI_URI },
  "openai/outputTemplate": UI_URI,
  "openai/widgetAccessible": true,
  "openai/toolInvocation/invoking": "Routing through xask…",
  "openai/toolInvocation/invoked": "xask route ready",
};

const tools = [
  {
    name: "xask_catalog",
    title: "Load xask model catalog",
    description: "Read the local xask provider/model/effort catalog and runtime availability. Does not dispatch a model.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
    _meta: widgetMeta,
  },
  {
    name: "xask_plan",
    title: "Preview an xask delegation",
    description: "Validate a provider/model/effort selection against the live catalog and return the exact xask argv without executing. The route always includes --gs and one terminal '| godspeed'.",
    inputSchema: {
      type: "object",
      properties: selectionProperties,
      required: ["provider", "model", "effort", "task"],
      additionalProperties: false,
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
    _meta: widgetMeta,
  },
  {
    name: "xask_dispatch",
    title: "Dispatch through xask",
    description: "Execute one explicit, validated xask delegation in an optional absolute working directory. The route always includes --gs and one terminal '| godspeed'. This may use remote providers and may change workspace files.",
    inputSchema: {
      type: "object",
      properties: selectionProperties,
      required: ["provider", "model", "effort", "task"],
      additionalProperties: false,
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
      openWorldHint: true,
    },
    _meta: {
      ...widgetMeta,
      "openai/toolInvocation/invoking": "Dispatching through xask…",
      "openai/toolInvocation/invoked": "xask dispatch finished",
    },
  },
];

async function catalogTool(args) {
  assertOnlyKeys(args, new Set());
  const catalog = await loadCatalog();
  const available = catalog.models.filter((model) => plainObject(model) && model.available !== false).length;
  return {
    content: [{ type: "text", text: `Loaded ${catalog.models.length} xask models (${available} currently available).` }],
    structuredContent: { kind: "catalog", catalog },
  };
}

async function planTool(args) {
  const allowed = new Set(["provider", "model", "effort", "substrate", "tier", "task", "godspeed", "workingDirectory"]);
  assertOnlyKeys(args, allowed);
  const workingDirectory = await validatedWorkingDirectory(args.workingDirectory);
  const catalog = await loadCatalog(workingDirectory);
  const selection = validateSelection(args, catalog);
  const result = await runXask(selectionArgv(selection, { plan: true }), {
    cwd: workingDirectory,
    timeoutMs: PLAN_TIMEOUT_MS,
  });
  const plan = parseJsonOutput(result, "plan failed");
  if (!plainObject(plan) || !Array.isArray(plan.argv) || plan.executes !== false) {
    throw new Error("plan failed: xask returned an unsupported plan shape");
  }
  return {
    content: [{ type: "text", text: typeof plan.command === "string" ? plan.command : "xask plan ready" }],
    structuredContent: {
      kind: "plan",
      catalog,
      request: publicRequest(selection, workingDirectory),
      plan,
    },
  };
}

async function dispatchTool(args) {
  const allowed = new Set(["provider", "model", "effort", "substrate", "tier", "task", "godspeed", "workingDirectory"]);
  assertOnlyKeys(args, allowed);
  const workingDirectory = await validatedWorkingDirectory(args.workingDirectory);
  const catalog = await loadCatalog(workingDirectory);
  const selection = validateSelection(args, catalog, { requireAvailable: true });
  const result = await runXask(selectionArgv(selection), {
    cwd: workingDirectory,
    timeoutMs: DISPATCH_TIMEOUT_MS,
  });
  const failed = Boolean(result.spawnError || result.timedOut || result.outputLimitHit || result.code !== 0);
  const stdout = result.stdout.trim();
  const stderr = result.stderr.trim();
  const summary = failed
    ? executionError("dispatch failed", result)
    : (stdout || "xask dispatch completed successfully");
  return {
    content: [{ type: "text", text: summary }],
    structuredContent: {
      kind: "dispatch",
      catalog,
      request: publicRequest(selection, workingDirectory),
      exitCode: result.code,
      signal: result.signal,
      stdout,
      stderr,
      timedOut: result.timedOut,
      outputLimitHit: result.outputLimitHit,
    },
    ...(failed ? { isError: true } : {}),
  };
}

async function callTool(name, args) {
  if (name === "xask_catalog") return catalogTool(args);
  if (name === "xask_plan") return planTool(args);
  if (name === "xask_dispatch") return dispatchTool(args);
  throw new Error(`unknown tool '${name}'`);
}

function toolError(error) {
  return {
    content: [{ type: "text", text: error instanceof Error ? error.message : "tool call failed" }],
    isError: true,
  };
}

async function uiHtml() {
  uiHtmlPromise ||= readFile(UI_PATH, "utf8");
  return uiHtmlPromise;
}

function send(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

function result(id, value) {
  send({ jsonrpc: "2.0", id, result: value });
}

function rpcError(id, code, message) {
  send({ jsonrpc: "2.0", id, error: { code, message } });
}

async function handleMessage(message) {
  if (!plainObject(message) || message.jsonrpc !== "2.0" || typeof message.method !== "string") {
    if (message?.id !== undefined) rpcError(message.id, -32600, "Invalid Request");
    return;
  }
  if (message.id === undefined) return;

  try {
    switch (message.method) {
      case "initialize": {
        const requested = message.params?.protocolVersion;
        result(message.id, {
          protocolVersion: typeof requested === "string" ? requested : "2025-06-18",
          capabilities: {
            tools: { listChanged: false },
            resources: { subscribe: false, listChanged: false },
          },
          serverInfo: { name: SERVER_NAME, version: SERVER_VERSION },
          instructions: "Use xask_catalog first, xask_plan to preview, and xask_dispatch only after the user explicitly chooses Dispatch. Every planned and executed delegation is Godspeed-locked: --gs plus one terminal '| godspeed'.",
        });
        break;
      }
      case "ping":
        result(message.id, {});
        break;
      case "tools/list":
        result(message.id, { tools });
        break;
      case "tools/call": {
        const name = message.params?.name;
        const args = message.params?.arguments ?? {};
        if (typeof name !== "string") {
          result(message.id, toolError(new Error("tool name is required")));
          break;
        }
        try {
          result(message.id, await callTool(name, args));
        } catch (error) {
          result(message.id, toolError(error));
        }
        break;
      }
      case "resources/list":
        result(message.id, {
          resources: [{
            uri: UI_URI,
            name: "xbgst-delegation",
            title: "XBGST Delegation Console",
            description: "Burnerchrome-style visual router for xask providers, models, effort, service tier, and substrate.",
            mimeType: UI_MIME,
            _meta: {
              ui: {
                csp: { connectDomains: [], resourceDomains: [] },
                prefersBorder: true,
              },
              "openai/widgetDescription": "Preview and explicitly dispatch a validated local xask route.",
              "openai/widgetPrefersBorder": true,
              "openai/widgetCSP": { connect_domains: [], resource_domains: [] },
            },
          }],
        });
        break;
      case "resources/templates/list":
        result(message.id, { resourceTemplates: [] });
        break;
      case "resources/read": {
        if (message.params?.uri !== UI_URI) {
          rpcError(message.id, -32002, "Resource not found");
          break;
        }
        result(message.id, {
          contents: [{
            uri: UI_URI,
            mimeType: UI_MIME,
            text: await uiHtml(),
            _meta: {
              "openai/widgetDescription": "Preview and explicitly dispatch a validated local xask route.",
              "openai/widgetPrefersBorder": true,
              "openai/widgetCSP": { connect_domains: [], resource_domains: [] },
            },
          }],
        });
        break;
      }
      default:
        rpcError(message.id, -32601, "Method not found");
    }
  } catch (error) {
    rpcError(message.id, -32603, error instanceof Error ? error.message : "Internal error");
  }
}

let inputBuffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  inputBuffer += chunk;
  let newline;
  while ((newline = inputBuffer.indexOf("\n")) !== -1) {
    const line = inputBuffer.slice(0, newline).trim();
    inputBuffer = inputBuffer.slice(newline + 1);
    if (!line) continue;
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      rpcError(null, -32700, "Parse error");
      continue;
    }
    void handleMessage(message);
  }
});

process.stdin.on("end", () => {
  const line = inputBuffer.trim();
  if (line) {
    try { void handleMessage(JSON.parse(line)); }
    catch { rpcError(null, -32700, "Parse error"); }
  }
});
