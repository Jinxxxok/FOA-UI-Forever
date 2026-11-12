-- FOA UI · 장비 도우미 (GearQuest 처럼, FOA 결로)
--  · 캐릭터 창 장비 칸 오른쪽 클릭 → 그 칸 업그레이드 후보 (지금 레벨 · 전문화 FOA 점수 순) + 추천 마법부여
--  · 아이템 툴팁: 그 칸에서 몇 점짜리인지 (지금 레벨 최고템 = 100)
--  · 지금 레벨 칸 최고템(또는 크게 좋은 템)을 얻으면 화면 위에 화려한 알림
--  후보 목록은 BIS 탭과 같은 자료(Dungeon.lua 순위)를 쓴다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Gear")
local F, C = Ink.font, Ink.c
local plain = Ink.plain
local build = select(4, GetBuildInfo()) or 0
local FOREVER = build >= 16001 and build < 20000 -- 추천 마법부여 · 순위 자료가 포에버(클래식 장비) 기준이라 포에버에서만

local GOLD = { 1, 0.82, 0.3 }
local UP = { 0.44, 0.83, 0.55 }
local DOWN = { 0.85, 0.47, 0.42 }
local QCOL = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 0.95, 0.95, 0.95 }, [2] = { 0.37, 0.83, 0.37 }, [3] = { 0.29, 0.62, 1 },
	[4] = { 0.76, 0.42, 1 }, [5] = { 1, 0.55, 0.15 }, [6] = { 0.9, 0.8, 0.5 },
}

-- 캐릭터 창 칸 번호 → 던전 도감 부위 (Dungeon.lua 와 같은 표) · BIS 탭 칸 순서
local INV2EJ = { [1] = 0, [2] = 1, [3] = 2, [15] = 3, [5] = 4, [9] = 5, [10] = 6, [6] = 7, [7] = 8, [8] = 9,
	[11] = 12, [12] = 12, [13] = 13, [14] = 13, [16] = 10, [17] = 11 }
local INV_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }
local SLOT_KO = { [1] = "머리", [2] = "목", [3] = "어깨", [15] = "등", [5] = "가슴", [9] = "손목", [10] = "손", [6] = "허리",
	[7] = "다리", [8] = "발", [11] = "반지", [12] = "반지", [13] = "장신구", [14] = "장신구", [16] = "주장비", [17] = "보조장비" }
local LOC2EJ = {
	INVTYPE_HEAD = 0, INVTYPE_NECK = 1, INVTYPE_SHOULDER = 2, INVTYPE_CLOAK = 3, INVTYPE_CHEST = 4, INVTYPE_ROBE = 4,
	INVTYPE_WRIST = 5, INVTYPE_HAND = 6, INVTYPE_WAIST = 7, INVTYPE_LEGS = 8, INVTYPE_FEET = 9,
	INVTYPE_WEAPON = 10, INVTYPE_2HWEAPON = 10, INVTYPE_WEAPONMAINHAND = 10,
	INVTYPE_WEAPONOFFHAND = 11, INVTYPE_SHIELD = 11, INVTYPE_HOLDABLE = 11, INVTYPE_FINGER = 12, INVTYPE_TRINKET = 13,
}
local LOC2INV = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 15, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
	INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8,
	INVTYPE_WEAPON = 16, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17,
	INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13,
}

-------------------------------------------------------------------------------
-- 순위 자료 (BIS 탭과 같은 것)
-------------------------------------------------------------------------------
local function D() return Ink.modules.Dungeon end

