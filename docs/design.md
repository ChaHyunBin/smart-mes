# smart-mes 설계서 — 생산·품질·설비 통합 MES

작성일: 2026-10-14

## 1. 프로젝트 개요

가상 가공 라인(MCT/CNC 3대)을 대상으로 생산·품질·설비 업무를 하나의 웹 시스템으로 묶는다. 작업지시와 실적을 관리하고, 비전 검사로 불량을 판정하며, 설비 데이터로 고장 징후를 미리 알린다.

이 프로젝트의 중심은 **백엔드·프론트엔드를 혼자 끝까지 만든 웹 시스템**이다. AI(비전 판정, 이상 점수)는 별도 Python 서비스로 두고, Spring Boot가 그 결과를 실적·불량·알람·정비 업무에 연결한다.

| 구분 | 선택 |
| --- | --- |
| 프론트엔드 | Vue 3, Vite, Vue Router, Pinia, Axios, Chart.js, STOMP.js |
| 백엔드 | Java 17, Spring Boot 4, Spring Security + JWT, MyBatis, WebSocket(STOMP), springdoc-openapi |
| DB | MySQL 8 |
| 설비 연동 | 1단계 MQTT (Mosquitto), 2단계 OPC UA (Eclipse Milo) |
| 분석 서비스 | Python FastAPI (비전 판정, 이상 점수) |
| 시뮬레이터 | Python (paho-mqtt, asyncua) |
| 인프라 | Docker Compose, GitHub Actions, 클라우드 또는 Linux 서버 배포 |

범위 밖: 실제 PLC 하드웨어, ERP 실연동(CSV로 대체), 다공장·다법인.

## 2. 채용공고 요구 역량과 증명 방법

| 공고 요구 역량 | 이 프로젝트에서 보여줄 것 |
| --- | --- |
| Java·Spring Boot, REST API | 도메인별 패키지, 공통 응답·예외, Swagger 문서, 페이징·검색 |
| 인증·권한 | Spring Security + JWT, 역할별(관리자·담당자·작업자) 접근 제어 |
| RDB 설계·SQL | 정규화 ERD, 실적·불량·OEE 집계 쿼리, 인덱스 설계 근거 |
| 대용량·시계열 데이터 | 1초 주기 설비 신호 배치 저장, 일자 파티션, 집계 테이블 |
| 프론트엔드(Vue/React) | 공통 컴포넌트, 라우터 권한 가드, 실시간 차트, 태블릿 작업자 화면 |
| 실시간 처리 | MQTT 수집 → WebSocket 푸시, 알람 즉시 표시 |
| 설비 연동(MQTT, OPC UA, PLC) | 시뮬레이터·수집기, 통신 끊김 처리, 2단계 OPC UA |
| 제조 업무 이해 | 작업지시→가공→검사→실적, 불량 파레토, OEE, 공구 수명, 정비 이력 |
| AI 결과의 업무 연동 | 비전 판정 → 불량 자동 등록, 이상 점수 → 알람·정비 요청 |
| 외부 시스템 연동 | FastAPI 호출(타임아웃·재시도), ERP 주문 CSV 업로드 |
| Git·배포 | 커밋 규칙, GitHub Actions CI, 실제 접속 가능한 배포 주소 |
| 운영(SM) | 감사 로그, 알람 조치 이력, 장애 대응 시나리오 문서 |

## 3. 시스템 아키텍처

```
[설비 시뮬레이터 (Python, 3대)] ──MQTT──▶ [Mosquitto]
                                              │ 구독
                                              ▼
┌──────────────── Spring Boot 백엔드 ────────────────┐       ┌── Python FastAPI ──┐
│ collector : 신호 저장 · 상태 구간 · 자동 실적        │──HTTP▶│ /vision/inspect    │
│ production / quality / equipment / maintenance     │◀──────│ /anomaly/score     │
│ REST API (/api/v1, JWT) · WebSocket(STOMP)          │       └────────────────────┘
│ 배치 : OEE 일별 집계 · 이상 점수 주기 계산           │
└────────────────────────────────────────────────────┘
        ▲ MyBatis                     ▲ REST · WebSocket
        ▼                             ▼
     [MySQL 8]                 [Vue 3 프론트엔드]

(2단계) 시뮬레이터 OPC UA 서버 ──OPC UA 구독──▶ collector
```

