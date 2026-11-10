#!/usr/bin/env python3
"""
월드 드랍 · 필드 몹 · 필드 희귀몹 · 상인 · 평판 · 던전 일반몹 장비 출처 → FOA_UI/ForeverSources.lua
 자료: wowf.io 아이템 데이터베이스 (/items, 아이템마다 얻는 곳) · 2026-11-10 수집
  - 장착 부위가 있는 고급(초록) 이상 장비만, 출처 종류: 월드 드랍 · 몹 드랍 · 희귀 몹/발견 · 상인 · 평판 · 던전 일반 몹/희귀 드랍
  - 보스 · 퀘스트 · 제작 출처는 기존 자료(ForeverLoot · ForeverQuestRewards · ForeverCrafts)가 맡는다
 wowf_src_names.txt : 이름 사전 (줄 번호 = 0부터)
 wowf_src_rows.txt  : "아이템:요구레벨:출처,출처;..."  출처 = 종류(w m r v p t x) + 진영(0 공통 1 호드 2 얼라) + 값(이름 번호 / 던전 키)
                      "+v3" = 상인 3곳 더 · "+m2" = 몹 2종 더
사용: python3 -I gen_sources.py <출력.lua>
"""
import sys, os
here = os.path.dirname(os.path.abspath(__file__))
names = open(os.path.join(here, "wowf_src_names.txt"), encoding="utf-8").read().strip().split("\n")
rows = open(os.path.join(here, "wowf_src_rows.txt"), encoding="utf-8").read().strip()
# 필드 희귀몹 지역 (wowf.io 희귀 몹 지도)
ZONE = {"행동대장 채찍송곳니": "돌발톱 산맥", "이안 스위프트리버": "불모의 땅", "사자왕 후마르": "불모의 땅",
        "껑충발 타크": "불모의 땅", "번개갈기": "불모의 땅", "Dro'zem the Blasphemous": "붉은마루 산맥",
        "칼날심장": "버섯구름 봉우리", "Nightveiled Rotheap": "저습지", "Lordaeron Captain": "로데론의 폐허"}
