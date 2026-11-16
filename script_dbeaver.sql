-- ============================================================
-- script_dbeaver.sql — Toàn bộ CSDL "Hệ thống đặt vé xem phim trực tuyến"
-- (Oracle Database 23ai, Đề tài 6 – Nhóm 3) — bản chạy trong DBeaver
--
-- CÁCH CHẠY TRONG DBEAVER:
-- 1) Tạo kết nối (connection) tới Oracle Database 23ai trong DBeaver
--    (Database > New Database Connection > Oracle), điền đúng
--    host/port/service name và user/password.
-- 2) Nếu CHƯA có user/schema riêng cho đồ án: dùng kết nối bằng
--    tài khoản QUẢN TRỊ (SYS AS SYSDBA hoặc ADMIN) trước, bỏ dấu
--    comment khối BƯỚC 0 bên dưới, đổi mật khẩu, rồi chạy riêng
--    khối đó. Sau đó tạo THÊM một kết nối DBeaver mới, dùng chính
--    user cinema_app vừa tạo (DBeaver cần một connection riêng
--    cho user mới, không chỉ đổi schema trong connection cũ).
-- 3) Mở kết nối cinema_app, mở file này trong SQL Editor, rồi chạy
--    TOÀN BỘ bằng lệnh "Execute SQL Script" (KHÔNG phải "Execute
--    SQL Statement"): phím tắt Alt+X (Windows/Linux) hoặc chọn
--    SQL Editor > Execute SQL Script trên thanh menu. Chạy bằng
--    Ctrl+Enter (chỉ chạy 1 câu lệnh) sẽ bị dừng ngang vì script
--    có nhiều khối PL/SQL nối tiếp nhau.
-- 4) Muốn xem DBMS_OUTPUT.PUT_LINE (vd kết quả báo cáo doanh thu):
--    mở panel "DBMS Output" của DBeaver (thường ở khung kết quả
--    phía dưới SQL Editor, hoặc Window > Show View > DBMS Output)
--    và bấm nút bật (hình tam giác/Enable) TRƯỚC khi chạy script.
-- ============================================================

-- ---------- BƯỚC 0 (tuỳ chọn): TẠO USER — chạy bằng tài khoản QUẢN TRỊ ----------
-- Bỏ dấu comment và đổi mật khẩu trước khi chạy, nếu bạn chưa có user cinema_app.
-- -- ============================================================
-- -- 00_create_user.sql
-- -- Chạy bằng tài khoản QUẢN TRỊ:
-- --   - Oracle Database 23ai Free cài local / Docker: connect SYS AS SYSDBA
-- --     (hoặc SYSTEM) vào PDB (ví dụ FREEPDB1), KHÔNG chạy trong CDB gốc.
-- --   - Oracle Cloud Autonomous Database (Always Free): connect bằng user ADMIN.
-- -- Mục đích: tạo một schema/user RIÊNG cho đồ án, không dùng chung
-- -- với schema hệ thống, để lỡ làm sai chỉ cần DROP USER rồi làm lại.
-- -- ============================================================
-- 
-- -- Đổi mật khẩu bên dưới trước khi chạy (Oracle yêu cầu mật khẩu đủ mạnh)!
-- CREATE USER cinema_app IDENTIFIED BY "DoiMatKhauManh123#";
-- 
-- -- Cách 1 (khuyến nghị cho Oracle Database 23ai Free):
-- -- DB_DEVELOPER_ROLE là role dựng sẵn từ 23ai, đủ quyền để tạo bảng, view,
-- -- function/procedure, trigger, job, MLE module... cho một schema ứng dụng.
-- GRANT DB_DEVELOPER_ROLE TO cinema_app;
-- GRANT UNLIMITED TABLESPACE TO cinema_app;
-- 
-- -- Cách 2 (dự phòng, dùng khi bản Oracle đang có không hỗ trợ DB_DEVELOPER_ROLE):
-- -- bỏ dấu comment các dòng dưới rồi chạy thay cho Cách 1.
-- -- GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE,
-- --       CREATE TRIGGER, CREATE SEQUENCE, CREATE TYPE, CREATE JOB
-- --   TO cinema_app;
-- -- GRANT UNLIMITED TABLESPACE TO cinema_app;
-- 
-- COMMIT;
-- 
-- -- Sau khi chạy xong: ĐÓNG kết nối admin, MỞ kết nối MỚI bằng chính
-- -- user "cinema_app" (và mật khẩu vừa đặt ở trên), rồi mới chạy lần lượt
-- -- các file 01 → 09 trong thư mục này. Từ đây về sau, mọi lệnh đều chạy
-- -- bằng user cinema_app, không chạy bằng tài khoản quản trị nữa.

-- ---------- Từ đây trở xuống: chạy bằng user cinema_app ----------

-- ============================================================
-- 01_tables.sql  (chạy bằng user cinema_app)
-- Tạo đủ 12 bảng theo đúng ERD ở Chương 2 của báo cáo, theo đúng
-- thứ tự để bảng sau không bị lỗi "tham chiếu tới bảng chưa tồn tại".
-- ============================================================

-- 1) CUSTOMER — độc lập, không phụ thuộc bảng nào khác
CREATE TABLE customer (
  customer_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name     VARCHAR2(100) NOT NULL,
  email         VARCHAR2(100) NOT NULL UNIQUE,
  phone         VARCHAR2(20),
  password_hash VARCHAR2(200) NOT NULL,
  created_at    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);

-- 2) MOVIE — độc lập
CREATE TABLE movie (
  movie_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title         VARCHAR2(200) NOT NULL,
  genre         VARCHAR2(50),
  duration_min  NUMBER NOT NULL CHECK (duration_min > 0),
  rating        VARCHAR2(10),               -- vd: 'P','C13','C16','C18'
  release_date  DATE,
  metadata      VARCHAR2(4000)              -- JSON lưu dạng chuỗi ký tự
                CHECK (metadata IS JSON)     -- Oracle tự kiểm tra đúng định dạng JSON
);

-- 3) THEATER — độc lập
CREATE TABLE theater (
  theater_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR2(100) NOT NULL,
  address    VARCHAR2(200)
);

-- 4) ROOM — phụ thuộc THEATER
CREATE TABLE room (
  room_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  theater_id NUMBER NOT NULL REFERENCES theater(theater_id),
  name       VARCHAR2(50) NOT NULL,
  room_type  VARCHAR2(10) DEFAULT '2D' NOT NULL
             CHECK (room_type IN ('2D','3D','IMAX'))
);

