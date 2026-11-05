"""AllTheThings 컴파일 자료(Lua) 를 실행하지 않고 읽는 작은 파서"""
import re

class P:
    pass

def parse(text, key):
    global s, n, pos
    start = text.index("categories." + key + "=") + len("categories." + key + "=")
    s = text; n = len(text); pos = start
    return value()

NUM = re.compile(r"-?(?:0x[0-9a-fA-F]+|\d+(?:\.\d*)?(?:[eE][-+]?\d+)?|\.\d+)")
NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*")

def ws():
    global pos
    while pos < n:
        c = s[pos]
        if c in " \t\r\n":
            pos += 1
        elif s.startswith("--", pos):
            e = s.find("\n", pos)
            pos = n if e < 0 else e + 1
        else:
            break

def string():
    global pos
    q = s[pos]; pos += 1
    out = []
    while s[pos] != q:
        if s[pos] == "\\":
            out.append(s[pos:pos + 2]); pos += 2
        else:
            out.append(s[pos]); pos += 1
    pos += 1
    return "".join(out)

def value():
    global pos
    ws()
    c = s[pos]
    if c == "{":
        return table()
    if c == "(":                                  # (function(t) ... end)({...}) 같은 즉시 호출
        pos += 1
        inner = value(); ws(); pos += 1; ws()
        if pos < n and s[pos] == "(":
            pos += 1; args = []; ws()
            while s[pos] != ")":
                args.append(value()); ws()
                if s[pos] == ",":
                    pos += 1; ws()
            pos += 1
            for a in args:
                if isinstance(a, (dict, list)):
                    return a
        return inner
    if c in "\"'":
        return string()
    if s.startswith("[[", pos):
        e = s.index("]]", pos); v = s[pos + 2:e]; pos = e + 2; return v
    m = NUM.match(s, pos)
    if m and (c.isdigit() or c in "-."):
        pos = m.end(); t = m.group(0)
        return int(t, 16) if "x" in t.lower() else (float(t) if any(ch in t for ch in ".eE") and "x" not in t.lower() else int(t))
    if s.startswith("function", pos):           # 함수 본문은 건너뛴다
        depth = 0
        while True:
            m = re.compile(r"\b(function|if|do|end|repeat|until)\b").search(s, pos)
            w = m.group(1); pos = m.end()
            if w in ("function", "if", "do", "repeat"):
                depth += 1
            elif w in ("end", "until"):
                depth -= 1
                if depth == 0:
                    return ("fn",)
    m = NAME.match(s, pos)
    if m:
        name = m.group(0); pos = m.end(); ws()
        if name in ("true", "false", "nil"):
            return {"true": True, "false": False, "nil": None}[name]
        if pos < n and s[pos] == "(":            # 생성자 호출: kind(id, {...})
            pos += 1
            args = []
            ws()
            while s[pos] != ")":
                args.append(value()); ws()
                if s[pos] == ",":
                    pos += 1; ws()
            pos += 1
            return ("call", name, args)
        if pos < n and s[pos] == "{":            # f{...}
            return ("call", name, [table()])
        return ("ref", name)
    raise ValueError("unexpected at %d: %r" % (pos, s[pos:pos + 40]))

def table():
    global pos
    pos += 1
    arr, d = [], {}
    while True:
        ws()
        if s[pos] == "}":
            pos += 1; break
        if s[pos] == "[":
            pos += 1; k = value(); ws(); pos += 1; ws(); pos += 1   # [k]=
            d[k] = value()
        else:
            m = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)").match(s, pos)
            if m:
                pos = m.end(); d[m.group(1)] = value()
            else:
                arr.append(value())
        ws()
        if s[pos] in ",;":
            pos += 1
    if d:
        if arr:
            d["__arr"] = arr
        return d
    return arr