function M:SlotList(ej)
	local d = D()
	if not (d and ej) then return {} end
	pcall(d.BuildRanks, d)
	if d.levelMode and d.levelRanks then return d.levelRanks[ej] or {} end
	local l = {}
	for _, r in pairs(d.ranks or {}) do if r.slot == ej then l[#l + 1] = r end end
	table.sort(l, function(a, b) return a.rank < b.rank end)
	return l
end

local function ScoreOf(link, offhand)
	local sc = ns.Score
	if not (sc and link) then return nil end
	local ok, v = pcall(sc.Score, sc, link, offhand)
	return ok and v or nil
end

-- 착용 대비 % (반올림한 정수) · 아이템 툴팁과 같은 계산 (Score:PctOf)
local function UpPct(new, old)
	local sc = ns.Score
	if not (sc and sc.PctOf) then
		return (old and old > 0 and new) and math.floor((new / old - 1) * 100 + 0.5) or nil
	end
	local ok, p = pcall(sc.PctOf, sc, new, old)
	if not (ok and p) then return nil end
	return math.floor(p + (p >= 0 and 0.5 or -0.5))
end

local function ItemLink(it)
	if it.link then return it.link end
	local _, link = C_Item.GetItemInfo(it.id)
	return link or ("item:" .. it.id)
end

-- 그 칸 최고 점수 (지금 레벨 1순위)
function M:BestScore(ej)
	local l = self:SlotList(ej)
	local top = l[1]
	if not top then return nil end
	return top.score or ScoreOf(ItemLink(top.it), ej == 11), top
end

-- 툴팁용: 이 아이템이 그 칸에서 몇 점인지 (1순위 = 100)
function M:SlotRank(link)
	if Ink.db.gearSlotRank == false or not link then return nil end
	local loc = select(4, C_Item.GetItemInfoInstant(link))
	local ej = loc and LOC2EJ[loc]
	if not ej then return nil end
	local best = self:BestScore(ej)
	local mine = ScoreOf(link, ej == 11)
	if not (best and mine and best > 0) then return nil end
	return math.max(0, math.min(100, math.floor(mine / best * 100 + 0.5)))
end
ns.GearSlotRank = function(link)
	if not FOREVER then return nil end
	local ok, v = pcall(M.SlotRank, M, link)
	return ok and v or nil
end

-------------------------------------------------------------------------------
-- 추천 마법부여 (포에버 마법부여 목록 · 지금 전문화 가중치로 고른다)
--  { 영문 이름, 숙련, 효과 } · 효과 키: 능력치(str agi …) / all 모든 능력치 / wdmg 무기 공격력
--  dodgep · hastep · blockp (1% 단위) / crusader 십자군 / school 속성 주문 피해
-------------------------------------------------------------------------------
local ENCH = {
	[9] = { -- 손목
		{ "Superior Strength", 295, { str = 9 } }, { "Superior Agility", 295, { agi = 9 } }, { "Superior Stamina", 300, { sta = 9 } },
		{ "Superior Intellect", 300, { int = 9 } }, { "Superior Spirit", 270, { spi = 9 } }, { "Healing Power", 300, { heal = 24 } },
		{ "Greater Spellpower", 300, { sp = 16 } }, { "Mana Regeneration", 290, { mp5 = 4 } }, { "Deflection", 235, { def = 7 } },
		{ "Greater Strength", 240, { str = 7 } }, { "Greater Agility", 240, { agi = 7 } }, { "Greater Stamina", 245, { sta = 7 } },
		{ "Greater Intellect", 255, { int = 7 } }, { "Greater Spirit", 220, { spi = 7 } }, { "Lesser Healing Power", 205, { heal = 16, sdmg = 6 } },
		{ "Strength", 180, { str = 5 } }, { "Agility", 190, { agi = 5 } }, { "Stamina", 170, { sta = 5 } },
		{ "Intellect", 210, { int = 5 } }, { "Spirit", 165, { spi = 5 } },
	},
	[5] = { -- 가슴
		{ "Greater Stats", 300, { all = 4 } }, { "Major Stamina", 275, { sta = 10 } }, { "Major Intellect", 290, { int = 10 } },
		{ "Stats", 245, { all = 3 } }, { "Superior Stamina", 220, { sta = 8 } }, { "Superior Intellect", 230, { int = 8 } },
		{ "Lesser Stats", 200, { all = 2 } }, { "Greater Stamina", 160, { sta = 6 } }, { "Greater Intellect", 185, { int = 6 } },
	},
	[15] = { -- 등
		{ "Agility", 300, { agi = 5 } }, { "Dodge", 300, { dodgep = 1 } }, { "Superior Defense", 285, { armor = 70 } },
		{ "Greater Defense", 205, { armor = 60 } }, { "Lesser Agility", 225, { agi = 3 } }, { "Defense", 155, { armor = 30 } },
	},
	[8] = { -- 발
		{ "Greater Agility", 295, { agi = 7 } }, { "Greater Stamina", 260, { sta = 7 } }, { "Spirit", 275, { spi = 5 } },
		{ "Agility", 235, { agi = 5 } }, { "Stamina", 215, { sta = 5 } }, { "Lesser Spirit", 190, { spi = 4 } },
	},
	[10] = { -- 손
		{ "Superior Agility", 300, { agi = 15 } }, { "Superior Strength", 300, { str = 15 } }, { "Healing Power", 300, { heal = 35, sdmg = 12 } },
		{ "Minor Haste", 250, { hastep = 1 } }, { "Fire Power", 300, { school = 20, sch = "fire" } }, { "Frost Power", 300, { school = 20, sch = "frost" } },
		{ "Shadow Power", 300, { school = 20, sch = "shadow" } }, { "Arcane Power", 300, { school = 20, sch = "arcane" } },
		{ "Natural Power", 300, { school = 20, sch = "nature" } }, { "Holy Power", 300, { school = 20, sch = "holy" } },
		{ "Greater Agility", 270, { agi = 10 } }, { "Greater Strength", 295, { str = 10 } }, { "Agility", 210, { agi = 7 } }, { "Strength", 225, { str = 7 } },
	},
	shield = {
		{ "Superior Spirit", 280, { spi = 9 } }, { "Greater Stamina", 265, { sta = 9 } }, { "Stamina", 210, { sta = 7 } },
		{ "Greater Spirit", 230, { spi = 7 } }, { "Lesser Block", 195, { blockp = 2 } }, { "Lesser Stamina", 155, { sta = 5 } },
	},
	weapon = {
		{ "Crusader", 300, { crusader = 1 } }, { "Agility", 290, { agi = 15 } }, { "Strength", 290, { str = 15 } },
		{ "Spell Power", 300, { sp = 30 } }, { "Healing Power", 300, { heal = 55 } }, { "Mighty Intellect", 300, { int = 22 } },
		{ "Mighty Spirit", 300, { spi = 22 } }, { "Superior Striking", 300, { wdmg = 5 } }, { "Fiery Weapon", 265, { fiery = 1 } },
		{ "Greater Striking", 245, { wdmg = 4 } }, { "Winter's Might", 190, { school = 15, sch = "frost" } }, { "Striking", 195, { wdmg = 3 } },
	},
	twohand = {
		{ "Crusader", 300, { crusader = 1 } }, { "Agility", 290, { agi = 25 } }, { "Strength", 290, { str = 25 } },
		{ "Spellblasting", 300, { sp = 65 } }, { "Mighty Spell Power", 300, { sp = 55 } }, { "Mighty Healing Power", 300, { heal = 100, sdmg = 34 } },
		{ "Superior Impact", 295, { wdmg = 9 } }, { "Major Intellect", 300, { int = 9 } }, { "Major Spirit", 300, { spi = 9 } },
		{ "Lesser Agility", 210, { agi = 15 } }, { "Lesser Strength", 220, { str = 15 } }, { "Greater Impact", 240, { wdmg = 7 } },
	},
}
local BUDGET_SKILL = 225 -- 가성비: 이 숙련 이하 제조법 (재료가 싸다)

local STAT_KO = { str = "힘", agi = "민첩", sta = "체력", int = "지능", spi = "정신력", def = "방어 숙련", armor = "방어도",
	sp = "주문력", heal = "치유량", sdmg = "주문 피해", mp5 = "5초당 마나", wdmg = "무기 공격력", all = "모든 능력치",
	dodgep = "회피", hastep = "가속", blockp = "방패 막기" }
local STAT_SHORT = { str = "힘", agi = "민", sta = "체", int = "지", spi = "정", all = "모능", armor = "방어", def = "방숙",
	heal = "치유", sp = "주문력", mp5 = "마나", wdmg = "무공" }
local SCHOOL_KO = { fire = "화염", frost = "냉기", shadow = "암흑", arcane = "비전", nature = "자연", holy = "신성" }

-- 전문화가 쓰는 속성 (장갑 속성 마부 · 겨울의 힘)
local function MySchools()
	local sc = ns.Score
	local ok, class, spec = false, nil, nil
	if sc then ok, class, spec = pcall(sc.Spec, sc) end
	local key = ok and ((class or "") .. ":" .. (spec or "")) or ""
	local t = {}
	if key:find("^MAGE") then
		if key:find("fire") then t.fire = true elseif key:find("frost") then t.frost = true else t.arcane = true end
	elseif key:find("^WARLOCK") then t.shadow = true; if key:find("destro") then t.fire = true end
	elseif key:find("^PRIEST") and key:find("shadow") then t.shadow = true
	elseif key:find("^DRUID") and (key:find("balance") or key:find("moon")) then t.arcane = true; t.nature = true
	elseif key:find("^SHAMAN") and key:find("ele") then t.nature = true end
	return t
end

local function EnchValue(fx, w, speed, schools)
	local v = 0
	for k, n in pairs(fx) do
		if k == "all" then
			v = v + n * ((w.str or 0) + (w.agi or 0) + (w.sta or 0) + (w.int or 0) + (w.spi or 0))
		elseif k == "wdmg" then
			v = v + (w.dps or 0) * n / (speed or 2.6)
		elseif k == "dodgep" then v = v + (w.dodge or 0) * n
		elseif k == "hastep" then v = v + (w.haste or 0) * n
		elseif k == "blockp" then v = v + (w.block or 0) * n
		elseif k == "crusader" then
			-- 십자군: 자주 힘 +100 (근접만) · 클래식 환산 힘 40 정도
			if (w.dps or 0) > 2 then v = v + 40 * (w.str or 0) end
		elseif k == "fiery" then
			-- 불타는 무기: 화염 피해 발동 · 무기 초당 공격력 2.5 정도로 친다
			if (w.dps or 0) > 2 then v = v + (w.dps or 0) * 2.5 end
		elseif k == "school" then
			if schools[fx.sch] then v = v + n * (w.sdmg or w.sp or 0) * 0.9 end
		elseif k == "sch" then
			-- 위에서 같이 계산
		elseif k == "heal" then
			v = v + n * (w.heal or 0)
		elseif k == "sdmg" then
			v = v + n * (w.sdmg or w.sp or 0)
		elseif k == "sp" then
			v = v + n * math.max(w.sp or 0, w.sdmg or 0, w.heal or 0)
		else
			v = v + n * (w[k] or 0)
		end
	end
	return v
end

local function FxLabel(fx)
	if fx.crusader then return "십자군", "십자군" end
	if fx.fiery then return "불타는 무기", "불타는" end
	if fx.school then return (SCHOOL_KO[fx.sch] or "") .. " 주문 피해 +" .. fx.school, nil end
	local parts, short = {}, {}
	for _, k in ipairs({ "all", "str", "agi", "sta", "int", "spi", "sp", "heal", "sdmg", "mp5", "wdmg", "armor", "def", "dodgep", "hastep", "blockp" }) do
		local n = fx[k]
		if n then
			local pct = (k == "dodgep" or k == "hastep" or k == "blockp") and "%" or ""
			parts[#parts + 1] = STAT_KO[k] .. " +" .. n .. pct
			if STAT_SHORT[k] then short[#short + 1] = STAT_SHORT[k] .. "+" .. n end
		end
	end
	return table.concat(parts, " · "), short[1]
end

-- 칸의 마법부여 목록 (무기는 한손 · 양손, 보조장비는 방패 · 한손 무기)
local function EnchList(inv)
	local link = GetInventoryItemLink("player", inv)
	local loc = link and select(4, C_Item.GetItemInfoInstant(link))
	if inv == 16 then
		if loc == "INVTYPE_2HWEAPON" then return ENCH.twohand end
		return link and ENCH.weapon or nil
	elseif inv == 17 then
		if loc == "INVTYPE_SHIELD" then return ENCH.shield end
		if loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" then return ENCH.weapon end
		return nil
	end
	return ENCH[inv]
end

-- 무기 속도 (툴팁 오른쪽 "속도 2.60") · 못 읽으면 nil
local function WeaponSpeed(inv)
	if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
	local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", inv)
	for _, l in ipairs(ok and data and data.lines or {}) do
		local r = plain(l.rightText)
		if type(r) == "string" then
			local str = r:match("(%d+[%.,]%d%d)")
			local n = str and tonumber((str:gsub(",", ".")))
			if n and n >= 1 and n <= 4.5 then return n end
		end
	end
end

function M:Recommend(inv)
	local list = EnchList(inv)
	local sc = ns.Score
	if not (list and sc) then return nil end
	local ok, w = pcall(sc.Weights, sc)
	if not ok or type(w) ~= "table" then return nil end
	local speed = (inv == 16 or inv == 17) and WeaponSpeed(inv) or nil
	local schools = MySchools()
	local best, bestV, cheap, cheapV
	for _, e in ipairs(list) do
		local v = EnchValue(e[3], w, speed, schools)
		if v > 0 then
			if not bestV or v > bestV then best, bestV = e, v end
			if e[2] <= BUDGET_SKILL and (not cheapV or v > cheapV) then cheap, cheapV = e, v end
		end
	end
	if not best then return nil end
	return best, (cheap ~= best) and cheap or nil
end

-- 지금 발린 마법부여(짧게: "민+9 체+3")가 추천과 같은지
local ALIAS = { str = { "힘" }, agi = { "민" }, sta = { "체" }, int = { "지" }, spi = { "정" }, all = { "모능" },
	armor = { "방어" }, def = { "방숙", "방어" }, heal = { "치유" }, sp = { "주문력", "주공", "주피" }, sdmg = { "주피", "주공" },
	mp5 = { "마나" }, wdmg = { "무공", "공" }, dodgep = { "회피" }, hastep = { "가속" }, blockp = { "막기" } }
local function Applied(cur, fx)
	if type(cur) ~= "string" or cur == "" then return false end
	if fx.crusader then return cur:find("십자군", 1, true) ~= nil or cur:find("Crusader", 1, true) ~= nil end
	if fx.fiery then return cur:find("불", 1, true) ~= nil or cur:find("Fiery", 1, true) ~= nil end
	for k, n in pairs(fx) do
		if ALIAS[k] then
			local hit
			for _, a in ipairs(ALIAS[k]) do
				if cur:find(a .. "+" .. n, 1, true) then hit = true break end
			end
			if not hit then return false end
			return true
		end
	end
	if fx.school then return cur:find("+" .. fx.school, 1, true) ~= nil end
	return false
end

-------------------------------------------------------------------------------
-- 칸 업그레이드 창 (장비 칸 오른쪽 클릭)
-------------------------------------------------------------------------------
-- 줄 높이 · 창 너비 (넉넉하게: 이름 · 획득처 · 비교 알약이 겹치지 않게)
local ROWS, ROW_H, PW = 4, 54, 340
local ROW_TOP = 90 -- 첫 후보 줄 시작 (창 위에서)

local function Pill(parent)
	local p = CreateFrame("Frame", nil, parent)
	p:SetSize(52, 18)
	p.bg = Ink:Round(p, "BACKGROUND", true, false)
	p.bg:SetAllPoints()
	p.text = Ink:Text(p, F.semi, 10, C.text, "CENTER")
	p.text:SetPoint("CENTER", 0, 0)
	p.Set = function(self, txt, col, a)
		self.text:SetText(txt)
		self.text:SetTextColor(col[1], col[2], col[3])
		self.bg:SetVertexColor(col[1], col[2], col[3], a or 0.14)
		self:SetWidth(math.max(34, (self.text:GetStringWidth() or 20) + 16))
	end
	return p
end

local function NewRow(parent, i)
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(PW - 20, ROW_H - 6)
	r:RegisterForClicks("AnyUp")
	r.bg = Ink:Round(r, "BACKGROUND", true, false)
	r.bg:SetAllPoints()
	r.bd = Ink:Round(r, "BORDER", true, true)
	r.bd:SetAllPoints()
	-- 1순위 줄: 금빛 결 + 한 번 지나가는 반짝임
	r.gold = r:CreateTexture(nil, "BACKGROUND", nil, 1)
	r.gold:SetTexture(Ink.tex.white)
	r.gold:SetPoint("TOPLEFT", 1, -1)
	r.gold:SetPoint("BOTTOMRIGHT", -1, 1)
	if r.gold.SetGradient and CreateColor then
		r.gold:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.16), CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
	end
	r.gold:Hide()
	r.sheenClip = CreateFrame("Frame", nil, r)
	r.sheenClip:SetAllPoints()
	if r.sheenClip.SetClipsChildren then r.sheenClip:SetClipsChildren(true) end
	r.sheen = r.sheenClip:CreateTexture(nil, "OVERLAY")
	r.sheen:SetTexture(Ink.tex.white)
	r.sheen:SetSize(36, ROW_H + 10)
	r.sheen:SetPoint("LEFT", r.sheenClip, "LEFT", -40, 0)
	r.sheen:SetBlendMode("ADD")
	if r.sheen.SetGradient and CreateColor then
		r.sheen:SetGradient("HORIZONTAL", CreateColor(1, 0.95, 0.75, 0), CreateColor(1, 0.95, 0.75, 0.35))
	end
	r.sheen:SetAlpha(0)
	local sg = r.sheen:CreateAnimationGroup()
	local a0 = sg:CreateAnimation("Alpha"); a0:SetFromAlpha(0); a0:SetToAlpha(1); a0:SetDuration(0.1); a0:SetOrder(1)
	local t1 = sg:CreateAnimation("Translation"); t1:SetOffset(PW + 40, 0); t1:SetDuration(0.9); t1:SetOrder(2); t1:SetSmoothing("IN_OUT")
	local a1 = sg:CreateAnimation("Alpha"); a1:SetFromAlpha(1); a1:SetToAlpha(0); a1:SetDuration(0.9); a1:SetOrder(2); a1:SetSmoothing("IN")
	r.sg = sg

	r.iconBg = Ink:Round(r, "ARTWORK", true, false, 1)
	r.iconBg:SetSize(36, 36)
	r.iconBg:SetPoint("LEFT", 7, 0)
	r.iconBg:SetVertexColor(0, 0, 0, 0.6)
	r.icon = r:CreateTexture(nil, "ARTWORK", nil, 2)
	r.icon:SetSize(34, 34)
	r.icon:SetPoint("CENTER", r.iconBg, "CENTER")
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if r.CreateMaskTexture then
		local m = r:CreateMaskTexture()
		m:SetTexture(Ink.tex.round4, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		m:SetAllPoints(r.icon)
		r.icon:AddMaskTexture(m)
	end
	r.iconBd = Ink:Round(r, "OVERLAY", true, true)
	r.iconBd:SetAllPoints(r.iconBg)
	r.rank = Ink:Text(r, F.latinB, 9, C.dim, "CENTER", "OVERLAY")
	r.rank:SetPoint("BOTTOMRIGHT", r.iconBg, "BOTTOMRIGHT", 3, -3)
	r.pill = Pill(r)
	r.pill:SetPoint("RIGHT", -10, 0)
	r.name = Ink:Text(r, F.semi, 13, C.text, "LEFT")
	r.name:SetPoint("TOPLEFT", r.iconBg, "TOPRIGHT", 11, -2)
	r.name:SetPoint("RIGHT", r.pill, "LEFT", -10, 0)
	r.src = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
	r.src:SetPoint("BOTTOMLEFT", r.iconBg, "BOTTOMRIGHT", 11, 2)
	r.src:SetPoint("RIGHT", r.pill, "LEFT", -10, 0)
	r:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.07)
		if self.link then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
			GameTooltip:Show()
		end
	end)
	r:SetScript("OnLeave", function(self)
		self.bg:SetVertexColor(1, 1, 1, self.base or 0.025)
		GameTooltip:Hide()
	end)
	r:SetScript("OnClick", function(self)
		if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
	end)
	r:Hide()
	return r
end

function M:BuildPopup()
	if self.popup then return self.popup end
	local p = CreateFrame("Frame", "FOAGearPopup", Ink.root)
	p:SetSize(PW, 300)
	p:SetFrameStrata("DIALOG")
	p:EnableMouse(true)
	p:SetClampedToScreen(true)
	p.shadow = p:CreateTexture(nil, "BACKGROUND", nil, -8)
	p.shadow:SetTexture(Ink.tex.glow)
	p.shadow:SetPoint("TOPLEFT", -30, 26)
	p.shadow:SetPoint("BOTTOMRIGHT", 30, -34)
	p.shadow:SetVertexColor(0, 0, 0, 0.75)
	p.bg = Ink:Round(p, "BACKGROUND", false, false, -7)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(0.035, 0.04, 0.052, 0.97)
	p.bd = Ink:Round(p, "BORDER", false, true)
	p.bd:SetAllPoints()
	p.bd:SetVertexColor(1, 1, 1, 0.09)
	p.accent = p:CreateTexture(nil, "ARTWORK")
	p.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	p.accent:SetSize(22, 2)
	p.accent:SetPoint("TOPLEFT", 14, -1)
	-- 머리: 부위 · 지금 템 · 칸 순위
	p.slot = Ink:Text(p, F.bold, 16, C.text, "LEFT")
	p.slot:SetPoint("TOPLEFT", 16, -16)
	p.rankPill = Pill(p)
	p.rankPill:SetPoint("TOPRIGHT", -14, -14)
	p.cur = Ink:Text(p, F.sans, 11, C.muted, "LEFT")
	p.cur:SetPoint("TOPLEFT", p.slot, "BOTTOMLEFT", 0, -7)
	p.cur:SetPoint("RIGHT", -14, 0)
	p.line1 = p:CreateTexture(nil, "ARTWORK")
	p.line1:SetColorTexture(1, 1, 1, 0.06)
	p.line1:SetHeight(1)
	p.line1:SetPoint("TOPLEFT", 14, -62)
	p.line1:SetPoint("TOPRIGHT", -14, -62)
	p.h1 = Ink:Text(p, F.semi, 10, C.dim, "LEFT")
	p.h1:SetPoint("TOPLEFT", 16, -72)
	p.rows = {}
	for i = 1, ROWS do
		local r = NewRow(p, i)
		r:SetPoint("TOPLEFT", 10, -ROW_TOP - (i - 1) * ROW_H)
		p.rows[i] = r
	end
	p.none = Ink:Text(p, F.sans, 11, C.muted, "LEFT")
	p.none:SetPoint("TOPLEFT", 16, -ROW_TOP - 10)
	p.none:SetWidth(PW - 32)
	p.none:SetWordWrap(true)
	-- 추천 마법부여
	p.line2 = p:CreateTexture(nil, "ARTWORK")
	p.line2:SetColorTexture(1, 1, 1, 0.06)
	p.line2:SetHeight(1)
	p.h2 = Ink:Text(p, F.semi, 10, C.dim, "LEFT")
	p.h2:SetText("추천 마법부여")
	p.ench = Ink:Text(p, F.bold, 15, UP, "LEFT")
	p.ench:SetWidth(PW - 32)
	p.enchName = Ink:Text(p, F.latin, 10, C.dim, "LEFT")
	p.enchName:SetWidth(PW - 32)
	p.enchState = Pill(p)
	p.cheap = Ink:Text(p, F.sans, 11, C.muted, "LEFT")
	p.cheap:SetWidth(PW - 32)
	-- BIS 탭으로
	p.more = CreateFrame("Button", nil, p)
	p.more:SetSize(140, 20)
	-- 화살표는 글꼴 기호(›) 대신 FOA 아이콘 (한글 글꼴에 › 가 없어서 네모로 깨졌다)
	p.more.chev = p.more:CreateTexture(nil, "ARTWORK")
	p.more.chev:SetTexture(Ink.icon("Chevron"))
	p.more.chev:SetSize(10, 10)
	p.more.chev:SetPoint("RIGHT", 0, 0)
	p.more.chev:SetRotation(math.rad(90))
	p.more.chev:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	p.more.text = Ink:Text(p.more, F.semi, 10, C.accent, "RIGHT")
	p.more.text:SetPoint("RIGHT", p.more.chev, "LEFT", -3, 0)
	p.more.text:SetText("BIS 탭에서 자세히")
	p.more:SetScript("OnClick", function() M:OpenBis(p.inv) end)
	p.more:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1); self.chev:SetVertexColor(1, 1, 1) end)
	p.more:SetScript("OnLeave", function(self)
		self.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		self.chev:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	end)
	-- 열릴 때: 제자리에서 부드럽게 (투명 → 선명 + 아주 살짝 커지며 자리잡기)
	--  위치 이동 애니메이션은 끝나는 순간 원래 자리로 "툭" 돌아가서 튕기는 느낌이 났다 → 크기 · 투명도만
	local ag = p:CreateAnimationGroup()
	local fa = ag:CreateAnimation("Alpha"); fa:SetFromAlpha(0); fa:SetToAlpha(1); fa:SetDuration(0.18); fa:SetSmoothing("OUT")
	local fs = ag:CreateAnimation("Scale"); fs:SetScaleFrom(0.97, 0.97); fs:SetScaleTo(1, 1); fs:SetDuration(0.22); fs:SetSmoothing("OUT")
	p.ag, p.agS = ag, fs
	-- 다른 칸으로 바꿀 때: 창은 그 자리에 두고 내용만 살짝 밝아지며 바뀐다
	local sw = p:CreateAnimationGroup()
	local sa = sw:CreateAnimation("Alpha"); sa:SetFromAlpha(0.55); sa:SetToAlpha(1); sa:SetDuration(0.16); sa:SetSmoothing("OUT")
	p.swap = sw
	-- 밖을 누르면 닫힘 · ESC · 캐릭터 창이 닫히면 같이 (다른 장비 칸을 누르는 건 "칸 바꾸기"라서 닫지 않는다)
	tinsert(UISpecialFrames, "FOAGearPopup")
	p:SetScript("OnUpdate", function(self)
		-- 캐릭터 창을 닫거나 다른 탭(평판 · 화폐)으로 넘어가 장비 칸이 안 보이면 같이 닫힌다
		local cf = CharacterFrame
		if not (cf and cf:IsVisible()) or (self.owner and not self.owner:IsVisible()) then self:Hide() return end
		if not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) or self:IsMouseOver() then return end
		for b in pairs(M.slotButtons or {}) do if b:IsMouseOver() then return end end
		self:Hide()
	end)
	p:Hide()
	self.popup = p
	return p
