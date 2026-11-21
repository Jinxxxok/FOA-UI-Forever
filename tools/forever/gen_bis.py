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
for line in open(src_dir + '/cons.txt', encoding='utf-8'):
    line = line.strip()
    if not line: continue
    if line.startswith('@'):
        keys = line[1:].split()
        for k in keys: specs.setdefault(k, {'pre': [], 'alt': [], 'stats': '', 'E': [], 'C': []})
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
    if not qdb: return s
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
     '-- 출처: MythicSim 포에버 시뮬 BIS (2026-11-22 · 공격대 전) · wowforever.be (방어 전사 · 신성 사제 · 복원 주술사)',
     '--       Method WoW Forever 공략 (2026-11-04 · 신성 · 보호 성기사 · 회복 드루이드 · 마부 · 소모품)',
     '--  아이템 번호는 각 사이트의 와우헤드 포에버 링크 · 포에버 아이템 자료(QuestieDB · ATT)와 이름 대조함',
     '--  획득처의 {n:번호|영어} NPC · {q:…} 퀘스트 · {f:…} 평판 = 게임에서 그 언어 이름으로 (번호: QuestieDB GPL-3.0 포에버 합본 · ATT 평판 목록)',
     '-- from = 이 전문화 장비 목록 출처 · g = BIS { [칸] = 아이템 } · alt = 대체 { 칸, 아이템 } (공략 순서) · src = 획득처 · en = 마부 · co = 소모품',
     'local _, ns = ...', 'ns.BIS_FOREVER = {', '\tsrc = "Method 공략",', '\tspecs = {']
for key in sorted(specs):
    d = specs[key]
    g, alt, srcs = {}, [], {}
    used = {}
    for slot, iid, s in d['pre']:
        invs = INV.get(slot)
        if not invs: continue
        n = used.get(slot, 0); used[slot] = n + 1
        inv = invs[min(n, len(invs) - 1)]
        if inv in g:  # 같은 칸 두 번째 (진영별 등) → 대체 1순위로
            alt.insert(0, (inv, iid))
        else:
            g[inv] = iid
        srcs[iid] = s
    for slot, iid, s in d['alt']:
        invs = INV.get(slot)
        if not invs or iid in g.values(): continue
        alt.append((invs[0], iid)); srcs.setdefault(iid, s)
    gs = ', '.join(f'[{k}] = {v}' for k, v in sorted(g.items()))
    als = ', '.join(f'{{ {a}, {b} }}' for a, b in alt)
    ss = ', '.join(f'[{k}] = "{esc(tokenize(v))}"' for k, v in srcs.items())
    en = ', '.join(f'{{ "{esc(s)}", "{t}", {n} }}' for s, t, n in d['E'])
    co = ', '.join(f'{{ "{esc(s)}", {n} }}' for s, t, n in d['C'])
    fr = d.get('from') or ('Method 공략' if g else '')
    L.append(f'\t\t["{key}"] = {{ from = "{esc(fr)}", stats = "{esc(d["stats"])}", g = {{ {gs} }}, alt = {{ {als} }}, src = {{ {ss} }}, en = {{ {en} }}, co = {{ {co} }} }},')
L += ['\t},', '}', '']
open(out, 'w', encoding='utf-8').write('\n'.join(L))
print(len(specs), 'specs')
if unres: print('그대로 둔 글:', sorted(unres))
