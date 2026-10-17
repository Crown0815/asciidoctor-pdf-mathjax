#!/usr/bin/env node

// Two modes:
//   render.js <latex> <format> <pixels_per_ex> <font>
//     renders one formula, prints the SVG and exits.
//   render.js --server <font>
//     starts MathJax once and renders one formula per line of stdin,
//     {"math": "...", "format": "TeX", "ex": 6}, answering with one line
//     per formula, {"svg": "..."} or {"error": "..."}.
// Starting MathJax takes seconds; the server mode pays that once per font
// instead of once per formula.
//
// Font names are MathJax 4 names (mathjax-tex, mathjax-stix2, ...).
// The MathJax 2 names previously passed to mathjax-node are still accepted.

const server = process.argv[2] === '--server';
const fontArg = server ? process.argv[3] : process.argv[5];

const LEGACY_FONTS = {
  'TeX': 'mathjax-tex',
  'STIX-Web': 'mathjax-stix2',
  'Asana-Math': 'mathjax-asana',
  'Neo-Euler': 'mathjax-euler',
  'Gyre-Pagella': 'mathjax-pagella',
  'Gyre-Termes': 'mathjax-termes',
  'Latin-Modern': 'mathjax-modern',
};

function resolveFont(name) {
  const requested = (name && String(name).trim()) || 'TeX';
  const font = LEGACY_FONTS[requested] || requested;
  // Neo Euler ships as a font extension in MathJax 4, not a standalone font.
  if (font === 'mathjax-euler') {
    return { font: 'mathjax-tex', fontExtensions: ['mathjax-euler'] };
  }
  return { font: font, fontExtensions: [] };
}

function assertInstalled(packageName) {
  try {
    // Font packages export no main entry, so resolve a file they do export.
    require.resolve(packageName + '/package.json');
  } catch (err) {
    throw new Error(
      `Cannot load ${packageName}. Install MathJax 4 with npm, for example: npm install ${packageName}@4`
    );
  }
}

const { font, fontExtensions } = resolveFont(fontArg);

let MathJax;
try {
  assertInstalled('@mathjax/src');
  assertInstalled(`@mathjax/${font}-font`);
  fontExtensions.forEach((extension) => assertInstalled(`@mathjax/${extension}-font-extension`));
  MathJax = require('@mathjax/src');
} catch (err) {
  console.error(err.message);
  process.exit(1);
}

function convertToSvg(latex, format, pixelsPerEx) {
  const display = format !== 'inline-TeX';
  const ex = Number(pixelsPerEx) || 6;
  return MathJax.tex2svgPromise(latex, {
    display: display,
    em: ex * 2,
    ex: ex,
    // Formulas are embedded at their natural width. A wide container keeps
    // MathJax from inserting line breaks when a width is still consulted.
    containerWidth: 100000,
  }).then((node) => {
    const adaptor = MathJax.startup.adaptor;
    const svg = adaptor.tags(node, 'svg')[0];
    if (!svg) {
      throw new Error('MathJax produced no SVG');
    }
    const xml = adaptor.serializeXML(svg);
    const mathError = xml.match(/data-mjx-error="([^"]*)"/);
    if (mathError) {
      throw new Error(mathError[1]);
    }
    return xml;
  });
}

MathJax.init({
  loader: {
    load: ['input/tex', 'output/svg'],
    // Font packages can report an older component version than MathJax itself.
    versionWarnings: false,
  },
  output: {
    font: font,
    fontExtensions: fontExtensions,
    displayOverflow: 'overflow',
    linebreaks: { inline: false },
  },
  svg: {
    fontCache: 'local',
  },
  startup: {
    typeset: false,
  },
}).then(() => {
  if (server) {
    let queue = Promise.resolve();
    const input = require('readline').createInterface({ input: process.stdin });
    input.on('line', (line) => {
      queue = queue.then(async () => {
        let answer;
        try {
          const request = JSON.parse(line);
          answer = { svg: await convertToSvg(request.math, request.format, request.ex) };
        } catch (err) {
          answer = { error: String(err && err.message ? err.message : err) };
        }
        process.stdout.write(JSON.stringify(answer) + '\n');
      });
    });
    input.on('close', () => {
      queue.then(() => {
        if (MathJax.done) MathJax.done();
      });
    });
  } else {
    const latex = process.argv[2];
    const format = process.argv[3];
    const pixelsPerEx = parseInt(process.argv[4], 10);
    return convertToSvg(latex, format, pixelsPerEx).then((svg) => {
      process.stdout.write(svg + '\n');
      if (MathJax.done) MathJax.done();
    });
  }
}).catch((err) => {
  console.error(err && err.message ? err.message : err);
  process.exit(1);
});
