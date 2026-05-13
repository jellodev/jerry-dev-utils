# jerry-dev-utils

Claude Code 플러그인 마켓플레이스 — 개발 워크플로우 유틸리티 모음.

## 제공 플러그인

### jerry (스킬 모음)

| 스킬 | 설명 |
|------|------|
| `jerry:jerry-docs` | 프로젝트 docs 표준 폴더 구조 한 번에 생성 |
| `jerry:team-harness` | BE, FE, DevOps가 함께 쓰는 공통 AI 작업 하네스 정의 |
| `jerry:backend-harness` | backend 전용 문서 흐름, 검증 게이트, 리뷰 규칙 정의 |
| `jerry:aidlc` | AWS AI-DLC 적응형 소프트웨어 개발 워크플로우 (Inception → Construction → Operations) |

> `jerry` 하위에 스킬이 계속 추가될 예정입니다.

### 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/docs-update` | 프로젝트 루트 하위 MD 파일을 코드 현황에 맞게 최신화 |

---

## 👤 Human Guide — 스킬 설치 방법

아래에서 사용 중인 AI 도구를 찾아 해당 명령어를 복붙하세요.

---

### Claude Code (CLI / Desktop App / VS Code 확장)

**처음 설치하는 경우** — 아래 두 줄을 순서대로 입력하세요.

```
/add-plugin jellodev/jerry-dev-utils
```
```
/install jerry
```

**이미 설치되어 있고 최신 스킬을 받고 싶은 경우**

```
/update jerry
```

> SSH 접근이 필요한 경우 Claude Code 설정에서 GitHub 인증을 먼저 완료하세요.

새 세션을 열면 스킬이 활성화됩니다.

---

### Cursor / Windsurf / Zed (MCP 미지원, 수동 설치)

터미널에서 아래 명령어를 실행해 스킬 파일을 직접 내려받습니다.

```bash
git clone https://github.com/jellodev/jerry-dev-utils.git /tmp/jerry-dev-utils
mkdir -p ~/.claude/skills
cp -r /tmp/jerry-dev-utils/plugins/jerry/skills/aidlc ~/.claude/skills/aidlc
rm -rf /tmp/jerry-dev-utils
```

> `~/.claude/skills/` 에 파일이 있으면 Claude Code 호환 환경에서 자동 인식됩니다.

---

### Gemini CLI

Gemini CLI 는 `~/.gemini/skills/` 디렉토리를 스캔합니다. 터미널에서 실행하세요.

```bash
git clone https://github.com/jellodev/jerry-dev-utils.git /tmp/jerry-dev-utils
mkdir -p ~/.gemini/skills
cp -r /tmp/jerry-dev-utils/plugins/jerry/skills/aidlc ~/.gemini/skills/aidlc
rm -rf /tmp/jerry-dev-utils
```

---

### GitHub Copilot CLI (Copilot in the CLI)

Copilot CLI 는 `~/.agents/skills/` 디렉토리를 스캔합니다. 터미널에서 실행하세요.

```bash
git clone https://github.com/jellodev/jerry-dev-utils.git /tmp/jerry-dev-utils
mkdir -p ~/.agents/skills
cp -r /tmp/jerry-dev-utils/plugins/jerry/skills/aidlc ~/.agents/skills/aidlc
rm -rf /tmp/jerry-dev-utils
```

---

### 스킬 사용 예시

설치 후 AI에게 아래처럼 말하면 됩니다.

```
jerry-docs 구조 만들어줘
docs scaffold 생성해줘
backend/docs에 문서 폴더 초기화해줘
우리 팀 공통 AI 작업 규칙 만들어줘
backend 하네스 규칙 정리해줘
새 기능 개발 시작할게 — aidlc 워크플로우로 진행해줘
```

---

## 🤖 AI Agent Guide

### 마켓플레이스 구조

```
jerry-dev-utils/               ← 마켓플레이스 루트 (jellodev/jerry-dev-utils)
└── plugins/
    └── jerry/                 ← 플러그인명
        └── skills/
            ├── jerry-docs/        ← 스킬명 → jerry:jerry-docs 로 호출
            │   ├── SKILL.md
            │   └── scripts/
            │       └── scaffold.sh
            ├── team-harness/      ← 스킬명 → jerry:team-harness 로 호출
            │   ├── SKILL.md
            │   └── references/
            └── backend-harness/   ← 스킬명 → jerry:backend-harness 로 호출
                ├── SKILL.md
                └── references/
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

### team-harness 스킬 동작

팀 공통 AI 개발 프로세스가 필요할 때:

1. 공통 artifact contract 확인
2. 구현 전 workflow/rubric/metrics 정의
3. 도메인별 확장 스킬 사용 여부 결정

기본 측정 템플릿:
- `plugins/jerry/skills/team-harness/references/measurement-template.md`

### backend-harness 스킬 동작

backend 작업 규칙이 필요할 때:

1. backend 로컬 instruction 파일 확인
2. docs/spec/plan/quality/debt 흐름 점검
3. 검증 근거와 완료 게이트를 backend 기준으로 적용

### 새 스킬 추가 방법

`plugins/jerry/skills/` 하위에 새 폴더를 만들고 `SKILL.md`를 작성하면 `jerry:<skill-name>` 으로 호출 가능합니다.

```
plugins/jerry/skills/<new-skill>/SKILL.md
```
