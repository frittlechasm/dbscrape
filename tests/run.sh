#!/bin/bash

set -u

repoDir="$(cd "$(dirname "$0")/.." && pwd)"
fakeBin="$repoDir/tests/fake-bin"
testRoot="$(mktemp -d /tmp/dbscrape-tests.XXXXXX)" || exit 1
originalTables="$testRoot/original-tables"
passed=0
failed=0

function cleanupTests() {
  if [ -e /tmp/tables ]; then
    find /tmp/tables -depth -delete
  fi
  if [ -e "$originalTables" ]; then
    mv "$originalTables" /tmp/tables
  fi
  find "$testRoot" -depth -delete
}

if [ -L /tmp/tables ] || { [ -e /tmp/tables ] && { [ ! -d /tmp/tables ] || [ ! -O /tmp/tables ]; }; }; then
  echo "Cannot safely preserve existing /tmp/tables" >&2
  exit 1
fi
if [ -e /tmp/tables ]; then
  mv /tmp/tables "$originalTables" || exit 1
fi
trap cleanupTests EXIT

function beginCase() {
  local name="$1"

  TEST_STATE_DIR="$testRoot/$name"
  mkdir -p "$TEST_STATE_DIR/active"
  : > "$TEST_STATE_DIR/calls"
  printf "0\n" > "$TEST_STATE_DIR/max-active"
  TEST_EXPECTED_PASSWORD="p@ ss/word"
  export TEST_STATE_DIR TEST_EXPECTED_PASSWORD
}

function runCli() {
  TEST_SCENARIO="$1"
  shift
  export TEST_SCENARIO

  if PATH="$fakeBin:$PATH" "$repoDir/dbscrape" "$@" \
    > "$TEST_STATE_DIR/stdout" 2> "$TEST_STATE_DIR/stderr"; then
    CLI_STATUS=0
  else
    CLI_STATUS=$?
  fi
}

function assertEqual() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "$expected" != "$actual" ]; then
    echo "    $message: expected '$expected', got '$actual'" >&2
    return 1
  fi
}

function assertFile() {
  if [ ! -f "$1" ]; then
    echo "    missing file: $1" >&2
    return 1
  fi
}

function assertNoFile() {
  if [ -e "$1" ]; then
    echo "    unexpected file: $1" >&2
    return 1
  fi
}

function assertContains() {
  if ! grep -Fq "$1" "$2"; then
    echo "    '$1' not found in $2" >&2
    return 1
  fi
}

function testMissingArguments() {
  beginCase missing-arguments
  runCli happy
  [ "$CLI_STATUS" -ne 0 ] || return 1
  assertContains "Usage: dbscrape" "$TEST_STATE_DIR/stderr"
}

function testStructuredMetadata() {
  beginCase metadata
  runCli happy user "$TEST_EXPECTED_PASSWORD" localhost app
  assertEqual 0 "$CLI_STATUS" "metadata status" || return 1
  assertFile /tmp/tables/users/full-details.txt || return 1
  assertFile /tmp/tables/audit.Events/columns.txt || return 1
  assertEqual "column_id" "$(sed -n '1p' /tmp/tables/users/columns.txt)" "first column" || return 1
  assertContains 'audit."Events"' /tmp/tables/tables.txt || return 1
  assertContains "DB Scraped!!" "$TEST_STATE_DIR/stdout"
}

function testSnapshotsAndFailures() {
  beginCase snapshots
  runCli happy user "$TEST_EXPECTED_PASSWORD" localhost app
  assertEqual 0 "$CLI_STATUS" "initial snapshot status" || return 1

  runCli detail-failure user "$TEST_EXPECTED_PASSWORD" localhost app
  [ "$CLI_STATUS" -ne 0 ] || return 1
  assertFile /tmp/tables/users/columns.txt || return 1

  runCli replacement user "$TEST_EXPECTED_PASSWORD" localhost app
  assertEqual 0 "$CLI_STATUS" "replacement status" || return 1
  assertFile /tmp/tables/orders/columns.txt || return 1
  assertNoFile /tmp/tables/users || return 1

  runCli list-failure user "$TEST_EXPECTED_PASSWORD" localhost app
  [ "$CLI_STATUS" -ne 0 ] || return 1
  assertFile /tmp/tables/orders/columns.txt
}

function testUnsafeNames() {
  beginCase unsafe
  runCli unsafe user "$TEST_EXPECTED_PASSWORD" localhost app
  [ "$CLI_STATUS" -ne 0 ] || return 1
  assertNoFile /tmp/escape
}

function testConcurrencyLimit() {
  beginCase concurrency
  runCli concurrency user "$TEST_EXPECTED_PASSWORD" localhost app
  assertEqual 0 "$CLI_STATUS" "concurrency status" || return 1
  assertEqual 5 "$(sed -n '1p' "$TEST_STATE_DIR/max-active")" "maximum concurrent jobs" || return 1
  assertFile /tmp/tables/table6/columns.txt
}

function testEmptyDatabase() {
  beginCase empty
  runCli empty user "$TEST_EXPECTED_PASSWORD" localhost app
  assertEqual 0 "$CLI_STATUS" "empty database status" || return 1
  assertFile /tmp/tables/tables.txt || return 1
  assertEqual 0 "$(wc -l < /tmp/tables/tables.txt | tr -d ' ')" "empty table list"
}

function runTest() {
  local name="$1"
  local testFunction="$2"

  if "$testFunction"; then
    passed=$((passed + 1))
    echo "PASS $name"
  else
    failed=$((failed + 1))
    echo "FAIL $name"
  fi
}

runTest "missing arguments" testMissingArguments
runTest "structured metadata" testStructuredMetadata
runTest "snapshots and failures" testSnapshotsAndFailures
runTest "unsafe names" testUnsafeNames
runTest "five-job concurrency limit" testConcurrencyLimit
runTest "empty database" testEmptyDatabase

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
