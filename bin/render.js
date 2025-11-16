#!/usr/bin/env node

const mj = require('mathjax-node');

const latex = process.argv[2];
const format = process.argv[3];
const pixels_per_ex = parseInt(process.argv[4]);
const font = process.argv[5] || "TeX";

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

convertToSvg(latex, format, pixels_per_ex).then(svg => {
  console.log(svg);
}).catch(err => console.error(err));
