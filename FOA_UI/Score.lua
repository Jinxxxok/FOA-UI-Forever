-- FOA UI · 아이템 점수 · 착용 비교
--  아이템 점수 = Σ(능력치 × 가중치). 가중치는 직업 · 특성마다 PvE / PvP 따로 (아래 W 표, 모든 직업에 같은 규칙).
--  가방 · 상인 · 퀘스트 보상 · 전리품 툴팁에 "착용 대비 +n%" 를 붙이고, 가방 칸에는 더 좋은 장비에 화살표.
--  포에버(클래식 능력치)는 직업 · 특성 가중치 점수, 본섭은 주 능력치 + 2차 능력치(전문화 BIS 비중) 점수.
--  본섭 장신구는 사용 · 발동 효과가 핵심이라 점수 대신 BIS 여부와 아이템 레벨만 알려 준다.
--  못 쓰는 장비(빨간 줄: 직업 · 방어구 · 무기 숙련)는 비교하지 않고, 레벨만 모자라면 "n레벨부터" 로 알려 준다.

local ADDON, ns = ...
local Ink = ns.Ink
local C, F = Ink.c, Ink.font
local M = Ink:Module("Score")
ns.Score = M

local build = select(4, GetBuildInfo()) or 0
local FOREVER = build >= 16001 and build < 20000
M.forever = FOREVER
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local plain = Ink.plain or function(v) return v end

-------------------------------------------------------------------------------
-- 가중치 (1 = 공격력 1 또는 주문력 1 정도의 값어치)
--  적중 / 치명타는 1% 당. 무기 초당 공격력(dps)은 무기 칸에만.
--  포에버는 클래식 능력치 체계라 클래식 EP(Equivalence Point) 관례를 따르고,
--  공략에 능력치 우선순위가 나오면 여기 숫자만 고치면 된다.
-------------------------------------------------------------------------------
local K = {
	str = "ITEM_MOD_STRENGTH_SHORT", agi = "ITEM_MOD_AGILITY_SHORT", sta = "ITEM_MOD_STAMINA_SHORT",
	int = "ITEM_MOD_INTELLECT_SHORT", spi = "ITEM_MOD_SPIRIT_SHORT",
	ap = "ITEM_MOD_ATTACK_POWER_SHORT", rap = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", fap = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
	sp = "ITEM_MOD_SPELL_POWER_SHORT", heal = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", sdmg = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
	mp5 = "ITEM_MOD_MANA_REGENERATION_SHORT", hp5 = "ITEM_MOD_HEALTH_REGENERATION_SHORT",
	hit = "ITEM_MOD_HIT_RATING_SHORT", crit = "ITEM_MOD_CRIT_RATING_SHORT",
	shit = "ITEM_MOD_HIT_SPELL_RATING_SHORT", scrit = "ITEM_MOD_CRIT_SPELL_RATING_SHORT",
	def = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", dodge = "ITEM_MOD_DODGE_RATING_SHORT", parry = "ITEM_MOD_PARRY_RATING_SHORT",
	block = "ITEM_MOD_BLOCK_RATING_SHORT", bv = "ITEM_MOD_BLOCK_VALUE_SHORT",
	armor = "RESISTANCE0_NAME", dps = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
	-- 포에버에 새로 생긴 능력치 (Method 공략 우선순위에 나옴)
	exp = "ITEM_MOD_EXPERTISE_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT", spen = "ITEM_MOD_SPELL_PENETRATION_SHORT",
}

