# jerry-dev-utils

Claude Code 개발 워크플로우 유틸리티 커맨드 모음.

## 커맨드 목록

| 커맨드 | 설명 |
|---|---|
| `/docs-update` | 프로젝트 루트 하위 MD 파일을 코드 현황에 맞게 최신화 |

## 설치 방법

### 1. SSH 설정 확인

`~/.ssh/config`에 jellodev 계정 설정이 있어야 합니다.

```
Host jellodev
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_personal
    IdentitiesOnly yes
```

SSH 키가 없다면 생성 후 GitHub jellodev 계정에 등록하세요.

```bash
ssh-keygen -t ed25519 -C "jello0097@hanmail.net" -f ~/.ssh/id_rsa_personal
chmod 600 ~/.ssh/id_rsa_personal
# 공개키를 GitHub → Settings → SSH Keys 에 등록
cat ~/.ssh/id_rsa_personal.pub
```

### 2. 플러그인 clone

```bash
mkdir -p ~/.claude/plugins/marketplaces/my-plugins/plugins
git clone git@jellodev:jellodev/jerry-dev-utils.git \
  ~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils
```

### 3. Claude Code settings.json에 플러그인 등록

`~/.claude/settings.json`의 `enabledPlugins`에 추가:

```json
{
  "enabledPlugins": {
    "jerry-dev-utils@my-plugins": true
  }
}
```

파일이 없으면 새로 생성:

```json
{
  "enabledPlugins": {
    "jerry-dev-utils@my-plugins": true
  }
}
```

### 4. Claude Code 재시작

새 세션을 열면 `/docs-update` 커맨드를 사용할 수 있습니다.

## 업데이트

```bash
git -C ~/.claude/plugins/marketplaces/my-plugins/plugins/jerry-dev-utils pull
```

## 커맨드 추가

`commands/` 폴더에 `.md` 파일을 추가하면 `/파일명` 커맨드로 사용할 수 있습니다.

```bash
# 예시: /lint-check 커맨드 추가
touch commands/lint-check.md
```

커맨드 파일 기본 구조:

```markdown
---
description: 커맨드 설명
allowed-tools: Read, Glob, Grep, Bash
---

## Your task

...
```
