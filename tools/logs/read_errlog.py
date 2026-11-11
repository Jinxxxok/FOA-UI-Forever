#!/usr/bin/env python3
"""
FOA 오류 기록 읽기
  게임 저장 파일(WTF/Account/<계정>/SavedVariables/FOA_UI.lua)의 InkUIDB.errlog 를 보기 좋게 정리한다.
  (게임은 /reload · 접속 종료 때 이 파일을 쓴다)
  코드는 실행하지 않고 Lua 표 글자만 읽는다.

사용: python3 -I read_errlog.py <FOA_UI.lua> [--all] [--since 11-11]
  --all    블리자드 오류(FOA 와 무관해 보이는 것)도 자세히
  --since  이 날짜(월-일) 이후 마지막으로 난 것만
"""
import re, sys

TOK = re.compile(r'''\s+|--\[\[.*?\]\]|--[^\n]*|(\[\[.*?\]\])|("(?:\\.|[^"\\])*")|(\d+\.?\d*(?:[eE][-+]?\d+)?)|([A-Za-z_][A-Za-z0-9_]*)|(.)''', re.S)


def tokens(s):
    for m in TOK.finditer(s):
        lb, st, num, name, ch = m.groups()
        if lb is not None:
            yield ('s', lb[2:-2])
        elif st is not None:
            body = st[1:-1]
            body = re.sub(r'\\(.)', lambda mm: {'n': '\n', 't': '\t'}.get(mm.group(1), mm.group(1)), body)
            yield ('s', body)
        elif num is not None:
            yield ('n', float(num) if ('.' in num or 'e' in num.lower()) else int(num))
        elif name is not None:
            yield ('id', name)
        elif ch is not None:
            yield ('p', ch)


class P:
    def __init__(s, toks):
        s.t, s.i = toks, 0

    def nxt(s):
        v = s.t[s.i]
        s.i += 1
        return v

    def peek(s, k=0):
        return s.t[s.i + k] if s.i + k < len(s.t) else (None, None)

    def value(s):
        k, v = s.nxt()
        if (k, v) == ('p', '{'):
            return s.table()
        if (k, v) == ('p', '-'):
            return -s.nxt()[1]
        if k in ('s', 'n'):
            return v
        return {'nil': None, 'true': True, 'false': False}.get(v, v)

    def table(s):
        out, idx = {}, 1
        while True:
            k, v = s.peek()
            if (k, v) == ('p', '}'):
                s.nxt()
                return out
            if (k, v) == ('p', '['):
                s.nxt()
                key = s.value()
                s.nxt()
                s.nxt()
                out[key] = s.value()
            elif k == 'id' and s.peek(1) == ('p', '='):
                s.nxt()
                s.nxt()
                out[v] = s.value()
            else:
                out[idx] = s.value()
                idx += 1
            if s.peek() in (('p', ','), ('p', ';')):
                s.nxt()


def arr(t):
    return [t[k] for k in sorted(k for k in t if isinstance(k, int))] if isinstance(t, dict) else []


def load(path):
    src = open(path, encoding='utf-8', errors='replace').read()
    i = src.find('InkUIDB = {')
    if i < 0:
        sys.exit('InkUIDB 를 못 찾았어요')
    toks = list(tokens(src[i + len('InkUIDB = '):]))
    p = P(toks)
    p.nxt()
    return p.table()


def main():
    args = sys.argv[1:]
    show_all = '--all' in args
    since = None
    if '--since' in args:
        since = args[args.index('--since') + 1]
    path = [a for a in args if not a.startswith('--') and a != since][0]
    db = load(path)
    L = db.get('errlog') or {}
    sessions = arr(L.get('sessions'))
    print('== 세션 (최근 %d)' % min(5, len(sessions)))
    for s in sessions[-5:]:
        print('  %s  FOA v%s  빌드 %s' % (s.get('t'), s.get('ver'), s.get('build')))
    items = arr(L.get('list'))
    if since:
        items = [e for e in items if (e.get('last') or '') >= since]
    items.sort(key=lambda e: e.get('lastT') or 0, reverse=True)
    order = {'FOA': 0, 'FOA 오염': 1, '블리자드': 2}
    items.sort(key=lambda e: order.get(e.get('kind'), 3))
    print('\n== 오류 %d가지' % len(items))
    for e in items:
        kind = e.get('kind')
        print('\n[%s] x%s  처음 %s (v%s)  마지막 %s (v%s)  %s' % (kind, e.get('n'), e.get('first'), e.get('ver'),
              e.get('last'), e.get('lastVer'), e.get('lastCtx') or e.get('ctx') or ''))
        print('  ' + (e.get('msg') or '').replace('\n', '\n  '))
        if kind != '블리자드' or show_all:
            if e.get('stack'):
                print('  -- 호출 경로')
                for line in (e.get('stack') or '').split('\n')[:14]:
                    if line.strip():
                        print('    ' + line.strip())
            if e.get('locals'):
                print('  -- 지역 변수')
                for line in (e.get('locals') or '').split('\n')[:20]:
                    if line.strip():
                        print('    ' + line.rstrip())
    bl = L.get('blocked') or {}
    if bl:
        print('\n== 막힌 동작 %d가지' % len(bl))
        for fn, b in sorted(bl.items(), key=lambda kv: kv[1].get('lastT') or 0, reverse=True):
            print('  %s  x%s (전투 중 %s)  마지막 %s  %s' % (fn, b.get('n'), b.get('combat'), b.get('last'), b.get('ctx') or ''))
    probe = db.get('bossProbe')
    if probe:
        print('\n== 보스 타이머 조사  기술번호 공개 %s / 비공개 %s · 이름 공개 %s / 비공개 %s' % (
            probe.get('plainID'), probe.get('secretID'), probe.get('plainName'), probe.get('secretName')))
        for line in arr(probe.get('list'))[-15:]:
            print('  ' + line)
    tr = arr(db.get('abandonTrace'))
    if tr:
        print('\n== 퀘스트 포기 창 닫힘 추적')
        for line in tr:
            print('  ' + line.replace('\n', '\n    '))


if __name__ == '__main__':
    main()
