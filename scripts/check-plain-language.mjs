import { readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const abbreviation = /\b(?:e\.g\.|i\.e\.|et al\.|Dr\.|Mr\.|Mrs\.|Ms\.|Prof\.)/g;
const continuedInitialism = /\b(?:[A-Z]\.){2,}(?=\s+\p{Ll})/gu;
const instruction = /^(?:(?:if|before|after)\b[^,]+,\s*)?(?:do not\s+)?(?:add|allow|apply|calculate|choose|compare|convert|copy|create|define|describe|do|examine|execute|find|give|include|keep|load|make|name|open|predict|read|record|remove|repeat|replace|report|return|run|save|select|set|stop|use|write)\b/i;

function quotationUnit(quotation, offset, source) {
  const terminal = quotation.slice(1, -1).trimEnd().match(/[.!?]$/)?.[0] ?? "";
  const rest = source.slice(offset + quotation.length).replace(/^[\s*_~]+/, "");
  const boundary = !rest || /^[\p{Lu}\p{N}]/u.test(rest);
  return ` QUOTATION${boundary ? terminal : ""} `;
}

export function plainText(value, citationTitles = false) {
  return value
    .replace(/(`+)[\s\S]*?\1/g, " CODE ")
    .replace(/!?\[([^\]]*)\]\([^\n]*?\)/g, (_, label) => citationTitles ? " TITLE " : label)
    .replace(/\\\([\s\S]*?\\\)|\$[^$\n]+\$/g, " FORMULA ")
    .replace(/\{[.#][^}]*\}/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&(?:[a-z]+|#\d+|#x[0-9a-f]+);/gi, " ENTITY ")
    .replace(/[“"][^”"\n]*[”"]/g, quotationUnit)
    .replace(/(?<![\p{L}\p{N}])['‘][^'’\n]+['’](?![\p{L}\p{N}])/gu, quotationUnit)
    .replace(/\([^()]*\)/g, " PARENTHESIS ")
    .replace(/\*|_|~/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function inspectText(value, kind = "paragraph", { deferLength = false } = {}) {
  const text = plainText(value, kind === "citation");
  const sentences = text.replace(abbreviation, (match) => match.replace(/\./g, "\uE000"))
    .replace(continuedInitialism, (match) => match.replace(/\./g, "\uE000"))
    .split(/(?<=[.!?])\s+/)
    .map((sentence) => sentence.replace(/\uE000/g, ".").trim())
    .filter((sentence) => /[\p{L}\p{N}]/u.test(sentence));
  const findings = [];
  if (text.includes(";")) findings.push("semicolon in authored prose");
  if (deferLength) return findings;
  if (kind !== "label" && sentences.length > 6) {
    findings.push(`${sentences.length} sentences in a paragraph (limit 6)`);
  }
  for (const sentence of sentences) {
    const words = sentence.match(/[\p{L}\p{N}]+(?:[-'’][\p{L}\p{N}]+)*/gu) ?? [];
    const limit = kind !== "label" && instruction.test(sentence) ? 20 : 25;
    if (words.length > limit) {
      findings.push(`${words.length} conservative words (limit ${limit}): ${sentence}`);
    }
  }
  return findings;
}

export function inspectSourceBlock({ text, kind = "paragraph" }) {
  const requiresRenderedCheck = /(`+)r[ \t][\s\S]*?\1/.test(text);
  return {
    findings: inspectText(text, kind, { deferLength: requiresRenderedCheck }),
    requiresRenderedCheck
  };
}

export function sourceBlocks(source) {
  const lines = source.split(/\r?\n/);
  const blocks = [];
  let frontmatter = lines[0] === "---";
  let fence = null;
  let excludedFences = 0;
  let citationSection = false;
  let citationLevel = 0;
  let paragraph = [];
  let paragraphIsList = false;
  let start = 1;
  const flush = () => {
    if (paragraph.length) blocks.push({ line: start, kind: citationSection ? "citation" : "paragraph", text: paragraph.join(" ") });
    paragraph = [];
    paragraphIsList = false;
  };
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (frontmatter) {
      if (index && line === "---") frontmatter = false;
      const field = line.match(/^(title|subtitle|description):\s*(.*)$/);
      if (field) {
        if (/^[>|]/.test(field[2])) throw new Error(`Folded metadata needs explicit extraction at line ${index + 1}`);
        blocks.push({ line: index + 1, kind: "label", text: field[2].replace(/^["']|["']$/g, "") });
      }
      continue;
    }
    const boundary = line.match(/^\s*(`{3,}|~{3,})(.*)$/);
    if (fence) {
      if (boundary && boundary[1][0] === fence[0] && boundary[1].length >= fence.length && !boundary[2].trim()) fence = null;
      continue;
    }
    if (boundary) {
      flush();
      fence = boundary[1];
      excludedFences += 1;
      continue;
    }
    if (!line.trim() || /^\s*:::/u.test(line)) {
      flush();
      continue;
    }
    if (/^\s*#{1,6}\s/.test(line)) {
      flush();
      const heading = line.match(/^\s*(#{1,6})\s+(.*)$/);
      const level = heading[1].length;
      if (citationSection && level <= citationLevel) citationSection = false;
      if (/^Sources\s*(?:\{[^}]*\})?$/i.test(heading[2])) {
        citationSection = true;
        citationLevel = level;
      }
      blocks.push({ line: index + 1, kind: "label", text: heading[2] });
      continue;
    }
    if (/^\s*\|/.test(line)) {
      flush();
      if (!/^[\s|:\-]+$/.test(line)) {
        for (const text of plainText(line).split("|").filter((cell) => cell.trim())) {
          blocks.push({ line: index + 1, kind: "label", text });
        }
      }
      continue;
    }
    const item = line.match(/^\s*(?:[-+*]|\d+[.)])\s+(.*)$/);
    const orderedContinuation = item && /^\s*\d+[.)]\s/.test(line) && paragraph.length > 0 && !paragraphIsList;
    if (item && !orderedContinuation) {
      flush();
      paragraphIsList = true;
    }
    if (!paragraph.length) start = index + 1;
    paragraph.push(item && !orderedContinuation ? item[1] : line.replace(/^\s*>\s?/, ""));
  }
  flush();
  if (frontmatter || fence) throw new Error("Unclosed front matter or code fence");
  return { blocks, excludedFences };
}

export function publicPages(root = ".") {
  const config = readFileSync(join(root, "_quarto.yml"), "utf8");
  const render = config.match(/^  render:\r?\n((?: {4}[^\n]*\n)+)/m);
  if (!render) throw new Error("Cannot find the explicit project.render list");
  const paths = [];
  for (const line of render[1].trimEnd().split(/\r?\n/)) {
    const match = line.match(/^    - ([\w./-]+(?:\*\.qmd)?)$/);
    if (!match) throw new Error(`Unsupported render entry: ${line}`);
    const pattern = match[1];
    if (pattern.endsWith("/*.qmd")) {
      const directory = pattern.slice(0, -6);
      const files = readdirSync(join(root, directory)).filter((file) => file.endsWith(".qmd"));
      if (!files.length) throw new Error(`No public pages match ${pattern}`);
      paths.push(...files.map((file) => `${directory}/${file}`));
    } else if (pattern.endsWith(".qmd")) {
      paths.push(pattern);
    } else {
      throw new Error(`Unsupported public-page pattern: ${pattern}`);
    }
  }
  if (!paths.length || new Set(paths).size !== paths.length) throw new Error("Empty or duplicate public-page inventory");
  return paths.sort();
}

export function auditSource(root = ".") {
  const findings = [];
  const coverage = [];
  const deferred = [];
  for (const path of publicPages(root)) {
    const { blocks, excludedFences } = sourceBlocks(readFileSync(join(root, path), "utf8"));
    let deferredBlocks = 0;
    for (const block of blocks) {
      const inspected = inspectSourceBlock(block);
      if (inspected.requiresRenderedCheck) {
        deferred.push({ path, line: block.line, kind: block.kind, reason: "Inline R requires rendered length and paragraph checks" });
        deferredBlocks += 1;
      }
      for (const message of inspected.findings) findings.push(`${path}:${block.line}: ${message}`);
    }
    coverage.push({ path, blocks: blocks.length, excludedFences, deferredBlocks });
  }
  return { findings, coverage, deferred };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const { findings, coverage, deferred } = auditSource();
  for (const finding of findings) console.error(finding);
  for (const block of deferred) console.log(`${block.path}:${block.line}: ${block.reason}.`);
  console.log(`Scanned authored source prose on ${coverage.length} public pages; ${findings.length} findings.`);
  console.log(`Deferred length and paragraph verdicts for ${deferred.length} inline-R blocks to the rendered-page suite.`);
  console.log(`Excluded ${coverage.reduce((sum, page) => sum + page.excludedFences, 0)} fenced blocks. Rendered prose needs a separate scan.`);
  console.log("Counts, quotation boundaries and recognized imperatives are heuristic. Vocabulary, meanings, grammar and STE compliance need contextual review.");
  process.exitCode = findings.length ? 1 : 0;
}
