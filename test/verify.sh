#! /bin/bash

function convert {
  local file="$1"
  asciidoctor-pdf \
    --require asciidoctor-mathjax \
    --attribute root="${PWD}" \
    --failure-level=INFO \
    --trace \
    "./verification/$file.adoc"
}

function verify {
  local test_case="$1"
  local received=./verification/"$test_case".pdf
  local verified=./verification/"$test_case".verified.pdf
  local diff=./verification/"$test_case".diff.pdf

  if xvfb-run diff-pdf --output-diff="$diff" "$received" "$verified" ; then
    rm "$diff"
    echo "PASS: Verification of $test_case.adoc"
  else
    >&2 echo "FAILED: Verification of $test_case.adoc"
  fi
}


gem install ./asciidoctor-mathjax-test.gem

for file in "$@"; do
  convert "$file"
  verify "$file"
done
