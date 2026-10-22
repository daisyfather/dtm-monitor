"""Convert SQL string literals containing non-ASCII chars into TO_CHAR(UNISTR('...')).
Comments are left untouched. Usage: unistr_conv.py in out"""
import sys

def uni_body(s):
    out = []
    for ch in s:
        o = ord(ch)
        if ch == '\\':
            out.append('\\005C')
        elif o < 128:
            out.append("''" if ch == "'" else ch)
        elif o <= 0xFFFF:
            out.append('\\%04X' % o)
        else:
            o -= 0x10000
            out.append('\\%04X\\%04X' % (0xD800 + (o >> 10), 0xDC00 + (o & 0x3FF)))
    return ''.join(out)

def uni(s):
    return "TO_CHAR(UNISTR('" + uni_body(s) + "'))"

def convert(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('--', i):
            j = src.find('\n', i); j = n if j < 0 else j
            out.append(src[i:j]); i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2); j = n if j < 0 else j + 2
            out.append(src[i:j]); i = j
        elif c == "'":
            j = i + 1; buf = []
            while j < n:
                if src[j] == "'":
                    if j + 1 < n and src[j + 1] == "'":
                        buf.append("'"); j += 2; continue
                    break
                buf.append(src[j]); j += 1
            val = ''.join(buf)
            if any(ord(ch) > 127 for ch in val):
                out.append(uni(val))
            else:
                out.append(src[i:j + 1])
            i = j + 1
        else:
            out.append(c); i += 1
    return ''.join(out)

if __name__ == '__main__':
    data = open(sys.argv[1], encoding='utf-8').read()
    open(sys.argv[2], 'w', encoding='utf-8').write(convert(data))
