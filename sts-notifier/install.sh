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
    *)
      # 이 분기에는 도달하지 않아야 하지만 방어적으로 처리
      echo "$HOME/.bashrc"
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

# ─── 의존성 확인 ──────────────────────────────────────────────────
SKIP_STATUSLINE=false

check_python3() {
  if command -v python3 &>/dev/null; then
    success "python3 확인됨: $(python3 --version 2>&1)"
    return 0
  fi

  error "python3가 설치되어 있지 않습니다."
  echo ""
  echo "  아래 명령어로 python3를 설치한 뒤 install.sh를 다시 실행해 주세요."
  echo ""
  case "$OS" in
    macos)
      echo "    brew install python3"
      ;;
    wsl|linux)
      echo "    sudo apt install -y python3"
      ;;
    gitbash)
      echo "    1. https://www.python.org/downloads/ 에서 설치 파일 다운로드"
      echo "    2. 설치 화면에서 'Add Python to PATH' 체크박스를 반드시 선택"
      echo "    3. 설치 완료 후 Git Bash를 재시작하고 ./install.sh 재실행"
      ;;
    *)
      echo "    https://www.python.org/downloads/ 에서 설치하세요."
      ;;
  esac
  exit 1
}

check_claude_dir() {
  if [[ -d "$HOME/.claude" ]]; then
    return 0
  fi

  warn "~/.claude 디렉토리가 없습니다."
  echo ""
  echo "  Claude Code가 설치되어 있지 않은 것 같습니다."
  echo "  Claude Code 설치: https://claude.ai/code"
  echo ""
  ask "  Claude Code 없이 계속 진행할까요? (statusLine 설정은 건너뜁니다) (y/N)"
  read -r resp </dev/tty || resp=""
  if [[ "${resp,,}" != "y" ]]; then
    echo ""
    echo "  설치를 중단합니다. Claude Code 설치 후 다시 실행해 주세요."
    exit 0
  fi
  SKIP_STATUSLINE=true
  warn "statusLine 설정을 건너뜁니다."
}

# ─── 의존성 확인 실행 ─────────────────────────────────────────────
info "의존성 확인 중..."
check_python3
check_claude_dir

# ─── launchd 알림 데몬 설치 (macOS 전용) ─────────────────────────

install_launchd() {
  if [[ "$OS" != "macos" ]]; then
    warn "launchd는 macOS 전용입니다. ($OS 환경) → 건너뜁니다."
    warn "알림 기능 없이 Claude Code 상태바만 사용됩니다."
    return 0
  fi

  local plist_src="$NOTIFIER_DIR/com.jellodev.sts-notifier.plist"
  local plist_dst="$HOME/Library/LaunchAgents/com.jellodev.sts-notifier.plist"
  local script_path="$NOTIFIER_DIR/check-sts-expiry.sh"

  # plist 소스 파일 존재 확인
  if [[ ! -f "$plist_src" ]]; then
    error "plist 파일을 찾을 수 없습니다: $plist_src"
    exit 1
  fi

  # LaunchAgents 디렉토리 생성 (없을 경우)
  mkdir -p "$HOME/Library/LaunchAgents"

  # plist 내 경로 플레이스홀더를 실제 경로로 치환해 목적지에 쓰기
  sed "s|REPLACE_WITH_SCRIPT_PATH|$script_path|g" "$plist_src" > "$plist_dst"

  # 이미 로드된 에이전트면 언로드 후 재로드 (업데이트 지원)
  if launchctl list 2>/dev/null | grep -q "com.jellodev.sts-notifier"; then
    launchctl unload "$plist_dst" 2>/dev/null || true
    info "기존 launchd 에이전트를 언로드했습니다."
  fi

  if launchctl load "$plist_dst"; then
    success "launchd 알림 데몬 설치 완료 (1분마다 STS 만료 체크)"
  else
    error "launchd 에이전트 로드에 실패했습니다."
    error "수동 설치: launchctl load $plist_dst"
    exit 1
  fi
}

# ─── launchd 설치 실행 ────────────────────────────────────────────
info "launchd 알림 데몬 설치 중..."
install_launchd