end

-- 화면 기준 가로 위치 (틀마다 배율이 달라서 실제 화면 픽셀로 비교)
local function ScreenX(f, edge)
	local v = f and (edge == "L" and f:GetLeft() or f:GetRight())
	return v and v * f:GetEffectiveScale() or nil
end

function M:TogglePopup(btn)
	if Ink.db.gearPopup == false or not btn then return end
	local inv = btn:GetID()
	if not INV2EJ[inv] then return end
	local p = self:BuildPopup()
	if p:IsShown() and p.inv == inv then p:Hide() return end
	local switching = p:IsShown()
	p.inv, p.owner = inv, btn
	self:Paint()
	if switching then
		-- 이미 열려 있으면 자리는 그대로, 내용만 바꾼다
		p.swap:Stop(); p.swap:Play()
		return
	end
	p:ClearAllPoints()
	-- 캐릭터 창 바깥 한 곳에 고정 (오른쪽 우선, 자리가 없으면 왼쪽) · 위쪽은 캐릭터 창 위에 맞춘다
	--  칸마다 높이를 따라 내려가면 아래 칸에서 화면 밖으로 밀리고 어수선했다
	--  오른쪽 세로 탭 · BIS 판까지 피해서 놓는다
	local cf = CharacterFrame
	local ps = p:GetEffectiveScale()
	local sw = (UIParent:GetWidth() or 1920) * UIParent:GetEffectiveScale()
	local pw = PW * ps
	local cfR, cfL = ScreenX(cf, "R"), ScreenX(cf, "L")
	local outR, outL = cfR, cfL
	local d = D()
	for _, x in ipairs({ cf and cf.ModeTabs, _G.FOABisTab, d and d.bisPanel }) do
		if type(x) == "table" and x.IsShown and x:IsShown() then
			local r, l = ScreenX(x, "R"), ScreenX(x, "L")
			if r and outR and r > outR then outR = r end
			if l and outL and l < outL then outL = l end
		end
	end
	local gap = 10 * ps
	local side
	if cf and outR and outR + gap + pw <= sw then
		side = "R"
		p:SetPoint("TOPLEFT", cf, "TOPRIGHT", (outR - cfR + gap) / ps, 0)
	elseif cf and outL and outL - gap - pw >= 0 then
		side = "L"
		p:SetPoint("TOPRIGHT", cf, "TOPLEFT", -(cfL - outL + gap) / ps, 0)
	else
		-- 양쪽 다 자리가 없으면 칸 바로 옆
		local cx, mid = btn:GetCenter(), cf and cf:GetCenter()
		side = (cx and mid and cx > mid) and "L" or "R"
		if side == "R" then p:SetPoint("TOPLEFT", btn, "TOPRIGHT", 14, 6) else p:SetPoint("TOPRIGHT", btn, "TOPLEFT", -14, 6) end
	end
	p.agS:SetOrigin(side == "R" and "LEFT" or "RIGHT", 0, 0)
	p:Show()
	p.ag:Stop(); p.ag:Play()