- 설비 신호는 collector가 받아 저장하고, 같은 값을 WebSocket으로 화면에 바로 보낸다.
- 비전 검사: 작업자가 이미지를 올리면 백엔드가 FastAPI에 판정을 요청하고, 결과를 검사 이력과 실적 불량 수량에 반영한다.
- 예지보전: 배치가 최근 신호(스핀들 부하·진동·온도)를 FastAPI에 보내 이상 점수를 받고, 임계치를 넘으면 알람과 정비 요청을 만든다.

## 4. 기능 목록

P1만 완성해도 제출 가능한 MES가 되게 잡았다. P2가 이 프로젝트의 차별점이다.

| 우선순위 | 영역 | 기능 |
| --- | --- | --- |
| P1 | 공통 | 로그인(JWT), 역할별 메뉴·접근 제어, 감사 로그 |
| P1 | 기준정보 | 품목, 공정(라우팅), 설비, 불량코드, 사용자 CRUD · 페이징·검색 · 엑셀 업로드/다운로드 |
| P1 | 생산 | 작업지시 등록·설비 배정·상태 변경, 실적 자동 집계 + 작업자 수동 등록 |
| P1 | 설비 모니터링 | 설비별 상태(가동/정지/알람/오프라인), 부하·RPM 실시간 차트 |
| P1 | 대시보드 | 금일 생산량, 목표 대비 달성률, 설비 가동 현황, 미확인 알람 |
| P2 | 품질 · 비전 검사 | 이미지 업로드 → 판정(양품/불량·유형·신뢰도) → 불량 자동 등록, 검사 이력 조회 |
| P2 | 품질 · 분석 | 불량 유형 파레토, 품목·설비별 불량률 |
| P2 | 설비 · 알람 | 임계치·통신 끊김 알람, 확인·조치 기록 |
| P2 | 설비 · 예지보전 | 설비별 이상 점수 추이, 임계 초과 시 정비 요청 자동 생성 |
| P2 | 설비 · 정비 | 정비 요청 → 처리 → 완료 이력, 공구 사용 횟수·수명 임박 알림 |
| P2 | OEE | 가동률 × 성능 × 품질, 설비·일자별 추이 |
| P3 | 연동 | ERP 주문 CSV → 작업지시 생성, OPC UA 수집 |

## 5. ERD

| 묶음 | 테이블 | 주요 컬럼 | 관계 |
| --- | --- | --- | --- |
| 기준정보 | item | item_id, item_code, item_name, std_cycle_sec | — |
| 기준정보 | routing | routing_id, item_id, seq, process_name, equipment_type | item 1:N |
| 기준정보 | equipment | equipment_id, equipment_code, name, type, status, mqtt_topic | — |
| 기준정보 | defect_code | defect_code, defect_name, category | — |
| 기준정보 | tool | tool_id, equipment_id, tool_no, life_limit_count, used_count | equipment 1:N |
| 기준정보 | app_user | user_id, login_id, password_hash, name, role | — |
| 생산 | work_order | wo_id, wo_no, item_id, equipment_id, plan_qty, status, plan_date, started_at, finished_at | item·equipment N:1 |
| 생산 | production_result | result_id, wo_id, equipment_id, good_qty, defect_qty, source(AUTO/MANUAL), created_by, created_at | work_order 1:N |
| 품질 | inspection | inspection_id, wo_id, equipment_id, image_path, verdict(OK/NG), defect_code, confidence, model_version, inspected_by, inspected_at | work_order 1:N |
| 품질 | defect_record | defect_id, result_id, inspection_id, defect_code, qty, source(VISION/MANUAL), note | production_result 1:N |
| 설비 | equipment_signal | signal_id, equipment_id, ts, run_state, spindle_load, spindle_rpm, vibration, temperature, part_count | equipment 1:N, 일자 파티션 |
| 설비 | equipment_state_log | log_id, equipment_id, state, start_ts, end_ts, duration_sec | 가동률 계산 |
| 설비 | alarm | alarm_id, equipment_id, alarm_type, alarm_code, level, occurred_at, ack_by, ack_at, action_note | equipment 1:N |
| 설비 | anomaly_score | equipment_id, calc_ts, score, threshold, features_json | equipment 1:N |
| 설비 | maintenance_order | mo_id, equipment_id, alarm_id, reason, status(REQUESTED/IN_PROGRESS/DONE), requested_at, done_at, done_by, note | equipment 1:N |
| 집계 | oee_daily | equipment_id, work_date, availability, performance, quality, oee | 배치 |
| 운영 | audit_log | log_id, user_id, action, target, created_at | — |

