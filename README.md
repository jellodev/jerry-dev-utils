# jerry-dev-utils

Claude Code 플러그인 - 개발 워크플로우 유틸리티 커맨드 모음.

프로젝트에서 반복적으로 수행하는 작업을 `/슬래시 커맨드`로 자동화합니다.

## 커맨드 목록

| 커맨드 | 설명 |
|---|---|
| `/docs-update` | 프로젝트 루트 하위 MD 파일을 코드 현황에 맞게 최신화 |

## Shell 유틸리티

| 유틸리티 | 설명 |
|---|---|
| `sts-notifier` | STS 임시 자격증명 만료 1시간/10분 전 macOS 알림 + Claude Code 하단 progress bar |

설치 방법: [`docs/sts-notifier-setup.md`](docs/sts-notifier-setup.md)

테스트: `bats --recursive sts-notifier/test/` (requires `brew install bats-core`)

## 요구사항

- [Claude Code](https://claude.ai/code) 설치
- GitHub 계정 및 SSH 설정

## 설치

### 1. 이 repo를 Claude Code 플러그인 경로에 clone

```bash
mkdir -p ~/.claude/plugins/marketplaces/my-plugins/plugins
git clone git@github.com:jellodev/jerry-dev-utils.git \
  ~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils
```

> SSH 대신 HTTPS를 사용한다면:
> ```bash
> git clone https://github.com/jellodev/jerry-dev-utils.git \
>   ~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils
> ```

### 2. Claude Code settings.json에 플러그인 등록

`~/.claude/settings.json`을 열고 `enabledPlugins`에 아래 항목을 추가합니다.

```json
{
  "enabledPlugins": {
    "jerry-dev-utils@my-plugins": true
  }
}
```

`settings.json`이 없다면 위 내용으로 새로 생성하세요.

### 3. Claude Code 재시작

새 세션을 열면 커맨드를 바로 사용할 수 있습니다.

```
/docs-update
```

## 업데이트

새 커맨드가 추가되거나 기존 커맨드가 수정되었을 때 아래 명령어로 최신 상태를 반영합니다.

```bash
git -C ~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils pull
```

## 기여

새 커맨드를 추가하고 싶다면 `commands/` 폴더에 `.md` 파일을 추가하고 PR을 보내주세요.

커맨드 파일 기본 구조:

```markdown
---
description: 커맨드 설명
allowed-tools: Read, Glob, Grep, Bash
---

## Your task

(작업 지시 내용)
```

파일명이 커맨드명이 됩니다. 예: `lint-check.md` → `/lint-check`