local MELEE = { str = 2.0, agi = 1.2, ap = 1, crit = 20, hit = 18, exp = 4, haste = 12, sta = 0.3, armor = 0.01, dps = 14 }
local W = {
	["WARRIOR:arms"] = MELEE,
	["WARRIOR:fury"] = MELEE,
	["WARRIOR:prot"] = { sta = 1.5, def = 1.5, armor = 0.1, dodge = 12, parry = 12, block = 6, bv = 0.5, str = 1, agi = 1, ap = 0.4, hit = 8, dps = 6, exp = 3 },
	["ROGUE:assassination"] = { agi = 2.0, str = 1, ap = 1, crit = 20, hit = 22, sta = 0.3, armor = 0.01, dps = 14, exp = 4, haste = 12 },
	["ROGUE:combat"] = { agi = 2.0, str = 1, ap = 1, crit = 20, hit = 22, sta = 0.3, armor = 0.01, dps = 14, exp = 4, haste = 12 },
	["ROGUE:subtlety"] = { agi = 2.0, str = 1, ap = 1, crit = 22, hit = 20, sta = 0.3, armor = 0.01, dps = 14, exp = 4, haste = 12 },
	["HUNTER:bm"] = { agi = 2.2, rap = 1, ap = 0.3, int = 0.4, crit = 20, hit = 20, sta = 0.3, armor = 0.01, rdps = 12, dps = 1, haste = 10 },
	["HUNTER:mm"] = { agi = 2.2, rap = 1, ap = 0.3, int = 0.4, crit = 22, hit = 20, sta = 0.3, armor = 0.01, rdps = 14, dps = 1, haste = 10 },
	["HUNTER:sv"] = { agi = 2.4, rap = 1, ap = 0.5, int = 0.4, crit = 20, hit = 20, sta = 0.3, armor = 0.01, rdps = 12, dps = 3, haste = 10 },
	["MAGE:arcane"] = { sp = 1, sdmg = 1, int = 0.6, spi = 0.3, scrit = 10, shit = 12, mp5 = 1.2, sta = 0.4, haste = 10, spen = 0.6 },
	["MAGE:fire"] = { sp = 1, sdmg = 1, int = 0.5, spi = 0.2, scrit = 14, shit = 14, mp5 = 1, sta = 0.4, haste = 10, spen = 0.6 },
	["MAGE:frost"] = { sp = 1, sdmg = 1, int = 0.5, spi = 0.25, scrit = 10, shit = 14, mp5 = 1, sta = 0.4, haste = 10, spen = 0.6 },
	["WARLOCK:aff"] = { sp = 1, sdmg = 1, int = 0.4, spi = 0.3, scrit = 6, shit = 14, mp5 = 0.8, sta = 0.6, haste = 10, spen = 0.8 },
	["WARLOCK:demo"] = { sp = 1, sdmg = 1, int = 0.4, spi = 0.25, scrit = 8, shit = 14, mp5 = 0.8, sta = 0.6, haste = 10, spen = 0.8 },
	["WARLOCK:destro"] = { sp = 1, sdmg = 1, int = 0.4, spi = 0.2, scrit = 12, shit = 14, mp5 = 0.8, sta = 0.5, haste = 10, spen = 0.8 },
	["PRIEST:disc"] = { heal = 1, sp = 1, int = 0.7, spi = 0.6, mp5 = 2, scrit = 8, sta = 0.3, haste = 6 },
	["PRIEST:holy"] = { heal = 1, sp = 1, int = 0.6, spi = 0.8, mp5 = 2, scrit = 8, sta = 0.2, haste = 6 },
	["PRIEST:shadow"] = { sp = 1, sdmg = 1, int = 0.4, spi = 0.5, shit = 12, scrit = 4, mp5 = 0.8, sta = 0.4, haste = 10, spen = 0.6 },
	["DRUID:balance"] = { sp = 1, sdmg = 1, int = 0.6, spi = 0.3, scrit = 10, shit = 12, mp5 = 1.2, sta = 0.3, haste = 10, spen = 0.6 },
	["DRUID:feral"] = { agi = 2.0, str = 2.0, ap = 1, fap = 1, crit = 20, hit = 18, sta = 0.4, armor = 0.02, exp = 4, haste = 12 },
	["DRUID:guardian"] = { sta = 1.5, armor = 0.15, agi = 1.2, def = 1, dodge = 12, str = 1, ap = 0.4, fap = 0.4, hit = 6, exp = 3 },
	["DRUID:resto"] = { heal = 1, sp = 1, int = 0.6, spi = 0.7, mp5 = 1.8, scrit = 6, sta = 0.2, haste = 6 },
	["PALADIN:holy"] = { heal = 1, sp = 1, int = 0.8, mp5 = 1.5, scrit = 10, spi = 0.2, sta = 0.2, haste = 6 },
	["PALADIN:prot"] = { sta = 1.5, def = 1.5, armor = 0.1, bv = 0.6, block = 6, sp = 0.5, int = 0.3, str = 0.6, dps = 4, exp = 3 },
	["PALADIN:ret"] = { str = 2.0, agi = 1.0, ap = 1, crit = 20, hit = 18, int = 0.3, sp = 0.3, sta = 0.3, armor = 0.01, dps = 14, exp = 4, haste = 12 },
	["SHAMAN:ele"] = { sp = 1, sdmg = 1, int = 0.6, mp5 = 1.2, scrit = 12, shit = 12, spi = 0.1, sta = 0.3, haste = 10, spen = 0.6 },
	["SHAMAN:enh"] = { str = 2.0, agi = 1.2, ap = 1, crit = 20, hit = 18, int = 0.3, sta = 0.3, armor = 0.01, dps = 14, exp = 4, haste = 12 },
	["SHAMAN:resto"] = { heal = 1, sp = 1, int = 0.7, mp5 = 1.8, spi = 0.3, scrit = 6, sta = 0.2, haste = 6 },
}
M.W = W
M.K = K

