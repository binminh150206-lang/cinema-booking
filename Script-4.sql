-- ============================================================
-- MỞ RỘNG CSDL CINEDB (Chạy bằng Alt + X trên CINEMA_SCHEMA)
-- ============================================================

-- 1. Mở rộng các bảng hiện có
ALTER TABLE theater ADD (city VARCHAR2(60));
UPDATE theater SET city = 'TP. Hồ Chí Minh' WHERE city IS NULL;

ALTER TABLE customer ADD (
  role           VARCHAR2(10) DEFAULT 'CUSTOMER' NOT NULL CHECK (role IN ('CUSTOMER','ADMIN')),
  birth_date     DATE,
  gender         VARCHAR2(10),
  address        VARCHAR2(200),
  otp_code       VARCHAR2(10),
  otp_expires_at TIMESTAMP
);

ALTER TABLE movie ADD (
  status VARCHAR2(5) DEFAULT 'NOW' NOT NULL CHECK (status IN ('NOW','SOON'))
);

-- 2. Tạo các bảng mở rộng (Combo bắp nước & Đánh giá phim)
CREATE TABLE combo (
  combo_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR2(100) NOT NULL,
  description VARCHAR2(300),
  price       NUMBER(10) NOT NULL CHECK (price >= 0),
  is_active   NUMBER(1) DEFAULT 1 NOT NULL
);

CREATE TABLE booking_combo (
  booking_id NUMBER NOT NULL REFERENCES booking(booking_id),
  combo_id   NUMBER NOT NULL REFERENCES combo(combo_id),
  qty        NUMBER(2) NOT NULL CHECK (qty BETWEEN 1 AND 10),
  unit_price NUMBER(10) NOT NULL,
  CONSTRAINT pk_booking_combo PRIMARY KEY (booking_id, combo_id)
);

ALTER TABLE booking ADD (combo_amount NUMBER(10) DEFAULT 0 NOT NULL);

CREATE TABLE review (
  review_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  movie_id    NUMBER NOT NULL REFERENCES movie(movie_id),
  customer_id NUMBER NOT NULL REFERENCES customer(customer_id),
  rating      NUMBER(1) NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content     VARCHAR2(1000),
  created_at  TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT uq_review UNIQUE (movie_id, customer_id)
);

