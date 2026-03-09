# STS Notifier install.sh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 비개발자와 개발자 모두 `./install.sh` 한 번으로 STS Notifier 전체를 설치할 수 있게 한다.

**Architecture:** 단일 bash 스크립트로 OS/shell 감지 → 의존성 확인 → launchd 설치 → statusLine 설정 → rc 파일 패치 → 자동 검증 순서로 진행한다. 각 단계는 멱등성을 보장하며, 실패 시 명확한 한국어/영문 안내와 복구 방법을 출력한다.

**Tech Stack:** bash, python3 (JSON 조작·타임스탬프), launchctl (macOS), osascript (macOS 알림), sed/awk (rc 파일 패치)

---

## 사전 지식

### 지원 환경 매트릭스

| OS | Shell | launchd | statusLine | rc 패치 |
|---|---|---|---|---|
| macOS | zsh | ✓ | ✓ | `~/.zshrc` |
| macOS | bash | ✓ | ✓ | `~/.bash_profile` |
| WSL (Linux) | zsh | ✗ (건너뜀) | ✓ | `~/.zshrc` |
| WSL (Linux) | bash | ✗ (건너뜀) | ✓ | `~/.bashrc` |
| Git Bash (Windows) | bash(msys) | ✗ (건너뜀) | ✓ (복사방식) | `~/.bashrc` |
| 기타 shell | - | ✗ | ✗ | 안내 후 중단 |

### 심볼릭 링크 vs 복사 정책

- macOS / WSL: `ln -sf` 심볼릭 링크 → git pull 즉시 반영
- Git Bash (Windows): 관리자 권한 없이 symlink 불가 → 파일 복사 + `./install.sh --update` 안내

### rc 파일 패치 전략

`_sts_update` 함수를 텍스트로 파싱할 때 중첩 `{}` 오삽입을 방지하기 위해
**마커 방식**을 사용한다:

1. rc 파일에 `# __STS_EXPIRY_HOOK_START__` / `# __STS_EXPIRY_HOOK_END__` 마커가 이미 있으면 → **건너뜀** (멱등성)
2. `_sts_update` 함수가 있으면:
   - python3로 함수 블록의 닫는 `}` 라인 번호를 정확히 파악 (괄호 depth 추적)
   - 그 줄 **앞에** 마커 + hook 코드 삽입
3. `_sts_update` 함수가 없으면:
   - rc 파일 맨 끝에 독립 hook 블록 추가
   - "함수를 찾지 못해 파일 끝에 추가했습니다. STS 발급 함수 내부에서 호출하세요." 안내

패치 전 반드시 `~/.zshrc.sts-notifier.bak` 백업 생성.

### settings.json 수정 정책

- `jq` 없이 **python3 `json` 모듈**로 파싱 (의존성 최소화)
- 파일 없음 → `{"statusLine": {...}}` 신규 생성
- `statusLine` 없음 → 기존 JSON에 키 추가
- `statusLine` 있음 → 기존 값 출력 후 `"교체할까요? (y/N)"` 확인
- 수정 전 `~/.claude/settings.json.sts-notifier.bak` 백업

---

## Task 1: 스크립트 골격 및 유틸리티 함수

**Files:**
- Create: `sts-notifier/install.sh`

**Step 1:** `install.sh` 파일 생성, shebang + 기본 설정

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Step 2:** 색상·출력 유틸리티 함수 작성

```bash
# 색상 코드
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }
ask()     { echo -e "${BOLD}$*${RESET}"; }  # 사용자 입력 유도
```

**Step 3:** 스크립트 절대 경로 계산 (심볼릭 링크 타도 안전하게)

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFIER_DIR="$SCRIPT_DIR"  # install.sh는 sts-notifier/ 안에 위치
```

**Step 4:** `--update` 플래그 파싱 (Git Bash 재동기화용)

```bash
UPDATE_MODE=false
[[ "${1:-}" == "--update" ]] && UPDATE_MODE=true
```

**Step 5:** 실행 권한 확인 및 부여

```bash
chmod +x "$NOTIFIER_DIR/check-sts-expiry.sh"
chmod +x "$NOTIFIER_DIR/sts-statusline.sh"
```

**Step 6:** 구문 검사

```bash
bash -n sts-notifier/install.sh
```

Expected: 오류 없음

**Step 7:** 커밋

```bash
git add sts-notifier/install.sh
git commit -m "feat(install): scaffold with utility functions"
```

---

## Task 2: OS / Shell 감지

**Files:**
- Modify: `sts-notifier/install.sh`

**Step 1:** OS 감지 함수 작성

```bash
detect_os() {
  case "$OSTYPE" in
    darwin*)  echo "macos" ;;
    linux*)
      if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    msys*|cygwin*) echo "gitbash" ;;
    *)        echo "unknown" ;;
  esac
}

