#!/usr/bin/env bats
# unit/statusline.bats
# Unit tests for sts-statusline.sh
#
# Isolation: HOME=<tmpdir> per test

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/sts-statusline.sh"

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
}

teardown() {
  rm -rf "$TEST_HOME"
}

expiry_after() {
  python3 -c "
import datetime
dt = datetime.datetime.utcnow() + datetime.timedelta(seconds=$1)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
"
}

# strip ANSI escape codes for plain-text assertions
strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# ─── no expiry file ────────────────────────────────────────────

@test "no .sts_expiry: outputs nothing" {
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty .sts_expiry: outputs nothing" {
  touch "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ─── output structure ─────────────────────────────────────────

@test "output contains [STS] label" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"[STS]"* ]]
}

@test "output contains KST expiry time" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"KST"* ]]
}

@test "output expiry time is in MM/DD HH:MM format" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  # match pattern like "03/10 09:20 KST"
  [[ "$plain" =~ [0-9]{2}/[0-9]{2}\ [0-9]{2}:[0-9]{2}\ KST ]]
}

# ─── progress bar content ─────────────────────────────────────

@test "more than 1 hour remaining: bar is all empty blocks" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  # bar should be 10 empty blocks (░), 0 filled (█)
  [[ "$plain" == *"░░░░░░░░░░"* ]]
  [[ "$plain" != *"█"* ]]
}

@test "30 minutes remaining: bar is half filled" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  # 1800s remaining out of 3600 → elapsed=1800 → 5 filled blocks
  [[ "$plain" == *"█████░░░░░"* ]]
}

@test "5 minutes remaining: bar is nearly full (9 filled)" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  # 300s remaining → elapsed=3300 → 9 filled blocks
  [[ "$plain" == *"█████████░"* ]]
}

@test "already expired: bar is completely full" {
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"██████████"* ]]
  [[ "$plain" != *"░"* ]]
}

# ─── time text ────────────────────────────────────────────────

@test "more than 1 hour: time text shows hours and minutes" {
  expiry_after 5400 > "$TEST_HOME/.sts_expiry"   # 1h 30m
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"시간"* ]]
}

@test "under 1 hour: time text shows minutes and seconds" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"   # 30m
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"분"* ]]
}

@test "under 1 minute: time text shows seconds only" {
  expiry_after 45 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"초 남음"* ]]
}

@test "expired: time text says expired" {
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"만료됨"* ]]
}

# ─── color codes ──────────────────────────────────────────────

@test "more than 1 hour: output contains green color code" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  # green = \033[32m
  [[ "$output" == *$'\033[32m'* ]]
}

@test "under 1 hour: output contains yellow color code" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  # yellow = \033[33m
  [[ "$output" == *$'\033[33m'* ]]
}

@test "under 10 minutes: output contains red color code" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  # red = \033[31m
  [[ "$output" == *$'\033[31m'* ]]
}

@test "expired: output contains bold red color code" {
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  # bold red = \033[1;31m
  [[ "$output" == *$'\033[1;31m'* ]]
}
