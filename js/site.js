const IMGBB_API_KEY = "848356f9c5214572f89c23e305b8cc8f";

const $ = (s) => document.querySelector(s),
  app = $("#app"),
  qs = new URLSearchParams(location.search);
const money = (n) => Number(n || 0).toLocaleString("vi-VN") + "đ";
const toDate = (t) =>
  new Date(typeof t === "number" ? t : /^\d+$/.test(String(t)) ? Number(t) : t);
const fDate = (t) =>
  toDate(t).toLocaleDateString("vi-VN", {
    weekday: "short",
    day: "2-digit",
    month: "2-digit",
  });
const fTime = (t) =>
  toDate(t).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
let user = JSON.parse(localStorage.getItem("cinema_user") || "null"),
  timer;
function toast(m, bad) {
  const t = $("#toast");
  t.textContent = m;
  t.className = "toast" + (bad ? " bad" : "");
  t.hidden = false;
  clearTimeout(toast.t);
  toast.t = setTimeout(() => (t.hidden = true), 3500);
}
const showErr = (e) => toast("Lỗi " + (e.code ?? "") + ": " + e.message, true);
const on = (s, f) => {
  const e = $(s);
  if (e) e.onclick = f;
};
const EYE =
  '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>';
const EYE_OFF =
  '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.9 17.9A10.9 10.9 0 0 1 12 19C5 19 1 12 1 12a18.5 18.5 0 0 1 5.1-5.9M9.9 4.2A9.1 9.1 0 0 1 12 5c7 0 11 7 11 7a18.5 18.5 0 0 1-2.2 3.2M1 1l22 22"/></svg>';
const pwField = (n, l) =>
  `<label class="f">${l}<span class="pw"><input name="${n}" type="password" required><button type="button" class="eye" data-eye aria-label="Hiện mật khẩu">${EYE}</button></span></label>`;
