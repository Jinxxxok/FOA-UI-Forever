# 포에버 BIS · 준비물 데이터 → FOA_UI/ForeverBIS.lua
#  method_bis.txt : @CLASS:spec / PRE|부위|이름|아이템번호|획득처 / ALT|... / STATS|...
#  cons.txt       : @키 키 ... / E|부위|item=번호 또는 spell=번호 / C|종류|item=번호
#  사용: python3 -I gen_bis.py <자료 폴더> <출력 ForeverBIS.lua> [QuestieDB 폴더]
#   QuestieDB 를 주면 획득처 글의 NPC · 퀘스트 · 평판 이름을 번호 표시({n:번호|영어} · {q:…} · {f:…})로 바꿔
#   게임에서 그 언어 이름으로 보이게 한다 (Dungeon.lua KoSource)
import sys, re, os
src_dir, out = sys.argv[1], sys.argv[2]
qdb = sys.argv[3] if len(sys.argv) > 3 else None
INV = {'head':[1],'neck':[2],'shoulder':[3],'cloak':[15],'back':[15],'chest':[5],'wrist':[9],'hands':[10],'gloves':[10],
       'waist':[6],'belt':[6],'legs':[7],'feet':[8],'boots':[8],'ring':[11,12],'ring 1':[11],'ring 2':[12],
       'trinket':[13,14],'trinket 1':[13],'trinket 2':[14],'1h weapon':[16],'weapon':[16],'2h weapon':[16],
       'off hand':[17],'shield':[17],'main hand':[16],'ranged':[18],'libram':[18],'idol':[18],'totem':[18]}
def esc(s): return s.replace('\\','\\\\').replace('"','\\"')
specs = {}
cur = None
for line in open(src_dir + '/method_bis.txt', encoding='utf-8'):
    line = line.strip()
    if not line: continue
    if line.startswith('@'):
        cur = line[1:]; specs.setdefault(cur, {'pre': [], 'alt': [], 'stats': '', 'E': [], 'C': []}); continue
    p = line.split('|')
    if p[0] == 'STATS':
        specs[cur]['stats'] = '' if p[1] == '-' else p[1]
    elif p[0] in ('PRE', 'ALT') and len(p) >= 5 and p[3].isdigit():
        specs[cur]['pre' if p[0] == 'PRE' else 'alt'].append((p[1].lower(), int(p[3]), p[4]))
# 새 자료 (MythicSim 시뮬 · wowforever.be): 같은 전문화면 Method 장비 목록을 이걸로 바꾼다
#  mythicsim_bis.txt : @CLASS:spec 출처 / 칸 | 이름 | 아이템 | 획득처
SLOT2 = {'shoulders': 'shoulder', 'wrists': 'wrist', 'ring 1': 'ring 1', 'ring 2': 'ring 2', 'trinket 1': 'trinket 1',
         'trinket 2': 'trinket 2', 'main hand': 'main hand', 'off hand': 'off hand', 'ranged': 'ranged'}
