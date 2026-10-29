// scripts/generate-data.mjs
// Generates JSON from YAML files in src/data into src/data/generated
// Then archives selected project files/folders into a .tar.gz

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import YAML from "yaml";

const ROOT = process.cwd();
const SRC = path.join(ROOT, "src", "data");
const OUT = path.join(SRC, "generated");
const RULES_API_DIR = path.join(ROOT, "public", "rules-api", "latest");
const RULES_API_PUBLISH_DIR = path.join(ROOT, "public", "rules-api", "latest");
const RULES_API_PUBLIC_URL = (
  process.env.RULES_API_PUBLIC_URL || "https://rules-api.whisperspace.com/rules-api/latest"
).replace(/\/+$/, "");
const DOCS_PUBLIC_URL = (process.env.DOCS_PUBLIC_URL || "https://docs.whisperspace.com").replace(/\/+$/, "");
const SAFE_CHAPTER_SLUG_RE = /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/;

//enable/disable the TAR behaviour here
const ENABLE_ARCHIVE = false;

const files = [
  { in: "skills.yaml", out: "skills.json" },
  { in: "weapons.yaml", out: "weapons.json" },
  { in: "armour.yaml", out: "armour.json" },
  { in: "weapon_keywords.yaml", out: "weapon_keywords.json" },
  { in: "items.yaml", out: "items.json" },
  { in: "cyberware.yaml", out: "cyberware.json" },
  { in: "narcotics.yaml", out: "narcotics.json" },
  { in: "hacking_gear.yaml", out: "hacking_gear.json" },
];

function timestamp() {
  // YYYYMMDD-HHMMSS (local time)
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return (
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  );
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });

  for (const f of files) {
    const inPath = path.join(SRC, f.in);
    const outPath = path.join(OUT, f.out);

    if (!fs.existsSync(inPath)) {
      console.warn(`[generate-data] Missing ${inPath} (skipping)`);
      continue;
    }

    const raw = fs.readFileSync(inPath, "utf8");
    const parsed = YAML.parse(raw);

    fs.writeFileSync(outPath, JSON.stringify(parsed, null, 2) + "\n", "utf8");
    console.log(`[generate-data] Wrote ${path.relative(ROOT, outPath)}`);
  }

  // --- Rules YAML aggregation ---
  const RULES_DIR = path.join(SRC, "rules");
  const RULES_OUT = path.join(OUT, "rules.json");
  const TOOLTIP_OUT = path.join(OUT, "skill_tooltips.json");
  if (fs.existsSync(RULES_DIR)) {
    const ruleFiles = fs.readdirSync(RULES_DIR).filter((f) => f.endsWith(".yaml")).sort();
    const docs = [];
    for (const filename of ruleFiles) {
      const inPath = path.join(RULES_DIR, filename);
      const raw = fs.readFileSync(inPath, "utf8");
      const parsed = YAML.parse(raw);
      docs.push({ file: filename, ...parsed });
    }
    fs.writeFileSync(RULES_OUT, JSON.stringify(docs, null, 2) + "\n", "utf8");
    console.log(`[generate-data] Wrote ${path.relative(ROOT, RULES_OUT)}`);

    const attrSkillsPath = path.join(RULES_DIR, "attributes-and-skills.yaml");
    if (fs.existsSync(attrSkillsPath)) {
      const raw = fs.readFileSync(attrSkillsPath, "utf8");
      const parsed = YAML.parse(raw);
      const rawTooltips = extractSkillTooltips(parsed);
      let skillsData = null;
      try {
        skillsData = JSON.parse(fs.readFileSync(path.join(OUT, "skills.json"), "utf8"));
      } catch {}
      const tooltipPayload = buildTooltipPayload(rawTooltips, skillsData);
      fs.writeFileSync(TOOLTIP_OUT, JSON.stringify(tooltipPayload, null, 2) + "\n", "utf8");
      console.log(`[generate-data] Wrote ${path.relative(ROOT, TOOLTIP_OUT)}`);
    } else {
      console.warn(`[generate-data] Missing ${path.relative(ROOT, attrSkillsPath)} (skipping tooltips)`);
    }
  } else {
    console.warn(`[generate-data] Rules directory missing: ${path.relative(ROOT, RULES_DIR)} (skipping)`);
  }

  writeRulesApiBundle();

  await archiveProject({ enabled: ENABLE_ARCHIVE });
}