-- 5) SEAT — phụ thuộc ROOM
CREATE TABLE seat (
  seat_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room_id   NUMBER NOT NULL REFERENCES room(room_id),
  row_label VARCHAR2(5) NOT NULL,
  seat_no   NUMBER NOT NULL,
  seat_type VARCHAR2(10) DEFAULT 'STANDARD' NOT NULL
            CHECK (seat_type IN ('STANDARD','VIP','COUPLE')),
  CONSTRAINT uq_seat UNIQUE (room_id, row_label, seat_no)
);

-- 6) SHOWTIME — phụ thuộc MOVIE, ROOM
CREATE TABLE showtime (
  showtime_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  movie_id    NUMBER NOT NULL REFERENCES movie(movie_id),
  room_id     NUMBER NOT NULL REFERENCES room(room_id),
  start_time  TIMESTAMP NOT NULL,
  end_time    TIMESTAMP NOT NULL,
  base_price  NUMBER NOT NULL CHECK (base_price >= 0),
  status      VARCHAR2(10) DEFAULT 'OPEN' NOT NULL
              CHECK (status IN ('OPEN','CLOSED','CANCELLED')),
  CONSTRAINT ck_showtime_time CHECK (end_time > start_time)
);

-- 7) PROMOTION — độc lập
CREATE TABLE promotion (
  promo_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code           VARCHAR2(30) NOT NULL UNIQUE,
  discount_type  VARCHAR2(10) NOT NULL CHECK (discount_type IN ('PERCENT','AMOUNT')),
  discount_value NUMBER NOT NULL CHECK (discount_value > 0),
  max_discount   NUMBER,
  min_amount     NUMBER,
  valid_from     DATE NOT NULL,
  valid_to       DATE NOT NULL,
  max_uses       NUMBER,
  used_count     NUMBER DEFAULT 0 NOT NULL,
  is_active      NUMBER(1) DEFAULT 1 NOT NULL CHECK (is_active IN (0,1)),
  conditions     VARCHAR2(4000) CHECK (conditions IS JSON),
  CONSTRAINT ck_promo_date CHECK (valid_to >= valid_from)
);

-- 8) BOOKING — phụ thuộc CUSTOMER, SHOWTIME
CREATE TABLE booking (
  booking_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id     NUMBER NOT NULL REFERENCES customer(customer_id),
  showtime_id     NUMBER NOT NULL REFERENCES showtime(showtime_id),
  promo_code      VARCHAR2(30),
  subtotal        NUMBER,
  discount_amount NUMBER,
  final_amount    NUMBER,
  status          VARCHAR2(10) DEFAULT 'PENDING' NOT NULL
                  CHECK (status IN ('PENDING','PAID','CANCELLED','EXPIRED')),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  expires_at      TIMESTAMP,
  paid_at         TIMESTAMP
);

-- 9) SHOWTIME_SEAT — bảng trung tâm chống bán trùng ghế (mục 3.1 báo cáo)
--    Chú ý: booking_id KHÔNG đặt FOREIGN KEY tới BOOKING — để tránh vòng
--    phụ thuộc (BOOKING cũng tham chiếu SHOWTIME), quan hệ này được kiểm
--    soát hoàn toàn trong PL/SQL của pkg_booking.
CREATE TABLE showtime_seat (
  showtime_id     NUMBER NOT NULL REFERENCES showtime(showtime_id),
  seat_id         NUMBER NOT NULL REFERENCES seat(seat_id),
  status          VARCHAR2(10) DEFAULT 'AVAILABLE' NOT NULL
                  CHECK (status IN ('AVAILABLE','HELD','SOLD')),
  held_by         NUMBER REFERENCES customer(customer_id),
  hold_expires_at TIMESTAMP,
  booking_id      NUMBER,
  CONSTRAINT pk_showtime_seat PRIMARY KEY (showtime_id, seat_id),
  CONSTRAINT ck_hold CHECK (status <> 'HELD'
                            OR (held_by IS NOT NULL AND hold_expires_at IS NOT NULL))
);

-- 10) TICKET — phụ thuộc BOOKING và SHOWTIME_SEAT (khoá ngoại tổ hợp)
CREATE TABLE ticket (
  ticket_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_id  NUMBER NOT NULL REFERENCES booking(booking_id),
  showtime_id NUMBER NOT NULL,
  seat_id     NUMBER NOT NULL,
  price       NUMBER(10) NOT NULL CHECK (price >= 0),
  CONSTRAINT uq_ticket_seat UNIQUE (showtime_id, seat_id),
  CONSTRAINT fk_ticket_ss FOREIGN KEY (showtime_id, seat_id)
    REFERENCES showtime_seat(showtime_id, seat_id)
);

-- 11) PAYMENT — phụ thuộc BOOKING
CREATE TABLE payment (
  payment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_id NUMBER NOT NULL REFERENCES booking(booking_id),
  method     VARCHAR2(20) NOT NULL,
  amount     NUMBER NOT NULL,
  status     VARCHAR2(20) NOT NULL CHECK (status IN ('SUCCESS','FAILED','REFUNDED')),
  paid_at    TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- 12) AUDIT_LOG — độc lập, do trigger tự ghi (mục 3.11.c báo cáo)
