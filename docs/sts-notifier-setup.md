# STS Notifier 설치 가이드

AWS STS 임시 자격증명 만료 **1시간 전** / **10분 전** / **만료 시** macOS 알림을 받는 방법을 설명합니다.

---

## 구성 요소

| 파일 | 역할 |
|---|---|
| `sts-notifier/check-sts-expiry.sh` | 만료 시각 확인 & macOS 알림 발송 |
| `sts-notifier/com.jellodev.sts-notifier.plist` | launchd UserAgent (1분마다 스크립트 실행) |

---

## 설치

```bash
cd ~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils/sts-notifier
./install.sh
```

이후 안내에 따라 진행하면 모든 설정이 자동으로 완료됩니다.

설치 스크립트가 수행하는 작업:
- macOS: launchd 알림 데몬 설치 (1분마다 만료 체크)
- Claude Code `~/.claude/settings.json`에 statusLine 등록
- `~/.zshrc` / `~/.bashrc` 등 rc 파일에 STS 발급 시 expiry 저장 hook 자동 삽입

> **Windows(Git Bash) 사용자:** 스크립트 업데이트 시 `./install.sh --update` 재실행이 필요합니다.

---

## 동작 확인

### 즉시 테스트

10분 이내 만료 알림 테스트:

```bash
# 현재 시각 + 9분 후로 설정
date -u -v+9M +"%Y-%m-%dT%H:%M:%SZ" > ~/.sts_expiry
~/bin/check-sts-expiry.sh
```

1시간 이내 만료 알림 테스트:

```bash
# 현재 시각 + 50분 후로 설정
date -u -v+50M +"%Y-%m-%dT%H:%M:%SZ" > ~/.sts_expiry
rm -f ~/.sts_notified_1h ~/.sts_notified_10m ~/.sts_notified_expired
~/bin/check-sts-expiry.sh
```

### launchd 동작 확인

launchd 로드 후 1분 대기하면 알림이 자동으로 수신됩니다.

로그 확인:

```bash
cat /tmp/sts-notifier.log
cat /tmp/sts-notifier.err
```

---

## 알림 상태 파일

| 파일 | 생성 시점 | 삭제 시점 |
|---|---|---|
| `~/.sts_notified_1h` | 1시간 알림 발송 후 | STS 재발급 시 |
| `~/.sts_notified_10m` | 10분 알림 발송 후 | STS 재발급 시 |
| `~/.sts_notified_expired` | 만료 알림 발송 후 | STS 재발급 시 |

알림 상태를 수동으로 초기화하려면:

```bash
rm -f ~/.sts_notified_1h ~/.sts_notified_10m ~/.sts_notified_expired
```

---

---

## Claude Code 하단 Progress Bar (statusLine)

STS 만료까지 남은 시간을 Claude Code 하단 상태바에 progress bar로 표시합니다.
bar가 차오를수록 만료 임박을 의미합니다.

```
[STS] ░░░░░░░░░░  1시간 30분 남음  만료: 03/10 09:20 KST   ← 여유 (초록)
[STS] █████░░░░░  30분 0초 남음   만료: 03/10 08:20 KST   ← 주의 (노랑)
[STS] █████████░   5분 0초 남음   만료: 03/10 07:55 KST   ← 위험 (빨강)
[STS] ██████████  만료됨           만료: 03/10 07:40 KST   ← 만료 (bold 빨강)
```

### 설치

`./install.sh` 실행 시 자동으로 `~/.claude/settings.json`에 statusLine이 등록됩니다.
수동으로 설정하려면 아래를 참고하세요.

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils/sts-notifier/sts-statusline.sh",
    "padding": 1
  }
}
```

#### 동작 확인

Claude Code에서 메시지를 하나 보내면 상태바가 갱신됩니다.

`~/.sts_expiry` 파일이 없으면 상태바에 아무것도 표시되지 않습니다.
STS를 발급하면 (`.zshrc` 수정 완료 후) 자동으로 표시됩니다.

### 수동 테스트

```bash
SCRIPT=~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils/sts-notifier/sts-statusline.sh

# 30분 후 만료로 설정하여 즉시 확인
date -u -v+30M +"%Y-%m-%dT%H:%M:%SZ" > ~/.sts_expiry
echo "" | bash "$SCRIPT"
```

---

## 제거

```bash
# launchd 에이전트 언로드
launchctl unload ~/Library/LaunchAgents/com.jellodev.sts-notifier.plist

# 파일 삭제
rm ~/Library/LaunchAgents/com.jellodev.sts-notifier.plist
rm ~/bin/check-sts-expiry.sh

# 상태 파일 삭제 (선택)
rm -f ~/.sts_expiry ~/.sts_notified_1h ~/.sts_notified_10m ~/.sts_notified_expired
```

그리고 `~/.zshrc`에서 `_sts_update`에 추가했던 코드를 제거합니다.
