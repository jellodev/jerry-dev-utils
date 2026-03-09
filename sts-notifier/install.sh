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
  # python3로 리터럴 치환 (경로의 특수문자 안전 처리)
  # 임시 파일에 먼저 쓴 뒤 mv (sed 실패 시 기존 plist 오염 방지)
  local plist_tmp
  plist_tmp="$(mktemp)"
  python3 -c "
import sys
src = open(sys.argv[1]).read()
print(src.replace('REPLACE_WITH_SCRIPT_PATH', sys.argv[2]), end='')
" "$plist_src" "$script_path" > "$plist_tmp"
  mv "$plist_tmp" "$plist_dst"

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

# ─── statusLine 스크립트 설치 ─────────────────────────────────────

install_statusline_script() {
  [[ "$SKIP_STATUSLINE" == true ]] && return 0

  local src="$NOTIFIER_DIR/sts-statusline.sh"
  local dst="$HOME/.claude/sts-statusline.sh"

  if [[ "$OS" == "gitbash" ]]; then
    # Windows Git Bash: symlink 권한 불가 → 파일 복사
    if [[ "$UPDATE_MODE" == true ]] || [[ ! -f "$dst" ]]; then
      cp "$src" "$dst"
      chmod +x "$dst"
      success "sts-statusline.sh 복사 완료 (Windows 환경)"
      if [[ "$UPDATE_MODE" == true ]]; then
        info "스크립트가 최신 버전으로 업데이트됐습니다."
      else
        warn "스크립트 업데이트 시: ./install.sh --update 를 다시 실행하세요."
      fi
    else
      info "sts-statusline.sh 이미 설치되어 있습니다. (건너뜀)"
      info "최신 버전으로 업데이트하려면: ./install.sh --update"
    fi
  else
    # macOS / WSL: 심볼릭 링크 (git pull 즉시 반영)
    ln -sf "$src" "$dst"
    success "심볼릭 링크 생성 완료"
    info "  $dst → $src"
  fi
}

# ─── settings.json 수정 ───────────────────────────────────────────

