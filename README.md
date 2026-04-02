# jerry-dev-utils

Claude Code 플러그인 마켓플레이스 — 개발 워크플로우 유틸리티 모음.

## 제공 플러그인

### jerry (스킬 모음)

| 스킬 | 설명 |
|------|------|
| `jerry:jerry-docs` | 프로젝트 docs 표준 폴더 구조 한 번에 생성 |

> `jerry` 하위에 스킬이 계속 추가될 예정입니다.

### 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/docs-update` | 프로젝트 루트 하위 MD 파일을 코드 현황에 맞게 최신화 |

---

## 👤 Human Guide — 설치 방법

### 1. 마켓플레이스 등록

Claude Code에서 아래 명령어로 이 레포를 마켓플레이스로 등록합니다.

```
/add-plugin jellodev/jerry-dev-utils
```

> SSH 접근이 필요한 경우 Claude Code 설정에서 GitHub 인증을 먼저 완료하세요.

### 2. jerry 플러그인 설치

마켓플레이스 등록 후 `jerry` 플러그인을 설치합니다.

```
/install jerry
```

### 3. 스킬 사용

새 세션을 열면 스킬이 활성화됩니다.

```
jerry-docs 구조 만들어줘
docs scaffold 생성해줘
backend/docs에 문서 폴더 초기화해줘
```

### 업데이트

```
/update jerry
```

---

## 🤖 AI Agent Guide

### 마켓플레이스 구조

```
jerry-dev-utils/               ← 마켓플레이스 루트 (jellodev/jerry-dev-utils)
└── plugins/
    └── jerry/                 ← 플러그인명
        └── skills/
            └── jerry-docs/    ← 스킬명 → jerry:jerry-docs 로 호출
                ├── SKILL.md
                └── scripts/
                    └── scaffold.sh
```

### 스킬 호출

```
Skill tool → skill: "jerry:jerry-docs"
```

### jerry-docs 스킬 동작

사용자가 docs 구조 생성을 요청하면:

1. 대상 경로 확인 (미지정 시 `./docs`)
2. `scripts/scaffold.sh <path>` 실행
3. 생성 결과 안내

생성 구조:
```
<docs-root>/
├── PLANS.md
├── SECURITY.md
├── RELIABILITY.md
├── ARCHITECTURE.md
├── exec-plans/
│   ├── active/
│   ├── completed/
│   └── tech-debt-tracker.md
├── product-specs/
│   └── index.md
└── references/
```

### 새 스킬 추가 방법

`plugins/jerry/skills/` 하위에 새 폴더를 만들고 `SKILL.md`를 작성하면 `jerry:<skill-name>` 으로 호출 가능합니다.

```
plugins/jerry/skills/<new-skill>/SKILL.md
```
