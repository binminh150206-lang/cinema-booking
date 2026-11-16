// ===== Cấu hình: 'ords' gọi Oracle REST Data Services thật, 'mock' chạy giả lập trong trình duyệt =====
const CONFIG = { MODE: "ords", BASE: "http://localhost:8080/ords/cinema" };
const HOLD_MS = 10 * 60 * 1000;
const raise = (code, msg) => {
  const e = new Error(msg);
  e.code = code;
  throw e;
};

// ---------- Chế độ ORDS: gọi REST API từ Oracle 23ai ----------
async function ords(path, method = "GET", body) {
  const r = await fetch(CONFIG.BASE + path, {
    method,
    headers: body !== undefined ? { "Content-Type": "application/json" } : {},
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  let j = {};
  try {
    j = await r.json();
  } catch (_) {}
  if (!r.ok) {
    const raw = [j.cause, j.detail, j.message, j.error]
      .filter(Boolean)
      .join("\n");
    const m = /ORA-(\d+):?\s*([^\n]*)/.exec(raw);
    raise(
      m ? -Number(m[1]) : r.status,
      m ? m[2].trim() : j.message || "Lỗi kết nối " + r.status,
    );
  }
  return j;
}

const ordsApi = {
  movies: () =>
    ords("/movies").then((j) =>
      (j.items || []).map((m) => ({
        status: "NOW",
        ...m,
        metadata:
          typeof m.metadata === "string"
            ? JSON.parse(m.metadata)
            : m.metadata || {},
      })),
    ),
  showtimes: (id) =>
    ords("/showtimes?movie_id=" + id).then((j) => j.items || []),
  showtime: (id) => ords("/showtimes/" + id),
  seatmap: (id) => ords("/seatmap/" + id).then((j) => j.items || []),
  hold: (c, s, ids) =>
    ords("/hold", "POST", {
      p_customer_id: +c,
      p_showtime_id: +s,
      p_seat_ids: JSON.stringify(ids),
    }),
  confirm: (b, p, m, c) =>
    ords("/confirm", "POST", {
      p_booking_id: +b,
      p_promo_code: p || null,
      p_method: m,
      p_combos: JSON.stringify(c || {}),
    }),
  cancel: (b, c) =>
    ords("/cancel", "POST", { p_booking_id: +b, p_customer_id: +c }),
  register: (n, e, p) =>
    ords("/register", "POST", { p_full_name: n, p_email: e, p_password: p }),
  revenue: () => ords("/revenue").then((j) => j.items || []),
  audit: () =>
    ords("/audit")
      .then((j) => j.items || [])
      .catch(() => []),
  login: (e, p) => ords("/login", "POST", { p_email: e, p_password: p }),
  myBookings: (c) =>
    ords("/mybookings?customer_id=" + c).then((j) => j.items || []),
  allShowtimes: () => ords("/showtimes").then((j) => j.items || []),
  addShowtime: (m, r, t, p) =>
    ords("/addshowtime", "POST", {
      p_movie_id: +m,
      p_room_id: +r,
      p_start: new Date(t).toISOString(),
      p_base_price: +p,
    }),
  rooms: () => ords("/rooms").then((j) => j.items || []),
  theaters: () => ords("/theaters").then((j) => j.items || []),
  requestReset: (e) => ords("/forgot", "POST", { p_email: e }),
  resetPassword: (e, o, n) =>
    ords("/reset", "POST", { p_email: e, p_otp: o, p_new: n }),
  resume: (b, c) => ords("/booking/" + b + "?customer_id=" + c),
  setRole: (c, r) => ords("/role", "POST", { p_customer_id: +c, p_role: r }),
  reviews: (id) => ords("/reviews?movie_id=" + id).then((j) => j.items || []),
  addReview: (c, m, r, t) =>
    ords("/reviews", "POST", {
      p_customer_id: +c,
      p_movie_id: +m,
      p_rating: +r,
      p_content: t,
    }),
  combos: () => ords("/combos").then((j) => j.items || []),
  saveCombo: (c) =>
    ords("/combos", "POST", { name: c.name, desc: c.desc, price: +c.price }),
  deleteCombo: (id) => ords("/combos/" + id, "DELETE"),
  promos: () => ords("/promos").then((j) => j.items || []),
  savePromo: (p) =>
    ords("/promos", "POST", {
      code: p.code,
      type: p.type,
      value: String(p.value),
      max: p.max ? String(p.max) : null,
      min: p.min ? String(p.min) : "0",
      maxUses: p.maxUses ? String(p.maxUses) : null,
      days: p.days || [],
    }),
  togglePromo: (c) => ords("/promos/" + c + "/toggle", "POST"),
  saveMovie: (m) =>
    ords("/movies", "POST", {
      movie_id: m.movie_id ? +m.movie_id : null,
      title: m.title,
      genre: m.genre,
      duration_min: +m.duration_min,
      rating: m.rating,
      status: m.status || "NOW",
      metadata: m.metadata || null,
    }),
  deleteMovie: (id) => ords("/movies/" + id, "DELETE"),
  cancelShowtime: (id) => ords("/showtimes/" + id + "/cancel", "POST"),
  customers: () => ords("/customers").then((j) => j.items || []),
  getProfile: (c) => ords("/profile?customer_id=" + c),
  updateProfile: (c, d) =>
    ords("/profile", "POST", {
      p_customer_id: +c,
      p_full_name: d.full_name,
      p_phone: d.phone || null,
      p_birth_date: d.birth || null,
      p_gender: d.gender || null,
      p_address: d.address || null,
    }),
  changePassword: (c, o, n) =>
    ords("/password", "POST", { p_customer_id: +c, p_old: o, p_new: n }),
  release: async () => {},
  reset: () => {
    localStorage.removeItem("cinema_user");
  },
};

// ---------- Chế độ MOCK: mô phỏng lại logic PL/SQL khi không bật Docker ----------
const KEY = "cinema_db_v6";
const hash = (t) => {
  let h = 0;
  for (const c of t) h = (h * 31 + c.charCodeAt(0)) | 0;
  return String(h);
};
function seed() {
  const day = (d, h) => {
    const x = new Date();
    x.setDate(x.getDate() + d);
    x.setHours(h, 0, 0, 0);
    return x.getTime();
  };
  const movies = [
    {
      movie_id: 1,
      title: "Hành Tinh Cuối Cùng",
      genre: "Khoa học viễn tưởng",
      duration_min: 128,
      rating: "T13",
      metadata: {
        director: "A. Nguyễn",
        cast: ["L. Trần", "M. Phạm"],
        language: "Phụ đề Việt",
      },
    },
    {
      movie_id: 2,
      title: "Mùa Hè Của Mèo",
      genre: "Hoạt hình",
      duration_min: 96,
      rating: "P",
      metadata: { director: "K. Lê", cast: [], language: "Lồng tiếng Việt" },
    },
    {
      movie_id: 3,
      title: "Đêm Không Ngủ",
      genre: "Kinh dị",
      duration_min: 110,
      rating: "T18",
      metadata: {
        director: "H. Võ",
        cast: ["T. Đặng"],
        language: "Tiếng Việt",
      },
    },
    {
      movie_id: 4,
      title: "Chuyến Tàu Hoàng Hôn",
      genre: "Tình cảm",
      duration_min: 118,
      rating: "T16",
      metadata: {
        director: "P. Hoàng",
        cast: ["N. Bùi", "D. Ngô"],
        language: "Tiếng Việt",
      },
    },
  ];
  movies.forEach((m) => (m.status = "NOW"));
  const soon = [
    {
      movie_id: 5,
      title: "Biệt Đội Sao Băng",
      genre: "Hành động",
      duration_min: 122,
      rating: "T13",
      status: "SOON",
      metadata: {
        director: "Q. Mai",
        cast: ["V. Lý"],
        language: "Phụ đề Việt",
      },
    },
    {
      movie_id: 6,
      title: "Ngôi Nhà Trên Mây",
      genre: "Hoạt hình",
      duration_min: 101,
      rating: "P",
      status: "SOON",
      metadata: { director: "S. Tạ", cast: [], language: "Lồng tiếng Việt" },
    },
  ];
  const theaters = [
    {
      theater_id: 1,
      name: "CineDB Landmark",
      city: "TP. Hồ Chí Minh",
      address: "Quận 1",
    },
    {
      theater_id: 2,
      name: "CineDB Bà Triệu",
      city: "Hà Nội",
      address: "Quận Hai Bà Trưng",
    },
    {
      theater_id: 3,
      name: "CineDB Sông Hàn",
      city: "Đà Nẵng",
      address: "Quận Hải Châu",
    },
    {
      theater_id: 4,
      name: "CineDB Thủ Đức",
      city: "TP. Hồ Chí Minh",
      address: "TP. Thủ Đức",
    },
    {
      theater_id: 5,
      name: "CineDB Ninh Kiều",
      city: "Cần Thơ",
      address: "Quận Ninh Kiều",
    },
    {
      theater_id: 6,
      name: "CineDB Lạch Tray",
      city: "Hải Phòng",
      address: "Quận Ngô Quyền",
    },
    {
      theater_id: 7,
      name: "CineDB Trần Phú",
      city: "Nha Trang",
      address: "Đường Trần Phú",
    },
  ];
  const rooms = [];
  theaters.forEach((t) =>
    ["2D", "3D"].forEach((ty, k) =>
      rooms.push({
        room_id: (t.theater_id - 1) * 2 + k + 1,
        theater_id: t.theater_id,
        theater_name: t.name,
        name: "Phòng " + (k + 1) + " (" + ty + ")",
      }),
    ),
  );
  const seats = [];
  "ABCDE".split("").forEach((r, i) => {
    for (let n = 1; n <= 8; n++)
      seats.push({
        seat_id: i * 8 + n,
        row_label: r,
        seat_no: n,
        seat_type: r === "E" ? "COUPLE" : r === "D" ? "VIP" : "STANDARD",
      });
  });
  const showtimes = [];
  let id = 1;
  theaters.forEach((t, ti) =>
    movies.forEach((m, i) =>
      [1, 2].forEach((d) =>
        [
          [9, 19],
          [14, 20],
        ][i % 2].forEach((h) => {
          const rid = ti * 2 + (i % 2) + 1;
          showtimes.push({
            showtime_id: id++,
            movie_id: m.movie_id,
            theater_id: t.theater_id,
            theater_name: t.name,
            room_id: rid,
            room_name: rooms.find((r) => r.room_id === rid).name,
            start_time: day(d, h),
            end_time: day(d, h) + (m.duration_min + 15) * 60000,
            base_price: i % 2 ? 100000 : 80000,
            status: "OPEN",
          });
        }),
      ),
    ),
  );
  movies.push(...soon);
  const promos = [
    {
      code: "WELCOME10",
      type: "PERCENT",
      value: 10,
      max: 30000,
      min: 0,
      maxUses: 100,
      used: 0,
      days: null,
    },
    {
      code: "GIAM50K",
      type: "FIXED",
      value: 50000,
      max: null,
      min: 200000,
      maxUses: 50,
      used: 0,
      days: null,
    },
    {
      code: "THU3",
      type: "PERCENT",
      value: 15,
      max: 40000,
      min: 0,
      maxUses: null,
      used: 0,
      days: ["TUE"],
    },
  ];
  return {
    theaters,
    rooms,
    movies,
    seats,
    showtimes,
    promos,
    combos: [
      {
        combo_id: 1,
        name: "Combo Bắp Nước",
        desc: "1 bắp lớn và 1 nước",
        price: 79000,
      },
      {
        combo_id: 2,
        name: "Combo Đôi",
        desc: "2 bắp và 2 nước",
        price: 129000,
      },
      { combo_id: 3, name: "Nước ngọt", desc: "Ly lớn", price: 29000 },
    ],
    customers: [
      {
        customer_id: 1,
        full_name: "Quản trị viên",
        email: "admin@cinedb.vn",
        pw: hash("Admin123"),
        role: "ADMIN",
      },
    ],
    reviews: [],
    bookings: [],
    audit: [],
    ss: {},
    nextBooking: 1,
  };
}
let db = JSON.parse(localStorage.getItem(KEY) || "null") || seed();
const save = () => localStorage.setItem(KEY, JSON.stringify(db));
const stOf = (id) =>
  db.showtimes.find((s) => s.showtime_id == id) ||
  raise(-20001, "Suất chiếu hoặc ghế không tồn tại");
const seatOf = (id) => db.seats.find((s) => s.seat_id == id);
const lab = (id) => seatOf(id).row_label + seatOf(id).seat_no;
const bookingOf = (id) =>
  db.bookings.find((b) => b.booking_id == id) ||
  raise(-20020, "Đơn không tồn tại");
const log = (b, o, n) =>
  db.audit.push({
    log_id: db.audit.length + 1,
    table_name: "BOOKING",
    record_id: b.booking_id,
    action: "STATUS_CHANGE",
    old_value: o,
    new_value: n,
    changed_at: Date.now(),
  });

function price(st, seat) {
  let p = st.base_price * ({ VIP: 1.25, COUPLE: 2 }[seat.seat_type] || 1);
  const d = new Date(st.start_time);
  if (d.getDay() === 0 || d.getDay() === 6) p *= 1.15;
  if (d.getHours() < 12) p *= 0.8;
  return Math.round(p / 1000) * 1000;
}
function discount(code, sub, st) {
  if (!code) return 0;
  const p = db.promos.find((x) => x.code === code.toUpperCase());
  if (!p || p.active === false) raise(-20034, "Mã khuyến mãi không tồn tại");
  if (p.maxUses != null && p.used >= p.maxUses)
    raise(-20031, "Mã khuyến mãi đã hết lượt dùng");
  if (sub < p.min) raise(-20032, "Chưa đạt giá trị đơn tối thiểu");
  if (
    p.days &&
    !p.days.includes(
      ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][
        new Date(st.start_time).getDay()
      ],
    )
  )
    raise(-20033, "Mã không áp dụng cho ngày chiếu này");
  let d = p.type === "PERCENT" ? (sub * p.value) / 100 : p.value;
  if (p.max != null) d = Math.min(d, p.max);
  return Math.min(Math.round(d / 1000) * 1000, sub);
}
function releaseExpired() {
  const n = Date.now();
  for (const k in db.ss)
    if (db.ss[k].status === "HELD" && db.ss[k].exp < n) delete db.ss[k];
  db.bookings.forEach((b) => {
    if (b.status === "PENDING" && b.exp < n) {
      log(b, "PENDING", "EXPIRED");
      b.status = "EXPIRED";
    }
  });
  save();
}
const freeSeats = (bid) => {
  for (const k in db.ss) if (db.ss[k].bookingId === bid) delete db.ss[k];
};
if (CONFIG.MODE === "mock") setInterval(releaseExpired, 60000);

const mockApi = {
  async movies() {
    return db.movies.map((m) => {
      const r = (db.reviews || []).filter((x) => x.movie_id === m.movie_id);
      return {
        ...m,
        review_count: r.length,
        avg_rating: r.length
          ? r.reduce((a, x) => a + x.rating, 0) / r.length
          : 0,
      };
    });
  },
  async showtime(id) {
    const s = stOf(id);
    return {
      ...s,
      title: db.movies.find((m) => m.movie_id === s.movie_id).title,
    };
  },
  async showtimes(mid) {
    return db.showtimes
      .filter(
        (s) =>
          s.movie_id == mid && s.start_time > Date.now() && s.status === "OPEN",
      )
      .map((s) => {
        const sold = Object.keys(db.ss).filter(
          (k) =>
            k.startsWith(s.showtime_id + "-") && db.ss[k].status === "SOLD",
        ).length;
        return { ...s, occupancy: Math.round((100 * sold) / db.seats.length) };
      });
  },
  async seatmap(id) {
    const st = stOf(id);
    return db.seats.map((s) => {
      const v = db.ss[id + "-" + s.seat_id];
      const status =
        !v || (v.status === "HELD" && v.exp < Date.now())
          ? "AVAILABLE"
          : v.status;
      return { ...s, status, price: price(st, s) };
    });
  },
  async hold(cid, stId, ids) {
    const st = stOf(stId);
    if (st.status !== "OPEN" || st.start_time <= Date.now())
      raise(-20012, "Suất chiếu đã đóng bán");
    if (!ids || ids.length < 1 || ids.length > 8)
      raise(-20010, "Mỗi đơn đặt từ 1 đến 8 ghế");
    const snap = JSON.stringify(db.ss),
      exp = Date.now() + HOLD_MS,
      bid = db.nextBooking;
    for (const sid of [...ids].sort((a, b) => a - b)) {
      const v = db.ss[stId + "-" + sid];
      if (!v || (v.status === "HELD" && v.exp < Date.now()))
        db.ss[stId + "-" + sid] = {
          status: "HELD",
          heldBy: cid,
          exp,
          bookingId: bid,
        };
      else {
        db.ss = JSON.parse(snap);
        raise(-20011, "Ghế " + lab(sid) + " đã có người giữ hoặc đã bán");
      }
    }
    db.bookings.push({
      booking_id: bid,
      customer_id: cid,
      showtime_id: stId,
      status: "PENDING",
      exp,
      tickets: [],
    });
    db.nextBooking++;
    save();
    return { booking_id: bid, expires_at: exp };
  },
  async confirm(bid, code, method, cmb = {}) {
    const b = bookingOf(bid),
      n = Date.now();
    if (b.status !== "PENDING" || b.exp < n)
      raise(-20020, "Đơn không còn hiệu lực");
    const mine = Object.entries(db.ss).filter(([, v]) => v.bookingId === bid);
    if (!mine.length || mine.some(([, v]) => v.status !== "HELD" || v.exp < n))
      raise(-20021, "Có ghế đã hết hạn giữ chỗ");
    const st = stOf(b.showtime_id);
    const tickets = mine.map(([k]) => {
      const s = seatOf(+k.split("-")[1]);
      return {
        seat_id: s.seat_id,
        seat_label: s.row_label + s.seat_no,
        price: price(st, s),
      };
    });
    const sub = tickets.reduce((a, t) => a + t.price, 0),
      disc = discount(code, sub, st);
    const cl = db.combos
        .filter((c) => cmb[c.combo_id] > 0)
        .map((c) => ({ name: c.name, qty: cmb[c.combo_id], price: c.price })),
      ct = cl.reduce((a, c) => a + c.qty * c.price, 0);
    if (disc > 0) db.promos.find((p) => p.code === code.toUpperCase()).used++;
    mine.forEach(([k]) => {
      db.ss[k] = { status: "SOLD", bookingId: bid };
    });
    log(b, "PENDING", "PAID");
    Object.assign(b, {
      status: "PAID",
      tickets,
      subtotal: sub,
      discount_amount: disc,
      final_amount: sub - disc + ct,
      combos: cl,
      promo: disc > 0 ? code.toUpperCase() : null,
      method,
    });
    save();
    return {
      booking_id: bid,
      subtotal: sub,
      discount_amount: disc,
      final_amount: sub - disc + ct,
      combos: cl,
      tickets,
    };
  },
  async cancel(bid, cid) {
    const b = bookingOf(bid);
    if (b.customer_id !== cid) raise(-20040, "Không có quyền huỷ đơn này");
    if (!["PENDING", "PAID"].includes(b.status))
      raise(-20041, "Đơn không thể huỷ ở trạng thái hiện tại");
    if (b.status === "PAID") {
      if (stOf(b.showtime_id).start_time < Date.now() + 2 * 3600e3)
        raise(-20042, "Chỉ huỷ vé đã thanh toán trước giờ chiếu ít nhất 2 giờ");
      if (b.promo) {
        const p = db.promos.find((x) => x.code === b.promo);
        p.used = Math.max(0, p.used - 1);
      }
      b.tickets = [];
    }
    freeSeats(bid);
    log(b, b.status, "CANCELLED");
    b.status = "CANCELLED";
    save();
  },
  async register(n, e, p) {
    if (
      !(p.length >= 8 && /[A-Z]/.test(p) && /[a-z]/.test(p) && /[0-9]/.test(p))
    )
      raise(
        -20060,
        "Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số",
      );
    if (db.customers.some((c) => c.email === e))
      raise(-20061, "Email đã được đăng ký");
    const c = {
      customer_id: db.customers.length + 1,
      full_name: n,
      email: e,
      pw: hash(p),
      role: "CUSTOMER",
    };
    db.customers.push(c);
    save();
    return { customer_id: c.customer_id };
  },
  async revenue() {
    const m = {};
    db.bookings
      .filter((b) => b.status === "PAID")
      .forEach((b) =>
        b.tickets.forEach((t) => {
          const st = stOf(b.showtime_id),
            mv = db.movies.find((x) => x.movie_id === st.movie_id),
            d = new Date(st.start_time).setHours(0, 0, 0, 0),
            k = mv.movie_id + "-" + d;
          m[k] = m[k] || {
            title: mv.title,
            show_date: d,
            tickets_sold: 0,
            gross_revenue: 0,
          };
          m[k].tickets_sold++;
          m[k].gross_revenue += t.price;
        }),
      );
    return Object.values(m);
  },
  async audit() {
    return db.audit;
  },
  async login(e, p) {
    const c = db.customers.find((x) => x.email === e && x.pw === hash(p));
    if (!c) raise(-20062, "Email hoặc mật khẩu không đúng");
    return { customer_id: c.customer_id, full_name: c.full_name, role: c.role };
  },
  async myBookings(cid) {
    releaseExpired();
    return db.bookings
      .filter((b) => b.customer_id === cid)
      .map((b) => {
        const st = stOf(b.showtime_id),
          cur = Object.entries(db.ss)
            .filter(([, v]) => v.bookingId === b.booking_id)
            .map(([k]) => lab(+k.split("-")[1]));
        return {
          booking_id: b.booking_id,
          status: b.status,
          title: db.movies.find((m) => m.movie_id === st.movie_id).title,
          start_time: st.start_time,
          room_name: st.room_name,
          seats: (cur.length
            ? cur
            : (b.tickets || []).map((t) => t.seat_label)
          ).join(", "),
          final_amount: b.final_amount || 0,
          showtime_id: b.showtime_id,
          subtotal: b.subtotal,
          discount_amount: b.discount_amount,
          combos: b.combos,
          tickets: b.tickets,
          exp: b.exp,
        };
      })
      .reverse();
  },
  async allShowtimes() {
    return db.showtimes.map((s) => {
      const sold = Object.keys(db.ss).filter(
        (k) => k.startsWith(s.showtime_id + "-") && db.ss[k].status === "SOLD",
      ).length;
      return {
        ...s,
        title: db.movies.find((m) => m.movie_id === s.movie_id).title,
        occupancy: Math.round((100 * sold) / db.seats.length),
      };
    });
  },
  async addShowtime(mid, rid, start, price) {
    const m = db.movies.find((x) => x.movie_id == mid),
      end = start + (m.duration_min + 15) * 60000;
    if (
      db.showtimes.some(
        (s) =>
          s.room_id == rid &&
          s.status !== "CANCELLED" &&
          s.start_time < end &&
          s.end_time > start,
      )
    )
      raise(-20050, "Phòng đã có suất chiếu trùng giờ");
    const id = Math.max(...db.showtimes.map((s) => s.showtime_id)) + 1;
    const R = db.rooms.find((r) => r.room_id == rid);
    db.showtimes.push({
      showtime_id: id,
      movie_id: +mid,
      room_id: +rid,
      theater_id: R.theater_id,
      theater_name: R.theater_name,
      room_name: R.name,
      start_time: start,
      end_time: end,
      base_price: +price,
      status: "OPEN",
    });
    save();
    return { showtime_id: id };
  },
  async rooms() {
    return db.rooms;
  },
  async resume(bid, cid) {
    const b = bookingOf(bid);
    if (b.customer_id !== cid) raise(-20040, "Không có quyền với đơn này");
    if (b.status !== "PENDING" || b.exp < Date.now())
      raise(-20020, "Đơn không còn hiệu lực");
    return {
      booking_id: bid,
      expires_at: b.exp,
      showtime_id: b.showtime_id,
      seat_ids: Object.entries(db.ss)
        .filter(([, v]) => v.bookingId === bid)
        .map(([k]) => +k.split("-")[1]),
    };
  },
  async setRole(cid, role) {
    db.customers.find((c) => c.customer_id === cid).role = role;
    save();
  },
  async reviews(mid) {
    return (db.reviews || [])
      .filter((r) => r.movie_id == mid)
      .sort((a, b) => b.at - a.at);
  },
  async addReview(cid, mid, rating, text) {
    if (!(rating >= 1 && rating <= 5))
      raise(-20080, "Điểm đánh giá từ 1 đến 5");
    const c = db.customers.find((x) => x.customer_id === cid);
    db.reviews = (db.reviews || []).filter(
      (r) => !(r.movie_id == mid && r.customer_id === cid),
    );
    db.reviews.push({
      review_id: Date.now(),
      movie_id: +mid,
      customer_id: cid,
      name: c.full_name,
      rating: +rating,
      text,
      at: Date.now(),
    });
    save();
  },
  async requestReset(e) {
    const c = db.customers.find((x) => x.email === e);
    if (!c) raise(-20063, "Email chưa được đăng ký");
    c.otp = String(Math.floor(100000 + Math.random() * 900000));
    c.otpExp = Date.now() + 10 * 60000;
    save();
    return { otp: c.otp };
  },
  async resetPassword(e, otp, np) {
    const c = db.customers.find((x) => x.email === e);
    if (!c || c.otp !== otp || c.otpExp < Date.now())
      raise(-20064, "Mã OTP không đúng hoặc đã hết hạn");
    if (
      !(
        np.length >= 8 &&
        /[A-Z]/.test(np) &&
        /[a-z]/.test(np) &&
        /[0-9]/.test(np)
      )
    )
      raise(
        -20060,
        "Mật khẩu mới phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số",
      );
    c.pw = hash(np);
    delete c.otp;
    save();
  },
  async theaters() {
    return db.theaters;
  },
  async combos() {
    return db.combos;
  },
  async saveCombo(c) {
    db.combos.push({
      combo_id: Math.max(0, ...db.combos.map((x) => x.combo_id)) + 1,
      name: c.name,
      desc: c.desc,
      price: +c.price,
    });
    save();
  },
  async deleteCombo(id) {
    db.combos = db.combos.filter((c) => c.combo_id != id);
    save();
  },
  async promos() {
    return db.promos;
  },
  async savePromo(p) {
    const code = p.code.toUpperCase();
    if (db.promos.some((x) => x.code === code))
      raise(-20070, "Mã khuyến mãi đã tồn tại");
    db.promos.push({
      code,
      type: p.type,
      value: +p.value,
      max: p.max ? +p.max : null,
      min: +p.min || 0,
      maxUses: p.maxUses ? +p.maxUses : null,
      used: 0,
      days: p.days.length ? p.days : null,
      active: true,
    });
    save();
  },
  async togglePromo(code) {
    const p = db.promos.find((x) => x.code === code);
    p.active = p.active === false;
    save();
  },
  async saveMovie(m) {
    if (m.movie_id)
      Object.assign(
        db.movies.find((x) => x.movie_id == m.movie_id),
        m,
      );
    else
      db.movies.push({
        ...m,
        movie_id: Math.max(...db.movies.map((x) => x.movie_id)) + 1,
      });
    save();
  },
  async deleteMovie(id) {
    if (db.showtimes.some((s) => s.movie_id == id))
      raise(-20052, "Phim đã có suất chiếu, hãy đổi trạng thái thay vì xoá");
    db.movies = db.movies.filter((m) => m.movie_id != id);
    save();
  },
  async cancelShowtime(id) {
    if (Object.keys(db.ss).some((k) => k.startsWith(id + "-")))
      raise(-20051, "Suất đã có người giữ hoặc mua vé, không thể huỷ");
    stOf(id).status = "CANCELLED";
    save();
  },
  async customers() {
    return db.customers;
  },
  async getProfile(cid) {
    const c = db.customers.find((x) => x.customer_id === cid);
    return {
      customer_id: c.customer_id,
      full_name: c.full_name,
      email: c.email,
      phone: c.phone || "",
      birth: c.birth || "",
      gender: c.gender || "",
      address: c.address || "",
    };
  },
  async updateProfile(cid, d) {
    if (d.phone && !/^(0|\+84)\d{9,10}$/.test(d.phone.replace(/\s/g, "")))
      raise(-20065, "Số điện thoại không hợp lệ");
    if (d.birth && new Date(d.birth) > new Date())
      raise(-20066, "Ngày sinh không hợp lệ");
    Object.assign(
      db.customers.find((x) => x.customer_id === cid),
      {
        full_name: d.full_name,
        phone: d.phone,
        birth: d.birth,
        gender: d.gender,
        address: d.address,
      },
    );
    save();
  },
  async changePassword(cid, oldp, newp) {
    const c = db.customers.find((x) => x.customer_id === cid);
    if (c.pw !== hash(oldp)) raise(-20062, "Mật khẩu hiện tại không đúng");
    if (
      !(
        newp.length >= 8 &&
        /[A-Z]/.test(newp) &&
        /[a-z]/.test(newp) &&
        /[0-9]/.test(newp)
      )
    )
      raise(
        -20060,
        "Mật khẩu mới phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số",
      );
    c.pw = hash(newp);
    save();
  },
  async release() {
    releaseExpired();
  },
  reset() {
    localStorage.removeItem(KEY);
    localStorage.removeItem("cinema_user");
  },
};
const API = CONFIG.MODE === "ords" ? ordsApi : mockApi;
