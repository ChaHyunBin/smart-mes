-- smart-mes 스키마 (MySQL 8)
-- 설계: docs/design.md 5장 ERD
SET NAMES utf8mb4;
USE smartmes;

-- =========================================================
-- 기준정보
-- =========================================================
CREATE TABLE app_user (
    user_id        BIGINT       NOT NULL AUTO_INCREMENT,
    login_id       VARCHAR(50)  NOT NULL,
    password_hash  VARCHAR(100) NOT NULL,
    name           VARCHAR(50)  NOT NULL,
    role           VARCHAR(20)  NOT NULL COMMENT 'ADMIN / MANAGER / OPERATOR',
    use_yn         CHAR(1)      NOT NULL DEFAULT 'Y',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_app_user_login (login_id)
) COMMENT '사용자';

CREATE TABLE item (
    item_id        BIGINT       NOT NULL AUTO_INCREMENT,
    item_code      VARCHAR(30)  NOT NULL,
    item_name      VARCHAR(100) NOT NULL,
    spec           VARCHAR(200) NULL,
    std_cycle_sec  INT          NOT NULL COMMENT '표준 사이클타임(초)',
    use_yn         CHAR(1)      NOT NULL DEFAULT 'Y',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    UNIQUE KEY uk_item_code (item_code)
) COMMENT '품목';

CREATE TABLE routing (
    routing_id     BIGINT       NOT NULL AUTO_INCREMENT,
    item_id        BIGINT       NOT NULL,
    seq            INT          NOT NULL COMMENT '공정 순서',
    process_name   VARCHAR(50)  NOT NULL,
    equipment_type VARCHAR(20)  NOT NULL COMMENT 'MCT / CNC / INSPECT',
    PRIMARY KEY (routing_id),
    UNIQUE KEY uk_routing_item_seq (item_id, seq),
    CONSTRAINT fk_routing_item FOREIGN KEY (item_id) REFERENCES item (item_id)
) COMMENT '공정(라우팅)';

CREATE TABLE equipment (
    equipment_id   BIGINT       NOT NULL AUTO_INCREMENT,
    equipment_code VARCHAR(30)  NOT NULL,
    name           VARCHAR(100) NOT NULL,
    type           VARCHAR(20)  NOT NULL COMMENT 'MCT / CNC',
    status         VARCHAR(20)  NOT NULL DEFAULT 'OFFLINE' COMMENT 'RUN / IDLE / STOP / ALARM / OFFLINE',
    mqtt_topic     VARCHAR(100) NOT NULL,
    use_yn         CHAR(1)      NOT NULL DEFAULT 'Y',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (equipment_id),
    UNIQUE KEY uk_equipment_code (equipment_code)
) COMMENT '설비';

CREATE TABLE defect_code (
    defect_code    VARCHAR(20)  NOT NULL,
    defect_name    VARCHAR(50)  NOT NULL,
    category       VARCHAR(20)  NOT NULL COMMENT 'DIMENSION / SURFACE / ETC',
    use_yn         CHAR(1)      NOT NULL DEFAULT 'Y',
    PRIMARY KEY (defect_code)
) COMMENT '불량코드';

CREATE TABLE tool (
    tool_id          BIGINT      NOT NULL AUTO_INCREMENT,
    equipment_id     BIGINT      NOT NULL,
    tool_no          INT         NOT NULL COMMENT '공구 번호(T번호)',
    tool_name        VARCHAR(50) NOT NULL,
    life_limit_count INT         NOT NULL COMMENT '수명 기준 사용 횟수',
    used_count       INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (tool_id),
    UNIQUE KEY uk_tool_equipment_no (equipment_id, tool_no),
    CONSTRAINT fk_tool_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
) COMMENT '공구';