CREATE TABLE audit_log (
  log_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name VARCHAR2(30), record_id NUMBER, action VARCHAR2(20),
  old_value  VARCHAR2(50), new_value VARCHAR2(50),
  changed_by VARCHAR2(128) DEFAULT SYS_CONTEXT('USERENV', 'SESSION_USER'),
  changed_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

COMMIT;

-- ============================================================
-- 02_functions_pricing.sql
-- Hai hàm tính giá độc lập (mục 3.2, 3.3 báo cáo). Phải tạo TRƯỚC
-- package pkg_booking vì sp_confirm_booking sẽ gọi hai hàm này.
-- ============================================================

-- 3.2. Hàm tính giá vé
CREATE OR REPLACE FUNCTION fn_calc_ticket_price(
  p_showtime_id NUMBER, p_seat_id NUMBER) RETURN NUMBER IS
  -- Khai báo kiểu dữ liệu cụ thể cho từng biến (không dùng %TYPE)
  v_base  NUMBER;
  v_start TIMESTAMP;
  v_type  VARCHAR2(10);
  v_price NUMBER;
BEGIN
  -- Bước 1: lấy giá cơ sở của suất chiếu và loại ghế
  SELECT st.base_price, st.start_time, s.seat_type
    INTO v_base, v_start, v_type
    FROM showtime st, seat s
   WHERE st.showtime_id = p_showtime_id AND s.seat_id = p_seat_id;

  -- Bước 2: nhân hệ số theo loại ghế (ghế thường x1, VIP x1.25, COUPLE x2)
  v_price := v_base * CASE v_type WHEN 'VIP' THEN 1.25
                                  WHEN 'COUPLE' THEN 2.0 ELSE 1 END;

  -- Bước 3: cộng thêm phụ thu nếu suất chiếu rơi vào thứ Bảy/Chủ Nhật
  IF TO_CHAR(v_start, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT','SUN') THEN
    v_price := v_price * 1.15;          -- phụ thu cuối tuần 15%
  END IF;

  -- Bước 4: giảm giá nếu là suất chiếu buổi sáng sớm (trước 12 giờ trưa)
  IF EXTRACT(HOUR FROM v_start) < 12 THEN
    v_price := v_price * 0.8;           -- suất sớm giảm 20%
  END IF;

  RETURN ROUND(v_price, -3);            -- làm tròn đến nghìn đồng
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001, 'Suất chiếu hoặc ghế không tồn tại');
END;
/

-- 3.3. Hàm tính khuyến mãi
CREATE OR REPLACE FUNCTION fn_calc_discount(
  p_code VARCHAR2, p_subtotal NUMBER, p_showtime_id NUMBER) RETURN NUMBER IS
  -- Khai báo riêng từng biến với kiểu dữ liệu cụ thể (không gộp chung vào %ROWTYPE)
  v_valid_from     DATE;
  v_valid_to       DATE;
  v_max_uses       NUMBER;
  v_used_count     NUMBER;
  v_min_amount     NUMBER;
  v_discount_type  VARCHAR2(10);
  v_discount_value NUMBER;
  v_max_discount   NUMBER;
  v_conditions     VARCHAR2(4000);  -- cột JSON được lưu dưới dạng chuỗi ký tự
  v_dow    VARCHAR2(3);     -- thứ trong tuần của suất chiếu, ví dụ 'TUE'
  v_days   VARCHAR2(200);   -- nội dung JSON "days" dạng chuỗi, ví dụ ["TUE","WED"]
  v_disc   NUMBER;
BEGIN
  -- Không nhập mã thì không giảm, khỏi cần kiểm tra gì thêm
  IF p_code IS NULL THEN RETURN 0; END IF;

  -- Bước 1: lấy từng cột cần dùng của mã khuyến mãi ra từng biến riêng
  -- (nếu không tìm thấy mã sẽ rơi vào NO_DATA_FOUND)
  SELECT valid_from, valid_to, max_uses, used_count, min_amount,
         discount_type, discount_value, max_discount, conditions
    INTO v_valid_from, v_valid_to, v_max_uses, v_used_count, v_min_amount,
         v_discount_type, v_discount_value, v_max_discount, v_conditions
    FROM promotion WHERE code = UPPER(p_code) AND is_active = 1;

  -- Bước 2: kiểm tra các điều kiện cơ bản của mã
  IF SYSDATE NOT BETWEEN v_valid_from AND v_valid_to THEN
    RAISE_APPLICATION_ERROR(-20030, 'Mã khuyến mãi đã hết hạn');
  ELSIF v_max_uses IS NOT NULL AND v_used_count >= v_max_uses THEN
    RAISE_APPLICATION_ERROR(-20031, 'Mã khuyến mãi đã hết lượt dùng');
  ELSIF p_subtotal < NVL(v_min_amount, 0) THEN
    RAISE_APPLICATION_ERROR(-20032, 'Chưa đạt giá trị đơn tối thiểu');
  END IF;

  -- Bước 3: kiểm tra điều kiện "chỉ áp dụng một số ngày trong tuần"
  -- (điều kiện này lưu trong cột JSON conditions, ví dụ {"days":["TUE","WED"]})
  IF v_conditions IS NOT NULL AND JSON_EXISTS(v_conditions, '$.days') THEN
    SELECT TO_CHAR(start_time, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH')
      INTO v_dow FROM showtime WHERE showtime_id = p_showtime_id;

    -- Chuyển cục JSON thành chuỗi ký tự rồi tìm xem có chứa đúng
    -- mã 3 ký tự của ngày chiếu hay không (ví dụ tìm "TUE" trong chuỗi)
    v_days := JSON_SERIALIZE(v_conditions RETURNING VARCHAR2(200));
    IF INSTR(v_days, '"' || v_dow || '"') = 0 THEN
      RAISE_APPLICATION_ERROR(-20033, 'Mã không áp dụng cho ngày chiếu này');
    END IF;
  END IF;

  -- Bước 4: tính số tiền giảm theo loại khuyến mãi, chặn trần max_discount
  v_disc := CASE v_discount_type WHEN 'PERCENT'
              THEN p_subtotal * v_discount_value / 100
              ELSE v_discount_value END;
  IF v_max_discount IS NOT NULL THEN v_disc := LEAST(v_disc, v_max_discount); END IF;
  RETURN LEAST(ROUND(v_disc, -3), p_subtotal);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20034, 'Mã khuyến mãi không tồn tại');
END;
/

-- ============================================================
-- 03_package_pkg_booking.sql
-- Package pkg_booking: toàn bộ nghiệp vụ đặt vé (mục 3.4–3.7, 3.11.b,
-- 3.11.d báo cáo). Chạy SPEC trước, BODY sau.
-- ============================================================

-- ---------- SPECIFICATION ----------
CREATE OR REPLACE PACKAGE pkg_booking IS
  PROCEDURE sp_hold_seats(
    p_customer_id IN NUMBER, p_showtime_id IN NUMBER,
    p_seat_ids IN SYS.ODCINUMBERLIST, p_booking_id OUT NUMBER
  );

  PROCEDURE sp_confirm_booking(
    p_booking_id IN NUMBER, p_promo_code IN VARCHAR2, p_method IN VARCHAR2
  );

  PROCEDURE sp_cancel_booking(
    p_booking_id IN NUMBER, p_customer_id IN NUMBER
  );

  PROCEDURE sp_release_expired_holds;
  PROCEDURE sp_daily_revenue_report(p_date IN DATE DEFAULT TRUNC(SYSDATE));

  FUNCTION fn_check_room_overlap(
    p_room_id NUMBER, p_start TIMESTAMP, p_end TIMESTAMP,
    p_exclude_id NUMBER DEFAULT NULL) RETURN NUMBER;

  PROCEDURE sp_add_showtime(
    p_movie_id NUMBER, p_room_id NUMBER, p_start TIMESTAMP, p_end TIMESTAMP,
    p_base_price NUMBER, p_showtime_id OUT NUMBER);
END pkg_booking;
/

-- ---------- BODY ----------
CREATE OR REPLACE PACKAGE BODY pkg_booking IS

  -- 3.4. Giữ chỗ tạm thời
  PROCEDURE sp_hold_seats(
    p_customer_id IN NUMBER, p_showtime_id IN NUMBER,
    p_seat_ids IN SYS.ODCINUMBERLIST, p_booking_id OUT NUMBER) IS
    c_hold_minutes CONSTANT NUMBER := 10;
    v_expire TIMESTAMP := SYSTIMESTAMP + NUMTODSINTERVAL(c_hold_minutes, 'MINUTE');
    v_start TIMESTAMP; v_status VARCHAR2(10);
  BEGIN
    -- Bước 1: chặn đặt suất đã đóng bán hoặc đã bắt đầu chiếu
    SELECT start_time, status INTO v_start, v_status
      FROM showtime WHERE showtime_id = p_showtime_id;
    IF v_status <> 'OPEN' OR v_start <= SYSTIMESTAMP THEN
      RAISE_APPLICATION_ERROR(-20012, 'Suất chiếu đã đóng bán');
    END IF;

    -- Bước 2: kiểm tra số lượng ghế hợp lệ (1 đến 8 ghế một đơn)
    IF p_seat_ids IS NULL OR p_seat_ids.COUNT NOT BETWEEN 1 AND 8 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Mỗi đơn đặt từ 1 đến 8 ghế');
    END IF;

    -- Bước 3: đánh dấu điểm mốc để có thể hoàn tác (ROLLBACK TO) nếu một
    -- ghế nào đó bị trùng ở giữa chừng, thay vì phải huỷ luôn toàn bộ giao dịch
    SAVEPOINT sp_start;

    -- Bước 4: tạo một đơn đặt vé mới ở trạng thái PENDING (đang chờ thanh toán)
    INSERT INTO booking(customer_id, showtime_id, status, expires_at)
    VALUES (p_customer_id, p_showtime_id, 'PENDING', v_expire)
    RETURNING booking_id INTO p_booking_id;

    -- Bước 5: lần lượt giữ từng ghế trong danh sách p_seat_ids.
    -- TABLE(p_seat_ids) biến tập hợp số thành một "bảng ảo" để duyệt bằng FOR,
    -- giống như duyệt qua từng phần tử của một mảng.
    FOR r IN (SELECT column_value AS seat_id FROM TABLE(p_seat_ids) ORDER BY 1) LOOP
      -- Chỉ UPDATE khi ghế đang trống, hoặc đang bị giữ nhưng đã quá hạn
      UPDATE showtime_seat
         SET status = 'HELD', held_by = p_customer_id,
             hold_expires_at = v_expire, booking_id = p_booking_id
       WHERE showtime_id = p_showtime_id AND seat_id = r.seat_id
         AND (status = 'AVAILABLE'
              OR (status = 'HELD' AND hold_expires_at < SYSTIMESTAMP));
      -- Không có dòng nào được cập nhật nghĩa là ghế đã bị người khác giữ/bán
      IF SQL%ROWCOUNT = 0 THEN
        ROLLBACK TO sp_start;   -- trả toàn bộ đơn về trạng thái ban đầu
        RAISE_APPLICATION_ERROR(-20011,
          'Ghế ' || r.seat_id || ' đã có người giữ hoặc đã bán');
      END IF;
    END LOOP;
    COMMIT;   -- mọi ghế đều giữ thành công mới COMMIT
  END sp_hold_seats;

  -- 3.5. Xác nhận thanh toán
  PROCEDURE sp_confirm_booking(
    p_booking_id IN NUMBER, p_promo_code IN VARCHAR2, p_method IN VARCHAR2, p_combos     IN VARCHAR2 DEFAULT NULL) IS
    -- Khai báo riêng từng cột cần dùng của đơn đặt vé (không dùng %ROWTYPE)
    v_status      VARCHAR2(10);
    v_expires_at  TIMESTAMP;
    v_showtime_id NUMBER;
    v_total NUMBER; v_cnt NUMBER;
    v_subtotal NUMBER; v_discount NUMBER;
  BEGIN
    -- Bước 1: khoá dòng đơn đặt lại (FOR UPDATE) để không ai bấm thanh toán
    -- trùng lặp cho cùng một đơn, rồi kiểm tra đơn còn hiệu lực không
    SELECT status, expires_at, showtime_id
      INTO v_status, v_expires_at, v_showtime_id
      FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
    IF v_status <> 'PENDING' OR v_expires_at < SYSTIMESTAMP THEN
      RAISE_APPLICATION_ERROR(-20020, 'Đơn không còn hiệu lực');
    END IF;

    -- Bước 2: tạo vé (ticket) cho từng ghế đang HELD và còn hạn giữ chỗ,
    -- giá mỗi vé được tính ngay bằng hàm fn_calc_ticket_price
    SELECT COUNT(*) INTO v_total FROM showtime_seat WHERE booking_id = p_booking_id;

    INSERT INTO ticket(booking_id, showtime_id, seat_id, price)
    SELECT booking_id, showtime_id, seat_id, fn_calc_ticket_price(showtime_id, seat_id)
      FROM showtime_seat
     WHERE booking_id = p_booking_id AND status = 'HELD'
       AND hold_expires_at >= SYSTIMESTAMP;
    v_cnt := SQL%ROWCOUNT;
    -- Nếu số vé tạo được ít hơn số ghế đã giữ, nghĩa là có ghế bị hết hạn giữa chừng
    IF v_cnt = 0 OR v_cnt <> v_total THEN
      RAISE_APPLICATION_ERROR(-20021, 'Có ghế đã hết hạn giữ chỗ');
    END IF;

    -- Bước 3: tính tổng tiền và số tiền được giảm (nếu có mã khuyến mãi)
    SELECT SUM(price) INTO v_subtotal FROM ticket WHERE booking_id = p_booking_id;
    v_discount := fn_calc_discount(p_promo_code, v_subtotal, v_showtime_id);

    -- Bước 4: nếu có giảm giá thì tăng used_count của mã lên 1,
    -- nhưng chỉ tăng khi used_count vẫn còn dưới max_uses (tránh vượt quá)
    IF v_discount > 0 THEN
      UPDATE promotion SET used_count = used_count + 1
       WHERE code = UPPER(p_promo_code)
         AND (max_uses IS NULL OR used_count < max_uses);
      IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20031, 'Mã khuyến mãi đã hết lượt dùng');
      END IF;
    END IF;

    -- Bước 5: chuyển ghế sang SOLD, chuyển đơn sang PAID, ghi nhận thanh toán.
    -- Toàn bộ 5 bước nằm trong một giao dịch duy nhất nhờ chỉ COMMIT ở cuối cùng.
    UPDATE showtime_seat SET status = 'SOLD', held_by = NULL, hold_expires_at = NULL
     WHERE booking_id = p_booking_id;
    UPDATE booking SET subtotal = v_subtotal, discount_amount = v_discount,
           final_amount = v_subtotal - v_discount, promo_code = UPPER(p_promo_code),
           status = 'PAID', paid_at = SYSTIMESTAMP
     WHERE booking_id = p_booking_id;
    INSERT INTO payment(booking_id, method, amount, status, paid_at)
    VALUES (p_booking_id, p_method, v_subtotal - v_discount, 'SUCCESS', SYSTIMESTAMP);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;   -- có lỗi ở bất kỳ bước nào thì huỷ hết, không để dữ liệu nửa vời
      RAISE;
  END sp_confirm_booking;

  -- 3.6. Giải phóng ghế giữ quá hạn (được DBMS_SCHEDULER gọi mỗi phút)
  PROCEDURE sp_release_expired_holds IS
  BEGIN
    UPDATE showtime_seat
       SET status = 'AVAILABLE', held_by = NULL, hold_expires_at = NULL, booking_id = NULL
     WHERE status = 'HELD' AND hold_expires_at < SYSTIMESTAMP;
    UPDATE booking SET status = 'EXPIRED'
     WHERE status = 'PENDING' AND expires_at < SYSTIMESTAMP;
    COMMIT;
  END sp_release_expired_holds;

  -- 3.7. Báo cáo doanh thu cuối ngày — Con trỏ tường minh (Explicit Cursor)
  PROCEDURE sp_daily_revenue_report(p_date IN DATE DEFAULT TRUNC(SYSDATE)) IS
    -- Khai báo con trỏ tường minh
    CURSOR c_revenue IS
      SELECT m.title, COUNT(*) AS tickets_sold, SUM(t.price) AS revenue
        FROM ticket t
        JOIN booking  b  ON b.booking_id = t.booking_id AND b.status = 'PAID'
        JOIN showtime st ON st.showtime_id = t.showtime_id
        JOIN movie    m  ON m.movie_id = st.movie_id
       WHERE TRUNC(b.paid_at) = p_date
       GROUP BY m.title
       ORDER BY SUM(t.price) DESC;

    -- Khai báo riêng từng biến tương ứng với từng cột cursor trả về (không dùng %ROWTYPE)
    v_title        VARCHAR2(200);
    v_tickets_sold NUMBER;
    v_revenue      NUMBER;
    v_total_rev NUMBER := 0;
    v_total_tkt NUMBER := 0;
  BEGIN
    DBMS_OUTPUT.PUT_LINE('BAO CAO DOANH THU NGAY ' || TO_CHAR(p_date, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE(RPAD('Phim', 35) || LPAD('So ve', 10) || LPAD('Doanh thu', 15));

    OPEN c_revenue;                      -- mở con trỏ
    LOOP
      FETCH c_revenue INTO v_title, v_tickets_sold, v_revenue;  -- lấy từng dòng
      EXIT WHEN c_revenue%NOTFOUND;      -- hết dòng thì dừng

      DBMS_OUTPUT.PUT_LINE(RPAD(v_title, 35)
                            || LPAD(v_tickets_sold, 10)
                            || LPAD(TO_CHAR(v_revenue, '999,999,999'), 15));
      v_total_rev := v_total_rev + v_revenue;
      v_total_tkt := v_total_tkt + v_tickets_sold;
    END LOOP;
    CLOSE c_revenue;                     -- đóng con trỏ

    DBMS_OUTPUT.PUT_LINE(RPAD('TONG CONG', 35) || LPAD(v_total_tkt, 10)
                          || LPAD(TO_CHAR(v_total_rev, '999,999,999'), 15));
  EXCEPTION
    WHEN OTHERS THEN
      IF c_revenue%ISOPEN THEN CLOSE c_revenue; END IF;  -- tránh rò rỉ con trỏ khi lỗi
      RAISE;
  END sp_daily_revenue_report;

  -- 3.11.b. Huỷ đơn và hoàn vé
  PROCEDURE sp_cancel_booking(p_booking_id IN NUMBER, p_customer_id IN NUMBER) IS
    -- Khai báo riêng từng cột cần dùng của đơn đặt vé (không dùng %ROWTYPE/%TYPE)
    v_bk_customer_id NUMBER;
    v_status         VARCHAR2(10);
    v_showtime_id    NUMBER;
    v_promo_code     VARCHAR2(30);
    v_final_amount   NUMBER;
    v_start          TIMESTAMP;
  BEGIN
    -- Bước 1: khoá dòng đơn, kiểm tra đúng chủ đơn và đúng trạng thái được phép huỷ
    SELECT customer_id, status, showtime_id, promo_code, final_amount
      INTO v_bk_customer_id, v_status, v_showtime_id, v_promo_code, v_final_amount
      FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
    IF v_bk_customer_id <> p_customer_id THEN
      RAISE_APPLICATION_ERROR(-20040, 'Khong co quyen huy don nay');
    ELSIF v_status NOT IN ('PENDING', 'PAID') THEN
      RAISE_APPLICATION_ERROR(-20041, 'Don khong the huy o trang thai hien tai');
    END IF;

    -- Bước 2: nếu đơn đã thanh toán (PAID) thì phải hoàn tiền và xoá vé,
    -- nhưng chỉ được huỷ khi còn ít nhất 2 giờ trước giờ chiếu
    IF v_status = 'PAID' THEN
      SELECT start_time INTO v_start FROM showtime WHERE showtime_id = v_showtime_id;
      IF v_start < SYSTIMESTAMP + INTERVAL '2' HOUR THEN
        RAISE_APPLICATION_ERROR(-20042, 'Chi huy ve da thanh toan truoc gio chieu it nhat 2 gio');
      END IF;
      DELETE FROM ticket WHERE booking_id = p_booking_id;   -- xoá vé trước
      INSERT INTO payment(booking_id, method, amount, status, paid_at)
      VALUES (p_booking_id, 'REFUND', -v_final_amount, 'REFUNDED', SYSTIMESTAMP);
      IF v_promo_code IS NOT NULL THEN
        UPDATE promotion SET used_count = GREATEST(used_count - 1, 0)
         WHERE code = v_promo_code;
      END IF;
    END IF;

    -- Bước 3: trả ghế về trống và chuyển đơn sang CANCELLED
    -- (nếu đơn đang PENDING thì chỉ cần làm đúng bước này, bỏ qua bước 2)
    UPDATE showtime_seat
       SET status = 'AVAILABLE', held_by = NULL, hold_expires_at = NULL, booking_id = NULL
     WHERE booking_id = p_booking_id;
    UPDATE booking SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END sp_cancel_booking;

  -- 3.11.d. Chống chồng giờ chiếu trong cùng phòng
  FUNCTION fn_check_room_overlap(
    p_room_id NUMBER, p_start TIMESTAMP, p_end TIMESTAMP,
    p_exclude_id NUMBER DEFAULT NULL) RETURN NUMBER IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt
      FROM showtime s
     WHERE s.room_id = p_room_id
       AND s.status <> 'CANCELLED'
       AND (p_exclude_id IS NULL OR s.showtime_id <> p_exclude_id)
       AND s.start_time < p_end      -- suất mới bắt đầu trước khi suất cũ kết thúc
       AND s.end_time   > p_start;   -- và kết thúc sau khi suất cũ bắt đầu
    RETURN v_cnt;
  END fn_check_room_overlap;

  PROCEDURE sp_add_showtime(
    p_movie_id NUMBER, p_room_id NUMBER, p_start TIMESTAMP, p_end TIMESTAMP,
    p_base_price NUMBER, p_showtime_id OUT NUMBER) IS
  BEGIN
    IF fn_check_room_overlap(p_room_id, p_start, p_end) > 0 THEN
      RAISE_APPLICATION_ERROR(-20050, 'Phong da co suat chieu trung gio');
    END IF;

    INSERT INTO showtime(movie_id, room_id, start_time, end_time, base_price, status)
    VALUES (p_movie_id, p_room_id, p_start, p_end, p_base_price, 'OPEN')
    RETURNING showtime_id INTO p_showtime_id;
    COMMIT;
    -- Lưu ý: trigger trg_showtime_seed (file 04) sẽ tự động chạy ngay sau INSERT
    -- này để sinh sẵn các dòng ghế trống cho suất chiếu vừa tạo.
  END sp_add_showtime;

END pkg_booking;
/

-- ============================================================
-- 04_triggers_job.sql
-- Trigger tự sinh ghế trống cho suất chiếu mới (3.6), job dọn ghế
-- giữ quá hạn chạy mỗi phút (3.6), trigger ghi nhật ký đổi trạng thái
-- đơn (3.11.c). Chạy SAU khi đã có pkg_booking (file 03) vì job gọi
-- thẳng pkg_booking.sp_release_expired_holds.
-- ============================================================

-- 3.6. Tự sinh ghế trống ngay khi thêm một suất chiếu mới
CREATE OR REPLACE TRIGGER trg_showtime_seed
AFTER INSERT ON showtime FOR EACH ROW
BEGIN
  INSERT INTO showtime_seat(showtime_id, seat_id)
  SELECT :NEW.showtime_id, seat_id FROM seat WHERE room_id = :NEW.room_id;
END;
/

-- 3.6. Job chạy mỗi phút để giải phóng ghế giữ quá hạn
BEGIN
  -- Xoá job cũ nếu lỡ chạy file này hai lần, tránh lỗi "job đã tồn tại"
  BEGIN
    DBMS_SCHEDULER.DROP_JOB('JOB_RELEASE_HOLDS', force => TRUE);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_RELEASE_HOLDS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN pkg_booking.sp_release_expired_holds; END;',
    repeat_interval => 'FREQ=MINUTELY;INTERVAL=1',
    enabled         => TRUE);
END;
/

-- 3.11.c. Nhật ký đổi trạng thái đơn
CREATE OR REPLACE TRIGGER trg_booking_audit
AFTER UPDATE OF status ON booking FOR EACH ROW
WHEN (OLD.status <> NEW.status)
BEGIN
  INSERT INTO audit_log(table_name, record_id, action, old_value, new_value)
  VALUES ('BOOKING', :NEW.booking_id, 'STATUS_CHANGE', :OLD.status, :NEW.status);
END;
/

-- ============================================================
-- 05_mle_password.sql
-- Hàm MLE (JavaScript) kiểm tra độ mạnh mật khẩu (mục 3.8 báo cáo).
-- Nếu Oracle báo thiếu quyền tạo MLE MODULE, xem lại file 00
-- (DB_DEVELOPER_ROLE đã bao gồm quyền này trên Oracle 23ai).
-- ============================================================

-- 1. Tạo MLE MODULE chứa mã JavaScript
CREATE OR REPLACE MLE MODULE mod_password_check
LANGUAGE JAVASCRIPT AS

export function isStrongPassword(pwd) {
  if (!pwd || pwd.length < 8) return 0;
  const hasUpper = /[A-Z]/.test(pwd);
  const hasLower = /[a-z]/.test(pwd);
  const hasDigit = /[0-9]/.test(pwd);
  return (hasUpper && hasLower && hasDigit) ? 1 : 0;
}
/

-- 2. Tạo Function PL/SQL gọi hàm JavaScript trên qua MLE
CREATE OR REPLACE FUNCTION fn_is_strong_password(p_password VARCHAR2)
RETURN NUMBER
AS MLE MODULE mod_password_check
SIGNATURE 'isStrongPassword(string)';
/

-- 3. Sử dụng trong thủ tục đăng ký khách hàng
CREATE OR REPLACE PROCEDURE sp_register_customer(
  p_full_name IN VARCHAR2, p_email IN VARCHAR2,
  p_password  IN VARCHAR2, p_customer_id OUT NUMBER) IS
BEGIN
  IF fn_is_strong_password(p_password) = 0 THEN
    RAISE_APPLICATION_ERROR(-20060,
      'Mat khau phai co it nhat 8 ky tu, gom chu hoa, chu thuong va so');
  END IF;
  INSERT INTO customer(full_name, email, password_hash)
  VALUES (p_full_name, p_email, STANDARD_HASH(p_password, 'SHA256'))
  RETURNING customer_id INTO p_customer_id;
  COMMIT;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20061, 'Email da duoc dang ky');
