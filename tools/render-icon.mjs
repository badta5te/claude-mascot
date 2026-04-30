#!/usr/bin/env node
// Build AppIcon.icns from a single composed SVG. Renders all sizes the macOS
// .iconset format requires, then shells out to `iconutil` to compile the .icns.
import { Resvg } from '@resvg/resvg-js';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..');
const SVG_DIR = resolve(HERE, 'svg');
const RESOURCES_DIR = resolve(REPO_ROOT, 'ClaudeMascot/Resources');
const ICONSET_DIR = resolve(REPO_ROOT, 'tools/AppIcon.iconset');
const ICNS_PATH = resolve(RESOURCES_DIR, 'AppIcon.icns');

// Apple's .iconset spec — these exact filenames are required.
const SIZES = [
  ['icon_16x16.png',       16],
  ['icon_16x16@2x.png',    32],
  ['icon_32x32.png',       32],
  ['icon_32x32@2x.png',    64],
  ['icon_128x128.png',     128],
  ['icon_128x128@2x.png',  256],
  ['icon_256x256.png',     256],
  ['icon_256x256@2x.png',  512],
  ['icon_512x512.png',     512],
  ['icon_512x512@2x.png',  1024],
];

const BG_COLOR = '#fff4ec';
const MASCOT_COLOR = '#c8614e';
// Apple's icon corner-radius ratio is ~22.37% of the icon side.
const CORNER_R_PCT = 22.37;

async function buildIconSvg() {
  // Mascot at native viewBox 110×87. Scale it to fill ~60% of a 1024×1024 canvas.
  const mascot = (await readFile(join(SVG_DIR, 'mascot-open.svg'), 'utf8'))
    .replaceAll(MASCOT_COLOR, MASCOT_COLOR); // no-op, but keeps intent explicit
  const bodyOnly = mascot
    .replace(/<\?xml[^>]*\?>/, '')
    .replace(/<svg[^>]*>/, '')
    .replace('</svg>', '');

  const SIDE = 1024;
  const R = (CORNER_R_PCT / 100) * SIDE;
  const MASCOT_W_DESIGN = 110;
  const MASCOT_H_DESIGN = 87;
  const SCALE = (SIDE * 0.62) / MASCOT_W_DESIGN; // ~62% of icon width
  const drawW = MASCOT_W_DESIGN * SCALE;
  const drawH = MASCOT_H_DESIGN * SCALE;
  const tx = (SIDE - drawW) / 2;
  const ty = (SIDE - drawH) / 2;

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIDE} ${SIDE}">
  <rect x="0" y="0" width="${SIDE}" height="${SIDE}" rx="${R}" ry="${R}" fill="${BG_COLOR}"/>
  <g transform="translate(${tx} ${ty}) scale(${SCALE})">
    ${bodyOnly}
  </g>
</svg>`;
}

async function main() {
  const svg = await buildIconSvg();

  await rm(ICONSET_DIR, { recursive: true, force: true });
  await mkdir(ICONSET_DIR, { recursive: true });

  for (const [name, size] of SIZES) {
    const png = new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render().asPng();
    await writeFile(join(ICONSET_DIR, name), png);
    process.stdout.write(`wrote ${name} (${size}px)\n`);
  }

  await mkdir(RESOURCES_DIR, { recursive: true });
  execFileSync('iconutil', ['-c', 'icns', '-o', ICNS_PATH, ICONSET_DIR], { stdio: 'inherit' });
  console.log(`built ${ICNS_PATH}`);
}

await main();