FROM = {'MythicSim': 'MythicSim 시뮬 11/22', 'wowforever.be': 'wowforever.be 공략'}
ms = src_dir + '/mythicsim_bis.txt'
if os.path.exists(ms):
    cur = None
    for line in open(ms, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        if line.startswith('@'):
            k, *rest = line[1:].split()
            cur = k
            d = specs.setdefault(cur, {'pre': [], 'alt': [], 'stats': '', 'E': [], 'C': []})
            d['pre'], d['alt'] = [], []
            d['from'] = FROM.get(rest[0] if rest else '', rest[0] if rest else '')
            continue
        q = [x.strip() for x in line.split('|')]
        if len(q) >= 4 and q[2].isdigit():
            slot = q[0].lower()
            specs[cur]['pre'].append((SLOT2.get(slot, slot), int(q[2]), q[3]))
# wowf.io BiS (wowf_bis.txt): 28 전문화 모두 · 사이트 추천 조합 = BIS · 칸 순위 = 대체 (MythicSim · Method 장비 목록을 바꾼다)
#  RA = 얼라이언스 추천 조합 · RH = 호드 추천 조합(다를 때만 → gh) · L칸 = 그 칸 순위 (꼬리표 a/h = 진영 전용 → fac)
#  wowf_src.txt : 획득처 글 (FOA 던전 전리품 · ForeverSources 가 모르는 아이템만 · [A]/[H] = 그 진영 조각)
WSLOT = {0: 1, 1: 2, 2: 3, 3: 15, 4: 5, 5: 9, 6: 10, 7: 6, 8: 7, 9: 8, 15: 18}
WALT = dict(WSLOT); WALT.update({10: 11, 11: 13, 12: 16, 13: 17, 14: 16})
wfac, wsrc = {}, {}
def wassign(tokens):
    g, ring, trink, weap = {}, 0, 0, []
    for t in tokens:
        a, b = t.split(':')
        iid, sis = int(a), [int(x) for x in b.split('.')]
        si = sis[0]
        if si in WSLOT: g[WSLOT[si]] = iid
        elif si == 10: g[11 + min(ring, 1)] = iid; ring += 1
        elif si == 11: g[13 + min(trink, 1)] = iid; trink += 1
        else: weap.append((iid, sis))
    for iid, sis in weap:
        if 14 in sis or (12 in sis and 16 not in g): g[16] = iid
        elif 13 in sis or 12 in sis: g[17] = iid
    return g
ws = src_dir + '/wowf_src.txt'
if os.path.exists(ws):
    mac = {}
    for line in open(ws, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        if line.startswith('@'):
            k, v = line[1:].split('=', 1); mac['@' + k] = v; continue
        ids, lab = line.split('|', 1)
        for i in ids.split(','): wsrc[int(i)] = mac.get(lab, lab)
wf = src_dir + '/wowf_bis.txt'
if os.path.exists(wf):
    cur = None
    for line in open(wf, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        kind, body = line.split('|', 1)
        if kind == 'K':
            cur = body
            d = specs.setdefault(cur, {'pre': [], 'alt': [], 'stats': '', 'E': [], 'C': []})
            d['pre'], d['alt'], d['from'], d['wg'], d['wgh'], d['walt'] = [], [], 'wowf.io BiS 11/26', {}, {}, []
        elif kind == 'RA':
            specs[cur]['wg'] = wassign(body.split())
        elif kind == 'RH':
            gh = wassign(body.split())
            specs[cur]['wgh'] = {k: v for k, v in gh.items() if specs[cur]['wg'].get(k) != v}
        elif kind[0] == 'L':
            inv = WALT[int(kind[1:])]
            d = specs[cur]
            used = set(d['wg'].values()) | set(d['wgh'].values())
            n = 0
            for t in re.split(r'[ ,]', body):
                m = re.match(r'(\d+)([a-z]*)', t)
                if not m: continue
                iid, fl = int(m.group(1)), m.group(2)
                if 'a' in fl: wfac[iid] = 2
                elif 'h' in fl: wfac[iid] = 1
                if iid in used or n >= (6 if inv in (11, 13, 16, 17) else 5): continue
                used.add(iid); n += 1
                d['walt'].append((inv, iid))
for line in open(src_dir + '/cons.txt', encoding='utf-8'):
    line = line.strip()
    if not line or line.startswith('#'): continue
    if line.startswith('@'):
        keys = line[1:].split()
        for k in keys: specs.setdefault(k, {'pre': [], 'alt': [], 'stats': '', 'E': [], 'C': []})
        continue
    # R| 준비물 출처 글 · T| 능력치 순서 (한국어 · 비어 있는 전문화를 채운다)
    if line.startswith('R|'):
        for k in keys: specs[k]['psrc'] = line[2:]
        continue
    if line.startswith('T|'):
        for k in keys: specs[k]['stats'] = line[2:]
        continue
    kind, slot, ref = line.split('|')
    t, n = ref.split('=')
    for k in keys: specs[k][kind].append((slot, t, int(n)))

# 획득처 글 → 번호 표시 (게임 언어 이름)
FACTIONS = [('Theramore Expeditionary Force', 2799), ('Darkspear Raiders', 2798), ('The Watchers', 2819),
            ('Silverwing Sentinels', 890), ('Warsong Outriders', 889), ('Stormpike Guard', 730), ('Frostwolf Clan', 729),
            ('League of Arathor', 509), ('Defilers', 510), ('Stormpike', 730), ('Frostwolf', 729)]
SKIP = {'Dungeon', 'Crafted', 'Vendor', 'Quest', 'Reputation', 'Tribute', 'Unknown', 'PvP', 'BoE', 'World Drop', 'World BoE',
        'Blackrock Spire', 'Blackrock Depths', 'Lower Blackrock Spire', 'Upper Blackrock Spire', 'Stratholme', 'Scholomance',
        'Dire Maul', 'Razorfen Downs', 'Azshara', 'Stranglethorn Vale', 'Darkmoon Faire', 'The Darkmoon Faire',
        'Blacksmithing', 'Enchanting', 'Engineering', 'Leatherworking', 'Tailoring', 'Alchemy', 'Cooking'}
NPC, QST = {}, {}
if qdb:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'quests'))
    import questie_data
    Q, N, _, _ = questie_data.load(qdb)
    for i, n in N.items():
        if isinstance(n.get('name'), str) and (n['name'] not in NPC or i < NPC[n['name']]): NPC[n['name']] = i
    for i, r in Q.items():
        if isinstance(r[0], str) and (r[0] not in QST or i < QST[r[0]]): QST[r[0]] = i
FRX = re.compile('|'.join(re.escape(n) for n, _ in FACTIONS))
FID = dict(FACTIONS)
unres = set()
def tokenize(s):
    if not qdb or re.search('[가-힣]', s): return s  # 한국어 글(wowf.io)은 그대로
    # 모양 맞추기: "Dungeon · 보스, 던전" → "던전 · 보스" · "Vendor · 상인, 지역 (값)" → "Vendor · 상인 (지역) · 값"
    m = re.match(r'^Dungeon · (.+), ([^,]+)$', s)
    if m: s = m.group(2) + ' · ' + m.group(1)
    m = re.match(r'^Vendor · (.+), ([^(]+?) \((.+)\)$', s)
    if m: s = 'Vendor · %s (%s) · %s' % m.groups()
    s = FRX.sub(lambda m: '{f:%d|%s}' % (FID[m.group(0)], m.group(0)), s)
    m = re.match(r'^Quest · (.+)$', s)
    if m:
        parts = []
        for p in m.group(1).split(' / '):
            if p in QST: parts.append('{q:%d|%s}' % (QST[p], p))
            else:
                if p not in SKIP and not p.startswith('Tier'): unres.add(p)
                parts.append(p)
        return 'Quest · ' + ' / '.join(parts)
    out = []
    for f in re.split(r'(\{[^}]*\}| · |, | / | \(|\))', s):
        if f and not f.startswith('{') and f not in SKIP and f in NPC: f = '{n:%d|%s}' % (NPC[f], f)
        elif f and not f.startswith('{') and re.match(r'^[A-Z][a-z]', f) and f not in SKIP and ' · ' not in f: unres.add(f)
        out.append(f)
    return ''.join(out)
L = ['-- FOA UI · 포에버 BIS · 준비물 (자동 생성 · tools/forever/gen_bis.py)',
     '-- 장비 출처: wowf.io 포에버 BiS (2026-11-26 · 28 전문화 · 사이트 추천 조합 = BIS · 칸 순위 = 대체 · gh = 호드 추천이 다른 칸)',
     '--  (예전: MythicSim 포에버 시뮬 BIS 2026-11-22 · wowforever.be — 자료 파일은 tools/forever 에 남겨 둠)',
     '--       Method WoW Forever 공략 (2026-11-04 · 신성 · 보호 성기사 · 회복 드루이드 · 마부 · 소모품 / 11-24 전사 준비물)',
     '--       Wowhead 포에버 공략 (2026-11 · 마법사 · 징벌 성기사 · 조화 드루이드 · 정기 주술사 준비물 · 능력치 순서)',
     '--       공략에 60 추천이 아직 없는 전문화(고양 · 복원 주술사 · 신성 사제 · 야성)는 같은 역할 공략 기준 (psrc 에 적음)',
     '--  아이템 번호는 각 사이트의 와우헤드 포에버 링크 · 포에버 아이템 자료(QuestieDB · ATT)와 이름 대조함',
     '--  획득처의 {n:번호|영어} NPC · {q:…} 퀘스트 · {f:…} 평판 = 게임에서 그 언어 이름으로 (번호: QuestieDB GPL-3.0 포에버 합본 · ATT 평판 목록)',
     '-- nm = 게임이 정보를 아직 안 준 아이템의 한글 이름 (wowf.io · "불러오는 중…" 대신)',
     '-- from = 이 전문화 장비 목록 출처 · g = BIS { [칸] = 아이템 } · gh = 호드 BIS (다른 칸만) · alt = 대체 { 칸, 아이템 } (공략 순서) · src = 획득처 ([A]/[H] = 그 진영 조각) · en = 마부 · co = 소모품 · psrc = 준비물 출처(없으면 Method)',
     '-- PvP: Skill Capped WoW Forever PvP 장비 공략 (2026-11-19 · 공격대 전 예측 세트) · 진영 짝 · 프리미어 PvP 진영 (AllTheThings MIT)',
     'local _, ns = ...', 'ns.BIS_FOREVER = {', '\tsrc = "Method 공략",', '\tspecs = {']
for key in sorted(specs):
    d = specs[key]
    g, alt, srcs = {}, [], {}
    used = {}
    if d.get('wg'):
        g, alt = dict(d['wg']), list(d['walt'])
        for iid in list(g.values()) + list(d['wgh'].values()) + [b for _, b in alt]:
            if iid in wsrc: srcs[iid] = wsrc[iid]
    for slot, iid, s in ([] if d.get('wg') else d['pre']):
        invs = INV.get(slot)
        if not invs: continue
        n = used.get(slot, 0); used[slot] = n + 1
        inv = invs[min(n, len(invs) - 1)]
        if inv in g:  # 같은 칸 두 번째 (진영별 등) → 대체 1순위로
            alt.insert(0, (inv, iid))
        else:
            g[inv] = iid
        srcs[iid] = s
    for slot, iid, s in ([] if d.get('wg') else d['alt']):
        invs = INV.get(slot)
        if not invs or iid in g.values(): continue
        alt.append((invs[0], iid)); srcs.setdefault(iid, s)
    gs = ', '.join(f'[{k}] = {v}' for k, v in sorted(g.items()))
    als = ', '.join(f'{{ {a}, {b} }}' for a, b in alt)
    ss = ', '.join(f'[{k}] = "{esc(tokenize(v))}"' for k, v in srcs.items())
    en = ', '.join(f'{{ "{esc(s)}", "{t}", {n} }}' for s, t, n in d['E'])
    co = ', '.join(f'{{ "{esc(s)}", {n} }}' for s, t, n in d['C'])
    fr = d.get('from') or ('Method 공략' if g else '')
    ps = f', psrc = "{esc(d["psrc"])}"' if d.get('psrc') else ''
    if d.get('wgh'): ps += ', gh = { ' + ', '.join(f'[{k}] = {v}' for k, v in sorted(d['wgh'].items())) + ' }'
    L.append(f'\t\t["{key}"] = {{ from = "{esc(fr)}", stats = "{esc(d["stats"])}"{ps}, g = {{ {gs} }}, alt = {{ {als} }}, src = {{ {ss} }}, en = {{ {en} }}, co = {{ {co} }} }},')
L.append('\t},')
# PvP: Skill Capped 포에버 PvP 장비 (skillcapped_pvp.txt) · 진영 짝 (pvp_pairs.txt) · 프리미어 PvP 진영 (pvp_premier_faction.txt)
#  pvp[키] = { from, g = { [칸] = 아이템 }, alt = { { 칸, 아이템 } … }, src = 획득처 (PvE 자료에서 같은 아이템 글을 빌림) }
#  장신구: [13] = PvP 장신구(진영 휘장) · [14] = 피해(치유 · 마나) 첫째 · 대체 = 나머지 + 생존
#  pair[아이템] = 반대 진영 아이템 · fac[아이템] = 1 호드 · 2 얼라 (PvP 공략 아이템과 프리미어 PvP 장비)
SC = {'HEAD': [1], 'NECK': [2], 'SHOULDERS': [3], 'SHOULDER': [3], 'BACK': [15], 'CHEST': [5], 'WRIST': [9], 'HANDS': [10],
      'WAIST': [6], 'LEGS': [7], 'FEET': [8], 'FINGER': [11, 12], 'RING': [11, 12], 'MAIN_HAND': [16], 'TWO_HAND': [16],
      'OFF_HAND': [17], 'RANGED': [18], 'WAND': [18], 'IDOL': [18], 'TOTEM': [18], 'LIBRAM': [18], 'RELIC': [18]}
allsrc = {}
for key in specs:
    for slot, iid, sx in specs[key]['pre'] + specs[key]['alt']: allsrc.setdefault(iid, sx)
for k, v in wsrc.items(): allsrc.setdefault(k, v)
pvp_path = src_dir + '/skillcapped_pvp.txt'
pv, curp = {}, None
if os.path.exists(pvp_path):
    for line in open(pvp_path, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        if line.startswith('@'):
            curp = line[1:].split()[0]; pv[curp] = {'G': [], 'A': [], 'T': {}}; continue
        kind, body = line.split('|', 1)
        if kind == 'T':
            for part in body.split(' | '):
                cat, ids = part.split('=')
                pv[curp]['T'][cat.strip()] = [int(x) for x in ids.split(',') if x]
        else:
            pv[curp][kind].append([(a, int(b)) for a, b in (t.split(':') for t in body.split())])
L.append('\tpvp = {')
for key in sorted(pv):
    d = pv[key]
    g, alt, srcs = {}, [], {}
    for set_i, sets in enumerate([d['G']] + [[x] for x in d['A']]):
        for st in sets:
            used = {}
            for lab, iid in st:
                invs = SC.get(lab)
                if not invs: continue
                n = used.get(lab, 0); used[lab] = n + 1
                inv = invs[min(n, len(invs) - 1)]
                if set_i == 0 and inv not in g: g[inv] = iid
                elif iid not in g.values() and (inv, iid) not in alt and not any(b == iid for _, b in alt): alt.append((inv, iid))
                if iid in allsrc: srcs[iid] = allsrc[iid]
    T = d['T']
    main = T.get('Damage') or T.get('Healing and mana') or []
    if T.get('PVP'): g[13] = T['PVP'][0]
    if main: g[14] = main[0]
    for iid in main[1:] + T.get('Survival', [])[:2]:
        if iid not in g.values(): alt.append((13, iid))
    for iid in list(g.values()) + [b for _, b in alt]:
        if iid in allsrc: srcs[iid] = allsrc[iid]
    gs = ', '.join(f'[{k}] = {v}' for k, v in sorted(g.items()))
    als = ', '.join(f'{{ {a}, {b} }}' for a, b in alt)
    ss = ', '.join(f'[{k}] = "{esc(tokenize(v))}"' for k, v in srcs.items())
    L.append(f'\t\t["{key}"] = {{ from = "Skill Capped PvP 11/19", g = {{ {gs} }}, alt = {{ {als} }}, src = {{ {ss} }} }},')
L.append('\t},')
pair, fac = {}, {}
pp = src_dir + '/pvp_pairs.txt'
if os.path.exists(pp):
    for line in open(pp, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        a, f, b = line.split('|'); a, b = int(a), int(b)
        pair[a], pair[b] = b, a
        fac[a] = 2 if f == 'A' else 1
        fac[b] = 1 if f == 'A' else 2
pf = src_dir + '/pvp_premier_faction.txt'
if os.path.exists(pf):
    for line in open(pf, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        f, ids = line.split('|')
        for x in ids.split(): fac.setdefault(int(x), 2 if f == 'A' else 1)
for k, v in wfac.items(): fac.setdefault(k, v)
L.append('\tpair = { ' + ', '.join(f'[{k}] = {v}' for k, v in sorted(pair.items())) + ' },')
L.append('\tfac = { ' + ', '.join(f'[{k}] = {v}' for k, v in sorted(fac.items())) + ' },')
# 한글 이름 (wowf_names.txt): 게임이 아이템 정보를 아직 안 준 칸에 "불러오는 중…" 대신
wn = src_dir + '/wowf_names.txt'
nm = {}
if os.path.exists(wn):
    for line in open(wn, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        for part in line.split('|'):
            a, b = part.split('=', 1); nm[int(a)] = b
L.append('\tnm = { ' + ', '.join(f'[{k}] = "{esc(v)}"' for k, v in sorted(nm.items())) + ' },')
L += ['}', '']
open(out, 'w', encoding='utf-8').write('\n'.join(L))
print(len(pv), 'pvp specs', len(pair), 'pairs', len(fac), 'faction items')
print(len(specs), 'specs')
if unres: print('그대로 둔 글:', sorted(unres))