-- =========================================================
-- 생산
-- =========================================================
CREATE TABLE work_order (
    wo_id          BIGINT      NOT NULL AUTO_INCREMENT,
    wo_no          VARCHAR(30) NOT NULL,
    item_id        BIGINT      NOT NULL,
    equipment_id   BIGINT      NULL,
    plan_qty       INT         NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'WAIT' COMMENT 'WAIT / RUN / DONE / CANCEL',
    plan_date      DATE        NOT NULL,
    started_at     DATETIME    NULL,
    finished_at    DATETIME    NULL,
    created_by     BIGINT      NULL,
    created_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (wo_id),
    UNIQUE KEY uk_work_order_no (wo_no),
    KEY idx_work_order_date_status (plan_date, status),
    KEY idx_work_order_equipment_status (equipment_id, status),
    CONSTRAINT fk_wo_item FOREIGN KEY (item_id) REFERENCES item (item_id),
    CONSTRAINT fk_wo_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
) COMMENT '작업지시';

CREATE TABLE production_result (
    result_id      BIGINT      NOT NULL AUTO_INCREMENT,
    wo_id          BIGINT      NOT NULL,
    equipment_id   BIGINT      NOT NULL,
    good_qty       INT         NOT NULL DEFAULT 0,
    defect_qty     INT         NOT NULL DEFAULT 0,
    source         VARCHAR(10) NOT NULL COMMENT 'AUTO / MANUAL',
    created_by     BIGINT      NULL,
    created_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (result_id),
    KEY idx_result_wo (wo_id),
    KEY idx_result_equipment_created (equipment_id, created_at),
    CONSTRAINT fk_result_wo FOREIGN KEY (wo_id) REFERENCES work_order (wo_id),
    CONSTRAINT fk_result_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
) COMMENT '생산실적';

-- =========================================================
-- 품질
-- =========================================================
CREATE TABLE inspection (
    inspection_id  BIGINT       NOT NULL AUTO_INCREMENT,
    wo_id          BIGINT       NOT NULL,
    equipment_id   BIGINT       NOT NULL,
    image_path     VARCHAR(300) NOT NULL,
    verdict        VARCHAR(5)   NOT NULL COMMENT 'OK / NG',
    defect_code    VARCHAR(20)  NULL,
    confidence     DECIMAL(5,4) NULL,
    model_version  VARCHAR(50)  NULL,
    inspected_by   BIGINT       NULL,
    inspected_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (inspection_id),
    KEY idx_inspection_wo (wo_id),
    KEY idx_inspection_verdict_at (verdict, inspected_at),
    CONSTRAINT fk_inspection_wo FOREIGN KEY (wo_id) REFERENCES work_order (wo_id),
    CONSTRAINT fk_inspection_defect FOREIGN KEY (defect_code) REFERENCES defect_code (defect_code)
) COMMENT '비전 검사 이력';

CREATE TABLE defect_record (
    defect_id      BIGINT       NOT NULL AUTO_INCREMENT,
    result_id      BIGINT       NULL,
    inspection_id  BIGINT       NULL,
    defect_code    VARCHAR(20)  NOT NULL,
    qty            INT          NOT NULL DEFAULT 1,
    source         VARCHAR(10)  NOT NULL COMMENT 'VISION / MANUAL',
    note           VARCHAR(300) NULL,
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (defect_id),
    KEY idx_defect_code_created (defect_code, created_at),
    CONSTRAINT fk_defect_result FOREIGN KEY (result_id) REFERENCES production_result (result_id),
    CONSTRAINT fk_defect_inspection FOREIGN KEY (inspection_id) REFERENCES inspection (inspection_id),
    CONSTRAINT fk_defect_code FOREIGN KEY (defect_code) REFERENCES defect_code (defect_code)
) COMMENT '불량 기록';

-- =========================================================
-- 설비
-- =========================================================
-- 1초 주기로 쌓이는 시계열 데이터. 조회는 (설비, 시간 범위)로만 하므로 복합 인덱스 하나로 충분하다.
-- 데이터가 커지면 일자 단위 파티션을 적용한다 (docs/design.md 참고).
CREATE TABLE equipment_signal (
    signal_id      BIGINT       NOT NULL AUTO_INCREMENT,
    equipment_id   BIGINT       NOT NULL,
    ts             DATETIME(3)  NOT NULL,
    run_state      VARCHAR(10)  NOT NULL,
    spindle_load   DECIMAL(6,2) NULL,
    spindle_rpm    INT          NULL,
    vibration      DECIMAL(6,3) NULL,
    temperature    DECIMAL(5,2) NULL,
    part_count     INT          NULL,
    tool_no        INT          NULL,
    PRIMARY KEY (signal_id),
    KEY idx_signal_equipment_ts (equipment_id, ts)
) COMMENT '설비 원천 신호';

