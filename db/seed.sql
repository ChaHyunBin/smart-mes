-- smart-mes 개발용 초기 데이터
-- 로그인 계정: admin / admin1234, manager / manager1234, operator / operator1234
SET NAMES utf8mb4;
USE smartmes;

INSERT INTO app_user (login_id, password_hash, name, role) VALUES
('admin',    '$2a$10$qRG/tl4O173pC3wIJu.ugeKx9xOIbx/ZycebxY5xTU72CFklmKrRS', '관리자',   'ADMIN'),
('manager',  '$2a$10$/Fufxn88kg/MorSoVQN.sOYQwr6gXPpFaaw8TrCLTOMu58q4Hse8i', '생산담당', 'MANAGER'),
('operator', '$2a$10$OwvzwfZekjGfTI6r/aeeu.a4BWpHftu/jd5RU5e4sHuHP7gdibpS2', '작업자1',  'OPERATOR');

INSERT INTO item (item_code, item_name, spec, std_cycle_sec) VALUES
('P-1001', '알루미늄 브래킷',   'AL6061 120x80x15',  95),
('P-1002', '모터 하우징 커버',   'AL6061 Ø110 t20',   180),
('P-2001', '샤프트 홀더',       'S45C 60x60x40',     240);

INSERT INTO routing (item_id, seq, process_name, equipment_type) VALUES
(1, 10, '1차 가공(MCT)', 'MCT'),
(1, 20, '외관 검사',     'INSPECT'),
(2, 10, '1차 가공(MCT)', 'MCT'),
(2, 20, '2차 가공(CNC)', 'CNC'),
(2, 30, '외관 검사',     'INSPECT'),
(3, 10, '선삭 가공(CNC)', 'CNC'),
(3, 20, '외관 검사',     'INSPECT');

INSERT INTO equipment (equipment_code, name, type, mqtt_topic) VALUES
('MCT-01', '머시닝센터 1호기', 'MCT', 'factory/line1/MCT-01'),
('MCT-02', '머시닝센터 2호기', 'MCT', 'factory/line1/MCT-02'),
('CNC-01', 'CNC 선반 1호기',   'CNC', 'factory/line1/CNC-01');

INSERT INTO defect_code (defect_code, defect_name, category) VALUES
('D-DIM',    '치수 불량',     'DIMENSION'),
('D-BURR',   '버(Burr)',      'SURFACE'),
('D-SCRATCH','스크래치',      'SURFACE'),
('D-CHIP',   '모서리 깨짐',   'SURFACE'),
('D-ETC',    '기타',          'ETC');

INSERT INTO tool (equipment_id, tool_no, tool_name, life_limit_count, used_count) VALUES
(1, 1, 'Ø10 엔드밀',    800, 120),
(1, 2, 'Ø6 드릴',      1200, 640),
(1, 3, 'Ø50 페이스밀', 1500, 1380),
(2, 1, 'Ø10 엔드밀',    800, 40),
(2, 2, 'M6 탭',         600, 510),
(3, 1, '외경 황삭 바이트', 500, 210),
(3, 2, '외경 정삭 바이트', 700, 650);

INSERT INTO work_order (wo_no, item_id, equipment_id, plan_qty, status, plan_date, created_by) VALUES
(CONCAT('WO-', DATE_FORMAT(CURDATE(), '%Y%m%d'), '-001'), 1, 1, 200, 'WAIT', CURDATE(), 2),
(CONCAT('WO-', DATE_FORMAT(CURDATE(), '%Y%m%d'), '-002'), 2, 2, 120, 'WAIT', CURDATE(), 2),
(CONCAT('WO-', DATE_FORMAT(CURDATE(), '%Y%m%d'), '-003'), 3, 3,  80, 'WAIT', CURDATE(), 2);
