#!/usr/bin/env python3
"""
wowf.io 아이템 점수(cv)에서 거꾸로 맞춘 능력치 값 → FOA_UI/Score.lua 의 WOWF 가중치 묶음
 자료: wowf_weights.txt (wowf.io 포에버 BiS 28 전문화 · 2026-11-26)
  - 방어구 칸에서 특수 효과 · 세트가 없는 아이템의 점수를 능력치로 최소 제곱 맞춤 (표본 · r2 는 파일에)
  - FOA 단위로 바꾼다: 물리 = 전투력 1 · 시전자 = 주문 공격력 1 · 치유사 = 치유량 1 · 방어 = 체력을 FOA 값 그대로
    치명타는 1% 당 (등급 14 = 1%) · 회피 12 · 무기 막기 15 · 방패 막기 5 = 1%
  - 표본이 5개(방어 전문화는 맞춤이 거칠어 10개)보다 적거나 0 이하(맞춤 오차)인 능력치는 FOA 값을 그대로 둔다
  - 고양 주술사 지능은 FOA 값 (포에버 특성 '정신 기민함' 지능 → 전투력 전환을 사이트가 넣지 않음)
  - 야성 드루이드 무기 초당 공격력은 사이트가 0 으로 쳐서(무기 칸 값 없음) FOA 값 (포에버는 변신 중에도 무기 공격력이 더해짐)
  - 적중 · 방어 숙련은 사이트가 상한을 넘긴 조합 기준이라 FOA 값 (FOA 는 상한까지 남은 만큼 따로 계산)
  - 숙련은 사이트의 '추천 조합' 값(상한 아래 1점 값) · FOA 값의 0.5 ~ 2배 안에서
  - 무기 초당 공격력: 무기 칸 점수에서 능력치 몫을 뺀 나머지 ÷ 초당 공격력 (중앙값)
사용: python3 -I gen_weights.py <wowf_weights.txt> <Score.lua> [--dry]
"""
import re
import sys

PHYS = {'ROGUE', 'WARRIOR:arms', 'WARRIOR:fury', 'PALADIN:ret', 'SHAMAN:enh', 'DRUID:feral', 'HUNTER'}
HEAL = {'PALADIN:holy', 'PRIEST:disc', 'PRIEST:holy', 'SHAMAN:resto', 'DRUID:resto'}
KEEP = {'SHAMAN:enh': ('int',)}
TANK = {'WARRIOR:prot', 'PALADIN:prot', 'DRUID:guardian'}
CASTER = {'MAGE', 'WARLOCK', 'PRIEST:shadow', 'SHAMAN:ele', 'DRUID:balance', 'PRIEST:disc', 'PRIEST:holy',
          'PALADIN:holy', 'SHAMAN:resto', 'DRUID:resto'}
# 사이트 능력치 번호 → (FOA 키, 1% 로 바꾸는 등급 수 또는 1)
MAP = {'4': ('str', 1), '3': ('agi', 1), '7': ('sta', 1), '5': ('int', 1), '6': ('spi', 1), '38': ('ap', 1),
       '41': ('heal', 1), '42': ('sp', 1), '43': ('mp5', 1), '47': ('spen', 1), 'armor': ('armor', 1),
       '32': ('crit', 14), '13': ('dodge', 12), '14': ('parry', 15), '15': ('block', 5)}


def role(key, sets):
    cls = key.split(':')[0]
    return key in sets or cls in sets


def foa_w(score_src):
    """Score.lua W 표에서 전문화별 현재 값"""
    out = {}
    body = score_src[score_src.index('local W = {'):score_src.index('\n}\n', score_src.index('local W = {'))]
    for m in re.finditer(r'\["(\w+:\w+)"\] = (?:Caster\()?\{([^}]*)\}', body):
        out[m.group(1)] = {k: float(v) for k, v in re.findall(r'(\w+) = ([\d.]+)', m.group(2))}
    return out