CREATE TABLE equipment_state_log (
    log_id         BIGINT      NOT NULL AUTO_INCREMENT,
    equipment_id   BIGINT      NOT NULL,
    state          VARCHAR(10) NOT NULL,
    start_ts       DATETIME    NOT NULL,
    end_ts         DATETIME    NULL COMMENT 'NULL이면 현재 진행 중인 구간',
    duration_sec   INT         NULL,
    PRIMARY KEY (log_id),
    KEY idx_state_equipment_start (equipment_id, start_ts),
    CONSTRAINT fk_state_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
) COMMENT '설비 상태 구간';

CREATE TABLE alarm (
    alarm_id       BIGINT       NOT NULL AUTO_INCREMENT,
    equipment_id   BIGINT       NOT NULL,
    alarm_type     VARCHAR(20)  NOT NULL COMMENT 'EQUIPMENT / THRESHOLD / COMM / ANOMALY',
    alarm_code     VARCHAR(30)  NOT NULL,
    level          VARCHAR(10)  NOT NULL COMMENT 'INFO / WARN / CRITICAL',
    message        VARCHAR(300) NULL,
    occurred_at    DATETIME     NOT NULL,
    ack_by         BIGINT       NULL,
    ack_at         DATETIME     NULL,
    action_note    VARCHAR(300) NULL,
    PRIMARY KEY (alarm_id),
    KEY idx_alarm_ack_occurred (ack_at, occurred_at),
    KEY idx_alarm_equipment_occurred (equipment_id, occurred_at),
    CONSTRAINT fk_alarm_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
) COMMENT '알람';

CREATE TABLE anomaly_score (
    score_id       BIGINT       NOT NULL AUTO_INCREMENT,
    equipment_id   BIGINT       NOT NULL,
    calc_ts        DATETIME     NOT NULL,
    score          DECIMAL(6,4) NOT NULL,
    threshold      DECIMAL(6,4) NOT NULL,
    features_json  JSON         NULL,
    PRIMARY KEY (score_id),
    KEY idx_anomaly_equipment_ts (equipment_id, calc_ts),
    CONSTRAINT fk_anomaly_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
) COMMENT '예지보전 이상 점수';

CREATE TABLE maintenance_order (
    mo_id          BIGINT       NOT NULL AUTO_INCREMENT,
    equipment_id   BIGINT       NOT NULL,
    alarm_id       BIGINT       NULL,
    reason         VARCHAR(300) NOT NULL,
    status         VARCHAR(20)  NOT NULL DEFAULT 'REQUESTED' COMMENT 'REQUESTED / IN_PROGRESS / DONE',
    requested_by   BIGINT       NULL,
    requested_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    done_by        BIGINT       NULL,
    done_at        DATETIME     NULL,
    note           VARCHAR(500) NULL,
    PRIMARY KEY (mo_id),
    KEY idx_mo_status (status, requested_at),
    CONSTRAINT fk_mo_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_mo_alarm FOREIGN KEY (alarm_id) REFERENCES alarm (alarm_id)
) COMMENT '정비 요청';

-- =========================================================
-- 집계·운영
-- =========================================================
CREATE TABLE oee_daily (
    equipment_id   BIGINT       NOT NULL,
    work_date      DATE         NOT NULL,
    availability   DECIMAL(5,4) NOT NULL,
    performance    DECIMAL(5,4) NOT NULL,
    quality        DECIMAL(5,4) NOT NULL,
    oee            DECIMAL(5,4) NOT NULL,
    calculated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (equipment_id, work_date),
    CONSTRAINT fk_oee_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
) COMMENT '일별 OEE';

CREATE TABLE audit_log (
    log_id         BIGINT       NOT NULL AUTO_INCREMENT,
    user_id        BIGINT       NULL,
    action         VARCHAR(50)  NOT NULL,
    target         VARCHAR(200) NULL,
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    KEY idx_audit_created (created_at)
) COMMENT '감사 로그';
