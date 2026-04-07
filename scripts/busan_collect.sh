#!/bin/zsh
# =============================================================================
# busan_collect.sh — 부산 지역 Phase 1~8 자동 수집 스크립트
# =============================================================================
# 사용법:
#   ./scripts/busan_collect.sh              # Phase 1부터 전체 실행
#   ./scripts/busan_collect.sh --resume     # 마지막 완료 Phase 다음부터 이어서
#   ./scripts/busan_collect.sh --phase=3    # 특정 Phase부터 시작
#   ./scripts/busan_collect.sh --phase=2 --end=5  # Phase 2~5만 실행
# =============================================================================

set -euo pipefail

# ── 설정 ──
PROJECT_DIR="/Users/kjsa/Documents/Project/부동심"
REGION="부산"
REGION_CODE="26"
LOG_DIR="${PROJECT_DIR}/workspace/logs"
META_DIR="${PROJECT_DIR}/workspace/meta"
PROGRESS_FILE="${META_DIR}/phase_progress.txt"
SCRIPT_LOG="${LOG_DIR}/busan_loop_$(date +%Y%m%d).txt"

START_PHASE=1
END_PHASE=8
RESUME=false

# ── 인자 파싱 ──
for arg in "$@"; do
  case $arg in
    --resume)
      RESUME=true
      ;;
    --phase=*)
      START_PHASE="${arg#*=}"
      ;;
    --end=*)
      END_PHASE="${arg#*=}"
      ;;
    --help)
      echo "사용법:"
      echo "  ./scripts/busan_collect.sh              # Phase 1부터 전체"
      echo "  ./scripts/busan_collect.sh --resume     # 이어서 실행"
      echo "  ./scripts/busan_collect.sh --phase=3    # Phase 3부터"
      echo "  ./scripts/busan_collect.sh --phase=2 --end=5  # Phase 2~5"
      exit 0
      ;;
    *)
      echo "알 수 없는 옵션: $arg (--help 참조)"
      exit 1
      ;;
  esac
done

# ── 디렉토리 확인 ──
mkdir -p "$LOG_DIR"

# ── resume 처리: phase_progress.txt에서 마지막 완료 Phase 찾기 ──
if $RESUME; then
  if [[ -f "$PROGRESS_FILE" ]]; then
    # 완료된 Phase 중 가장 큰 번호 + 1
    LAST_DONE=$(awk -F'\t' '$2 == "완료" {gsub(/Phase/,"",$1); if($1+0 > max) max=$1+0} END {print max+0}' "$PROGRESS_FILE")
    if [[ $LAST_DONE -ge 8 ]]; then
      echo "[$(date '+%H:%M:%S')] 모든 Phase가 이미 완료되었습니다."
      exit 0
    fi
    START_PHASE=$((LAST_DONE + 1))
    echo "[$(date '+%H:%M:%S')] Phase ${LAST_DONE}까지 완료 확인. Phase ${START_PHASE}부터 재개합니다."
  else
    echo "[$(date '+%H:%M:%S')] progress 파일 없음. Phase 1부터 시작합니다."
    START_PHASE=1
  fi
fi

# ── 로그 함수 ──
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  echo "$msg" >> "$SCRIPT_LOG"
}

# ── Phase별 프롬프트 생성 ──
build_prompt() {
  local phase=$1

  # 공통 앞부분
  local common_prefix="너는 부동심 프로젝트의 데이터 수집 에이전트다.
프로젝트 디렉토리: ${PROJECT_DIR}
대상 지역: ${REGION} (시도코드: ${REGION_CODE})
현재 작업: Phase ${phase}

.claude/CLAUDE.md의 핵심 원칙을 따르라:
- append-only (기존 데이터 삭제 금지)
- 탭구분 TXT (엑셀 붙여넣기 가능)
- 기존 루트 마스터 파일(요소.txt 등) 수정 금지
- UTF-8, LF 줄바꿈, 숫자에 콤마 없음

파일명 규칙: {중분류}_26_부산_{구군}.txt
부산 구군 목록: 중구, 서구, 동구, 영도구, 부산진구, 동래구, 남구, 북구, 해운대구, 사하구, 금정구, 강서구, 연제구, 수영구, 사상구, 기장군

"

  # Phase별 구체 지시
  case $phase in
    1)
      cat <<PROMPT
