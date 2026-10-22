#!/usr/bin/env python3
"""Chan file SQL co ky tu ngoai ASCII trong phan CODE (khong tinh comment).

Ly do: Oracle client cua team dang dung NLS_LANG khong phai UTF-8, chuoi tieng
Viet trong code bi doi thanh '?' khi gui xuong database. Moi chuoi tieng Viet
trong code phai viet bang TO_CHAR(UNISTR('...')) - dung tools/unistr_conv.py.

Comment (-- va /* */) duoc phep co tieng Viet vi khong anh huong du lieu.

File co dong "-- ascii-check: skip" o 5 dong dau se duoc bo qua
(chi dung cho file lich su da deploy, khong dung cho file moi).

Cach dung:
    python3 tools/check_ascii.py            # quet toan bo *.sql trong repo
    python3 tools/check_ascii.py a.sql b.sql
Ma thoat 1 neu co vi pham.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def strip_comments(src: str) -> str:
    """Bo comment SQL, giu nguyen chuoi literal (ke ca literal chua -- hoac /*)."""
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith("--", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
        elif src[i] == "'":
            j = i + 1
            while j < n:
                if src[j] == "'":
                    if j + 1 < n and src[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def check(path: pathlib.Path) -> list:
    text = path.read_text(encoding="utf-8")
    if any("ascii-check: skip" in line for line in text.splitlines()[:5]):
        return []
    code = strip_comments(text)
    problems = []
    for lineno, line in enumerate(code.splitlines(), 1):
        bad = sorted({c for c in line if ord(c) > 127})
        if bad:
            problems.append((lineno, "".join(bad), line.strip()[:100]))
    return problems


def main(argv):
    files = [pathlib.Path(a) for a in argv] or sorted(
        p for p in ROOT.rglob("*.sql") if ".git" not in p.parts)
    failed = 0
    for f in files:
        for lineno, chars, snippet in check(f):
            failed += 1
            rel = f.relative_to(ROOT) if f.is_absolute() else f
            print(f"{rel}: ~dong {lineno}: ky tu ngoai ASCII [{chars}] -> {snippet}")
    if failed:
        print(f"\n{failed} dong vi pham. Doi chuoi tieng Viet sang UNISTR: "
              "python3 tools/unistr_conv.py <in.sql> <out.sql>")
        return 1
    print(f"OK - {len(files)} file SQL, khong co ky tu ngoai ASCII trong code.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
