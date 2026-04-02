#!/bin/sh
# backend-docs-scaffold
# 사용법: sh scaffold.sh [docs-root]
# docs-root 기본값: ./docs

DOCS="${1:-./docs}"

mkdir -p "$DOCS/exec-plans/active"
mkdir -p "$DOCS/exec-plans/completed"
mkdir -p "$DOCS/product-specs"
mkdir -p "$DOCS/references"

touch "$DOCS/exec-plans/active/.gitkeep"
touch "$DOCS/exec-plans/completed/.gitkeep"
touch "$DOCS/references/.gitkeep"

cat > "$DOCS/PLANS.md" <<'EOF'
# Plans

구현 계획 문서 인덱스입니다.

## 진행 중

`exec-plans/active/` 하위 문서를 참고하세요.

## 완료

`exec-plans/completed/` 하위 문서를 참고하세요.

## 기술 부채

[tech-debt-tracker.md](exec-plans/tech-debt-tracker.md)
EOF

cat > "$DOCS/SECURITY.md" <<'EOF'
# Security

보안 정책 및 고려사항을 기록합니다.

## TBD
EOF

cat > "$DOCS/RELIABILITY.md" <<'EOF'
# Reliability

안정성 목표 및 장애 대응 전략을 기록합니다.

## TBD
EOF

cat > "$DOCS/ARCHITECTURE.md" <<'EOF'
# Architecture

아키텍처 설계 및 주요 결정사항을 기록합니다.

## TBD
EOF

cat > "$DOCS/exec-plans/tech-debt-tracker.md" <<'EOF'
# Tech Debt Tracker

기술 부채 목록을 추적합니다.

| 항목 | 영역 | 우선순위 | 등록일 | 상태 |
|------|------|----------|--------|------|
EOF

cat > "$DOCS/product-specs/index.md" <<'EOF'
# Product Specs

제품 명세 문서 인덱스입니다.

## TBD
EOF

echo ""
echo "✅ docs scaffold 생성 완료: $DOCS"
echo ""
echo "  $DOCS/"
echo "  ├── PLANS.md"
echo "  ├── SECURITY.md"
echo "  ├── RELIABILITY.md"
echo "  ├── ARCHITECTURE.md"
echo "  ├── exec-plans/"
echo "  │   ├── active/"
echo "  │   ├── completed/"
echo "  │   └── tech-debt-tracker.md"
echo "  ├── product-specs/"
echo "  │   └── index.md"
echo "  └── references/"