end

local function RankCol(v)
	if v >= 95 then return GOLD end
	if v >= 80 then return UP end
	if v >= 60 then return { 0.86, 0.88, 0.9 } end
	return DOWN
end

function M:Paint()
	local p = self.popup
	local inv = p.inv
	local ej = INV2EJ[inv]
	p.slot:SetText(SLOT_KO[inv] or "")
	local curLink = GetInventoryItemLink("player", inv)
	local curID = GetInventoryItemID("player", inv)
	local curScore = curLink and ScoreOf(curLink, inv == 17)
	if curLink then
		local q = GetInventoryItemQuality("player", inv) or 1
		local qc = QCOL[q] or QCOL[1]
		local name = C_Item.GetItemInfo(curLink) or curLink:match("%[(.-)%]") or ""
		p.cur:SetText(string.format("지금  |cff%02x%02x%02x%s|r", math.floor(qc[1] * 255), math.floor(qc[2] * 255), math.floor(qc[3] * 255), name))
	else
		p.cur:SetText("지금  비어 있음")
	end
	local best = self:BestScore(ej)
	if curScore and best and best > 0 then
		local v = math.max(0, math.min(100, math.floor(curScore / best * 100 + 0.5)))
		p.rankPill:Set("칸 " .. v, RankCol(v), 0.16)
		p.rankPill:Show()
	else
		p.rankPill:Hide()
	end
	local lvl = UnitLevel("player") or 1
	local d = D()
	p.h1:SetText((d and d.levelMode) and string.format("%d레벨 · 이 칸 최고템 순위", lvl) or "이 칸 BIS · 대체템")
	local list = self:SlotList(ej)
	local y = -ROW_TOP
	local n = 0
	for i, r in ipairs(p.rows) do
		local e = list[i]
		if e then
			n = i
			local it = e.it
			local link = ItemLink(it)
			r.link = link
			r.icon:SetTexture(it.icon or C_Item.GetItemIconByID(it.id) or 134400)
			local qc = QCOL[it.quality or 1] or QCOL[1]
			r.iconBd:SetVertexColor(qc[1], qc[2], qc[3], 0.9)
			r.name:SetText(it.name or C_Item.GetItemInfo(it.id) or "불러오는 중…")
			r.name:SetTextColor(qc[1], qc[2], qc[3])
			local src = ""
			if d and d.SourceText then
				local okS, v = pcall(d.SourceText, d, it)
				if okS and type(v) == "string" then src = v end
			end
			r.src:SetText(src)
			local top = (e.rank or (i - 1)) == 0
			local worn = curID == it.id
			r.rank:SetText(top and "" or tostring(i))
			r.gold:SetShown(top)
			r.base = top and 0.05 or 0.025
			r.bg:SetVertexColor(1, 1, 1, r.base)
			if worn then
				r.bd:SetVertexColor(UP[1], UP[2], UP[3], 0.5)
				r.pill:Set("착용 중", UP)
			else
				r.bd:SetVertexColor(top and GOLD[1] or 1, top and GOLD[2] or 1, top and GOLD[3] or 1, top and 0.42 or 0.06)
				local sc = e.score or ScoreOf(link, inv == 17)
				if top and (not curScore or not sc or sc > curScore) then
					r.pill:Set("최고", GOLD, 0.2)
				elseif sc and curScore and curScore > 0 then
					local pct = UpPct(sc, curScore) or 0
					if pct > 0 then r.pill:Set("+" .. pct .. "%", UP)
					elseif pct < 0 then r.pill:Set(pct .. "%", DOWN)
					else r.pill:Set("비슷", { 0.7, 0.72, 0.75 }) end
				elseif sc and not curLink then
					r.pill:Set("빈 칸", UP)
				else
					r.pill:Set("—", { 0.6, 0.62, 0.66 })
				end
			end
			r:Show()
			if top and not worn then
				r.sg:Stop()
				C_Timer.After(0.12, function() if r:IsShown() then r.sg:Play() end end)
			end
		else
			r:Hide()
		end
	end
	p.none:SetShown(n == 0)
	if n == 0 then
		p.none:SetText((d and d.levelPending) and "아이템 정보를 받아 오는 중이에요…" or "지금 레벨에 갈 수 있는 곳에서 이 칸 템을 못 찾았어요")
		n = 1
	end
	y = -ROW_TOP - n * ROW_H - 8
	-- 추천 마법부여
	local best1, cheap = self:Recommend(inv)
	local function place(r, x, yy) r:ClearAllPoints(); r:SetPoint("TOPLEFT", x, yy) end
	p.line2:ClearAllPoints()
	p.line2:SetPoint("TOPLEFT", 12, y)
	p.line2:SetPoint("TOPRIGHT", -12, y)
	place(p.h2, 16, y - 12)
	-- 상태 알약은 "추천 마법부여" 제목 줄 오른쪽 · 효과 · 영문 이름 · 가성비는 각자 한 줄 (겹치지 않게)
	p.enchState:ClearAllPoints()
	p.enchState:SetPoint("TOPRIGHT", -14, y - 9)
	if best1 then
		local label = FxLabel(best1[3])
		p.ench:SetText(label)
		place(p.ench, 16, y - 32)
		p.enchName:SetText("Enchant · " .. best1[1])
		place(p.enchName, 16, y - 52)
		-- 지금 발린 마법부여와 비교
		local Ch = Ink.modules.Character
		local curE
		if Ch and Ch.ScanSlot then
			local okE, e1 = pcall(Ch.ScanSlot, inv)
			curE = okE and e1 or nil
		end
		local curShort = curE and Ch.ShortStats and Ch.ShortStats(curE) or nil
		if not curLink then
			p.enchState:Hide()
		elseif Applied(curShort, best1[3]) then
			p.enchState:Set("적용됨", UP); p.enchState:Show()
		elseif cheap and Applied(curShort, cheap[3]) then
			p.enchState:Set("가성비 적용됨", { 0.86, 0.88, 0.9 }); p.enchState:Show()
		elseif curShort and curShort ~= "" then
			p.enchState:Set("지금 " .. curShort, { 1, 0.65, 0.3 }); p.enchState:Show()
		else
			p.enchState:Set("없음", DOWN); p.enchState:Show()
		end
		p.ench:Show(); p.enchName:Show()
		if cheap then
			local cl = FxLabel(cheap[3])
			p.cheap:SetText("가성비  " .. cl .. "  |cff5E636B(제조법 숙련 " .. cheap[2] .. ")|r")
			place(p.cheap, 16, y - 72)
			p.cheap:Show()
			y = y - 94
		else
			p.cheap:Hide()
			y = y - 72
		end
	else
		p.ench:SetText(((inv == 16 or inv == 17) and not curLink) and "무기를 들면 골라 드려요" or "마법부여가 없는 칸이에요")
		p.ench:SetTextColor(0.6, 0.62, 0.66)
		place(p.ench, 16, y - 32)
		p.enchName:Hide(); p.enchState:Hide(); p.cheap:Hide()
		y = y - 56
	end
	if best1 then p.ench:SetTextColor(UP[1], UP[2], UP[3]) end
	p.more:ClearAllPoints()
	p.more:SetPoint("TOPRIGHT", -16, y - 4)
	p:SetHeight(-y + 38)