-- PvP: 체력을 크게, 적중 · 정신력 · 마나 회복은 덜 (탄력도가 없는 클래식 PvP 관례)
local function PvP(w)
	local p = {}
	for k, v in pairs(w) do p[k] = v end
	p.sta = math.max(1.0, (w.sta or 0) * 3)
	if p.hit then p.hit = p.hit * 0.5 end
	if p.shit then p.shit = p.shit * 0.6 end
	if p.spi then p.spi = p.spi * 0.4 end
	if p.mp5 then p.mp5 = p.mp5 * 0.6 end
	if p.crit then p.crit = p.crit * 1.1 end
	if p.armor then p.armor = math.max(p.armor, 0.03) end
	return p
end

-- 특성 탭 순서 (클래식 특성 트리 순서) · 본섭 특성 번호
local TABS = {
	WARRIOR = { "arms", "fury", "prot" }, ROGUE = { "assassination", "combat", "subtlety" },
	HUNTER = { "bm", "mm", "sv" }, MAGE = { "arcane", "fire", "frost" },
	WARLOCK = { "aff", "demo", "destro" }, PRIEST = { "disc", "holy", "shadow" },
	DRUID = { "balance", "feral", "resto" }, PALADIN = { "holy", "prot", "ret" },
	SHAMAN = { "ele", "enh", "resto" },
}
local SPEC_ID = {
	[71] = "arms", [72] = "fury", [73] = "prot", [259] = "assassination", [260] = "combat", [261] = "subtlety",
	[253] = "bm", [254] = "mm", [255] = "sv", [62] = "arcane", [63] = "fire", [64] = "frost",
	[265] = "aff", [266] = "demo", [267] = "destro", [256] = "disc", [257] = "holy", [258] = "shadow",
	[102] = "balance", [103] = "feral", [104] = "guardian", [105] = "resto", [65] = "holy", [66] = "prot", [70] = "ret",
	[262] = "ele", [263] = "enh", [264] = "resto",
}
-- 특성이 아직 없을 때 (레벨 10 전) 기본
M.TABS = TABS
local DEFAULT = { WARRIOR = "arms", ROGUE = "combat", HUNTER = "bm", MAGE = "frost", WARLOCK = "aff", PRIEST = "shadow", DRUID = "feral", PALADIN = "ret", SHAMAN = "enh" }
local SPEC_NAME = {
	arms = "무기", fury = "분노", prot = "방어", assassination = "암살", combat = "전투", subtlety = "잠행",
	bm = "야수", mm = "사격", sv = "생존", arcane = "비전", fire = "화염", frost = "냉기",
	aff = "고통", demo = "악마", destro = "파괴", disc = "수양", holy = "신성", shadow = "암흑",
	balance = "조화", feral = "야성", guardian = "수호", resto = "회복", ret = "징벌", ele = "정기", enh = "고양",
}

M.SPEC_NAME = SPEC_NAME