function bindEyes() {
  document.querySelectorAll("[data-eye]").forEach(
    (b) =>
      (b.onclick = () => {
        const i = b.previousElementSibling,
          show = i.type === "password";
        i.type = show ? "text" : "password";
        b.innerHTML = show ? EYE_OFF : EYE;
        b.setAttribute("aria-label", show ? "Ẩn mật khẩu" : "Hiện mật khẩu");
      }),
  );
}
const NEWS = [
  {
    id: 1,
    date: "05/11/2026",
    title: "Giữ ghế 10 phút: đặt vé không lo bị giành chỗ",
    body: "Khi bạn chọn ghế, hệ thống giữ chỗ trong 10 phút. Hết thời gian mà chưa thanh toán, ghế tự động trở về trống để người khác có thể đặt. Mỗi đơn đặt tối đa 8 ghế.",
  },
  {
    id: 2,
    date: "03/11/2026",
    title: "Thứ Ba đồng giá với mã THU3",
    body: "Nhập mã THU3 khi thanh toán để giảm 15% (tối đa 40.000đ) cho các suất chiếu vào thứ Ba. Mã không áp dụng cho các ngày khác trong tuần.",
  },
  {
    id: 4,
    date: "25/10/2026",
    title: "Quy định huỷ vé và hoàn tiền",
    body: "Đơn chưa thanh toán có thể huỷ bất kỳ lúc nào. Vé đã thanh toán chỉ huỷ được khi còn ít nhất 2 giờ trước giờ chiếu và được hoàn 100% số tiền đã trả.",
  },
];
const esc = (t) =>
  String(t).replace(
    /[&<>"]/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c],
  );

async function uploadImgBB(file) {
  if (!IMGBB_API_KEY || IMGBB_API_KEY === "DAN_API_KEY_IMGBB_CUA_BAN_VAO_DAY") {
    throw new Error("Bạn chưa dán API Key của ImgBB vào đầu file js/site.js");
  }
  const fd = new FormData();
  fd.append("image", file);
  const res = await fetch(
    `https://api.imgbb.com/1/upload?key=${IMGBB_API_KEY}`,
    {
      method: "POST",
      body: fd,
    },
  );
  const data = await res.json();
  if (!data.success) {
    throw new Error(data.error?.message || "Tải ảnh lên ImgBB thất bại");
  }
  return data.data.display_url;
}

const poster = (m) => {
  const meta =
    typeof m.metadata === "string"
      ? JSON.parse(m.metadata || "{}")
      : m.metadata || {};
  const url = meta.poster;
  return `<div class="poster" style="--h:${(Number(m.movie_id || 0) * 67) % 360};position:relative;overflow:hidden"><i class="age" style="z-index:2">${m.rating || ""}</i>${m.review_count ? `<i class="star" style="z-index:2">★ ${Number(m.avg_rating || 0).toFixed(1)}</i>` : ""}<span class="ini">${(m.title || "?")[0]}</span><b>${m.title || ""}</b>${url ? `<img src="${esc(url)}" alt="${esc(m.title || "")}" onerror="this.remove()" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;z-index:1">` : ""}</div>`;
};

function layout() {
  const cur = location.pathname.split("/").pop() || "index.html",
    L = [
      ["phim.html", "Phim"],
      ["rap.html", "Rạp"],
      ["uu-dai.html", "Ưu đãi"],
      ["tin-tuc.html", "Tin tức"],
      ["ve-cua-toi.html", "Vé của tôi"],
    ];
  $("#hdr").innerHTML =
    `<header class="hd"><div class="wrap hbar"><a class="logo" href="index.html">Cine<span>DB</span></a><button class="burger" aria-label="Mở menu" onclick="this.closest('.hd').classList.toggle('open')">☰</button><nav class="nav">${L.map(([h, t]) => `<a href="${h}" class="${cur === h ? "on" : ""}">${t}</a>`).join("")}</nav><form class="srch" action="phim.html"><input name="q" placeholder="Tìm phim" aria-label="Tìm phim"></form><div class="acc">${user ? `<a class="pill" href="ho-so.html">${esc(user.name)}</a>${user.role === "ADMIN" ? '<a class="btn sm" href="quan-tri.html">Trang quản trị</a>' : '<a class="btn sm alt" href="quan-tri-dang-nhap.html">Quản trị viên</a>'}` : '<a class="btn sm" href="dang-nhap.html">Đăng nhập</a><a class="btn sm alt" href="quan-tri-dang-nhap.html">Quản trị viên</a>'}</div></div></header>`;
  $("#ftr").innerHTML =
    `<footer><div class="wrap"><div><h4>CineDB Việt Nam</h4><p>Hệ thống đặt vé xem phim trực tuyến. Đồ án môn Các hệ quản trị cơ sở dữ liệu, Oracle Database 23ai (Đề tài 6).</p></div><div><h4>Xem phim</h4><a href="phim.html">Phim đang chiếu</a><a href="phim.html?tab=soon">Phim sắp chiếu</a><a href="rap.html">Rạp chiếu phim</a><a href="uu-dai.html">Ưu đãi</a></div><div><h4>Tài khoản</h4><a href="dang-nhap.html">Đăng nhập</a><a href="thanh-vien.html">Đăng ký</a><a href="ho-so.html">Hồ sơ cá nhân</a><a href="ve-cua-toi.html">Vé của tôi</a><a href="quan-tri-dang-nhap.html">Quản trị viên</a></div><div><h4>Chính sách</h4><p>Giữ ghế 10 phút. Huỷ vé đã thanh toán trước giờ chiếu ít nhất 2 giờ, hoàn 100%.</p></div></div><div class="wrap muted">© 2026 CineDB. Giao diện mang tính minh hoạ, không phải trang chính thức của bất kỳ hệ thống rạp nào.</div></footer>`;
}

// ----- khối danh sách phim có tab Đang chiếu / Sắp chiếu -----
function movieBlock(ms, tab) {
  const list = ms.filter((m) => m.status === (tab === "soon" ? "SOON" : "NOW"));
  return `<div class="tabs"><button data-t="now" class="${tab === "soon" ? "" : "on"}">Đang chiếu</button><button data-t="soon" class="${tab === "soon" ? "on" : ""}">Sắp chiếu</button></div>
  <div class="grid">${list.map((m) => `<article class="card"><a href="chi-tiet.html?id=${m.movie_id}">${poster(m)}</a><div class="cb"><h3><a href="chi-tiet.html?id=${m.movie_id}">${m.title}</a></h3><div class="muted small">${m.genre} · ${m.duration_min} phút</div><a class="btn ${tab === "soon" ? "alt" : ""}" href="chi-tiet.html?id=${m.movie_id}">${tab === "soon" ? "Chi tiết" : "Mua vé"}</a></div></article>`).join("") || '<p class="muted">Không tìm thấy phim phù hợp.</p>'}</div>`;
}
function mountMovies(box, ms, tab) {
  box.innerHTML = movieBlock(ms, tab);
  box.dataset.tab = tab || "";
  box
    .querySelectorAll(".tabs button")
    .forEach((b) => (b.onclick = () => mountMovies(box, ms, b.dataset.t)));
}

async function pHome() {
  const ms = await API.movies(),
    now = ms.filter((m) => m.status === "NOW"),
    feat = now.slice(0, 3);
  app.innerHTML = `<section class="hero" id="hero"><div class="wrap hero-in"><div><span class="chip2">Phim nổi bật</span><h1 id="h-t"></h1><p class="meta" id="h-m"></p><p class="lead" id="h-d"></p><div class="acts"><a class="btn" id="h-b">Mua vé ngay</a><a class="btn ghost" id="h-i">Xem chi tiết</a></div><div class="dots">${feat.map(() => "<i></i>").join("")}</div></div><div class="hero-poster" id="h-p"></div></div></section>
  <div class="wrap"><div class="qbar"><b>Đặt vé nhanh</b><select id="qm" aria-label="Chọn phim"><option value="">1. Chọn phim</option>${now.map((m) => `<option value="${m.movie_id}">${m.title}</option>`).join("")}</select><select id="qs" disabled aria-label="Chọn suất chiếu"><option value="">2. Chọn suất chiếu</option></select><button class="btn" id="qgo" disabled>Mua vé ngay</button></div></div>
  <div class="wrap"><h2 class="t">Phim</h2><div id="mv"></div></div>
  <div class="wrap"><h2 class="t">Tin mới</h2><div class="grid">${NEWS.slice(
    0,
    3,
  )
    .map(
      (x) =>
        `<a class="box" href="tin-tuc.html?id=${x.id}"><h3>${x.title}</h3><p class="muted small">${x.date}</p></a>`,
    )
    .join("")}</div></div>`;
  mountMovies($("#mv"), ms, "now");
  let i = 0;
  const show = (k) => {
    i = k;
    const m = feat[k],
      d =
        typeof m.metadata === "string"
          ? JSON.parse(m.metadata || "{}")
          : m.metadata || {};
    $("#hero").style.setProperty("--h", (m.movie_id * 67) % 360);
    $("#h-t").textContent = m.title;
    $("#h-m").textContent =
      m.genre + " · " + m.duration_min + " phút · " + m.rating;
    $("#h-d").textContent = d.director
      ? "Đạo diễn " + d.director + (d.language ? ", " + d.language : "")
      : "";
    $("#h-b").href = $("#h-i").href = "chi-tiet.html?id=" + m.movie_id;
    $("#h-p").innerHTML = poster(m);
    document
      .querySelectorAll(".dots i")
      .forEach((x, j) => (x.className = j === k ? "on" : ""));
  };
  document
    .querySelectorAll(".dots i")
    .forEach((x, j) => (x.onclick = () => show(j)));
  if (feat.length) {
    show(0);
    setInterval(() => show((i + 1) % feat.length), 5000);
  }
  $("#qm").onchange = async (e) => {
    const ss = e.target.value ? await API.showtimes(e.target.value) : [];
    $("#qs").innerHTML =
      '<option value="">2. Chọn suất chiếu</option>' +
      ss
        .map(
          (s) =>
            `<option value="${s.showtime_id}">${fDate(s.start_time)} ${fTime(s.start_time)}, ${s.theater_name || ""}, ${s.room_name}</option>`,
        )
        .join("");
    $("#qs").disabled = !ss.length;
    $("#qgo").disabled = true;
  };
  $("#qs").onchange = (e) => ($("#qgo").disabled = !e.target.value);
  on("#qgo", () => (location.href = "dat-ve.html?st=" + $("#qs").value));
}

async function pPhim() {
  const ms = await API.movies(),
    genres = [...new Set(ms.map((m) => m.genre))];
  app.innerHTML = `<div class="wrap"><h1 class="t">Phim</h1><div style="display:flex;gap:.6rem;justify-content:center;flex-wrap:wrap;margin-bottom:1rem"><input id="q" placeholder="Tìm tên phim"><select id="g"><option value="">Tất cả thể loại</option>${genres.map((g) => `<option>${g}</option>`).join("")}</select></div><div id="mv"></div></div>`;
  const go = () => {
    const q = $("#q").value.toLowerCase(),
      g = $("#g").value;
    mountMovies(
      $("#mv"),
      ms.filter(
        (m) => m.title.toLowerCase().includes(q) && (!g || m.genre === g),
      ),
      $("#mv").dataset.tab || qs.get("tab"),
    );
  };
  $("#q").value = qs.get("q") || "";
  $("#q").oninput = go;
  $("#g").onchange = go;
  go();
}

async function pChiTiet() {
  const id = qs.get("id");
  if (!id) {
    location.href = "phim.html";
    return;
  }
  const [ms, ss, rv] = await Promise.all([
      API.movies(),
      API.showtimes(id),
      API.reviews(id),
    ]),
    m = ms.find((x) => x.movie_id == id);
  if (!m) {
    location.href = "phim.html";
    return;
  }
  const d =
      typeof m.metadata === "string"
        ? JSON.parse(m.metadata || "{}")
        : m.metadata || {},
    th = {};
  ss.forEach((s) =>
    ((th[s.theater_name || "Rạp"] ||= {})[fDate(s.start_time)] ||= []).push(s),
  );
  app.innerHTML = `<section class="mhero" style="--h:${(m.movie_id * 67) % 360}"><div class="wrap row2">${poster(m)}<div><span class="chip2">${m.status === "SOON" ? "Sắp chiếu" : "Đang chiếu"}</span><h1>${m.title}</h1><p class="meta">${m.genre} · ${m.duration_min} phút · ${m.rating}${m.review_count ? " · ★ " + Number(m.avg_rating || 0).toFixed(1) + " (" + m.review_count + " đánh giá)" : ""}</p><p><b>Đạo diễn:</b> ${d.director || "Đang cập nhật"}<br><b>Diễn viên:</b> ${(Array.isArray(d.cast) ? d.cast.join(", ") : d.cast) || "Đang cập nhật"}<br><b>Ngôn ngữ:</b> ${d.language || "Đang cập nhật"}</p>${d.trailer ? `<div style="display:flex;justify-content:center;margin-top:.8rem"><a class="btn ghost" href="${d.trailer}" target="_blank" rel="noopener" style="position:static;margin:0;transform:none">Xem trailer</a></div>` : ""}</div></div></section>
  <div class="wrap"><h2 class="t">Lịch chiếu</h2>${
    Object.keys(th)
      .map(
        (n) =>
          `<h3>${n}</h3>${Object.keys(th[n])
            .map(
              (k) =>
                `<div class="day"><b>${k}</b><div>${th[n][k].map((s) => `<a class="chip" href="dat-ve.html?st=${s.showtime_id}">${fTime(s.start_time)}<small>${s.room_name}, ${money(s.base_price)}</small></a>`).join("")}</div></div>`,
            )
            .join("")}`,
      )
      .join("") ||
    '<p class="muted">Phim chưa có lịch chiếu. Hãy quay lại sau.</p>'
  }
  <h2 class="t">Đánh giá</h2><div class="box" style="margin-bottom:1rem">${user ? `<form id="rf"><label class="f">Điểm của bạn<br><select name="r"><option value="5">5 sao</option><option value="4">4 sao</option><option value="3">3 sao</option><option value="2">2 sao</option><option value="1">1 sao</option></select></label><label class="f">Nhận xét<br><textarea name="t" rows="3" maxlength="500" required></textarea></label><button class="btn">Gửi đánh giá</button></form>` : `<a class="btn" href="dang-nhap.html?next=${encodeURIComponent("chi-tiet.html?id=" + id)}">Đăng nhập để đánh giá</a>`}</div>
  ${rv.map((r) => `<div class="rev"><b>${esc(r.name)}</b> <span class="stars">${"★".repeat(r.rating)}${"☆".repeat(5 - r.rating)}</span> <span class="muted small">${fDate(r.at)}</span><p>${esc(r.text)}</p></div>`).join("") || '<p class="muted">Chưa có đánh giá nào.</p>'}</div>`;
  const rf = $("#rf");
  if (rf)
    rf.onsubmit = async (ev) => {
      ev.preventDefault();
      const f = new FormData(rf);
      try {
        await API.addReview(user.id, id, +f.get("r"), f.get("t"));
        toast("Cảm ơn bạn đã đánh giá");
        pChiTiet();
      } catch (e) {
        showErr(e);
      }
    };
}

async function pDatVe() {
  const id = qs.get("st");
  if (!id) {
    location.href = "phim.html";
    return;
  }
  if (!user) {
    toast("Hãy đăng nhập tài khoản trước khi đặt vé", true);
    setTimeout(
      () =>
        (location.href =
          "dang-nhap.html?next=" + encodeURIComponent("dat-ve.html?st=" + id)),
      900,
    );
    return;
  }
  const [st, ms] = await Promise.all([API.showtime(id), API.movies()]),
    mv = ms.find((x) => x.movie_id == st.movie_id) || {
      movie_id: 0,
      title: st.title,
      rating: "",
    };
  let seats = await API.seatmap(id),
    sel = new Set(),
    hold = null;
  if (qs.get("resume")) {
    try {
      const r = await API.resume(+qs.get("resume"), user.id);
      hold = { id: r.booking_id, exp: toDate(r.expires_at).getTime() };
      (r.seat_ids || []).forEach((i) => sel.add(Number(i)));
    } catch (e) {
      showErr(e);
    }
  }
  const info = (i) => seats.find((x) => x.seat_id === i),
    label = (i) => info(i).row_label + info(i).seat_no;
  const reload = async () => {
    seats = await API.seatmap(id);
    draw();
  };
  const tick = () => {
    clearInterval(timer);
    timer = setInterval(async () => {
      const s = Math.max(0, Math.round((hold.exp - Date.now()) / 1000)),
        c = $("#cd");
      if (c)
        c.textContent =
          Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
      if (!s) {
        clearInterval(timer);
        hold = null;
        sel.clear();
        toast("Hết 10 phút, ghế đã được trả lại", true);
        await reload();
      }
    }, 1000);
  };
  function draw() {
    const rows = [...new Set(seats.map((s) => s.row_label))],
      est = [...sel].reduce((a, i) => a + (info(i)?.price || 0), 0);
    app.innerHTML = `<div class="wrap"><div class="steps"><span class="${hold ? "" : "on"}">1. Chọn ghế</span><span class="${hold ? "on" : ""}">2. Thanh toán</span><span>3. Nhận vé</span></div><div class="book"><div class="box"><div class="screen">Màn hình</div>
    ${rows
      .map(
        (r) =>
          `<div class="srow"><b>${r}</b>${seats
            .filter((s) => s.row_label === r)
            .map(
              (s) =>
                `<button class="seat ${s.seat_type} ${s.status} ${sel.has(s.seat_id) ? "sel" : ""}" data-id="${s.seat_id}" ${s.status !== "AVAILABLE" || hold ? "disabled" : ""} title="${label(s.seat_id)}, ${s.seat_type}${s.price ? ", " + money(s.price) : ""}">${s.seat_no}</button>`,
            )
            .join("")}</div>`,
      )
      .join("")}
    <div class="legend"><span><i style="background:var(--s1)"></i>Thường</span><span><i style="background:var(--s2)"></i>VIP</span><span><i style="background:var(--s3)"></i>Ghế đôi</span><span><i style="background:var(--red)"></i>Đang chọn</span><span><i style="background:var(--s4)"></i>Đã có người</span></div></div>
    <aside class="box"><div class="sum">${poster(mv)}<div><h3>${mv.title}</h3><div class="muted">${fDate(st.start_time)} ${fTime(st.start_time)}<br>${st.theater_name || ""}, ${st.room_name || ""}</div></div></div>
    <p>Ghế: <b>${[...sel].map(label).join(", ") || "chưa chọn"}</b></p><div class="tot"><span>Tạm tính</span><span id="tot">${est ? money(est) : "—"}</span></div><br>
    ${
      hold
        ? `<p>Đơn #${hold.id}, còn <b id="cd"></b> để thanh toán</p><div class="pay"><input id="promo" placeholder="Mã khuyến mãi" style="min-width:0;width:100%;margin-bottom:.5rem"><label><input type="radio" name="m" value="MOMO" checked>Ví MoMo</label><label><input type="radio" name="m" value="ZALOPAY">ZaloPay</label><label><input type="radio" name="m" value="CARD">Thẻ ATM / Visa</label></div><br><button class="btn" id="pay">Thanh toán</button> <button class="btn alt" id="cancel">Huỷ đơn</button>`
        : `<button class="btn" id="hold" ${sel.size ? "" : "disabled"}>Giữ ghế 10 phút</button><p class="muted small">Chọn tối đa 8 ghế mỗi đơn.</p>`
    }</aside></div></div>`;
    app.querySelectorAll(".seat").forEach(
      (b) =>
        (b.onclick = () => {
          const i = +b.dataset.id;
          if (sel.has(i)) sel.delete(i);
          else if (sel.size < 8) sel.add(i);
          else toast("Tối đa 8 ghế mỗi đơn", true);
          draw();
        }),
    );
    on("#hold", async () => {
      try {
        const r = await API.hold(user.id, +id, [...sel]);
        hold = {
          id: r.booking_id,
          exp: r.expires_at
            ? toDate(r.expires_at).getTime()
            : Date.now() + 600000,
        };
        toast("Đã giữ ghế, hãy thanh toán trong 10 phút");
        draw();
        tick();
      } catch (e) {
        showErr(e);
        sel.clear();
        await reload();
      }
    });
    on("#pay", async () => {
      try {
        const r = await API.confirm(
          hold.id,
          $("#promo").value.trim() || null,
          document.querySelector("[name=m]:checked").value,
        );
        clearInterval(timer);
        sessionStorage.setItem(
          "ticket",
          JSON.stringify({
            ...r,
            booking_id: hold.id,
            title: mv.title,
            when: fDate(st.start_time) + " " + fTime(st.start_time),
            room: (st.theater_name || "") + ", " + st.room_name,
          }),
        );
        location.href = "ve.html";
      } catch (e) {
        showErr(e);
      }
    });
    on("#cancel", async () => {
      try {
        await API.cancel(hold.id, user.id);
        clearInterval(timer);
        hold = null;
        sel.clear();
        toast("Đã huỷ đơn");
        await reload();
      } catch (e) {
        showErr(e);
      }
    });
  }
  draw();
  if (hold) tick();
}

async function pVe() {
  const t = JSON.parse(sessionStorage.getItem("ticket") || "null");
  if (!t) {
    app.innerHTML =
      '<div class="wrap"><h1 class="t">Vé của bạn</h1><p style="text-align:center" class="muted">Bạn chưa có vé nào. <a href="phim.html" style="color:var(--red)">Chọn phim ngay</a></p></div>';
    return;
  }
  app.innerHTML = `<div class="wrap"><div class="steps"><span>1. Chọn ghế</span><span>2. Thanh toán</span><span class="on">3. Nhận vé</span></div><div class="stub"><div class="main"><h2 style="margin:0;color:var(--red)">${t.title || "Vé xem phim"}</h2><p class="muted">${t.when || ""}, ${t.room || ""}</p><p>Ghế: <b>${(t.tickets || []).map((x) => x.seat_label).join(", ") || t.seatsText || "—"}</b></p><p class="muted">Tiền vé ${money(t.subtotal)}, giảm ${money(t.discount_amount)}</p><h3 style="margin:0">Đã thanh toán ${money(t.final_amount)}</h3><div class="bar"></div></div><div class="tear"><p class="muted">Mã đơn</p><h2 style="margin:0">#${t.booking_id}</h2><div id="qr" style="display:inline-block;background:#fff;padding:6px;border-radius:8px;margin:.6rem 0"></div><p class="muted">Trạng thái</p><b id="st">PAID</b></div></div>
  <p style="text-align:center"><button class="btn alt" onclick="print()">In vé</button> <button class="btn alt" id="refund">Huỷ vé và hoàn tiền</button> <a class="btn" href="index.html">Về trang chủ</a></p></div>`;
  if (window.QRCode)
    new QRCode($("#qr"), {
      text:
        "CINEDB-" +
        t.booking_id +
        "-" +
        ((t.tickets || []).map((x) => x.seat_label).join(".") ||
          t.seatsText ||
          ""),
      width: 104,
      height: 104,
    });
  else $("#qr").remove();
  on("#refund", async () => {
    if (!user) {
      location.href = "dang-nhap.html";
      return;
    }
    try {
      await API.cancel(t.booking_id, user.id);
      $("#st").textContent = "CANCELLED";
      sessionStorage.removeItem("ticket");
      toast("Đã hoàn tiền 100%");
    } catch (e) {
      showErr(e);
    }
  });
}

async function pThanhVien() {
  if (user) {
    location.href = "ho-so.html";
    return;
  }
  const inp = (n, l, t = "text") =>
    `<label class="f">${l}<input name="${n}" type="${t}" required></label>`;
  app.innerHTML = `<div class="wrap"><h1 class="t">Đăng ký thành viên</h1><form id="f" class="box" style="max-width:480px">${inp("n", "Họ tên")}${inp("e", "Email", "email")}${pwField("p", "Mật khẩu")}${pwField("c", "Xác nhận mật khẩu")}<p class="muted small">Tối thiểu 8 ký tự, có chữ hoa, chữ thường và chữ số.</p><button class="btn">Đăng ký</button> <a href="dang-nhap.html">Đã có tài khoản? Đăng nhập</a></form></div>`;
  $("#f").onsubmit = async (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target);
    if (f.get("p") !== f.get("c")) {
      toast("Mật khẩu xác nhận không khớp", true);
      return;
    }
    try {
      const r = await API.register(f.get("n").trim(), f.get("e"), f.get("p"));
      localStorage.setItem(
        "cinema_user",
        JSON.stringify({
          id: r.customer_id,
          name: f.get("n").trim(),
          email: f.get("e"),
          role: "CUSTOMER",
        }),
      );
      location.href = qs.get("next") || "index.html";
    } catch (e) {
      showErr(e);
    }
  };
}

async function pHoSo() {
  if (!user) {
    location.href = "dang-nhap.html?next=ho-so.html";
    return;
  }
  const p = await API.getProfile(user.id),
    today = new Date().toISOString().slice(0, 10),
    v = (x) => esc(x || "");
  app.innerHTML = `<div class="wrap"><h1 class="t">Hồ sơ cá nhân</h1><div class="prof"><aside class="box ctr"><div class="avatar">${esc((p.full_name || "?")[0].toUpperCase())}</div><h3>${v(p.full_name)}</h3><p class="muted small">${v(p.email)}<br>Mã khách hàng ${p.customer_id}${user.role === "ADMIN" ? "<br>Quản trị viên" : ""}</p><a class="btn alt sm" href="ve-cua-toi.html">Vé của tôi</a> <button class="btn alt sm" id="out">Đăng xuất</button></aside>
  <div><form id="pf" class="box"><h3>Thông tin cá nhân</h3><div class="fgrid"><label class="f">Họ tên<input name="n" value="${v(p.full_name)}" required></label><label class="f">Email<input value="${v(p.email)}" disabled></label><label class="f">Số điện thoại<input name="ph" type="tel" value="${v(p.phone)}" placeholder="0901234567"></label><label class="f">Ngày sinh<input name="b" type="date" max="${today}" value="${v(String(p.birth || "").slice(0, 10))}"></label><label class="f">Giới tính<select name="g">${["", "Nam", "Nữ", "Khác"].map((x) => `<option value="${x}" ${p.gender === x ? "selected" : ""}>${x || "Không muốn nêu"}</option>`).join("")}</select></label><label class="f">Địa chỉ<input name="a" value="${v(p.address)}"></label></div><button class="btn">Lưu thay đổi</button></form>
  <form id="pw" class="box" style="margin-top:1.2rem"><h3>Đổi mật khẩu</h3>${pwField("o", "Mật khẩu hiện tại")}${pwField("p", "Mật khẩu mới")}${pwField("c", "Xác nhận mật khẩu mới")}<p class="muted small">Tối thiểu 8 ký tự, có chữ hoa, chữ thường và chữ số.</p><button class="btn">Đổi mật khẩu</button></form></div></div></div>`;
  bindEyes();
  $("#pf").onsubmit = async (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target),
      n = f.get("n").trim();
    try {
      await API.updateProfile(user.id, {
        full_name: n,
        phone: f.get("ph").trim(),
        birth: f.get("b"),
        gender: f.get("g"),
        address: f.get("a").trim(),
      });
      user.name = n;
      localStorage.setItem("cinema_user", JSON.stringify(user));
      layout();
      toast("Đã lưu hồ sơ");
    } catch (e) {
      showErr(e);
    }
  };
  $("#pw").onsubmit = async (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target);
    if (f.get("p") !== f.get("c")) {
      toast("Mật khẩu xác nhận không khớp", true);
      return;
    }
    try {
      await API.changePassword(user.id, f.get("o"), f.get("p"));
      ev.target.reset();
      toast("Đã đổi mật khẩu");
    } catch (e) {
      showErr(e);
    }
  };
  on("#out", () => {
    localStorage.removeItem("cinema_user");
    location.href = "index.html";
  });
}

function pUuDai() {
  const l = [
    [
      "WELCOME10",
      "Giảm 10% mọi đơn",
      "Giảm tối đa 30.000đ, dùng được cho mọi suất chiếu.",
    ],
    ["GIAM50K", "Giảm 50.000đ", "Áp dụng cho đơn từ 200.000đ."],
    [
      "THU3",
      "Thứ Ba đồng giá",
      "Giảm 15% (tối đa 40.000đ), chỉ áp dụng cho suất chiếu thứ Ba. Điều kiện này lưu trong cột JSON PROMOTION.conditions.",
    ],
  ];
  app.innerHTML = `<div class="wrap"><h1 class="t">Tin mới và ưu đãi</h1><div class="grid">${l.map((x) => `<div class="box promo"><h3>${x[1]}</h3><p>${x[2]}</p><p>Mã: <code>${x[0]}</code></p></div>`).join("")}</div></div>`;
}

function pDangNhap() {
  if (user) {
    location.href = "index.html";
    return;
  }
  app.innerHTML = `<div class="wrap"><h1 class="t">Đăng nhập</h1><form id="f" class="box" style="max-width:480px;margin:auto"><label class="f">Email<br><input name="e" type="email" required style="width:100%"></label>${pwField("p", "Mật khẩu")}<button class="btn">Đăng nhập</button> <a href="thanh-vien.html">Chưa có tài khoản? Đăng ký</a><br><a href="quen-mat-khau.html">Quên mật khẩu?</a></form></div>`;
  $("#f").onsubmit = async (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target);
    try {
      const r = await API.login(f.get("e"), f.get("p"));
      localStorage.setItem(
        "cinema_user",
        JSON.stringify({
          id: r.customer_id,
          name: r.full_name,
          email: f.get("e"),
          role: r.role,
        }),
      );
      location.href = qs.get("next") || "index.html";
    } catch (e) {
      showErr(e);
    }
  };
}

async function pVeCuaToi() {
  if (!user) {
    location.href = "dang-nhap.html?next=ve-cua-toi.html";
    return;
  }
  const bs = await API.myBookings(user.id),
    vi = {
      PAID: "Đã thanh toán",
      PENDING: "Chờ thanh toán",
      CANCELLED: "Đã huỷ",
      EXPIRED: "Hết hạn",
    };
  app.innerHTML = `<div class="wrap"><h1 class="t">Vé của tôi</h1><table><tr><th>Đơn</th><th>Phim</th><th>Suất chiếu</th><th>Ghế</th><th>Tổng tiền</th><th>Trạng thái</th><th></th></tr>${bs.map((b, i) => `<tr><td>#${b.booking_id}</td><td>${b.title}</td><td>${fDate(b.start_time)} ${fTime(b.start_time)}<br><small class="muted">${b.room_name}</small></td><td>${b.seats || "—"}</td><td>${b.final_amount ? money(b.final_amount) : "—"}</td><td>${vi[b.status] || b.status}</td><td>${b.status === "PAID" ? `<button class="btn sm" data-v="${i}">Xem vé</button> ` : ""}${b.status === "PENDING" && toDate(b.exp).getTime() > Date.now() ? `<a class="btn sm" href="dat-ve.html?st=${b.showtime_id}&resume=${b.booking_id}">Thanh toán tiếp</a> ` : ""}${["PENDING", "PAID"].includes(b.status) ? `<button class="btn sm alt" data-c="${b.booking_id}">${b.status === "PAID" ? "Huỷ và hoàn tiền" : "Huỷ đơn"}</button>` : ""}</td></tr>`).join("") || '<tr><td colspan="7">Bạn chưa có đơn đặt vé nào.</td></tr>'}</table></div>`;
  app.querySelectorAll("[data-c]").forEach(
    (b) =>
      (b.onclick = async () => {
        try {
          await API.cancel(+b.dataset.c, user.id);
          toast("Đã huỷ đơn");
          pVeCuaToi();
        } catch (e) {
          showErr(e);
        }
      }),
  );
  app.querySelectorAll("[data-v]").forEach(
    (b) =>
      (b.onclick = () => {
        const x = bs[+b.dataset.v];
        sessionStorage.setItem(
          "ticket",
          JSON.stringify({
            booking_id: x.booking_id,
            title: x.title,
            when: fDate(x.start_time) + " " + fTime(x.start_time),
            room: x.room_name,
            tickets: x.tickets,
            seatsText: x.seats,
            subtotal: x.subtotal,
            discount_amount: x.discount_amount,
            final_amount: x.final_amount,
          }),
        );
        location.href = "ve.html";
      }),
  );
}

async function pRap() {
  const [ts, rooms, ss] = await Promise.all([
    API.theaters(),
    API.rooms(),
    API.allShowtimes(),
  ]);
  if (!ts.length) {
    app.innerHTML =
      '<div class="wrap"><h1 class="t">Rạp chiếu phim</h1><p class="muted">Chưa có dữ liệu rạp.</p></div>';
    return;
  }
  const t = ts.find((x) => x.theater_id == qs.get("t")) || ts[0],
    up = ss
      .filter(
        (s) =>
          toDate(s.start_time).getTime() > Date.now() && s.status === "OPEN",
      )
      .sort((a, b) => toDate(a.start_time) - toDate(b.start_time));
  app.innerHTML = `<div class="wrap"><h1 class="t">Rạp chiếu phim</h1>${[
    ...new Set(ts.map((x) => x.city)),
  ]
    .map(
      (c) =>
        `<h3>${c}</h3><div class="tabs" style="justify-content:flex-start">${ts
          .filter((x) => x.city === c)
          .map(
            (x) =>
              `<button class="${x.theater_id === t.theater_id ? "on" : ""}" onclick="location.href='rap.html?t=${x.theater_id}'">${x.name}</button>`,
          )
          .join("")}</div>`,
    )
    .join("")}
  <div class="box"><h3>${t.name}</h3><p class="muted">${t.address}, ${t.city}</p></div>
  ${rooms
    .filter((r) => r.theater_id === t.theater_id)
    .map(
      (r) =>
        `<h3>${r.name}: suất chiếu sắp tới</h3><table><tr><th>Phim</th><th>Ngày giờ</th><th>Giá cơ sở</th><th>Đã bán</th><th></th></tr>${
          up
            .filter((s) => s.room_id === r.room_id)
            .map(
              (s) =>
                `<tr><td>${s.title}</td><td>${fDate(s.start_time)} ${fTime(s.start_time)}</td><td>${money(s.base_price)}</td><td>${s.occupancy}%</td><td><a class="btn" href="dat-ve.html?st=${s.showtime_id}">Mua vé</a></td></tr>`,
            )
            .join("") || '<tr><td colspan="5">Chưa có suất chiếu.</td></tr>'
        }</table>`,
    )
    .join("")}</div>`;
}

function pTinTuc() {
  const a = NEWS.find((x) => x.id == qs.get("id"));
  app.innerHTML = a
    ? `<div class="wrap" style="max-width:720px"><a href="tin-tuc.html" style="color:var(--red)">Quay lại tin tức</a><h1>${a.title}</h1><p class="muted">${a.date}</p><p>${a.body}</p></div>`
    : `<div class="wrap"><h1 class="t">Tin tức</h1><div class="grid">${NEWS.map((x) => `<a class="box" href="tin-tuc.html?id=${x.id}"><h3>${x.title}</h3><p class="muted small">${x.date}</p><p>${x.body.slice(0, 90)}…</p></a>`).join("")}</div></div>`;
}

// ----- Quản trị (chỉ vai trò ADMIN) -----
const act = async (fn, ok, again) => {
  try {
    await fn();
    toast(ok);
    again();
  } catch (e) {
    showErr(e);
  }
};
const fld = (n, l, x = "") => `<label>${l}<br><input name="${n}" ${x}></label>`;
const FORM =
  'class="box" style="display:flex;gap:.8rem;flex-wrap:wrap;align-items:end"';

async function pQuanTri() {
  if (user?.role !== "ADMIN") {
    app.innerHTML =
      '<div class="wrap" style="text-align:center"><h1 class="t">Quản trị</h1><p>Chỉ quản trị viên mới xem được trang này. <a href="quan-tri-dang-nhap.html" style="color:var(--red)">Đăng nhập</a></p><p class="muted small">Tài khoản: admin@cinedb.vn / Admin123</p></div>';
    return;
  }
  const tab = qs.get("tab") || "doanhthu",
    tabs = [
      ["doanhthu", "Doanh thu"],
      ["phim", "Phim"],
      ["suat", "Suất chiếu"],
      ["khuyenmai", "Khuyến mãi"],
      ["khach", "Khách hàng"],
    ];
  app.innerHTML = `<div class="wrap"><h1 class="t">Quản trị</h1><div class="tabs" style="flex-wrap:wrap">${tabs.map(([k, v]) => `<button class="${k === tab ? "on" : ""}" onclick="location.href='quan-tri.html?tab=${k}'">${v}</button>`).join("")}</div><div id="ad"></div></div>`;
  await (
    {
      doanhthu: aRev,
      phim: aMovies,
      suat: aShow,
      khuyenmai: aPromo,
      khach: aCust,
    }[tab] || aRev
  )($("#ad"));
}

async function aRev(box) {
  const [rev, log] = await Promise.all([API.revenue(), API.audit()]),
    tot = rev.reduce((a, r) => a + Number(r.gross_revenue), 0),
    days = {};
  rev.forEach((r) => (days[r.show_date] ||= []).push(r));
  const rows = Object.keys(days)
    .sort()
    .flatMap((d) =>
      days[d]
        .sort((a, b) => b.gross_revenue - a.gross_revenue)
        .map((r, i) => ({ ...r, rnk: i + 1 })),
    );
  box.innerHTML = `<div class="stats"><div><b>${money(tot)}</b><span>Doanh thu gộp</span></div><div><b>${rev.reduce((a, r) => a + Number(r.tickets_sold), 0)}</b><span>Vé đã bán</span></div><div><b>${log.filter((l) => l.new_value === "PAID").length}</b><span>Đơn đã thanh toán</span></div><div><b>${log.filter((l) => ["CANCELLED", "EXPIRED"].includes(l.new_value)).length}</b><span>Đơn huỷ hoặc hết hạn</span></div></div><p><button class="btn alt" id="csv">Xuất CSV</button> <button class="btn" id="rel">Chạy thu hồi ghế hết hạn</button> <button class="btn alt" id="rst">Đặt lại phiên</button></p>
  <h3>Doanh thu và hạng phim theo ngày chiếu</h3><table><tr><th>Ngày chiếu</th><th>Hạng</th><th>Phim</th><th>Số vé</th><th>Doanh thu gộp</th></tr>${rows.map((r) => `<tr><td>${toDate(r.show_date).toLocaleDateString("vi-VN")}</td><td>${r.rnk}</td><td>${r.title}</td><td>${r.tickets_sold}</td><td>${money(r.gross_revenue)}</td></tr>`).join("") || '<tr><td colspan="5">Chưa có vé nào được bán.</td></tr>'}<tr><td colspan="4"><b>Tổng cộng</b></td><td><b>${money(tot)}</b></td></tr></table>
  <h3>Nhật ký đổi trạng thái đơn</h3><table><tr><th>Đơn</th><th>Từ</th><th>Sang</th><th>Lúc</th></tr>${log.map((l) => `<tr><td>#${l.record_id}</td><td>${l.old_value}</td><td>${l.new_value}</td><td>${fDate(l.changed_at)} ${fTime(l.changed_at)}</td></tr>`).join("") || '<tr><td colspan="4">Chưa có thay đổi nào.</td></tr>'}</table>`;
  on("#csv", () => {
    const csv =
      "\ufeffNgày chiếu,Hạng,Phim,Số vé,Doanh thu gộp\n" +
      rows
        .map((r) =>
          [
            toDate(r.show_date).toLocaleDateString("vi-VN"),
            r.rnk,
            '"' + r.title + '"',
            r.tickets_sold,
            r.gross_revenue,
          ].join(","),
        )
        .join("\n");
    const a = document.createElement("a");
    a.href = URL.createObjectURL(
      new Blob([csv], { type: "text/csv;charset=utf-8" }),
    );
    a.download = "doanh-thu.csv";
    a.click();
  });
  on("#rel", async () => {
    await API.release();
    toast("Đã giải phóng ghế quá hạn");
    aRev(box);
  });
  on("#rst", () => {
    API.reset();
    location.href = "index.html";
  });
}

async function aMovies(box) {
  const ms = await API.movies(),
    again = () => aMovies(box);
  box.innerHTML = `<h3>Thêm phim</h3><form id="f" ${FORM}>${fld("title", "Tên phim", "required")}${fld("genre", "Thể loại", "required")}${fld("dur", "Thời lượng (phút)", 'type="number" min="30" value="100" required')}<label>Giới hạn tuổi<br><select name="rating"><option>P</option><option>T13</option><option>T16</option><option>T18</option></select></label><label>Trạng thái<br><select name="status"><option value="NOW">Đang chiếu</option><option value="SOON">Sắp chiếu</option></select></label>${fld("director", "Đạo diễn")}${fld("cast", "Diễn viên (cách nhau dấu phẩy)")}${fld("lang", "Ngôn ngữ")}${fld("trailer", "Link trailer", 'type="url"')}<label>Ảnh poster<br><input type="file" name="poster" id="p-file" accept="image/*"></label><img id="p-prev" alt="" style="display:none;width:44px;height:62px;object-fit:cover;border-radius:6px;border:1px solid #ddd"><button class="btn">Thêm phim</button></form>
  <h3>Danh sách phim</h3><table><tr><th>Phim</th><th>Thể loại</th><th>Phút</th><th>Tuổi</th><th>Trạng thái</th><th></th></tr>${ms
    .map((m) => {
      const meta =
        typeof m.metadata === "string"
          ? JSON.parse(m.metadata || "{}")
          : m.metadata || {};
      return `<tr><td style="display:flex;align-items:center;gap:.6rem">${meta.poster ? `<img src="${esc(meta.poster)}" style="width:36px;height:50px;object-fit:cover;border-radius:4px">` : ""}<span>${m.title}</span></td><td>${m.genre}</td><td>${m.duration_min}</td><td>${m.rating}</td><td>${m.status === "NOW" ? "Đang chiếu" : "Sắp chiếu"}</td><td><button class="btn alt" data-p="${m.movie_id}">Đổi poster</button> <button class="btn alt" data-s="${m.movie_id}">Đổi trạng thái</button> <button class="btn alt" data-e="${m.movie_id}">Sửa</button> <button class="btn alt" data-d="${m.movie_id}">Xoá</button></td></tr>`;
    })
    .join("")}</table>`;

  $("#p-file").onchange = (e) => {
    const file = e.target.files[0],
      prev = $("#p-prev");
    if (file) {
      prev.src = URL.createObjectURL(file);
      prev.style.display = "block";
    } else {
      prev.style.display = "none";
    }
  };

  $("#f").onsubmit = async (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target),
      btn = ev.target.querySelector("button"),
      file = f.get("poster"),
      oldTxt = btn.textContent;
    btn.disabled = true;
    try {
      let posterUrl = "";
      if (file && file.size > 0) {
        btn.textContent = "Đang tải ảnh...";
        posterUrl = await uploadImgBB(file);
      }
      btn.textContent = "Đang lưu phim...";
      await API.saveMovie({
        title: f.get("title"),
        genre: f.get("genre"),
        duration_min: +f.get("dur"),
        rating: f.get("rating"),
        status: f.get("status"),
        metadata: {
          director: f.get("director"),
          cast: f
            .get("cast")
            .split(",")
            .map((x) => x.trim())
            .filter(Boolean),
          language: f.get("lang"),
          trailer: f.get("trailer"),
          ...(posterUrl ? { poster: posterUrl } : {}),
        },
      });
      toast("Đã thêm phim");
      again();
    } catch (e) {
      showErr(e);
      btn.disabled = false;
      btn.textContent = oldTxt;
    }
  };

  box.querySelectorAll("[data-p]").forEach(
    (b) =>
      (b.onclick = () => {
        const inp = document.createElement("input");
        inp.type = "file";
        inp.accept = "image/*";
        inp.onchange = async () => {
          const file = inp.files[0];
          if (!file) return;
          const m = ms.find((x) => x.movie_id == b.dataset.p),
            oldTxt = b.textContent;
          b.disabled = true;
          b.textContent = "Đang tải...";
          try {
            const url = await uploadImgBB(file),
              meta =
                typeof m.metadata === "string"
                  ? JSON.parse(m.metadata || "{}")
                  : m.metadata || {};
            await API.saveMovie({
              ...m,
              metadata: { ...meta, poster: url },
            });
            toast("Đã cập nhật poster");
            again();
          } catch (e) {
            showErr(e);
            b.disabled = false;
            b.textContent = oldTxt;
          }
        };
        inp.click();
      }),
  );

  box.querySelectorAll("[data-s]").forEach(
    (b) =>
      (b.onclick = () => {
        const m = ms.find((x) => x.movie_id == b.dataset.s);
        act(
          () =>
            API.saveMovie({
              ...m,
              status: m.status === "NOW" ? "SOON" : "NOW",
            }),
          "Đã đổi trạng thái",
          again,
        );
      }),
  );

  box.querySelectorAll("[data-e]").forEach(
    (b) =>
      (b.onclick = () => {
        const m = ms.find((x) => x.movie_id == b.dataset.e),
          t = window.prompt("Tên phim", m.title),
          g = t && window.prompt("Thể loại", m.genre),
          d = g && window.prompt("Thời lượng (phút)", m.duration_min);
        if (d)
          act(
            () =>
              API.saveMovie({
                ...m,
                title: t,
                genre: g,
                duration_min: +d || m.duration_min,
              }),
            "Đã cập nhật phim",
            again,
          );
      }),
  );

  box
    .querySelectorAll("[data-d]")
    .forEach(
      (b) =>
        (b.onclick = () =>
          window.confirm("Xoá phim này?") &&
          act(() => API.deleteMovie(b.dataset.d), "Đã xoá phim", again)),
    );
}

async function aShow(box) {
  const [ss, ms, rooms] = await Promise.all([
      API.allShowtimes(),
      API.movies(),
      API.rooms(),
    ]),
    again = () => aShow(box);
  box.innerHTML = `<h3>Thêm suất chiếu</h3><form id="f" ${FORM}><label>Phim<br><select name="m">${ms
    .filter((m) => m.status === "NOW")
    .map((m) => `<option value="${m.movie_id}">${m.title}</option>`)
    .join(
      "",
    )}</select></label><label>Phòng<br><select name="r">${rooms.map((r) => `<option value="${r.room_id}">${r.theater_name}, ${r.name}</option>`).join("")}</select></label><label>Giờ bắt đầu<br><input type="datetime-local" name="t" required></label>${fld("p", "Giá cơ sở", 'type="number" value="90000" min="0" step="1000"')}<button class="btn">Thêm suất chiếu</button></form>
  <h3>Suất chiếu và tỉ lệ lấp đầy</h3><table><tr><th>Phim</th><th>Rạp, phòng</th><th>Giờ chiếu</th><th>Giá</th><th>Lấp đầy</th><th>Trạng thái</th><th></th></tr>${ss
    .sort((a, b) => toDate(a.start_time) - toDate(b.start_time))
    .map(
      (s) =>
        `<tr><td>${s.title}</td><td>${s.theater_name}, ${s.room_name}</td><td>${fDate(s.start_time)} ${fTime(s.start_time)}</td><td>${money(s.base_price)}</td><td>${s.occupancy}%</td><td>${s.status === "OPEN" ? "Mở bán" : "Đã huỷ"}</td><td>${s.status === "OPEN" ? `<button class="btn alt" data-c="${s.showtime_id}">Huỷ suất</button>` : ""}</td></tr>`,
    )
    .join("")}</table>`;
  $("#f").onsubmit = (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target);
    act(
      () =>
        API.addShowtime(
          f.get("m"),
          f.get("r"),
          new Date(f.get("t")).getTime(),
          f.get("p"),
        ),
      "Đã thêm suất chiếu, ghế được tạo tự động",
      again,
    );
  };
  box
    .querySelectorAll("[data-c]")
    .forEach(
      (b) =>
        (b.onclick = () =>
          window.confirm("Huỷ suất chiếu này?") &&
          act(
            () => API.cancelShowtime(b.dataset.c),
            "Đã huỷ suất chiếu",
            again,
          )),
    );
}

async function aPromo(box) {
  const ps = await API.promos(),
    again = () => aPromo(box);
  box.innerHTML = `<h3>Thêm mã khuyến mãi</h3><form id="f" ${FORM}>${fld("code", "Mã", "required")}<label>Loại<br><select name="type"><option value="PERCENT">Giảm theo %</option><option value="AMOUNT">Giảm số tiền</option></select></label>${fld("value", "Giá trị", 'type="number" min="1" required')}${fld("max", "Giảm tối đa (đ)", 'type="number" min="0"')}${fld("min", "Đơn tối thiểu (đ)", 'type="number" min="0" value="0"')}${fld("uses", "Số lượt tối đa", 'type="number" min="1"')}${fld("days", "Ngày áp dụng (MON,TUE,... để trống nếu mọi ngày)")}<button class="btn">Thêm mã</button></form>
  <h3>Danh sách mã</h3><table><tr><th>Mã</th><th>Loại</th><th>Giá trị</th><th>Tối đa</th><th>Tối thiểu</th><th>Ngày</th><th>Đã dùng</th><th>Trạng thái</th></tr>${ps.map((p) => `<tr><td><b>${p.code}</b></td><td>${p.type === "PERCENT" ? "%" : "Số tiền"}</td><td>${p.type === "PERCENT" ? p.value + "%" : money(p.value)}</td><td>${p.max ? money(p.max) : "—"}</td><td>${money(p.min)}</td><td>${p.days ? p.days.join(", ") : "Mọi ngày"}</td><td>${p.used}/${p.maxUses ?? "∞"}</td><td><button class="btn alt" data-t="${p.code}">${p.active === false ? "Đang tắt, bật lại" : "Đang bật, tắt đi"}</button></td></tr>`).join("")}</table>`;
  $("#f").onsubmit = (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target);
    act(
      () =>
        API.savePromo({
          code: f.get("code"),
          type: f.get("type"),
          value: f.get("value"),
          max: f.get("max"),
          min: f.get("min"),
          maxUses: f.get("uses"),
          days: f
            .get("days")
            .toUpperCase()
            .split(",")
            .map((x) => x.trim())
            .filter(Boolean),
        }),
      "Đã thêm mã khuyến mãi",
      again,
    );
  };
  box
    .querySelectorAll("[data-t]")
    .forEach(
      (b) =>
        (b.onclick = () =>
          act(() => API.togglePromo(b.dataset.t), "Đã cập nhật mã", again)),
    );
}

async function aCust(box) {
  const cs = await API.customers(),
    again = () => aCust(box);
  box.innerHTML = `<h3>Khách hàng</h3><table><tr><th>Mã</th><th>Họ tên</th><th>Email</th><th>Vai trò</th><th></th></tr>${cs.map((c) => `<tr><td>${c.customer_id}</td><td>${esc(c.full_name)}</td><td>${esc(c.email)}</td><td>${c.role === "ADMIN" ? "Quản trị viên" : "Khách hàng"}</td><td>${c.customer_id !== user.id ? `<button class="btn alt sm" data-r="${c.customer_id}">${c.role === "ADMIN" ? "Thu hồi quyền quản trị" : "Cấp quyền quản trị"}</button>` : ""}</td></tr>`).join("")}</table>`;
  box.querySelectorAll("[data-r]").forEach(
    (b) =>
      (b.onclick = () => {
        const c = cs.find((x) => x.customer_id == b.dataset.r);
        act(
          () =>
            API.setRole(
              c.customer_id,
              c.role === "ADMIN" ? "CUSTOMER" : "ADMIN",
            ),
          "Đã cập nhật quyền",
          again,
        );
      }),
  );
}

function pQuenMk() {
  app.innerHTML = `<div class="wrap"><h1 class="t">Quên mật khẩu</h1><form id="f1" class="box" style="max-width:480px"><label class="f">Email đã đăng ký<br><input name="e" type="email" required style="width:100%"></label><button class="btn">Gửi mã OTP</button></form>
  <form id="f2" class="box" style="max-width:480px;margin-top:1rem" hidden><p id="otp" class="muted small"></p><label class="f">Mã OTP<br><input name="o" required inputmode="numeric" style="width:100%"></label>${pwField("p", "Mật khẩu mới")}<button class="btn">Đặt lại mật khẩu</button></form></div>`;
  let email = "";
  $("#f1").onsubmit = async (ev) => {
    ev.preventDefault();
    email = new FormData(ev.target).get("e");
    try {
      const r = await API.requestReset(email);
      $("#f2").hidden = false;
      $("#otp").textContent =
        r && r.otp
          ? "Mã OTP (giả lập email, có hiệu lực 10 phút): " + r.otp
          : "Mã OTP đã được gửi tới email của bạn.";
    } catch (e) {
      showErr(e);
    }
  };
  $("#f2").onsubmit = async (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target);
    try {
      await API.resetPassword(email, f.get("o"), f.get("p"));
      toast("Đã đặt lại mật khẩu, hãy đăng nhập");
      setTimeout(() => (location.href = "dang-nhap.html"), 1200);
    } catch (e) {
      showErr(e);
    }
  };
}

function pQtDangNhap() {
  if (user?.role === "ADMIN") {
    location.href = "quan-tri.html";
    return;
  }
  app.innerHTML = `<div class="wrap"><h1 class="t">Đăng nhập quản trị viên</h1><form id="f" class="box" style="max-width:480px;margin:auto"><label class="f">Email quản trị<br><input name="e" type="email" required></label>${pwField("p", "Mật khẩu")}<button class="btn">Đăng nhập quản trị</button></form></div>`;
  $("#f").onsubmit = async (ev) => {
    ev.preventDefault();
    const f = new FormData(ev.target);
    try {
      const r = await API.login(f.get("e"), f.get("p"));
      if (r.role !== "ADMIN") {
        toast("Tài khoản này không có quyền quản trị", true);
        return;
      }
      localStorage.setItem(
        "cinema_user",
        JSON.stringify({
          id: r.customer_id,
          name: r.full_name,
          email: f.get("e"),
          role: "ADMIN",
        }),
      );
      location.href = qs.get("next") || "quan-tri.html";
    } catch (e) {
      showErr(e);
    }
  };
}

const pages = {
  home: pHome,
  phim: pPhim,
  chitiet: pChiTiet,
  datve: pDatVe,
  ve: pVe,
  thanhvien: pThanhVien,
  uudai: pUuDai,
  quantri: pQuanTri,
  dangnhap: pDangNhap,
  vecuatoi: pVeCuaToi,
  rap: pRap,
  tintuc: pTinTuc,
  quenmk: pQuenMk,
  hoso: pHoSo,
  qtdangnhap: pQtDangNhap,
};
layout();
Promise.resolve()
  .then(pages[document.body.dataset.page])
  .then(() => bindEyes())
  .catch(
    (e) => (app.innerHTML = '<div class="wrap err">' + e.message + "</div>"),
  );
