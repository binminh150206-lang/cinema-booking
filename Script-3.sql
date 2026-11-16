-- 1. Sửa lại hàm FN_CALC_DISCOUNT (đưa JSON_SERIALIZE vào câu SELECT SQL)
CREATE OR REPLACE FUNCTION fn_calc_discount(
  p_promo_code  IN VARCHAR2,
  p_subtotal    IN NUMBER,
  p_showtime_id IN NUMBER
) RETURN NUMBER IS
  v_type       promotion.discount_type%TYPE;
  v_val        promotion.discount_value%TYPE;
  v_max        promotion.max_discount%TYPE;
  v_min        promotion.min_amount%TYPE;
  v_from       promotion.valid_from%TYPE;
  v_to         promotion.valid_to%TYPE;
  v_max_uses   promotion.max_uses%TYPE;
  v_used       promotion.used_count%TYPE;
  v_active     promotion.is_active%TYPE;
  v_cond_txt   VARCHAR2(4000);
  v_start_time showtime.start_time%TYPE;
  v_show_day   VARCHAR2(10);
  v_obj        JSON_OBJECT_T;
  v_arr        JSON_ARRAY_T;
  v_day_ok     BOOLEAN;
  v_disc       NUMBER := 0;
BEGIN
  IF p_promo_code IS NULL OR TRIM(p_promo_code) = '' THEN
    RETURN 0;
  END IF;

  BEGIN
    SELECT discount_type, discount_value, max_discount, NVL(min_amount, 0),
           valid_from, valid_to, max_uses, used_count, is_active,
           JSON_SERIALIZE(conditions RETURNING VARCHAR2(4000))
      INTO v_type, v_val, v_max, v_min,
           v_from, v_to, v_max_uses, v_used, v_active, v_cond_txt
      FROM promotion
     WHERE code = UPPER(TRIM(p_promo_code));
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20034, 'Mã khuyến mãi không tồn tại');
  END;

  IF v_active <> 1 OR TRUNC(SYSDATE) NOT BETWEEN v_from AND v_to THEN
    RAISE_APPLICATION_ERROR(-20034, 'Mã khuyến mãi không tồn tại hoặc đã hết hạn');
  END IF;

  IF v_max_uses IS NOT NULL AND v_used >= v_max_uses THEN
    RAISE_APPLICATION_ERROR(-20031, 'Mã khuyến mãi đã hết lượt dùng');
  END IF;

  IF p_subtotal < v_min THEN
    RAISE_APPLICATION_ERROR(-20032, 'Chưa đạt giá trị đơn tối thiểu');
  END IF;

  IF v_cond_txt IS NOT NULL THEN
    v_obj := JSON_OBJECT_T.parse(v_cond_txt);
    IF v_obj.has('days') AND NOT v_obj.get('days').is_null THEN
      v_arr := v_obj.get_Array('days');
      IF v_arr.get_size > 0 THEN
        SELECT start_time INTO v_start_time
          FROM showtime WHERE showtime_id = p_showtime_id;
        v_show_day := TO_CHAR(v_start_time, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN');
        v_day_ok := FALSE;
        FOR i IN 0 .. v_arr.get_size - 1 LOOP
          IF UPPER(v_arr.get_String(i)) = v_show_day THEN
            v_day_ok := TRUE;
            EXIT;
          END IF;
        END LOOP;
        IF NOT v_day_ok THEN
          RAISE_APPLICATION_ERROR(-20033, 'Mã không áp dụng cho ngày chiếu này');
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_type = 'PERCENT' THEN
    v_disc := p_subtotal * v_val / 100;
  ELSE
    v_disc := v_val;
  END IF;

  IF v_max IS NOT NULL THEN
    v_disc := LEAST(v_disc, v_max);
  END IF;

  RETURN LEAST(ROUND(v_disc, -3), p_subtotal);
END fn_calc_discount;
/

-- 2. Tạo lại hàm MLE FN_IS_STRONG_PASSWORD
CREATE OR REPLACE FUNCTION fn_is_strong_password(p_password VARCHAR2)
RETURN NUMBER
AS MLE MODULE mod_password_check
SIGNATURE 'isStrongPassword(string)';
/

-- 3. Biên dịch lại 2 đối tượng phụ thuộc
ALTER PROCEDURE sp_register_customer COMPILE;
ALTER PACKAGE pkg_booking COMPILE BODY;
SELECT object_name, object_type, status FROM user_objects WHERE status <> 'VALID';
-- 1. Đặt chuột vào đây và bấm Ctrl + Enter
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE OR REPLACE FUNCTION fn_is_strong_password(p_password VARCHAR2)
    RETURN NUMBER
    AS MLE MODULE mod_password_check
    SIGNATURE 'isStrongPassword(string)';
  ]';
END;
-- 2. Đặt chuột vào dòng này và bấm Ctrl + Enter
ALTER PROCEDURE sp_register_customer COMPILE;