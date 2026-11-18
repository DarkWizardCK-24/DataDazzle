"""Compose the 1920x1080 promo thumbnails in docs/thumbnails/.

    python tool/make_thumbnails.py

Needs docs/screenshots/*.png (tool/capture_screenshots.py) and
assets/brand/logo.png (tool/make_logo.py). Pages are plain HTML rendered with
Playwright, with every image embedded, so the output is reproducible.
Writes datadazzle-thumb-1-hero.png, -2-devices.png, -3-gallery.png.
"""
import base64
import glob
import io
import os

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, 'docs', 'screenshots')
OUT = os.path.join(ROOT, 'docs', 'thumbnails')

TITLE = 'DataDazzle'
TAGLINE = 'Design your tables. Own your data.'
BLURB = 'Build custom tables, capture records with generated forms, and move data in and out as CSV, Excel or ODS.'


def data_uri(path, max_w=640, fmt='JPEG'):
    """Downscale + embed an image (keeps the HTML small)."""
    with Image.open(path) as im:
        im = im.convert('RGB')
        if im.width > max_w:
            im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, fmt, quality=90)
    mime = 'image/jpeg' if fmt == 'JPEG' else 'image/png'
    return f'data:{mime};base64,' + base64.b64encode(buf.getvalue()).decode()


def logo_uri():
    p = os.path.join(ROOT, 'assets', 'brand', 'logo.png')
    with open(p, 'rb') as f:
        return 'data:image/png;base64,' + base64.b64encode(f.read()).decode()


def shot(name, **kw):
    return data_uri(os.path.join(SHOTS, name + '.png'), **kw)


CSS = '''
* { box-sizing: border-box; margin: 0; }
html, body { width: 1920px; height: 1080px; overflow: hidden; }
body {
  font-family: "Segoe UI", Inter, Arial, sans-serif; color: #fff; position: relative;
  background:
    radial-gradient(900px 700px at 78% 30%, rgba(255,193,7,0.18), transparent 60%),
    radial-gradient(700px 600px at 8% 95%, rgba(255,160,0,0.10), transparent 60%),
    linear-gradient(135deg, #060606 0%, #151515 45%, #2c2c2c 100%);
}
/* faint spreadsheet grid, like the app's own table view */
body::before {
  content: ""; position: absolute; inset: 0;
  background-image:
    linear-gradient(rgba(255,255,255,0.045) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.045) 1px, transparent 1px);
  background-size: 96px 64px;
  -webkit-mask-image: linear-gradient(135deg, transparent 5%, #000 55%, #000 100%);
  mask-image: linear-gradient(135deg, transparent 5%, #000 55%, #000 100%);
}
.abs { position: absolute; }
.spark { position: absolute; width: 56px; height: 56px; }
.logo { border-radius: 24%; box-shadow: 0 18px 50px rgba(0,0,0,.55), 0 0 60px rgba(255,193,7,.25); }
h1 { font-weight: 800; letter-spacing: -3px; line-height: 1; }
h1 b { color: #FFA000; font-weight: 800; }
.tag { color: #FFC107; font-weight: 700; }
.blurb { color: rgba(255,255,255,.72); line-height: 1.4; }
.pills { display: flex; flex-wrap: wrap; gap: 14px; width: 650px; }
.pill {
  display: inline-flex; align-items: center; gap: 12px; padding: 10px 22px;
  border-radius: 999px; border: 2px solid rgba(255,255,255,.18);
  background: rgba(255,255,255,.06); font-size: 26px; font-weight: 600;
}
.pill i { width: 12px; height: 12px; border-radius: 50%; background: #FFC107; display: block; }
.chip { display: inline-flex; align-items: center; gap: 12px; padding: 12px 26px;
  border-radius: 999px; background: #FFC107; color: #111; font-weight: 800; font-size: 26px; white-space: nowrap; }
.chip i { width: 12px; height: 12px; border-radius: 50%; background: #111; display: block; }
.plat { white-space: nowrap; font-size: 25px; font-weight: 600; color: rgba(255,255,255,.7); letter-spacing: .5px; }
.phone {
  position: absolute; background: #0a0a0a; border-radius: 68px; padding: 14px;
  box-shadow: 0 0 0 3px #3a3a3a, 0 40px 90px rgba(0,0,0,.65), 0 0 0 1px #000 inset;
}
.phone .scr { position: relative; border-radius: 54px; overflow: hidden; background: #000; width: 100%; height: 100%; padding-top: 46px; }
.phone img { width: 100%; height: 100%; object-fit: cover; object-position: top; display: block; }
.phone .notch { position: absolute; top: 14px; left: 50%; transform: translateX(-50%);
  width: 32%; height: 26px; background: #000; border-radius: 99px; z-index: 2; }
.laptop-screen {
  position: absolute; background: #0a0a0a; border-radius: 26px; padding: 14px;
  box-shadow: 0 0 0 3px #3a3a3a, 0 40px 90px rgba(0,0,0,.6);
}
.laptop-screen img { width: 100%; height: 100%; object-fit: cover; object-position: top left; display: block; border-radius: 12px; }
.laptop-base { position: absolute; height: 22px; border-radius: 0 0 26px 26px;
  background: linear-gradient(#4a4a4a, #222); box-shadow: 0 30px 50px rgba(0,0,0,.5); }
.card {
  position: absolute; display: flex; align-items: center; gap: 22px; padding: 22px 34px 22px 22px;
  border-radius: 28px; background: rgba(24,24,24,.92); border: 2px solid rgba(255,255,255,.14);
  box-shadow: 0 24px 60px rgba(0,0,0,.55); z-index: 5; backdrop-filter: blur(6px);
}
.card .ic { width: 78px; height: 78px; border-radius: 20px; display: grid; place-items: center; }
.card small { display: block; font-size: 26px; color: rgba(255,255,255,.6); letter-spacing: .5px; }
.card strong { display: block; font-size: 42px; font-weight: 800; letter-spacing: -.5px; }
'''

