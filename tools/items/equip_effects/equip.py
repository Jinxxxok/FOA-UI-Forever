# 착용 · 적중 시 효과 문장 틀 모으기 → equip_templates.json  (wdc5.py · sparse.py · koKR Spell.db2 필요)
import sys, struct, re, json, collections; sys.path.insert(0, ".")
import wdc5
from sparse import parse_sparse_strings
f = lambda u: struct.unpack("<f", struct.pack("<I", u & 0xffffffff))[0]
ie = {rid: v for rid, v, rel in wdc5.parse(open("969941.db2", "rb").read())}       # [슬롯, 발동 종류, 충전, 재사용, 분류 재사용, 분류, 주문, …]
x = collections.defaultdict(set)
for rid, v, rel in wdc5.parse(open("3177687.db2", "rb").read()): x[v[0]].add(rel)  # 아이템 효과 → 아이템
eff = collections.defaultdict(list)
for rid, v, rel in wdc5.parse(open("1140088.db2", "rb").read()): eff[rel].append(v) # [오라, 난이도, 효과 순번, 효과, …, 22 기본값, …]
desc = parse_sparse_strings(open("1140089_ko.db2", "rb").read(), 3)
spell_items = collections.defaultdict(set); trig = {}
for eid, v in ie.items():
    if v[1] in (1, 2): spell_items[v[6]] |= x.get(eid, set()); trig[v[6]] = v[1]
groups = collections.defaultdict(lambda: {"items": 0, "spells": [], "aura": set(), "ex": None, "trig": set()})
for sid, items in spell_items.items():
    d = desc.get(sid)
    if not d or not d[1]: continue
    vals = {v[2] + 1: f(v[22]) for v in eff.get(sid, [])}
    t = re.sub(r"\$\{\$s(\d)\}(\.\d)?", "N", d[1]); t = re.sub(r"\$s(\d)", "N", t)
    t = re.sub(r"\$\{[^}]*\}", "X", t); t = re.sub(r"\$[a-zA-Z]+\d*", "X", t)
    g = groups[t]; g["items"] += len(items); g["spells"].append(sid); g["trig"].add(trig[sid])
    for v in eff.get(sid, []): g["aura"].add((v[0], v[25][0] if isinstance(v[25], tuple) else v[25]))
    if not g["ex"]: g["ex"] = (sid, d[1][:90], {k: round(v, 2) for k, v in vals.items()})
out = sorted(groups.items(), key=lambda kv: -kv[1]["items"])
json.dump([[t, g["items"], len(g["spells"]), sorted(g["aura"]), sorted(g["trig"]), g["ex"]] for t, g in out],
          open("equip_templates.json", "w"), ensure_ascii=False)
print("templates", len(out))
