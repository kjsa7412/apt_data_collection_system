#!/bin/zsh
# =============================================================================
# collect.sh — 범용 지역별 Phase 1~8 자동 수집 스크립트
# =============================================================================
# 사용법:
#   ./scripts/collect.sh --region=부산              # 부산 Phase 1~8 전체
#   ./scripts/collect.sh --region=서울 --phase=3    # 서울 Phase 3부터
#   ./scripts/collect.sh --region=대구 --resume     # 대구 이어서
#   ./scripts/collect.sh --region=경기 --phase=2 --end=5  # 경기 Phase 2~5
#   ./scripts/collect.sh --help
# =============================================================================

set -euo pipefail

PROJECT_DIR="/Users/kjsa/Documents/Project/부동심"
LOG_DIR="${PROJECT_DIR}/workspace/logs"
META_DIR="${PROJECT_DIR}/workspace/meta"
PROGRESS_FILE="${META_DIR}/phase_progress.txt"

START_PHASE=1
END_PHASE=8
RESUME=false
REGION=""
REGION_CODE=""

# ── 지역코드 매핑 ──
get_region_code() {
  case $1 in
    서울) echo "11" ;;
    부산) echo "26" ;;
    대구) echo "27" ;;
    인천) echo "28" ;;
    광주) echo "29" ;;
    대전) echo "30" ;;
    울산) echo "31" ;;
    세종) echo "36" ;;
    경기) echo "41" ;;
    강원) echo "42" ;;
    충북) echo "43" ;;
    충남) echo "44" ;;
    전북) echo "45" ;;
    전남) echo "46" ;;
    경북) echo "47" ;;
    경남) echo "48" ;;
    제주) echo "50" ;;
    *) echo ""; return 1 ;;
  esac
}

# ── 인자 파싱 ──
for arg in "$@"; do
  case $arg in
    --region=*) REGION="${arg#*=}" ;;
    --phase=*)  START_PHASE="${arg#*=}" ;;
    --end=*)    END_PHASE="${arg#*=}" ;;
    --resume)   RESUME=true ;;
    --help)
      echo "사용법:"
      echo "  ./scripts/collect.sh --region=부산              # Phase 1~8 전체"
      echo "  ./scripts/collect.sh --region=서울 --phase=3    # Phase 3부터"
      echo "  ./scripts/collect.sh --region=대구 --resume     # 이어서 실행"
      echo "  ./scripts/collect.sh --region=경기 --phase=2 --end=5"
      echo ""
      echo "지원 지역: 서울 부산 대구 인천 광주 대전 울산 세종 경기 강원 충북 충남 전북 전남 경북 경남 제주"
      exit 0
      ;;
    *) echo "알 수 없는 옵션: $arg (--help 참조)"; exit 1 ;;
  esac
done

if [[ -z "$REGION" ]]; then
  echo "오류: --region 필수. 예) --region=부산"
  echo "./scripts/collect.sh --help 참조"
  exit 1
fi

REGION_CODE=$(get_region_code "$REGION")
if [[ -z "$REGION_CODE" ]]; then
  echo "오류: 지원하지 않는 지역 '$REGION'"
  exit 1
fi

SCRIPT_LOG="${LOG_DIR}/${REGION}_loop_$(date +%Y%m%d).txt"
mkdir -p "$LOG_DIR"

# ── resume ──
if $RESUME; then
  if [[ -f "$PROGRESS_FILE" ]]; then
    LAST_DONE=$(awk -F'\t' '$2 == "완료" {gsub(/Phase/,"",$1); if($1+0 > max) max=$1+0} END {print max+0}' "$PROGRESS_FILE")
    if [[ $LAST_DONE -ge 8 ]]; then
      echo "모든 Phase가 이미 완료되었습니다."
      exit 0
    fi
    START_PHASE=$((LAST_DONE + 1))
    echo "Phase ${LAST_DONE}까지 완료. Phase ${START_PHASE}부터 재개."
  fi
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  echo "$msg" >> "$SCRIPT_LOG"
}

# ── 실행 ──
log "===== ${REGION}(${REGION_CODE}) Phase ${START_PHASE}→${END_PHASE} 시작 ====="

for phase in $(seq $START_PHASE $END_PHASE); do
  log "--- Phase ${phase} 시작 ---"
  PHASE_LOG="${LOG_DIR}/phase${phase}_${REGION}_$(date +%Y%m%d_%H%M%S).txt"

  PROMPT="너는 부동심 프로젝트의 데이터 수집 에이전트다.
프로젝트: ${PROJECT_DIR}
대상 지역: ${REGION} (시도코드: ${REGION_CODE})

.claude/CLAUDE.md를 먼저 읽고 프로젝트 원칙을 숙지하라.
.claude/commands/collect-phase.md를 읽고 Phase ${phase}의 실행 절차를 따르라.
.claude/skills/ 내 관련 skill 파일을 참고하라.
.claude/policies/ 내 정책을 반드시 준수하라.
workspace/meta/taxonomy.txt에서 Phase ${phase} 해당 대분류의 수집 항목을 확인하라.

실행: Phase ${phase}, 지역: ${REGION}
- WebSearch/WebFetch로 실데이터를 수집하라
- 결과를 workspace/output/ 해당 폴더에 탭구분 TXT로 저장하라
- 파일명 규칙: {중분류}_${REGION_CODE}_${REGION}_{시군구}.txt
- 수집 후 workspace/meta/phase_progress.txt, collection_status.txt 갱신하라
- 수집 로그를 workspace/logs/collect_log_$(date +%Y-%m-%d).txt에 append하라
- 실패 항목은 workspace/queue/failed/에 기록하라"

  if claude -p "$PROMPT" \
    --output-format text \
    --max-turns 50 \
    --cwd "$PROJECT_DIR" \
    2>&1 | tee "$PHASE_LOG"; then
    log "Phase ${phase} 완료 (성공)"
  else
    log "Phase ${phase} 완료 (오류 — 계속 진행)"
  fi
done

log "===== ${REGION}(${REGION_CODE}) Phase ${START_PHASE}→${END_PHASE} 종료 ====="
