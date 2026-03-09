#!/usr/bin/env bats
# e2e/notifier-flow.bats
# End-to-end flow tests for check-sts-expiry.sh
#
# Simulates the full lifecycle:
#   STS issued (far future) → 1h warning → 10m warning → expired → re-issued

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/check-sts-expiry.sh"

setup() {
  TEST_HOME="$(mktemp -d)"
  MOCK_BIN="$(mktemp -d)"
  CALLS_LOG="$BATS_TMPDIR/osascript_calls"

  cat > "$MOCK_BIN/osascript" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$BATS_TMPDIR/osascript_calls"
EOF
  chmod +x "$MOCK_BIN/osascript"

  export HOME="$TEST_HOME"
  export PATH="$MOCK_BIN:$PATH"
  rm -f "$CALLS_LOG"
}

teardown() {
  rm -rf "$TEST_HOME" "$MOCK_BIN"
}

expiry_after() {
  python3 -c "
import datetime
dt = datetime.datetime.utcnow() + datetime.timedelta(seconds=$1)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
"
}

notification_count() {
  [ -f "$CALLS_LOG" ] && wc -l < "$CALLS_LOG" | tr -d ' ' || echo "0"
}

# ─── full lifecycle ─────────────────────────────────────────────

@test "lifecycle: no notification while STS has 2 hours remaining" {
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"

  bash "$SCRIPT"

  [ "$(notification_count)" -eq 0 ]
  [ ! -f "$TEST_HOME/.sts_notified_1h" ]
  [ ! -f "$TEST_HOME/.sts_notified_10m" ]
  [ ! -f "$TEST_HOME/.sts_notified_expired" ]
}

@test "lifecycle: 1h notification sent once when under 1 hour" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"

  # first run: notification fires
  bash "$SCRIPT"
  [ "$(notification_count)" -eq 1 ]
  [ -f "$TEST_HOME/.sts_notified_1h" ]

  # second run: no duplicate
  bash "$SCRIPT"
  [ "$(notification_count)" -eq 1 ]
}

@test "lifecycle: 10m notification sent once when under 10 minutes" {
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  touch "$TEST_HOME/.sts_notified_1h"   # simulate 1h already fired

  # first run: 10m fires
  bash "$SCRIPT"
  [ "$(notification_count)" -eq 1 ]
  [ -f "$TEST_HOME/.sts_notified_10m" ]

  # second run: no duplicate
  bash "$SCRIPT"
  [ "$(notification_count)" -eq 1 ]
}

@test "lifecycle: expired notification sent once after expiry" {
  expiry_after -600 > "$TEST_HOME/.sts_expiry"
  touch "$TEST_HOME/.sts_notified_1h"
  touch "$TEST_HOME/.sts_notified_10m"

  # first run: expired fires
  bash "$SCRIPT"
  [ "$(notification_count)" -eq 1 ]
  [ -f "$TEST_HOME/.sts_notified_expired" ]

  # second run: no duplicate
  bash "$SCRIPT"
  [ "$(notification_count)" -eq 1 ]
}

@test "lifecycle: re-issuing STS clears all notified flags" {
  # simulate expired state
  expiry_after -600 > "$TEST_HOME/.sts_expiry"
  touch "$TEST_HOME/.sts_notified_1h"
  touch "$TEST_HOME/.sts_notified_10m"
  touch "$TEST_HOME/.sts_notified_expired"

  # simulate re-issue: update expiry and clear flags (as _sts_update does)
  expiry_after 7200 > "$TEST_HOME/.sts_expiry"
  rm -f "$TEST_HOME/.sts_notified_1h" \
        "$TEST_HOME/.sts_notified_10m" \
        "$TEST_HOME/.sts_notified_expired"

  bash "$SCRIPT"

  # no notification for far-future expiry
  [ "$(notification_count)" -eq 0 ]
  [ ! -f "$TEST_HOME/.sts_notified_1h" ]
  [ ! -f "$TEST_HOME/.sts_notified_10m" ]
  [ ! -f "$TEST_HOME/.sts_notified_expired" ]
}

@test "lifecycle: after re-issue, 1h warning fires again when approaching" {
  # start with cleared flags and new expiry at 30m
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"

  bash "$SCRIPT"

  [ "$(notification_count)" -eq 1 ]
  [ -f "$TEST_HOME/.sts_notified_1h" ]
}

@test "lifecycle: total 3 notifications fired across full expiry cycle" {
  # Step 1: 1h warning
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  bash "$SCRIPT"

  # Step 2: 10m warning (manually advance state)
  expiry_after 300 > "$TEST_HOME/.sts_expiry"
  bash "$SCRIPT"

  # Step 3: expired
  expiry_after -60 > "$TEST_HOME/.sts_expiry"
  bash "$SCRIPT"

  [ "$(notification_count)" -eq 3 ]
}

@test "lifecycle: multiple runs between thresholds send no extra notifications" {
  expiry_after 1800 > "$TEST_HOME/.sts_expiry"
  bash "$SCRIPT"   # fires 1h
  bash "$SCRIPT"   # suppressed
  bash "$SCRIPT"   # suppressed

  [ "$(notification_count)" -eq 1 ]
}
