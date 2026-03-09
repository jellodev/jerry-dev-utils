#!/usr/bin/env bats
# e2e/install-flow.bats
# Integration tests for install.sh core logic
#
# Covers:
#   - settings.json created when missing
#   - existing statusLine preserved when user declines replacement
#   - rc patch idempotency (running twice does not duplicate hook)

INSTALL="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/install.sh"
NOTIFIER_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
  TEST_HOME="$(mktemp -d)"
  MOCK_BIN="$(mktemp -d)"
  mkdir -p "$TEST_HOME/.claude"

  # launchctl mock
  cat > "$MOCK_BIN/launchctl" <<'EOF'
#!/usr/bin/env bash
echo "launchctl $*"
exit 0
EOF
  chmod +x "$MOCK_BIN/launchctl"

  # osascript mock (no-op, prevents real macOS notifications)
  cat > "$MOCK_BIN/osascript" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/osascript"

  export HOME="$TEST_HOME"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_HOME" "$MOCK_BIN"
}

# ─── helper: run install.sh in non-interactive mode ────────────────────────
# Pipes auto-responses for any read prompts. install.sh exits 0 on success.
run_install() {
  local stdin_input="${1:-}"
  echo "$stdin_input" | HOME="$TEST_HOME" PATH="$MOCK_BIN:$PATH" bash "$INSTALL" 2>/dev/null
}

# ─── Test 1: settings.json created when missing ────────────────────────────

@test "install creates settings.json when missing" {
  rm -f "$TEST_HOME/.claude/settings.json"

  # Auto-answer 'y' to rc file creation prompt if needed
  run bash -c "echo 'y' | HOME='$TEST_HOME' PATH='$MOCK_BIN:$PATH' bash '$INSTALL' 2>/dev/null; true"

  [ -f "$TEST_HOME/.claude/settings.json" ]

  # Verify statusLine key is present and command points to sts-statusline.sh
  python3 -c "
import json, sys
d = json.load(open('$TEST_HOME/.claude/settings.json'))
assert 'statusLine' in d, 'statusLine key missing'
assert d['statusLine'].get('type') == 'command', 'type should be command'
assert 'sts-statusline.sh' in d['statusLine'].get('command', ''), 'command should point to sts-statusline.sh'
"
}

# ─── Test 2: existing statusLine preserved when user declines ──────────────

@test "install preserves existing statusLine when user declines replacement" {
  # Pre-populate settings.json with an existing statusLine
  cat > "$TEST_HOME/.claude/settings.json" <<'EOF'
{"statusLine":{"type":"command","command":"/old/my-script.sh","padding":1}}
EOF

  # Send 'N' to decline replacement; 'y' for any other prompts
  printf 'N\ny\n' | HOME="$TEST_HOME" PATH="$MOCK_BIN:$PATH" bash "$INSTALL" 2>/dev/null || true

  # Original command must be preserved
  val=$(python3 -c "
import json
d = json.load(open('$TEST_HOME/.claude/settings.json'))
print(d['statusLine']['command'])
")
  [ "$val" = "/old/my-script.sh" ]
}

# ─── Test 3: rc patch is idempotent ────────────────────────────────────────

@test "rc patch is idempotent: running twice does not duplicate hook" {
  # Provide an existing rc file with no _sts_update function
  echo "# empty rc" > "$TEST_HOME/.zshrc"

  # First install: accept all prompts with 'y'
  printf 'y\ny\n' | HOME="$TEST_HOME" PATH="$MOCK_BIN:$PATH" SHELL=/bin/zsh bash "$INSTALL" 2>/dev/null || true

  # Second install: idempotency check
  printf 'y\ny\n' | HOME="$TEST_HOME" PATH="$MOCK_BIN:$PATH" SHELL=/bin/zsh bash "$INSTALL" 2>/dev/null || true

  # Hook marker must appear exactly once
  count=$(grep -c "__STS_EXPIRY_HOOK_START__" "$TEST_HOME/.zshrc" || echo 0)
  [ "$count" -eq 1 ]
}