${common_prefix}
[Phase 1 — 단지 마스터 기반 구축]

실행할 작업:
1. WebSearch로 부산광역시 아파트 단지 기본정보를 수집하라
   - 검색 키워드: "부산 아파트 단지 목록", "부산 {구군명} 아파트", 공동주택 관리정보시스템 등
2. 수집할 컬럼 (탭구분):
   수집일자	단지코드	단지명	시도	시군구	법정동	도로명주소	위도	경도	총세대수	동수	최고층수	준공연도	시공사	브랜드등급	복도유형	난방방식	용적률	건폐율	총주차대수	세대당주차
3. 구군별로 분리 저장: workspace/output/02_단지스펙/단지마스터_26_부산_{구군}.txt
4. 각 파일 첫 행은 헤더, 이후 데이터행 append
5. 수집 완료 후:
   - workspace/meta/phase_progress.txt에서 Phase1 행을 "진행중" 또는 "완료"로 갱신
   - workspace/meta/collection_status.txt에서 02_단지스펙 행 갱신
   - workspace/logs/collect_log_$(date +%Y-%m-%d).txt에 로그 append

가능한 한 많은 단지를 수집하라. 공공데이터 API가 없으면 WebSearch/WebFetch로 대체 수집하라.
PROMPT
      ;;
    2)
      cat <<PROMPT
${common_prefix}
[Phase 2 — 거래/가격/전세/매물 축적]

선행조건: workspace/output/02_단지스펙/ 에 부산 단지마스터가 존재해야 한다. 먼저 확인하라.

실행할 작업:
1. 국토부 실거래가 공개시스템 또는 WebSearch로 부산 아파트 실거래가 데이터 수집
   - 매매실거래, 전세실거래, 월세실거래
2. 매매실거래 컬럼:
   수집일자	단지코드	단지명	시도	시군구	법정동	전용면적	거래금액	거래층	거래일자	거래유형	해제여부
3. 전세실거래 컬럼:
   수집일자	단지코드	단지명	시도	시군구	법정동	전용면적	보증금	거래층	거래일자	계약기간
4. 저장 위치:
   - workspace/output/01_거래가격/매매실거래_26_부산_{구군}.txt
   - workspace/output/01_거래가격/전세실거래_26_부산_{구군}.txt
   - workspace/output/18_전세임대/전세현황_26_부산_{구군}.txt
5. 수집 완료 후 meta 파일 갱신 (phase_progress, collection_status, collect_log)

최근 1년치 거래 데이터를 우선 수집하라.
PROMPT
      ;;
    3)
      cat <<PROMPT
${common_prefix}
[Phase 3 — 입지/교통/학군/생활권 축적]

실행할 작업:
1. 부산 주요 단지별 교통/입지 데이터 수집 (WebSearch 활용)
   - 04_입지: 급지, 생활권, 미세입지
   - 05_교통: 최근접역, 도보시간, 노선가치, 광역교통
   - 06_직주근접: 부산 주요 업무지구(서면, 센텀시티, 부산역, 해운대)까지 통근시간
   - 07_학군: 배정초등학교, 학원가, 학군 평판
   - 08_생활인프라: 편의점, 마트, 병원, 공원 접근성
   - 09_자연환경: 해변, 산, 공원, 대기질
   - 10_유해시설: 혐오시설, 소음원

2. 저장 위치 (각각 탭구분 TXT):
   - workspace/output/04_입지/입지_26_부산.txt
   - workspace/output/05_교통/역세권_26_부산.txt
   - workspace/output/06_직주근접/직주근접_26_부산.txt
   - workspace/output/07_학군/학군_26_부산.txt
   - workspace/output/08_생활인프라/생활인프라_26_부산.txt
   - workspace/output/09_자연환경/자연환경_26_부산.txt
   - workspace/output/10_유해시설/유해시설_26_부산.txt

