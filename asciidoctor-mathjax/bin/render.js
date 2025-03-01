#!/usr/bin/env node

const mjAPI = require("mathjax-node");
const fs = require("fs");

mjAPI.config({
  MathJax: {
    // Default configuration
    SVG: {
      font: "TeX", // Default font, can be adjusted if needed
      scale: 100   // Default scaling (100%)
    }
  }
});
mjAPI.start();

// Get command-line arguments
const fontSize = parseFloat(process.argv[2]) || 12;
const expression = process.argv[3]; // LaTeX expression
const outputFile = process.argv[4]; // Output SVG path

// Validate input
if (!expression || !outputFile) {
  console.error("Usage: node render.js <fontSize> <expression> <outputFile>");
  console.error("Example: node render.js 12 \"\\frac{1}{2}\" output.svg");
  process.exit(1);
}

// Calculate ex size based on font size
// 1ex ≈ 0.5em, and we assume 1pt input = 1pt base size
// MathJax default is 6pt per ex, so we scale accordingly
const baseEx = 6; // MathJax default ex size in points
const exSize = (fontSize / 12) * baseEx; // Scale ex relative to 12pt base

mjAPI.typeset({
  math: expression,
  format: "TeX",
  svg: true,
  ex: exSize,    // Adjusted ex size based on font input
  width: 100,    // Arbitrary large width to avoid clipping
}, function (data) {
  if (!data.errors) {
    // Optionally adjust SVG viewBox to reflect font size scaling
    let svg = data.svg;
    // Add font size attribute to SVG for reference (optional)
    svg = svg.replace('<svg ', `<svg font-size="${fontSize}pt" `);
    fs.writeFileSync(outputFile, svg);
    console.log(`SVG written to ${outputFile} with font size ${fontSize}pt`);
  } else {
    console.error("MathJax error:", data.errors);
    process.exit(1);
  }
});