function M:Spec()
	local _, class = UnitClass("player")
	local key = Ink.cdb and Ink.cdb.scoreSpec
	if key and W[class .. ":" .. key] then return class, key end
	if GetSpecialization and GetSpecializationInfo then
		local i = GetSpecialization()
		local id = i and GetSpecializationInfo(i)
		if id and SPEC_ID[id] then return class, SPEC_ID[id] end
	end
	if GetTalentTabInfo and TABS[class] then
		local best, bestN = nil, 0
		for t = 1, 3 do
			local a, b, c, d, e = GetTalentTabInfo(t)
			-- 클라이언트마다 반환 순서가 달라서, 숫자 중 포인트로 보이는 값을 쓴다
			local n = (type(c) == "number" and c) or (type(e) == "number" and e) or 0
			if n > bestN then best, bestN = TABS[class][t], n end
		end
		if best then return class, best end
	end
	return class, DEFAULT[class]
end

function M:Mode()
	return (Ink.cdb and Ink.cdb.scoreMode) or "pve"
end

function M:Weights()
	local class, spec = self:Spec()
	local w = W[(class or "") .. ":" .. (spec or "")]
	if not w then return end
	if self:Mode() == "pvp" then
		self.pvpCache = self.pvpCache or {}
		self.pvpCache[w] = self.pvpCache[w] or PvP(w)
		return self.pvpCache[w], class, spec
	end
	return w, class, spec
end

function M:ProfileName()
	local _, class, spec = self:Weights()
	return (SPEC_NAME[spec or ""] or "") .. " " .. (UnitClass("player") or "") .. " · " .. (self:Mode() == "pvp" and "PvP" or "PvE")
end

-------------------------------------------------------------------------------
-- 툴팁 읽기: 못 쓰는 장비 / 요구 레벨 / 장착 효과(적중 · 치명 · 공격력 · 주문력 …)
-------------------------------------------------------------------------------
local LEVEL_PAT
local function LevelPattern()
	if LEVEL_PAT == nil then
		LEVEL_PAT = ITEM_MIN_LEVEL and ("^" .. ITEM_MIN_LEVEL:gsub("%%d", "(%%d+)") .. "$") or false
	end
	return LEVEL_PAT
end

local function IsRed(c)
	return c and c.r and c.r > 0.95 and c.g < 0.2 and c.b < 0.2
end

-- 장착 효과 문장에서 숫자 뽑기 (한글 / 영어)
local EFFECTS = {
	{ "주문.-적중", "spell.-hit", "shit", true },
	{ "주문.-치명", "spell.-critical", "scrit", true },
	{ "적중", "chance to hit", "hit", true },
	{ "치명타", "critical strike", "crit", true },
	{ "원거리 전투력", "ranged attack power", "rap" },
	{ "공격 전투력", "attack power", "ap" },
	{ "피해와 치유", "damage and healing", "sp" },
	{ "치유량", "healing done", "heal" },
	{ "5초마다.-마나", "mana per 5", "mp5" },
	{ "방어 숙련", "defense", "def" },
	{ "회피", "dodge", "dodge", true },
	{ "무기 막기", "parry", "parry", true },
}
local function ParseEffect(text, out)
	local low = text:lower()
	for _, e in ipairs(EFFECTS) do
		if text:find(e[1]) or low:find(e[2]) then
			local n = tonumber(text:match("(%d+)%%")) or tonumber(text:match("(%d+)"))
			if n and (not e[4] or text:find("%%")) then
				out[e[3]] = (out[e[3]] or 0) + n
				return
			end
		end
	end
end

