#!/usr/bin/env python3
"""App Store 크리에이티브 자산(제품 페이지 헤더 · 검색 결과) 생성: HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_creative_assets.py [언어 ...]     (없으면 표에 있는 언어 전부)

자리 (DeployBar 가 배포 · --publish 때 iOS 페이지에 올린다)
  docs/screenshots/creative/<언어>/header.png   3840x1646  제품 페이지 맨 위
  docs/screenshots/creative/<언어>/search.png   3840x2560  검색 결과 (없으면 스크린샷이 대신 보인다)

⚠️ 안전 영역 밖은 기기에 따라 잘린다. 글은 반드시 안전 영역 안에 둔다(배경 · 기기 그림은 넘쳐도 된다).
   수치는 Apple 공식 PSD 템플릿에서 잰 값이다(https://developer.apple.com/app-store/asset-best-practices/).
   아이폰에서 헤더는 가운데만 남고, 검색 결과는 약 385pt 폭으로 줄어 보인다. 그래서 글이 크다.
⚠️ 가격 · 할인 · 주소(URL) · 수상 · 다른 플랫폼 이름은 넣지 않는다(Apple 가이드).
기기 화면은 스토어 스크린샷(docs/screenshots/marketing/<언어>/iphone-*.png)을 그대로 쓴다 — 같은 이야기가 이어지게.
"""
import subprocess, sys, pathlib, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots" / "marketing"
OUT = ROOT / "docs" / "screenshots" / "creative"
ICON = ROOT / "docs" / "screenshots" / "app-icon.png"   # LectureQ/AppIcon.icon 을 ictool 로 뽑은 것
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# (가로, 세로, 안전 영역 left, top, right, bottom)
SPEC = {
    "header": (3840, 1646, (1097, 493, 2743, 1154)),
    "search": (3840, 2560, (836, 765, 3004, 1795)),
}

# 헤더는 처음 온 사람에게 한 가지 약속만 한다: 강의 중 생긴 궁금증이 배운 점이 된다(부제와 같은 약속).
# 눈썹글은 앱 이름.
HEADER = {
    "ko":      ("질문노트", "강의 중 떠오른 질문을<br>배운 점으로"),
    "en":      ("LectureQ", "Turn lecture questions<br>into real learning"),
    "en-GB":   ("LectureQ", "Turn lecture questions<br>into real learning"),
    "zh-Hans": ("LectureQ", "听课时的疑问，<br>都变成收获"),
    "zh-Hant": ("LectureQ", "上課時的疑問，<br>都變成收穫"),
    "ja":      ("LectureQ", "講義中の疑問を、<br>学びに変える"),
    "ru":      ("LectureQ", "Вопросы с лекции<br>становятся знанием"),
    "es":      ("LectureQ", "Tus dudas de clase,<br>convertidas en aprendizaje"),
    "de":      ("LectureQ", "Fragen aus der Vorlesung<br>werden zu Wissen"),
    "fr":      ("LectureQ", "Vos questions de cours<br>deviennent savoir"),
    "it":      ("LectureQ", "Le domande a lezione<br>diventano sapere"),
    "pt-BR":   ("LectureQ", "Dúvidas da aula<br>viram aprendizado"),
    "th":      ("LectureQ", "ข้อสงสัยในคลาส<br>กลายเป็นความรู้"),
    "vi":      ("LectureQ", "Thắc mắc trong giờ học<br>thành kiến thức"),
    "cs":      ("LectureQ", "Otázky z přednášky<br>se mění ve znalosti"),
    "da":      ("LectureQ", "Spørgsmål fra timen<br>bliver til viden"),
    "el":      ("LectureQ", "Οι απορίες του μαθήματος<br>γίνονται γνώση"),
    "fi":      ("LectureQ", "Luennon kysymykset<br>muuttuvat osaamiseksi"),
    "id":      ("LectureQ", "Pertanyaan saat kuliah<br>jadi ilmu"),
    "nb":      ("LectureQ", "Spørsmål fra forelesningen<br>blir til kunnskap"),
    "nl":      ("LectureQ", "Vragen tijdens college<br>worden kennis"),
    "pl":      ("LectureQ", "Pytania z wykładu<br>zamieniasz w wiedzę"),
    "sv":      ("LectureQ", "Frågor från föreläsningen<br>blir kunskap"),
    "tr":      ("LectureQ", "Dersteki sorular<br>bilgiye dönüşür"),
}

