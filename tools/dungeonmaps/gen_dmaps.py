#!/usr/bin/env python3
"""
던전 지도 그림(타일 파일 번호) + 보스 위치 → FOA_UI/DungeonMaps.lua
 자료: 내 게임 파일 (본섭 12.1.5 · UiMapXMapArt · UiMapArtTile · JournalEncounter 표, tools/mapreveal 의 CASC 읽기로 뽑은 dmaps.json)
       지도 그림 파일은 포에버 게임 파일에도 그대로 있다 (확인함)
 보스 맞추기: AllTheThings 의 던전 도감 번호(e) → 없으면 한글 이름
"""
import json, re, sys
dm = json.load(open(sys.argv[1], encoding="utf-8"))
dj = json.load(open(sys.argv[2], encoding="utf-8"))
loot = open(sys.argv[3], encoding="utf-8").read()
FLOORS = {
 "ragefire": [213], "wailing": [279], "deadmines": [291, 292], "shadowfang": [310, 311, 312, 313, 314, 315, 316],
 "blackfathom": [221, 222, 223], "stockade": [225], "gnomeregan": [226, 227, 228, 229], "kraul": [301], "downs": [300],
 "sm_gy": [302], "sm_lib": [303], "sm_arm": [304], "sm_cath": [305], "uldaman": [230, 231], "zulfarrak": [219],
 "maraudon": [280, 281], "sunken": [220], "brd": [242, 243], "lbrs": [250, 251, 252, 253, 254, 255], "ubrs": [250, 251, 252, 253, 254, 255],
 "dm_east": [234, 235, 236, 237, 238, 239, 240], "dm_west": [234, 235, 236, 237, 238, 239, 240], "dm_north": [234, 235, 236, 237, 238, 239, 240],
 "strat_live": [317, 318], "strat_ud": [317, 318], "scholo": [476, 477, 478, 479], "onyxia": [248],
}
ej = dm["ej"]
byId = {e["id"]: e for e in ej}
norm = lambda s: re.sub(r"[\s·:,'\-]", "", s)
# 보스 목록 (ForeverLoot.lua): key → [(ko, npc)]
cur = None
bosses = {}
for line in loot.splitlines():
    m = re.search(r'key = "([a-z_]+)"', line)
    if m: cur = m.group(1); bosses[cur] = []
    m = re.search(r'\{ "([^"]+)", \{[^}]*\}, (\d+), (\d), "', line)
    if m and cur: bosses[cur].append((m.group(1), int(m.group(2))))
# ATT 도감 번호: npc → enc
enc = {}
for d in dj:
    for b in d["bosses"]:
        if b.get("enc"): enc[b["npc"]] = b["enc"]
pos, used = {}, set()
miss = []
for key, fl in FLOORS.items():
    cand = [e for e in ej if e["ui"] in fl and e["x"] > 0]
    for ko, npc in bosses.get(key, []):
        e = byId.get(enc.get(npc, -1))
        if e and e["ui"] not in fl: e = None
        if not e:
            for c in cand:
                if norm(c["name"]) == norm(ko) or (len(norm(ko)) >= 3 and (norm(ko) in norm(c["name"]) or norm(c["name"]) in norm(ko))):
                    e = c; break
        if e:
            pos[npc] = (e["ui"], e["x"], e["y"])
        else:
            miss.append((key, ko))
maps = {u: dm["maps"][str(u)]["fids"] for fl in FLOORS.values() for u in fl if str(u) in dm["maps"]}
out = ["-- FOA UI · 던전 지도 + 보스 위치 (자동 생성 · tools/dungeonmaps/gen_dmaps.py)",
       "-- 지도 그림: 게임 파일의 던전 지도 타일 (포에버 파일에도 있음) · 보스 위치: 게임 파일의 던전 도감 표",
       "local _, ns = ...", "ns.DUNGEON_MAPS = {", "\tfloors = {"]
for k, fl in FLOORS.items():
    out.append('\t\t%s = { %s },' % (k, ", ".join(str(u) for u in fl if u in maps)))
out.append("\t},\n\ttiles = {")
for u, f in sorted(maps.items()):
    out.append('\t\t[%d] = "%s",' % (u, ",".join(map(str, f))))
out.append("\t},\n\t-- [NPC 번호] = { 지도, x, y }\n\tpos = {")
for npc, (u, x, y) in sorted(pos.items()):
    out.append("\t\t[%d] = { %d, %.4f, %.4f }," % (npc, u, x, y))
out.append("\t},\n}")
open(sys.argv[4], "w", encoding="utf-8").write("\n".join(out) + "\n")
print("maps", len(maps), "pos", len(pos), "miss", len(miss))
for m in miss: print("  -", m)
