#!/usr/bin/env node

import { appendFileSync } from "node:fs";

const argv = process.argv.slice(2);
const capturePath = process.env.XASK_CAPTURE_PATH;
if (capturePath) appendFileSync(capturePath, `${JSON.stringify({ argv, cwd: process.cwd() })}\n`);

const catalog = {
  schema_version: 1,
  providers: [{
    id: "chatgpt",
    label: "OpenAI / ChatGPT",
    default_model_id: "gpt-5.6-sol",
    transports: ["stock", "sekhmet"],
    available: true,
  }],
  models: [{
    provider: "chatgpt",
    model_id: "gpt-5.6-sol",
    display_name: "GPT-5.6-Sol",
    supported_efforts: ["low", "medium", "high", "xhigh", "max", "ultra"],
    default_effort: "low",
    service_tiers: ["default", "fast"],
    transports: ["stock", "sekhmet"],
    substrate_available: { stock: true, sekhmet: true },
    visible: true,
    available: true,
  }],
};

if (argv[0] === "catalog") {
  process.stdout.write(`${JSON.stringify(catalog)}\n`);
  process.exit(0);
}

if (argv[0] === "plan") {
  process.stdout.write(`${JSON.stringify({
    schema_version: 1,
    selection: {
      provider: argv[argv.indexOf("--provider") + 1],
      substrate: argv[argv.indexOf("--substrate") + 1],
      model_id: argv[argv.indexOf("--model-id") + 1],
      effort: argv[argv.indexOf("--effort") + 1],
      service_tier: argv[argv.indexOf("--service-tier") + 1],
    },
    argv: ["xask", ...argv.slice(1).filter((value) => value !== "--json")],
    command: ["xask", ...argv.slice(1).filter((value) => value !== "--json")].map(JSON.stringify).join(" "),
    executes: false,
  })}\n`);
  process.exit(0);
}

const separator = argv.indexOf("--");
const task = separator === -1 ? "" : argv[separator + 1];
process.stdout.write(`fake dispatch complete: ${task}\n`);
