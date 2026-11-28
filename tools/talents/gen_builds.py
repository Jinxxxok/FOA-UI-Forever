#!/usr/bin/env python3
"""
포에버 특성 빌드 → FOA_UI/TalentBuilds.lua
 - 특성 칸 표(nodes)는 지금 TalentBuilds.lua 의 것을 그대로 쓰고, PATCH 로 게임 패치를 반영한다
 - rb_*.txt : RankedBoost 빌드 (작성자 찍는 순서)  · other_*.txt : Mobalytics · ConquestCapped · Kami-labs
 - 검사: 51점 · 최대 단계 이하 · 줄 조건(줄마다 그 트리 5점) · 같은 배분 중복 없음
   작성자 순서가 줄 조건을 어기면 그 점수만 조건이 풀릴 때까지 뒤로 미룬다
   순서가 없는 빌드(작성자순서 0)는 가장 깊은 트리부터 위 줄 → 아래 줄
usage: gen_builds.py <TalentBuilds.lua> <rb.txt> <other.txt> <out.lua>
"""
import re, sys
src_path, rb_path, other_path, out_path = sys.argv[1:5]
src = open(src_path, encoding="utf-8").read()
NODES = dict(re.findall(r'^\t\t([A-Z]+) = "([^"]*)",?$', src, re.M))
OLD = {(a, b, c): e for a, b, c, d, e in re.findall(r'\{ "([A-Z]+:[a-z]+)", "([a-z]+)", "([^"]*)", "([^"]*)", "([^"]*)"', src)}

# 2026-11-25 조화 드루이드 개편 (게임 1.60.1.71139) · wowforevertalents.com · 블리자드 핫픽스 공지
PATCH = {
    104923: {"name": "Starlight Wrath"},            # Improved Wrath → Starlight Wrath (Starfire 시전 시간도 줄임)
    104931: {"name": "Moon and Stars"},             # Improved Moonfire → Moon and Stars
    104933: {"max": 2},                             # Improved Starfire 5 → 2단계 (기절만)
    104936: {"icon": 132123, "name": "Dreamstate"}, # Moonfury 삭제 → Dreamstate (ability_druid_dreamstate)
}
info, order_nodes = {}, {}
for cls, s in NODES.items():
    order_nodes[cls] = []
    for part in s.split(";"):
        nid, icon, mx, t, r, name = part.split("|", 5)
        nid = int(nid)
        d = {"cls": cls, "icon": int(icon), "max": int(mx), "t": int(t), "r": int(r), "name": name}
        d.update(PATCH.get(nid, {}))
        info[nid] = d
        order_nodes[cls].append(nid)

