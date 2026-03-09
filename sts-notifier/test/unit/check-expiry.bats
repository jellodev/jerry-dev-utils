#!/usr/bin/env bats
# unit/check-expiry.bats
# Unit tests for check-sts-expiry.sh
#
# Isolation:
#   - HOME=<tmpdir>          : isolate state files
#   - mock osascript in PATH : capture notification calls

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/check-sts-expiry.sh"

setup() {
  TEST_HOME="$(mktemp -d)"
  MOCK_BIN="$(mktemp -d)"

  # osascript mock: record call args to a file
  cat > "$MOCK_BIN/osascript" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$BATS_TMPDIR/osascript_calls"
EOF
  chmod +x "$MOCK_BIN/osascript"

  export HOME="$TEST_HOME"
  export PATH="$MOCK_BIN:$PATH"
  rm -f "$BATS_TMPDIR/osascript_calls"
}

teardown() {
  rm -rf "$TEST_HOME" "$MOCK_BIN"
}

# helper: UTC ISO8601 timestamp offset seconds from now
expiry_after() {
  python3 -c "
import datetime
dt = datetime.datetime.utcnow() + datetime.timedelta(seconds=$1)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
"
}

# ─── missing / empty / invalid file ────────────────────────────

@test "no .sts_expiry file: exits 0 with no notification" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TMPDIR/osascript_calls" ]
}

@test "empty .sts_expiry file: exits 0 with no notification" {
  touch "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TMPDIR/osascript_calls" ]
}

@test "invalid date in .sts_expiry: exits 1 with no notification" {
  echo "not-a-date" > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [ ! -f "$BATS_TMPDIR/osascript_calls" ]
}

# ─── more than 1 hour remaining ────────────────────────────────

@test "2 hours remaining: no notification sent" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TMPDIR/osascript_calls" ]
}

# ─── 1-hour warning ────────────────────────────────────────────

@test "30 minutes remaining: sends 1h warning notification" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "AWS STS" "$BATS_TMPDIR/osascript_calls"
}

@test "1h notification: creates ~/.sts_notified_1h file" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  bash "$SCRIPT"
  [ -f "$TEST_HOME/.sts_notified_1h" ]
}

@test "1h notification: suppressed when ~/.sts_notified_1h exists" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  touch "$TEST_HOME/.sts_notified_1h"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TMPDIR/osascript_calls" ]
}

# ─── 10-minute warning ─────────────────────────────────────────

@test "5 minutes remaining: sends 10m urgent notification" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "AWS STS" "$BATS_TMPDIR/osascript_calls"
}

@test "10m notification: creates ~/.sts_notified_10m file" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  bash "$SCRIPT"
  [ -f "$TEST_HOME/.sts_notified_10m" ]
}

@test "10m notification: suppressed when ~/.sts_notified_10m exists" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  touch "$TEST_HOME/.sts_notified_10m"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TMPDIR/osascript_calls" ]
}

@test "under 10m with 1h flag present: still sends 10m notification" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  touch "$TEST_HOME/.sts_notified_1h"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "AWS STS" "$BATS_TMPDIR/osascript_calls"
}

# ─── expired ───────────────────────────────────────────────────

@test "already expired: sends expired notification" {
  expiry_after -600 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "AWS STS" "$BATS_TMPDIR/osascript_calls"
}

@test "expired notification: creates ~/.sts_notified_expired file" {
  expiry_after -600 > "$TEST_HOME/.sts_expiry"
  bash "$SCRIPT"
  [ -f "$TEST_HOME/.sts_notified_expired" ]
}

@test "expired notification: suppressed when ~/.sts_notified_expired exists" {
  expiry_after -600 > "$TEST_HOME/.sts_expiry"
  touch "$TEST_HOME/.sts_notified_expired"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TMPDIR/osascript_calls" ]
}

# ─── boundary values ───────────────────────────────────────────

@test "exactly 3600 seconds remaining: sends 1h notification" {
  expiry_after 3600 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "AWS STS" "$BATS_TMPDIR/osascript_calls"
}

@test "exactly 600 seconds remaining: sends 10m notification" {
  expiry_after 600 > "$TEST_HOME/.sts_expiry"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "AWS STS" "$BATS_TMPDIR/osascript_calls"
}