OEE: 가동률 = 가동시간 ÷ 계획시간, 성능 = (생산수량 × 표준사이클) ÷ 가동시간, 품질 = 양품 ÷ 생산수량.

## 6. API 명세

| 메서드 | 경로 | 설명 |
| --- | --- | --- |
| POST | /api/v1/auth/login, /auth/refresh | 로그인, 토큰 재발급 |
| GET/POST/PUT/DELETE | /api/v1/items, /routings, /equipments, /defect-codes, /tools, /users | 기준정보 CRUD (page, size, 검색) |
| GET/POST | /api/v1/items/excel | 엑셀 다운로드 / 업로드 |
| GET/POST | /api/v1/work-orders | 작업지시 목록 / 등록 |
| PATCH | /api/v1/work-orders/{id}/status | 시작·완료 |
| GET/POST | /api/v1/results | 실적 조회 / 수동 등록 |
| POST | /api/v1/inspections | 이미지 업로드 → 비전 판정 → 결과 저장 |
| GET | /api/v1/inspections?woId=&verdict= | 검사 이력 |
| GET | /api/v1/quality/pareto?from=&to= | 불량 파레토 |
| GET | /api/v1/equipments/{id}/signals?from=&to= | 설비 신호 조회 |
| GET | /api/v1/equipments/{id}/anomaly?from=&to= | 이상 점수 추이 |
| GET / PATCH | /api/v1/alarms, /alarms/{id}/ack | 알람 조회 / 확인·조치 |
| GET/POST/PATCH | /api/v1/maintenance-orders | 정비 요청·처리 |
| GET | /api/v1/dashboard/summary?date= | 대시보드 요약 |
| GET | /api/v1/oee?equipmentId=&from=&to= | OEE 추이 |

| WebSocket 채널 | 내용 |
| --- | --- |
| /topic/equipment/status | 설비 상태 변경 |
| /topic/equipment/{id}/signal | 설비별 실시간 값 |
| /topic/alarm | 신규 알람(통신·임계치·이상 점수) |

| 분석 서비스 (FastAPI) | 입력 → 출력 |
| --- | --- |
| POST /vision/inspect | 이미지 → verdict, defect_type, confidence, model_version |
| POST /anomaly/score | 설비 최근 신호 구간 → score, threshold, top_features |

비전 모델은 1차로 공개 표면 결함 데이터셋 기반 YOLOv8 분류(또는 간단한 규칙 기반)로 시작하고, 모델 교체가 가능하도록 응답 형식만 고정한다. 이상 점수는 1차로 이동평균·표준편차 기반 점수, 2차로 Isolation Forest를 적용한다.

## 7. 화면 구성

