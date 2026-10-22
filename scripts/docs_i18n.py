#!/usr/bin/env python3
"""docs/ 웹 페이지의 언어 연결을 채운다.

한국어는 docs/*.html (루트), 나머지 언어는 docs/<로케일>/*.html.
각 페이지의 `<!--HREFLANG-->` 자리(또는 이전에 채운 블록)에 canonical·hreflang 링크를,
`<!--LANGSWITCH-->` 자리에 언어 전환 링크를 넣는다. 여러 번 돌려도 같은 결과.

usage: python3 scripts/docs_i18n.py
"""
import os
import re

BASE = "https://m1zz.github.io/LectureQ/"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs")
PAGES = ["index.html", "privacy.html", "support.html", "ai-guide.html"]
# (로케일 폴더, hreflang, 그 언어로 쓴 이름)
LANGS = [
    ("", "ko", "한국어"), ("en", "en", "English"), ("en-GB", "en-GB", "English (UK)"),
    ("zh-Hans", "zh-Hans", "简体中文"), ("zh-Hant", "zh-Hant", "繁體中文"), ("ja", "ja", "日本語"),
    ("ru", "ru", "Русский"), ("es", "es", "Español"), ("de", "de", "Deutsch"), ("fr", "fr", "Français"),
    ("it", "it", "Italiano"), ("pt-BR", "pt-BR", "Português (Brasil)"), ("th", "th", "ไทย"),
    ("vi", "vi", "Tiếng Việt"), ("cs", "cs", "Čeština"), ("da", "da", "Dansk"), ("el", "el", "Ελληνικά"),
    ("fi", "fi", "Suomi"), ("id", "id", "Bahasa Indonesia"), ("nb", "nb", "Norsk bokmål"),
    ("nl", "nl", "Nederlands"), ("pl", "pl", "Polski"), ("sv", "sv", "Svenska"), ("tr", "tr", "Türkçe"),
]

HEAD_RE = re.compile(r"<!--HREFLANG-->|<!--hreflang:start-->.*?<!--hreflang:end-->", re.S)
SWITCH_RE = re.compile(r"<!--LANGSWITCH-->|<!--langswitch:start-->.*?<!--langswitch:end-->", re.S)
SWITCH_CSS = ("<style>.langs{display:flex;flex-wrap:wrap;gap:4px 12px;font-size:13px;margin:0 0 18px;}"
              ".langs a{color:var(--muted);text-decoration:none;}.langs a[aria-current]{color:var(--fg);font-weight:600;}"
              ".langs a:hover{color:var(--teal);}</style>")


def url(folder, page):
    name = "" if page == "index.html" else page
    return BASE + (folder + "/" if folder else "") + name


def rel(from_folder, to_folder, page):
    up = "../" if from_folder else "./"
    return up + (to_folder + "/" if to_folder else "") + page


def main():
    for folder, _, _ in LANGS:
        for page in PAGES:
            path = os.path.join(ROOT, folder, page)
            if not os.path.exists(path):
                raise SystemExit(f"없음: {path}")
            s = open(path, encoding="utf-8").read()
            head = [f'<link rel="canonical" href="{url(folder, page)}">']
            head += [f'<link rel="alternate" hreflang="{h}" href="{url(f, page)}">' for f, h, _ in LANGS]
            head.append(f'<link rel="alternate" hreflang="x-default" href="{url("", page)}">')
            head_block = "<!--hreflang:start-->\n" + "\n".join(head) + "\n" + SWITCH_CSS + "\n<!--hreflang:end-->"
            links = []
            for f, h, label in LANGS:
                cur = ' aria-current="page"' if f == folder else ""
                links.append(f'<a href="{rel(folder, f, page)}" hreflang="{h}" lang="{h}"{cur}>{label}</a>')
            switch = ('<!--langswitch:start--><nav class="langs" aria-label="Language">'
                      + " ".join(links) + "</nav><!--langswitch:end-->")
            if not HEAD_RE.search(s) or not SWITCH_RE.search(s):
                raise SystemExit(f"자리 표시가 없음: {path}")
            s = HEAD_RE.sub(lambda _: head_block, s, count=1)
            s = SWITCH_RE.sub(lambda _: switch, s, count=1)
            open(path, "w", encoding="utf-8").write(s)
    print(f"{len(LANGS)} 언어 × {len(PAGES)} 페이지")


if __name__ == "__main__":
    main()