OS="$(detect_os)"
```

**Step 2:** Shell 감지 함수 작성

```bash
detect_shell() {
  local shell_name
  shell_name="$(basename "$SHELL" 2>/dev/null || echo "")"
  case "$shell_name" in
    zsh)  echo "zsh" ;;
    bash) echo "bash" ;;
    *)    echo "unknown" ;;
  esac
}

SHELL_TYPE="$(detect_shell)"
```

**Step 3:** rc 파일 경로 결정 함수

```bash
get_rc_file() {
  case "$SHELL_TYPE" in
    zsh)
      echo "$HOME/.zshrc"
      ;;
    bash)
      # macOS bash는 .bash_profile, Linux/WSL/GitBash는 .bashrc
      if [[ "$OS" == "macos" ]]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
  esac
}
```

**Step 4:** 미지원 shell 안내 함수

```bash
guide_shell_install() {
  error "지원되지 않는 shell입니다: $SHELL"
  echo ""
  echo "STS Notifier는 zsh 또는 bash가 필요합니다."
  echo "아래 중 하나를 설치한 뒤 install.sh를 다시 실행해 주세요."
  echo ""
  case "$OS" in
    macos)
      echo "  zsh 설치:  brew install zsh"
      echo "  기본 shell 변경: chsh -s \$(which zsh)"
      ;;
    wsl|linux)
      echo "  zsh 설치:  sudo apt install -y zsh"
      echo "  기본 shell 변경: chsh -s \$(which zsh)"
      ;;
    gitbash)
      echo "  Git Bash는 bash를 기본으로 사용합니다."
      echo "  Git이 정상 설치되어 있는지 확인해 주세요: https://git-scm.com"
      ;;
  esac
  exit 1
}

[[ "$SHELL_TYPE" == "unknown" ]] && guide_shell_install
```

**Step 5:** 감지 결과 출력

```bash
info "OS: $OS / Shell: $SHELL_TYPE"
```

**Step 6:** 구문 검사

```bash
bash -n sts-notifier/install.sh
```

**Step 7:** 커밋

```bash
git commit -am "feat(install): OS and shell detection"
```

---

## Task 3: 의존성 확인

**Files:**
- Modify: `sts-notifier/install.sh`

**Step 1:** python3 확인 함수

```bash
check_python3() {
  if command -v python3 &>/dev/null; then
    success "python3 확인됨: $(python3 --version)"
    return 0
  fi

  error "python3가 설치되어 있지 않습니다."
  echo ""
  echo "아래 명령어로 설치한 뒤 install.sh를 다시 실행해 주세요."
  echo ""
  case "$OS" in
    macos)   echo "  brew install python3" ;;
    wsl|linux) echo "  sudo apt install -y python3" ;;
    gitbash)
      echo "  1. https://www.python.org/downloads/ 에서 설치"
      echo "  2. 설치 시 'Add Python to PATH' 반드시 체크"
      ;;
  esac
  exit 1
}
```

**Step 2:** `~/.claude` 디렉토리 확인

```bash
check_claude_dir() {
  if [[ ! -d "$HOME/.claude" ]]; then
    warn "~/.claude 디렉토리가 없습니다. Claude Code가 설치되어 있나요?"
    echo ""
    echo "Claude Code 설치: https://claude.ai/code"
    echo ""
    ask "계속 진행할까요? statusLine 설정은 건너뜁니다. (y/N)"
    read -r resp
    if [[ "${resp,,}" != "y" ]]; then
      echo "설치를 중단합니다."
      exit 0
    fi
    SKIP_STATUSLINE=true
  fi
}