END sp_register_customer;
/

-- ============================================================
-- 06_views_reports.sql
-- Sơ đồ ghế cho giao diện, view + hàm thống kê doanh thu/lấp đầy
-- (mục 3.11.a và 3.11.e báo cáo).
-- ============================================================

-- 3.11.a. Sơ đồ ghế — giao diện chỉ đọc view này, không đọc thẳng SHOWTIME_SEAT
CREATE OR REPLACE VIEW v_seat_map AS
SELECT ss.showtime_id, s.seat_id, s.row_label, s.seat_no, s.seat_type,
       CASE WHEN ss.status = 'HELD' AND ss.hold_expires_at < SYSTIMESTAMP
            THEN 'AVAILABLE' ELSE ss.status END AS status
  FROM showtime_seat ss JOIN seat s ON s.seat_id = ss.seat_id;

-- 3.11.e. Thống kê doanh thu và tỉ lệ lấp đầy (cho quản trị)
CREATE OR REPLACE VIEW v_revenue_by_movie AS
SELECT m.movie_id, m.title, TRUNC(st.start_time) AS show_date,
       COUNT(*) AS tickets_sold, SUM(t.price) AS gross_revenue
  FROM ticket t
  JOIN booking  b  ON b.booking_id  = t.booking_id AND b.status = 'PAID'
  JOIN showtime st ON st.showtime_id = t.showtime_id
  JOIN movie    m  ON m.movie_id     = st.movie_id
 GROUP BY m.movie_id, m.title, TRUNC(st.start_time);

