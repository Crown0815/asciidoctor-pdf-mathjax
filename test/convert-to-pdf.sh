#! /bin/bash

set -euo pipefail

asciidoctor-pdf \
      --require asciidoctor-mathjax \
      --attribute stem=latexmath \
      --attribute imagesdir="${PWD}/media" \
      --failure-level=INFO \
      --verbose \
      --trace \
      "$1"
