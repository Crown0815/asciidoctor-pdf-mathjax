#! /bin/bash

set -euo pipefail

gem install ./asciidoctor-mathjax-test.gem

asciidoctor-pdf \
      --require asciidoctor-mathjax \
      --attribute stem=latexmath \
      --attribute imagesdir="${PWD}/media" \
      --failure-level=INFO \
      --verbose \
      --trace \
      "$1"
