# sts-notifier 테스트

## 요구사항

- [bats-core](https://github.com/bats-core/bats-core) 1.x 이상
  ```bash
  brew install bats-core
  ```

## 실행

```bash
# 전체 테스트
bats test/

# 유닛 테스트만
bats test/unit/

# E2E 테스트만
bats test/e2e/

# 특정 파일
bats test/unit/check-expiry.bats
```

## 구성

| 파일 | 대상 | 설명 |
|---|---|---|
| `unit/check-expiry.bats` | `check-sts-expiry.sh` | 만료 조건 분기, 상태 파일, 중복 방지 |
| `unit/statusline.bats` | `sts-statusline.sh` | progress bar, 색상, 시간 포맷, KST 변환 |
| `e2e/notifier-flow.bats` | `check-sts-expiry.sh` | 발급→알림→재발급 전체 플로우 |
| `e2e/statusline-flow.bats` | `sts-statusline.sh` | expiry 없음→초록→노랑→빨강→만료 플로우 |

## 격리 방식

모든 테스트는 `mktemp -d`로 임시 HOME 디렉토리를 생성하고 `HOME=<tmpdir>`로 오버라이드합니다.
`osascript`(macOS 알림)는 mock 함수로 대체합니다.
