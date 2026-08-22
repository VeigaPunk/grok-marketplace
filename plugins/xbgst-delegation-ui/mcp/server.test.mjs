import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { access, mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const serverPath = path.join(here, "server.mjs");
const fakeXaskPath = path.join(here, "test", "fixtures", "fake-xask.mjs");

class RpcClient {
  constructor(child) {
    this.child = child;
    this.nextId = 1;
    this.pending = new Map();
    this.stderr = "";
    let buffer = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      buffer += chunk;
      let newline;
      while ((newline = buffer.indexOf("\n")) !== -1) {
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        if (!line) continue;
        const message = JSON.parse(line);
        const waiter = this.pending.get(message.id);
        if (waiter) {
          this.pending.delete(message.id);
          if (message.error) waiter.reject(new Error(message.error.message));
          else waiter.resolve(message.result);
        }
      }
    });
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk) => { this.stderr += chunk; });
    child.on("exit", (code) => {
      for (const waiter of this.pending.values()) waiter.reject(new Error(`server exited ${code}: ${this.stderr}`));
      this.pending.clear();
    });
  }

  call(method, params = {}) {
    const id = this.nextId++;
    const promise = new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    return promise;
  }

  notify(method, params = {}) {
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
  }

  close() {
    this.child.stdin.end();
  }
}

async function doesNotExist(candidate) {
  try {
    await access(candidate);
    return false;
  } catch {
    return true;
  }
}

test("stdio MCP exposes the widget and keeps xask argv literal", async (t) => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "xbgst-mcp-test-"));
  const capturePath = path.join(tempRoot, "argv.ndjson");
  const injectedPath = path.join(tempRoot, "should-not-exist");
  const injectedSubshellPath = path.join(tempRoot, "also-should-not-exist");
  const child = spawn(process.execPath, [serverPath], {
    env: {
      ...process.env,
      XASK_BIN: fakeXaskPath,
      XASK_CAPTURE_PATH: capturePath,
      XASK_MCP_CATALOG_TIMEOUT_MS: "3000",
      XASK_MCP_PLAN_TIMEOUT_MS: "3000",
      XASK_MCP_DISPATCH_TIMEOUT_MS: "3000",
    },
    stdio: ["pipe", "pipe", "pipe"],
  });
  const client = new RpcClient(child);
  t.after(async () => {
    client.close();
    if (child.exitCode === null) child.kill("SIGTERM");
    await rm(tempRoot, { recursive: true, force: true });
  });

  const initialized = await client.call("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "offline-test", version: "1" },
  });
  assert.equal(initialized.serverInfo.name, "xbgst-delegation");
  client.notify("notifications/initialized");

  const listed = await client.call("tools/list");
  assert.deepEqual(listed.tools.map((tool) => tool.name), ["xask_catalog", "xask_plan", "xask_dispatch"]);
  assert.equal(listed.tools[0].annotations.readOnlyHint, true);
  assert.equal(listed.tools[2].annotations.openWorldHint, true);
  assert.equal(listed.tools[2].annotations.destructiveHint, true);
  assert.equal(listed.tools[1].inputSchema.properties.godspeed.const, true);
  assert.equal(listed.tools[1].inputSchema.properties.godspeed.default, true);

  const resources = await client.call("resources/list");
  assert.equal(resources.resources[0].uri, "ui://xbgst/delegation.html");
  assert.equal(resources.resources[0].mimeType, "text/html;profile=mcp-app");
  const resource = await client.call("resources/read", { uri: "ui://xbgst/delegation.html" });
  assert.match(resource.contents[0].text, /Choose the mind\. Set the depth\./);
  assert.match(resource.contents[0].text, /window\.openai/);
  assert.match(resource.contents[0].text, /directive\.md · locked/);
  assert.match(resource.contents[0].text, /WWKD remains a separate planning skill/);

  const taskBody = `review this; touch ${injectedPath}; $(touch ${injectedSubshellPath})`;
  const task = `${taskBody} | godspeed | godspeed  `;
  const canonicalTask = `${taskBody} | godspeed`;
  const selection = {
    provider: "chatgpt",
    model: "gpt-5.6-sol",
    effort: "high",
    substrate: "stock",
    tier: "fast",
    task,
    godspeed: true,
  };
  const planned = await client.call("tools/call", { name: "xask_plan", arguments: selection });
  assert.equal(planned.isError, undefined);
  assert.equal(planned.structuredContent.kind, "plan");
  assert.equal(planned.structuredContent.plan.executes, false);

  const dispatched = await client.call("tools/call", {
    name: "xask_dispatch",
    arguments: { ...selection, workingDirectory: tempRoot },
  });
  assert.equal(dispatched.isError, undefined);
  assert.equal(dispatched.structuredContent.kind, "dispatch");
  assert.equal(dispatched.structuredContent.exitCode, 0);
  assert.match(dispatched.structuredContent.stdout, /fake dispatch complete/);
  assert.equal(await doesNotExist(injectedPath), true);
  assert.equal(await doesNotExist(injectedSubshellPath), true);

  const captures = (await readFile(capturePath, "utf8")).trim().split("\n").map(JSON.parse);
  assert.equal(captures.length, 4);
  assert.deepEqual(captures[0].argv, ["catalog", "--json"]);
  assert.deepEqual(captures[1].argv, [
    "plan", "--provider", "chatgpt", "--substrate", "stock", "--model-id", "gpt-5.6-sol",
    "--effort", "high", "--service-tier", "fast", "--gs", "--json", "--", canonicalTask,
  ]);
  assert.deepEqual(captures[2].argv, ["catalog", "--json"]);
  assert.deepEqual(captures[3].argv, [
    "--provider", "chatgpt", "--substrate", "stock", "--model-id", "gpt-5.6-sol",
    "--effort", "high", "--service-tier", "fast", "--gs", "--", canonicalTask,
  ]);
  assert.equal(captures[1].argv.at(-1).match(/\| godspeed/g)?.length, 1);
  assert.equal(captures[3].argv.at(-1).match(/\| godspeed/g)?.length, 1);
  assert.match(captures[1].argv.at(-1), / \| godspeed$/);
  assert.match(captures[3].argv.at(-1), / \| godspeed$/);
  assert.equal(captures[2].cwd, tempRoot);
  assert.equal(captures[3].cwd, tempRoot);

  const rejected = await client.call("tools/call", {
    name: "xask_dispatch",
    arguments: { ...selection, task: taskBody, godspeed: false },
  });
  assert.equal(rejected.isError, true);
  assert.match(rejected.content[0].text, /godspeed=false is unsupported/);

  const forced = await client.call("tools/call", {
    name: "xask_plan",
    arguments: { ...selection, task: taskBody, godspeed: undefined },
  });
  assert.equal(forced.isError, undefined);

  const finalCaptures = (await readFile(capturePath, "utf8")).trim().split("\n").map(JSON.parse);
  assert.equal(finalCaptures.length, 7);
  assert.deepEqual(finalCaptures[4].argv, ["catalog", "--json"]);
  assert.deepEqual(finalCaptures[5].argv, ["catalog", "--json"]);
  assert.deepEqual(finalCaptures[6].argv, [
    "plan", "--provider", "chatgpt", "--substrate", "stock", "--model-id", "gpt-5.6-sol",
    "--effort", "high", "--service-tier", "fast", "--gs", "--json", "--", canonicalTask,
  ]);
});
