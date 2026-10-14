# CLAUDE.md — smart-mes

## 프로젝트 한 줄 요약
생산·품질·설비를 하나로 묶은 웹 기반 통합 MES.
작업지시·실적(생산), 비전 검사·불량 분석(품질), 설비 모니터링·예지보전(설비)을 구현한다.
스마트팩토리(MES·제조 IT 개발) 취업용 개인 포트폴리오이며, 면접관이 README만 보고 5분 안에 실행할 수 있어야 한다.

## 이 프로젝트가 증명해야 하는 것
- 백엔드·프론트엔드를 혼자 끝까지 설계·구현·배포할 수 있다 (핵심)
- 설비 데이터 수집(MQTT → 2단계 OPC UA)과 실시간 화면 연동을 할 수 있다
- 비전 AI(불량 판정)와 예지보전(이상 감지)을 실제 업무 흐름(실적·알람·정비)에 붙일 수 있다
- 배경: 개발자는 MCT/CNC 가공 현장 약 4년 경력 + 팀 프로젝트에서 YOLOv8·PaddleOCR 담당.
  AI 모델 자체보다 "AI 결과를 업무 시스템에 연결하는 웹 개발"이 이 프로젝트의 중심이다.
- 상세 설계는 `docs/design.md`

## 기술 스택
| 구분 | 선택 |
| --- | --- |
| 프론트엔드 | Vue 3 (Composition API, `<script setup>`), Vite, Vue Router, Pinia, Axios, Chart.js, STOMP.js |
| 백엔드 | Java 17, Spring Boot 4, Spring Security + JWT, MyBatis, Spring WebSocket(STOMP), springdoc-openapi(Swagger), Spring Batch 또는 @Scheduled |
| DB | MySQL 8 (MariaDB 호환 SQL만 사용) |
| 설비 연동 | 1단계 MQTT (Mosquitto + Spring Integration MQTT), 2단계 OPC UA (Eclipse Milo) |
| 분석 서비스 | Python 3.11, FastAPI — 비전 판정 API, 이상 점수 API |
| 시뮬레이터 | Python (paho-mqtt, 2단계 asyncua) |
| 테스트 | JUnit 5, MockMvc, (프론트) Vitest |
| 인프라 | Docker Compose, GitHub Actions(CI), 클라우드 또는 Linux 서버 배포 |

## 개발 환경
- 개발 PC: Windows 10/11. winget으로 Git, JDK 17(Temurin), Node.js LTS, Python 3.11, Docker Desktop(WSL 2), VS Code, IntelliJ Community 설치
- MySQL·Mosquitto는 Docker로만 띄운다. 로컬 설치를 전제로 한 안내를 하지 말 것
- 명령어 예시는 Windows PowerShell 기준. 백엔드는 `.\gradlew.bat` 사용
- 비밀값은 `.env`로 분리하고 `.env.example`만 커밋
- 개발자는 Git을 배우는 중이다. Git 명령이 필요하면 무엇을 하는 명령인지 한 줄로 설명할 것

## 저장소 구조
```
smart-mes/
├── backend/          # Spring Boot (auth, master, production, quality, equipment, maintenance, collector, common)
├── frontend/         # Vue 3 + Vite
├── analytics/        # Python FastAPI (vision, anomaly)
├── simulator/        # Python 설비 시뮬레이터 (MQTT, 2단계 OPC UA)
├── db/               # schema.sql, seed.sql
├── docs/             # design.md, ERD, API, 장애 대응 시나리오, 시연 GIF
├── docker-compose.yml
└── README.md
```

## 실행 순서
1. `docker compose up -d` → MySQL(3306), Mosquitto(1883)
2. `backend/`: `.\gradlew.bat bootRun` (8080, Swagger: /swagger-ui.html)
3. `frontend/`: `npm install` → `npm run dev` (5173)
4. `analytics/`: `pip install -r requirements.txt` → `uvicorn main:app --port 8000`
5. `simulator/`: `pip install -r requirements.txt` → `python main.py`

## 코딩 규칙
- 백엔드: 도메인별 패키지(`production`, `quality` …) 안에 `controller → service → mapper`, DTO는 요청/응답 분리
- REST 경로 `/api/v1/...`, 응답 `{ success, data, error }`, 예외는 `@RestControllerAdvice` + 에러 코드 enum
- 목록 API는 페이징(page, size)·검색 조건을 기본으로 지원
- 권한: ADMIN(관리자), MANAGER(생산·품질 담당), OPERATOR(작업자). 메서드 단위 `@PreAuthorize`
- SQL은 MyBatis XML 매퍼, 집계 쿼리는 인덱스 근거를 주석으로 남김
- 실시간 채널: `/topic/equipment/status`, `/topic/equipment/{id}/signal`, `/topic/alarm`
- 설비 연동은 `SignalSource` 인터페이스로 추상화(`MqttSignalSource`, 이후 `OpcUaSignalSource`)
- 분석 서비스 호출은 `AnalyticsClient` 하나로 모으고, 타임아웃·실패 시 재시도/보류 처리
- 프론트: 공통 컴포넌트(`DataGrid`, `SearchForm`, `Modal`, `StatusBadge`)를 먼저 만들고 화면에서 재사용, API 호출은 `src/api/` 모듈로 분리, 라우터 가드로 권한 처리
- 커밋 메시지 접두어 `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:` (한국어 본문 가능)
- 기능 하나 끝날 때마다 테스트 최소 1개

## MQTT 토픽 규칙
- `factory/line1/{equipmentCode}/signal` — 1초 주기, runState·spindleLoad·spindleRpm·vibration·temperature·partCount·toolNo
- `factory/line1/{equipmentCode}/alarm` — 발생 시
- `factory/line1/{equipmentCode}/status` — retain, Last Will로 OFFLINE

## 진행 단계 (현재 위치를 여기서 갱신)
- [ ] 1주차 — 개발 환경 설치, 저장소·Docker Compose, DB 스키마·시드, Spring Security+JWT 로그인, 프론트 레이아웃·로그인 화면  ← 현재
- [ ] 2주차 — 기준정보 CRUD(페이징·검색·엑셀), 공통 컴포넌트, 공통 응답·예외, Swagger
- [ ] 3주차 — 시뮬레이터 + MQTT 수집기, 신호·상태 구간 저장
- [ ] 4주차 — 작업지시·실적(자동/수동), 작업자 태블릿 화면
- [ ] 5주차 — WebSocket 실시간 모니터링, 생산 대시보드 → P1 완료
- [ ] 6주차 — 품질: 비전 검사(FastAPI 연동), 불량 등록·파레토
- [ ] 7주차 — 설비: 알람, 예지보전 이상 점수, 정비 이력, 공구 수명
- [ ] 8주차 — OEE 배치·분석 화면, 테스트 보강
- [ ] 9주차 — GitHub Actions CI, 서버 배포, README·시연 GIF·장애 대응 문서
- [ ] 이후 — OPC UA, ERP CSV 연동

## Claude에게 부탁
- 큰 작업은 먼저 계획을 보여주고 진행
- 코드를 바꾼 뒤에는 실행·확인 방법을 한두 줄로 알려줄 것
- 개발자가 직접 이해하고 설명할 수 있어야 하므로, 새 개념이 나오면 짧게 설명할 것
- 단계가 끝나면 위 체크리스트를 갱신할 것