SPARK = ('<svg class="spark" style="{s}" viewBox="0 0 100 100"><path d="M50 2 C54 38 62 46 98 50 '
         'C62 54 54 62 50 98 C46 62 38 54 2 50 C38 46 46 38 50 2 Z" fill="#FFC107" opacity=".9"/></svg>')

ICON_CHECK = ('<svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3.2" '
              'stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>')
ICON_UNDO = ('<svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.8" '
             'stroke-linecap="round" stroke-linejoin="round"><path d="M9 7L4 12l5 5"/><path d="M4 12h10a6 6 0 0 1 0 12" '
             'transform="translate(0 -6)"/></svg>')
ICON_SHIELD = ('<svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.6" '
               'stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>'
               '<path d="M8.5 12l2.5 2.5L16 9.5"/></svg>')
ICON_SORT = ('<svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.8" '
             'stroke-linecap="round" stroke-linejoin="round"><path d="M7 4v16M3 16l4 4 4-4M17 20V4M13 8l4-4 4 4"/></svg>')


def card(style, icon, bg, small, strong):
    return (f'<div class="card" style="{style}"><div class="ic" style="background:{bg}">{icon}</div>'
            f'<div><small>{small}</small><strong>{strong}</strong></div></div>')


def phone(img, left, top, w, rot=0, z=1):
    """Phone whose screen keeps the screenshot's 1170:2532 aspect."""
    inner_w = w - 28
    h = round(inner_w * 2532 / 1170) + 28
    return (f'<div class="phone" style="left:{left}px;top:{top}px;width:{w}px;height:{h}px;'
            f'transform:rotate({rot}deg);z-index:{z}"><div class="scr"><div class="notch"></div>'
            f'<img src="{img}"></div></div>')


def left_block(top_logo, big=True):
    logo = logo_uri()
    t = top_logo
    return f'''
  <img class="logo abs" src="{logo}" style="left:110px;top:{t}px;width:170px;height:170px">
  <h1 class="abs" style="left:104px;top:{t + 195}px;font-size:132px;white-space:nowrap">Data<b>Dazzle</b></h1>
  <div class="tag abs" style="left:110px;top:{t + 360}px;font-size:44px;white-space:nowrap">{TAGLINE}</div>
  <div class="blurb abs" style="left:110px;top:{t + 440}px;width:820px;font-size:30px">{BLURB}</div>
  <div class="pills abs" style="left:110px;top:{t + 600}px">
    <span class="pill"><i></i>Custom tables</span><span class="pill"><i></i>Search, sort &amp; filter</span>
    <span class="pill"><i></i>Field rules</span><span class="pill"><i></i>Bulk delete + undo</span>
  </div>
  <div class="abs" style="left:110px;top:{t + 765}px;display:flex;align-items:center;gap:24px">
    <span class="chip"><i></i>Built with Flutter</span>
    <span class="plat">Android &nbsp;·&nbsp; iOS &nbsp;·&nbsp; Windows &nbsp;·&nbsp; Web</span>
  </div>'''


