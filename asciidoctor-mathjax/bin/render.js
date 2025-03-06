#!/usr/bin/env node

const mj = require('mathjax-node');
mj.config({
  MathJax: {
    // MathJax configuration
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

const latex = process.argv[2];
const format = process.argv[3];
const pixels_per_ex = parseInt(process.argv[4]);
convertToSvg(latex, format, pixels_per_ex).then(svg => {
  console.log(svg);
}).catch(err => console.error(err));
