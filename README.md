# CineDB – Website đặt vé xem phim (Đề tài 6, Oracle 23ai)

## Chạy bằng VS Code
File > Open Folder > `cinema-booking`, cài extension **Live Server**, chuột phải `index.html` > Open with Live Server.

## Tài khoản
- Khách hàng: tự đăng ký (mật khẩu như `MatKhau123`).
- Quản trị viên (demo): `admin@cinedb.vn` / `Admin123`. Liên kết Quản trị chỉ hiện với vai trò này.
- Mã khuyến mãi: `WELCOME10`, `GIAM50K` (đơn từ 200.000đ), `THU3` (suất thứ Ba).

## Các trang
`index` | `phim` (tìm kiếm, lọc thể loại) | `chi-tiet?id=` (lịch chiếu theo rạp, ngày) | `rap` (3 rạp, 3 thành phố) | `dat-ve?st=` (chọn ghế, combo, khuyến mãi, thanh toán) | `ve` (in vé, hoàn vé) | `ve-cua-toi` | `dang-nhap` | `thanh-vien` (đăng ký, hồ sơ, đổi mật khẩu) | `uu-dai` | `tin-tuc` | `quan-tri` (doanh thu, phim, suất chiếu, khuyến mãi, combo, khách hàng)

## Chế độ (`CONFIG.MODE` trong `js/api.js`)
- `mock`: chạy độc lập, lưu localStorage, mô phỏng logic PL/SQL.
- `ords`: gọi `/cinema/...`. Ngoài các endpoint ở mục 3.9 báo cáo, cần thêm: `/login`, `/mybookings`, `/showtimes` (tất cả suất), `/addshowtime`, `/showtimes/:id/cancel`, `/rooms`, `/theaters`, `/combos`, `/promos`, `/movies` (POST, DELETE), `/customers`, `/profile`, `/password`, `/audit`.
- `database/mo-rong.sql`: các bảng và cột bổ sung (city, role, status phim, combo, booking_combo).

## Bổ sung ở bản mới
Giao diện hiện đại (sáng/tối theo hệ thống, dùng được trên điện thoại), tìm kiếm trên thanh menu, đánh giá phim bằng sao, thanh toán tiếp đơn đang chờ, xem lại vé đã mua, cấp hoặc thu hồi quyền quản trị, thống kê và xuất CSV doanh thu.
Endpoint ORDS thêm: `/booking/:id?customer_id=`, `/reviews`, `/role`. Bảng `review` nằm trong `database/mo-rong.sql`.

Thêm: mã QR trên vé (thư viện qrcodejs tải từ cdnjs, cần mạng), quên mật khẩu bằng OTP (`quen-mat-khau.html`; ở chế độ mock mã OTP hiện ngay trên trang, ở chế độ ords cần endpoint `/forgot` và `/reset`), sửa phim trong tab Phim của quản trị.
