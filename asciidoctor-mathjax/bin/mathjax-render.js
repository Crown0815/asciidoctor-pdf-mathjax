#!/usr/bin/env node
const mjAPI = require('mathjax-node');
const fs = require('fs');

mjAPI.config({ MathJax: {} });
mjAPI.start();

const mathExpression = process.argv[2];
const outputPath = process.argv[3];
const isBlock = process.argv[4] === 'true';

mjAPI.typeset({
  math: mathExpression,
  format: 'TeX',
  svg: true,
  display: isBlock
}, function (data) {
  if (!data.errors) {
    fs.writeFileSync(outputPath, data.svg);
    console.log(outputPath);
  } else {
    console.error('Error rendering math:', data.errors);
    process.exit(1);
  }
});