def main(wpath, spath, dry):
    src = open(spath, encoding='utf-8').read()
    cur = foa_w(src)
    specs, key = {}, None
    for line in open(wpath, encoding='utf-8'):
        line = line.strip()
        if line.startswith('K|'):
            key = line[2:]; specs[key] = {}
        elif line.startswith('W|'):
            p = line.split('|')
            specs[key]['fit'] = {k: (float(v.split(':')[0]), int(v.split(':')[1])) for k, v in (t.split('=') for t in p[1].split())}
            specs[key]['wpn'] = dict(re.findall(r'(\w+)=([\d.\-]+)n\d+', p[3]))
        elif line.startswith('C|'):
            m = re.search(r'cw=(\{[^}]*\})', line)
            specs[key]['cw'] = {k: float(v) for k, v in re.findall(r'"(\w+)":([\d.]+)', m.group(1))} if m else {}
    lines, report = [], []
    for key in sorted(specs):
        d, f = specs[key], specs[key]['fit']
        old = cur.get(key, {})
        need = 10 if role(key, TANK) else 5
        def val(sid):
            v = f.get(sid)
            return v[0] if v and v[1] >= need and v[0] > 0 else None
        if role(key, TANK):
            u = (val('7') or 0) / (old.get('sta') or 1.5)
        elif role(key, HEAL):
            u = val('41')
        elif role(key, PHYS):
            u = val('38')
        else:
            u = val('42')
        if not u:
            report.append(f'{key}: 단위 없음 · 건너뜀'); continue
        new = {}
        for sid, (k, per) in MAP.items():
            v = val(sid)
            if v is None or k in ('heal', 'sp') and role(key, HEAL) or k == 'ap' and role(key, PHYS) or k == 'sp' and not role(key, TANK) and role(key, CASTER):
                continue
            new[k] = round(v * per / u, 2 if v * per / u < 10 else 1)
        for k in KEEP.get(key, ()): new.pop(k, None)
        if role(key, CASTER) and 'crit' in new: new['scrit'] = new['crit']
        if not role(key, HEAL) and role(key, CASTER) and 'sp' not in new: pass
        if role(key, CASTER) and not role(key, HEAL) and val('42'): new['sdmg'] = 1
        if role(key, HEAL) and 'sp' in new: del new['sp']
        if key.startswith('HUNTER'): new['rap'] = 1; new['ap'] = 1
        # 무기
        wp = d.get('wpn', {})
        mh = float(wp['mh']) if 'mh' in wp else float(wp['2h']) if '2h' in wp else None
        if mh and mh > 0 and role(key, PHYS | TANK):
            new['dps'] = round(mh / u, 1)
        if key.startswith('HUNTER') and 'rg' in wp: new['rdps'] = round(float(wp['rg']) / u, 1)
        # 숙련: 추천 조합 값 (상한 아래)
        cw = d.get('cw', {})
        if '37' in cw and old.get('exp'):
            e = cw['37'] * 10 / u
            new['exp'] = round(min(max(e, old['exp'] * 0.5), old['exp'] * 2), 1)
        diff = ' '.join(f'{k} {old.get(k, "-")}→{v}' for k, v in sorted(new.items()) if old.get(k) != v)
        report.append(f'{key}: {diff}')
        lines.append(f'\t["{key}"] = {{ ' + ', '.join(f'{k} = {v}' for k, v in sorted(new.items())) + ' },')
    block = ('-- [자동 생성 · tools/forever/gen_weights.py] wowf.io 포에버 BiS 아이템 점수에서 맞춘 능력치 값 (2026-11-26)\n'
             '--  위 W 표(공략 우선순위)에 덮어쓴다 · 적중 · 가속 · 방어 숙련 · 계열 주문 공격력은 위 값 그대로\n'
             'local WOWF = {\n' + '\n'.join(lines) + '\n}\n'
             'for key, t in pairs(WOWF) do\n\tlocal w = W[key]\n\tif w then for k, v in pairs(t) do w[k] = v end end\nend\nM.WOWF = WOWF\n')
    print('\n'.join(report))
    if dry: return
    pat = re.compile(r'-- \[자동 생성 · tools/forever/gen_weights\.py\].*?\nM\.WOWF = WOWF\n', re.S)
    if pat.search(src):
        src = pat.sub(lambda _: block, src)
    else:
        anchor = '-- 특정 계열 주문 공격력'
        src = src.replace(anchor, block + anchor, 1)
    open(spath, 'w', encoding='utf-8').write(src)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], '--dry' in sys.argv)
