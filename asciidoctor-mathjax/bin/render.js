#!/usr/bin/env node

const mj = require('mathjax-node');
mj.config({
  MathJax: {
    // MathJax configuration
  }
});
mj.start();

async function convertToSvg(latex, format) {
  const data = await mj.typeset({
    math: latex,
    format: format,
    svg: true,
  });
  return data.svg;
}

const latex = process.argv[2];
const format = process.argv[3];
convertToSvg(latex, format).then(svg => {
  console.log(svg);
}).catch(err => console.error(err));