async function archiveProject({ enabled }) {
  if (!enabled) return;

  const { create: tarCreate } = await import("tar");

  // --- Archive step (final) ---
  const targets = [
    "scripts",
    "src",
    "public",
    ".tool-versions",
    "background.html",
    "index.html",
    "package.json",
    "package-lock.json",
    "README.md",
    "tsconfig.json",
    "tsconfig.node.json",
    "tsconfig.tsbuildinfo",
    "vite.config.ts",
  ];

  // Only include things that exist; warn on missing
  const existing = targets.filter((p) => {
    const abs = path.join(ROOT, p);
    const ok = fs.existsSync(abs);
    if (!ok) console.warn(`[generate-data] Archive target missing: ${p} (skipping)`);
    return ok;
  });

  const ARCHIVE_DIR = "./";
  const ARCHIVE_PATH = path.join(ARCHIVE_DIR, `project-${timestamp()}.tar.gz`);

  fs.mkdirSync(ARCHIVE_DIR, { recursive: true });

  await tarCreate(
    {
      gzip: true,
      file: ARCHIVE_PATH,
      cwd: ROOT,
      portable: true,
    },
    existing
  );

  console.log(`[generate-data] Archived -> ${path.relative(ROOT, ARCHIVE_PATH)}`);
}

function collectTables(node, out = []) {
  const content = node?.content ?? [];
  for (const block of content) {
    if (block?.type === "table") out.push(block);
  }
  const sections = node?.sections ?? [];
  for (const section of sections) collectTables(section, out);
  return out;
}

function cellText(cell) {
  const text = String(cell?.text ?? "").trim();
  if (text) return text;
  const spans = cell?.spans ?? [];
  if (Array.isArray(spans) && spans.length) {
    return spans.map((s) => String(s?.text ?? "").trim()).join("").trim();
  }
  return "";
}