-- 툴팁 줄: 못 쓰면 "no", 레벨이 모자라면 요구 레벨, 장착 효과 능력치
local tipCache = {}
local function ReadTooltip(link)
	local c = tipCache[link]
	if c then return c end
	local r = { effects = {} }
	if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return r end
	local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
	if not ok or not data or not data.lines then return r end
	-- 아이템 정보가 아직 안 왔으면 (줄이 거의 없음) 기억하지 않는다
	local complete = #data.lines >= 2 and GetItemInfo(link) ~= nil
	local lp = LevelPattern()
	local onEquip = ITEM_SPELL_TRIGGER_ONEQUIP
	for i, line in ipairs(data.lines) do
		local t = plain(line.leftText)
		if i > 1 and type(t) == "string" then
			if IsRed(line.leftColor) or IsRed(line.rightColor) then
				local lv = lp and tonumber(t:match(lp))
				if lv then r.level = lv
				elseif not (DURABILITY_TEMPLATE and t:find(DURABILITY_TEMPLATE:gsub("%%d", "%%d+"):gsub("%%s", ".-"))) then
					r.no = true
				end
			end
			local rt = plain(line.rightText)
			if type(rt) == "string" and (IsRed(line.rightColor)) then r.no = true end
			if onEquip and t:find(onEquip, 1, true) then ParseEffect(t, r.effects) end
		end
	end
	if complete then tipCache[link] = r else M.missed = true end
	return r
end

-- 내 캐릭터가 쓸 수 있는 장비인가 (빨간 줄 없음 · 레벨만 모자란 건 쓸 수 있다고 본다)
function M:Usable(link)
	return not ReadTooltip(link).no
end

-------------------------------------------------------------------------------
-- 점수
-------------------------------------------------------------------------------
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local OFFHAND_FACTOR = 0.5

local scoreCache = {}
function M:Score(link, asOffhand)
	if not link then return 0 end
	local w = self:Weights()
	if not w then return end
	local key = link .. (asOffhand and "#oh" or "") .. self:Mode()
	if scoreCache[key] then return scoreCache[key] end
	local stats = GetItemStats(link)
	if not stats then M.missed = true return end
	local loc = select(4, GetItemInfoInstant(link))
	local total = 0
	for short, full in pairs(K) do
		local v = stats[full]
		if v and v ~= 0 then
			if short == "dps" then
				if RANGED[loc] then total = total + v * (w.rdps or 0)
				else total = total + v * (w.dps or 0) * (asOffhand and OFFHAND_FACTOR or 1) end
			else
				-- 클래식식 적중 · 치명타는 1% 단위. 혹시 등급 수치(큰 숫자)로 오면 대략 1% = 14 로 본다
				if (short == "hit" or short == "crit" or short == "shit" or short == "scrit" or short == "haste") and v > 5 then v = v / 14 end
				total = total + v * (w[short] or 0)
			end
		end
	end
	-- 툴팁에만 있는 장착 효과 (GetItemStats 가 못 읽는 것)
	local tip = ReadTooltip(link)
	for short, v in pairs(tip.effects) do
		if not stats[K[short] or ""] then total = total + v * (w[short] or 0) end
	end
	scoreCache[key] = total
	return total
end

local function Equipped(slot) return GetInventoryItemLink("player", slot) end

-- 본섭: 주 능력치 + 2차 능력치(특화 · 가속 · 치명 · 유연)를 전문화마다 다른 비중으로
--  비중은 그 전문화 BIS 장비(BISData)에 붙은 2차 능력치 합에서 뽑는다 → BIS 가 좋아하는 능력치가 높게.
--  내 전문화 주 능력치가 아닌 장비는 비교하지 않는다. 장신구는 사용 · 발동 효과가 핵심이라 따로 본다.
local PRIMARY = { [1] = "ITEM_MOD_STRENGTH_SHORT", [2] = "ITEM_MOD_AGILITY_SHORT", [4] = "ITEM_MOD_INTELLECT_SHORT" }
local SECONDARY = { "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_VERSATILITY" }
local SEC_NAME = { ITEM_MOD_MASTERY_RATING_SHORT = "특화", ITEM_MOD_HASTE_RATING_SHORT = "가속", ITEM_MOD_CRIT_RATING_SHORT = "치명", ITEM_MOD_VERSATILITY = "유연" }

local function RetailSpec()
	if not (GetSpecialization and GetSpecializationInfo) then return end
	local i = GetSpecialization()
	if not i then return end
	local id, name, _, _, _, primary = GetSpecializationInfo(i)
	local _, class = UnitClass("player")
	return id, name, primary, class
end

