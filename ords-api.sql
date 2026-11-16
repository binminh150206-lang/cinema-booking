BEGIN
  ORDS.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'CINEMA_SCHEMA',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'cinema',
    p_auto_rest_auth      => FALSE
  );

  BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'cinema_api');
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  ORDS.DEFINE_MODULE(
    p_module_name    => 'cinema_api',
    p_base_path      => '/',
    p_items_per_page => 200,
    p_status         => 'PUBLISHED',
    p_comments       => 'CineDB REST API synced with js/api.js'
  );

  -- 1. PHIM
  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'movies');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'movies', p_method => 'GET',
    p_source_type => 'json/collection',
    p_source      => q'[
      SELECT m.movie_id, m.title, m.genre, m.duration_min, m.rating,
             m.release_date, m.metadata, m.status,
             NVL((SELECT ROUND(AVG(r.rating), 1) FROM review r WHERE r.movie_id = m.movie_id), 0) AS avg_rating,
             (SELECT COUNT(*) FROM review r WHERE r.movie_id = m.movie_id) AS review_count
        FROM movie m
       ORDER BY m.movie_id
    ]'
  );
  BEGIN
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api',
    p_pattern     => 'movies',
    p_method      => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE
        v_raw    CLOB;
        v_obj    JSON_OBJECT_T;
        v_elem   JSON_ELEMENT_T;
        v_id     NUMBER := NULL;
        v_title  VARCHAR2(200);
        v_genre  VARCHAR2(100);
        v_dur    NUMBER;
        v_rating VARCHAR2(20);
        v_status VARCHAR2(20) := 'NOW';
        v_meta   VARCHAR2(32767) := NULL;
      BEGIN
        v_raw := :body_text;
        IF v_raw IS NULL OR DBMS_LOB.GETLENGTH(v_raw) = 0 THEN
          RAISE_APPLICATION_ERROR(-20050, 'Dữ liệu JSON gửi lên bị rỗng');
        END IF;

        v_obj := JSON_OBJECT_T.parse(v_raw);

        IF v_obj.has('movie_id') AND NOT v_obj.get('movie_id').is_null THEN
          v_id := TO_NUMBER(TRIM(v_obj.get_String('movie_id')));
        END IF;

        v_title  := v_obj.get_String('title');
        v_genre  := v_obj.get_String('genre');
        v_dur    := TO_NUMBER(TRIM(v_obj.get_String('duration_min')));
        v_rating := v_obj.get_String('rating');

        IF v_obj.has('status') AND NOT v_obj.get('status').is_null THEN
          v_status := NVL(TRIM(v_obj.get_String('status')), 'NOW');
        END IF;

        IF v_obj.has('metadata') AND NOT v_obj.get('metadata').is_null THEN
          v_elem := v_obj.get('metadata');
          IF v_elem.is_string THEN
            v_meta := v_obj.get_String('metadata');
          ELSE
            v_meta := v_elem.stringify();
          END IF;
        END IF;

        IF v_id IS NOT NULL THEN
          UPDATE movie
             SET title        = v_title,
                 genre        = v_genre,
                 duration_min = v_dur,
                 rating       = v_rating,
                 status       = v_status
           WHERE movie_id = v_id;
          IF v_meta IS NOT NULL THEN
            UPDATE movie SET metadata = v_meta WHERE movie_id = v_id;
          END IF;
        ELSE
          INSERT INTO movie(title, genre, duration_min, rating, release_date, status, metadata)
          VALUES (v_title, v_genre, v_dur, v_rating, TRUNC(SYSDATE), v_status, v_meta)
          RETURNING movie_id INTO v_id;
        END IF;

        COMMIT;
        :movie_id := v_id;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          :status_code := 400;
          :error := SQLERRM;
      END;
    ]'
  );
  COMMIT;
