#!/usr/bin/env bash
# install.sh — STS Notifier 설치 스크립트
# 사용법: ./install.sh [--update]
#   --update : Git Bash(Windows) 환경에서 스크립트 재동기화 시 사용
set -euo pipefail

# ─── 색상 / 출력 유틸리티 ────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }
ask()     { echo -e "${BOLD}$*${RESET}"; }

# ─── 스크립트 경로 (심볼릭 링크를 타도 안전) ─────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFIER_DIR="$SCRIPT_DIR"

# ─── 플래그 파싱 ─────────────────────────────────────────────────
UPDATE_MODE=false
[[ "${1:-}" == "--update" ]] && UPDATE_MODE=true

# ─── 실행 권한 보장 ───────────────────────────────────────────────
chmod +x "$NOTIFIER_DIR/check-sts-expiry.sh"
chmod +x "$NOTIFIER_DIR/sts-statusline.sh"