local retailW = {}
function M:RetailWeights()
	local id, _, _, class = RetailSpec()
	if not id then return end
	local key = class .. ":" .. id
	if retailW[key] then return retailW[key] end
	local spec = ns.BIS and ns.BIS.specs and ns.BIS.specs[key]
	local sum, total, missing = {}, 0, false
	if spec and spec.g then
		for _, itemID in pairs(spec.g) do
			local st = GetItemStats("item:" .. itemID)
			if st then
				for _, k in ipairs(SECONDARY) do
					local v = st[k] or 0
					sum[k] = (sum[k] or 0) + v
					total = total + v
				end
			else
				missing = true
				if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
			end
		end
	end
	local w = { order = {} }
	local top = 0
	for _, k in ipairs(SECONDARY) do top = math.max(top, sum[k] or 0) end
	for _, k in ipairs(SECONDARY) do
		-- 가장 좋아하는 2차 = 0.6, 나머지는 비율대로 (최소 0.2). BIS 정보가 없으면 모두 0.4
		w[k] = (top > 0) and math.max(0.2, 0.6 * (sum[k] or 0) / top) or 0.4
		w.order[#w.order + 1] = k
	end
	table.sort(w.order, function(x, y) return w[x] > w[y] end)
	w.bis = spec and spec.g
	if total > 0 and not missing then retailW[key] = w end
	return w
end

local function RetailScore(link)
	local stats = GetItemStats(link)
	if not stats then M.missed = true return end
	local _, _, my = RetailSpec()
	local hasPrimary, mine = false, 0
	for id, k in pairs(PRIMARY) do
		if stats[k] then
			hasPrimary = true
			if id == my then mine = stats[k] end
		end
	end
	if hasPrimary and my and mine == 0 then return false end
	local w = M:RetailWeights() or {}
	local sc = mine
	for _, k in ipairs(SECONDARY) do sc = sc + (stats[k] or 0) * (w[k] or 0.4) end
	sc = sc + (stats.ITEM_MOD_STAMINA_SHORT or 0) * 0.02
	return sc
end

function M:RetailOrder()
	local w = self:RetailWeights()
	if not w then return "" end
	local t = {}
	for _, k in ipairs(w.order) do t[#t + 1] = SEC_NAME[k] end
	return table.concat(t, " > ")
end

-- 본섭 장신구: 사용 · 발동 효과가 핵심이라 점수 대신 BIS 여부 + 아이템 레벨만
local function RetailTrinket(link)
	local itemID = GetItemInfoInstant(link)
	local w = M:RetailWeights()
	local isBis = false
	if w and w.bis then
		for slot, id in pairs(w.bis) do
			if (slot == 13 or slot == 14) and id == itemID then isBis = true end
		end
	end
	local function lvl(l) return l and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(l) or 0 end
	local a, b = Equipped(13), Equipped(14)
	local sameID
	for _, e in ipairs({ a, b }) do
		if e and GetItemInfoInstant(e) == itemID then sameID = e end
	end
	local base = sameID and lvl(sameID) or math.min(lvl(a), lvl(b))
	return { trinket = true, bis = isBis, ilvl = lvl(link) - base, same = sameID ~= nil, empty = not a or not b,
		pct = (isBis and not sameID) and 1 or ((sameID and lvl(link) > lvl(sameID)) and 1 or 0) }
end

-------------------------------------------------------------------------------
-- 착용 중인 것과 비교
-------------------------------------------------------------------------------
local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}


-- 결과: { pct, new, old, level, empty } 또는 nil (비교할 수 없음)
function M:Compare(link)
	if not link or Ink.db.itemCompare == false or self:Mode() == "off" then return end
	local loc = select(4, GetItemInfoInstant(link))
	local slots = loc and SLOTS[loc]
	if not slots then return end
	local tip = ReadTooltip(link)
	if tip.no then return end
	if not FOREVER and loc == "INVTYPE_TRINKET" then
		local r = RetailTrinket(link)
		local lvl = tip.level
		if lvl and lvl <= (UnitLevel("player") or 0) then lvl = nil end
		r.level = lvl
		return r
	end
	local score = FOREVER and function(l, oh) return self:Score(l, oh) end or function(l) return RetailScore(l) end
	local new
	local old
	if loc == "INVTYPE_2HWEAPON" then
		new = score(link)
		local mh, oh = Equipped(16), Equipped(17)
		local a = mh and score(mh) or 0
		local b = oh and score(oh, true) or 0
		if a == nil or b == nil then return end
		old = (a or 0) + (FOREVER and (b or 0) or 0)
	elseif loc == "INVTYPE_WEAPON" then
		local mh, oh = Equipped(16), Equipped(17)
		local mhLoc = mh and select(4, GetItemInfoInstant(mh))
		if mhLoc == "INVTYPE_2HWEAPON" then
			-- 양손 → 한손: 한손 + 지금 보조장비 없음
			new, old = score(link), score(mh)
		else
			local ohIsWeapon = oh and select(4, GetItemInfoInstant(oh)) == "INVTYPE_WEAPON"
			local dual = CanDualWield and CanDualWield()
			local sm = mh and score(mh) or 0
			if dual and ohIsWeapon then
				local so = score(oh, true) or 0
				-- 약한 쪽과 비교
				if FOREVER and so < sm * OFFHAND_FACTOR then new, old = score(link, true), so else new, old = score(link), sm end
			elseif dual and not oh then
				new, old = score(link, true), 0
				if not mh then new, old = score(link), 0 end
			else
				new, old = score(link), sm
			end
		end
	elseif loc == "INVTYPE_FINGER" or loc == "INVTYPE_TRINKET" then
		new = score(link)
		local a, b = Equipped(slots[1]), Equipped(slots[2])
		if not a or not b then old = 0
		else
			local sa, sb = score(a), score(b)
			if sa == nil or sb == nil then return end
			old = math.min(sa or 0, sb or 0)
		end
	elseif loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
		local mh = Equipped(16)
		if mh and select(4, GetItemInfoInstant(mh)) == "INVTYPE_2HWEAPON" then return end
		new = score(link, loc == "INVTYPE_WEAPONOFFHAND")
		local oh = Equipped(17)
		old = oh and score(oh, loc == "INVTYPE_WEAPONOFFHAND") or 0
	else
		new = score(link)
		local cur = Equipped(slots[1])
		old = cur and score(cur) or 0
	end
	if new == false or old == false then return end
	if new == nil or old == nil then return end
	local empty = old == 0
	local pct = empty and 100 or ((new - old) / math.max(math.abs(old), 1) * 100)
	local lvl = tip.level
	if lvl and lvl <= (UnitLevel("player") or 0) then lvl = nil end
	return { pct = pct, new = new, old = old, level = lvl, empty = empty }
end

-- 가방 칸: 더 좋은 장비인가 (화살표 표시용)
function M:BagUpgrade(bag, slot)
	local link = C_Container.GetContainerItemLink(bag, slot)
	if not link then return end
	local ok, r = pcall(self.Compare, self, link)
	if not ok or not r then return end
	if r.trinket then
		if r.pct > 0 then return r end
	elseif r.empty or r.pct > 0.5 then
		return r
	end
end

function M:Invalidate()
	wipe(scoreCache)
	self.version = (self.version or 0) + 1
	local bags = Ink.modules.Bags
	if bags and bags.Schedule then pcall(bags.Schedule, bags) end
	pcall(self.UpdateQuestRewards, self)
end

-------------------------------------------------------------------------------
-- 툴팁 줄
-------------------------------------------------------------------------------
local function Line(tt, r)
	local txt
	if r.trinket then
		-- 본섭 장신구
		if r.bis then txt = "|cffFFF468BIS 장신구|r"
		else txt = "|cff9EA3AB장신구 · 사용/발동 효과로 판단|r" end
		if r.same and r.ilvl > 0 then txt = txt .. string.format("  |cff6FD39A같은 장신구 아이템 레벨 +%d|r", r.ilvl)
		elseif r.ilvl ~= 0 and not r.empty then txt = txt .. string.format("  |cff9EA3AB아이템 레벨 %+d|r", r.ilvl) end
		if r.level then txt = txt .. string.format("  |cffFFF468%d레벨부터|r", r.level) end
		tt:AddLine(txt)
		return
	end
	if r.empty then
		txt = "|cff6FD39A▲ 빈 칸에 착용 가능|r"
	else
		local p = math.floor(r.pct + (r.pct >= 0 and 0.5 or -0.5))
		if p > 0 then txt = string.format("|cff6FD39A▲ 착용 대비 +%d%%|r", p)
		elseif p < 0 then txt = string.format("|cffD9776B▼ 착용 대비 %d%%|r", p)
		else txt = "|cff9EA3AB= 착용한 것과 비슷|r" end
	end
	if r.level then txt = txt .. string.format("  |cffFFF468%d레벨부터|r", r.level) end
	local right = FOREVER and M:ProfileName() or M:RetailOrder()
	tt:AddDoubleLine(txt, string.format("|cff5E636B%s|r", right or ""))
end

function M:HookTooltip()
	if not (TooltipDataProcessor and Enum.TooltipDataType) then return end
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		pcall(M.OnTooltip, M, tt)
	end)
