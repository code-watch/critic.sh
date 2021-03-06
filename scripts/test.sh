#!/usr/bin/env bash

_trimColors() {
  while read -r line; do
    # shellcheck disable=2001
    sed "s,$(printf '\033')\\[[0-9;]*[a-zA-Z],,g" <<< "$line"
  done
}

_trimOutput() {
  while read -r line; do
    echo "$line" | awk '{$1=$1;print}' | awk /./
  done
}

_abspath() {
  # shellcheck disable=2164
  echo "$(cd "$(dirname "$1")"; pwd)"
}

_runTest() {
  local file="$1"
  local expectedCode="${2:-}"

  output="$(bash "$file")"
  code=$?

  if [ $code -eq "$expectedCode" ]; then
    echo "Exit codes match"
  else
    echo "Exit codes do not match. Actual: $code, expected: $expectedCode"
    exitCode=$code
  fi
}

exitCode=0
export CRITIC_COVERAGE_REPORT_HTML=false

echo -e "\n--- Coverage report"
_runTest "examples/test.sh" 1

expectedCoverage="$(cat <<EOF
$(pwd)/examples/lib.sh
Total LOC: 19
Covered LOC: 3
Coverage %: 50
Ignored LOC: 5
Uncovered Lines: 21 22 30
[critic] Tests completed. Passed: 7, Failed: 1
EOF
)"

if ! diff -bBEi \
  <(sed -n -e '/\[critic\] Coverage Report/,$p' <<< "$output" | _trimColors | _trimOutput | tail -n +2) \
  <(echo "$expectedCoverage"); then
  exitCode=1
else
  echo "Coverage report matches"
fi

echo -e "\n--- _output_contains"
expectedOutput="$(cat <<EOF
readme
Should print readme
PASS ✔ : Readme contains options
PASS ✔ : Output contains 'critic.sh'
EOF
)"
if ! diff -bBEi \
  <(echo "$output" | _trimColors | awk '/^readme/,/^ *$/' | _trimOutput) \
  <(echo "$expectedOutput"); then
  exitCode=1
else
  echo "Output matches"
fi

echo -e "\n--- _describe_skip"
_runTest "scripts/fixtures/describe-skip.sh" 0
expectedOutput="$(cat <<EOF
foo
Should print foo
PASS ✔ : Output equals 'foo'

echo_first (skip)
Should get the correct number of args (skip)

custom expression
Should test custom expression
PASS ✔ : [ 1 -eq 1 ]
PASS ✔ : Two should be equal to two

[critic] Coverage Report

$(pwd)/examples/lib.sh
Total LOC: 19
Covered LOC: 1
Coverage %: 16
Ignored LOC: 5
Uncovered Lines: 10 21 22 26 30

[critic] Tests completed. Passed: 3, Failed: 0
EOF
)"

if ! diff -bBEi \
  <(echo "$output" | _trimColors | _trimOutput) \
  <(echo "$expectedOutput"); then
  exitCode=1
else
  echo "Output matches"
fi


echo -e "\n--- _test_skip"
_runTest "scripts/fixtures/test-skip.sh" 0
expectedOutput="$(cat <<EOF
foo
Should print foobar (skip)
Should print foo
PASS ✔ : Output equals 'foo'

echo_first
Should get the correct number of args (skip)

custom expression
Should test custom expression
PASS ✔ : [ 1 -eq 1 ]
PASS ✔ : Two should be equal to two

[critic] Coverage Report

$(pwd)/examples/lib.sh
Total LOC: 19
Covered LOC: 1
Coverage %: 16
Ignored LOC: 5
Uncovered Lines: 10 21 22 26 30

[critic] Tests completed. Passed: 3, Failed: 0
EOF
)"

if ! diff -bBEi \
  <(echo "$output" | _trimColors | _trimOutput) \
  <(echo "$expectedOutput"); then
  exitCode=1
else
  echo "Output matches"
fi

exit $exitCode
