#! /bin/bash

function convert {
  local test_file="$1"
  asciidoctor-pdf \
    --require asciidoctor-pdf-mathjax \
    --attribute root="${PWD}" \
    --failure-level=INFO \
    --trace \
    "$test_file"
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
    return 1
  fi
}


gem install ./asciidoctor-pdf-mathjax-test.gem
tests=0
success=0

export -f convert

echo "Running tests..."
find "$1"/[!_]*.adoc | parallel --will-cite --halt-on-error 2 convert {}
for file in "$1"/[!_]*.adoc; do
  (( tests+=1 ))
  test_case="${file%.adoc}"
  verify "$test_case" && (( success+=1 ))
done
echo "Passed ($success/$tests) tests!"
exit $(( tests-success ))