end

function M:OpenBis(inv)
	local d = D()
	if not d then return end
	if not d.bisTab and d.AttachBisTab then pcall(d.AttachBisTab, d) end
	for i, v in ipairs(INV_ORDER) do if v == inv then d.bisSel = i end end
	if not (d.bisPanel and d.bisPanel:IsShown()) and d.bisTab then d.bisTab:Click() end
	pcall(d.PaintBis, d)
	if self.popup then self.popup:Hide() end
end

local SLOT_FRAME = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist", [10] = "Hands",
	[6] = "Waist", [7] = "Legs", [8] = "Feet", [11] = "Finger0", [12] = "Finger1", [13] = "Trinket0", [14] = "Trinket1",
	[16] = "MainHand", [17] = "SecondaryHand" }

function M:HookSlots()
	if self.slotsHooked then return end
	local any
	for inv in pairs(INV2EJ) do
		local b = _G["Character" .. SLOT_FRAME[inv] .. "Slot"]
		if b and b.HookScript then
			any = true
			M.slotButtons = M.slotButtons or {}
			M.slotButtons[b] = true
			b:HookScript("OnClick", function(self, button)
				if button == "RightButton" and not (CursorHasItem and CursorHasItem()) then M:TogglePopup(self) end
			end)
			b:HookScript("OnEnter", function()
				if Ink.db.gearPopup ~= false and GameTooltip:IsOwned(b) then
					GameTooltip:AddLine("|cff8E939B오른쪽 클릭: 이 칸 업그레이드 · 추천 마법부여|r")
					GameTooltip:Show()
				end
			end)
		end
	end
	self.slotsHooked = any
