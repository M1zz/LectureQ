#!/usr/bin/env python3
"""앱스토어(Mac) 스크린샷 합성: 배경 그라데이션 + 문구 + 앱 창 캡처 → 2880×1800 PNG.

usage: python3 compose.py <raw_dir> <out_dir>
raw_dir 에는 capture.sh 가 만든 <screen>.png (창 캡처, 투명 모서리) 가 있어야 한다.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2880, 1800
TOP = (28, 84, 212)       # 앱 아이콘 파랑
BOTTOM = (22, 170, 178)   # 앱 아이콘 청록

# (파일 순서, 화면 이름, 제목, 부제)
SHOTS = [
    ("01", "main", "강의 중 떠오른 질문, 흘려보내지 마세요",
     "질문 · 시간별 메모 · 내 말로 정리한 답을 한 화면에"),
    ("02", "capture", "떠오른 순간, 단축키 한 번으로 기록",
     "강의 시점이 자동으로 찍혀 타임블록에 자리를 잡아요"),
    ("03", "summary", "강의가 끝나면 던질 질문과 배운 점만 남아요",
     "해결한 질문의 답이 그대로 복습 노트가 됩니다"),
    ("04", "graph", "원질문에서 꼬리질문까지 한눈에",
     "생각이 어디서 어디로 뻗어갔는지 그래프로 확인하세요"),
    ("05", "timeline", "시간 블록 위에 질문이 쌓여요",
     "언제 무엇을 배웠고 어디서 막혔는지 시간순으로"),
    ("06", "state", "듣기 전에, 무엇을 배우고 싶은지 먼저",
     "지금의 나와 강의를 마친 나를 적어두고 비교해 보세요"),
]

FONT_DIRS = [os.path.expanduser("~/Library/Fonts"), "/Library/Fonts"]


def font(name, size):
    for d in FONT_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    # Pretendard 가 없으면 시스템 한글 폰트
    return ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", size)


def background():
    mask = Image.linear_gradient("L").resize((W, H))
    return Image.composite(Image.new("RGB", (W, H), BOTTOM),
                           Image.new("RGB", (W, H), TOP), mask).convert("RGBA")


def shadow_for(win, blur=48, opacity=0.38):
    """창 알파 모양 그대로의 부드러운 그림자 (속도를 위해 1/4 크기에서 블러)."""
    k = 4
    small = win.split()[3].resize((win.width // k, win.height // k))
    pad = blur // k * 3
    canvas = Image.new("L", (small.width + pad * 2, small.height + pad * 2), 0)
    canvas.paste(small.point(lambda a: int(a * opacity)), (pad, pad))
    canvas = canvas.filter(ImageFilter.GaussianBlur(blur // k))
    canvas = canvas.resize((canvas.width * k, canvas.height * k), Image.LANCZOS)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 255))
    shadow.putalpha(canvas)
    return shadow, pad * k


def centered(draw, y, text, fnt, fill):
    l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
    draw.text(((W - (r - l)) / 2 - l, y - t), text, font=fnt, fill=fill)
    return y + (b - t)


def compose(raw_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    title_font = font("Pretendard-Bold.otf", 108)
    sub_font = font("Pretendard-Medium.otf", 50)

    for num, screen, title, subtitle in SHOTS:
        src = os.path.join(raw_dir, f"{screen}.png")
        if not os.path.exists(src):
            print(f"skip {screen} (no capture)")
            continue

        img = background()
        draw = ImageDraw.Draw(img)
        y = centered(draw, 150, title, title_font, (255, 255, 255, 255))
        centered(draw, y + 44, subtitle, sub_font, (255, 255, 255, 215))

        win = Image.open(src).convert("RGBA")
        target_w = 2360
        scale = target_w / win.width
        win = win.resize((target_w, round(win.height * scale)), Image.LANCZOS)
        x, top = (W - win.width) // 2, 440   # 아래쪽은 캔버스 밖으로 살짝 잘려 나가게

        shadow, pad = shadow_for(win)
        # 캔버스 밖으로 나가는 부분은 잘라서 합성
        sy = top - pad + 24
        shadow = shadow.crop((0, 0, shadow.width, min(shadow.height, H - sy)))
        img.alpha_composite(shadow, (x - pad, sy))
        img.paste(win, (x, top), win)

        out = os.path.join(out_dir, f"{num}_{screen}.png")
        img.convert("RGB").save(out, optimize=True)
        print(out)


if __name__ == "__main__":
    compose(sys.argv[1], sys.argv[2])
