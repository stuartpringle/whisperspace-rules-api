#!/usr/bin/env node
import process from "node:process";

function expect(condition, message) {
  if (!condition) throw new Error(message);
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

async function fetchText(url) {
  const response = await fetch(url, { method: "GET", redirect: "follow" });
  const text = await response.text();
  return { response, text };
}

async function fetchJson(url) {
  const { response, text } = await fetchText(url);
  let payload = null;
  try {
    payload = JSON.parse(text);
  } catch (error) {
    throw new Error(`${url} returned non-JSON payload (status ${response.status})`);
  }
  return { response, payload };
}

const urls = {
  rulesApi: process.env.WS_RULES_API_BASE || "https://rules-api.whisperspace.com",
  builder: process.env.WS_BUILDER_BASE || "https://builder.whisperspace.com",
  obr: process.env.WS_OBR_BASE || "https://obr.whisperspace.com",
  gm: process.env.WS_GM_BASE || "https://gm.whisperspace.com",
  docs: process.env.WS_DOCS_BASE || "https://docs.whisperspace.com",
};

async function run() {
  const checks = [];

  {
    const { response, payload } = await fetchJson(`${urls.rulesApi}/rules-api/latest/meta.json`);
    expect(response.status === 200, `rules meta status ${response.status}, expected 200`);
    expect(typeof payload.version === "string" && payload.version.length > 0, "rules meta.version missing");
    checks.push("rules-api meta");
  }

  {
    const { response, payload } = await fetchJson(`${urls.rulesApi}/character-api/health`);
    expect(response.status === 200, `character-api health status ${response.status}, expected 200`);
    expect(payload.ok === true, "character-api health missing ok:true");
    checks.push("character-api health");
  }

  {
    const { response, text } = await fetchText(`${urls.builder}/`);
    expect(response.status === 200, `builder status ${response.status}, expected 200`);
    expect(text.includes("<html"), "builder payload does not look like HTML");
    checks.push("builder");
  }

  {
    const { response, payload } = await fetchJson(`${urls.obr}/manifest.json`);
    expect(response.status === 200, `obr manifest status ${response.status}, expected 200`);
    expect(typeof payload.name === "string" && payload.name.length > 0, "obr manifest name missing");
    expect(isObject(payload.action), "obr manifest action missing");
    checks.push("obr manifest");
  }

  {
    const { response, payload } = await fetchJson(`${urls.obr}/rules/manifest.json`);
    expect(response.status === 200, `obr rules manifest status ${response.status}, expected 200`);
    expect(typeof payload.name === "string" && payload.name.length > 0, "obr rules manifest name missing");
    checks.push("obr rules manifest");
  }

  {
    const { response, payload } = await fetchJson(`${urls.gm}/manifest.json`);
    expect(response.status === 200, `gm manifest status ${response.status}, expected 200`);
    expect(typeof payload.name === "string" && payload.name.length > 0, "gm manifest name missing");
    checks.push("gm manifest");
  }

  {
    const { response, text } = await fetchText(`${urls.docs}/`);
    expect(response.status === 200, `docs status ${response.status}, expected 200`);
    expect(text.includes("<html"), "docs payload does not look like HTML");
    checks.push("docs");
  }

  console.log(
    `ecosystem:smoke OK (${checks.length} checks): ${checks.join(", ")}`
  );
}

run().catch((error) => {
  console.error(`ecosystem:smoke ERROR: ${error.message || String(error)}`);
  process.exit(1);
});