SKIP_STATUSLINE=false
```

**Step 3:** 검사 실행

```bash
check_python3
check_claude_dir
```

**Step 4:** 커밋

```bash
git commit -am "feat(install): dependency checks"
```

---

## Task 4: launchd 알림 데몬 설치 (macOS 전용)

**Files:**
- Modify: `sts-notifier/install.sh`

**Step 1:** launchd 설치 함수 작성

```bash
install_launchd() {
  if [[ "$OS" != "macos" ]]; then
    warn "launchd는 macOS 전용입니다. ($OS) → 건너뜁니다."
    warn "알림 기능 없이 Claude Code 상태바만 사용됩니다."
    return 0
  fi

  local plist_src="$NOTIFIER_DIR/com.jellodev.sts-notifier.plist"
  local plist_dst="$HOME/Library/LaunchAgents/com.jellodev.sts-notifier.plist"
  local script_path="$NOTIFIER_DIR/check-sts-expiry.sh"

  # plist 내 경로 치환 후 목적지에 쓰기
  sed "s|REPLACE_WITH_SCRIPT_PATH|$script_path|g" "$plist_src" > "$plist_dst"

  # 이미 로드된 에이전트면 언로드 후 재로드
  if launchctl list | grep -q "com.jellodev.sts-notifier" 2>/dev/null; then
    launchctl unload "$plist_dst" 2>/dev/null || true
  fi

  launchctl load "$plist_dst"
  success "launchd 알림 데몬 설치 완료"
}
```

**Step 2:** 호출

```bash
install_launchd
```

**Step 3:** 커밋

```bash
git commit -am "feat(install): launchd agent installation"
```

---

## Task 5: statusLine 심볼릭 링크 + settings.json 수정

**Files:**
- Modify: `sts-notifier/install.sh`

**Step 1:** 심볼릭 링크 / 복사 함수

```bash
install_statusline_script() {
  [[ "$SKIP_STATUSLINE" == true ]] && return 0

  local src="$NOTIFIER_DIR/sts-statusline.sh"
  local dst="$HOME/.claude/sts-statusline.sh"

  if [[ "$OS" == "gitbash" ]]; then
    # Windows Git Bash: symlink 대신 복사
    if [[ "$UPDATE_MODE" == true ]] || [[ ! -f "$dst" ]]; then
      cp "$src" "$dst"
      chmod +x "$dst"
      success "sts-statusline.sh 복사 완료 (Windows)"
      warn "스크립트 업데이트 시: ./install.sh --update 재실행 필요"
    else
      info "sts-statusline.sh 이미 설치됨 (건너뜀)"
    fi
  else
    # macOS / WSL: 심볼릭 링크
    ln -sf "$src" "$dst"
    success "심볼릭 링크 생성: $dst → $src"
  fi
}
```

**Step 2:** settings.json 수정 함수 — python3로 JSON 파싱

```bash
install_settings_json() {
  [[ "$SKIP_STATUSLINE" == true ]] && return 0

  local settings="$HOME/.claude/settings.json"
  local script_cmd="$HOME/.claude/sts-statusline.sh"
  local new_entry='{"type":"command","command":"'"$script_cmd"'","padding":1}'

  # 파일 없으면 새로 생성
  if [[ ! -f "$settings" ]]; then
    python3 -c "
import json
data = {'statusLine': {'type': 'command', 'command': '$script_cmd', 'padding': 1}}
print(json.dumps(data, indent=2, ensure_ascii=False))
" > "$settings"
    success "~/.claude/settings.json 생성 완료"
    return 0
  fi

  # 기존 statusLine 확인
  local existing
  existing=$(python3 -c "
import json, sys
try:
    data = json.load(open('$settings'))
    sl = data.get('statusLine')
    if sl:
        print(json.dumps(sl, ensure_ascii=False))
    else:
        print('')
except Exception as e:
    print('PARSE_ERROR:' + str(e))
    sys.exit(1)
")

  if [[ "$existing" == PARSE_ERROR* ]]; then
    error "settings.json 파싱 실패: $existing"
    error "수동으로 확인해 주세요: $settings"
    return 1
  fi

  if [[ -n "$existing" ]]; then
    echo ""
    warn "이미 statusLine이 설정되어 있습니다:"
    echo "  $existing"
    echo ""
    ask "STS Notifier로 교체할까요? (y/N)"
    read -r resp
    if [[ "${resp,,}" != "y" ]]; then
      info "statusLine 설정을 건너뜁니다."
      return 0
    fi
  fi

  # 백업 후 수정
  cp "$settings" "${settings}.sts-notifier.bak"
  python3 -c "
import json
data = json.load(open('$settings'))
data['statusLine'] = {'type': 'command', 'command': '$script_cmd', 'padding': 1}
with open('$settings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
  success "settings.json 업데이트 완료 (백업: ${settings}.sts-notifier.bak)"
}
```

**Step 3:** 호출

```bash
install_statusline_script
install_settings_json
```

**Step 4:** 커밋

```bash
git commit -am "feat(install): statusline symlink and settings.json patch"
```

---

## Task 6: rc 파일 자동 패치

**Files:**
- Modify: `sts-notifier/install.sh`

이 태스크가 가장 복잡하다. python3로 괄호 depth를 추적해 `_sts_update` 함수의 닫는 `}` 줄을 정확히 찾는다.

**Step 1:** hook 코드 상수 정의

```bash
HOOK_CODE='
# __STS_EXPIRY_HOOK_START__ (sts-notifier - 자동 삽입, 수동 수정 금지)
local __expiry_utc
__expiry_utc=$(echo "${result:-}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get(\"expires_at_utc\", \"\"))
except:
    pass
" 2>/dev/null)
if [[ -n "$__expiry_utc" && "$__expiry_utc" != "null" ]]; then
  echo "${__expiry_utc/ UTC/}" | sed "s/ /T/;s/\$/Z/" > "$HOME/.sts_expiry"
  rm -f "$HOME/.sts_notified_1h" "$HOME/.sts_notified_10m" "$HOME/.sts_notified_expired"
fi
# __STS_EXPIRY_HOOK_END__'
```

**Step 2:** 이미 패치됐는지 확인하는 함수

```bash
is_already_patched() {
  local rc_file="$1"
  grep -q "__STS_EXPIRY_HOOK_START__" "$rc_file" 2>/dev/null
}
```

**Step 3:** python3로 `_sts_update` 함수의 닫는 `}` 줄 번호 찾기

```bash
find_function_closing_brace() {
  local rc_file="$1"
  python3 - "$rc_file" <<'PYEOF'
import sys

rc_file = sys.argv[1]
with open(rc_file) as f:
    lines = f.readlines()

in_func = False
depth = 0
func_start = -1

for i, line in enumerate(lines):
    stripped = line.strip()
    # 함수 선언 감지: "_sts_update" + "{"
    if not in_func and '_sts_update' in stripped and (
        stripped.endswith('{') or '() {' in stripped or '(){' in stripped
    ):
        in_func = True
        func_start = i
        depth = stripped.count('{') - stripped.count('}')
        continue

    if in_func:
        depth += stripped.count('{') - stripped.count('}')
        if depth <= 0:
            # 이 줄이 닫는 }
            print(i + 1)  # 1-based 줄 번호
            sys.exit(0)

# 함수를 찾지 못함
print(-1)
PYEOF
}
```

**Step 4:** rc 파일 패치 메인 함수

```bash
patch_rc_file() {
  local rc_file
  rc_file="$(get_rc_file)"

  # rc 파일 없으면 생성 여부 확인
  if [[ ! -f "$rc_file" ]]; then
    warn "$rc_file 파일이 없습니다."
    ask "새로 생성할까요? (y/N)"
    read -r resp
    if [[ "${resp,,}" != "y" ]]; then
      warn "rc 파일 패치를 건너뜁니다. STS 발급 시 자동으로 expiry가 저장되지 않습니다."
      return 0
    fi
    touch "$rc_file"
    success "$rc_file 생성됨"
  fi

  # 이미 패치됐으면 건너뜀
  if is_already_patched "$rc_file"; then
    success "$rc_file 이미 패치되어 있습니다 (건너뜀)"
    return 0
  fi

  # 백업
  cp "$rc_file" "${rc_file}.sts-notifier.bak"

  # _sts_update 함수 닫는 } 줄 번호 찾기
  local close_line
  close_line="$(find_function_closing_brace "$rc_file")"

  if [[ "$close_line" -gt 0 ]]; then
    # 함수 닫는 } 앞에 hook 삽입 (sed: N번째 줄 앞에 삽입)
    local tmp_file
    tmp_file="$(mktemp)"
    python3 - "$rc_file" "$close_line" "$HOOK_CODE" > "$tmp_file" <<'PYEOF'
import sys

rc_file   = sys.argv[1]
close_line = int(sys.argv[2])  # 1-based
hook_code  = sys.argv[3]

with open(rc_file) as f:
    lines = f.readlines()

# close_line-1 인덱스 앞에 hook 삽입
insert_at = close_line - 1
lines.insert(insert_at, hook_code + '\n')

with open(sys.argv[0] + '.out', 'w') as _:
    pass  # unused

sys.stdout.write(''.join(lines))
PYEOF
    mv "$tmp_file" "$rc_file"
    success "_sts_update 함수에 expiry hook 삽입 완료: $rc_file"
  else
    # 함수 없음 → 파일 끝에 독립 블록 추가
    cat >> "$rc_file" <<EOF

# sts-notifier: _sts_update 함수를 찾지 못해 파일 끝에 추가했습니다.
# STS 발급 함수 내에서 아래 함수를 호출하세요: __sts_save_expiry
__sts_save_expiry() {
$HOOK_CODE
}
EOF
    warn "_sts_update 함수를 찾지 못했습니다."
    warn "STS 발급 함수 내에서 '__sts_save_expiry' 를 호출해 주세요."
    warn "추가된 위치: $rc_file (맨 끝)"
  fi
}
```

**Step 5:** 호출

```bash
patch_rc_file
```

**Step 6:** 커밋

```bash
git commit -am "feat(install): rc file auto-patch with brace-depth tracking"
```

---

## Task 7: 동작 자동 검증

**Files:**
- Modify: `sts-notifier/install.sh`

**Step 1:** 검증 함수 작성

```bash
verify_installation() {
  echo ""
  info "설치 검증 중..."
  local failed=0

  # 검증용 임시 expiry (5분 후)
  local test_expiry
  test_expiry=$(python3 -c "
import datetime
dt = datetime.datetime.utcnow() + datetime.timedelta(minutes=5)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
")
  echo "$test_expiry" > "$HOME/.sts_expiry"

  # [검증 1] check-sts-expiry.sh
  if HOME="$HOME" bash "$NOTIFIER_DIR/check-sts-expiry.sh" 2>/dev/null; then
    success "check-sts-expiry.sh 정상 동작"
  else
    error "check-sts-expiry.sh 실행 실패"
    failed=1
  fi

  # [검증 2] sts-statusline.sh 출력에 [STS] 포함 여부
  local statusline_out
  statusline_out=$(echo "" | bash "$NOTIFIER_DIR/sts-statusline.sh" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
  if [[ "$statusline_out" == *"[STS]"* ]]; then
    success "sts-statusline.sh 출력 확인: $statusline_out"
  else
    error "sts-statusline.sh 출력 이상: '$statusline_out'"
    failed=1
  fi

  # [검증 3] launchd (macOS only)
  if [[ "$OS" == "macos" ]]; then
    if launchctl list 2>/dev/null | grep -q "com.jellodev.sts-notifier"; then
      success "launchd 에이전트 로드 확인"
    else
      error "launchd 에이전트 로드 실패"
      failed=1
    fi
  fi

  # 테스트용 expiry 정리
  rm -f "$HOME/.sts_expiry"

  return $failed
}
```

**Step 2:** 검증 실패 시 안내

```bash
if ! verify_installation; then
  echo ""
  error "일부 검증이 실패했습니다."
  echo "로그 확인: /tmp/sts-notifier.err"
  echo "재설치:   ./install.sh"
  exit 1
fi
```

**Step 3:** 커밋

```bash
git commit -am "feat(install): automated post-install verification"
```

---

## Task 8: 완료 요약 출력

**Files:**
- Modify: `sts-notifier/install.sh`

**Step 1:** 완료 배너 함수

```bash
print_summary() {
  local rc_file
  rc_file="$(get_rc_file)"

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║${RESET}   ${BOLD}STS Notifier 설치 완료!${RESET}                   ${GREEN}║${RESET}"
  echo -e "${GREEN}╠══════════════════════════════════════════════╣${RESET}"

  [[ "$OS" == "macos" ]] && \
  echo -e "${GREEN}║${RESET} ${GREEN}✓${RESET} launchd 알림 데몬 (1분마다 체크)          ${GREEN}║${RESET}"

  [[ "$SKIP_STATUSLINE" == false ]] && \
  echo -e "${GREEN}║${RESET} ${GREEN}✓${RESET} Claude Code 하단 progress bar             ${GREEN}║${RESET}"

  echo -e "${GREEN}║${RESET} ${GREEN}✓${RESET} $rc_file 패치 완료                ${GREEN}║${RESET}"
  echo -e "${GREEN}║${RESET} ${GREEN}✓${RESET} 동작 검증 통과                             ${GREEN}║${RESET}"
  echo -e "${GREEN}╠══════════════════════════════════════════════╣${RESET}"
  echo -e "${GREEN}║${RESET} ${BOLD}다음 단계:${RESET}                                   ${GREEN}║${RESET}"
  echo -e "${GREEN}║${RESET}   source $rc_file              ${GREEN}║${RESET}"
  echo -e "${GREEN}║${RESET}   이후 STS 재발급하면 자동으로 작동합니다.  ${GREEN}║${RESET}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${RESET}"
  echo ""
}
```

**Step 2:** 호출

```bash
print_summary
```

**Step 3:** 전체 구문 검사

```bash
bash -n sts-notifier/install.sh && echo "syntax OK"
```

**Step 4:** 최종 커밋

```bash
git commit -am "feat(install): completion summary banner"
```

---

## Task 9: 통합 테스트 (bats)

**Files:**
- Create: `sts-notifier/test/e2e/install-flow.bats`

install.sh의 핵심 로직(OS 감지, rc 패치, settings.json 수정)을 격리 환경에서 검증한다.
launchd / osascript 등 macOS 전용 기능은 mock으로 대체한다.

**Step 1:** 테스트 파일 작성

```bash
#!/usr/bin/env bats
# e2e/install-flow.bats

INSTALL="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/install.sh"

setup() {
  TEST_HOME="$(mktemp -d)"
  MOCK_BIN="$(mktemp -d)"
  mkdir -p "$TEST_HOME/.claude"
  export HOME="$TEST_HOME"
  export PATH="$MOCK_BIN:$PATH"

  # launchctl mock
  printf '#!/usr/bin/env bash\necho "launchctl $@"\n' > "$MOCK_BIN/launchctl"
  chmod +x "$MOCK_BIN/launchctl"

  # osascript mock
  printf '#!/usr/bin/env bash\n' > "$MOCK_BIN/osascript"
  chmod +x "$MOCK_BIN/osascript"
}

teardown() { rm -rf "$TEST_HOME" "$MOCK_BIN"; }
```

**Step 2:** settings.json 신규 생성 테스트

```bash
@test "install creates settings.json when missing" {
  rm -f "$TEST_HOME/.claude/settings.json"
  # install 함수만 직접 소싱해서 호출
  HOME="$TEST_HOME" bash -c "
    source '$INSTALL' --source-only 2>/dev/null || true
    install_settings_json
  "
  [ -f "$TEST_HOME/.claude/settings.json" ]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.claude/settings.json'))
assert 'statusLine' in d
"
}
```

**Step 3:** 기존 statusLine 보존 테스트

```bash
@test "install preserves existing statusLine when user declines" {
  echo '{"statusLine":{"type":"command","command":"/old/script.sh"}}' \
    > "$TEST_HOME/.claude/settings.json"
  # 'N' 입력으로 거부
  echo "N" | HOME="$TEST_HOME" bash -c "
    source '$INSTALL' --source-only 2>/dev/null || true
    install_settings_json
  "
  val=$(python3 -c "
import json
d = json.load(open('$TEST_HOME/.claude/settings.json'))
print(d['statusLine']['command'])
")
  [ "$val" = "/old/script.sh" ]
}
```

**Step 4:** rc 패치 멱등성 테스트

```bash
@test "rc patch is idempotent: running twice does not duplicate hook" {
  echo "# empty rc" > "$TEST_HOME/.zshrc"
  SHELL_TYPE=zsh HOME="$TEST_HOME" bash -c "
    source '$INSTALL' --source-only 2>/dev/null || true
    patch_rc_file
    patch_rc_file
  "
  count=$(grep -c "__STS_EXPIRY_HOOK_START__" "$TEST_HOME/.zshrc")
  [ "$count" -eq 1 ]
}
```

**Step 5:** 테스트 실행

```bash
bats sts-notifier/test/e2e/install-flow.bats
```

Expected: 3 tests PASS

**Step 6:** 커밋

```bash
git add sts-notifier/test/e2e/install-flow.bats
git commit -m "test(install): integration tests for install flow"
```

---

## Task 10: docs 업데이트

**Files:**
- Modify: `docs/sts-notifier-setup.md`
- Modify: `README.md`

**Step 1:** `sts-notifier-setup.md` 설치 섹션을 `install.sh` 한 줄 설명으로 교체

```markdown
## 설치

```bash
cd ~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils/sts-notifier
./install.sh
```

이후 안내에 따라 진행하면 모든 설정이 자동으로 완료됩니다.
```

**Step 2:** README.md `sts-notifier` 항목 설명 업데이트

```markdown
| `sts-notifier` | STS 만료 1시간/10분 전 macOS 알림 + Claude Code 하단 progress bar. `./install.sh` 한 번으로 설치. |
```

**Step 3:** 커밋

```bash
git commit -am "docs: update install guide to use install.sh"
```
