#! /bin/bash

gem install ./asciidoctor-mathjax-test.gem

for file in "$@"; do
  asciidoctor-pdf \
    --require asciidoctor-mathjax \
    --attribute root=${PWD} \
    --failure-level=INFO \
    --verbose \
    --trace \
    "$file"
done
