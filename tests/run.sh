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
  TEST_EXPECTED_HOST="localhost"
  TEST_EXPECTED_PORT=""
  export TEST_STATE_DIR TEST_EXPECTED_PASSWORD TEST_EXPECTED_HOST TEST_EXPECTED_PORT
}

function runCli() {
  TEST_SCENARIO="$1"
  shift
  export TEST_SCENARIO

  if PGPASSWORD="$TEST_EXPECTED_PASSWORD" PATH="$fakeBin:$PATH" "$repoDir/dbscrape" "$@" \
    > "$TEST_STATE_DIR/stdout" 2> "$TEST_STATE_DIR/stderr"; then
    CLI_STATUS=0
  else
    CLI_STATUS=$?
  fi
}

function runCliWithoutPassword() {
  TEST_SCENARIO="$1"
  shift
  export TEST_SCENARIO

  if env -u PGPASSWORD PATH="$fakeBin:$PATH" "$repoDir/dbscrape" "$@" \
    < /dev/null > "$TEST_STATE_DIR/stdout" 2> "$TEST_STATE_DIR/stderr"; then
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

function testNonInteractivePassword() {
  beginCase non-interactive-password
  runCliWithoutPassword happy user localhost app
  [ "$CLI_STATUS" -ne 0 ] || return 1
  assertContains "Password required: set PGPASSWORD" "$TEST_STATE_DIR/stderr"
}

function testStructuredMetadata() {
  beginCase metadata
  TEST_EXPECTED_PORT="5433"
  export TEST_EXPECTED_PORT
  runCli happy user localhost:5433 app
  assertEqual 0 "$CLI_STATUS" "metadata status" || return 1
  assertFile /tmp/tables/users/full-details.txt || return 1
  assertFile /tmp/tables/audit.Events/columns.txt || return 1
  assertEqual "column_id" "$(sed -n '1p' /tmp/tables/users/columns.txt)" "first column" || return 1
  assertContains 'audit."Events"' /tmp/tables/tables.txt || return 1
  assertContains "DB Scraped!!" "$TEST_STATE_DIR/stdout"
}

function testOrdinaryTablesOnly() {
  beginCase ordinary-tables
  runCli happy user localhost app
  assertEqual 0 "$CLI_STATUS" "ordinary table status" || return 1
  assertContains "c.relkind = 'r'" "$TEST_STATE_DIR/calls" || return 1
  assertContains "NOT c.relispartition" "$TEST_STATE_DIR/calls"
}

function testSnapshotsAndFailures() {
  beginCase snapshots
  runCli happy user localhost app
  assertEqual 0 "$CLI_STATUS" "initial snapshot status" || return 1

  runCli detail-failure user localhost app
  [ "$CLI_STATUS" -ne 0 ] || return 1
  assertFile /tmp/tables/users/columns.txt || return 1

  runCli replacement user localhost app
  assertEqual 0 "$CLI_STATUS" "replacement status" || return 1
  assertFile /tmp/tables/orders/columns.txt || return 1
  assertNoFile /tmp/tables/users || return 1

  runCli list-failure user localhost app
  [ "$CLI_STATUS" -ne 0 ] || return 1
  assertFile /tmp/tables/orders/columns.txt
}

function testLegalIdentifiers() {
  beginCase identifiers
  runCli identifiers user localhost app
  assertEqual 0 "$CLI_STATUS" "legal identifier status" || return 1
  assertFile /tmp/tables/.identifiers/public/Order-Items/columns.txt || return 1
  assertFile /tmp/tables/.identifiers/public/Order%2dItems/columns.txt || return 1
  assertFile /tmp/tables/.identifiers/sales-data/path%2ftable/columns.txt || return 1
  assertFile /tmp/tables/.identifiers/public/%2e/columns.txt || return 1
  assertFile /tmp/tables/.identifiers/public/caf%c3%a9/columns.txt || return 1
  assertFile /tmp/tables/.identifiers/public/100%25-done/columns.txt || return 1
  assertFile /tmp/tables/.identifiers/public/line%0abreak/columns.txt || return 1
  assertFile /tmp/tables/.identifiers/public/say%22hi/columns.txt || return 1
  assertContains 'public."Order Items"' /tmp/tables/tables.txt || return 1
  assertContains '"sales data"."path/table"' /tmp/tables/tables.txt
}

function testConcurrencyLimit() {
  beginCase concurrency
  runCli concurrency user localhost app
  assertEqual 0 "$CLI_STATUS" "concurrency status" || return 1
  assertEqual 5 "$(sed -n '1p' "$TEST_STATE_DIR/max-active")" "maximum concurrent jobs" || return 1
  assertFile /tmp/tables/table6/columns.txt
}

function testEmptyDatabase() {
  beginCase empty
  runCli empty user localhost app
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
runTest "non-interactive password requirement" testNonInteractivePassword
runTest "structured metadata" testStructuredMetadata
runTest "ordinary tables only" testOrdinaryTablesOnly
runTest "snapshots and failures" testSnapshotsAndFailures
runTest "legal PostgreSQL identifiers" testLegalIdentifiers
runTest "five-job concurrency limit" testConcurrencyLimit
runTest "empty database" testEmptyDatabase

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