3. taxonomy.txt의 해당 대분류 컬럼 구조를 참고하여 헤더 작성
4. 수집 완료 후 meta 파일 갱신
PROMPT
      ;;
    4)
      cat <<PROMPT
${common_prefix}
[Phase 4 — 지역 거시지표/정책/공급 축적]

실행할 작업:
1. 부산광역시 시군구 단위 거시지표 수집 (WebSearch 활용)
   - 12_공급: 입주물량, 미분양, 분양예정, 청약경쟁률
   - 13_수요: 수요층 구성, 전입전출, 수요유입
   - 14_정책규제: 규제지역 지정현황, 세금, 대출한도, 청약규제
   - 15_거시경제: 기준금리, 주담대금리, CPI, 실업률 (전국 데이터)
   - 19_인구가구: 구군별 인구, 가구수, 고령화율, 소득
   - 20_상권소비: 구군별 상권규모, 공실률
   - 21_범죄안전: 구군별 범죄율, CCTV, 치안
   - 22_재난환경: 침수이력, 지반, 대기질

2. 저장 위치:
   - workspace/output/12_공급/입주물량_26_부산.txt
   - workspace/output/13_수요/수요현황_26_부산.txt
   - workspace/output/14_정책규제/정책현황_26_부산.txt
   - workspace/output/15_거시경제/거시경제_전국.txt
   - workspace/output/19_인구가구/인구_26_부산.txt
   - workspace/output/20_상권소비/상권_26_부산.txt
   - workspace/output/21_범죄안전/범죄안전_26_부산.txt
   - workspace/output/22_재난환경/재난환경_26_부산.txt

3. 수집 완료 후 meta 파일 갱신
PROMPT
      ;;
    5)
      cat <<PROMPT
${common_prefix}
[Phase 5 — 개발호재/정비사업/도시계획 축적]

실행할 작업:
1. 부산 개발호재/정비사업 데이터 수집 (WebSearch 활용)
   - 16_개발호재: GTX/신규노선(부산지하철 연장, BRT), 신도시, 도시재생, 대형쇼핑몰, 기업이전, 북항재개발, 에코델타시티, 센텀2지구 등
   - 17_재건축재개발: 부산 재건축/재개발 추진 단지, 안전진단, 정비구역, 리모델링

2. 저장 위치:
   - workspace/output/16_개발호재/개발사업_26_부산.txt
     컬럼: 수집일자	사업명	사업유형	위치	규모	추진단계	착공예정	완공예정	영향지역	가격반영도	비고
   - workspace/output/17_재건축재개발/정비사업_26_부산.txt
     컬럼: 수집일자	단지명	시군구	사업유형	추진단계	안전진단등급	용적률갭	대지지분	예상비례율	예상분담금	비고

3. 수집 완료 후 meta 파일 갱신
PROMPT
      ;;
    6)
      cat <<PROMPT
${common_prefix}
[Phase 6 — 뉴스/커뮤니티/여론/이슈 축적]

실행할 작업:
1. 부산 부동산 관련 최신 뉴스/여론 수집 (WebSearch 활용)
   - 검색 키워드: "부산 아파트 시세", "부산 부동산 전망", "부산 재개발", "해운대 아파트", "부산 분양", "부산 전세", 구군별 키워드
2. 수집 항목: 뉴스 제목, 요약(2~3문장), 출처, 날짜, 관련지역, 감성(긍정/부정/중립)

3. 저장 위치:
   - workspace/output/23_여론뉴스/뉴스_$(date +%Y%m%d).txt
     컬럼: 수집일자	제목	요약	출처	원문날짜	관련지역	감성	키워드
   - workspace/output/23_여론뉴스/감성분석_26_부산.txt
     컬럼: 수집일자	지역	긍정비율	부정비율	중립비율	주요키워드	급상승이슈	리스크시그널

