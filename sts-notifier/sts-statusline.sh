#!/usr/bin/env bash
# sts-statusline.sh
# Claude Code statusLine용 STS 만료 progress bar 스크립트.
#
# 설정 방법 (~/.claude/settings.json):
#   {
#     "statusLine": {
#       "type": "command",
#       "command": "~/.claude/sts-statusline.sh",
#       "padding": 1
#     }
#   }
#
# Progress bar 설계:
#   - bar가 차오를수록 만료 임박 (100% = 만료)
#   - 기준: 만료까지 1시간을 100%로 정규화
#     - 1시간 초과: 0% (bar 비어 있음, 초록)
#     - 1시간 이내: 점점 차오름 (노랑)
#     - 10분 이내:  거의 가득 (빨강)
#     - 만료:       가득 참   (빨강)

# stdin은 Claude Code가 보내는 JSON이지만 STS 데이터는 없으므로 무시
cat > /dev/null

EXPIRY_FILE="$HOME/.sts_expiry"

# ~/.sts_expiry 없으면 아무것도 출력하지 않음 (상태바 비움)
[[ -f "$EXPIRY_FILE" ]] || exit 0

expiry_raw=$(tr -d '[:space:]' < "$EXPIRY_FILE")
[[ -z "$expiry_raw" ]] && exit 0

# UTC ISO8601 → Unix timestamp (macOS 호환)
expiry_ts=$(python3 -c "
import sys, datetime
s = '$expiry_raw'.replace('Z', '+00:00')
try:
    dt = datetime.datetime.fromisoformat(s)
    print(int(dt.timestamp()))
except Exception:
    sys.exit(1)
" 2>/dev/null)

[[ -z "$expiry_ts" ]] && exit 0

now_ts=$(date +%s)
remaining=$(( expiry_ts - now_ts ))

# 만료 절대 시각 KST 변환 (UTC+9)
expiry_kst=$(python3 -c "
import datetime
ts = $expiry_ts
dt_utc = datetime.datetime.utcfromtimestamp(ts)
dt_kst = dt_utc + datetime.timedelta(hours=9)
print(dt_kst.strftime('%m/%d %H:%M'))
" 2>/dev/null)

# --- Progress bar 계산 ---
# 기준: 3600초(1시간)를 100%로 정규화
# 차오를수록 만료 임박 → filled = (3600 - remaining) / 3600 * BAR_WIDTH
BAR_WIDTH=10
ONE_HOUR=3600

if (( remaining <= 0 )); then
  filled=$BAR_WIDTH
else
  # 1시간 초과면 elapsed 비율 0으로 고정 (bar 비어 있음)
  if (( remaining >= ONE_HOUR )); then
    filled=0
  else
    elapsed=$(( ONE_HOUR - remaining ))
    filled=$(( elapsed * BAR_WIDTH / ONE_HOUR ))
    # 최소 1칸은 채워서 "뭔가 줄고 있음"을 시각적으로 표시
    (( filled < 1 )) && filled=1
  fi
fi

empty=$(( BAR_WIDTH - filled ))
bar_filled=$(printf "%${filled}s" | tr ' ' '█')
bar_empty=$(printf "%${empty}s" | tr ' ' '░')

# --- 색상 선택 ---
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BOLD_RED='\033[1;31m'
RESET='\033[0m'

if (( remaining <= 0 )); then
  bar_color=$BOLD_RED
  label_color=$BOLD_RED
elif (( remaining <= 600 )); then
  bar_color=$RED
  label_color=$RED
elif (( remaining <= ONE_HOUR )); then
  bar_color=$YELLOW
  label_color=$YELLOW
else
  bar_color=$GREEN
  label_color=$GREEN
fi

# --- 남은 시간 텍스트 ---
if (( remaining <= 0 )); then
  time_text="만료됨"
elif (( remaining < 60 )); then
  time_text="${remaining}초 남음"
elif (( remaining < ONE_HOUR )); then
  remain_min=$(( remaining / 60 ))
  remain_sec=$(( remaining % 60 ))
  time_text="${remain_min}분 ${remain_sec}초 남음"
else
  remain_hour=$(( remaining / ONE_HOUR ))
  remain_min=$(( (remaining % ONE_HOUR) / 60 ))
  time_text="${remain_hour}시간 ${remain_min}분 남음"
fi

# --- 출력 ---
printf "${label_color}[STS]${RESET} ${bar_color}${bar_filled}${bar_empty}${RESET} ${label_color}${time_text}${RESET}  만료: ${expiry_kst} KST\n"