| 메뉴 | 화면 | 주요 요소 | 역할 |
| --- | --- | --- | --- |
| 대시보드 | 생산 현황 | 생산량·달성률 카드, 설비 타일, 시간대별 생산 차트, 미확인 알람 | 관리자·담당자 |
| 생산 | 작업지시 관리 | 검색·페이징 그리드, 등록 모달, 설비 배정 | 담당자 |
| 생산 | 작업자 화면(태블릿) | 진행 중 지시, 시작/완료, 수량 입력, 검사 사진 촬영·업로드 | 작업자 |
| 품질 | 검사 이력 | 판정 결과·이미지 미리보기·신뢰도 필터 | 담당자 |
| 품질 | 불량 분석 | 파레토, 품목·설비별 불량률 | 담당자 |
| 설비 | 실시간 모니터링 | 설비 상태 타일, 부하·진동 라인차트 | 공통 |
| 설비 | 예지보전 | 이상 점수 추이·임계선, 정비 요청 버튼 | 담당자 |
| 설비 | 알람·정비 | 알람 확인·조치, 정비 요청 처리 이력, 공구 수명 | 공통 |
| 설비 | OEE 분석 | 가동률·성능·품질 분해 차트 | 관리자 |
| 기준정보 | 품목·라우팅·설비·불량코드·사용자 | 공통 그리드 CRUD, 엑셀 업·다운로드 | 관리자 |

## 8. 설비 연동

| 토픽 | 주기 | 페이로드 예시 |
| --- | --- | --- |
| factory/line1/{code}/signal | 1초 | `{"ts":"…","runState":"RUN","spindleLoad":42.5,"spindleRpm":8000,"vibration":1.2,"temperature":36.4,"partCount":128,"toolNo":3}` |
| factory/line1/{code}/alarm | 발생 시 | `{"ts":"…","alarmCode":"SP-OVERLOAD","level":"WARN"}` |
| factory/line1/{code}/status | retain | `{"state":"ONLINE"}` (Last Will로 OFFLINE) |

시뮬레이터 시나리오: 정상 가동, 공구 마모(부하·진동 점진 상승), 베어링 이상(진동·온도 상승 → 예지보전 검출 대상), 비계획 정지, 통신 끊김.

수집기 규칙: 1초 버퍼 배치 INSERT, runState 변경 시 상태 구간 마감·생성, partCount 증가분을 진행 중 작업지시 실적에 반영, 30초 무수신 시 OFFLINE·알람.

## 9. 개발 환경 (Windows, winget)

```powershell
winget install -e --id Git.Git
winget install -e --id EclipseAdoptium.Temurin.17.JDK
winget install -e --id OpenJS.NodeJS.LTS
winget install -e --id Python.Python.3.11
winget install -e --id Docker.DockerDesktop
winget install -e --id Microsoft.VisualStudioCode
winget install -e --id JetBrains.IntelliJIDEA.Community
wsl --install
```

설치 후 재부팅 → Docker Desktop 첫 실행. Spring Boot·MyBatis(Gradle), Vue 3(npm), FastAPI·paho-mqtt(pip), MySQL·Mosquitto(Docker)는 프로젝트 파일에서 자동으로 받는다.

## 10. 일정

| 주차 | 내용 | 결과물 |
| --- | --- | --- |
| 1 | 환경 설치, 저장소, Docker Compose, 스키마·시드, 로그인(백·프론트) | 로그인 후 빈 레이아웃 |
| 2 | 기준정보 CRUD, 공통 컴포넌트, 예외·응답, Swagger | 기준정보 화면 전체 |
| 3 | 시뮬레이터 + MQTT 수집기 | DB에 신호 적재 |
| 4 | 작업지시·실적, 작업자 화면 | 생산 흐름 동작 |
| 5 | 실시간 모니터링, 대시보드 | **P1 완료** |
| 6 | 비전 검사(FastAPI), 불량 분석 | 품질 모듈 |
| 7 | 알람, 예지보전, 정비·공구 | 설비 모듈 |
| 8 | OEE, 테스트 보강 | OEE 화면 |
| 9 | CI, 서버 배포, README·시연 GIF·장애 대응 문서 | **제출 가능한 포트폴리오** |
