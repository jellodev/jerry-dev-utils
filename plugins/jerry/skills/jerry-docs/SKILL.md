---
name: jerry-docs
description: 프로젝트 docs 폴더 표준 구조를 한 번에 생성한다. "docs 구조 만들어줘", "docs scaffold 생성해줘", "문서 폴더 초기화해줘" 같이 프로젝트 문서 폴더를 셋업할 때 사용한다. exec-plans(active/completed), product-specs, references 폴더와 PLANS.md, SECURITY.md, RELIABILITY.md, ARCHITECTURE.md, tech-debt-tracker.md, product-specs/index.md 파일을 생성한다.
---

# jerry-docs

프로젝트 docs 표준 구조를 생성한다.

## 사용법

```sh
sh scripts/scaffold.sh [docs-root-path]
```

- `docs-root-path` 기본값: `./docs`
- 경로를 명시적으로 지정하면 해당 위치에 생성된다.

## 예시

```sh
# 현재 디렉토리 기준 ./docs 에 생성
sh scripts/scaffold.sh

# 경로 지정
sh scripts/scaffold.sh backend/docs
sh scripts/scaffold.sh my-service/docs
```

## 생성 구조

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

## 실행 절차

1. 사용자가 원하는 docs 경로를 확인한다 (미지정 시 `./docs` 사용).
2. `scripts/scaffold.sh <path>` 를 실행한다.
3. 생성 결과를 사용자에게 안내한다.
