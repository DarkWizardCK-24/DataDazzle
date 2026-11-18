"""Generate the DataDazzle logo (SVG + PNG) and the platform app icons.

    python tool/make_logo.py

Writes assets/brand/:
  logo.svg / logo.png            rounded tile, transparent corners (logo.png is 512x512)
  icon-full.png                  full-bleed square, no transparency (1024px master
                                 used to cut the launcher icons)
  logo-horizontal.svg / .png     tile + "DataDazzle" wordmark
and overwrites the launcher icons for Android, iOS, web and Windows, keeping
each existing file's pixel size.
"""
import glob
import io
import os

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, 'assets', 'brand')

AMBER_1, AMBER_2 = '#FFE082', '#FFA000'


def tile(rounded=True):
    """The mark: a table (amber header row) with a sparkle, on a dark tile."""
    rx = 112 if rounded else 0
    cells = []
    x0, y0, cw, ch, gap = 110, 128, 88, 62, 14
    for r in range(4):
        for c in range(3):
            x = x0 + c * (cw + gap)
            y = y0 + r * (ch + gap)
            if r == 0:
                fill = 'url(#amber)'
            else:
                # soft diagonal fade so the grid feels lit from the sparkle
                a = 0.95 - 0.12 * (r - 1) - 0.06 * c
                fill = f'rgba(245,245,245,{a:.2f})'
            cells.append(
                f'<rect x="{x}" y="{y}" width="{cw}" height="{ch}" rx="14" fill="{fill}"/>'
            )
    return f'''
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#4a4a4a"/>
      <stop offset="0.55" stop-color="#1c1c1c"/>
      <stop offset="1" stop-color="#050505"/>
    </linearGradient>
    <linearGradient id="amber" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{AMBER_1}"/>
      <stop offset="1" stop-color="{AMBER_2}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#FFD54F" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#FFD54F" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="512" height="512" rx="{rx}" fill="url(#bg)"/>
  <rect x="3" y="3" width="506" height="506" rx="{max(rx - 3, 0)}" fill="none"
        stroke="rgba(255,255,255,0.16)" stroke-width="6"/>
  {''.join(cells)}
  <circle cx="378" cy="150" r="110" fill="url(#glow)"/>
  <!-- main sparkle -->
  <path d="M378 62 C386 118 410 142 466 150 C410 158 386 182 378 238
           C370 182 346 158 290 150 C346 142 370 118 378 62 Z"
        fill="#FFFFFF" stroke="{AMBER_1}" stroke-width="5" stroke-linejoin="round"/>
  <!-- small sparkle -->
  <path d="M440 232 C443 252 452 261 472 264 C452 267 443 276 440 296
           C437 276 428 267 408 264 C428 261 437 252 440 232 Z"
        fill="url(#amber)"/>'''


def svg(rounded=True):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
        'width="512" height="512">' + tile(rounded) + '</svg>'
    )


def horizontal_svg():
    """Tile + wordmark on its own dark plate, so it reads on any background."""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1800 512" width="1800" height="512">
  <rect width="1800" height="512" rx="112" fill="#0b0b0b"/>
  <rect x="3" y="3" width="1794" height="506" rx="109" fill="none"
        stroke="rgba(255,255,255,0.16)" stroke-width="6"/>
  <g>{tile(True)}</g>
  <text x="590" y="330" font-family="Segoe UI, Inter, Arial, sans-serif"
        font-weight="800" font-size="196" letter-spacing="-3">
    <tspan fill="#FFFFFF">Data</tspan><tspan fill="{AMBER_2}">Dazzle</tspan>
  </text>
</svg>'''


def render(page, svg_text, w, h, transparent=True):
    sized = svg_text.replace('<svg ', '<svg style="width:%dpx;height:%dpx" ' % (w, h), 1)
    page.set_viewport_size({'width': w, 'height': h})
    page.set_content(
        '<html><body style="margin:0;background:transparent">'
        '<div style="width:%dpx;height:%dpx">%s</div></body></html>' % (w, h, sized)
    )
    page.wait_for_timeout(300)
    png = page.screenshot(omit_background=transparent)
    return Image.open(io.BytesIO(png)).convert('RGBA')


def main():
    os.makedirs(BRAND, exist_ok=True)
    open(os.path.join(BRAND, 'logo.svg'), 'w', encoding='utf8').write(svg(True))
    open(os.path.join(BRAND, 'logo-horizontal.svg'), 'w', encoding='utf8').write(
        horizontal_svg()
    )
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch()
        except Exception:
            exe = sorted(glob.glob(os.path.join(os.environ.get('LOCALAPPDATA', ''), 'ms-playwright',
                                                'chromium-*', 'chrome-win*', 'chrome.exe')))[-1]
            browser = p.chromium.launch(executable_path=exe)
        page = browser.new_page()
        logo = render(page, svg(True), 1024, 1024)
        full = render(page, svg(False), 1024, 1024, transparent=False).convert('RGB')
        wide = render(page, horizontal_svg(), 1800, 512)
        browser.close()

    logo_512 = logo.resize((512, 512), Image.LANCZOS)
    assert logo_512.size == (512, 512)
    logo_512.save(os.path.join(BRAND, 'logo.png'), optimize=True)
    full.save(os.path.join(BRAND, 'icon-full.png'), optimize=True)
    wide.save(os.path.join(BRAND, 'logo-horizontal.png'), optimize=True)
    print('wrote assets/brand/*')

    # --- launcher icons: same file names/sizes as the existing ones ---------
    def resized(src, size):
        return src.resize((size, size), Image.LANCZOS)

    targets = []
    targets += glob.glob(os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'mipmap-*', 'ic_launcher.png'))
    targets += glob.glob(os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', '*.png'))
    targets += glob.glob(os.path.join(ROOT, 'web', 'icons', '*.png'))
    targets += [os.path.join(ROOT, 'web', 'favicon.png')]
    count = 0
    for path in targets:
        if not os.path.exists(path):
            continue
        with Image.open(path) as old:
            w, h = old.size
        is_maskable = 'maskable' in os.path.basename(path)
        if is_maskable:
            # keep the mark inside the maskable safe zone (centre 80%)
            canvas = Image.new('RGB', (w, h), (12, 12, 12))
            inner = int(w * 0.8)
            canvas.paste(resized(full, inner), ((w - inner) // 2, (h - inner) // 2))
            out = canvas
        elif 'ios' in path.replace('\\', '/').split('/ios/')[-1][:4] or '/ios/' in path.replace('\\', '/'):
            out = resized(full, w)  # iOS icons must not have transparency
        else:
            out = resized(logo if 'web' in path else full, w)
        if out.size != (w, h):
            out = out.resize((w, h), Image.LANCZOS)
        out.save(path)
        count += 1

    ico_path = os.path.join(ROOT, 'windows', 'runner', 'resources', 'app_icon.ico')
    if os.path.exists(ico_path):
        full.resize((256, 256), Image.LANCZOS).save(
            ico_path, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        )
        count += 1
    print(f'updated {count} platform icon files')


if __name__ == '__main__':
    main()
