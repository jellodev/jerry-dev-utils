---
name: aidlc
description: AWS AI-Driven Lifecycle Consulting (AI-DLC) 적응형 소프트웨어 개발 워크플로우. 사용자가 새로운 기능 개발, 시스템 설계, 코드 구현, 리팩토링, 인프라 설계 등 소프트웨어 개발 관련 요청을 할 때 이 스킬을 사용하라. 단순 질문이 아닌 실제 개발 작업이면 항상 이 워크플로우를 먼저 적용하라. Inception(요구사항 분석 및 계획) → Construction(설계 및 구현) → Operations 3단계로 적응적으로 진행한다.
---

# AWS AI-DLC Adaptive Workflow

## 시작 전 필독

이 스킬은 모든 규칙 세부 파일을 `references/` 디렉토리에 번들로 포함하고 있다.
모든 파일 경로는 이 `references/` 디렉토리를 루트로 해석한다.

**Claude Code 환경**: `references/` = `~/.claude/skills/aidlc-skill/references/`
**Claude.ai 환경**: `references/` = 이 스킬 패키지 내부의 references 디렉토리

## Step 1: 핵심 워크플로우 로드

`references/core-workflow.md` 를 읽고 전체 워크플로우 규칙을 파악하라.

## Step 2: 공통 규칙 로드

워크플로우 시작 시 반드시 다음 파일들을 읽어라:
- `references/common/process-overview.md`
- `references/common/session-continuity.md`
- `references/common/content-validation.md`
- `references/common/question-format-guide.md`

## Step 3: Extensions 스캔

`references/extensions/` 디렉토리를 재귀 탐색하되,
`*.opt-in.md` 파일만 읽어라 (전체 규칙 파일은 사용자 승인 후 로드).

## Step 4: 환영 메시지 표시

`references/common/welcome-message.md` 를 읽고 사용자에게 표시하라.
(새 워크플로우 시작 시 1회만)

## Step 5: 워크플로우 실행

`core-workflow.md` 의 지시에 따라 단계별로 진행하라.

각 단계에서 참조하는 파일들:

| 단계 | 파일 |
|---|---|
| Workspace Detection | `references/inception/workspace-detection.md` |
| Reverse Engineering | `references/inception/reverse-engineering.md` |
| Requirements Analysis | `references/inception/requirements-analysis.md` |
| User Stories | `references/inception/user-stories.md` |
| Workflow Planning | `references/inception/workflow-planning.md` |
| Application Design | `references/inception/application-design.md` |
| Units Generation | `references/inception/units-generation.md` |
| Functional Design | `references/construction/functional-design.md` |
| NFR Requirements | `references/construction/nfr-requirements.md` |
| NFR Design | `references/construction/nfr-design.md` |
| Infrastructure Design | `references/construction/infrastructure-design.md` |
| Code Generation | `references/construction/code-generation.md` |
| Build and Test | `references/construction/build-and-test.md` |
| Operations | `references/operations/operations.md` |

보조 규칙:
- `references/common/depth-levels.md`
- `references/common/error-handling.md`
- `references/common/overconfidence-prevention.md`
- `references/common/ascii-diagram-standards.md`
- `references/common/terminology.md`

## 인자 처리

사용자가 `/aidlc <태스크 설명>` 형태로 호출했다면,
`<태스크 설명>`을 초기 사용자 요청으로 간주하고 audit.md에 첫 번째 항목으로 기록하라.