-- 3. Cập nhật package pkg_booking để sp_confirm_booking xử lý combo
CREATE OR REPLACE PACKAGE pkg_booking IS
  PROCEDURE sp_hold_seats(
    p_customer_id IN NUMBER, p_showtime_id IN NUMBER,
    p_seat_ids IN SYS.ODCINUMBERLIST, p_booking_id OUT NUMBER
  );

  PROCEDURE sp_confirm_booking(
    p_booking_id IN NUMBER, p_promo_code IN VARCHAR2,
    p_method IN VARCHAR2, p_combos IN VARCHAR2 DEFAULT NULL
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

CREATE OR REPLACE PACKAGE BODY pkg_booking IS

  PROCEDURE sp_hold_seats(
    p_customer_id IN NUMBER, p_showtime_id IN NUMBER,
    p_seat_ids IN SYS.ODCINUMBERLIST, p_booking_id OUT NUMBER) IS
    c_hold_minutes CONSTANT NUMBER := 10;
    v_expire TIMESTAMP := SYSTIMESTAMP + NUMTODSINTERVAL(c_hold_minutes, 'MINUTE');
    v_start TIMESTAMP; v_status VARCHAR2(10);
  BEGIN
    SELECT start_time, status INTO v_start, v_status
      FROM showtime WHERE showtime_id = p_showtime_id;
    IF v_status <> 'OPEN' OR v_start <= SYSTIMESTAMP THEN
      RAISE_APPLICATION_ERROR(-20012, 'Suất chiếu đã đóng bán');
    END IF;

    IF p_seat_ids IS NULL OR p_seat_ids.COUNT NOT BETWEEN 1 AND 8 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Mỗi đơn đặt từ 1 đến 8 ghế');
    END IF;

    SAVEPOINT sp_start;

    INSERT INTO booking(customer_id, showtime_id, status, expires_at)
    VALUES (p_customer_id, p_showtime_id, 'PENDING', v_expire)
    RETURNING booking_id INTO p_booking_id;

    FOR r IN (SELECT column_value AS seat_id FROM TABLE(p_seat_ids) ORDER BY 1) LOOP
      UPDATE showtime_seat
         SET status = 'HELD', held_by = p_customer_id,
             hold_expires_at = v_expire, booking_id = p_booking_id
       WHERE showtime_id = p_showtime_id AND seat_id = r.seat_id
         AND (status = 'AVAILABLE'
              OR (status = 'HELD' AND hold_expires_at < SYSTIMESTAMP));
      IF SQL%ROWCOUNT = 0 THEN
        ROLLBACK TO sp_start;
        RAISE_APPLICATION_ERROR(-20011,
          'Ghế ' || r.seat_id || ' đã có người giữ hoặc đã bán');
      END IF;
    END LOOP;
    COMMIT;
  END sp_hold_seats;

  PROCEDURE sp_confirm_booking(
    p_booking_id IN NUMBER, p_promo_code IN VARCHAR2,
    p_method IN VARCHAR2, p_combos IN VARCHAR2 DEFAULT NULL) IS
    v_status      VARCHAR2(10);
    v_expires_at  TIMESTAMP;
    v_showtime_id NUMBER;
    v_total NUMBER; v_cnt NUMBER;
    v_subtotal NUMBER; v_discount NUMBER;
    v_combo_amt NUMBER := 0;
    v_obj JSON_OBJECT_T;
    v_keys JSON_KEY_LIST;
    v_cid NUMBER; v_qty NUMBER; v_cprice NUMBER;
  BEGIN
    SELECT status, expires_at, showtime_id
      INTO v_status, v_expires_at, v_showtime_id
      FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
    IF v_status <> 'PENDING' OR v_expires_at < SYSTIMESTAMP THEN
      RAISE_APPLICATION_ERROR(-20020, 'Đơn không còn hiệu lực');
    END IF;

    SELECT COUNT(*) INTO v_total FROM showtime_seat WHERE booking_id = p_booking_id;

    INSERT INTO ticket(booking_id, showtime_id, seat_id, price)
    SELECT booking_id, showtime_id, seat_id, fn_calc_ticket_price(showtime_id, seat_id)
      FROM showtime_seat
     WHERE booking_id = p_booking_id AND status = 'HELD'
       AND hold_expires_at >= SYSTIMESTAMP;
    v_cnt := SQL%ROWCOUNT;
    IF v_cnt = 0 OR v_cnt <> v_total THEN
      RAISE_APPLICATION_ERROR(-20021, 'Có ghế đã hết hạn giữ chỗ');
    END IF;

    IF p_combos IS NOT NULL AND TRIM(p_combos) NOT IN ('', '{}', 'null') THEN
      v_obj := JSON_OBJECT_T.parse(p_combos);
      v_keys := v_obj.get_keys;
      FOR i IN 1 .. v_keys.COUNT LOOP
        v_cid := TO_NUMBER(v_keys(i));
        v_qty := v_obj.get_Number(v_keys(i));
        IF v_qty > 0 THEN
          SELECT price INTO v_cprice FROM combo WHERE combo_id = v_cid AND is_active = 1;
          INSERT INTO booking_combo(booking_id, combo_id, qty, unit_price)
          VALUES (p_booking_id, v_cid, v_qty, v_cprice);
          v_combo_amt := v_combo_amt + (v_qty * v_cprice);
        END IF;
      END LOOP;
    END IF;

    SELECT SUM(price) INTO v_subtotal FROM ticket WHERE booking_id = p_booking_id;
    v_discount := fn_calc_discount(p_promo_code, v_subtotal, v_showtime_id);

    IF v_discount > 0 THEN
      UPDATE promotion SET used_count = used_count + 1
       WHERE code = UPPER(p_promo_code)
         AND (max_uses IS NULL OR used_count < max_uses);
      IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20031, 'Mã khuyến mãi đã hết lượt dùng');
      END IF;
    END IF;

    UPDATE showtime_seat SET status = 'SOLD', held_by = NULL, hold_expires_at = NULL
     WHERE booking_id = p_booking_id;
    UPDATE booking SET subtotal = v_subtotal, discount_amount = v_discount,
           combo_amount = v_combo_amt,
           final_amount = v_subtotal - v_discount + v_combo_amt,
           promo_code = UPPER(p_promo_code),
           status = 'PAID', paid_at = SYSTIMESTAMP
     WHERE booking_id = p_booking_id;
    INSERT INTO payment(booking_id, method, amount, status, paid_at)
    VALUES (p_booking_id, p_method, v_subtotal - v_discount + v_combo_amt, 'SUCCESS', SYSTIMESTAMP);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END sp_confirm_booking;

  PROCEDURE sp_release_expired_holds IS
  BEGIN
    UPDATE showtime_seat
       SET status = 'AVAILABLE', held_by = NULL, hold_expires_at = NULL, booking_id = NULL
     WHERE status = 'HELD' AND hold_expires_at < SYSTIMESTAMP;
    UPDATE booking SET status = 'EXPIRED'
     WHERE status = 'PENDING' AND expires_at < SYSTIMESTAMP;
    COMMIT;
  END sp_release_expired_holds;

  PROCEDURE sp_daily_revenue_report(p_date IN DATE DEFAULT TRUNC(SYSDATE)) IS
    CURSOR c_revenue IS
      SELECT m.title, COUNT(*) AS tickets_sold, SUM(t.price) AS revenue
        FROM ticket t
        JOIN booking  b  ON b.booking_id = t.booking_id AND b.status = 'PAID'
        JOIN showtime st ON st.showtime_id = t.showtime_id
        JOIN movie    m  ON m.movie_id = st.movie_id
       WHERE TRUNC(b.paid_at) = p_date
       GROUP BY m.title
       ORDER BY SUM(t.price) DESC;
    v_title VARCHAR2(200); v_tickets_sold NUMBER; v_revenue NUMBER;
    v_total_rev NUMBER := 0; v_total_tkt NUMBER := 0;
  BEGIN
    DBMS_OUTPUT.PUT_LINE('BAO CAO DOANH THU NGAY ' || TO_CHAR(p_date, 'DD/MM/YYYY'));
    OPEN c_revenue;
    LOOP
      FETCH c_revenue INTO v_title, v_tickets_sold, v_revenue;
      EXIT WHEN c_revenue%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE(RPAD(v_title, 35) || LPAD(v_tickets_sold, 10) || LPAD(TO_CHAR(v_revenue, '999,999,999'), 15));
      v_total_rev := v_total_rev + v_revenue;
      v_total_tkt := v_total_tkt + v_tickets_sold;
    END LOOP;
    CLOSE c_revenue;
    DBMS_OUTPUT.PUT_LINE(RPAD('TONG CONG', 35) || LPAD(v_total_tkt, 10) || LPAD(TO_CHAR(v_total_rev, '999,999,999'), 15));
  EXCEPTION
    WHEN OTHERS THEN
      IF c_revenue%ISOPEN THEN CLOSE c_revenue; END IF;
      RAISE;
  END sp_daily_revenue_report;

  PROCEDURE sp_cancel_booking(p_booking_id IN NUMBER, p_customer_id IN NUMBER) IS
    v_bk_customer_id NUMBER; v_status VARCHAR2(10); v_showtime_id NUMBER;
    v_promo_code VARCHAR2(30); v_final_amount NUMBER; v_start TIMESTAMP;
  BEGIN
    SELECT customer_id, status, showtime_id, promo_code, final_amount
      INTO v_bk_customer_id, v_status, v_showtime_id, v_promo_code, v_final_amount
      FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
    IF v_bk_customer_id <> p_customer_id THEN
      RAISE_APPLICATION_ERROR(-20040, 'Không có quyền huỷ đơn này');
    ELSIF v_status NOT IN ('PENDING', 'PAID') THEN
      RAISE_APPLICATION_ERROR(-20041, 'Đơn không thể huỷ ở trạng thái hiện tại');
    END IF;

    IF v_status = 'PAID' THEN
      SELECT start_time INTO v_start FROM showtime WHERE showtime_id = v_showtime_id;
      IF v_start < SYSTIMESTAMP + INTERVAL '2' HOUR THEN
        RAISE_APPLICATION_ERROR(-20042, 'Chỉ huỷ vé đã thanh toán trước giờ chiếu ít nhất 2 giờ');
      END IF;
      DELETE FROM ticket WHERE booking_id = p_booking_id;
      INSERT INTO payment(booking_id, method, amount, status, paid_at)
      VALUES (p_booking_id, 'REFUND', -v_final_amount, 'REFUNDED', SYSTIMESTAMP);
      IF v_promo_code IS NOT NULL THEN
        UPDATE promotion SET used_count = GREATEST(used_count - 1, 0) WHERE code = v_promo_code;
      END IF;
    END IF;

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
       AND s.start_time < p_end
       AND s.end_time   > p_start;
    RETURN v_cnt;
  END fn_check_room_overlap;

  PROCEDURE sp_add_showtime(
    p_movie_id NUMBER, p_room_id NUMBER, p_start TIMESTAMP, p_end TIMESTAMP,
    p_base_price NUMBER, p_showtime_id OUT NUMBER) IS
  BEGIN
    IF fn_check_room_overlap(p_room_id, p_start, p_end) > 0 THEN
      RAISE_APPLICATION_ERROR(-20050, 'Phòng đã có suất chiếu trùng giờ');
    END IF;
    INSERT INTO showtime(movie_id, room_id, start_time, end_time, base_price, status)
    VALUES (p_movie_id, p_room_id, p_start, p_end, p_base_price, 'OPEN')
    RETURNING showtime_id INTO p_showtime_id;
    COMMIT;
  END sp_add_showtime;