def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
with open(sys.argv[1], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 장비 얻는 곳: 월드 드랍 · 필드 몹 · 필드 희귀몹 · 상인 · 평판 · 던전 일반 몹 (자동 생성 · tools/items/gen_sources.py)\n")
    f.write("-- 자료: wowf.io 아이템 데이터베이스 (2026-11-10) · 보스 · 퀘스트 · 제작은 다른 파일\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\n\n")
    f.write("local N = { [0] = %s,\n" % q(names[0]))
    for n in names[1:]:
        f.write("\t%s,\n" % q(n))
    f.write("}\nlocal ZONE = {\n")
    for k, v in ZONE.items():
        f.write("\t[%s] = %s,\n" % (q(k), q(v)))
    f.write("}\n")
    f.write("local RAW = %s\n\n" % q(rows))
    f.write('''-- [아이템] = { rl = 요구 레벨, src = { { 종류, 진영, 값 }, ... }, more = { v = n, m = n } }
local S = {}
for row in RAW:gmatch("[^;]+") do
	local id, rl, rest = row:match("^(%d+):(%d+):(.+)$")
	if id then
		local e = { rl = tonumber(rl), src = {}, more = {} }
		for tok in rest:gmatch("[^,]+") do
			local k = tok:sub(1, 1)
			if k == "+" then
				e.more[tok:sub(2, 2)] = tonumber(tok:sub(3))
			else
				local val = tok:sub(3)
				if k == "m" or k == "r" or k == "v" or k == "p" then val = N[tonumber(val)] end
				table.insert(e.src, { k, tonumber(tok:sub(2, 2)) or 0, val })
			end
		end
		S[tonumber(id)] = e
	end
end
ns.FOREVER_SOURCES = S

-- 던전 일반 몹 · 모든 몹 희귀 드랍은 던전 전리품 목록에도 ("희귀 · 선택" 칸, 진행 순서에는 안 들어감)
do
	local byKey = {}
	for id, e in pairs(S) do
		for _, s in ipairs(e.src) do
			if s[1] == "t" or s[1] == "x" then
				local g = byKey[s[3]] or { t = {}, x = {} }
				byKey[s[3]] = g
				table.insert(g[s[1]], id)
			end
		end
	end
	for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
		local g = byKey[d.key]
		local done = false
		for _, b in ipairs(d.bosses or {}) do if b[5] == "Trash" or b[5] == "Any mob" then done = true end end
		if g and d.bosses and not done then
			if #g.t > 0 then table.sort(g.t); table.insert(d.bosses, { "일반 몹", g.t, 0, 3, "Trash" }) end
			if #g.x > 0 then table.sort(g.x); table.insert(d.bosses, { "모든 몹 · 희귀 드랍", g.x, 0, 3, "Any mob" }) end
		end
	end
end

-- 던전 키 → 이름 (ForeverLoot 의 한글 이름)
local function DungeonName(key)
	for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
		if d.key == key then return d.ko or d.en end
	end
	return key
end

local WINGED = { "붉은십자군 수도원 ", "스트라솔름 ", "검은바위 첨탑 ", "혈투의 전장 " }

-- 출처 한 줄. 진영이 정해진 출처는 내 진영 것만 (없으면 전부)
function ns.ItemSourceText(id)
	local e = S[id]
	if not e then return end
	local fg = UnitFactionGroup and UnitFactionGroup("player")
	local facN = fg == "Horde" and 1 or (fg == "Alliance" and 2 or 0)
	local by, order = {}, {}
	for _, s in ipairs(e.src) do
		if s[2] == 0 or s[2] == facN or facN == 0 then
			if not by[s[1]] then by[s[1]] = {}; order[#order + 1] = s[1] end
			table.insert(by[s[1]], s[3])
		end
	end
	local parts = {}
	for _, k in ipairs(order) do
		local l = by[k]
		if k == "w" then
			parts[#parts + 1] = "월드 드랍"
		elseif k == "m" then
			parts[#parts + 1] = "필드 몹 · " .. table.concat(l, ", ") .. (e.more.m and (" 외 " .. e.more.m .. "종") or "")
		elseif k == "r" then
			for _, n in ipairs(l) do
				if n:find("^도서관 책") or n:find("^숨은 아이템") then parts[#parts + 1] = n
				else parts[#parts + 1] = "필드 희귀몹 · " .. n .. (ZONE[n] and (" (" .. ZONE[n] .. ")") or "") end
			end
		elseif k == "v" then
			parts[#parts + 1] = "상인 · " .. table.concat(l, ", ") .. (e.more.v and (" 외 " .. e.more.v .. "곳") or "")
		elseif k == "p" then
			parts[#parts + 1] = "평판 보상 · " .. (l[1]:gsub(" 평판 · ", " · "))
		elseif k == "t" or k == "x" then
			-- 날개가 여러 개인 던전은 한 번만: "붉은십자군 수도원 묘지 · 도서관"
			local ds, grp = {}, {}
			for _, key in ipairs(l) do
				local n = DungeonName(key)
				local pre, wing
				for _, p in ipairs(WINGED) do if n:sub(1, #p) == p then pre, wing = p, n:sub(#p + 1) end end
				if pre then
					if not grp[pre] then grp[pre] = {}; ds[#ds + 1] = pre end
					table.insert(grp[pre], wing)
				else ds[#ds + 1] = n end
			end
			for i, n in ipairs(ds) do if grp[n] then ds[i] = n .. table.concat(grp[n], "·") end end
			parts[#parts + 1] = table.concat(ds, ", ") .. (k == "t" and " · 던전 일반 몹" or " · 던전 희귀 드랍(모든 몹)")
		end
	end
	if #parts == 0 then return end
	return table.concat(parts, "  /  ")
end

-- 내 진영에서 얻을 수 있는가
function ns.ItemSourceForMe(id)
	local e = S[id]
	if not e then return false end
	local fg = UnitFactionGroup and UnitFactionGroup("player")
	local facN = fg == "Horde" and 1 or (fg == "Alliance" and 2 or 0)
	for _, s in ipairs(e.src) do if s[2] == 0 or s[2] == facN then return true end end
	return false
end
''')
print(len(rows.split(";")), "items", len(names), "names")