CREATE OR REPLACE FUNCTION fn_occupancy_rate(p_showtime_id NUMBER) RETURN NUMBER IS
  v_rate NUMBER;
BEGIN
  SELECT ROUND(100 * COUNT(CASE WHEN status = 'SOLD' THEN 1 END) / NULLIF(COUNT(*), 0), 1)
    INTO v_rate FROM showtime_seat WHERE showtime_id = p_showtime_id;
  RETURN NVL(v_rate, 0);
END;
/

-- ============================================================
-- 07_grants.sql  (mục 3.11.f báo cáo — không bắt buộc để demo chạy được)
-- Trong đồ án này, schema cinema_app vừa là nơi sở hữu toàn bộ
-- bảng/package (schema owner) vừa đóng luôn vai trò tài khoản ứng
-- dụng kết nối CSDL, nên role bên dưới chủ yếu MINH HOẠ mô hình
-- phân quyền "ứng dụng không ghi trực tiếp lên bảng, chỉ gọi qua
-- package" — chủ owner thì mặc nhiên có đủ quyền rồi nên tự cấp cho
-- chính mình không thay đổi gì cả.
-- Nếu muốn làm đúng nghĩa (và có câu trả lời chắc hơn khi vấn đáp),
-- có thể tạo thêm một user khác (vd cinema_web) không sở hữu bảng,
-- chỉ được CONNECT + cấp đúng role này, rồi để ứng dụng web dùng
-- user đó thay vì user chủ schema.
-- ============================================================

