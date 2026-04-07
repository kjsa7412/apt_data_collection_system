# 부동심 수집 스크립트 사용 가이드

## 사전 요구사항

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 설치 및 인증 완료
- `claude` 명령어가 터미널 PATH에 등록되어 실행 가능한 상태

```bash
# 확인
which claude && claude --version
```

---

## 스크립트 목록

| 파일 | 용도 | 특징 |
|------|------|------|
| `busan_collect.sh` | 부산 지역 전용 수집 | Phase별 상세 프롬프트 내장, 높은 수집 정확도 |
| `collect.sh` | 전국 17개 시도 범용 수집 | `.claude/` 명세 파일 기반, 어떤 지역이든 사용 가능 |

---

## busan_collect.sh

부산 16개 구군을 대상으로 Phase 1~8 데이터를 자동 수집한다. 각 Phase마다 수집할 컬럼, 파일명, 저장 위치가 프롬프트에 명시되어 있어 수집 품질이 높다.

### 기본 실행

```bash
cd /Users/kjsa/Documents/Project/부동심
./scripts/busan_collect.sh
```

Phase 1(단지 마스터) → Phase 8(누락 탐지)까지 순차 실행된다.

### 옵션

```bash
# 특정 Phase부터 시작
./scripts/busan_collect.sh --phase=3

# 특정 Phase 구간만 실행
./scripts/busan_collect.sh --phase=2 --end=5

# 중단된 지점부터 이어서 (phase_progress.txt 기반)
./scripts/busan_collect.sh --resume

# 도움말
./scripts/busan_collect.sh --help
```

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `--phase=N` | 시작 Phase 번호 (1~8) | 1 |
| `--end=N` | 종료 Phase 번호 (1~8) | 8 |
| `--resume` | 마지막 완료 Phase 다음부터 재개 | - |

### Phase별 수집 내용

| Phase | 수집 내용 | 저장 위치 |
|-------|-----------|-----------|
| 1 | 단지 기본정보 (명칭, 세대수, 준공연도, 브랜드 등) | `output/02_단지스펙/` |
| 2 | 매매/전세/월세 실거래가, 호가, 거래량 | `output/01_거래가격/`, `output/18_전세임대/` |
| 3 | 교통, 학군, 생활인프라, 자연환경, 유해시설 | `output/04~10_*/` |
| 4 | 공급, 수요, 정책, 거시경제, 인구, 상권, 범죄, 재난 | `output/12~15_*/`, `output/19~22_*/` |
| 5 | 개발호재, 재건축/재개발/리모델링 | `output/16_개발호재/`, `output/17_재건축재개발/` |
| 6 | 뉴스, 커뮤니티 여론, 감성분석 | `output/23_여론뉴스/` |
| 7 | 파생지표, 종합점수, 급지등급, 컷오프 판정 | `output/25_파생지표/`, `output/26_점수등급/` |
| 8 | 누락 탐지, 재수집, 최종 인덱스 갱신 | `logs/gap_report_*.txt` |

---

## collect.sh

전국 17개 시도 어디든 동일한 방식으로 수집할 수 있는 범용 스크립트. `.claude/commands/`, `.claude/skills/`, `.claude/policies/` 명세 파일을 Claude가 직접 읽고 해석하여 실행한다.

### 기본 실행

```bash
cd /Users/kjsa/Documents/Project/부동심
./scripts/collect.sh --region=부산
```

### 옵션

```bash
# 서울 Phase 1~8 전체
./scripts/collect.sh --region=서울

# 대구 Phase 3부터
./scripts/collect.sh --region=대구 --phase=3

# 경기 Phase 2~5만
./scripts/collect.sh --region=경기 --phase=2 --end=5

# 인천 이어서 실행
./scripts/collect.sh --region=인천 --resume

# 도움말
./scripts/collect.sh --help
```

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `--region=지역명` | 수집 대상 시도 (필수) | - |
| `--phase=N` | 시작 Phase 번호 | 1 |
| `--end=N` | 종료 Phase 번호 | 8 |
| `--resume` | 이어서 실행 | - |

### 지원 지역

| 시도코드 | 지역명 | 시도코드 | 지역명 |
|----------|--------|----------|--------|
| 11 | 서울 | 43 | 충북 |
| 26 | 부산 | 44 | 충남 |
| 27 | 대구 | 45 | 전북 |
| 28 | 인천 | 46 | 전남 |
| 29 | 광주 | 47 | 경북 |
| 30 | 대전 | 48 | 경남 |
| 31 | 울산 | 50 | 제주 |
| 36 | 세종 | 41 | 경기 |
| 42 | 강원 | | |

---

## 로그 확인

스크립트 실행 중 모든 로그는 `workspace/logs/`에 저장된다.

```bash
# 전체 실행 로그 (요약)
cat workspace/logs/busan_loop_20260408.txt

# Phase별 상세 로그 (Claude 출력 전문)
cat workspace/logs/phase1_busan_20260408_100530.txt

# 수집 진행 현황
cat workspace/meta/phase_progress.txt

# 데이터 현황
cat workspace/meta/collection_status.txt

# 누락 리포트 (Phase 8 이후)
cat workspace/logs/gap_report_2026-04-08.txt
```

---

## 산출물 확인

수집된 데이터는 `workspace/output/` 하위 26개 폴더에 탭구분 TXT로 저장된다.

```bash
# 부산 관련 파일 목록
find workspace/output -name "*부산*" -type f

# 특정 파일 미리보기 (첫 5행)
head -5 workspace/output/02_단지스펙/단지마스터_26_부산_해운대구.txt

# 전체 파일 수/행 수 집계
find workspace/output -name "*.txt" | wc -l
find workspace/output -name "*부산*" -exec cat {} + | wc -l
```

---

## 중단과 재개

스크립트는 Phase 단위로 진행 상태를 `workspace/meta/phase_progress.txt`에 기록한다. 실행 중 중단되더라도 `--resume`으로 이어갈 수 있다.

```bash
# Ctrl+C로 중단 후
./scripts/busan_collect.sh --resume

# 또는 특정 Phase부터 수동 재개
./scripts/busan_collect.sh --phase=4
```

---

## 여러 지역 순차 실행

```bash
# 수도권 3개 시도 순차 실행
for region in 서울 경기 인천; do
  ./scripts/collect.sh --region=$region
done

# 광역시 전체
for region in 부산 대구 광주 대전 울산; do
  ./scripts/collect.sh --region=$region
done
```

---

## 주의사항

- 한 Phase당 평균 5~15분 소요 (데이터량과 네트워크 상황에 따라 변동)
- `claude` CLI의 API 사용량이 발생하므로 과금에 유의
- 수집된 데이터는 append-only 원칙: 기존 파일을 삭제하거나 덮어쓰지 않음
- 프로젝트 루트의 마스터 파일(요소.txt, 코드마스터 등)은 읽기 전용으로 절대 수정되지 않음