RB = {  # 경로 → (키, 모드, 이름)
 "warrior/fury-dps": ("WARRIOR:fury", "pve", "레이드"), "warrior/arms-dps": ("WARRIOR:arms", "pve", "레이드"),
 "warrior/protection-tank": ("WARRIOR:prot", "pve", "탱커"), "warrior/arms-pvp": ("WARRIOR:arms", "pvp", "기본"),
 "warrior/arms-leveling": ("WARRIOR:arms", "lvl", "무기 · 레벨업 (RankedBoost)"),
 "paladin/holy-healing": ("PALADIN:holy", "pve", "힐러"), "paladin/protection-tank": ("PALADIN:prot", "pve", "탱커"),
 "paladin/retribution-dps": ("PALADIN:ret", "pve", "레이드"), "paladin/holy-pvp": ("PALADIN:holy", "pvp", "기본"),
 "paladin/retribution-leveling": ("PALADIN:ret", "lvl", "징벌 · 레벨업 (RankedBoost)"),
 "hunter/beast-mastery-dps": ("HUNTER:bm", "pve", "레이드"), "hunter/marksmanship-dps": ("HUNTER:mm", "pve", "레이드"),
 "hunter/survival-dps": ("HUNTER:sv", "pve", "레이드"), "hunter/survival-pvp": ("HUNTER:sv", "pvp", "기본"),
 "hunter/beast-mastery-leveling": ("HUNTER:bm", "lvl", "야수 · 레벨업 (RankedBoost)"),
 "rogue/assassination-dps": ("ROGUE:assassination", "pve", "레이드"), "rogue/combat-dps": ("ROGUE:combat", "pve", "레이드 · 던전"),
 "rogue/subtlety-pvp": ("ROGUE:subtlety", "pvp", "기본"), "rogue/combat-leveling": ("ROGUE:combat", "lvl", "전투 · 레벨업 (RankedBoost)"),
 "priest/shadow-dps": ("PRIEST:shadow", "pve", "레이드"), "priest/holy-healing": ("PRIEST:holy", "pve", "힐러"),
 "priest/discipline-healing": ("PRIEST:disc", "pve", "힐러"), "priest/discipline-pvp": ("PRIEST:disc", "pvp", "기본"),
 "priest/shadow-leveling": ("PRIEST:shadow", "lvl", "암흑 · 레벨업 (RankedBoost)"),
 "shaman/restoration-healing": ("SHAMAN:resto", "pve", "힐러"), "shaman/elemental-dps": ("SHAMAN:ele", "pve", "레이드"),
 "shaman/enhancement-dps": ("SHAMAN:enh", "pve", "레이드"), "shaman/elemental-pvp": ("SHAMAN:ele", "pvp", "기본"),
 "shaman/enhancement-leveling": ("SHAMAN:enh", "lvl", "고양 · 레벨업 (RankedBoost)"),
 "mage/arcane-dps": ("MAGE:arcane", "pve", "레이드"), "mage/fire-dps": ("MAGE:fire", "pve", "레이드"),
 "mage/frost-dps": ("MAGE:frost", "pve", "레이드"), "mage/frost-pvp": ("MAGE:frost", "pvp", "기본"),
 "mage/frost-leveling": ("MAGE:frost", "lvl", "냉기 · 레벨업 (RankedBoost)"),
 "warlock/affliction-dps": ("WARLOCK:aff", "pve", "레이드"), "warlock/demonology-dps": ("WARLOCK:demo", "pve", "레이드"),
 "warlock/destruction-dps": ("WARLOCK:destro", "pve", "레이드"), "warlock/destruction-pvp": ("WARLOCK:destro", "pvp", "기본"),
 "warlock/affliction-leveling": ("WARLOCK:aff", "lvl", "고통 · 레벨업 (RankedBoost)"),
 "druid/restoration-healing": ("DRUID:resto", "pve", "힐러"), "druid/restoration-pvp": ("DRUID:resto", "pvp", "기본"),
 "druid/feral-combat-dps": ("DRUID:feral", "pve", "레이드"), "druid/feral-combat-tank": ("DRUID:guardian", "pve", "탱커"),
 "druid/feral-combat-hybrid": ("DRUID:feral", "pve", "하이브리드 (표범 · 곰)"),
 "druid/feral-combat-leveling": ("DRUID:feral", "lvl", "야성 · 레벨업 (RankedBoost)"),
}

def parse_runs(s):
    return [(int(a), int(b)) for a, b in (p.split(":") for p in s.split())]

def to_points(runs):
    pts, cur = [], {}
    for nid, tg in runs:
        for _ in range(tg - cur.get(nid, 0)):
            pts.append(nid)
        cur[nid] = max(cur.get(nid, 0), tg)
    return pts

def to_runs(pts):
    out, cnt = [], {}
    for nid in pts:
        cnt[nid] = cnt.get(nid, 0) + 1
        if out and out[-1][0] == nid: out[-1][1] = cnt[nid]
        else: out.append([nid, cnt[nid]])
    return " ".join("%d:%d" % (a, b) for a, b in out)

def gate_fix(pts):
    """줄 조건을 지키도록: 못 찍는 점수는 찍을 수 있을 때까지 뒤로"""
    spent, done, out, wait = [0, 0, 0], {}, [], list(pts)
    moved = 0
    while wait:
        for i, nid in enumerate(wait):
            n = info[nid]
            if spent[n["t"]] >= (n["r"] - 1) * 5:
                out.append(nid); spent[n["t"]] += 1; done[nid] = done.get(nid, 0) + 1
                if i: moved += 1
                del wait[i]
                break
        else:
            raise SystemExit("줄 조건을 못 지킴: %r" % wait)
    return out, moved

def auto_order(final):
    """작성자 순서가 없을 때: 가장 깊은 트리부터, 위 줄 → 아래 줄 (같은 줄은 칸 표 순서)"""
    cls = info[next(iter(final))]["cls"]
    tree_pts = [0, 0, 0]
    for nid, v in final.items(): tree_pts[info[nid]["t"]] += v
    trees = sorted(range(3), key=lambda t: -tree_pts[t])
    pts = []
    for t in trees:
        nodes = sorted([n for n in order_nodes[cls] if n in final and info[n]["t"] == t],
                       key=lambda n: (info[n]["r"], order_nodes[cls].index(n)))
        for n in nodes: pts += [n] * final[n]
    return pts

