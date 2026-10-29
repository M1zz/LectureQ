// 질문노트 웹 체험: 질문을 남기면 그 시각의 타임블록 옆에 ? 가 생긴다.
// 규칙은 앱과 같다. 블록 밖 시각의 질문은 ±30분 창을 이웃 블록과 겹치지 않게 잘라 새 블록을 만든다
// (ContentView.ensureCoverage). 예시 강의 · 질문 글은 앱의 데모 모드(DemoText.swift)에서 가져왔다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const lang = document.documentElement.lang;
  const esc = s => s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

  const mins = s => { const m = /^(\d{1,2}):(\d{2})$/.exec(s.trim()); return m && +m[1] < 24 && +m[2] < 60 ? +m[1] * 60 + +m[2] : null; };
  const hhmm = n => `${String(Math.floor(n / 60) % 24).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;
  const clock = n => new Intl.DateTimeFormat(lang, { hour: "numeric", minute: "2-digit" })
    .format(new Date(2026, 0, 1, Math.floor(n / 60) % 24, n % 60));
  const nowMins = () => { const d = new Date(); return d.getHours() * 60 + d.getMinutes(); };

  // 블록 색: 앱처럼 hue 하나에 채도 · 명도는 고정 (HSB 0.62, 0.9 → HSL 74%, 62%)
  const blocks = [{ start: 600, dur: 60, notes: T.b1, hue: 216 }, { start: 670, dur: 50, notes: T.b2, hue: 160 }];
  const qs = T.qs.map(([t, text, r, a], i) => ({ id: i, t: mins(t), text, resolved: !!r, answered: !!a }));
  let nextHue = 30;

  root.innerHTML = `
    <div class="lq-stage">
      <p class="lq-title">${esc(T.lecture)}</p>
      <div class="lq-blocks"></div>
    </div>
    <div class="lq-side">
      <form class="lq-form">
        <label class="lq-label" for="lq-q">${esc(T.add)}</label>
        <textarea id="lq-q" rows="2" placeholder="${esc(T.ph)}">${esc(T.draft)}</textarea>
        <div class="lq-row">
          <label class="lq-time">${esc(T.time)} <input id="lq-t" value="11:52" inputmode="numeric" autocomplete="off" size="5"></label>
          <button type="button" class="lq-btn lq-now">${esc(T.now)}</button>
          <button type="submit" class="lq-btn lq-save">${esc(T.save)}</button>
        </div>
      </form>
      <ul class="lq-list" aria-live="polite"></ul>
      <p class="muted small">${esc(T.note)}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const blocksEl = $(".lq-blocks"), list = $(".lq-list"), input = $("#lq-q"), timeEl = $("#lq-t");
  const inBlock = (b, t) => t >= b.start && t <= b.start + b.dur;

  // 어느 블록에도 들지 않는 질문마다 블록을 하나씩 만든다 (앱과 같은 계산).
  function ensureCoverage() {
    for (const q of qs) {
      if (blocks.some(b => inBlock(b, q.t))) continue;
      const ends = blocks.map(b => b.start + b.dur).filter(e => e <= q.t);
      const starts = blocks.map(b => b.start).filter(s => s >= q.t);
      let start = q.t - 30, end = q.t + 30;
      if (ends.length && start < Math.max(...ends)) start = Math.max(...ends);
      if (starts.length && end > Math.min(...starts)) end = Math.min(...starts);
      if (start > q.t) start = q.t;
      if (end < q.t + 1) end = q.t + 1;
      blocks.push({ start, dur: Math.max(5, Math.ceil(end - start)), notes: "", hue: nextHue, fresh: true });
      nextHue = (nextHue + 97) % 360;
      blocks.sort((a, b) => a.start - b.start);
    }
  }

  const mark = q => `<button type="button" class="lq-q ${q.resolved ? "done" : "open"}${q.answered ? " filled" : ""}"
      data-id="${q.id}" aria-label="${esc(q.text)}, ${esc(q.resolved ? T.resolved : T.unresolved)}">?</button>`;

  function render(fresh) {
    blocksEl.innerHTML = blocks.map(b => `
      <div class="lq-block${b.fresh ? " fresh" : ""}" style="--h:${b.hue}">
        <div class="lq-gutter">
          <span>${clock(b.start)}</span>
          <div class="lq-line" style="min-height:${Math.max(84, b.dur * 4.2)}px">
            ${qs.filter(q => inBlock(b, q.t)).map(q =>
              `<span class="lq-pin" style="top:${((q.t - b.start) / b.dur) * 100}%">${mark(q)}</span>`).join("")}
          </div>
          <span>${clock(b.start + b.dur)}</span>
        </div>
        <div class="lq-card">${esc(b.notes)}</div>
      </div>`).join("");
    blocks.forEach(b => delete b.fresh);
    list.innerHTML = qs.map(q => `
      <li data-id="${q.id}" class="${q.id === fresh ? "fresh" : ""}">
        ${mark(q).replace('class="lq-q', 'aria-pressed="' + q.resolved + '" data-toggle class="lq-q')}
        <span class="lq-text">${esc(q.text)}</span><span class="lq-at">${hhmm(q.t)}</span>
      </li>`).join("");
    if (fresh != null) list.lastElementChild.scrollIntoView({ block: "nearest" });
  }

  $(".lq-form").addEventListener("submit", e => {
    e.preventDefault();
    const text = input.value.trim();
    if (!text) { input.focus(); return; }
    const q = { id: qs.length, t: mins(timeEl.value) ?? nowMins(), text, resolved: false, answered: false };
    qs.push(q);
    ensureCoverage();
    render(q.id);
    root.dataset.used = "1";
    input.value = "";
    input.focus();
  });
  // 앱처럼 Return 은 저장, Shift+Return 은 줄바꿈
  input.addEventListener("keydown", e => {
    if (e.key === "Enter" && !e.shiftKey && !e.isComposing) { e.preventDefault(); $(".lq-form").requestSubmit(); }
  });
  $(".lq-now").addEventListener("click", () => { timeEl.value = hhmm(nowMins()); });

  root.addEventListener("click", e => {
    const btn = e.target.closest(".lq-q");
    if (!btn) return;
    const q = qs[+btn.dataset.id];
    if (btn.hasAttribute("data-toggle")) {           // 목록의 ? : 해결 ↔ 미해결
      q.resolved = !q.resolved;
      render();
      list.querySelector(`[data-id="${q.id}"] .lq-q`).focus();
    } else {                                          // 블록 옆 ? : 그 질문으로 이동
      const li = list.querySelector(`li[data-id="${q.id}"]`);
      li.classList.remove("fresh"); void li.offsetWidth; li.classList.add("fresh");
      li.scrollIntoView({ block: "nearest" });
    }
  });

  render();
})();