# 검색 결과는 스크린샷 1장(질문 목록)과 같은 이야기다. 눈썹글은 그 나라 사람이 검색창에 치는 말.
SEARCH = {
    "ko":      ("강의 필기", "궁금한 건<br>그 시점에 적어 두기", "강의 시각과 함께 질문이 차곡차곡 쌓여요"),
    "en":      ("Lecture notes", "Note it now,<br>ask it later", "Every question keeps its moment in the lecture"),
    "en-GB":   ("Lecture notes", "Note it now,<br>ask it later", "Every question keeps its moment in the lecture"),
    "zh-Hans": ("听课笔记", "有疑问，<br>当场记下来", "问题按讲课时间整齐排好"),
    "zh-Hant": ("上課筆記", "有疑問，<br>當場記下來", "問題依上課時間整齊排好"),
    "ja":      ("講義ノート", "気になったら<br>その場でメモ", "質問が講義の時刻と一緒にたまっていく"),
    "ru":      ("Конспект лекций", "Запишите вопрос<br>прямо на лекции", "Каждый вопрос — с моментом лекции"),
    "es":      ("Apuntes de clase", "Anota la duda<br>en el momento", "Cada pregunta guarda el minuto de la clase"),
    "de":      ("Vorlesungsnotizen", "Fragen notieren,<br>sobald sie kommen", "Jede Frage mit dem Moment der Vorlesung"),
    "fr":      ("Notes de cours", "Notez la question<br>sur le moment", "Chaque question garde l’instant du cours"),
    "it":      ("Appunti di lezione", "Annota il dubbio<br>sul momento", "Ogni domanda con il minuto della lezione"),
    "pt-BR":   ("Anotações de aula", "Anote a dúvida<br>na hora", "Cada pergunta guarda o momento da aula"),
    "th":      ("จดเลคเชอร์", "สงสัยตรงไหน<br>จดไว้ตรงนั้น", "คำถามเรียงตามเวลาในคลาส"),
    "vi":      ("Ghi chép bài giảng", "Thắc mắc là<br>ghi ngay", "Câu hỏi xếp theo thời điểm của bài giảng"),
    "cs":      ("Poznámky z přednášek", "Zapište otázku<br>hned na místě", "Každá otázka i s časem přednášky"),
    "da":      ("Forelæsningsnoter", "Skriv spørgsmålet<br>ned med det samme", "Hvert spørgsmål med tidspunktet i timen"),
    "el":      ("Σημειώσεις μαθήματος", "Γράψε την απορία<br>επί τόπου", "Κάθε ερώτηση με τη στιγμή του μαθήματος"),
    "fi":      ("Luentomuistiinpanot", "Kirjaa kysymys<br>heti kun se herää", "Jokainen kysymys luennon hetken kanssa"),
    "id":      ("Catatan kuliah", "Ada yang bingung?<br>Catat saat itu juga", "Pertanyaan tersusun sesuai waktu kuliah"),
    "nb":      ("Forelesningsnotater", "Skriv ned spørsmålet<br>med en gang", "Hvert spørsmål med tidspunktet i timen"),
    "nl":      ("Collegeaantekeningen", "Noteer je vraag<br>meteen", "Elke vraag met het moment in het college"),
    "pl":      ("Notatki z wykładów", "Zapisz pytanie<br>od razu", "Każde pytanie z chwilą wykładu"),
    "sv":      ("Föreläsningsanteckningar", "Skriv ner frågan<br>direkt", "Varje fråga med tidpunkten i föreläsningen"),
    "tr":      ("Ders notları", "Aklına geleni<br>o an yaz", "Sorular ders saatiyle birlikte sıralanır"),
}

