source ./.run-tests.sh

function verify {
  local test_case="$1"
  local received=./verification/"$test_case".pdf
  local verified=./verification/"$test_case".verified.pdf
  local diff=./verification/"$test_case".diff.pdf

  if diff-pdf --output-diff="$diff" "$received" "$verified" ; then
      echo "PASS: Verification of $test_case.adoc"
  else
      >&2 echo "FAILED: Verification of $test_case.adoc"
  fi
}

verify asciimath
verify latex
verify stem_asciimath
verify stem_latex