def check(key, label, pts):
    cls = key.split(":")[0]
    cnt = {}
    for n in pts:
        assert n in info, (key, label, n)
        assert info[n]["cls"] == cls, (key, label, n)
        cnt[n] = cnt.get(n, 0) + 1
        assert cnt[n] <= info[n]["max"], ("최대 단계 초과", key, label, info[n]["name"], cnt[n], info[n]["max"])
    assert len(pts) == 51, ("51점 아님", key, label, len(pts))
    return cnt

entries = []
def add(key, mode, label, origin, author, runs):
    pts = to_points(parse_runs(runs))
    if not author:
        fin = {}
        for n in pts: fin[n] = fin.get(n, 0) + 1
        pts = auto_order(fin)
    pts, moved = gate_fix(pts)
    cnt = check(key, label, pts)
    entries.append((key, mode, label, origin, to_runs(pts), author, cnt, moved))

for line in open(other_path, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    key, mode, label, origin, author, runs = line.split("|")
    if runs == "=KEEP":
        runs = OLD[(key, mode, label)]
    add(key, mode, label, origin, author == "1", runs)
    if origin.startswith("Mobalytics") and entries[-1][2] == label and False: pass
for line in open(rb_path, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    path, runs = line.split("|")
    key, mode, label = RB[path]
    add(key, mode, label, "RankedBoost", True, runs)

# Kami-labs 는 맨 뒤로 (예전 파일 순서)
entries.sort(key=lambda e: (e[3] == "Kami-labs",))
# 같은 배분 중복 검사 (같은 키 · 모드)
seen = {}
for e in entries:
    sig = (e[0], e[1], tuple(sorted(e[6].items())))
    if sig in seen: print("중복:", e[0], e[1], e[2], "=", seen[sig])
    seen[sig] = e[2]
for e in entries:
    if e[7]: print("줄 조건 때문에 뒤로 민 점수: %s %s %s → %d" % (e[0], e[1], e[2], e[7]))

def node_str(cls):
    return ";".join("%d|%d|%d|%d|%d|%s" % (n, info[n]["icon"], info[n]["max"], info[n]["t"], info[n]["r"], info[n]["name"]) for n in order_nodes[cls])

out = []
out.append("-- FOA UI · 포에버 특성 빌드 (레벨업 · PvE · PvP) — tools/talents/README.md")
out.append("-- 출처 (게임 빌드 1.60.1.71139, 2026-11-28 확인):")
out.append("--   RankedBoost 직업별 빌드 (PvE · PvP · 레벨업 · 작성자 찍는 순서) · https://rankedboost.com/world-of-warcraft/forever/build/")
out.append("--   Mobalytics 인증 PvP 공략 (작성자 이름 표기) · https://mobalytics.gg/wow-forever/pvp-class-guides")
out.append("--   ConquestCapped 조화 드루이드 (11/25 조화 개편 뒤 새 트리) · https://conquestcapped.com/guides/wow-forever/wow-forever-balance-druid-talents/")
out.append("--   Kami-labs 잠행 도적 빌드 · https://kami-labs.fr/en/wow-forever/builds/")
out.append("-- 특성 칸 번호(노드)는 사이트들이 같은 게임 번호를 쓴다 → 게임 안에서는 노드 번호로 먼저 찾고, 없으면 아이콘으로 찾는다.")
out.append("--   조화 드루이드 칸은 11/25 개편(Starlight Wrath · Moon and Stars · Improved Starfire 2단계 · Dreamstate)을 반영했다.")
out.append("-- nodes[직업] = \"노드|아이콘 파일|최대 단계|트리(0-2)|줄|영문 이름;...\"")
out.append("-- list = { \"직업:전문화\", 모드(lvl · pve · pvp), \"빌드 이름\", \"출처\", \"노드:목표단계 ...\" (찍는 순서), 작성자 순서면 true }")
out.append("--   찍는 순서: 작성자 순서가 있으면 그대로(줄 조건을 어기는 점수만 뒤로), 없으면 FOA 가 위 줄부터 정리")
out.append("local _, ns = ...")
out.append("local b = select(4, GetBuildInfo()) or 0")
out.append("if not (b >= 16001 and b < 20000) then return end")
out.append("ns.TalentBuilds = {")
out.append('\tver = "1.60.1.71139",')
out.append("\tnodes = {")
for cls in NODES:
    out.append('\t\t%s = "%s",' % (cls, node_str(cls)))
out.append("\t},")
out.append("\tlist = {")
for key, mode, label, origin, runs, author, cnt, moved in entries:
    out.append('\t\t{ "%s", "%s", "%s", "%s", "%s"%s },' % (key, mode, label, origin, runs, ", true" if author else ""))
out.append("\t},")
out.append("}")
open(out_path, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("빌드", len(entries), "개 →", out_path)
from collections import Counter
print(Counter(e[1] for e in entries))