# ⚠️ 색은 앱과 같다: 밝은 바탕, 강조색은 아이콘의 남색(AccentColor, 시스템 Indigo).
BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:#f4f4f9; position:relative;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "Thonburi", sans-serif; }
.glow { position:absolute; border-radius:50%%; filter:blur(180px); pointer-events:none; }
.text { position:absolute; display:flex; flex-direction:column; justify-content:center; }
.eyebrow { font-weight:700; color:#5e5ce6; letter-spacing:-0.01em; line-height:1.15; display:flex; align-items:center; gap:.4em; }
.eyebrow img { height:1.25em; width:1.25em; }
.headline { font-weight:800; color:#1c1c1e; letter-spacing:-0.03em; line-height:1.14; text-wrap:balance; }
.sub { font-weight:500; color:#6e6e76; letter-spacing:-0.01em; line-height:1.35; text-wrap:balance; }
:lang(th) .headline, :lang(th) .eyebrow, :lang(th) .sub,
:lang(ja) .headline, :lang(zh) .headline { letter-spacing:0; }
:lang(th) .headline { line-height:1.3; }
:lang(ko) .headline, :lang(ko) .sub, :lang(ko) .eyebrow { word-break:keep-all; }
.phone { position:absolute; background:#1c1c1e; padding:26px; border-radius:170px;
  box-shadow: 0 70px 160px rgba(40,38,120,.22), 0 0 0 3px #3a3a3e inset; }
.phone img { width:100%%; display:block; border-radius:146px; }
"""

# 글이 상자를 넘지 않을 때까지 줄인다. 끝까지 안 맞으면 표시하고 멈춘다(잘린 글을 올리지 않는다).
FIT_JS = """
<script>
function lines(el) {
  return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight));
}
function fit(box, el, max, min) {
  const want = el.querySelectorAll('br').length + 1;
  let size = max;
  el.style.fontSize = size + 'px';
  while (size > min && (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 ||
         lines(el) > want)) {
    size -= 4; el.style.fontSize = size + 'px';
  }
  if (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 || lines(el) > want)
    document.body.dataset.overflow = '1';
}
document.fonts.ready.then(() => {
  const box = document.querySelector('.text');
  const h = document.querySelector('.headline');
  for (const el of document.querySelectorAll('.eyebrow, .sub')) {
    let size = parseFloat(getComputedStyle(el).fontSize);
    while (size > 48 && el.scrollWidth > box.clientWidth + 1) { size -= 4; el.style.fontSize = size + 'px'; }
  }
  fit(box, h, +h.dataset.max, +h.dataset.min);
  document.body.dataset.done = '1';
});
</script>
"""


def phone(img, left, top, width, rotate=0):
    return (f'<div class="phone" style="left:{left}px;top:{top}px;width:{width}px;'
            f'transform:rotate({rotate}deg)"><img src="{img}"></div>')


def shot(lang, name):
    p = SHOTS / lang / f"{name}.png"
    if not p.exists():
        raise SystemExit(f"스크린샷이 없다: {p} — scripts/capture_ios.sh 로 먼저 찍을 것")
    return p.as_uri()


def search_html(lang):
    W, H, (l, t, r, b) = SPEC["search"]
    eyebrow, headline, sub = SEARCH[lang]
    sw, sh = r - l, b - t
    col = int(sw * 0.58)
    ph_w = 1000
    ph_left = l + col + int(sw * 0.04)
    return f"""
<div class="glow" style="left:{ph_left - 400}px;top:300px;width:1900px;height:1900px;background:rgba(94,92,230,.20)"></div>
<div class="glow" style="left:{l - 700}px;top:{t - 500}px;width:1400px;height:1000px;background:rgba(94,92,230,.08)"></div>
{phone(shot(lang, "iphone-01-list"), ph_left, t - 380, ph_w)}
<div class="text" style="left:{l}px;top:{t}px;width:{col}px;height:{sh}px">
  <div class="eyebrow" style="font-size:100px">{eyebrow}</div>
  <div class="headline" data-max="230" data-min="130" style="margin-top:36px">{headline}</div>
  <div class="sub" style="font-size:84px;margin-top:52px">{sub}</div>
</div>"""


def header_html(lang):
    W, H, (l, t, r, b) = SPEC["header"]
    eyebrow, headline = HEADER[lang]
    sw, sh = r - l, b - t
    return f"""
<div class="glow" style="left:{l - 200}px;top:{t - 400}px;width:{sw + 400}px;height:{sh + 800}px;background:rgba(94,92,230,.14)"></div>
{phone(shot(lang, "iphone-01-list"), 330, 300, 620, -8)}
{phone(shot(lang, "iphone-02-main"), 2890, 300, 620, 8)}
<div class="text" style="left:{l}px;top:{t}px;width:{sw}px;height:{sh}px;align-items:center;text-align:center">
  <div class="eyebrow" style="font-size:80px"><img src="{ICON.as_uri()}">{eyebrow}</div>
  <div class="headline" data-max="190" data-min="100" style="margin-top:30px">{headline}</div>
</div>"""


def render(lang, kind):
    W, H, _ = SPEC[kind]
    body = search_html(lang) if kind == "search" else header_html(lang)
    page = (f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>'
            f'{BASE_CSS % {"W": W, "H": H}}</style></head><body>{body}{FIT_JS}</body></html>')
    html_path = pathlib.Path(tempfile.gettempdir()) / f"lectureq-creative-{lang}-{kind}.html"
    html_path.write_text(page, encoding="utf-8")
    flags = [f"--window-size={W},{H}", "--force-device-scale-factor=1", "--disable-gpu",
             "--virtual-time-budget=3000", "--allow-file-access-from-files"]
    dom = subprocess.run([CHROME, "--headless=new", "--dump-dom", *flags, html_path.as_uri()],
                         capture_output=True, text=True, timeout=90).stdout
    if 'data-done="1"' not in dom:
        raise SystemExit(f"글 맞추기가 끝나지 않았다: {lang} {kind}")
    if 'data-overflow="1"' in dom:
        raise SystemExit(f"글이 안전 영역을 넘는다: {lang} {kind} — 문구를 줄일 것")
    out_dir = OUT / lang
    out_dir.mkdir(parents=True, exist_ok=True)
    out_png = out_dir / f"{kind}.png"
    for _ in range(3):   # Chrome 은 가끔 아무것도 안 그리고 끝난다
        try:
            r = subprocess.run([CHROME, "--headless=new", f"--screenshot={out_png}", "--hide-scrollbars",
                                *flags, html_path.as_uri()], capture_output=True, timeout=90)
        except subprocess.TimeoutExpired:
            continue
        if r.returncode == 0 and out_png.exists():
            break
    else:
        raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
    # 알파 채널이 있으면 애플이 거절한다 — RGB 로 다시 저장
    subprocess.run(["python3", "-c", "import sys;from PIL import Image;"
                    "Image.open(sys.argv[1]).convert('RGB').save(sys.argv[1])", str(out_png)], check=True)
    print(f"rendered {out_png.relative_to(ROOT)}")


if __name__ == "__main__":
    langs = sys.argv[1:] or list(HEADER)
    for lang in langs:
        if lang not in HEADER or lang not in SEARCH:
            raise SystemExit(f"문구가 없는 언어: {lang}")
        for kind in ("header", "search"):
            render(lang, kind)
