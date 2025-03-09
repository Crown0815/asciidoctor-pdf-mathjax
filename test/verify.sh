#! /bin/bash

function convert {
  local test_file="$1"
  if asciidoctor-pdf \
    --require asciidoctor-mathjax \
    --attribute root="${PWD}" \
    --failure-level=INFO \
    --trace \
    "$test_file"; then
    echo "PASS: Conversion of $test_file.adoc"
  else
    >&2 echo "FAILED: Conversion of $test_file.adoc"
  fi
}

function verify {
  local test_file="$1"
  local received="$test_file".pdf
  local verified="$test_file".verified.pdf
  local diff="$test_file".diff.pdf

  if xvfb-run diff-pdf --output-diff="$diff" "$received" "$verified" ; then
    rm "$diff"
    echo "PASS: Verification of $test_file.adoc"
  else
    >&2 echo "FAILED: Verification of $test_file.adoc"
  fi
}


gem install ./asciidoctor-mathjax-test.gem

export -f test
export -f convert
export -f verify

echo "Running tests..."
find "$1"/[!_]*.adoc | parallel --will-cite --halt-on-error 2 convert {}
for file in "$1"/[!_]*.adoc; do
  test_case="${file%.adoc}"
  verify "$test_case"
done
echo "Completed tests!"
