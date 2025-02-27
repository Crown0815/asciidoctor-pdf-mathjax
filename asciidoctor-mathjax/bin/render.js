const mjAPI = require("mathjax-node");
const fs = require("fs");

mjAPI.config({
  MathJax: {
    // Default configuration
  }
});
mjAPI.start();

// Get command-line arguments
const fontSize = process.argv[2]; // e.g., "12" (in pt)
const expression = process.argv[3]; // LaTeX expression
const outputFile = process.argv[4]; // Output SVG path

mjAPI.typeset({
  math: expression,
  format: "TeX",
  svg: true,
  ex: 6, // Base em size (6pt per ex, roughly matches 12pt base font)
  width: 100, // Arbitrary large width to avoid clipping
}, function (data) {
  if (!data.errors) {
    fs.writeFileSync(outputFile, data.svg);
  } else {
    console.error("MathJax error:", data.errors);
    process.exit(1);
  }
});
