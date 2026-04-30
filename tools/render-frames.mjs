#!/usr/bin/env node
import { Resvg } from '@resvg/resvg-js';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..');
const SVG_DIR = resolve(HERE, 'svg');
const RESOURCES_DIR = resolve(REPO_ROOT, 'ClaudeMascot/Resources');
const SVG_BASE_URL = 'https://raw.githubusercontent.com/leeorlandi/claude-code-mascot/main/assets';

const SOURCE_BODY_COLOR = '#c8614e';

const TARGET_HEIGHT = 16;

// FLOAT_PX_AT_1X — desired bob amplitude in *output* pixels at @1x (so @2x is 2× this).
// PAD_TOP and FLOAT are chosen so the design-unit translation maps to a whole number
// of output pixels at both @1x and @2x — otherwise the eyes (tiny rects on sub-pixel
// boundaries already) anti-alias differently between frames and appear to flicker.
//   PAD_TOP=14, viewBox h=101, target=16 → FLOAT = 12.625 design units
//                                          → 2 px @ 1x, 4 px @ 2x  ✓ both integer
const FLOAT_PX_AT_1X = 2;
const PAD_TOP = 14;
const VIEWBOX_HEIGHT = 87 + PAD_TOP;
const FLOAT = FLOAT_PX_AT_1X * VIEWBOX_HEIGHT / TARGET_HEIGHT;

// Per-state pair of (eyes, dy) tuples: A is rest, B is the toggled frame.
//   idle      — eyes blink, body still      (waiting input)
//   working   — body floats up, eyes open   (cooking)
//   attention — eyes blink, body still      (needs you — different colour, faster blink)
const STATES = {
  idle:      { color: '#8a8a8a', a: { eyes: 'open', dy: 0 }, b: { eyes: 'squint', dy: 0      } },
  working:   { color: '#3aa676', a: { eyes: 'open', dy: 0 }, b: { eyes: 'open',   dy: -FLOAT } },
  attention: { color: '#e07b3a', a: { eyes: 'open', dy: 0 }, b: { eyes: 'squint', dy: 0      } },
};

async function poseSvg({ eyes, dy }) {
  const VIEWBOX_ORIGINAL = 'viewBox="0 0 110 87"';
  const VIEWBOX_EXTENDED = `viewBox="0 ${-PAD_TOP} 110 ${VIEWBOX_HEIGHT}"`;
  const svg = await ensureSvg(`mascot-${eyes}`);
  return svg
    .replace(VIEWBOX_ORIGINAL, VIEWBOX_EXTENDED)
    .replace(/(<svg[^>]*>)/, `$1<g transform="translate(0,${dy})">`)
    .replace('</svg>', '</g></svg>');
}

async function ensureSvg(name) {
  const path = join(SVG_DIR, `${name}.svg`);
  try {
    return await readFile(path, 'utf8');
  } catch {
    await mkdir(SVG_DIR, { recursive: true });
    const url = `${SVG_BASE_URL}/${name}.svg`;
    process.stdout.write(`fetch ${url} ... `);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    const text = await res.text();
    await writeFile(path, text);
    console.log('saved');
    return text;
  }
}

function recolor(svg, color) {
  return svg.replaceAll(SOURCE_BODY_COLOR, color);
}

function renderPng(svg, height) {
  const resvg = new Resvg(svg, { fitTo: { mode: 'height', value: height } });
  return resvg.render().asPng();
}

async function writeFrames(name, png1x, png2x) {
  await writeFile(join(RESOURCES_DIR, `${name}.png`), png1x);
  await writeFile(join(RESOURCES_DIR, `${name}@2x.png`), png2x);
}

async function main() {
  await mkdir(RESOURCES_DIR, { recursive: true });
  for (const [state, { color, a, b }] of Object.entries(STATES)) {
    for (const [variant, pose] of [['a', a], ['b', b]]) {
      const svg = recolor(await poseSvg(pose), color);
      const name = `${state}-${variant}`;
      await writeFrames(name, renderPng(svg, TARGET_HEIGHT), renderPng(svg, TARGET_HEIGHT * 2));
      console.log(`wrote ${name} (eyes=${pose.eyes} dy=${pose.dy} @ ${color})`);
    }
  }
}

await main();
