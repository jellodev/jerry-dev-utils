#!/usr/bin/env bash
# check-sts-expiry.sh
# ~/.sts_expiry 파일에서 STS 만료 시각(UTC ISO8601)을 읽어
# 만료 1시간 전 / 10분 전 / 만료 시 macOS 알림을 발송한다.
#
# 중복 알림 방지:
#   ~/.sts_notified_1h      - 1시간 알림 발송 완료
#   ~/.sts_notified_10m     - 10분 알림 발송 완료
#   ~/.sts_notified_expired - 만료 알림 발송 완료
# 위 파일들은 STS 재발급 시 삭제하여 초기화한다.

EXPIRY_FILE="$HOME/.sts_expiry"

# ~/.sts_expiry 파일이 없으면 조용히 종료
[[ -f "$EXPIRY_FILE" ]] || exit 0

expiry_raw=$(tr -d '[:space:]' < "$EXPIRY_FILE")

# 빈 파일이면 종료
[[ -z "$expiry_raw" ]] && exit 0

# UTC ISO8601 → Unix timestamp (macOS 호환)
# 형식: 2026-03-10T08:20:26Z
expiry_ts=$(python3 -c "
import sys, datetime
s = '$expiry_raw'.replace('Z', '+00:00')
try:
    dt = datetime.datetime.fromisoformat(s)
    print(int(dt.timestamp()))
except Exception:
    sys.exit(1)
" 2>/dev/null)

if [[ -z "$expiry_ts" ]]; then
  echo "[sts-notifier] ~/.sts_expiry 파싱 실패: $expiry_raw" >&2
  exit 1
fi

now_ts=$(date +%s)
remaining=$(( expiry_ts - now_ts ))

send_notification() {
  local title="$1"
  local message="$2"
  # STS_NOTIFIER_VERIFY=1 이면 install.sh 검증 중 → 실제 알림 생략
  if [[ "${STS_NOTIFIER_VERIFY:-}" == "1" ]]; then
    return 0
  fi
  osascript -e "display notification \"$message\" with title \"$title\" sound name \"Ping\""
}

# 이미 만료된 경우
if (( remaining <= 0 )); then
  if [[ ! -f "$HOME/.sts_notified_expired" ]]; then
    send_notification "AWS STS 만료됨" "STS 임시 자격증명이 만료되었습니다. 재발급이 필요합니다."
    touch "$HOME/.sts_notified_expired"
  fi
  exit 0
fi

# 10분(600초) 이내 만료
if (( remaining <= 600 )); then
  if [[ ! -f "$HOME/.sts_notified_10m" ]]; then
    remain_min=$(( remaining / 60 ))
    remain_sec=$(( remaining % 60 ))
    send_notification "AWS STS 만료 임박!" "약 ${remain_min}분 ${remain_sec}초 후 STS가 만료됩니다. 지금 바로 재발급하세요."
    touch "$HOME/.sts_notified_10m"
  fi
  exit 0
fi

# 1시간(3600초) 이내 만료
if (( remaining <= 3600 )); then
  if [[ ! -f "$HOME/.sts_notified_1h" ]]; then
    remain_min=$(( remaining / 60 ))
    send_notification "AWS STS 만료 예정" "약 ${remain_min}분 후 STS가 만료됩니다. 미리 재발급을 준비하세요."
    touch "$HOME/.sts_notified_1h"
  fi
  exit 0
fi

exit 0