4. 수집 완료 후 meta 파일 갱신
PROMPT
      ;;
    7)
      cat <<PROMPT
${common_prefix}
[Phase 7 — 파생지표/스코어/비교평가 생성]

실행할 작업:
1. Phase 1~6에서 수집된 workspace/output/ 내 부산 관련 파일을 모두 읽어라
2. 읽은 데이터를 기반으로 파생지표를 계산하라:
   - 25_파생지표: 평당가, 가격변동률, 전세가율, 갭투자금액, 환금성등급, 입지종합점수, 상품성점수, 미래가치등급
   - 26_점수등급: 실거주점수(0~100), 투자점수(0~100), 종합점수, 급지등급(S/A/B/C/D), 컷오프판정(PASS/WARN/FAIL)
3. 점수 산출 시 컷오프_마스터.txt의 PASS/WARN/FAIL 기준 적용

4. 저장 위치:
   - workspace/output/25_파생지표/파생지표_26_부산.txt
     컬럼: 수집일자	단지코드	단지명	시군구	평당가	가격변동률_3M	가격변동률_1Y	전세가율	갭투자금액	환금성등급	입지종합점수	상품성점수	미래가치등급
   - workspace/output/26_점수등급/종합점수_26_부산.txt
     컬럼: 수집일자	단지코드	단지명	시군구	실거주점수	투자점수	종합점수	급지등급	시군구내랭킹	실거주판정	투자판정	가구유형적합도

5. 수집 완료 후 meta 파일 갱신
PROMPT
      ;;
    8)
      cat <<PROMPT
${common_prefix}
[Phase 8 — 누락 탐지 및 재수집]

실행할 작업:
1. workspace/meta/taxonomy.txt를 읽고 부산 관련 예상 데이터 목록을 생성하라
2. workspace/output/ 전체를 스캔하여 부산 데이터 현황을 파악하라
3. 누락 항목을 탐지하라:
   - 파일 자체 부재 (HIGH)
   - 파일은 있으나 행 부족 (MED)
   - 필수 컬럼 빈값 과다 (LOW)
   - 특정 구군 데이터 누락 (MED)
4. 누락 리포트 저장:
   - workspace/logs/gap_report_$(date +%Y-%m-%d).txt
     컬럼: 대분류	중분류	항목	누락유형	심각도	상세	권장조치	관련Phase
5. HIGH 심각도 항목이 있으면 해당 Phase의 수집을 재시도하라
6. 최종 진행 현황을 정리하여 출력하라:
   - workspace/meta/phase_progress.txt 갱신 (모든 Phase "완료")
   - workspace/meta/collection_status.txt 갱신
   - workspace/meta/master_index.txt 갱신 (모든 output 파일 인덱싱)

7. 최종 요약을 workspace/logs/report_$(date +%Y-%m-%d).txt로 저장
PROMPT
      ;;
  esac
}

# ── 메인 실행 루프 ──
log "=========================================="
log "부산 지역 수집 시작: Phase ${START_PHASE} → ${END_PHASE}"
log "=========================================="

for phase in $(seq $START_PHASE $END_PHASE); do
  log "------------------------------------------"
  log "Phase ${phase} 시작"
  log "------------------------------------------"

  PROMPT=$(build_prompt $phase)
  PHASE_LOG="${LOG_DIR}/phase${phase}_busan_$(date +%Y%m%d_%H%M%S).txt"

  # Claude Code CLI 실행 (프로젝트 디렉토리에서)
  if (cd "$PROJECT_DIR" && claude -p "$PROMPT" \
    --output-format text \
    --max-turns 50) \
    2>&1 | tee "$PHASE_LOG"; then
    log "Phase ${phase} 완료 (성공)"
  else
    log "Phase ${phase} 완료 (오류 발생 — 다음 Phase로 계속)"
  fi

  log "Phase ${phase} 로그: ${PHASE_LOG}"
done

log "=========================================="
log "부산 지역 수집 완료: Phase ${START_PHASE} → ${END_PHASE}"
log "=========================================="