end

-------------------------------------------------------------------------------
-- 최고 장비 획득 알림 (화면 위 가운데)
-------------------------------------------------------------------------------
local SPARK = "Interface\\AddOns\\FOA_UI\\Media\\Textures\\Sparkle"

function M:BuildToast()
	if self.toast then return self.toast end
	local t = CreateFrame("Button", "FOAGearToast", Ink.root)
	t:SetSize(420, 86)
	t:SetFrameStrata("HIGH")
	t:RegisterForClicks("AnyUp")
	Ink:Movable("gearToast", "장비 획득 알림", t, "center", 750, 150)
	t.glow = t:CreateTexture(nil, "BACKGROUND", nil, -8)
	t.glow:SetTexture(Ink.tex.glow)
	t.glow:SetPoint("TOPLEFT", -60, 40)
	t.glow:SetPoint("BOTTOMRIGHT", 60, -40)
	t.glow:SetBlendMode("ADD")
	t.bg = Ink:Round(t, "BACKGROUND", false, false, -7)
	t.bg:SetAllPoints()
	t.bg:SetVertexColor(0.035, 0.04, 0.052, 0.94)
	t.bd = Ink:Round(t, "BORDER", false, true)
	t.bd:SetAllPoints()
	-- 지나가는 반짝임
	t.clip = CreateFrame("Frame", nil, t)
	t.clip:SetAllPoints()
	if t.clip.SetClipsChildren then t.clip:SetClipsChildren(true) end
	t.sheen = t.clip:CreateTexture(nil, "OVERLAY")
	t.sheen:SetTexture(Ink.tex.white)
	t.sheen:SetSize(70, 130)
	t.sheen:SetPoint("LEFT", t.clip, "LEFT", -80, 0)
	t.sheen:SetBlendMode("ADD")
	if t.sheen.SetRotation then t.sheen:SetRotation(math.rad(-18)) end
	if t.sheen.SetGradient and CreateColor then
		t.sheen:SetGradient("HORIZONTAL", CreateColor(1, 0.95, 0.75, 0), CreateColor(1, 0.95, 0.75, 0.3))
	end
	t.sheen:SetAlpha(0)
	-- 아이콘 + 금빛 고리 + 퍼지는 고리 + 별
	t.ic = CreateFrame("Frame", nil, t)
	t.ic:SetSize(54, 54)
	t.ic:SetPoint("LEFT", 16, 0)
	t.icon = t.ic:CreateTexture(nil, "ARTWORK")
	t.icon:SetPoint("TOPLEFT", 3, -3)
	t.icon:SetPoint("BOTTOMRIGHT", -3, 3)
	t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if t.ic.CreateMaskTexture then
		local m = t.ic:CreateMaskTexture()
		m:SetTexture(Ink.tex.round4, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		m:SetAllPoints(t.icon)
		t.icon:AddMaskTexture(m)
	end
	t.iconBd = Ink:Round(t.ic, "OVERLAY", false, true)
	t.iconBd:SetAllPoints()
	t.burst = t.ic:CreateTexture(nil, "BACKGROUND")
	t.burst:SetTexture(Ink.tex.ring)
	t.burst:SetPoint("CENTER")
	t.burst:SetSize(54, 54)
	t.burst:SetBlendMode("ADD")
	t.burst:SetAlpha(0)
	t.stars = {}
	for i, pos in ipairs({ { -30, 22, 16 }, { 28, 26, 12 }, { 32, -20, 14 }, { -26, -24, 10 } }) do
		local s = t.ic:CreateTexture(nil, "OVERLAY")
		s:SetTexture(SPARK)
		s:SetSize(pos[3], pos[3])
		s:SetPoint("CENTER", pos[1], pos[2])
		s:SetBlendMode("ADD")
		s:SetAlpha(0)
		local ag = s:CreateAnimationGroup()
		ag:SetLooping("REPEAT")
		local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.25); a1:SetOrder(1); a1:SetStartDelay(0.15 * i)
		local s1 = ag:CreateAnimation("Scale"); s1:SetScaleFrom(0.3, 0.3); s1:SetScaleTo(1, 1); s1:SetDuration(0.25); s1:SetOrder(1); s1:SetStartDelay(0.15 * i)
		local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.45); a2:SetOrder(2)
		local r2 = ag:CreateAnimation("Rotation"); r2:SetDegrees(-60); r2:SetDuration(0.45); r2:SetOrder(2)
		s.ag = ag
		t.stars[i] = s
	end
	t.kicker = Ink:Text(t, F.semi, 11, GOLD, "LEFT")
	t.kicker:SetPoint("TOPLEFT", t.ic, "TOPRIGHT", 14, -4)
	t.name = Ink:Text(t, F.bold, 16, C.text, "LEFT")
	t.name:SetPoint("TOPLEFT", t.kicker, "BOTTOMLEFT", 0, -4)
	t.name:SetPoint("RIGHT", -16, 0)
	t.detail = Ink:Text(t, F.sans, 11, C.soft, "LEFT")
	t.detail:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -4)
	t.detail:SetPoint("RIGHT", -16, 0)
	t.line = t:CreateTexture(nil, "ARTWORK")
	t.line:SetSize(26, 2)
	t.line:SetPoint("TOPLEFT", 16, -1)
	-- 등장 · 퇴장
	local ag = t:CreateAnimationGroup()
	local a0 = ag:CreateAnimation("Alpha"); a0:SetFromAlpha(0); a0:SetToAlpha(1); a0:SetDuration(0.22); a0:SetOrder(1)
	local s0 = ag:CreateAnimation("Scale"); s0:SetScaleFrom(1.12, 1.12); s0:SetScaleTo(1, 1); s0:SetDuration(0.3); s0:SetOrder(1); s0:SetSmoothing("OUT")
	local a9 = ag:CreateAnimation("Alpha"); a9:SetFromAlpha(1); a9:SetToAlpha(0); a9:SetDuration(0.6); a9:SetOrder(2); a9:SetStartDelay(5.5)
	ag:SetScript("OnFinished", function() t:Hide() end)
	t.ag = ag
	local sg = t.sheen:CreateAnimationGroup()
	local b0 = sg:CreateAnimation("Alpha"); b0:SetFromAlpha(0); b0:SetToAlpha(1); b0:SetDuration(0.1); b0:SetOrder(1); b0:SetStartDelay(0.25)
	local b1 = sg:CreateAnimation("Translation"); b1:SetOffset(560, 0); b1:SetDuration(1.1); b1:SetOrder(2); b1:SetSmoothing("IN_OUT")
	local b2 = sg:CreateAnimation("Alpha"); b2:SetFromAlpha(1); b2:SetToAlpha(0); b2:SetDuration(1.1); b2:SetOrder(2); b2:SetSmoothing("IN")
	t.sg = sg
	local bg2 = t.burst:CreateAnimationGroup()
	local c1 = bg2:CreateAnimation("Scale"); c1:SetScaleFrom(1, 1); c1:SetScaleTo(2.6, 2.6); c1:SetDuration(0.8); c1:SetSmoothing("OUT")
	local c2 = bg2:CreateAnimation("Alpha"); c2:SetFromAlpha(0.9); c2:SetToAlpha(0); c2:SetDuration(0.8); c2:SetSmoothing("OUT")
	t.bg2 = bg2
	t:SetScript("OnClick", function(self)
		self.ag:Stop(); self:Hide()
		if not InCombatLockdown() and ToggleCharacter and not (CharacterFrame and CharacterFrame:IsShown()) then pcall(ToggleCharacter, "PaperDollFrame") end
	end)
	t:Hide()
	self.toast = t
	return t