CREATE ROLE cinema_app_role;
GRANT EXECUTE ON pkg_booking            TO cinema_app_role;
GRANT EXECUTE ON fn_is_strong_password  TO cinema_app_role;
GRANT SELECT  ON movie                  TO cinema_app_role;
GRANT SELECT  ON showtime               TO cinema_app_role;
GRANT SELECT  ON v_seat_map             TO cinema_app_role;
GRANT cinema_app_role TO cinema_app;   -- cinema_app: tài khoản ứng dụng

-- ============================================================
-- 08_seed_data_and_test.sql
-- Dữ liệu mẫu để CSDL có cái mà xem/chạy thử ngay, cộng một đoạn
-- test nhanh ở cuối để chứng minh toàn bộ luồng (giữ ghế → thanh
-- toán → xem báo cáo doanh thu) chạy đúng.
-- Chạy SAU khi đã có đủ file 01 → 06 (và 07 nếu muốn).
-- ============================================================

-- Lưu ý khi chạy bằng DBeaver (khác SQL Developer/SQLcl):
-- "SET SERVEROUTPUT ON" là lệnh riêng của SQL*Plus, DBeaver không hiểu.
-- Để thấy được các dòng DBMS_OUTPUT.PUT_LINE bên dưới, mở tab
-- "Output" / "DBMS Output" trong DBeaver (Window > tìm "DBMS Output",
-- hoặc icon hình loa ở panel dưới cùng khi đang mở SQL Editor) rồi bấm
-- nút bật (Enable) CHO CHÍNH KẾT NỐI đang dùng, trước khi chạy script này.