END;
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'movies', p_method => 'POST', p_name => 'movie_id', p_bind_variable_name => 'movie_id', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'movies', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'movies/:id');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'movies/:id', p_method => 'DELETE',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE v_cnt NUMBER;
      BEGIN
        SELECT COUNT(*) INTO v_cnt FROM showtime WHERE movie_id = :id;
        IF v_cnt > 0 THEN RAISE_APPLICATION_ERROR(-20052, 'Phim đã có suất chiếu, hãy đổi trạng thái thay vì xoá'); END IF;
        DELETE FROM movie WHERE movie_id = :id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'movies/:id', p_method => 'DELETE', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  -- 2. RẠP, PHÒNG, SUẤT CHIẾU & SƠ ĐỒ GHẾ
  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'theaters');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'theaters', p_method => 'GET', p_source_type => 'json/collection', p_source => 'SELECT theater_id, name, city, address FROM theater ORDER BY theater_id');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'rooms');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'rooms', p_method => 'GET', p_source_type => 'json/collection', p_source => 'SELECT r.room_id, r.theater_id, t.name AS theater_name, r.name FROM room r JOIN theater t ON t.theater_id = r.theater_id ORDER BY r.room_id');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'showtimes');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'showtimes', p_method => 'GET',
    p_source_type => 'json/collection',
    p_source      => q'[
      SELECT st.showtime_id, st.movie_id, m.title, r.theater_id, t.name AS theater_name,
             st.room_id, r.name AS room_name,
             TO_CHAR(st.start_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS start_time,
             TO_CHAR(st.end_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS end_time,
             st.base_price, st.status,
             NVL((SELECT ROUND(100 * SUM(CASE WHEN ss.status = 'SOLD' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0))
                    FROM showtime_seat ss WHERE ss.showtime_id = st.showtime_id), 0) AS occupancy
        FROM showtime st
        JOIN movie m ON m.movie_id = st.movie_id
        JOIN room r ON r.room_id = st.room_id
        JOIN theater t ON t.theater_id = r.theater_id
       WHERE (:movie_id IS NULL OR (st.movie_id = :movie_id AND st.start_time > SYSTIMESTAMP AND st.status = 'OPEN'))
       ORDER BY st.start_time
    ]'
  );

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'showtimes/:id');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'showtimes/:id', p_method => 'GET',
    p_source_type => 'json/item',
    p_source      => q'[
      SELECT st.showtime_id, st.movie_id, m.title, r.theater_id, t.name AS theater_name,
             st.room_id, r.name AS room_name,
             TO_CHAR(st.start_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS start_time,
             TO_CHAR(st.end_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS end_time,
             st.base_price, st.status
        FROM showtime st
        JOIN movie m ON m.movie_id = st.movie_id
        JOIN room r ON r.room_id = st.room_id
        JOIN theater t ON t.theater_id = r.theater_id
       WHERE st.showtime_id = :id
    ]'
  );

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'showtimes/:id/cancel');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'showtimes/:id/cancel', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE v_cnt NUMBER;
      BEGIN
        SELECT COUNT(*) INTO v_cnt FROM showtime_seat WHERE showtime_id = :id AND status IN ('HELD', 'SOLD');
        IF v_cnt > 0 THEN RAISE_APPLICATION_ERROR(-20051, 'Suất đã có người giữ hoặc mua vé, không thể huỷ'); END IF;
        UPDATE showtime SET status = 'CANCELLED' WHERE showtime_id = :id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'showtimes/:id/cancel', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'addshowtime');
  BEGIN
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api',
    p_pattern     => 'addshowtime',
    p_method      => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE
        v_id    NUMBER;
        v_dur   NUMBER;
        v_raw   VARCHAR2(100) := TRIM(:p_start);
        v_start TIMESTAMP;
        v_end   TIMESTAMP;
      BEGIN
        SELECT duration_min INTO v_dur FROM movie WHERE movie_id = :p_movie_id;

        IF REGEXP_LIKE(v_raw, '^\d+$') THEN
          v_start := CAST(
            (TIMESTAMP '1970-01-01 00:00:00 +00:00' + NUMTODSINTERVAL(TO_NUMBER(v_raw) / 1000, 'SECOND'))
            AT TIME ZONE '+07:00' AS TIMESTAMP
          );
        ELSIF INSTR(v_raw, 'Z') > 0 THEN
          v_start := CAST(
            TO_TIMESTAMP_TZ(v_raw, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"')
            AT TIME ZONE '+07:00' AS TIMESTAMP
          );
        ELSE
          v_start := TO_TIMESTAMP(REPLACE(SUBSTR(v_raw, 1, 16), 'T', ' '), 'YYYY-MM-DD HH24:MI');
        END IF;

        v_end := v_start + NUMTODSINTERVAL(v_dur + 15, 'MINUTE');
        pkg_booking.sp_add_showtime(:p_movie_id, :p_room_id, v_start, v_end, :p_base_price, v_id);
        :showtime_id := v_id;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          :status_code := 400;
          :error := SQLERRM;
      END;
    ]'
  );
  COMMIT;
