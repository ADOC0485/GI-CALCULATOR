"""Build-time only. Generates the app icons from assets/branding/app_icon.png.

Usage: python -I tool/build_app_icons.py
Writes Android launcher icons (legacy and adaptive), the Windows .ico and the
in-app logo. Requires Pillow.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets' / 'branding' / 'app_icon.png'
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def resized(image, size):
    return image.resize((size, size), Image.LANCZOS)


def padded(image, canvas, content, color=(0, 0, 0, 0)):
    """[image] scaled to [content] px, centred on a [canvas] px square."""
    out = Image.new('RGBA', (canvas, canvas), color)
    small = resized(image, content)
    offset = (canvas - content) // 2
    out.alpha_composite(small, (offset, offset))
    return out


def main():
    icon = Image.open(SOURCE).convert('RGBA')
    # Background of the rounded square, sampled just inside its top edge.
    w, h = icon.size
    background = icon.getpixel((w // 2, int(h * 0.08)))[:3]

    for name, scale in DENSITIES.items():
        folder = RES / f'mipmap-{name}'
        folder.mkdir(parents=True, exist_ok=True)
        # Legacy icon: the rounded square with a little margin.
        legacy = round(48 * scale)
        padded(icon, legacy, round(legacy * 0.92)).save(folder / 'ic_launcher.png')
        # Adaptive foreground: 108 dp layer. At 90 dp the purple square
        # covers the whole 72 dp visible area (no inner edge shows) while
        # the moon stays inside the 66 dp safe circle.
        layer = round(108 * scale)
        padded(icon, layer, round(90 * scale)).save(folder / 'ic_launcher_foreground.png')

    anydpi = RES / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n',
        encoding='utf-8',
    )
    (RES / 'values' / 'ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
        '</resources>\n' % background,
        encoding='utf-8',
    )

    ico = ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
    icon.save(ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])

    resized(icon, 256).save(ROOT / 'assets' / 'branding' / 'logo.png')
    print('Íconos generados. Fondo adaptable: #%02X%02X%02X' % background)


if __name__ == '__main__':
    main()
