#!/usr/bin/env node

const mj = require('mathjax-node');
mj.config({
  MathJax: {
    // MathJax configuration
  }
});
mj.start();

const fs = require('fs');

async function convertToSvg(latex) {
  const data = await mj.typeset({
    math: latex,
    format: 'TeX',
    svg: true,
  });
  return data.svg;
}

const latex = process.argv[2];
convertToSvg(latex).then(svg => {
  console.log(svg);
}).catch(err => console.error(err));
