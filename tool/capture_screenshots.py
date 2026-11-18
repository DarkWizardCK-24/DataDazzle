"""Capture README / portfolio screenshots of the DataDazzle web demo.

    flutter build web --release --dart-define=DEMO=true
    python tool/capture_screenshots.py            # serves build/web itself

Options: --port 8737   --no-serve (use an already running server on --port)
Writes docs/screenshots/{mobile,tablet,desktop}-<screen>.png and a small
docs/screenshots/thumbs/<same name>.png for each (used by the README).
Use --thumbs-only to rebuild just the thumbnails from existing screenshots.
The demo build picks the screen from query params: ?route=<route>&table=<n>
(routes: home, tables, data, cards, add, edit-row, detail, create, edit,
search, filter, select, undo, rules).
"""
import argparse
import functools
import glob
import http.server
import os
import threading
import time

from playwright.sync_api import sync_playwright
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, 'build', 'web')
OUT = os.path.join(ROOT, 'docs', 'screenshots')
THUMBS = os.path.join(OUT, 'thumbs')
THUMB_WIDTH = {'mobile': 270, 'tablet': 330, 'desktop': 440}

DEVICES = {
    'mobile': dict(viewport={'width': 390, 'height': 844}, device_scale_factor=3, is_mobile=True, has_touch=True),
    'tablet': dict(viewport={'width': 820, 'height': 1180}, device_scale_factor=2, is_mobile=True, has_touch=True),
    'desktop': dict(viewport={'width': 1440, 'height': 900}, device_scale_factor=1.5),
}

# (device, file name, route, table index)
SHOTS = [
    ('mobile', 'home', 'home', 0),
    ('mobile', 'tables', 'tables', 0),
    ('mobile', 'table-view', 'data', 0),
    ('mobile', 'inventory', 'data', 1),
    ('mobile', 'card-view', 'cards', 2),
    ('mobile', 'record-details', 'detail', 0),
    ('mobile', 'add-row', 'add', 0),
    ('mobile', 'edit-row', 'edit-row', 2),
    ('mobile', 'create-table', 'create', 0),
    ('mobile', 'edit-table', 'edit', 0),
    ('mobile', 'search-sort', 'search', 0),
    ('mobile', 'filter', 'filter', 0),
    ('mobile', 'multi-select', 'select', 0),
    ('mobile', 'undo-delete', 'undo', 0),
    ('mobile', 'field-rules', 'rules', 0),
    ('tablet', 'tables', 'tables', 0),
    ('tablet', 'table-view', 'data', 1),
    ('tablet', 'card-view', 'cards', 0),
    ('tablet', 'edit-table', 'edit', 0),
    ('desktop', 'tables', 'tables', 0),
    ('desktop', 'table-view', 'data', 0),
    ('desktop', 'inventory', 'data', 1),
    ('desktop', 'card-view', 'cards', 2),
    ('desktop', 'record-details', 'detail', 0),
    ('desktop', 'edit-table', 'edit', 0),
    ('desktop', 'search-sort', 'search', 0),
    ('desktop', 'multi-select', 'select', 0),
]

SETTLE = {'add': 2.0, 'edit-row': 2.0, 'detail': 2.0, 'filter': 2.0, 'undo': 1.5, 'rules': 1.0}


def make_thumb(device, path):
    """Shrink a screenshot to a README-sized thumbnail next to it."""
    os.makedirs(THUMBS, exist_ok=True)
    with Image.open(path) as im:
        w = THUMB_WIDTH[device]
        h = round(im.height * w / im.width)
        thumb = im.convert('RGB').resize((w, h), Image.LANCZOS)
        out = os.path.join(THUMBS, os.path.basename(path))
        thumb.save(out, optimize=True)
        return out


def thumbs_only():
    for device, name, _, _ in SHOTS:
        path = os.path.join(OUT, f'{device}-{name}.png')
        if os.path.exists(path):
            print('thumb', make_thumb(device, path))


def serve(port):
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

    handler = functools.partial(Quiet, directory=WEB)
    httpd = http.server.ThreadingHTTPServer(('127.0.0.1', port), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=8737)
    ap.add_argument('--no-serve', action='store_true')
    ap.add_argument('--thumbs-only', action='store_true')
    ap.add_argument('--only', nargs='*', help='limit to "<device>-<name>" keys')
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    if args.thumbs_only:
        return thumbs_only()
    httpd = None if args.no_serve else serve(args.port)
    try:
        with sync_playwright() as p:
            try:
                browser = p.chromium.launch()
            except Exception:
                # Browser revision mismatch: fall back to any installed Chromium.
                exe = sorted(glob.glob(os.path.join(os.environ.get('LOCALAPPDATA', ''), 'ms-playwright',
                                                    'chromium-*', 'chrome-win*', 'chrome.exe')))[-1]
                browser = p.chromium.launch(executable_path=exe)
            for device, name, route, table in SHOTS:
                key = f'{device}-{name}'
                if args.only and key not in args.only:
                    continue
                ctx = browser.new_context(**DEVICES[device])
                page = ctx.new_page()
                page.goto(f'http://127.0.0.1:{args.port}/?route={route}&table={table}', wait_until='networkidle')
                page.wait_for_selector('flutter-view, flt-glass-pane', state='attached', timeout=60000)
                page.evaluate('document.fonts.ready')
                time.sleep(2.5 + SETTLE.get(route, 0))
                page.wait_for_load_state('networkidle')
                path = os.path.join(OUT, f'{key}.png')
                page.screenshot(path=path)
                print('saved', path)
                make_thumb(device, path)
                ctx.close()
            browser.close()
    finally:
        if httpd:
            httpd.shutdown()


if __name__ == '__main__':
    main()