end

function M:ShowToast(link, kind, detail)
	local t = self:BuildToast()
	local col = kind == "best" and GOLD or UP
	t.glow:SetVertexColor(col[1], col[2], col[3], 0.35)
	t.bd:SetVertexColor(col[1], col[2], col[3], 0.55)
	t.line:SetColorTexture(col[1], col[2], col[3], 0.95)
	t.burst:SetVertexColor(col[1], col[2], col[3], 1)
	t.kicker:SetText(kind == "best" and "최고 장비 획득" or "업그레이드 획득")
	t.kicker:SetTextColor(col[1], col[2], col[3])
	local name, _, q, _, _, _, _, _, _, icon = C_Item.GetItemInfo(link)
	local qc = QCOL[q or 1] or QCOL[1]
	t.icon:SetTexture(icon or C_Item.GetItemIconByID(link) or 134400)
	t.iconBd:SetVertexColor(qc[1], qc[2], qc[3], 1)
	t.name:SetText(name or link)
	t.name:SetTextColor(qc[1], qc[2], qc[3])
	t.detail:SetText(detail or "")
	t:SetAlpha(1)
	t:Show()
	t.ag:Stop(); t.ag:Play()
	t.sg:Stop(); t.sg:Play()
	t.bg2:Stop(); t.bg2:Play()
	for _, s in ipairs(t.stars) do s.ag:Stop(); s.ag:Play() end
	local sound = kind == "best" and ((SOUNDKIT and SOUNDKIT.UI_LEGENDARY_LOOT_TOAST) or 63971) or ((SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST) or 31578)
	pcall(PlaySound, sound, "Master")