-- 1) Rạp và phòng chiếu
INSERT INTO theater(name, address) VALUES ('CGV Demo', '123 Đường ABC, Quận 1, TP.HCM');

INSERT INTO room(theater_id, name, room_type)
SELECT theater_id, 'Phòng 1', '2D' FROM theater WHERE name = 'CGV Demo';
INSERT INTO room(theater_id, name, room_type)
SELECT theater_id, 'Phòng 2', '3D' FROM theater WHERE name = 'CGV Demo';

-- 2) Ghế: mỗi phòng 5 hàng (A–E) x 8 ghế/hàng.
--    Hàng A,B: STANDARD — hàng C,D: VIP — hàng E: COUPLE.
BEGIN
  FOR r IN (SELECT room_id FROM room) LOOP
    FOR i IN 1..5 LOOP               -- hàng ghế: A=1, B=2, ... E=5
      FOR j IN 1..8 LOOP             -- số ghế trong hàng
        INSERT INTO seat(room_id, row_label, seat_no, seat_type)
        VALUES (r.room_id, CHR(64 + i), j,
                CASE WHEN i <= 2 THEN 'STANDARD'
                     WHEN i <= 4 THEN 'VIP'
                     ELSE 'COUPLE' END);
      END LOOP;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

-- 3) Phim (metadata là JSON lưu dạng chuỗi, đúng thiết kế mục 2.6)
INSERT INTO movie(title, genre, duration_min, rating, release_date, metadata) VALUES
('Biệt Đội Siêu Anh Hùng', 'Hành động', 130, 'C13', DATE '2026-01-10',
 '{"director":"Nguyen Van Dao","actors":["Dien Vien A","Dien Vien B"],"language":"Phu de"}');
INSERT INTO movie(title, genre, duration_min, rating, release_date, metadata) VALUES
('Mùa Hè Của Chúng Ta', 'Tâm lý', 105, 'P', DATE '2026-02-01',
 '{"director":"Tran Thi Hoa","actors":["Dien Vien C"],"language":"Long tieng"}');
INSERT INTO movie(title, genre, duration_min, rating, release_date, metadata) VALUES
('Vương Quốc Hoạt Hình', 'Hoạt hình', 95, 'P', DATE '2026-03-15',
 '{"director":"Le Van Binh","actors":["Long tieng Vietnam"],"language":"Long tieng"}');
COMMIT;

-- 4) Suất chiếu — tạo qua pkg_booking.sp_add_showtime để đi đúng luồng
--    (hàm fn_check_room_overlap kiểm tra trùng giờ, trigger trg_showtime_seed
--    tự sinh sẵn ghế trống cho từng suất vừa tạo).
DECLARE
  v_showtime_id NUMBER;
  v_ngay_mai    DATE := TRUNC(SYSDATE) + 1;
  v_movie1 NUMBER; v_movie2 NUMBER; v_movie3 NUMBER;
  v_room1  NUMBER; v_room2  NUMBER;