install_settings_json() {
  [[ "$SKIP_STATUSLINE" == true ]] && return 0

  local settings="$HOME/.claude/settings.json"
  local script_cmd="$HOME/.claude/sts-statusline.sh"

  # 파일 없으면 새로 생성
  if [[ ! -f "$settings" ]]; then
    python3 -c "
import json, sys
data = {'statusLine': {'type': 'command', 'command': sys.argv[1], 'padding': 1}}
with open(sys.argv[2], 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$script_cmd" "$settings"
    success "~/.claude/settings.json 생성 완료"
    return 0
  fi

  # 기존 settings.json 파싱
  local existing parse_result
  parse_result=$(python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    sl = data.get('statusLine')
    if sl:
        print('HAS_STATUSLINE')
        print(json.dumps(sl, ensure_ascii=False))
    else:
        print('NO_STATUSLINE')
except Exception as e:
    print('PARSE_ERROR:' + str(e))
    sys.exit(0)
" "$settings")

  if [[ "$parse_result" == PARSE_ERROR* ]]; then
    error "settings.json 파싱 실패: ${parse_result#PARSE_ERROR:}"
    error "파일을 직접 확인하세요: $settings"
    return 1
  fi

  if [[ "$parse_result" == HAS_STATUSLINE* ]]; then
    local existing_json
    existing_json="$(echo "$parse_result" | tail -n 1)"
    echo ""
    warn "이미 statusLine이 설정되어 있습니다:"
    echo "  $existing_json"
    echo ""
    ask "STS Notifier로 교체할까요? (y/N)"
    read -r resp </dev/tty || resp=""
    if [[ "${resp,,}" != "y" ]]; then
      info "statusLine 설정을 건너뜁니다."
      return 0
    fi
  fi

  # 백업 후 수정 (tmpfile+mv: python3 실패 시 기존 파일 보존)
  cp "$settings" "${settings}.sts-notifier.bak"
  local settings_tmp
  settings_tmp="$(mktemp)"
  python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
data['statusLine'] = {'type': 'command', 'command': sys.argv[2], 'padding': 1}
with open(sys.argv[3], 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$settings" "$script_cmd" "$settings_tmp"
  mv "$settings_tmp" "$settings"
  success "settings.json 업데이트 완료"
  info "백업 파일: ${settings}.sts-notifier.bak"
}

# ─── statusLine 설치 실행 ─────────────────────────────────────────
info "Claude Code statusLine 설정 중..."
install_statusline_script
install_settings_json

# ─── rc 파일 자동 패치 ────────────────────────────────────────────

# STS 발급 후 expiry를 저장하는 hook 코드 (마커로 감쌈)
# 주의: 이 변수는 heredoc으로 정의하지 않고 단일 따옴표 문자열로 정의한다.
#       실제 rc 파일에 삽입될 때 변수 확장이 일어나면 안 된다.
_STS_HOOK_BLOCK='
# __STS_EXPIRY_HOOK_START__ (sts-notifier 자동 삽입 - 수동 수정 금지)
local __expiry_utc
__expiry_utc=$(echo "${result:-}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    v = d.get(\"expires_at_utc\", \"\")
    if v:
        print(v)
except Exception:
    pass
" 2>/dev/null || true)
if [[ -n "${__expiry_utc:-}" && "${__expiry_utc:-}" != "null" ]]; then
  echo "${__expiry_utc/ UTC/}" | sed "s/ /T/;s/\$/Z/" > "${HOME}/.sts_expiry"
  rm -f "${HOME}/.sts_notified_1h" "${HOME}/.sts_notified_10m" "${HOME}/.sts_notified_expired"
fi
# __STS_EXPIRY_HOOK_END__'

# 이미 패치됐는지 확인 (마커 기반)
_is_already_patched() {
  local rc_file="$1"
  grep -q "__STS_EXPIRY_HOOK_START__" "$rc_file" 2>/dev/null
}

# python3로 _sts_update 함수의 닫는 } 줄 번호를 반환 (1-based)
# 찾지 못하면 -1 반환
_find_function_closing_brace() {
  local rc_file="$1"
  python3 - "$rc_file" <<'PYEOF'
import sys

rc_file = sys.argv[1]
try:
    with open(rc_file, encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
except Exception as e:
    print(-1)
    sys.exit(0)

in_func = False
depth = 0

for i, line in enumerate(lines):
    stripped = line.strip()
    # 주석 제거 (간단히 # 이후 무시 - 문자열 내 #은 오탐 가능하나 실용적으로 충분)
    if '#' in stripped:
        stripped = stripped[:stripped.index('#')].strip()

    # 함수 선언 감지: _sts_update 포함 + { 포함
    if not in_func and '_sts_update' in line and '{' in stripped:
        in_func = True
        depth = stripped.count('{') - stripped.count('}')
        # depth가 이미 0 이하면 한 줄 함수 (드문 경우)
        if depth <= 0:
            print(i + 1)
            sys.exit(0)
        continue

    if in_func:
        depth += stripped.count('{') - stripped.count('}')
        if depth <= 0:
            print(i + 1)  # 1-based
            sys.exit(0)

# 찾지 못함
print(-1)
PYEOF
}

patch_rc_file() {
  local rc_file
  rc_file="$(get_rc_file)"

  # rc 파일 없으면 생성 여부 확인
  if [[ ! -f "$rc_file" ]]; then
    warn "$rc_file 파일이 없습니다."
    echo ""
    ask "  새로 생성할까요? (y/N)"
    read -r resp </dev/tty || resp=""
    if [[ "${resp,,}" != "y" ]]; then
      warn "rc 파일 패치를 건너뜁니다."
      warn "STS 발급 시 expiry가 자동으로 저장되지 않습니다."
      return 0
    fi
    touch "$rc_file"
    success "$rc_file 생성됨"
  fi

  # 이미 패치됐으면 건너뜀 (멱등성)
  if _is_already_patched "$rc_file"; then
    success "$rc_file 이미 패치되어 있습니다. (건너뜀)"
    return 0
  fi

  # 백업
  cp "$rc_file" "${rc_file}.sts-notifier.bak"

  # _sts_update 함수의 닫는 } 줄 번호 파악
  local close_line
  close_line="$(_find_function_closing_brace "$rc_file")"

  local tmp_file
  tmp_file="$(mktemp)"

  if [[ "$close_line" -gt 0 ]]; then
    # 함수 발견: 닫는 } 앞 줄에 hook 삽입
    python3 - "$rc_file" "$close_line" "$_STS_HOOK_BLOCK" > "$tmp_file" <<'PYEOF'
import sys

rc_file    = sys.argv[1]
close_line = int(sys.argv[2])  # 1-based
hook_block = sys.argv[3]

with open(rc_file, encoding='utf-8', errors='replace') as f:
    lines = f.readlines()

# close_line-1 인덱스(0-based) 앞에 삽입
insert_at = close_line - 1
lines.insert(insert_at, hook_block + '\n')

sys.stdout.write(''.join(lines))
PYEOF
    mv "$tmp_file" "$rc_file"
    success "_sts_update 함수에 expiry hook이 삽입됐습니다: $rc_file"
  else
    # 함수 미발견: 파일 끝에 독립 헬퍼 함수로 추가
    {
      cat "$rc_file"
      printf '\n'
      printf '# sts-notifier: STS 발급 함수를 찾지 못해 파일 끝에 추가했습니다.\n'
      printf '# STS 발급 함수(_sts_update 등) 마지막 줄에 __sts_save_expiry 를 호출하세요.\n'
      printf '__sts_save_expiry() {\n'
      printf '%s\n' "$_STS_HOOK_BLOCK"
      printf '}\n'
    } > "$tmp_file"
    mv "$tmp_file" "$rc_file"
    warn "_sts_update 함수를 찾지 못했습니다."
    warn "STS 발급 함수 안에서 '__sts_save_expiry' 를 직접 호출하세요."
    warn "추가된 위치: $rc_file (파일 끝)"
  fi
}

# ─── rc 파일 패치 실행 ────────────────────────────────────────────
info "rc 파일 패치 중..."
patch_rc_file

# ─── 설치 후 자동 검증 ────────────────────────────────────────────

verify_installation() {
  echo ""
  info "설치 검증 중..."
  local failed=0

  # 검증용 임시 expiry: 5분 후 만료 (10분 이내 알림 임계값 내)
  local test_expiry
  test_expiry=$(python3 -c "
import datetime
dt = datetime.datetime.utcnow() + datetime.timedelta(minutes=5)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
")
  echo "$test_expiry" > "$HOME/.sts_expiry"

  # [검증 1] check-sts-expiry.sh 정상 실행 확인
  if bash "$NOTIFIER_DIR/check-sts-expiry.sh" 2>/dev/null; then
    success "[검증 1] check-sts-expiry.sh 정상 동작"
  else
    error "[검증 1] check-sts-expiry.sh 실행 실패"
    failed=1
  fi

  # [검증 2] sts-statusline.sh 출력에 [STS] 포함 여부
  local statusline_out
  statusline_out=$(echo "" | bash "$NOTIFIER_DIR/sts-statusline.sh" 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' || true)
  if [[ "$statusline_out" == *"[STS]"* ]]; then
    success "[검증 2] sts-statusline.sh 출력 확인"
    info "  출력 미리보기: $statusline_out"
  else
    error "[검증 2] sts-statusline.sh 출력 이상: '$statusline_out'"
    failed=1
  fi

  # [검증 3] launchd 에이전트 로드 확인 (macOS 전용)
  if [[ "$OS" == "macos" ]]; then
    if launchctl list 2>/dev/null | grep -q "com.jellodev.sts-notifier"; then
      success "[검증 3] launchd 에이전트 정상 로드"
    else
      error "[검증 3] launchd 에이전트 로드 실패"
      failed=1
    fi
  fi

  # 테스트용 expiry 정리
  rm -f "$HOME/.sts_expiry"

  return $failed
}

# ─── 검증 실행 ────────────────────────────────────────────────────
if ! verify_installation; then
  echo ""
  error "일부 검증이 실패했습니다."
  echo ""
  echo "  로그 확인: /tmp/sts-notifier.err"
  echo "  재설치:   ./install.sh"
  exit 1
fi

# ─── 완료 요약 ────────────────────────────────────────────────────

print_summary() {
  local rc_file
  rc_file="$(get_rc_file)"

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║${RESET}   ${BOLD}STS Notifier 설치 완료!${RESET}                       ${GREEN}║${RESET}"
  echo -e "${GREEN}╠══════════════════════════════════════════════════╣${RESET}"

  if [[ "$OS" == "macos" ]]; then
    echo -e "${GREEN}║${RESET}  ${GREEN}✓${RESET} launchd 알림 데몬 (1분마다 만료 체크)      ${GREEN}║${RESET}"
  fi

  if [[ "$SKIP_STATUSLINE" == false ]]; then
    echo -e "${GREEN}║${RESET}  ${GREEN}✓${RESET} Claude Code 하단 progress bar 활성화       ${GREEN}║${RESET}"
  fi

  echo -e "${GREEN}║${RESET}  ${GREEN}✓${RESET} ${rc_file} 패치 완료           ${GREEN}║${RESET}"
  echo -e "${GREEN}║${RESET}  ${GREEN}✓${RESET} 동작 검증 통과                              ${GREEN}║${RESET}"
  echo -e "${GREEN}╠══════════════════════════════════════════════════╣${RESET}"
  echo -e "${GREEN}║${RESET}  ${BOLD}다음 단계:${RESET}                                      ${GREEN}║${RESET}"
  echo -e "${GREEN}║${RESET}    source ${rc_file}                ${GREEN}║${RESET}"
  echo -e "${GREEN}║${RESET}    이후 STS를 재발급하면 자동으로 동작합니다.  ${GREEN}║${RESET}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
}

print_summary