function cleanDescription(text) {
  return String(text ?? "")
    .replace(/([a-z])([A-Z][a-z])/g, "$1. $2")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeTooltipKey(text) {
  return String(text ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function buildTooltipPayload(rawTooltips, skillsData) {
  const attributesByShort = rawTooltips.attributes ?? {};
  const skillsByLabel = rawTooltips.skills ?? {};

  const attributesById = {};
  for (const [k, v] of Object.entries(attributesByShort)) {
    const key = String(k).toLowerCase();
    if (["phys", "ref", "soc", "ment"].includes(key)) attributesById[key] = v;
  }

  const labelToId = new Map();
  const inherent = Array.isArray(skillsData?.inherent) ? skillsData.inherent : [];
  const learnedByFocus = skillsData?.learned && typeof skillsData.learned === "object" ? skillsData.learned : {};

  for (const skill of inherent) {
    const norm = normalizeTooltipKey(skill?.label);
    if (norm && typeof skill?.id === "string") labelToId.set(norm, skill.id);
  }
  for (const list of Object.values(learnedByFocus)) {
    if (!Array.isArray(list)) continue;
    for (const skill of list) {
      const norm = normalizeTooltipKey(skill?.label);
      if (norm && typeof skill?.id === "string") labelToId.set(norm, skill.id);
    }
  }

  const skillsById = {};
  for (const [label, description] of Object.entries(skillsByLabel)) {
    const id = labelToId.get(normalizeTooltipKey(label));
    if (id && !skillsById[id]) skillsById[id] = description;
  }

  return {
    version: 2,
    attributes: attributesById,
    attributesById,
    attributesByShort,
    skills: skillsById,
    skillsById,
    skillsByLabel,
  };
}

function extractSkillTooltips(ruleDoc) {
  const tables = collectTables(ruleDoc, []);
  const attributes = {};
  const skills = {};

  for (const table of tables) {
    const rows = (table?.rows ?? []).map((row) => row.map((cell) => cellText(cell)));
    if (!rows.length) continue;
    let headerRowIndex = 0;
    let dataStartIndex = 1;
    if (rows[0].length === 1 && rows.length > 1) {
      headerRowIndex = 1;
      dataStartIndex = 2;
    } else if (rows.length > 1) {
      const row0 = rows[0].map((h) => String(h).toLowerCase());
      const row1 = rows[1].map((h) => String(h).toLowerCase());
      const row0LooksHeader = row0.some((h) => h.includes("description") || h.includes("skill") || h.includes("attribute"));
      const row1LooksHeader = row1.some((h) => h.includes("description") || h.includes("skill") || h.includes("attribute"));
      if (!row0LooksHeader && row1LooksHeader) {
        headerRowIndex = 1;
        dataStartIndex = 2;
      }
    }
    const header = rows[headerRowIndex].map((h) => h.toLowerCase());

    const isAttributeTable =
      header.includes("attribute") && header.includes("short form") && header.includes("description");
    if (isAttributeTable) {
      for (const row of rows.slice(dataStartIndex)) {
        const shortForm = row[1];
        const description = cleanDescription(row[2]);
        if (!shortForm || !description) continue;
        attributes[shortForm] = description;
      }
      continue;
    }

    const hasDescription = header.some((h) => h.includes("description"));
    const hasSkillsLabel = header[0]?.includes("skills") || header[0]?.includes("skill");
    if (!hasDescription || !hasSkillsLabel) continue;

    if (header.length >= 3 && header.some((h) => h.includes("max rank"))) {
      for (const row of rows.slice(dataStartIndex)) {
        const name = row[0];
        const description = cleanDescription(row[2]);
        if (!name || !description) continue;
        if (!skills[name]) skills[name] = description;
      }
    } else if (header.length >= 2) {
      for (const row of rows.slice(dataStartIndex)) {
        const name = row[0];
        const description = cleanDescription(row[1]);
        if (!name || !description) continue;
        if (!skills[name]) skills[name] = description;
      }
    }
  }

  return { attributes, skills };
}

function writeRulesApiBundle() {
  const rulesVersion = readRulesVersion();
  const rulesApiDirs = Array.from(new Set([RULES_API_DIR, RULES_API_PUBLISH_DIR]));
  const filesToCopy = [
    "skills.json",
    "weapons.json",
    "armour.json",
    "weapon_keywords.json",
    "items.json",
    "cyberware.json",
    "narcotics.json",
    "hacking_gear.json",
    "rules.json",
    "skill_tooltips.json",
  ];

  for (const dir of rulesApiDirs) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // Remove legacy US spelling files if present.
  for (const dir of rulesApiDirs) {
    try {
      fs.rmSync(path.join(dir, "armor.json"));
    } catch {}
  }

  // Copy assets (images) if present.
  const assetsSrc = path.join(SRC, "rules", "assets");
  if (fs.existsSync(assetsSrc)) {
    for (const dir of rulesApiDirs) {
      const assetsDest = path.join(dir, "assets");
      try {
        fs.rmSync(assetsDest, { recursive: true, force: true });
      } catch {}
      fs.mkdirSync(assetsDest, { recursive: true });
      fs.cpSync(assetsSrc, assetsDest, { recursive: true });
    }
  }

  const meta = {
    version: rulesVersion,
    generatedAt: new Date().toISOString(),
    files: {},
  };

  for (const filename of filesToCopy) {
    const srcPath = path.join(OUT, filename);
    if (!fs.existsSync(srcPath)) {
      console.warn(`[generate-data] Missing ${path.relative(ROOT, srcPath)} (skipping rules-api)`);
      continue;
    }
    const data = fs.readFileSync(srcPath);
    const hash = crypto.createHash("sha256").update(data).digest("hex");
    for (const dir of rulesApiDirs) {
      const destPath = path.join(dir, filename);
      fs.writeFileSync(destPath, data);
    }
    meta.files[filename] = {
      sha256: hash,
      bytes: data.length,
    };
  }

  // Include core module files if present
  const coreDir = path.join(RULES_API_DIR, "core");
  if (fs.existsSync(coreDir)) {
    const coreFiles = fs.readdirSync(coreDir).filter((f) => f.endsWith(".js"));
    for (const file of coreFiles) {
      const filePath = path.join(coreDir, file);
      const data = fs.readFileSync(filePath);
      const hash = crypto.createHash("sha256").update(data).digest("hex");
      meta.files[`core/${file}`] = { sha256: hash, bytes: data.length };
    }
  }

  writeChapterFiles(rulesApiDirs, meta);

  const metaJson = JSON.stringify(meta, null, 2) + "\n";
  for (const dir of rulesApiDirs) {
    const metaPath = path.join(dir, "meta.json");
    fs.writeFileSync(metaPath, metaJson, "utf8");
    console.log(`[generate-data] Wrote ${path.relative(ROOT, metaPath)}`);
  }
}

// Last commit date of a rules YAML file, used to seed a chapter's updatedAt the first time
// it appears in the index (so existing chapters don't all claim to have changed today).
function gitLastCommitDate(relativePath) {
  try {
    const out = execFileSync("git", ["log", "-1", "--format=%cI", "--", relativePath], {
      cwd: ROOT,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    return out ? new Date(out).toISOString() : "";
  } catch {
    return "";
  }
}

function readPreviousChapterIndex(dir) {
  try {
    const previous = JSON.parse(fs.readFileSync(path.join(dir, "chapters", "index.json"), "utf8"));
    return new Map((previous.chapters || []).map((entry) => [entry.slug, entry]));
  } catch {
    return new Map();
  }
}

// rules.json is too large for AI tools and browsers-as-readers to take in one fetch, so each
// chapter is also published on its own as chapters/<slug>.json (exactly one entry of
// rules.json, minified), plus chapters/index.json listing them. These are extra files only:
// rules.json and meta.json are unchanged, and the chapter files are not listed in meta.json.
//
// Each index entry carries a content hash and an updatedAt that only moves when that
// chapter's content changes (the docs sitemap uses it for <lastmod>). The index has no
// per-run timestamp, so the hourly publish leaves it untouched unless the rules changed.
function writeChapterFiles(rulesApiDirs, meta) {
  const rulesPath = path.join(OUT, "rules.json");
  if (!fs.existsSync(rulesPath)) return;
  const chapters = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
  const previousBySlug = readPreviousChapterIndex(rulesApiDirs[0]);

  const files = [];
  const index = {
    description:
      "Whisperspace TTRPG rules, one file per chapter. Each chapter file holds that chapter's " +
      "nested sections (title, content blocks, sections) exactly as in rules.json.",
    version: meta.version,
    updatedAt: "",
    fullRulebook: `${RULES_API_PUBLIC_URL}/rules.json`,
    chapters: [],
  };

  for (const chapter of chapters) {
    const slug = typeof chapter?.slug === "string" ? chapter.slug : "";
    if (!SAFE_CHAPTER_SLUG_RE.test(slug)) {
      console.warn(`[generate-data] Skipping chapter file for unsafe slug ${JSON.stringify(slug)}`);
      continue;
    }
    const data = JSON.stringify(chapter) + "\n";
    const sha256 = crypto.createHash("sha256").update(data).digest("hex");
    const previous = previousBySlug.get(slug);
    let updatedAt = meta.generatedAt;
    if (previous?.sha256 === sha256 && previous.updatedAt) {
      updatedAt = previous.updatedAt;
    } else if (!previous?.sha256) {
      updatedAt = gitLastCommitDate(path.join("src", "data", "rules", chapter.file || "")) || updatedAt;
    }
    files.push({ name: `${slug}.json`, data });
    index.chapters.push({
      title: chapter.title,
      slug,
      url: `${RULES_API_PUBLIC_URL}/chapters/${slug}.json`,
      docsUrl: `${DOCS_PUBLIC_URL}/${slug}/`,
      bytes: Buffer.byteLength(data),
      sha256,
      updatedAt,
    });
  }
  index.updatedAt = index.chapters.reduce(
    (latest, entry) => (entry.updatedAt > latest ? entry.updatedAt : latest),
    ""
  );
  files.push({ name: "index.json", data: JSON.stringify(index, null, 2) + "\n" });

  for (const dir of rulesApiDirs) {
    // Rebuilt from scratch each run so chapters removed from the rulebook don't linger.
    const chaptersDir = path.join(dir, "chapters");
    fs.rmSync(chaptersDir, { recursive: true, force: true });
    fs.mkdirSync(chaptersDir, { recursive: true });
    for (const file of files) {
      fs.writeFileSync(path.join(chaptersDir, file.name), file.data, "utf8");
    }
    console.log(`[generate-data] Wrote ${index.chapters.length} chapter files to ${path.relative(ROOT, chaptersDir)}`);
  }
}

function readRulesVersion() {
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
    if (typeof pkg.rulesVersion === "string" && pkg.rulesVersion.trim()) {
      return pkg.rulesVersion.trim();
    }
    if (typeof pkg.version === "string" && pkg.version.trim()) {
      return pkg.version.trim();
    }
  } catch {}
  return timestamp();
}

main().catch((err) => {
  console.error("[generate-data] Failed:", err);
  process.exitCode = 1;
});
