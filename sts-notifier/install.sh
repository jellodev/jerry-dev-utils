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
if [[ "${1:-}" == "--update" ]]; then
  UPDATE_MODE=true
  info "업데이트 모드로 실행합니다."
elif [[ -n "${1:-}" ]]; then
  warn "알 수 없는 옵션: ${1:-}. 무시합니다."
fi

# ─── 실행 권한 보장 ───────────────────────────────────────────────
if [[ ! -f "$NOTIFIER_DIR/check-sts-expiry.sh" ]]; then
  error "check-sts-expiry.sh 파일을 찾을 수 없습니다: $NOTIFIER_DIR/check-sts-expiry.sh"
  exit 1
fi
chmod +x "$NOTIFIER_DIR/check-sts-expiry.sh"

if [[ ! -f "$NOTIFIER_DIR/sts-statusline.sh" ]]; then
  error "sts-statusline.sh 파일을 찾을 수 없습니다: $NOTIFIER_DIR/sts-statusline.sh"
  exit 1
fi
chmod +x "$NOTIFIER_DIR/sts-statusline.sh"

# ─── OS 감지 ─────────────────────────────────────────────────────
detect_os() {
  case "$OSTYPE" in
    darwin*)
      echo "macos"
      ;;
    linux*)
      if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    msys*|cygwin*)
      echo "gitbash"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# ─── Shell 감지 ───────────────────────────────────────────────────
detect_shell() {
  local shell_name
  shell_name="$(basename "${SHELL:-}" 2>/dev/null || echo "")"
  case "$shell_name" in
    zsh)  echo "zsh"  ;;
    bash) echo "bash" ;;
    *)    echo "unknown" ;;
  esac
}

# ─── rc 파일 경로 결정 ────────────────────────────────────────────
# macOS bash → ~/.bash_profile, 그 외 bash → ~/.bashrc, zsh → ~/.zshrc
get_rc_file() {
  case "$SHELL_TYPE" in
    zsh)
      echo "$HOME/.zshrc"
      ;;
    bash)
      if [[ "$OS" == "macos" ]]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
  esac
}

# ─── 미지원 shell 안내 ────────────────────────────────────────────
guide_shell_install() {
  error "지원되지 않는 shell입니다: ${SHELL:-알 수 없음}"
  echo ""
  echo "  STS Notifier는 zsh 또는 bash가 필요합니다."
  echo "  아래 안내에 따라 설치 후 install.sh를 다시 실행해 주세요."
  echo ""
  case "$OS" in
    macos)
      echo "  [zsh 설치]"
      echo "    brew install zsh"
      echo "    chsh -s \$(which zsh)   # 기본 shell 변경"
      echo "    터미널을 재시작한 뒤 ./install.sh 를 다시 실행하세요."
      ;;
    wsl|linux)
      echo "  [zsh 설치]"
      echo "    sudo apt install -y zsh"
      echo "    chsh -s \$(which zsh)   # 기본 shell 변경"
      echo "    터미널을 재시작한 뒤 ./install.sh 를 다시 실행하세요."
      ;;
    gitbash)
      echo "  Git Bash는 bash를 기본으로 제공합니다."
      echo "  Git이 올바르게 설치되어 있는지 확인하세요: https://git-scm.com"
      ;;
    *)
      echo "  https://www.zsh.org 에서 zsh를 설치하세요."
      ;;
  esac
  exit 1
}

# ─── OS / Shell 감지 실행 ─────────────────────────────────────────
OS="$(detect_os)"
SHELL_TYPE="$(detect_shell)"

[[ "$SHELL_TYPE" == "unknown" ]] && guide_shell_install

info "환경 감지: OS=$OS / Shell=$SHELL_TYPE"
