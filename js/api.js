// ===== Cấu hình gọi Oracle REST Data Services (Oracle 23ai) =====
const CONFIG = { BASE: "http://localhost:8080/ords/cinema" };

const raise = (code, msg) => {
  const e = new Error(msg);
  e.code = code;
  throw e;
};

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

const API = {
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
  confirm: (b, p, m) =>
    ords("/confirm", "POST", {
      p_booking_id: +b,
      p_promo_code: p || null,
      p_method: m,
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
  promos: () => ords("/promos").then((j) => j.items || []),
  savePromo: (p) =>
    ords("/promos", "POST", {
      code: p.code,
      type: p.type,
      value: String(p.value),
      max: p.max ? String(p.max) : null,
      min: p.min ? String(p.min) : "0",
      max_uses: p.maxUses ? String(p.maxUses) : null,
      days: p.days && p.days.length ? JSON.stringify(p.days) : null,
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
