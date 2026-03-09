#!/usr/bin/env bats
# e2e/statusline-flow.bats
# End-to-end flow tests for sts-statusline.sh
#
# Simulates the full visual progression as STS approaches expiry:
#   no file → far future (green/empty) → 30m (yellow/half) → 5m (red/full) → expired

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

strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# ─── stage 0: no file ──────────────────────────────────────────

@test "flow stage 0: no .sts_expiry produces empty output (status bar hidden)" {
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ─── stage 1: far future (>1h) ─────────────────────────────────

@test "flow stage 1: 2 hours remaining shows empty bar with green color" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"[STS]"* ]]
  [[ "$plain" == *"░░░░░░░░░░"* ]]
  [[ "$plain" != *"█"* ]]
  [[ "$output" == *$'\033[32m'* ]]
}

@test "flow stage 1: output includes remaining hours in time text" {
  expiry_after 5400 > "$TEST_HOME/.sts_expiry"   # 1h30m
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"시간"* ]]
}

# ─── stage 2: under 1 hour (yellow) ───────────────────────────

@test "flow stage 2: 30 minutes remaining shows half-filled bar with yellow" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"█████░░░░░"* ]]
  [[ "$output" == *$'\033[33m'* ]]
}

@test "flow stage 2: time text shows minutes remaining" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"30분"* ]]
}

@test "flow stage 2: KST expiry time is present in output" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" =~ [0-9]{2}/[0-9]{2}\ [0-9]{2}:[0-9]{2}\ KST ]]
}

# ─── stage 3: under 10 minutes (red) ──────────────────────────

@test "flow stage 3: 5 minutes remaining shows nearly full bar with red" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"█████████░"* ]]
  [[ "$output" == *$'\033[31m'* ]]
}

@test "flow stage 3: time text shows minutes and seconds" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"5분 0초 남음"* ]]
}

# ─── stage 4: expired ──────────────────────────────────────────

@test "flow stage 4: expired shows full bar with bold red" {
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"██████████"* ]]
  [[ "$plain" != *"░"* ]]
  [[ "$output" == *$'\033[1;31m'* ]]
}

@test "flow stage 4: expired time text says expired" {
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"만료됨"* ]]
}

# ─── progression consistency ───────────────────────────────────

@test "flow progression: bar fill increases as expiry approaches" {
  # 2h remaining → 0 filled blocks
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  count_far=$(echo "$output" | strip_ansi | tr -cd '█' | wc -c | tr -d ' ')

  # 30m remaining → 5 filled blocks
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  count_mid=$(echo "$output" | strip_ansi | tr -cd '█' | wc -c | tr -d ' ')

  # expired → 10 filled blocks
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  count_exp=$(echo "$output" | strip_ansi | tr -cd '█' | wc -c | tr -d ' ')

  [ "$count_far" -lt "$count_mid" ]
  [ "$count_mid" -lt "$count_exp" ]
}

@test "flow progression: re-issuing STS resets bar to empty" {
  # start expired
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain_expired=$(echo "$output" | strip_ansi)
  [[ "$plain_expired" == *"██████████"* ]]

  # re-issue: far future
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT" <<< ""
  plain_fresh=$(echo "$output" | strip_ansi)
  [[ "$plain_fresh" == *"░░░░░░░░░░"* ]]
  [[ "$plain_fresh" != *"█"* ]]
}

@test "flow: script accepts stdin JSON without error (Claude Code compatibility)" {
  expiry_after 3600 > "$TEST_HOME/.sts_expiry"
  json='{"model":{"display_name":"Opus"},"context_window":{"used_percentage":25}}'
  run bash "$SCRIPT" <<< "$json"
  [ "$status" -eq 0 ]
  plain=$(echo "$output" | strip_ansi)
  [[ "$plain" == *"[STS]"* ]]
}