def hero():
    body = (
        left_block(70)
        + SPARK.format(s='left:930px;top:90px;')
        + SPARK.format(s='left:850px;top:975px;width:40px;height:40px')
        + SPARK.format(s='left:1840px;top:300px;width:44px;height:44px')
        + phone(shot('mobile-tables'), 1000, 250, 360, rot=-9, z=1)
        + phone(shot('mobile-search-sort'), 1500, 230, 360, rot=8, z=1)
        + phone(shot('mobile-multi-select'), 1230, 100, 430, rot=0, z=3)
        + card('left:1290px;top:2px', ICON_CHECK, '#2e9d4f', 'Import report', '12 in · 3 skipped')
        + card('left:880px;top:880px', ICON_UNDO, '#FFC107', 'Row deleted', 'UNDO')
    )
    return body


def devices():
    body = (
        left_block(70)
        + SPARK.format(s='left:760px;top:140px;width:44px;height:44px')
        + SPARK.format(s='left:1830px;top:70px;')
        + '<div class="laptop-screen" style="left:960px;top:200px;width:820px;height:560px">'
          f'<img src="{shot("desktop-table-view", max_w=1400)}"></div>'
        + '<div class="laptop-base" style="left:910px;top:760px;width:920px"></div>'
        + phone(shot('mobile-field-rules'), 1560, 330, 330, rot=0, z=3)
        + card('left:1000px;top:860px', ICON_SHIELD, '#FFC107', 'Field rules', 'Required · Unique')
        + card('left:1060px;top:70px', ICON_SORT, '#FFC107', 'Tap a header', 'Sort any column')
    )
    return body


def gallery():
    logo = logo_uri()
    specs = [
        ('mobile-tables', 90, 520, 320, -0),
        ('mobile-search-sort', 440, 470, 330, 0),
        ('mobile-multi-select', 780, 340, 360, 0),
        ('mobile-filter', 1150, 470, 330, 0),
        ('mobile-field-rules', 1500, 520, 320, 0),
    ]
    phones = ''.join(phone(shot(n), x, y, w, rot=r, z=1) for n, x, y, w, r in specs)
    body = f'''
  <img class="logo abs" src="{logo}" style="left:640px;top:60px;width:130px;height:130px">
  <h1 class="abs" style="left:800px;top:70px;font-size:132px">Data<b>Dazzle</b></h1>
  <div class="tag abs" style="left:0;top:225px;width:1920px;text-align:center;font-size:54px">{TAGLINE}</div>
  {SPARK.format(s='left:120px;top:100px;')}
  {SPARK.format(s='left:1760px;top:200px;width:44px;height:44px')}
  {phones}'''
    return body


PAGES = {
    'datadazzle-thumb-1-hero.png': hero,
    'datadazzle-thumb-2-devices.png': devices,
    'datadazzle-thumb-3-gallery.png': gallery,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch()
        except Exception:
            exe = sorted(glob.glob(os.path.join(os.environ.get('LOCALAPPDATA', ''), 'ms-playwright',
                                                'chromium-*', 'chrome-win*', 'chrome.exe')))[-1]
            browser = p.chromium.launch(executable_path=exe)
        page = browser.new_page(viewport={'width': 1920, 'height': 1080})
        for name, build in PAGES.items():
            page.set_content(f'<html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{build()}</body></html>')
            page.wait_for_timeout(500)
            path = os.path.join(OUT, name)
            page.screenshot(path=path)
            with Image.open(path) as im:
                assert im.size == (1920, 1080), im.size
            print('saved', path)
        browser.close()


if __name__ == '__main__':
    main()