end

function M:OnTooltip(tt)
	do
		if Ink.db.itemCompare == false or not tt.AddLine or not tt.GetItem then return end
		-- 비교용 보조 툴팁(착용 중 표시)에는 안 붙인다
		local name = tt.GetName and tt:GetName() or ""
		if name:find("Shopping") or name:find("Compare") then return end
		local ok, _, link = pcall(tt.GetItem, tt)
		link = ok and plain(link)
		if not link then return end
		for s = 1, 19 do if Equipped(s) == link then return end end
		local r = M:Compare(link)
		if r then Line(tt, r) end
	end
end

-------------------------------------------------------------------------------
-- 퀘스트 보상: 더 좋은 장비에 화살표
-------------------------------------------------------------------------------
function M:UpdateQuestRewards()
	if Ink.db.itemCompare == false then return end
	local frame = QuestInfoRewardsFrame
	if not frame or not frame:IsVisible() then return end
	local buttons = frame.RewardButtons or {}
	for i = 1, 10 do
		local b = buttons[i] or _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
		if b and b:IsShown() then
			local link
			local kind = b.type or "choice"
			if QuestInfoFrame and QuestInfoFrame.questLog and GetQuestLogItemLink then
				link = GetQuestLogItemLink(kind, b:GetID())
			elseif GetQuestItemLink then
				link = GetQuestItemLink(kind, b:GetID())
			end
			local r = link and self:Compare(link)
			if not b.foaUp then
				b.foaUp = b:CreateTexture(nil, "OVERLAY", nil, 7)
				b.foaUp:SetTexture(Ink.icon("Up"))
				b.foaUp:SetSize(14, 14)
				local icon = b.Icon or b.icon or _G[(b:GetName() or "") .. "IconTexture"]
				b.foaUp:SetPoint("TOPLEFT", icon or b, "TOPLEFT", -2, 2)
			end
			local show = r and ((r.trinket and r.pct > 0) or (not r.trinket and (r.empty or r.pct > 0.5)))
			b.foaUp:SetShown(show and true or false)
			if show then
				if r.level then b.foaUp:SetVertexColor(C.accent[1], C.accent[2], C.accent[3]) else b.foaUp:SetVertexColor(0.44, 0.83, 0.6) end
			end
		elseif b and b.foaUp then
			b.foaUp:Hide()
		end
	end
end

-------------------------------------------------------------------------------
function M:Init()
	self:HookTooltip()
	if QuestInfo_Display then
		hooksecurefunc("QuestInfo_Display", function() C_Timer.After(0, function() pcall(M.UpdateQuestRewards, M) end) end)
	end
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
		"ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "SKILL_LINES_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event)
		if event == "GET_ITEM_INFO_RECEIVED" then
			-- 아이템 정보가 늦게 와서 점수를 못 낸 칸이 있으면 잠깐 뒤에 다시
			if M.retryQueued or not M.missed then return end
			M.missed = nil
			M.retryQueued = true
			C_Timer.After(0.5, function() M.retryQueued = nil; M:Invalidate() end)
			return
		end
		if event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED" then wipe(tipCache) end
		M:Invalidate()
	end)
end