END;
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'addshowtime', p_method => 'POST', p_name => 'showtime_id', p_bind_variable_name => 'showtime_id', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'addshowtime', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'seatmap/:id');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'seatmap/:id', p_method => 'GET',
    p_source_type => 'json/collection',
    p_source      => q'[
      SELECT s.seat_id, s.row_label, s.seat_no, s.seat_type,
             CASE WHEN ss.status = 'HELD' AND ss.hold_expires_at < SYSTIMESTAMP THEN 'AVAILABLE' ELSE ss.status END AS status,
             fn_calc_ticket_price(ss.showtime_id, s.seat_id) AS price
        FROM showtime_seat ss
        JOIN seat s ON s.seat_id = ss.seat_id
       WHERE ss.showtime_id = :id
       ORDER BY s.row_label, s.seat_no
    ]'
  );

  -- 3. GIỮ GHẾ, THANH TOÁN, HỦY VÉ & VÉ CỦA TÔI
  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'hold');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'hold', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'{
      DECLARE
        v_list SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
        v_raw  VARCHAR2(4000) := REGEXP_REPLACE(:p_seat_ids, '[^0-9,]', '');
        v_part VARCHAR2(50); v_idx NUMBER := 1; v_bk NUMBER; v_exp TIMESTAMP;
      BEGIN
        LOOP
          v_part := REGEXP_SUBSTR(v_raw, '[^,]+', 1, v_idx);
          EXIT WHEN v_part IS NULL;
          v_list.EXTEND; v_list(v_list.COUNT) := TO_NUMBER(v_part); v_idx := v_idx + 1;
        END LOOP;
        pkg_booking.sp_hold_seats(:p_customer_id, :p_showtime_id, v_list, v_bk);
        SELECT expires_at INTO v_exp FROM booking WHERE booking_id = v_bk;
        :booking_id := v_bk;
        :expires_at := TO_CHAR(v_exp, 'YYYY-MM-DD"T"HH24:MI:SS');
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    }'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'hold', p_method => 'POST', p_name => 'booking_id', p_bind_variable_name => 'booking_id', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'hold', p_method => 'POST', p_name => 'expires_at', p_bind_variable_name => 'expires_at', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'hold', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'confirm');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'confirm', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      BEGIN
        pkg_booking.sp_confirm_booking(:p_booking_id, :p_promo_code, :p_method, :p_combos);
        SELECT booking_id, subtotal, discount_amount, final_amount
          INTO :booking_id, :subtotal, :discount_amount, :final_amount
          FROM booking WHERE booking_id = :p_booking_id;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'confirm', p_method => 'POST', p_name => 'booking_id', p_bind_variable_name => 'booking_id', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'confirm', p_method => 'POST', p_name => 'subtotal', p_bind_variable_name => 'subtotal', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'confirm', p_method => 'POST', p_name => 'discount_amount', p_bind_variable_name => 'discount_amount', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'confirm', p_method => 'POST', p_name => 'final_amount', p_bind_variable_name => 'final_amount', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'confirm', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'cancel');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'cancel', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      BEGIN
        pkg_booking.sp_cancel_booking(:p_booking_id, :p_customer_id);
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'cancel', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'mybookings');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'mybookings', p_method => 'GET',
    p_source_type => 'json/collection',
    p_source      => q'[
      SELECT b.booking_id,
             CASE WHEN b.status = 'PENDING' AND b.expires_at < SYSTIMESTAMP THEN 'EXPIRED' ELSE b.status END AS status,
             m.title,
             TO_CHAR(st.start_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS start_time,
             r.name AS room_name,
             NVL(
               (SELECT LISTAGG(s.row_label || s.seat_no, ', ') WITHIN GROUP (ORDER BY s.row_label, s.seat_no)
                  FROM ticket tk JOIN seat s ON s.seat_id = tk.seat_id WHERE tk.booking_id = b.booking_id),
               (SELECT LISTAGG(s.row_label || s.seat_no, ', ') WITHIN GROUP (ORDER BY s.row_label, s.seat_no)
                  FROM showtime_seat ss JOIN seat s ON s.seat_id = ss.seat_id WHERE ss.booking_id = b.booking_id)
             ) AS seats,
             NVL(b.final_amount, 0) AS final_amount,
             b.showtime_id, b.subtotal, b.discount_amount,
             TO_CHAR(b.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS exp
        FROM booking b
        JOIN showtime st ON st.showtime_id = b.showtime_id
        JOIN movie m ON m.movie_id = st.movie_id
        JOIN room r ON r.room_id = st.room_id
       WHERE b.customer_id = :customer_id
       ORDER BY b.booking_id DESC
    ]'
  );

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'booking/:id');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'booking/:id', p_method => 'GET',
    p_source_type => 'json/item',
    p_source      => q'~
      SELECT b.booking_id,
             TO_CHAR(b.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS expires_at,
             b.showtime_id,
             '[' || (SELECT LISTAGG(ss.seat_id, ',') WITHIN GROUP (ORDER BY ss.seat_id)
                       FROM showtime_seat ss WHERE ss.booking_id = b.booking_id) || ']' AS "seat_ids{}"
        FROM booking b
       WHERE b.booking_id = :id AND b.customer_id = :customer_id AND b.status = 'PENDING' AND b.expires_at > SYSTIMESTAMP
    ~'
  );

  -- 4. COMBO & KHUYẾN MÃI
  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'combos');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'combos', p_method => 'GET', p_source_type => 'json/collection', p_source => 'SELECT combo_id, name, description AS "desc", price FROM combo WHERE is_active = 1 ORDER BY combo_id');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'combos', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      BEGIN
        INSERT INTO combo(name, description, price) VALUES (:name, :desc, :price);
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'combos', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'combos/:id');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'combos/:id', p_method => 'DELETE', p_source_type => 'plsql/block', p_source => 'BEGIN UPDATE combo SET is_active = 0 WHERE combo_id = :id; COMMIT; END;');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'promos');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'promos', p_method => 'GET',
    p_source_type => 'json/collection',
    p_source      => q'[
      SELECT code, discount_type AS type, discount_value AS value, max_discount AS max, min_amount AS min,
             max_uses AS "maxUses", used_count AS used,
             CASE WHEN conditions IS NOT NULL THEN JSON_QUERY(conditions, '$.days') ELSE 'null' END AS "days{}",
             CASE WHEN is_active = 1 THEN 'true' ELSE 'false' END AS "active{}"
        FROM promotion ORDER BY code
    ]'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'promos', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE
        v_obj JSON_OBJECT_T := JSON_OBJECT_T.parse(:body_text);
        v_code VARCHAR2(30) := UPPER(TRIM(v_obj.get_String('code')));
        v_cnt NUMBER; v_days JSON_ARRAY_T; v_cond VARCHAR2(500) := NULL;
      BEGIN
        SELECT COUNT(*) INTO v_cnt FROM promotion WHERE code = v_code;
        IF v_cnt > 0 THEN RAISE_APPLICATION_ERROR(-20070, 'Mã khuyến mãi đã tồn tại'); END IF;
        IF v_obj.has('days') AND NOT v_obj.get('days').is_null THEN
          v_days := v_obj.get_Array('days');
          IF v_days.get_size > 0 THEN v_cond := '{"days":' || v_days.to_string() || '}'; END IF;
        END IF;
        INSERT INTO promotion(code, discount_type, discount_value, max_discount, min_amount, valid_from, valid_to, max_uses, used_count, is_active, conditions)
        VALUES (
          v_code, v_obj.get_String('type'), TO_NUMBER(v_obj.get_String('value')),
          CASE WHEN v_obj.has('max') AND NOT v_obj.get('max').is_null THEN TO_NUMBER(v_obj.get_String('max')) ELSE NULL END,
          CASE WHEN v_obj.has('min') AND NOT v_obj.get('min').is_null THEN TO_NUMBER(v_obj.get_String('min')) ELSE 0 END,
          DATE '2026-01-01', DATE '2026-12-31',
          CASE WHEN v_obj.has('maxUses') AND NOT v_obj.get('maxUses').is_null THEN TO_NUMBER(v_obj.get_String('maxUses')) ELSE NULL END,
          0, 1, CASE WHEN v_cond IS NOT NULL THEN JSON(v_cond) ELSE NULL END
        );
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'promos', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'promos/:code/toggle');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'promos/:code/toggle', p_method => 'POST', p_source_type => 'plsql/block', p_source => 'BEGIN UPDATE promotion SET is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END WHERE code = UPPER(:code); COMMIT; END;');

  -- 5. TÀI KHOẢN, HỒ SƠ & MẬT KHẨU
  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'register');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'register', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE v_id NUMBER; v_cnt NUMBER;
      BEGIN
        IF fn_is_strong_password(:p_password) = 0 THEN RAISE_APPLICATION_ERROR(-20060, 'Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số'); END IF;
        SELECT COUNT(*) INTO v_cnt FROM customer WHERE LOWER(email) = LOWER(TRIM(:p_email));
        IF v_cnt > 0 THEN RAISE_APPLICATION_ERROR(-20061, 'Email đã được đăng ký'); END IF;
        INSERT INTO customer(full_name, email, password_hash, role) VALUES (TRIM(:p_full_name), LOWER(TRIM(:p_email)), STANDARD_HASH(:p_password, 'SHA256'), 'CUSTOMER') RETURNING customer_id INTO v_id;
        COMMIT;
        :customer_id := v_id;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'register', p_method => 'POST', p_name => 'customer_id', p_bind_variable_name => 'customer_id', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'register', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'login');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'login', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      BEGIN
        SELECT customer_id, full_name, role INTO :customer_id, :full_name, :role
          FROM customer WHERE LOWER(email) = LOWER(TRIM(:p_email)) AND password_hash = STANDARD_HASH(:p_password, 'SHA256');
      EXCEPTION
        WHEN NO_DATA_FOUND THEN :status_code := 401; :error := 'ORA-20062: Email hoặc mật khẩu không đúng';
        WHEN OTHERS THEN :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'login', p_method => 'POST', p_name => 'customer_id', p_bind_variable_name => 'customer_id', p_source_type => 'RESPONSE', p_param_type => 'INT', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'login', p_method => 'POST', p_name => 'full_name', p_bind_variable_name => 'full_name', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'login', p_method => 'POST', p_name => 'role', p_bind_variable_name => 'role', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'login', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'profile');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'profile', p_method => 'GET',
    p_source_type => 'json/item',
    p_source      => q'[
      SELECT customer_id, full_name, email, NVL(phone, '') AS phone,
             NVL(TO_CHAR(birth_date, 'YYYY-MM-DD'), '') AS birth,
             NVL(gender, '') AS gender, NVL(address, '') AS address
        FROM customer WHERE customer_id = :customer_id
    ]'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'profile', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'{
      BEGIN
        IF :p_phone IS NOT NULL AND NOT REGEXP_LIKE(REPLACE(:p_phone, ' ', ''), '^(0|\+84)\d{9,10}$') THEN RAISE_APPLICATION_ERROR(-20065, 'Số điện thoại không hợp lệ'); END IF;
        IF :p_birth_date IS NOT NULL AND TO_DATE(:p_birth_date, 'YYYY-MM-DD') > TRUNC(SYSDATE) THEN RAISE_APPLICATION_ERROR(-20066, 'Ngày sinh không hợp lệ'); END IF;
        UPDATE customer
           SET full_name = :p_full_name, phone = :p_phone,
               birth_date = CASE WHEN :p_birth_date IS NOT NULL THEN TO_DATE(:p_birth_date, 'YYYY-MM-DD') ELSE NULL END,
               gender = :p_gender, address = :p_address
         WHERE customer_id = :p_customer_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    }'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'profile', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'password');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'password', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE v_cnt NUMBER;
      BEGIN
        SELECT COUNT(*) INTO v_cnt FROM customer WHERE customer_id = :p_customer_id AND password_hash = STANDARD_HASH(:p_old, 'SHA256');
        IF v_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20062, 'Mật khẩu hiện tại không đúng'); END IF;
        IF fn_is_strong_password(:p_new) = 0 THEN RAISE_APPLICATION_ERROR(-20060, 'Mật khẩu mới phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số'); END IF;
        UPDATE customer SET password_hash = STANDARD_HASH(:p_new, 'SHA256') WHERE customer_id = :p_customer_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'password', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'forgot');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'forgot', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE v_otp VARCHAR2(10) := TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(100000, 999999)));
      BEGIN
        UPDATE customer SET otp_code = v_otp, otp_expires_at = SYSTIMESTAMP + INTERVAL '10' MINUTE WHERE LOWER(email) = LOWER(TRIM(:p_email));
        IF SQL%ROWCOUNT = 0 THEN RAISE_APPLICATION_ERROR(-20063, 'Email chưa được đăng ký'); END IF;
        COMMIT;
        :otp := v_otp;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'forgot', p_method => 'POST', p_name => 'otp', p_bind_variable_name => 'otp', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'forgot', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'reset');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'reset', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      DECLARE v_cnt NUMBER;
      BEGIN
        SELECT COUNT(*) INTO v_cnt FROM customer WHERE LOWER(email) = LOWER(TRIM(:p_email)) AND otp_code = :p_otp AND otp_expires_at >= SYSTIMESTAMP;
        IF v_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20064, 'Mã OTP không đúng hoặc đã hết hạn'); END IF;
        IF fn_is_strong_password(:p_new) = 0 THEN RAISE_APPLICATION_ERROR(-20060, 'Mật khẩu mới phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số'); END IF;
        UPDATE customer SET password_hash = STANDARD_HASH(:p_new, 'SHA256'), otp_code = NULL, otp_expires_at = NULL WHERE LOWER(email) = LOWER(TRIM(:p_email));
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'reset', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  -- 6. ĐÁNH GIÁ & QUẢN TRỊ
  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'reviews');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'reviews', p_method => 'GET',
    p_source_type => 'json/collection',
    p_source      => q'[
      SELECT r.review_id, r.movie_id, r.customer_id, c.full_name AS name, r.rating, r.content AS text,
             TO_CHAR(r.created_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS at
        FROM review r JOIN customer c ON c.customer_id = r.customer_id
       WHERE r.movie_id = :movie_id ORDER BY r.created_at DESC
    ]'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'reviews', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source      => q'[
      BEGIN
        IF :p_rating NOT BETWEEN 1 AND 5 THEN RAISE_APPLICATION_ERROR(-20080, 'Điểm đánh giá từ 1 đến 5'); END IF;
        MERGE INTO review r USING (SELECT :p_movie_id AS movie_id, :p_customer_id AS customer_id FROM dual) src
           ON (r.movie_id = src.movie_id AND r.customer_id = src.customer_id)
        WHEN MATCHED THEN UPDATE SET r.rating = :p_rating, r.content = :p_content, r.created_at = SYSTIMESTAMP
        WHEN NOT MATCHED THEN INSERT (movie_id, customer_id, rating, content) VALUES (:p_movie_id, :p_customer_id, :p_rating, :p_content);
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN ROLLBACK; :status_code := 400; :error := SQLERRM;
      END;
    ]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'cinema_api', p_pattern => 'reviews', p_method => 'POST', p_name => 'error', p_bind_variable_name => 'error', p_source_type => 'RESPONSE', p_param_type => 'STRING', p_access_method => 'OUT');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'revenue');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'cinema_api', p_pattern => 'revenue', p_method => 'GET',
    p_source_type => 'json/collection',
    p_source      => q'[
      SELECT m.title, TO_CHAR(TRUNC(st.start_time), 'YYYY-MM-DD') AS show_date,
             COUNT(tk.ticket_id) AS tickets_sold, NVL(SUM(tk.price), 0) AS gross_revenue
        FROM ticket tk
        JOIN booking b ON b.booking_id = tk.booking_id AND b.status = 'PAID'
        JOIN showtime st ON st.showtime_id = b.showtime_id
        JOIN movie m ON m.movie_id = st.movie_id
       GROUP BY m.title, TRUNC(st.start_time)
       ORDER BY TRUNC(st.start_time) DESC, gross_revenue DESC
    ]'
  );

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'audit');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'audit', p_method => 'GET', p_source_type => 'json/collection', p_source => 'SELECT log_id, table_name, record_id, action, old_value, new_value, TO_CHAR(changed_at, ''YYYY-MM-DD"T"HH24:MI:SS'') AS changed_at FROM audit_log ORDER BY log_id DESC');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'customers');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'customers', p_method => 'GET', p_source_type => 'json/collection', p_source => 'SELECT customer_id, full_name, email, phone, role FROM customer ORDER BY customer_id');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'cinema_api', p_pattern => 'role');
  ORDS.DEFINE_HANDLER(p_module_name => 'cinema_api', p_pattern => 'role', p_method => 'POST', p_source_type => 'plsql/block', p_source => 'BEGIN UPDATE customer SET role = :p_role WHERE customer_id = :p_customer_id; COMMIT; END;');

  -- CẤP QUYỀN CORS LUÔN TẠI ĐÂY
  ORDS.SET_MODULE_ORIGINS_ALLOWED(
    p_module_name     => 'cinema_api',
    p_origins_allowed => 'http://127.0.0.1:5500,http://localhost:5500'
  );

  COMMIT;
END;