BEGIN
  SELECT movie_id INTO v_movie1 FROM movie ORDER BY movie_id OFFSET 0 ROWS FETCH NEXT 1 ROW ONLY;
  SELECT movie_id INTO v_movie2 FROM movie ORDER BY movie_id OFFSET 1 ROWS FETCH NEXT 1 ROW ONLY;
  SELECT movie_id INTO v_movie3 FROM movie ORDER BY movie_id OFFSET 2 ROWS FETCH NEXT 1 ROW ONLY;
  SELECT room_id  INTO v_room1  FROM room WHERE name = 'Phòng 1' ORDER BY room_id FETCH FIRST 1 ROW ONLY;
  SELECT room_id  INTO v_room2  FROM room WHERE name = 'Phòng 2' ORDER BY room_id FETCH FIRST 1 ROW ONLY;

  -- Suất 1: Phòng 1, 09:00 ngày mai, giá cơ sở 75.000
  pkg_booking.sp_add_showtime(
    v_movie1, v_room1,
    CAST(v_ngay_mai + 9/24 AS TIMESTAMP),
    CAST(v_ngay_mai + 11.2/24 AS TIMESTAMP),
    75000, v_showtime_id);

  -- Suất 2: Phòng 1, 14:00 ngày mai (không chồng giờ với suất 1)
  pkg_booking.sp_add_showtime(
    v_movie2, v_room1,
    CAST(v_ngay_mai + 14/24 AS TIMESTAMP),
    CAST(v_ngay_mai + 15.75/24 AS TIMESTAMP),
    65000, v_showtime_id);

  -- Suất 3: Phòng 2, 10:00 ngày mai
  pkg_booking.sp_add_showtime(
    v_movie3, v_room2,
    CAST(v_ngay_mai + 10/24 AS TIMESTAMP),
    CAST(v_ngay_mai + 11.6/24 AS TIMESTAMP),
    80000, v_showtime_id);

  COMMIT;
END;
/

-- 5) Khách hàng — đăng ký qua sp_register_customer để đi qua MLE
--    kiểm tra độ mạnh mật khẩu (mục 3.8).
DECLARE
  v_customer_id NUMBER;
BEGIN
  sp_register_customer('Nguyễn Văn An', 'an.nguyen@example.com', 'MatKhau123', v_customer_id);
  sp_register_customer('Trần Thị Bình', 'binh.tran@example.com', 'MatKhau456', v_customer_id);
END;
/

-- 6) Mã khuyến mãi mẫu
INSERT INTO promotion(code, discount_type, discount_value, max_discount, min_amount,
                       valid_from, valid_to, max_uses, used_count, is_active, conditions)
VALUES ('WELCOME10', 'PERCENT', 10, 50000, 100000,
        DATE '2026-01-01', DATE '2026-12-31', 100, 0, 1, NULL);

INSERT INTO promotion(code, discount_type, discount_value, max_discount, min_amount,
                       valid_from, valid_to, max_uses, used_count, is_active, conditions)
VALUES ('WEEKDAY20', 'PERCENT', 20, 30000, 0,
        DATE '2026-01-01', DATE '2026-12-31', NULL, 0, 1, '{"days":["MON","TUE","WED"]}');
COMMIT;

-- ============================================================
-- 7) TEST NHANH: giữ ghế → xác nhận thanh toán → xem lại
--    (chạy thử để tự thấy toàn bộ luồng hoạt động đúng)
-- ============================================================
DECLARE
  v_showtime_id NUMBER;
  v_customer_id NUMBER;
  v_seat1 NUMBER; v_seat2 NUMBER;
  v_booking_id NUMBER;
BEGIN
  SELECT showtime_id INTO v_showtime_id
    FROM showtime WHERE base_price = 75000 AND ROWNUM = 1;
  SELECT customer_id INTO v_customer_id
    FROM customer WHERE email = 'an.nguyen@example.com';

  -- lấy 2 ghế STANDARD hàng A của chính phòng đang chiếu suất trên
  SELECT seat_id INTO v_seat1 FROM seat
   WHERE room_id = (SELECT room_id FROM showtime WHERE showtime_id = v_showtime_id)
     AND row_label = 'A' AND seat_no = 1;
  SELECT seat_id INTO v_seat2 FROM seat
   WHERE room_id = (SELECT room_id FROM showtime WHERE showtime_id = v_showtime_id)
     AND row_label = 'A' AND seat_no = 2;

  -- Bước 1: giữ 2 ghế trong 10 phút
  pkg_booking.sp_hold_seats(
    v_customer_id, v_showtime_id,
    SYS.ODCINUMBERLIST(v_seat1, v_seat2), v_booking_id);
  DBMS_OUTPUT.PUT_LINE('Da giu cho thanh cong, booking_id = ' || v_booking_id);

  -- Bước 2: xác nhận thanh toán, dùng mã khuyến mãi WELCOME10
  pkg_booking.sp_confirm_booking(v_booking_id, 'WELCOME10', 'CREDIT_CARD');
  DBMS_OUTPUT.PUT_LINE('Da xac nhan thanh toan cho booking_id = ' || v_booking_id);
END;
/

-- Xem lại kết quả. "PROMPT" và "EXEC" là lệnh riêng của SQL*Plus nên
-- không dùng ở đây; DBeaver chỉ hiểu SQL/PL-SQL chuẩn.

-- ===== Thông tin đơn vừa thanh toán =====
SELECT booking_id, status, subtotal, discount_amount, final_amount, promo_code
  FROM booking ORDER BY booking_id DESC FETCH FIRST 1 ROWS ONLY;

-- ===== Sơ đồ ghế của suất chiếu (chỉ các ghế không còn trống) =====
SELECT * FROM v_seat_map WHERE status <> 'AVAILABLE';

-- ===== Báo cáo doanh thu theo NGÀY THANH TOÁN (paid_at), không phải
-- ngày chiếu — nên dù suất chiếu là "ngày mai", đơn vừa thanh toán xong
-- (paid_at = hôm nay) vẫn xuất hiện ngay trong báo cáo của hôm nay.
-- Thay "EXEC thu_tuc;" (SQL*Plus) bằng khối PL/SQL thường:
BEGIN
  pkg_booking.sp_daily_revenue_report;
END;
/

SELECT * FROM CUSTOMER
SELECT * FROM REVIEW 
SELECT * FROM MOVIE 