END pkg_booking;
/

-- 4. Dữ liệu mẫu bổ sung (Admin, Combo, Khuyến mãi)
INSERT INTO customer(full_name, email, password_hash, role)
VALUES ('Quản trị viên', 'admin@cinedb.vn', STANDARD_HASH('Admin123', 'SHA256'), 'ADMIN');

INSERT INTO combo(name, description, price) VALUES ('Combo Bắp Nước', '1 bắp lớn và 1 nước', 79000);
INSERT INTO combo(name, description, price) VALUES ('Combo Đôi', '2 bắp và 2 nước', 129000);
INSERT INTO combo(name, description, price) VALUES ('Nước ngọt', 'Ly lớn', 29000);

INSERT INTO promotion(code, discount_type, discount_value, max_discount, min_amount, valid_from, valid_to, max_uses, used_count, is_active, conditions)
VALUES ('GIAM50K', 'AMOUNT', 50000, NULL, 200000, DATE '2026-01-01', DATE '2026-12-31', 50, 0, 1, NULL);

INSERT INTO promotion(code, discount_type, discount_value, max_discount, min_amount, valid_from, valid_to, max_uses, used_count, is_active, conditions)
VALUES ('THU3', 'PERCENT', 15, 40000, 0, DATE '2026-01-01', DATE '2026-12-31', NULL, 0, 1, '{"days":["TUE"]}');

-- 5. Tạo 2 Index tối ưu truy vấn (bỏ qua nếu đã tồn tại)
BEGIN
  EXECUTE IMMEDIATE 'CREATE INDEX idx_ss_hold ON showtime_seat(status, hold_expires_at)';
EXCEPTION WHEN OTHERS THEN IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'CREATE INDEX idx_showtime_movie ON showtime(movie_id, start_time)';
EXCEPTION WHEN OTHERS THEN IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/

COMMIT;	