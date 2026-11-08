-- Mở rộng thiết kế CSDL cho các chức năng bổ sung của website (chạy sau script gốc của báo cáo)
ALTER TABLE theater ADD (city VARCHAR2(60));                      -- nhiều rạp theo thành phố
ALTER TABLE customer ADD (role VARCHAR2(10) DEFAULT 'CUSTOMER' NOT NULL
  CHECK (role IN ('CUSTOMER','ADMIN')));                          -- phân quyền quản trị
ALTER TABLE movie ADD (status VARCHAR2(5) DEFAULT 'NOW' NOT NULL
  CHECK (status IN ('NOW','SOON')));                              -- phim đang chiếu / sắp chiếu

CREATE TABLE combo (                                              -- combo bắp nước
  combo_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR2(100) NOT NULL,
  description VARCHAR2(300),
  price       NUMBER(10) NOT NULL CHECK (price >= 0),
  is_active   NUMBER(1) DEFAULT 1 NOT NULL
);
CREATE TABLE booking_combo (                                      -- combo trong từng đơn, giá lưu tại thời điểm bán
  booking_id NUMBER NOT NULL REFERENCES booking(booking_id),
  combo_id   NUMBER NOT NULL REFERENCES combo(combo_id),
  qty        NUMBER(2) NOT NULL CHECK (qty BETWEEN 1 AND 10),
  unit_price NUMBER(10) NOT NULL,
  CONSTRAINT pk_booking_combo PRIMARY KEY (booking_id, combo_id)
);
ALTER TABLE booking ADD (combo_amount NUMBER(10) DEFAULT 0 NOT NULL);
-- Lưu ý: sp_confirm_booking cần nhận danh sách combo, ghi booking_combo và
-- final_amount = subtotal - discount_amount + combo_amount (khuyến mãi chỉ tính trên tiền vé).

CREATE TABLE review (                                             -- đánh giá phim (mỗi khách một đánh giá cho mỗi phim)
  review_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  movie_id    NUMBER NOT NULL REFERENCES movie(movie_id),
  customer_id NUMBER NOT NULL REFERENCES customer(customer_id),
  rating      NUMBER(1) NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content     VARCHAR2(1000),
  created_at  TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT uq_review UNIQUE (movie_id, customer_id)
);

-- Hồ sơ cá nhân (bỏ qua các cột đã có sẵn trong bảng customer)
ALTER TABLE customer ADD (phone VARCHAR2(15), birth_date DATE, gender VARCHAR2(10), address VARCHAR2(200));
