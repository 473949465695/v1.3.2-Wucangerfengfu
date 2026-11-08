import io, os, sys, subprocess, unicodedata
from fontTools.ttLib import TTFont
from fontTools import subset as ftsubset

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(ROOT, "_font")
OUT_DIR = os.path.join(ROOT, "app", "assets", "fonts")
HTML = os.path.join(ROOT, "app", "assets", "index.html")
os.makedirs(OUT_DIR, exist_ok=True)

html = io.open(HTML, encoding="utf-8").read()

chars = set()
# 1) every char actually used in the page
chars.update(html)
# 2) ASCII
chars.update(chr(c) for c in range(0x20, 0x7F))
# 3) GB2312 level 1 (3755 most common hanzi)
for hi in range(0xB0, 0xD8):
    for lo in range(0xA1, 0xFF):
        try:
            chars.add(bytes([hi, lo]).decode("gb2312"))
        except Exception:
            pass
# 4) punctuation / symbols that a Chinese sentence can plausibly contain
extras = "·…—～、。，；：？！“”‘’（）《》〈〉【】〔〕「」『』％＋－×÷＝／＼　·※℃№"
chars.update(extras)

chars = {c for c in chars if unicodedata.category(c) not in ("Cc", "Cs", "Co", "Cn")}
text = "".join(sorted(chars))
print("requested codepoints:", len(chars))

for weight in ("Regular", "Bold"):
    src = os.path.join(SRC_DIR, "NotoSerifSC-%s.otf" % weight)
    out = os.path.join(OUT_DIR, "wcf-serif-%s.otf" % ("400" if weight == "Regular" else "700"))
    font = TTFont(src)
    cmap = font.getBestCmap()
    missing = [c for c in chars if ord(c) not in cmap]
    font.close()

    args = [
        sys.executable, "-m", "fontTools.subset", src,
        "--output-file=" + out,
        "--text=" + text,
        "--layout-features=",
        "--no-hinting",
        "--desubroutinize",
        "--name-IDs=1,2,3,4,6",
        "--drop-tables+=DSIG,GSUB,GPOS,MATH",
        "--recalc-bounds",
    ]
    r = subprocess.run(args, capture_output=True)
    size = os.path.getsize(out) if os.path.exists(out) else -1
    print("%-8s out=%d bytes  missing_from_source=%d  rc=%d" % (weight, size, len(missing), r.returncode))
    if missing:
        print("   missing sample:", "".join(missing[:40]))
        print("   missing codes:", [hex(ord(c)) for c in missing[:20]])
    if r.returncode != 0:
        print(r.stderr.decode("utf-8", "replace")[:2000])
