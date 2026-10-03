#!/usr/bin/env node

const mj = require('mathjax-node');

// Two modes:
//   render.js <latex> <format> <pixels_per_ex> <font>
//     renders one formula, prints the SVG and exits.
//   render.js --server <font>
//     starts MathJax once and renders one formula per line of stdin,
//     {"math": "...", "format": "TeX", "ex": 6}, answering with one line
//     per formula, {"svg": "..."} or {"error": "..."}.
// Starting MathJax takes seconds; the server mode pays that once per font
// instead of once per formula.
const server = process.argv[2] === '--server';
const font = server ? process.argv[3] : process.argv[5];

mj.config({
  MathJax: {
    SVG: {
      font: font
    }
  }
});
mj.start();

async function convertToSvg(latex, format, pixels_per_ex) {
  const data = await mj.typeset({
    ex: pixels_per_ex,
    math: latex,
    format: format,
    svg: true,
  });
  return data.svg;
}

if (server) {
  let queue = Promise.resolve();
  require('readline').createInterface({ input: process.stdin }).on('line', line => {
    queue = queue.then(async () => {
      let answer;
      try {
        const request = JSON.parse(line);
        answer = { svg: await convertToSvg(request.math, request.format, request.ex) };
      } catch (err) {
        answer = { error: String(err) };
      }
      process.stdout.write(JSON.stringify(answer) + '\n');
    });
  });
} else {
  const latex = process.argv[2];
  const format = process.argv[3];
  const pixels_per_ex = parseInt(process.argv[4]);

  convertToSvg(latex, format, pixels_per_ex).then(svg => {
    console.log(svg);
  }).catch(err => console.error(err));
}