end

-- 새로 들어온 장비가 그 칸 1순위(또는 크게 좋은 것)인지
function M:CheckNew(link, tries)
	local id, _, _, loc = C_Item.GetItemInfoInstant(link)
	local ej, inv = loc and LOC2EJ[loc], loc and LOC2INV[loc]
	if not (id and ej) then return end
	local new = ScoreOf(link, ej == 11)
	if new == nil and (tries or 0) < 2 then
		-- 아이템 정보가 아직 안 왔으면 잠깐 뒤 다시
		C_Timer.After(1, function() pcall(M.CheckNew, M, link, (tries or 0) + 1) end)
		return
	end
	if not new or new <= 0 then return end
	local sc = ns.Score
	if sc and sc.Usable then
		local okU, usable = pcall(sc.Usable, sc, link)
		if okU and usable == false then return end
	end
	local minLv = select(5, C_Item.GetItemInfo(link))
	if minLv and minLv > (UnitLevel("player") or 1) then return end
	-- 착용 대비: 아이템 툴팁과 똑같은 비교 (Score:Compare)
	--  반지 · 장신구는 약한 쪽, 양손 무기는 주장비 + 보조장비 합, 쌍수는 약한 손과 비교
	local pct, better
	local okC, r = false, nil
	if sc and sc.Compare then okC, r = pcall(sc.Compare, sc, link) end
	if okC and r and not r.trinket and type(r.pct) == "number" then
		if r.empty then
			better = true
		else
			pct = math.floor(r.pct + (r.pct >= 0 and 0.5 or -0.5))
			better = pct > 0
		end
	else
		-- 비교 기능을 끈 경우: 같은 칸(반지 · 장신구는 약한 쪽)과 점수로
		local curScore
		local pair = (inv == 11 and { 11, 12 }) or (inv == 13 and { 13, 14 }) or { inv }
		for _, s in ipairs(pair) do
			local l = GetInventoryItemLink("player", s)
			local v = l and ScoreOf(l, s == 17) or 0
			if not curScore or v < curScore then curScore = v end
		end
		curScore = curScore or 0
		better = new > curScore
		pct = curScore > 0 and UpPct(new, curScore) or nil
	end
	if not better then return end
	local list = self:SlotList(ej)
	local top = list[1]
	local where = SLOT_KO[inv] or ""
	if top and top.it and top.it.id == id then
		self:ShowToast(link, "best", where .. "  ·  지금 레벨 1순위" .. (pct and ("  ·  착용 대비 +" .. pct .. "%") or ""))
	elseif pct and pct >= (Ink.db.gearToastPct or 15) then
		self:ShowToast(link, "up", where .. "  ·  착용 대비 +" .. pct .. "%")
	end
end

local function BagLinks()
	local t = {}
	if not (C_Container and C_Container.GetContainerNumSlots) then return t end
	for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and info.hyperlink then t[info.itemID] = info.hyperlink end
		end
	end
	return t
end

-- 이번 접속에서 이미 본 장비 (벗었다 다시 넣은 것 · 은행에서 꺼낸 것은 "새로 얻은 것"이 아니다)
M.known = {}
local function RememberEquipped()
	for s = 1, 19 do
		local id = GetInventoryItemID("player", s)
		if id then M.known[id] = true end
	end
end

function M:ScanBags()
	local skip = Ink.db.gearToast == false or (BankFrame and BankFrame:IsShown())
		or (GuildBankFrame and GuildBankFrame:IsShown())
	for id, link in pairs(BagLinks()) do
		if not self.known[id] then
			self.known[id] = true
			if not skip then pcall(M.CheckNew, M, link) end
		end
	end
end

-------------------------------------------------------------------------------
function M:Init()
	if not FOREVER then return end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "ADDON_LOADED", "PLAYER_LEVEL_UP",
		"PLAYER_EQUIPMENT_CHANGED" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local pending
	e:SetScript("OnEvent", function(_, ev)
		if ev == "PLAYER_ENTERING_WORLD" or ev == "ADDON_LOADED" then pcall(M.HookSlots, M) end
		if ev == "PLAYER_ENTERING_WORLD" then
			-- 접속 직후 가방 · 착용 장비는 "원래 있던 것"으로 (알림 없이)
			if not M.ready then
				C_Timer.After(3, function()
					RememberEquipped()
					for id in pairs(BagLinks()) do M.known[id] = true end
					M.ready = true
				end)
			end
		elseif ev == "PLAYER_EQUIPMENT_CHANGED" then
			RememberEquipped()
		elseif ev == "BAG_UPDATE_DELAYED" then
			if not M.ready or pending then return end
			pending = true
			C_Timer.After(0.6, function() pending = nil; pcall(M.ScanBags, M) end)
		end
		if M.popup and M.popup:IsShown() then pcall(M.Paint, M) end
	end)
	pcall(self.HookSlots, self)
end
