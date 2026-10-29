// scripts/export-markdown.mjs
// Renders the published rules (public/rules-api/latest/rules.json) as one Markdown file per
// chapter plus a README index, for the GitHub rules repo that AI tools (e.g. ChatGPT's
// GitHub connector) read directly.
//
// Usage: node scripts/export-markdown.mjs <output-dir>
//
// Output is deterministic: dates come from each chapter's updatedAt in chapters/index.json,
// which only changes when that chapter's content changes, so re-running with unchanged
// rules produces byte-identical files.

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const ROOT = process.cwd();
const LATEST_DIR = path.join(ROOT, "public", "rules-api", "latest");
const RULES_API_PUBLIC_URL = (
  process.env.RULES_API_PUBLIC_URL || "https://rules-api.whisperspace.com/rules-api/latest"
).replace(/\/+$/, "");
const DOCS_PUBLIC_URL = (process.env.DOCS_PUBLIC_URL || "https://docs.whisperspace.com").replace(/\/+$/, "");
const SAFE_SLUG_RE = /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/;
const CHAPTERS_DIR_NAME = "chapters";

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

// Escape characters that would otherwise turn plain rule text into Markdown/HTML syntax.
function escapeInline(text) {
  return String(text ?? "")
    .replace(/\\/g, "\\\\")
    .replace(/([*_`\[\]<>])/g, "\\$1");
}

// Escape Markdown block syntax at the start of a line (headings, quotes, list markers).
function escapeLineStarts(text) {
  return text
    .split("\n")
    .map((line) => line.replace(/^(\s*)([#>+-]|\d+\.)(?=\s|$)/, "$1\\$2"))
    .join("\n");
}

// Parser links look like "combat.yaml#flanking"; point them at the matching chapter file.
function resolveHref(href, chapterSlugByFile) {
  const value = String(href || "").trim();
  if (!value) return "";
  if (/^https?:\/\//i.test(value)) return value;
  const [file, anchor = ""] = value.split("#");
  const slug = chapterSlugByFile.get(file);
  if (!slug) return "";
  return `${slug}.md${anchor ? `#${anchor}` : ""}`;
}

function wrapSpan(text, style, href) {
  const escaped = escapeInline(text);
  let out = escaped;
  if (style.includes("italic")) out = `*${out}*`;
  if (style.includes("bold")) out = `**${out}**`;
  if (href) out = `[${out}](${href})`;
  return out;
}

// Apply bold/italic/link spans. Spans are substrings of the text in order of appearance.
function renderRichText(node, ctx) {
  const text = String(node?.text ?? "");
  const spans = Array.isArray(node?.spans) ? node.spans : [];
  let out = "";
  let cursor = 0;
  for (const span of spans) {
    const spanText = String(span?.text ?? "");
    if (!spanText) continue;
    const at = text.indexOf(spanText, cursor);
    if (at < 0) continue;
    const style = String(span.style || "");
    const href = style.includes("link") ? resolveHref(span.href, ctx.chapterSlugByFile) : "";
    if (!style.match(/bold|italic/) && !href) continue;
    out += escapeInline(text.slice(cursor, at));
    out += wrapSpan(spanText, style, href);
    cursor = at + spanText.length;
  }
  out += escapeInline(text.slice(cursor));
  return out.trim();
}

function renderList(block, ctx, indent = "") {
  return (block.items || [])
    .map((item, index) => {
      const marker = block.ordered ? `${index + 1}.` : "-";
      const continuation = `${indent}${" ".repeat(marker.length + 1)}`;
      const body = renderRichText(item, ctx).replace(/\n/g, `\n${continuation}`);
      return `${indent}${marker} ${body}`;
    })
    .join("\n");
}

function renderCell(cell, ctx) {
  const parts = [];
  const text = renderRichText(cell, ctx);
  if (text && text !== "-") parts.push(text);
  for (const block of cell?.blocks || []) {
    if (block.type === "list") {
      for (const item of block.items || []) parts.push(`• ${renderRichText(item, ctx)}`);
    } else if (block.type === "paragraph") {
      parts.push(renderRichText(block, ctx));
    }
  }
  if (!parts.length && text === "-") parts.push("-");
  return parts.join("<br>").replace(/\n+/g, "<br>").replace(/\|/g, "\\|");
}

function renderTable(block, ctx) {
  const rows = (block.rows || []).map((row) => row.map((cell) => renderCell(cell, ctx)));
  if (!rows.length) return "";
  const width = Math.max(...rows.map((row) => row.length));
  const pad = (row) => [...row, ...Array(width - row.length).fill("")];
  const line = (row) => `| ${pad(row).join(" | ")} |`;
  const [header, ...body] = rows;
  return [line(header), `|${" --- |".repeat(width)}`, ...body.map(line)].join("\n");
}

function renderBlock(block, ctx) {
  switch (block?.type) {
    case "paragraph":
      return escapeLineStarts(renderRichText(block, ctx));
    case "list":
      return renderList(block, ctx);
    case "table":
      return renderTable(block, ctx);
    case "image": {
      const src = String(block.src || "").replace(/^\/+/, "");
      if (!src) return "";
      const url = /^https?:\/\//i.test(src) ? src : `${RULES_API_PUBLIC_URL}/${src}`;
      return `![${escapeInline(block.alt || "")}](${url})`;
    }
    default:
      return "";
  }
}

// Explicit anchors keep the parser's slugs (used by cross-chapter links) working on GitHub,
// whose own heading anchors are derived differently.
function renderSection(section, depth, ctx, intro = "") {
  const parts = [];
  const level = Math.min(depth, 6);
  const anchor = SAFE_SLUG_RE.test(section.slug || "") ? `<a id="${section.slug}"></a>\n` : "";
  parts.push(`${anchor}${"#".repeat(level)} ${escapeInline(section.title || "Untitled")}`);
  if (intro) parts.push(intro);
  let previous = null;
  for (const block of section.content || []) {
    const rendered = renderBlock(block, ctx);
    if (!rendered) continue;
    // The parser emits nested list levels as consecutive list blocks; keep them in one
    // tight list instead of separating them with blank lines.
    if (previous?.type === "list" && block.type === "list" && previous.ordered === block.ordered) {
      parts[parts.length - 1] += `\n${rendered}`;
    } else {
      parts.push(rendered);
    }
    previous = block;
  }
  for (const child of section.sections || []) {
    parts.push(renderSection(child, depth + 1, ctx));
  }
  return parts.join("\n\n");
}

function renderChapter(chapter, entry, ctx) {
  const updated = entry?.updatedAt ? entry.updatedAt.slice(0, 10) : "";
  const meta = [
    `> Whisperspace rules, chapter: **${escapeInline(chapter.title)}**`,
    `> Web version: ${DOCS_PUBLIC_URL}/${chapter.slug}/`,
    updated ? `> Last changed: ${updated}` : "",
    "> Generated from the official rules. Do not edit by hand; changes are overwritten.",
  ].filter(Boolean);
  return `${renderSection(chapter, 1, ctx, meta.join("\n"))}\n`;
}

function renderReadme(chapters, index) {
  const details = [
    `- Rules version: ${index.version || "unknown"}`,
    index.updatedAt ? `- Last rules change: ${index.updatedAt.slice(0, 10)}` : null,
    `- Web version: ${DOCS_PUBLIC_URL}/`,
    `- Machine-readable JSON: ${RULES_API_PUBLIC_URL}/rules.json (per chapter: ${RULES_API_PUBLIC_URL}/chapters/index.json)`,
  ].filter(Boolean);
  const lines = [
    "# Whisperspace Rules",
    "",
    "The complete rules for **Whisperspace**, a science-fiction tabletop roleplaying game, as",
    "plain Markdown: one file per chapter in [`chapters/`](chapters/).",
    "",
    "This repository is generated automatically from the official rules every time they",
    "change. Don't edit it by hand.",
    "",
    ...details,
    "",
    "## Chapters",
    "",
    "| Chapter | File | Last changed |",
    "| --- | --- | --- |",
  ];
  const entryBySlug = new Map((index.chapters || []).map((entry) => [entry.slug, entry]));
  for (const chapter of chapters) {
    const updated = entryBySlug.get(chapter.slug)?.updatedAt?.slice(0, 10) || "";
    lines.push(
      `| ${escapeInline(chapter.title).replace(/\|/g, "\\|")} | [${chapter.slug}.md](${CHAPTERS_DIR_NAME}/${chapter.slug}.md) | ${updated} |`
    );
  }
  return `${lines.join("\n")}\n`;
}

function main() {
  const outDir = process.argv[2];
  if (!outDir) {
    console.error("Usage: node scripts/export-markdown.mjs <output-dir>");
    process.exit(2);
  }
  const rules = readJson(path.join(LATEST_DIR, "rules.json"));
  let index = { chapters: [] };
  try {
    index = readJson(path.join(LATEST_DIR, "chapters", "index.json"));
  } catch {
    console.warn("[export-markdown] chapters/index.json missing; dates will be omitted");
  }
  const entryBySlug = new Map((index.chapters || []).map((entry) => [entry.slug, entry]));

  const chapters = rules.filter((chapter) => {
    const ok = SAFE_SLUG_RE.test(chapter?.slug || "");
    if (!ok) console.warn(`[export-markdown] Skipping chapter with unsafe slug ${JSON.stringify(chapter?.slug)}`);
    return ok;
  });
  const ctx = {
    chapterSlugByFile: new Map(chapters.map((chapter) => [chapter.file, chapter.slug])),
  };

  const chaptersDir = path.join(outDir, CHAPTERS_DIR_NAME);
  fs.mkdirSync(chaptersDir, { recursive: true });
  const expected = new Set();
  for (const chapter of chapters) {
    const name = `${chapter.slug}.md`;
    expected.add(name);
    fs.writeFileSync(path.join(chaptersDir, name), renderChapter(chapter, entryBySlug.get(chapter.slug), ctx), "utf8");
  }
  // Remove chapters that no longer exist in the rules.
  for (const name of fs.readdirSync(chaptersDir)) {
    if (name.endsWith(".md") && !expected.has(name)) fs.rmSync(path.join(chaptersDir, name));
  }
  fs.writeFileSync(path.join(outDir, "README.md"), renderReadme(chapters, index), "utf8");
  console.log(`[export-markdown] Wrote ${chapters.length} chapters to ${outDir}`);
}

main();
