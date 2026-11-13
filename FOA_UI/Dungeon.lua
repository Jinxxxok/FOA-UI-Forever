-- FOA UI · 던전 전리품 사이드바 + BIS (본섭 예시 구현)
--  · 세계 지도에 던전 지도가 보이면(또는 던전 안이면) 지도 오른쪽에 "전리품" 사이드바가 붙는다.
--    블리자드 던전 도감 데이터를 내 직업 · 전문화로 걸러서 보스별로 보여 준다.
--  · BIS / 대체 1~3: 진짜 BIS 데이터(BIS_DATA)가 연결되기 전까지는 "예시 순위"로 채운다.
--    (이번 확장팩 던전 전리품을 부위별로 줄 세운 것. 구조 확인용)
--  · 던전에 들어가면 위에 "내 BIS n · 대체 n" 알림, 아이템 툴팁에 순위 · 드랍 위치 줄.
--  · 캐릭터 창 아래 탭 줄 끝에 "BIS" 탭 → 오른쪽에 부위별 BIS 판이 펼쳐진다.
--  던전 도감이 없는 클라이언트(포에버 등)에서는 아무것도 하지 않는다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Dungeon")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

-- 진짜 BIS 데이터가 생기면 여기에: BIS_DATA["ROGUE:260"] = { [itemID] = { rank = 0, slot = 10, src = "..." }, ... }
local BIS_DATA = {}
M.BIS_DATA = BIS_DATA

local SLOT_NAME = {
	[0] = "머리", [1] = "목", [2] = "어깨", [3] = "등", [4] = "가슴", [5] = "손목", [6] = "손", [7] = "허리",
	[8] = "다리", [9] = "발", [10] = "주장비", [11] = "보조장비", [12] = "반지", [13] = "장신구",
}
local SLOT_GLYPH = {
	[0] = "머", [1] = "목", [2] = "어", [3] = "등", [4] = "가", [5] = "손", [6] = "손", [7] = "허",
	[8] = "다", [9] = "발", [10] = "주", [11] = "보", [12] = "반", [13] = "장",
}
-- 캐릭터 창 칸 → 던전 도감 부위
local INV = {
	{ 1, 0, "머리" }, { 2, 1, "목" }, { 3, 2, "어깨" }, { 15, 3, "등" }, { 5, 4, "가슴" }, { 9, 5, "손목" },
	{ 10, 6, "손" }, { 6, 7, "허리" }, { 7, 8, "다리" }, { 8, 9, "발" }, { 11, 12, "반지 1" }, { 12, 12, "반지 2" },
	{ 13, 13, "장신구 1" }, { 14, 13, "장신구 2" }, { 16, 10, "주장비" }, { 17, 11, "보조장비" },
}
local QCOL = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 0.95, 0.95, 0.95 }, [2] = { 0.37, 0.83, 0.37 }, [3] = { 0.29, 0.62, 1 },
	[4] = { 0.76, 0.42, 1 }, [5] = { 1, 0.55, 0.15 }, [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 }, [8] = { 0, 0.8, 1 },
}

local FOREVER = (function() local b = select(4, GetBuildInfo()) or 0 return b >= 16001 and b < 20000 end)()
M.forever = FOREVER
local FLoot, ForeverScan -- 포에버 던전 자료 (아래에서 정의)

local function Available()
	return C_EncounterJournal and EJ_SelectInstance and EJ_GetNumLoot and C_EncounterJournal.GetLootInfoByIndex and true or false
end

-- 내 직업의 전문화 목록 { {id, name, icon}, ... }
-- 포에버: 특성 트리 아이콘 (GetTalentTabInfo 가 없어서 전문화 번호로 아이콘을 찾는다)
local FOREVER_SPEC_ID = {
	WARRIOR = { arms = 71, fury = 72, prot = 73 }, ROGUE = { assassination = 259, combat = 260, subtlety = 261 },
	HUNTER = { bm = 253, mm = 254, sv = 255 }, MAGE = { arcane = 62, fire = 63, frost = 64 },
	WARLOCK = { aff = 265, demo = 266, destro = 267 }, PRIEST = { disc = 256, holy = 257, shadow = 258 },
	DRUID = { balance = 102, feral = 103, guardian = 104, resto = 105 }, PALADIN = { holy = 65, prot = 66, ret = 70 },
	SHAMAN = { ele = 262, enh = 263, resto = 264 },
}
local SPEC_ICON = {
	[71] = 132355, [72] = 132347, [73] = 132341, [259] = 236270, [260] = 236286, [261] = 132320,
	[253] = 461112, [254] = 236179, [255] = 461113, [62] = 135932, [63] = 135810, [64] = 135846,
	[265] = 136145, [266] = 136172, [267] = 136186, [256] = 135940, [257] = 237542, [258] = 136207,
	[102] = 136096, [103] = 132115, [104] = 132276, [105] = 136041, [65] = 135920, [66] = 236264, [70] = 135873,
	[262] = 136048, [263] = 237581, [264] = 136052,
}
local function ForeverSpecIcon(class, key)
	local id = FOREVER_SPEC_ID[class] and FOREVER_SPEC_ID[class][key]
	if not id then return end
	if GetSpecializationInfoByID then
		local ok, _, _, _, icon = pcall(GetSpecializationInfoByID, id)
		if ok and icon then return icon end
	end
	return SPEC_ICON[id]
end

local function Specs()
	local list = {}
	if FOREVER then
		-- 포에버: 전문화 대신 특성 트리 (FOA 아이템 점수와 같은 이름표)
		local sc = ns.Score
		local _, class = UnitClass("player")
		local tabs = sc and sc.TABS and sc.TABS[class] or {}
		for t, key in ipairs(tabs) do
			local icon
			if GetTalentTabInfo then
				local _, b, _, d = GetTalentTabInfo(t)
				icon = (type(b) == "number" and b) or (type(d) == "number" and d) or nil
			end
			icon = icon or ForeverSpecIcon(class, key)
			list[#list + 1] = { id = key, name = sc.SPEC_NAME[key] or key, icon = icon }
			if class == "DRUID" and key == "feral" then
				list[#list + 1] = { id = "guardian", name = sc.SPEC_NAME.guardian or "수호", icon = ForeverSpecIcon(class, "guardian") or icon }
			end
		end
		return list
	end
	local n = GetNumSpecializations and GetNumSpecializations() or 0
	for i = 1, n do
		local id, name, _, icon = GetSpecializationInfo(i)
		if id then list[#list + 1] = { id = id, name = name, icon = icon } end
	end
	return list
end

local function CurrentSpecID()
	if FOREVER then
		if not ns.Score then return "" end
		local _, spec = ns.Score:Spec() -- (a and f() 는 값 하나만 돌려주므로 따로 부른다)
		return spec or ""
	end
	local idx = GetSpecialization and GetSpecialization()
	return idx and GetSpecializationInfo(idx) or 0
end

-- 지금 "보고 있는" 전문화 (BIS 판 · 사이드바에서 바꿀 수 있다. 기본은 지금 전문화)
local function ViewSpecID()
	local v = Ink.cdb and Ink.cdb.bisSpec
	if v then
		for _, sp in ipairs(Specs()) do if sp.id == v then return v end end
	end
	return CurrentSpecID()
end

local function SpecKey()
	local _, class, classID = UnitClass("player")
	local specID = ViewSpecID() or 0
	local specName = ""
	for _, sp in ipairs(Specs()) do if sp.id == specID then specName = sp.name end end
	return class .. ":" .. specID, classID, specID, specName, class
end

-- 포에버: 보고 있는 특성 키 ("arcane" 등) · 점수를 그 특성 기준으로
local function ViewKey()
	local v = ViewSpecID()
	return type(v) == "string" and v ~= "" and v or nil
end

function M:SetViewSpec(id)
	if Ink.cdb then Ink.cdb.bisSpec = (id ~= CurrentSpecID()) and id or nil end
	self.dirty = true
	self:PaintSidebar()
	self:PaintBis()
end

-- 전문화 고르기 (아이콘 줄): 고른 것 = 노란 테두리, 지금 내 전문화 = 아래 작은 점
local function SpecPills(parent, size)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(10, size)
	holder.btns = {}
	function holder:Refresh()
		local specs = Specs()
		local view, cur = ViewSpecID(), CurrentSpecID()
		local x = 0
		for i, sp in ipairs(specs) do
			local b = self.btns[i]
			if not b then
				b = CreateFrame("Button", nil, self)
				b:SetSize(size, size)
				b.icon = b:CreateTexture(nil, "ARTWORK")
				b.icon:SetPoint("TOPLEFT", 2, -2)
				b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
				b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				local m = b:CreateMaskTexture()
				m:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				m:SetAllPoints(b.icon)
				b.icon:AddMaskTexture(m)
				b.bd = Ink:Round(b, "OVERLAY", true, true)
				b.bd:SetAllPoints()
				b.dot = b:CreateTexture(nil, "OVERLAY", nil, 2)
				b.dot:SetTexture(Ink.tex.disc)
				b.dot:SetSize(5, 5)
				b.dot:SetPoint("TOP", b, "BOTTOM", 0, -2)
				b.dot:SetVertexColor(C.green[1], C.green[2], C.green[3])
				b:SetScript("OnClick", function(btn) M:SetViewSpec(btn.specID) end)
				b:SetScript("OnEnter", function(btn)
					GameTooltip:SetOwner(btn, "ANCHOR_TOP")
					GameTooltip:AddLine(btn.specName .. " BIS 보기", 1, 1, 1)
					if btn.specID == CurrentSpecID() then GameTooltip:AddLine("지금 내 전문화", 0.44, 0.83, 0.6) end
					GameTooltip:Show()
				end)
				b:SetScript("OnLeave", GameTooltip_Hide)
				self.btns[i] = b
			end
			b.specID, b.specName = sp.id, sp.name
			b.icon:SetTexture(sp.icon)
			local on = sp.id == view
			local a = C.accent
			b.bd:SetVertexColor(on and a[1] or 1, on and a[2] or 1, on and a[3] or 1, on and 1 or 0.15)
			b.icon:SetDesaturated(not on)
			b.icon:SetAlpha(on and 1 or 0.6)
			b.dot:SetShown(sp.id == cur)
			b:ClearAllPoints()
			b:SetPoint("LEFT", x, 0)
			b:Show()
			x = x + size + 5
		end
		for i = #specs + 1, #self.btns do self.btns[i]:Hide() end
		self:SetWidth(math.max(10, x - 5))
	end
	return holder
end

-------------------------------------------------------------------------------
-- 던전 도감 읽기
--  도감 선택 상태는 블리자드 창과 같이 쓰는 것이라, 읽은 뒤 원래 필터로 되돌린다.
--  블리자드 던전 도감 창이 열려 있으면 그 화면이 바뀌지 않게 읽지 않는다.
-------------------------------------------------------------------------------
M.cache = {}      -- [journalInstanceID] = { id, name, bosses = { { index, id, name, items = {...} } }, missing }
M.ranks = {}      -- [itemID] = { rank, slot, inst, boss, bossName }
M.rankCount = {}  -- [journalInstanceID] = { bis = n, alt = n }

local function WithEJ(fn)
	if EncounterJournal and EncounterJournal:IsShown() then return false end
	local oc, os = EJ_GetLootFilter()
	local slotFilter = C_EncounterJournal.GetSlotFilter and C_EncounterJournal.GetSlotFilter()
	local tier = EJ_GetCurrentTier and EJ_GetCurrentTier()
	local ok, err = pcall(fn)
	pcall(EJ_SetLootFilter, oc or 0, os or 0)
	if slotFilter and C_EncounterJournal.SetSlotFilter then pcall(C_EncounterJournal.SetSlotFilter, slotFilter) end
	if tier and EJ_SelectTier then pcall(EJ_SelectTier, tier) end
	if not ok then Ink:LogError("Dungeon: " .. tostring(err)) end
	return ok
end

local function ReadInstance(jid)
	local _, classID, specID = SpecKey()
	local data = { id = jid, bosses = {}, missing = 0 }
	EJ_SelectInstance(jid)
	data.name = EJ_GetInstanceInfo(jid)
	EJ_SetLootFilter(classID or 0, specID or 0)
	if C_EncounterJournal.ResetSlotFilter then C_EncounterJournal.ResetSlotFilter() end
	local byEnc = {}
	for i = 1, 30 do
		local name, _, encID = EJ_GetEncounterInfoByIndex(i, jid)
		if not name then break end
		local b = { index = i, id = encID, name = name, items = {} }
		data.bosses[i] = b
		byEnc[encID] = b
	end
	for i = 1, EJ_GetNumLoot() do
		local info = C_EncounterJournal.GetLootInfoByIndex(i)
		if info and info.itemID then
			local b = info.encounterID and byEnc[info.encounterID]
			if not info.name then data.missing = data.missing + 1 end
			if b then
				local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(info.itemID)
				table.insert(b.items, {
					id = info.itemID, name = info.name, link = info.link, icon = info.icon,
					slot = info.filterType, slotText = info.slot, armor = info.armorType, quality = q or 3,
					inst = jid, boss = b.index, bossName = b.name,
				})
			end
		end
	end
	return data
end

function M:Scan(jid, quiet)
	if FOREVER then
		if not jid then return end
		local cached = self.cache[jid]
		if cached and cached.missing == 0 then return cached end
		local data = ForeverScan(jid, quiet)
		if data then self.cache[jid] = data end
		return data or cached
	end
	if not Available() or not jid then return nil end
	local key = SpecKey()
	local cached = self.cache[jid]
	if cached and cached.spec == key and cached.missing == 0 then return cached end
	local data
	WithEJ(function() data = ReadInstance(jid) end)
	if data then
		data.spec = key
		self.cache[jid] = data
	end
	return data or cached
end

-- 이번 확장팩 레이드 + 던전 목록 (순위를 매길 범위). 레이드를 앞에 둬서 같은 품질이면 레이드 템이 먼저
function M:TierDungeons()
	if self.tierList then return self.tierList end
	local list = {}
	self.isRaid = {}
	WithEJ(function()
		local n = EJ_GetNumTiers and EJ_GetNumTiers()
		if n and EJ_SelectTier then EJ_SelectTier(n) end
		for _, raid in ipairs({ true, false }) do
			for i = 1, 30 do
				local id = EJ_GetInstanceByIndex(i, raid)
				if not id then break end
				list[#list + 1] = id
				self.isRaid[id] = raid
			end
		end
	end)
	self.tierList = list
	return list
end

-- 캐릭터 창 칸 번호 → 던전 도감 부위
local INV2EJ = { [1] = 0, [2] = 1, [3] = 2, [15] = 3, [5] = 4, [9] = 5, [10] = 6, [6] = 7, [7] = 8, [8] = 9,
	[11] = 12, [12] = 12, [13] = 13, [14] = 13, [16] = 10, [17] = 11 }
M.INV2EJ = INV2EJ

local SECONDARY = { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_VERSATILITY" }

-- 아이템 정보 요청은 아이템마다 한 번만 (계속 다시 요청하면 서버가 늦게 주거나 안 준다)
--  도착하면 잠깐 모아서 한 번에 다시 그린다 (답이 안 오면 30초 뒤 한 번 더)
local requested = {}
local arrivePending
local function ItemArrived()
	if arrivePending then return end
	arrivePending = true
	C_Timer.After(0.6, function()
		arrivePending = nil
		M.dirty = true
		pcall(M.PaintSidebar, M)
		pcall(M.PaintBis, M)
	end)
end
-- 서버에 아이템 정보를 한꺼번에 너무 많이 물으면 뒤쪽 요청이 버려진다
--  (레벨 BIS 후보 수백 개를 먼저 물어서, 나중에 연 붉은십자군 수도원 등의 전리품이 끝내 안 오던 문제)
--  → 줄을 세워 조금씩 보내고, 지금 화면에 보이는 것(prio)은 맨 앞으로 · 8초 안에 안 오면 다시 줄 세우기
local queue, queued = {}, {}
local pumpTicker
local function Send(id)
	requested[id] = GetTime()
	if Item and Item.CreateFromItemID then
		local it = Item:CreateFromItemID(id)
		if it.IsItemEmpty and it:IsItemEmpty() then return end
		it:ContinueOnItemLoad(ItemArrived)
	elseif C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, id)
	end
end
local function Pump()
	local n = 0
	while n < 4 and #queue > 0 do
		local id = table.remove(queue, 1)
		queued[id] = nil
		local cached = C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(id)
		if not cached then Send(id); n = n + 1 end
	end
	if #queue == 0 and pumpTicker then pumpTicker:Cancel(); pumpTicker = nil end
end
-- 같은 아이템을 끝없이 다시 묻지 않는다 (게임이 들고 있는 아이템 정보는 개수 한도가 있어서,
--  수백 개를 계속 돌려 물으면 먼저 받은 것 · 착용 중인 장비 정보가 밀려났다가 다시 오기를 반복했다)
--  화면에 보이는 것(prio)은 6번, 순위 계산용은 3번까지
local tries = {}
local function RequestItem(id, prio)
	if not id then return end
	if C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(id) then return end
	local t = requested[id]
	if t and GetTime() - t < 8 then return end
	if (tries[id] or 0) >= (prio and 6 or 3) then return end
	if not queued[id] then tries[id] = (tries[id] or 0) + 1 end
	if queued[id] then
		if not prio then return end
		for i, q in ipairs(queue) do if q == id then table.remove(queue, i) break end end
	end
	queued[id] = true
	if prio then table.insert(queue, 1, id) else queue[#queue + 1] = id end
	if not pumpTicker then
		if C_Timer.NewTicker then pumpTicker = C_Timer.NewTicker(0.2, Pump) else Pump() end
	end
end

local function ItemStats(id)
	local ok, st = pcall(C_Item.GetItemStats, "item:" .. id)
	return ok and st or nil
end

-- BIS 장비에 붙은 2차 능력치 합 → 이 전문화가 좋아하는 능력치 비중
local function Weights(spec)
	local w, total = {}, 0
	for _, id in pairs(spec.g) do
		local st = ItemStats(id)
		if st then
			for _, k in ipairs(SECONDARY) do
				local v = st[k] or 0
				w[k] = (w[k] or 0) + v
				total = total + v
			end
		else
			RequestItem(id)
		end
	end
	if total <= 0 then return nil end
	for _, k in ipairs(SECONDARY) do w[k] = (w[k] or 0) / total end
	return w
end

local function Score(it, w)
	local st = ItemStats(it.id)
	if not st then return 0 end
	local sc = 0
	for _, k in ipairs(SECONDARY) do sc = sc + (st[k] or 0) * ((w and w[k]) or 0.25) end
	return sc
end

-- 도감에 없는 아이템(제작 · 티어 · 기타)의 표시 정보
local function LooseItem(id)
	local _, _, _, _, icon = C_Item.GetItemInfoInstant(id)
	local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not name then RequestItem(id, true) end
	local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
	local _, link = C_Item.GetItemInfo(id)
	local data = ns.BIS
	local src = (data and data.crafted[id]) and "전문기술 제작"
		or (data and data.tier[id]) and "티어 세트 · 레이드 / 촉매"
		or (ns.ItemSourceText and ns.ItemSourceText(id)) or "기타 (평판 · 상점 · 월드 드랍 등)"
	return { id = id, name = name, icon = icon, quality = q or 4, link = link, srcText = src }
end

-- 아이템 출처 글자
-- 포에버: 아이템 → 어느 던전 어느 보스 (처음 물어볼 때 한 번 만든다)
function M:DropSource(id)
	if not self.dropIndex then
		local idx = {}
		for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
			for _, b in ipairs(d.bosses or {}) do
				for _, iid in ipairs(b[2]) do
					if not idx[iid] then idx[iid] = { d, b } end
				end
			end
		end
		self.dropIndex = idx
	end
	local e = self.dropIndex[id]
	if not e then return end
	local d, b = e[1], e[2]
	local bn = M.BossName and M.BossName({ npc = b[3], name = b[1] }) or b[1]
	return d.ko .. " · " .. bn
end

function M:SourceText(it)
	if it.srcText then return it.srcText end
	if it.quest then return self:QuestSourceText(it) end
	if it.wsrc then return self:WorldSourceText(it) end
	if it.craft then
		local t = "제작 · " .. (M.CRAFT_PROF and M.CRAFT_PROF[it.craft] or "전문기술")
		if it.spell and M.RecipeFor and M:RecipeFor(it.spell) then t = t .. " · 제조법 상인" end
		local price = ns.AHPrice and ns.AHPrice(it.id)
		local A = Ink.modules.AHPrice
		if price and A and A.Money then t = t .. "  ·  경매장 " .. A.Money(price) end
		return t
	end
	if FOREVER and it.inst and it.kind == 3 and ns.ItemSourceText and ns.ItemSourceText(it.id) then
		return self:WorldSourceText(it)
	end
	if FOREVER and it.inst then
		local d = FLoot(it.inst)
		local bn = M.BossName and M.BossName({ npc = it.npc, name = it.bossName }) or it.bossName
		return (d and (d.ko or d.en) or "던전") .. " · " .. (bn or "") .. (it.kind == 1 and " (희귀몹)" or (it.kind == 2 and " (특수 몹 · 상자)" or ""))
	end
	local inst = self.cache[it.inst]
	return (inst and inst.name or "던전") .. " · " .. (it.boss or "?") .. "넴 " .. (it.bossName or "")
end

-- 포에버 획득처 (Method 공략 영어) → 한글로 짧게
local SRC_KO = {
	{ "Leatherworking", "가죽세공" }, { "Blacksmithing", "대장기술" }, { "Tailoring", "재봉술" }, { "Enchanting", "마법부여" },
	{ "Engineering", "기계공학" }, { "World Drop", "월드 드랍" }, { "BoE", "착귀" }, { "Quest", "퀘스트" }, { "Unknown", "획득처 미확인" },
	{ "No known source yet", "획득처 미확인" }, { "Exalted", "확고한 동맹" }, { "Revered", "매우 우호적" }, { "Friendly", "우호적" },
	{ "Darkmoon Faire", "다크문 축제" }, { "Razorfen Downs", "가시덩굴 구릉" }, { "Lower Blackrock Spire", "검은바위 첨탑 하층" },
	{ "Upper Blackrock Spire", "검은바위 첨탑 상층" }, { "Blackrock Depths", "검은바위 나락" }, { "Stratholme", "스트라솔름" },
	{ "Dire Maul", "혈투의 전장" }, { "Tarnished Undermine Real", "빛바랜 언더마인 주화" }, { "rep", "평판" }, { " or ", " / " },
	{ "Reputation:", "평판:" }, { "Drop:", "" },
}
local function KoSource(s)
	if not s then return "기타" end
	for _, r in ipairs(SRC_KO) do s = s:gsub(r[1], r[2]) end
	return s
end

-- 포에버 던전 전리품 (ForeverLoot.lua · 던전 도감 대신)
local EQUIP_EJ = {
	INVTYPE_HEAD = 0, INVTYPE_NECK = 1, INVTYPE_SHOULDER = 2, INVTYPE_CLOAK = 3, INVTYPE_CHEST = 4, INVTYPE_ROBE = 4,
	INVTYPE_WRIST = 5, INVTYPE_HAND = 6, INVTYPE_WAIST = 7, INVTYPE_LEGS = 8, INVTYPE_FEET = 9,
	INVTYPE_WEAPON = 10, INVTYPE_WEAPONMAINHAND = 10, INVTYPE_2HWEAPON = 10, INVTYPE_WEAPONOFFHAND = 11,
	INVTYPE_SHIELD = 11, INVTYPE_HOLDABLE = 11, INVTYPE_FINGER = 12, INVTYPE_TRINKET = 13,
}
FLoot = function(key)
	for i, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
		if d.key == key then return d, i end
	end
end
M.FLoot = FLoot

-- quiet: 이름이 없어도 서버에 요청하지 않는다 (추천 계산용으로 모든 던전을 훑을 때)
-- 퀘스트를 시작하는 아이템 → 그 퀘스트를 받을 수 있는 진영 (다른 진영 것은 전리품 목록에서 뺀다:
--  "티탄의 유물"처럼 얼라 · 호드용이 따로 있어서 같은 이름이 두 번 보였다)
local startItemFac
local function OtherFactionItem(id)
	if not startItemFac then
		if not ns.DUNGEON_QUESTS then return false end
		startItemFac = {}
		for _, list in pairs(ns.DUNGEON_QUESTS or {}) do
			for _, q in ipairs(list) do
				local item, fac = q[13] or 0, q[3] or 0
				if item > 0 then
					local t = startItemFac[item] or {}
					startItemFac[item] = t
					t[fac] = true
				end
			end
		end
	end
	local t = startItemFac[id]
	if not t or t[0] then return false end
	local fg = UnitFactionGroup("player")
	local facN = fg == "Horde" and 1 or (fg == "Alliance" and 2 or 0)
	return facN ~= 0 and not t[facN]
end

ForeverScan = function(key, quiet)
	local d = FLoot(key)
	if not d then return end
	local data = { id = key, name = d.ko or d.en, lo = d.lo, hi = d.hi, bosses = {}, missing = 0, d = d }
	for bi, b in ipairs(d.bosses) do
		local boss = { index = bi, name = b[1], npc = b[3], rare = (b[4] or 0) >= 1, kind = b[4], en = b[5], items = {} }
		for _, id in ipairs(b[2]) do
			local iid, _, _, loc, icon = C_Item.GetItemInfoInstant(id)
			-- 게임 자료에 없는 아이템(패치로 바뀐 번호)은 건너뛴다. 안 그러면 영원히 "불러오는 중"
			if iid and not OtherFactionItem(id) then
				local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(id)
				local name, link
				if cached then
					name, link = C_Item.GetItemInfo(id)
					name = name or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
				end
				if not name then
					data.missing = data.missing + 1
					if not quiet then RequestItem(id, true) end
				end
				local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
				table.insert(boss.items, {
					id = id, name = name, link = link, icon = icon, slot = loc and EQUIP_EJ[loc], quality = q or 2,
					inst = key, boss = bi, bossName = b[1], npc = b[3], rare = (b[4] or 0) >= 1, kind = b[4],
				})
			end
		end
		data.bosses[bi] = boss
	end
	return data
end

-- 포에버: 공략 BIS (g) = BIS, 공략 대체(alt) 순서 = 대체 1~3 (던전 도감이 없어서 전리품 표 대신 공략 목록)
function M:BuildRanksForever()
	local lvl = UnitLevel("player") or 60
	local skey = SpecKey()
	local key = skey .. ":" .. lvl .. (Ink.db.bisCrafts == false and "" or ":c") .. (Ink.db.bisQuests == false and "" or ":q") .. (Ink.db.bisWorld == false and "" or ":w")
	if self.rankKey == key and not self.dirty then return end
	-- 아이템이 도착할 때마다(dirty) 곧바로 다시 만들면, 0.2초마다 다시 그려지는 아이템 툴팁이
	--  수천 개 후보를 계속 훑었다 → 같은 조건이면 2초에 한 번만, 미뤄진 건 잠시 뒤 한 번에
	local now = GetTime()
	if self.rankKey == key and self.rankAt and now - self.rankAt < 2 then
		if not self.rankDefer then
			self.rankDefer = true
			C_Timer.After(2.05 - (now - self.rankAt), function()
				M.rankDefer = nil
				if not M.dirty then return end
				if (M.bisPanel and M.bisPanel:IsShown()) or (M.sidebar and M.sidebar:IsShown()) then
					pcall(M.PaintSidebar, M)
					pcall(M.PaintBis, M)
				end
			end)
		end
		return
	end
	self.rankKey, self.dirty, self.rankAt = key, nil, now
	wipe(self.ranks)
	wipe(self.rankCount)
	local spec = ns.BIS_FOREVER and ns.BIS_FOREVER.specs[skey]
	self.spec = spec and { src = ns.BIS_FOREVER.src, g = spec.g, fo = spec } or nil
	self.isExample = false
	local per = {}
	-- 던전 전리품 모음 (아이템 → 어느 던전 몇 넴)
	local pool, byId = {}, {}
	-- 만렙 전에는 지금 갈 수 있는 던전(권장 최저 레벨 ≤ 내 레벨 + 4)만 대체템 후보로
	for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
		local data = (not d.soon) and self:Scan(d.key, true)
		local open = lvl >= 60 or d.lo <= lvl + 4
		for _, b in ipairs(data and data.bosses or {}) do
			for _, it in ipairs(b.items) do
				byId[it.id] = byId[it.id] or it
				if it.slot and open then
					pool[it.slot] = pool[it.slot] or {}
					table.insert(pool[it.slot], it)
				end
			end
		end
	end
	-- 만렙 전: 공략 BIS(만렙 기준) 대신 지금 레벨에 착용 가능한 최고템 (아래 BuildLevelRanks)
	self.levelMode = lvl < 60
	if self.levelMode then
		self:AddCrafts(pool, lvl)
		self:AddQuestRewards(pool, lvl)
		self:AddWorldSources(pool, lvl)
		return self:BuildLevelRanks(pool, lvl)
	end
	self:AddQuestRewards(pool, lvl)
	self:AddWorldSources(pool, lvl)
	local function Fill()
		-- 공략 대체가 3개 안 되는 칸은 던전 전리품 중 FOA 점수(직업 · 특성 가중치) 높은 순으로 채운다
		local sc = ns.Score
		if not sc then return end
		for slot, list in pairs(pool) do
			local cand = {}
			for _, it in ipairs(list) do
				if not self.ranks[it.id] then
					local l = "item:" .. it.id
					local v = sc:Score(l, nil, FOREVER and ViewKey() or nil)
					if v and v > 0 and sc:Usable(l) then it.score = v; cand[#cand + 1] = it end
				end
			end
			table.sort(cand, function(a, b) return a.score > b.score end)
			for _, it in ipairs(cand) do
				if (per[slot] or 0) >= 3 then break end
				per[slot] = (per[slot] or 0) + 1
				self.ranks[it.id] = { rank = per[slot], slot = slot, it = it, foa = true }
			end
		end
		for _, r in pairs(self.ranks) do
			if r.it.inst then
				local c = self.rankCount[r.it.inst] or { bis = 0, alt = 0 }
				if r.rank == 0 then c.bis = c.bis + 1 else c.alt = c.alt + 1 end
				self.rankCount[r.it.inst] = c
			end
		end
	end
	if not spec then Fill() return end
	for inv, id in pairs(spec.g) do
		local slot = INV2EJ[inv]
		if slot then
			local it = byId[id] or LooseItem(id)
			if not it.inst then it.srcText = KoSource(spec.src[id]) end
			it.slot = it.slot or slot
			self.ranks[id] = { rank = 0, slot = slot, it = it, inv = inv }
		end
	end
	for _, a in ipairs(spec.alt) do
		local inv, id = a[1], a[2]
		local slot = INV2EJ[inv]
		if slot and not self.ranks[id] then
			per[slot] = (per[slot] or 0) + 1
			if per[slot] <= 3 then
				local it = byId[id] or LooseItem(id)
				if not it.inst then it.srcText = KoSource(spec.src[id]) end
				it.slot = it.slot or slot
				self.ranks[id] = { rank = per[slot], slot = slot, it = it, inv = inv }
			end
		end
	end
	Fill()
end

-- 순위 매기기
--  BIS 자료가 있는 전문화: BIS = 자료의 장비, 대체 1~3 = 이번 확장팩 레이드 · 던전 전리품 중
--  BIS 장비들의 2차 능력치 비중으로 점수를 매긴 상위 3개 (FOA 계산)
--  자료가 없으면: 예시 (부위마다 품질 → 레이드 · 던전 → 보스 순)
function M:BuildRanks(extra)
	if FOREVER then return self:BuildRanksForever() end
	local key = SpecKey()
	if self.rankKey == key and not extra and not self.dirty then return end
	self.rankKey, self.dirty = key, nil
	wipe(self.ranks)
	wipe(self.rankCount)
	local spec = ns.BIS and ns.BIS.specs[key]
	self.spec = spec
	local pool, byId = {}, {}
	local ids = {}
	for _, id in ipairs(self:TierDungeons()) do ids[#ids + 1] = id end
	if extra then
		local found
		for _, id in ipairs(ids) do if id == extra then found = true end end
		if not found then table.insert(ids, 1, extra) end
	end
	for order, jid in ipairs(ids) do
		local data = self:Scan(jid)
		if data then
			for _, b in ipairs(data.bosses) do
				for _, it in ipairs(b.items) do
					if it.slot then
						it.order = order
						pool[it.slot] = pool[it.slot] or {}
						table.insert(pool[it.slot], it)
						byId[it.id] = byId[it.id] or it
					end
				end
			end
		end
	end
	if spec then
		-- BIS: 칸마다 (반지 · 장신구는 두 칸 모두 BIS)
		local bisIds = {}
		for inv, id in pairs(spec.g) do
			local slot = INV2EJ[inv]
			local it = byId[id] or LooseItem(id)
			it.slot = it.slot or slot
			self.ranks[id] = { rank = 0, slot = slot, it = it, inv = inv }
			bisIds[id] = true
		end
		-- 대체 1~3: BIS 능력치 비중 점수
		local w = Weights(spec)
		for slot, list in pairs(pool) do
			local cand, seen = {}, {}
			for _, it in ipairs(list) do
				if not bisIds[it.id] and not seen[it.id] then
					seen[it.id] = true
					it.score = Score(it, w)
					cand[#cand + 1] = it
				end
			end
			table.sort(cand, function(a, b)
				if a.score ~= b.score then return a.score > b.score end
				if a.quality ~= b.quality then return a.quality > b.quality end
				return a.order < b.order
			end)
			for i = 1, math.min(3, #cand) do self.ranks[cand[i].id] = { rank = i, slot = slot, it = cand[i] } end
		end
	else
		for slot, list in pairs(pool) do
			table.sort(list, function(a, b)
				if a.quality ~= b.quality then return a.quality > b.quality end
				if a.order ~= b.order then return a.order < b.order end
				if a.boss ~= b.boss then return a.boss > b.boss end
				return a.id < b.id
			end)
			local seen, n = {}, 0
			local max = (slot == 12 or slot == 13) and 5 or 4
			for _, it in ipairs(list) do
				if not seen[it.id] and n < max then
					seen[it.id] = true
					self.ranks[it.id] = { rank = n, slot = slot, it = it }
					n = n + 1
				end
			end
		end
	end
	for _, r in pairs(self.ranks) do
		if r.it.inst then
			local c = self.rankCount[r.it.inst] or { bis = 0, alt = 0 }
			if r.rank == 0 then c.bis = c.bis + 1 else c.alt = c.alt + 1 end
			self.rankCount[r.it.inst] = c
		end
	end
	self.isExample = not spec
end

-- 자료 출처 한 줄
function M:SourceLabel()
	if FOREVER and self.levelMode then
		local srcs = { "던전" }
		if Ink.db.bisCrafts ~= false and ns.FOREVER_CRAFTS then srcs[#srcs + 1] = "제작" end
		if Ink.db.bisQuests ~= false and ns.FOREVER_QREWARDS then srcs[#srcs + 1] = "퀘스트" end
		if Ink.db.bisWorld ~= false and ns.FOREVER_SOURCES then srcs[#srcs + 1] = "월드 · 필드 · 상인 · 평판" end
		return (UnitLevel("player") or 1) .. "레벨 착용 가능\n" .. table.concat(srcs, " · ") .. " 중 FOA 점수 순"
	end
	if FOREVER then
		return self.spec and ("BIS · 대체: " .. self.spec.src .. " (레이드 전) + FOA 점수") or "대체: FOA 점수 (공략 BIS 준비 중)"
	end
	if self.spec then return "BIS: " .. self.spec.src .. " · 대체: FOA 계산" end
	return "예시 순위 (BIS 자료 없음)"
end

local function RankText(r)
	if not r then return nil end
	if r.lvlMode then return r.rank == 0 and "레벨 최고" or ("다음 " .. r.rank) end
	if r.rank == 0 then return "BIS" end
	return "대체 " .. r.rank
end

-------------------------------------------------------------------------------
-- 공용 꾸밈
-------------------------------------------------------------------------------
local function Panel(f, accentColor)
	f.bg = Ink:Round(f, "BACKGROUND", false, false, -8)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.96)
	f.bd = Ink:Round(f, "BORDER", false, true, -8)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.08)
	f.accent = f:CreateTexture(nil, "ARTWORK")
	local a = accentColor or C.accent
	f.accent:SetColorTexture(a[1], a[2], a[3], 0.95)
	f.accent:SetSize(26, 2)
	f.accent:SetPoint("TOPLEFT", 16, -1)
end

-- 순위 배지: BIS = 노란 바탕, 대체 = 노란 테두리
local function Badge(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(40, 18)
	b.fill = Ink:Round(b, "BACKGROUND", true, false)
	b.fill:SetAllPoints()
	b.line = Ink:Round(b, "BORDER", true, true)
	b.line:SetAllPoints()
	b.text = Ink:Text(b, F.latinB, 10, C.text, "CENTER")
	b.text:SetPoint("CENTER", 0, 0)
	function b:Set(r)
		if not r then self:Hide() return end
		local a = C.accent
		if r.rank == 0 then
			self.fill:SetVertexColor(a[1], a[2], a[3], 1)
			self.line:SetVertexColor(a[1], a[2], a[3], 1)
			self.text:SetFont(r.lvlMode and F.bold or F.latinB, Ink:BoostSize(10), "")
			self.text:SetTextColor(0.05, 0.055, 0.07)
			self.text:SetText(r.lvlMode and "최고" or "BIS")
			self:SetWidth(r.lvlMode and 36 or 34)
		else
			self.fill:SetVertexColor(a[1], a[2], a[3], 0.06)
			self.line:SetVertexColor(a[1], a[2], a[3], 0.6)
			self.text:SetFont(F.semi, Ink:BoostSize(10), "")
			self.text:SetTextColor(a[1], a[2], a[3])
			self.text:SetText((r.lvlMode and "다음 " or "대체 ") .. r.rank)
			self:SetWidth(44)
		end
		self:Show()
	end
	return b
end

local function ItemIcon(parent, size)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(size, size)
	h.icon = h:CreateTexture(nil, "ARTWORK")
	h.icon:SetPoint("TOPLEFT", 1, -1)
	h.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local m = h:CreateMaskTexture()
	m:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(h.icon)
	h.icon:AddMaskTexture(m)
	h.bd = Ink:Round(h, "OVERLAY", true, true)
	h.bd:SetAllPoints()
	h.glyph = Ink:Text(h, F.semi, 11, C.muted, "CENTER")
	h.glyph:SetPoint("CENTER")
	function h:Set(icon, q, glyph)
		local c = QCOL[q or 1] or QCOL[1]
		self.bd:SetVertexColor(c[1], c[2], c[3], 0.9)
		if icon then
			self.icon:SetTexture(icon)
			self.icon:Show()
			self.glyph:SetText("")
		else
			self.icon:Hide()
			self.glyph:SetText(glyph or "")
			self.glyph:SetTextColor(c[1], c[2], c[3])
		end
	end
	return h
end

-------------------------------------------------------------------------------
-- 전리품 사이드바 (지도 오른쪽)
-------------------------------------------------------------------------------
local SB_W, ROW_H, HEAD_H = 330, 40, 30

function M:BuildSidebar()
	local f = CreateFrame("Frame", "FOADungeonLoot", UIParent)
	f:SetSize(SB_W, 600)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	Panel(f)
	f.tag = Ink:Text(f, F.latinB, 9, C.muted, "LEFT")
	f.tag:SetPoint("TOPLEFT", 16, -14)
	f.title = Ink:Text(f, F.bold, 15, C.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f.tag, "BOTTOMLEFT", 0, -4)
	f.title:SetWidth(SB_W - 32)
	if FOREVER then
		-- 포에버: 던전 고르기(펼치기) · 진행 경로 · 보기 방식은 따로 (아래 BuildForeverTop)
		self:BuildForeverTop(f)
		self:BuildList(f)
		self.sidebar = f
		return
	end
	-- 요약: 큰 숫자 BIS · 대체 + 직업/전문화
	f.nBis = Ink:Text(f, F.num, 34, C.accent, "LEFT")
	f.nBis:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -12)
	f.lBis = Ink:Text(f, F.sans, 10, C.soft, "LEFT")
	f.lBis:SetPoint("TOPLEFT", f.nBis, "BOTTOMLEFT", 1, -2)
	f.lBis:SetText("BIS")
	f.nAlt = Ink:Text(f, F.num, 34, C.text, "LEFT")
	f.nAlt:SetPoint("LEFT", f.nBis, "RIGHT", 26, 0)
	f.lAlt = Ink:Text(f, F.sans, 10, C.soft, "LEFT")
	f.lAlt:SetPoint("TOPLEFT", f.nAlt, "BOTTOMLEFT", 1, -2)
	f.lAlt:SetText("대체템")
	f.pills = SpecPills(f, 22)
	f.pills:SetPoint("TOPRIGHT", -16, -56)
	f.spec = Ink:Text(f, F.semi, 11, C.text, "RIGHT")
	f.spec:SetPoint("TOPRIGHT", f.pills, "BOTTOMRIGHT", 0, -9)
	f.example = Ink:Text(f, F.sans, 10, C.dim, "RIGHT")
	f.example:SetPoint("TOPRIGHT", f.spec, "BOTTOMRIGHT", 0, -4)
	-- 내 장비만 / 전부
	f.mine = CreateFrame("Button", nil, f)
	f.mine:SetSize(70, 22)
	f.mine:SetPoint("TOPRIGHT", f.example, "BOTTOMRIGHT", 0, -6)
	f.mine.bg = Ink:Round(f.mine, "BACKGROUND", true, false)
	f.mine.bg:SetAllPoints()
	f.mine.bd = Ink:Round(f.mine, "BORDER", true, true)
	f.mine.bd:SetAllPoints()
	f.mine.text = Ink:Text(f.mine, F.semi, 10, C.accent, "CENTER")
	f.mine.text:SetPoint("CENTER")
	f.mine:SetScript("OnClick", function()
		Ink.db.dungeonAll = not Ink.db.dungeonAll
		M:PaintSidebar()
	end)
	self:BuildList(f)
	self.sidebar = f
end

-- 구분선 + 보스별 목록 (휠로 스크롤)
function M:BuildList(f)
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetColorTexture(1, 1, 1, 0.06)
	f.line:SetHeight(1)
	f.line:SetPoint("TOPLEFT", 12, -150)
	f.line:SetPoint("TOPRIGHT", -12, -150)
	local sf = CreateFrame("ScrollFrame", nil, f)
	sf:SetPoint("TOPLEFT", f.line, "BOTTOMLEFT", -4, -5)
	sf:SetPoint("BOTTOMRIGHT", -8, 10)
	local body = CreateFrame("Frame", nil, sf)
	body:SetSize(SB_W - 16, 10)
	sf:SetScrollChild(body)
	sf:EnableMouseWheel(true)
	-- 스크롤 범위는 내용 높이로 직접 계산 (블리자드 범위 값이 다시 그리기 직후엔 늦게 바뀌어서 잘 안 내려가던 문제)
	sf:SetScript("OnMouseWheel", function(self, d)
		local r = math.max(0, (body:GetHeight() or 0) - (self:GetHeight() or 0))
		self:SetVerticalScroll(math.max(0, math.min(r, self:GetVerticalScroll() - d * 60)))
	end)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, d) sf:GetScript("OnMouseWheel")(sf, d) end)
	f.sf, f.body = sf, body
	f.heads, f.rows = {}, {}
	f.empty = Ink:Text(body, F.sans, 11, C.dim, "CENTER")
	f.empty:SetPoint("TOP", 0, -30)
	f.empty:SetWidth(SB_W - 40)
	f.empty:SetWordWrap(true)
end

-------------------------------------------------------------------------------
-- 포에버: 던전 고르기 · 진행 경로 · 보기 방식 (내 직업 / 추천 / 전부)
-------------------------------------------------------------------------------
local RARE_C = { 0.78, 0.64, 1 }
local DOWN_C = { 0.44, 0.83, 0.6 }

-- 보스 이름: 게임 클라이언트가 알려 주는 이름(언어별 정확한 이름) → 없으면 자료의 한글 이름
local npcNames = {}
local function NpcName(id)
	if not id or id == 0 then return end
	local v = npcNames[id]
	if v then return v ~= false and v or nil end
	local db = Ink.db
	local loc = GetLocale and GetLocale() or "?"
	if db then
		db.npcNames = db.npcNames or {}
		if db.npcNames.loc ~= loc then db.npcNames = { loc = loc } end
		if db.npcNames[id] then npcNames[id] = db.npcNames[id] return db.npcNames[id] end
	end
	if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		local ok, data = pcall(C_TooltipInfo.GetHyperlink, "unit:Creature-0-0-0-0-" .. id .. "-0000000000")
		local line = ok and data and data.lines and data.lines[1]
		local t = line and plain(line.leftText)
		if type(t) == "string" and t ~= "" and not t:find("Creature%-") and t ~= _G.UNKNOWNOBJECT and t ~= _G.UNKNOWN then
			npcNames[id] = t
			if db then db.npcNames[id] = t end
			return t
		end
	end
end
local function BossName(b)
	return NpcName(b.npc) or b.name
end
M.BossName = BossName

-- 보기 방식: 만렙 전엔 "내 직업" 이 기본 (공략 BIS 는 만렙 기준이라)
local function ViewMode()
	if not FOREVER then return Ink.db.dungeonAll and "all" or "rec" end
	local v = Ink.db.dungeonView
	if v == "rec" or v == "class" or v == "all" then return v end
	return (UnitLevel("player") or 1) >= 60 and "rec" or "class"
end
M.ViewMode = ViewMode

-- 내 직업이 실제로 쓰는 장비인지: 방어구는 직업 주력 재질만 (망토 · 장신구 등은 통과), 무기 · 레벨 · 직업 제한은 툴팁의 빨간 글씨로
local ARMOR_OK = {
	WARRIOR = { [3] = true, [4] = true }, PALADIN = { [3] = true, [4] = true },
	HUNTER = { [2] = true, [3] = true }, SHAMAN = { [2] = true, [3] = true },
	ROGUE = { [2] = true }, DRUID = { [2] = true },
	MAGE = { [1] = true }, PRIEST = { [1] = true }, WARLOCK = { [1] = true },
}
local usableCache = {}
-- 한 번 받은 아이템 정보(이름 · 링크 · 요구 레벨)는 기억 → 나중에 게임이 그 정보를 내려놔도 다시 묻지 않는다
local basics = {}
local function ItemBasics(id)
	local m = basics[id]
	if m then return m[1], m[2], m[3] end
	local name, link, _, _, minLv = C_Item.GetItemInfo(id)
	if name then basics[id] = { name, link, minLv or 0 } end
	return name, link, minLv
end
local function ForMyClass(it)
	local _, cls = UnitClass("player")
	local key = it.id .. cls .. (UnitLevel("player") or 0)
	if usableCache[key] ~= nil then return usableCache[key] end
	local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(it.id)
	local ok = true
	if classID == 4 and loc ~= "INVTYPE_CLOAK" and subID and subID >= 1 and subID <= 4 then
		ok = (ARMOR_OK[cls] or {})[subID] and true or false
	end
	-- 무기: 내 직업이 아예 못 배우는 종류(도적의 지팡이 · 양손 도끼 등)는 정보를 받기 전에 뺀다
	if ok and classID == 2 and subID and ns.WEAPON_OK and ns.WEAPON_OK[cls] and not ns.WEAPON_OK[cls][subID] then
		ok = false
	end
	if not ok then usableCache[key] = false return false end
	if ok and ns.Score and ns.Score.Usable then
		local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(it.id)
		local good, u = pcall(ns.Score.Usable, ns.Score, "item:" .. it.id)
		if good and u == false then ok = false end
		if not cached then return ok end -- 아직 정보가 없으면 저장하지 않는다
	end
	usableCache[key] = ok
	return ok
end
M.ForMyClass = ForMyClass

-- 제작 장비도 후보로 (ForeverCrafts.lua · 게임 파일에서 뽑은 제작 주문 → 만들어지는 아이템)
--  요구 레벨은 아이템 정보를 받아야 알 수 있어서, 숙련(노란색 시작)으로 대충 레벨 창을 먼저 좁힌다 (요구 레벨 ≈ 숙련 / 6)
local CRAFT_PROF = { "대장기술", "가죽세공", "재봉술", "기계공학", "마법부여" }
M.CRAFT_PROF = CRAFT_PROF
-- 제작 주문 → 제조법 상인 (RecipeVendors.lua) : 상인 판매 제조법이면 어디서 · 얼마에 · 숙련 몇에
local recipeBySpell
function M:RecipeFor(spell)
	if not recipeBySpell then
		recipeBySpell = {}
		for item, e in pairs(ns.RECIPE_VENDORS or {}) do recipeBySpell[e[2]] = { item = item, prof = e[1], req = e[3], list = e[4] } end
	end
	return recipeBySpell[spell]
end

-- BIS 툴팁에 붙이는 제작 정보
function M:CraftTooltip(it, tt)
	tt = tt or GameTooltip
	local prof = CRAFT_PROF[it.craft] or "전문기술"
	tt:AddLine(" ")
	tt:AddLine("|cffFFF468FOA|r  제작 · " .. prof, 1, 1, 1)
	local price = ns.AHPrice and ns.AHPrice(it.id)
	local A = Ink.modules.AHPrice
	if price and A and A.Money then tt:AddDoubleLine("경매장 최저가", A.Money(price), 0.7, 0.72, 0.75, 1, 1, 1) end
	local r = it.spell and self:RecipeFor(it.spell)
	local P = Ink.modules.Professions
	if r then
		local x = P and P.PickVendor and P.PickVendor(r)
		local rname = C_Item.GetItemNameByID and C_Item.GetItemNameByID(r.item)
		if not rname and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, r.item) end
		Ink.TipLine(tt, "제조법: " .. (rname or "상인 판매 제조법") .. (r.req and r.req > 0 and ("  ·  " .. prof .. " " .. r.req .. " 필요") or ""), 0.96, 0.95, 0.9)
		if x and P.VendorText then
			local who, where, cost = P.VendorText(x)
			tt:AddDoubleLine(who or "상인", cost or "", 1, 0.82, 0.32, 1, 1, 1)
			if where and where ~= "" then tt:AddLine(where, 0.7, 0.72, 0.75) end
			tt:AddLine("클릭: 제조법 상인 위치를 지도에", 0.56, 0.58, 0.61)
		elseif r.list and #r.list > 0 then
			tt:AddLine("내 진영에서 파는 상인이 없어요", 0.7, 0.72, 0.75)
		end
	else
		tt:AddLine("제조법은 상인이 팔지 않아요", 0.96, 0.95, 0.9)
		tt:AddLine("상급자 · 드랍 · 퀘스트로 배워요", 0.7, 0.72, 0.75)
	end
	tt:AddLine("직접 못 만들면 경매장 · 제작 의뢰", 0.56, 0.58, 0.61)
end

function M:AddCrafts(pool, lvl)
	if Ink.db.bisCrafts == false or not ns.FOREVER_CRAFTS then return end
	self.craftById = self.craftById or {}
	for _, c in ipairs(ns.FOREVER_CRAFTS) do
		local id, prof, spell, triv = c[1], c[2], c[3], c[4]
		local est = triv / 6
		if est <= lvl + 6 and est >= lvl - 22 then
			local iid, _, _, loc, icon = C_Item.GetItemInfoInstant(id)
			local slot = iid and loc and EQUIP_EJ[loc]
			if slot then
				local it = self.craftById[id]
				if not it then
					it = { id = id, icon = icon, slot = slot, craft = prof, spell = spell }
					self.craftById[id] = it
				end
				if not it.name then
					local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(id)
					if cached then
						local name, link, q = C_Item.GetItemInfo(id)
						it.name, it.link, it.quality = name, link, q or 2
					end
				end
				if ForMyClass(it) then
					pool[slot] = pool[slot] or {}
					table.insert(pool[slot], it)
				end
			end
		end
	end
end

-- 퀘스트 보상 장비도 후보로 (ForeverQuestRewards.lua · AllTheThings MIT)
--  내 진영 · 내 직업 퀘스트만, 이미 끝낸 퀘스트는 빼고, 퀘스트 레벨로 대충 레벨 창을 좁힌다
function M:AddQuestRewards(pool, lvl)
	if Ink.db.bisQuests == false or not ns.FOREVER_QREWARDS then return end
	local fac = UnitFactionGroup("player")
	local facN = fac == "Horde" and 1 or (fac == "Alliance" and 2 or 0)
	local _, _, classID = UnitClass("player")
	local done = C_QuestLog.IsQuestFlaggedCompleted
	self.questById = self.questById or {}
	for _, e in ipairs(ns.FOREVER_QREWARDS) do
		local id, qid, qlvl, qfac, cls = e[1], e[2], e[3], e[4], e[9]
		local okFac = qfac == 0 or qfac == facN
		local okCls = #cls == 0
		if not okCls then for _, c in ipairs(cls) do if c == classID then okCls = true break end end end
		-- 필요 레벨이 지금 레벨보다 높으면 아직 받을 수 없어서 "지금 레벨 최고"에 넣지 않는다
		--  (예: 3625 마력이 깃든 아즈샤리트 퇴마검 · 45레벨부터 · 슬픔의 늪부터 14단계 연퀘)
		if okFac and okCls and qlvl <= lvl and qlvl >= lvl - 22 and not (done and done(qid)) then
			local iid, _, _, loc, icon = C_Item.GetItemInfoInstant(id)
			local slot = iid and loc and EQUIP_EJ[loc]
			if slot then
				local it = self.questById[id]
				if not it then
					it = { id = id, icon = icon, slot = slot, quest = qid, qlvl = qlvl, qmap = e[5], qx = e[6], qy = e[7], qnpc = e[8] }
					self.questById[id] = it
				end
				if not it.name then
					local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(id)
					if cached then
						local name, link, q = C_Item.GetItemInfo(id)
						it.name, it.link, it.quality = name, link, q or 2
					end
				end
				-- 던전 전리품 · 제작템과 같은 아이템이면 그쪽을 쓴다
				if ForMyClass(it) and not (self.craftById and self.craftById[id]) then
					pool[slot] = pool[slot] or {}
					table.insert(pool[slot], it)
				end
			end
		end
	end
	-- 던전 퀘스트 보상 (DungeonQuests.lua · 보상 목록) · 같은 규칙
	local added = {}
	for inst, list in pairs(ns.DUNGEON_QUESTS or {}) do
		for _, q in ipairs(list) do
			local qid, qlvl, qfac, cls = q[1], q[2] or 0, q[3] or 0, q[10] or {}
			local okFac = qfac == 0 or qfac == facN
			local okCls = #cls == 0
			if not okCls then for _, c in ipairs(cls) do if c == classID then okCls = true break end end end
			if okFac and okCls and q[12] ~= 1 and qlvl <= lvl and qlvl >= lvl - 22 and not (done and done(qid)) then
				for _, id in ipairs(q[9] or {}) do
					local iid, _, _, loc, icon = C_Item.GetItemInfoInstant(id)
					local slot = iid and loc and EQUIP_EJ[loc]
					if slot and not added[id] then
						local it = self.questById[id]
						if not it then
							it = { id = id, icon = icon, slot = slot, quest = qid, qlvl = qlvl, qmap = q[4], qx = q[5], qy = q[6], qnpc = q[7], dq = inst }
							self.questById[id] = it
						end
						if not it.name then
							local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(id)
							if cached then
								local name, link, qq = C_Item.GetItemInfo(id)
								it.name, it.link, it.quality = name, link, qq or 2
							end
						end
						local dup = false
						for _, x in ipairs(pool[slot] or {}) do if x.id == id then dup = true break end end
						if not dup and ForMyClass(it) and not (self.craftById and self.craftById[id]) then
							added[id] = true
							pool[slot] = pool[slot] or {}
							table.insert(pool[slot], it)
						end
					end
				end
			end
		end
	end
end

-- 월드 드랍 · 필드 몹 · 필드 희귀몹 · 상인 · 평판 · 던전 일반 몹 장비도 후보로 (ForeverSources.lua · wowf.io)
--  내 진영에서 얻을 수 있는 것만, 요구 레벨이 내 레벨 아래 15레벨 안 (요구 레벨이 없는 건 12레벨까지만)
function M:AddWorldSources(pool, lvl)
	if Ink.db.bisWorld == false or not ns.FOREVER_SOURCES then return end
	self.worldById = self.worldById or {}
	local have = {}
	for _, list in pairs(pool) do for _, it in ipairs(list) do have[it.id] = true end end
	for id, e in pairs(ns.FOREVER_SOURCES) do
		local rl = e.rl or 0
		local okLv = (rl == 0 and lvl <= 12) or (rl > 0 and rl <= lvl and rl >= lvl - 15)
		if okLv and not have[id] and ns.ItemSourceForMe(id) then
			local iid, _, _, loc, icon = C_Item.GetItemInfoInstant(id)
			local slot = iid and loc and EQUIP_EJ[loc]
			if slot then
				local it = self.worldById[id]
				if not it then
					it = { id = id, icon = icon, slot = slot, wsrc = true }
					self.worldById[id] = it
				end
				if not it.name then
					local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(id)
					if cached then
						local name, link, q = C_Item.GetItemInfo(id)
						it.name, it.link, it.quality = name, link, q or 2
					end
				end
				if ForMyClass(it) then
					have[id] = true
					pool[slot] = pool[slot] or {}
					table.insert(pool[slot], it)
				end
			end
		end
	end
end

-- 월드 출처 글자 (착용 시 귀속이면 경매장 시세도)
function M:WorldSourceText(it)
	local t = ns.ItemSourceText and ns.ItemSourceText(it.id) or "기타"
	local bind = select(14, C_Item.GetItemInfo(it.id))
	if bind == 2 then
		t = t .. "  ·  착용 시 귀속"
		local price = ns.AHPrice and ns.AHPrice(it.id)
		local A = Ink.modules.AHPrice
		if price and A and A.Money then t = t .. " · 경매장 " .. A.Money(price) end
	end
	return t
end

-- 이름을 아직 못 받은 퀘스트: 받는 중이면 "불러오는 중", 서버에 자료가 없으면 번호
M.questFail = {}
function M.QuestFallback(qid)
	return M.questFail[qid] and ("퀘스트 #" .. qid) or "퀘스트 이름 불러오는 중…"
end

-- 퀘스트 이름: 게임에 물어보고(처음엔 서버에서 늦게 옴) 받은 이름은 저장해 둔다 (다음 접속부터 바로)
local function QuestTitleOf(qid)
	if not qid then return end
	local db = Ink.db
	local loc = GetLocale and GetLocale() or "?"
	if db then
		db.questTitles = db.questTitles or {}
		if db.questTitles.loc ~= loc then db.questTitles = { loc = loc } end
	end
	local Q = Ink.modules.QuestMap
	local t = (Q and Q.QuestTitle and Q:QuestTitle(qid)) or (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid))
	if type(t) == "string" and t ~= "" then
		if db then db.questTitles[qid] = t end
		return t
	end
	if C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, qid) end
	return db and db.questTitles[qid] or nil
end

-- 던전 퀘스트 → 던전 이름 (날개가 여러 개인 곳은 공통 이름)
local DQ_COMMON = { [316] = "붉은십자군 수도원", [229] = "검은바위 첨탑", [230] = "혈투의 전장", [236] = "스트라솔름" }
local DQ_ORANGE = "FFB347"
function M:DQName(inst)
	if not inst then return end
	if DQ_COMMON[inst] then return DQ_COMMON[inst] end
	for key, v in pairs(M.DQ_INST or {}) do
		if v == inst then
			local d = FLoot(key)
			if d then return d.ko or d.en end
		end
	end
end

function M:QuestSourceText(it)
	local info = it.qmap and it.qmap > 0 and C_Map.GetMapInfo and C_Map.GetMapInfo(it.qmap)
	local inLog = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(it.quest)
	local dn = it.dq and self:DQName(it.dq)
	return (it.dq and (dn and ("|cff" .. DQ_ORANGE .. dn .. "|r 던전 퀘스트 · ") or "던전 퀘스트 · ") or "퀘스트 · ") .. (QuestTitleOf(it.quest) or M.QuestFallback(it.quest)) .. (inLog and " (진행 중)" or "") .. (info and ("  ·  " .. info.name) or "")
end

-- BIS 툴팁에 붙이는 퀘스트 정보
function M:QuestRewardTooltip(it, tt)
	tt = tt or GameTooltip
	tt:AddLine(" ")
	tt:AddLine("|cffFFF468FOA|r  " .. (it.dq and "던전 퀘스트 보상" or "퀘스트 보상"), 1, 1, 1)
	if it.dq then
		-- 어느 던전 퀘스트인지 한눈에 (주황 · 문 아이콘)
		local dn = self:DQName(it.dq) or "던전"
		tt:AddLine((M.TipIcon and M.TipIcon("Door", { 1, 0.70, 0.28 }) .. " " or "") .. "|cff" .. DQ_ORANGE .. dn .. "|r  |cffD9DBE0던전 퀘스트|r", 1, 1, 1)
	end
	Ink.TipLine(tt, (QuestTitleOf(it.quest) or M.QuestFallback(it.quest)) .. (it.qlvl and it.qlvl > 0 and ("  ·  " .. it.qlvl .. "레벨부터") or ""), 0.96, 0.95, 0.9)
	local Q = Ink.modules.QuestMap
	local giver = it.qnpc and it.qnpc > 0 and Q and Q.GiverName and Q:GiverName(it.qnpc)
	local info = it.qmap and it.qmap > 0 and C_Map.GetMapInfo and C_Map.GetMapInfo(it.qmap)
	if giver then tt:AddLine("주는 NPC: " .. giver, 1, 0.82, 0.32) end
	if info then tt:AddLine(info.name .. string.format("  %.1f, %.1f", it.qx or 0, it.qy or 0), 0.7, 0.72, 0.75) end
	local inLog = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(it.quest)
	if inLog then tt:AddLine("지금 진행 중인 퀘스트예요", 0.44, 0.83, 0.55)
	else
		-- 선행 퀘스트: 남은 개수와 맨 처음 받을 퀘스트 (누구 · 어디 · 몇 레벨)
		local chain = M.QuestChain and M.QuestChain(it.quest)
		if chain and #chain > 0 then
			local first = chain[1]
			local f = M.QuestStep and M.QuestStep(first) or {}
			-- 맨 처음 단계에 자리 정보가 없으면(자료에 없는 퀘스트) 자리를 아는 가장 앞 단계에서
			local where = f
			if not (f.npc or f.zone) and M.QuestStep then
				for _, q in ipairs(chain) do
					local w = M.QuestStep(q)
					if w.npc or w.zone then where = w break end
				end
			end
			local lv = f.lvl or where.lvl
			tt:AddLine("선행 퀘스트 " .. #chain .. "개를 먼저 해야 해요", 1, 0.62, 0.3)
			tt:AddLine("처음: " .. (f.title or ("#" .. first)) .. (lv and lv > 0 and ("  ·  " .. lv .. "레벨부터") or ""), 0.92, 0.92, 0.9)
			if where.npc or where.zone then
				tt:AddLine("      " .. (where.npc or "") .. ((where.npc and where.zone) and " · " or "") .. (where.zone or ""), 0.7, 0.72, 0.75)
			end
		elseif chain then
			tt:AddLine("선행 퀘스트 없이 바로 받을 수 있어요", 0.44, 0.83, 0.55)
		else
			tt:AddLine("선행 퀘스트가 있을 수 있어요", 0.56, 0.58, 0.61)
		end
	end
	if info then tt:AddLine("클릭: 퀘스트 주는 곳을 지도에", 0.56, 0.58, 0.61) end
end

-- 만렙 전 "레벨 최고템": 부위마다 지금 착용 가능한(요구 레벨 ≤ 내 레벨) 내 직업 장비를 FOA 점수 순으로 4개
--  두 손 무기를 드는 직업(도적 · 20레벨부터 전사 · 사냥꾼)은 한손 무기를 보조장비 칸에도 (보조 손 점수로)
function M:BuildLevelRanks(pool, lvl)
	self.levelRanks = {}
	self.levelPending = false
	local sc = ns.Score
	if not sc then return end
	local _, cls = UnitClass("player")
	local dual = cls == "ROGUE" or ((cls == "WARRIOR" or cls == "HUNTER") and lvl >= 20)
	local function Rank(list, off)
		local out, seen = {}, {}
		for _, it in ipairs(list) do
			if not seen[it.id] then
				seen[it.id] = true
				local name, link, minLv = ItemBasics(it.id)
				if not name then
					self.levelPending = true
					RequestItem(it.id)
				elseif (minLv or 0) <= lvl and ForMyClass(it) then
					local v = sc:Score(link or ("item:" .. it.id), off, FOREVER and ViewKey() or nil)
					if v == nil then self.levelPending = true; RequestItem(it.id) end
					if v and v > 0 then out[#out + 1] = { it = it, score = v, minLv = minLv } end
				end
			end
		end
		table.sort(out, function(a2, b2) return a2.score > b2.score end)
		return out
	end
	for slot, list in pairs(pool) do
		local src = list
		if slot == 11 and dual then
			src = {}
			for _, it in ipairs(list) do src[#src + 1] = it end
			for _, it in ipairs(pool[10] or {}) do
				local loc = select(4, C_Item.GetItemInfoInstant(it.id))
				if loc == "INVTYPE_WEAPON" then src[#src + 1] = it end
			end
		end
		local ranked = Rank(src, slot == 11 and dual)
		local l = {}
		for i = 1, math.min(4, #ranked) do
			l[i] = { rank = i - 1, slot = slot, it = ranked[i].it, lvlMode = true, score = ranked[i].score }
		end
		if #l > 0 then self.levelRanks[slot] = l end
	end
	if dual and not self.levelRanks[11] and pool[10] then
		local src = {}
		for _, it in ipairs(pool[10]) do
			if select(4, C_Item.GetItemInfoInstant(it.id)) == "INVTYPE_WEAPON" then src[#src + 1] = it end
		end
		local ranked = Rank(src, true)
		local l = {}
		for i = 1, math.min(4, #ranked) do l[i] = { rank = i - 1, slot = 11, it = ranked[i].it, lvlMode = true } end
		if #l > 0 then self.levelRanks[11] = l end
	end
	-- 아이템 → 순위 (전리품 칸 "추천" · 툴팁용. 두 칸에 다 있으면 높은 순위로)
	for _, l in pairs(self.levelRanks) do
		for _, r in ipairs(l) do
			local cur = self.ranks[r.it.id]
			if not cur or r.rank < cur.rank then self.ranks[r.it.id] = r end
		end
	end
	for _, r in pairs(self.ranks) do
		if r.it.inst then
			local c = self.rankCount[r.it.inst] or { bis = 0, alt = 0 }
			if r.rank == 0 then c.bis = c.bis + 1 else c.alt = c.alt + 1 end
			self.rankCount[r.it.inst] = c
		end
	end
	-- 정보가 덜 왔으면 잠시 뒤 다시 (아이템 도착 이벤트가 안 오는 경우 대비)
	if not self.levelPending then self.levelTries = 0 end
	if self.levelPending and not self.levelRetry and (self.levelTries or 0) < 10 then
		self.levelRetry = true
		self.levelTries = (self.levelTries or 0) + 1
		C_Timer.After(3, function()
			M.levelRetry = nil
			M.dirty = true
			pcall(M.PaintBis, M)
			pcall(M.PaintSidebar, M)
		end)
	end
end

-- 권장 레벨 색: 높음(빨강) · 조금 높음(주황) · 적정(초록) · 낮음(회색)
local function LevelColor(lo, hi)
	local lv = UnitLevel("player") or 1
	if lv < lo - 2 then return C.red, "높음" end
	if lv < lo then return C.orange, "조금 높음" end
	if lv <= hi then return DOWN_C, "적정" end
	return C.muted, "낮음"
end

-- 처치 기록 (캐릭터별 · 던전마다 · 마지막 처치 후 90분이 지나 다시 들어가면 새로 시작)
local function KillSet(key)
	local cdb = Ink.cdb
	if not (cdb and key) then return {} end
	cdb.dKills = cdb.dKills or {}
	local k = cdb.dKills[key]
	if not k then k = { t = 0 }; cdb.dKills[key] = k end
	return k
end
M.KillSet = KillSet

-- 이 보스를 잡았으면 앞 보스도 잡은 것 (앞 보스가 죽어야 나오는 보스)
--  스니드(643)는 스니드의 벌목기(642)가 부서져야 튀어나온다 · 벌목기는 전투 단위가 따로 없고 바로 이어져서 놓치기 쉽다
local KILL_IMPLIES = { [643] = { 642 } }

function M:MarkKill(key, npc)
	if not (key and npc) then return end
	local k = KillSet(key)
	local changed = false
	local function mark(n)
		if not k[n] then k[n], k.t = true, time(); changed = true end
		for _, m in ipairs(KILL_IMPLIES[n] or {}) do mark(m) end
	end
	mark(npc)
	if changed and self.sidebar and self.sidebar:IsShown() then self:PaintSidebar() end
end

-- 새 던전(가라앉은 도시 · 크롤도크 보루 등)은 게임 자료에 던전 번호 · 이름이 아직 없어서
--  들어가도 어느 던전인지 모른다 → 그 던전 보스를 보거나(대상 · 마우스) 던전 목록에서 직접 고르면
--  "이 던전 번호 = 이 던전"으로 기억해 두고 다음부터 바로 알아본다 (계정 공유)
function M:LearnInstance(key)
	if not (key and FLoot(key) and IsInInstance()) then return end
	local instID = select(8, GetInstanceInfo())
	if type(instID) ~= "number" or not Ink.db then return end
	Ink.db.instLearn = Ink.db.instLearn or {}
	Ink.db.instLearn[instID] = key
end

-- 아직 모르는 던전 안에서 그 던전 보스를 보면 배운다
local bossOwner
function M:LearnHere(unit)
	if self.hereKey or not IsInInstance() or self:MatchInstance() then return end
	local ok, guid = pcall(UnitGUID, unit)
	guid = ok and plain(guid)
	if type(guid) ~= "string" then return end
	local npc = tonumber((select(6, strsplit("-", guid))))
	if not npc then return end
	if not bossOwner then
		bossOwner = {}
		for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
			if not d.soon then
				for _, b in ipairs(d.bosses or {}) do if b[3] then bossOwner[b[3]] = d.key end end
			end
		end
	end
	local key = bossOwner[npc]
	if not key then return end
	self:LearnInstance(key)
	self.lastToast = nil
	self:OnForeverEnter()
end

-- 날개가 여러 개인 던전 (붉은십자군 수도원 네 날개 · 검은바위 첨탑 · 혈투의 전장 · 스트라솔름)
--  인스턴스 번호와 이름이 같아서 아래 순서로 날개를 가린다. 1~4 는 "확실", 그래도 모르면 추측
--   1) 던전 지도 층 번호 (그 층을 쓰는 날개가 하나뿐일 때 · 묘지 302 · 도서관 303 · 무기고 304 · 대성당 305)
--   2) 던전 찾기 번호 (GetInstanceInfo 10번째)
--   3) 이번 방문에서 본 그 날개 보스 (마우스를 올리거나 대상으로 잡으면)
--   4) 예전에 확실히 알았던 자리 근처 (확실할 때마다 지도 위 내 자리를 기억해 둔다)
--   추측: 마지막에 고른 날개 → 레벨  (예전엔 "배운 자리"가 인스턴스 번호로 저장돼 다른 날개에서도 그대로 쓰였다)
local floorKey
local function KeyByFloor(ui)
	if not ui then return end
	if not floorKey then
		floorKey = {}
		for key, list in pairs(ns.DUNGEON_MAPS and ns.DUNGEON_MAPS.floors or {}) do
			for _, u in ipairs(list) do
				if floorKey[u] == nil then floorKey[u] = key elseif floorKey[u] ~= key then floorKey[u] = false end
			end
		end
	end
	local k = floorKey[ui]
	return k and FLoot(k) and k or nil
end
local LFG_WING = { [18] = "sm_gy", [165] = "sm_lib", [163] = "sm_arm", [164] = "sm_cath" }
M.visit = 0 -- 인스턴스에 들어올 때마다 +1 (본 보스 · 직접 고른 날개는 이번 방문에만)

local function PlayerSpot()
	local ui = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not ui then return end
	local ok, p = pcall(C_Map.GetPlayerMapPosition, ui, "player")
	local x, y
	if ok and p then x, y = p:GetXY() end
	return ui, x, y
end
M.PlayerSpot = PlayerSpot

-- 확실히 아는 날개면 지금 자리를 기억 (다음엔 위치만으로 가린다)
function M:RememberWingSpot(key)
	local ui, x, y = PlayerSpot()
	if not (key and ui and x and y and x > 0 and y > 0 and Ink.db) then return end
	Ink.db.wingSpots = Ink.db.wingSpots or {}
	local list = Ink.db.wingSpots[ui] or {}
	Ink.db.wingSpots[ui] = list
	for _, sp in ipairs(list) do
		if math.abs(sp[1] - x) < 0.02 and math.abs(sp[2] - y) < 0.02 then sp[3] = key return end
	end
	list[#list + 1] = { math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000, key }
	while #list > 80 do table.remove(list, 1) end
end
local function WingBySpot(ui, x, y, ok)
	local list = ui and x and y and Ink.db and Ink.db.wingSpots and Ink.db.wingSpots[ui]
	if not list then return end
	local best, bd
	for _, sp in ipairs(list) do
		if ok[sp[3]] then
			local d = (sp[1] - x) ^ 2 + (sp[2] - y) ^ 2
			if not bd or d < bd then best, bd = sp[3], d end
		end
	end
	if best and bd < 0.06 ^ 2 then return best end
end

-- 지금 들어와 있는 포에버 던전 · 확실한가 (두 번째 값)
function M:MatchInstance()
	if not IsInInstance() then return end
	local name, _, _, _, _, _, _, instID, _, lfg = GetInstanceInfo()
	local ui, px, py = PlayerSpot()
	local byFloor = KeyByFloor(ui)
	if byFloor then return byFloor, true end
	local list = ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}
	local byUi, cands = {}, {}
	for _, d in ipairs(list) do
		if not d.soon then
			local hit = (d.inst and d.inst == instID) or (name and (name == d.ko or name == d.en or name == d.groupKo))
			if d.ui and ui and d.ui == ui then byUi[#byUi + 1] = d; hit = true end
			if hit then cands[#cands + 1] = d end
		end
	end
	if #cands == 0 then
		-- 자료에 인스턴스 번호가 없는 던전: 그 던전 보스를 보고 배운 자리
		local learned = Ink.db and Ink.db.instLearn and instID and Ink.db.instLearn[instID]
		if learned and FLoot(learned) then return learned, true end
		return
	end
	if #byUi == 1 then return byUi[1].key, true end
	if #cands == 1 then return cands[1].key, true end
	local ok = {}
	for _, d in ipairs(cands) do ok[d.key] = true end
	local lk = type(lfg) == "number" and LFG_WING[lfg]
	if lk and ok[lk] then return lk, true end
	if self.wingVisit == self.visit and self.wingSeen and ok[self.wingSeen] then return self.wingSeen, true end
	local sp = WingBySpot(ui, px, py, ok)
	if sp then return sp, true end
	-- 추측
	local sel = Ink.cdb and Ink.cdb.fDungeon
	if sel and ok[sel] then return sel, false end
	local lv, best, bestD = UnitLevel("player") or 1, nil, 999
	for _, d in ipairs(cands) do
		local dist = math.abs((d.lo + d.hi) / 2 - lv)
		if dist < bestD then best, bestD = d.key, dist end
	end
	return best, false
end

-- 던전 안에서 보스를 보면: 날개가 여러 개인 던전이면 그 날개로 (이번 방문 동안 · 자리도 기억)
function M:SeeBoss(unit)
	if not IsInInstance() then return end
	local ok, guid = pcall(UnitGUID, unit)
	guid = ok and plain(guid)
	if type(guid) ~= "string" then return end
	local npc = tonumber((select(6, strsplit("-", guid))))
	if not npc then return end
	if not bossOwner then
		bossOwner = {}
		for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
			if not d.soon then
				for _, b in ipairs(d.bosses or {}) do if b[3] and b[3] > 0 then bossOwner[b[3]] = d.key end end
			end
		end
	end
	local key = bossOwner[npc]
	local d = key and FLoot(key)
	if not (d and d.group) then return end
	local cur = self:MatchInstance()
	local cd = cur and FLoot(cur)
	if not (cd and cd.group == d.group) then return end
	self:RememberWingSpot(key)
	if self.wingSeen == key and self.wingVisit == self.visit then return end
	self.wingSeen, self.wingVisit = key, self.visit
	if self.hereKey ~= key then
		self.hereKey = key
		self:OnForeverEnter()
		if self.boardOn and self.board and self.board:IsShown() then self:ShowBoard(self:ForeverCurrent()) end
	end
end

function M:SelectForever(key)
	if not FLoot(key) then return end
	if Ink.cdb then Ink.cdb.fDungeon = key end
	self.showing = key
	-- 직접 고른 던전은 이번 방문 동안만 (다른 날개 · 다른 던전에 들어오면 실제 자리로)
	self.manualIn = IsInInstance() and { name = (GetInstanceInfo()), visit = self.visit } or nil
	-- 모르는 던전 안에서 직접 고르면: 여기가 그 던전이라고 배운다 (처치 체크 · 입장 알림이 바로 동작)
	if IsInInstance() and not self.hereKey and not self:MatchInstance() then
		self:LearnInstance(key)
		self.hereKey = key
	end
	if self.sidebar then
		self.sidebar.sf:SetVerticalScroll(0)
		if self.sidebar.menu then self.sidebar.menu:Hide() end
	end
	self:PaintSidebar()
end

-- 작은 버튼 (둥근 바탕 + 글자/아이콘)
local function Chip(parent, h)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(h or 20)
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(1, 1, 1, 0.04)
	b.bd = Ink:Round(b, "BORDER", true, true)
	b.bd:SetAllPoints()
	b.bd:SetVertexColor(1, 1, 1, 0.09)
	b.text = Ink:Text(b, F.semi, 10, C.soft, "CENTER")
	b.text:SetPoint("CENTER")
	return b
end

function M:BuildForeverTop(f)
	f.title:ClearAllPoints()
	-- 던전 이름 = 펼치기 버튼
	local pick = CreateFrame("Button", nil, f)
	pick:SetPoint("TOPLEFT", 8, -26)
	pick:SetPoint("TOPRIGHT", -8, -26)
	pick:SetHeight(28)
	pick.hl = Ink:Round(pick, "BACKGROUND", true, false)
	pick.hl:SetAllPoints()
	pick.hl:SetVertexColor(1, 1, 1, 0)
	f.title:SetParent(pick)
	f.title:SetPoint("LEFT", 8, 0)
	f.title:SetWidth(0)
	f.title:SetWordWrap(false)
	pick.chev = pick:CreateTexture(nil, "OVERLAY")
	pick.chev:SetTexture(Ink.icon("Chevron"))
	pick.chev:SetSize(14, 14)
	pick.chev:SetPoint("LEFT", f.title, "RIGHT", 6, -1)
	pick.chev:SetVertexColor(C.soft[1], C.soft[2], C.soft[3], 0.9)
	pick:SetScript("OnEnter", function(self) self.hl:SetVertexColor(1, 1, 1, 0.05) end)
	pick:SetScript("OnLeave", function(self) self.hl:SetVertexColor(1, 1, 1, 0) end)
	pick:SetScript("OnClick", function() M:ToggleMenu() end)
	f.pick = pick
	-- 권장 레벨 (내 레벨 기준 색)
	f.lvl = Chip(f, 18)
	f.lvl:SetPoint("TOPRIGHT", -14, -7)
	f.lvl.text:SetFont(F.numR or F.semi, Ink:BoostSize(10), "")
	f.lvl:SetScript("OnEnter", function(self)
		if not self.tip then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:AddLine(self.tip, 1, 1, 1)
		GameTooltip:Show()
	end)
	f.lvl:SetScript("OnLeave", GameTooltip_Hide)
	-- 입구 길 안내
	f.entr = Chip(f, 18)
	f.entr:SetPoint("RIGHT", f.lvl, "LEFT", -5, 0)
	f.entr:SetWidth(44)
	f.entr.text:ClearAllPoints()
	f.entr.text:SetPoint("CENTER", 6, 0)
	f.entr.text:SetText("입구")
	f.entr.icon = f.entr:CreateTexture(nil, "OVERLAY")
	f.entr.icon:SetTexture(Ink.icon("MapPin"))
	f.entr.icon:SetSize(11, 11)
	f.entr.icon:SetPoint("RIGHT", f.entr.text, "LEFT", -3, 0)
	f.entr.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3])
	f.entr:SetScript("OnClick", function(self)
		local e = self.e
		if not e then return end
		-- 전역 길 안내 대신: 그 지역 지도를 열어 입구 표시에 물결
		local Map = Ink.modules.Map
		if Map and Map.FocusEntrance and Ink.db.mapEntrances ~= false then
			Map:FocusEntrance(M.showing, e[1])
		else
			Ink:OpenMap(e[1])
		end
	end)
	f.entr:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.09)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:AddLine("던전 입구 보기", 1, 1, 1)
		GameTooltip:AddLine("지역 지도에서 입구 표시가 반짝여요", 0.7, 0.72, 0.75)
		if self.where then GameTooltip:AddLine(self.where, 0.7, 0.72, 0.75) end
		GameTooltip:Show()
	end)
	f.entr:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0.04); GameTooltip:Hide() end)
	-- 보스 수 · 처치 진행 (오른쪽 클릭: 처치 기록 지우기)
	f.meta = CreateFrame("Button", nil, f)
	f.meta:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", 8, -2)
	f.meta:SetSize(SB_W - 120, 16)
	f.meta:RegisterForClicks("RightButtonUp")
	f.meta.text = Ink:Text(f.meta, F.sans, 10, C.muted, "LEFT")
	f.meta.text:SetPoint("LEFT")
	f.meta:SetScript("OnClick", function()
		if Ink.cdb and Ink.cdb.dKills and M.showing then Ink.cdb.dKills[M.showing] = nil end
		M:PaintSidebar()
	end)
	f.meta:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:AddLine("진행 경로", 1, 1, 1)
		GameTooltip:AddLine("보스를 잡으면 경로에 체크가 붙어요", 0.7, 0.72, 0.75)
		GameTooltip:AddLine("오른쪽 클릭: 처치 기록 지우기", 0.7, 0.72, 0.75)
		GameTooltip:Show()
	end)
	f.meta:SetScript("OnLeave", GameTooltip_Hide)
	-- 경로 접기/펼치기
	f.fold = CreateFrame("Button", nil, f)
	f.fold:SetSize(60, 16)
	f.fold:SetPoint("TOPRIGHT", pick, "BOTTOMRIGHT", -6, -2)
	f.fold.text = Ink:Text(f.fold, F.sans, 10, C.muted, "RIGHT")
	f.fold.text:SetPoint("RIGHT", -14, 0)
	f.fold.icon = f.fold:CreateTexture(nil, "OVERLAY")
	f.fold.icon:SetTexture(Ink.icon("Chevron"))
	f.fold.icon:SetSize(11, 11)
	f.fold.icon:SetPoint("RIGHT")
	f.fold:SetScript("OnClick", function()
		Ink.db.dRouteHide = not Ink.db.dRouteHide
		M:PaintSidebar()
	end)
	f.fold:SetScript("OnEnter", function(self) self.text:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
	f.fold:SetScript("OnLeave", function(self) self.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
	-- 진행 경로 그림
	local route = CreateFrame("Frame", nil, f)
	route:SetPoint("TOPLEFT", 16, -78)
	route:SetSize(SB_W - 32, 10)
	route.nodes, route.segs, route.chips = {}, {}, {}
	f.route = route
	-- 전문화 · 보기 방식
	f.pills = SpecPills(f, 20)
	f.seg = CreateFrame("Frame", nil, f)
	f.seg:SetSize(10, 22)
	f.seg.btns = {}
	for i, m in ipairs({ { "class", "내 직업" }, { "rec", "추천" }, { "all", "전부" } }) do
		local b = Chip(f.seg, 22)
		b.mode, b.label = m[1], m[2]
		b:SetScript("OnClick", function(self)
			Ink.db.dungeonView = self.mode
			M:PaintSidebar()
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			if self.mode == "class" then
				GameTooltip:AddLine("내 직업이 쓰는 장비", 1, 1, 1)
				GameTooltip:AddLine("주력 방어구 재질 · 쓸 수 있는 무기만", 0.7, 0.72, 0.75)
			elseif self.mode == "rec" then
				GameTooltip:AddLine("추천 (BIS · 대체)", 1, 1, 1)
				Ink.TipLine(GameTooltip, M:SourceLabel(), 0.7, 0.72, 0.75)
			else
				GameTooltip:AddLine("전리품 전부", 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		f.seg.btns[i] = b
	end
	f.spec = Ink:Text(f, F.semi, 10, C.text, "LEFT")
	f.spec:SetPoint("LEFT", f.pills, "RIGHT", 8, 0)
	f.spec:SetWidth(70)
	self:BuildMenu(f)
end

-- 던전 펼치기 목록 (레벨 순 · 구간별 · 날개는 묶음 이름과 함께)
local MENU_ROW, MENU_HEAD = 30, 22
function M:BuildMenu(f)
	local m = CreateFrame("Frame", nil, f)
	m:SetPoint("TOPLEFT", f.pick, "BOTTOMLEFT", 0, -4)
	m:SetPoint("BOTTOMRIGHT", -8, 8)
	m:SetFrameLevel(f:GetFrameLevel() + 30)
	m:EnableMouse(true)
	m:Hide()
	m.bg = Ink:Round(m, "BACKGROUND", false, false)
	m.bg:SetAllPoints()
	m.bg:SetVertexColor(0.045, 0.05, 0.064, 0.985)
	m.bd = Ink:Round(m, "BORDER", false, true)
	m.bd:SetAllPoints()
	m.bd:SetVertexColor(1, 1, 1, 0.1)
	local sf = CreateFrame("ScrollFrame", nil, m)
	sf:SetPoint("TOPLEFT", 6, -6)
	sf:SetPoint("BOTTOMRIGHT", -6, 6)
	local body = CreateFrame("Frame", nil, sf)
	body:SetSize(SB_W - 28, 10)
	sf:SetScrollChild(body)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, d)
		local r = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(math.max(0, math.min(r, self:GetVerticalScroll() - d * 60)))
	end)
	m.sf, m.body, m.rows, m.heads = sf, body, {}, {}
	m:SetScript("OnShow", function() f.pick.chev:SetRotation(math.pi) end)
	m:SetScript("OnHide", function() f.pick.chev:SetRotation(0) end)
	f.menu = m
end

function M:ToggleMenu()
	local f = self.sidebar
	if not (f and f.menu) then return end
	if f.menu:IsShown() then f.menu:Hide() return end
	self:PaintMenu(true)
	f.menu:Show()
end

local function MenuRow(body)
	local r = CreateFrame("Button", nil, body)
	r:SetSize(SB_W - 28, MENU_ROW)
	r.hl = Ink:Round(r, "BACKGROUND", true, false)
	r.hl:SetAllPoints()
	r.hl:SetVertexColor(1, 1, 1, 0)
	r.bar = r:CreateTexture(nil, "ARTWORK")
	r.bar:SetSize(2, 16)
	r.bar:SetPoint("LEFT", 2, 0)
	r.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	r.name = Ink:Text(r, F.semi, 12, C.text, "LEFT")
	r.name:SetPoint("LEFT", 12, 0)
	r.lvl = Ink:Text(r, F.numR or F.semi, 11, C.soft, "RIGHT")
	r.lvl:SetPoint("RIGHT", -10, 0)
	r.dot = r:CreateTexture(nil, "OVERLAY")
	r.dot:SetTexture(Ink.tex.disc)
	r.dot:SetSize(6, 6)
	r.dot:SetPoint("RIGHT", r.lvl, "LEFT", -8, 0)
	r.sub = Ink:Text(r, F.sans, 10, C.dim, "RIGHT")
	r.sub:SetPoint("RIGHT", r.dot, "LEFT", -6, 0)
	r:SetScript("OnEnter", function(self) if not self.soon then self.hl:SetVertexColor(1, 1, 1, 0.06) end end)
	r:SetScript("OnLeave", function(self) self.hl:SetVertexColor(1, 1, 1, self.sel and 0.035 or 0) end)
	r:SetScript("OnClick", function(self) if not self.soon then M:SelectForever(self.key) end end)
	return r
end

-- toSel: 처음 펼칠 때만 고른 던전 쪽으로 스크롤 (열어 둔 채 다시 그릴 때는 보던 자리 그대로)
function M:PaintMenu(toSel)
	local f = self.sidebar
	local m = f and f.menu
	if not m then return end
	local list = ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}
	local lv = UnitLevel("player") or 1
	local cur = self.showing
	local here = self:MatchInstance()
	local sections = {
		{ "초반", "13–30", function(d) return not d.raid and d.lo < 26 end },
		{ "중반", "29–46", function(d) return not d.raid and d.lo >= 26 and d.lo < 41 end },
		{ "후반", "41–60", function(d) return not d.raid and d.lo >= 41 end },
		{ "레이드", "60", function(d) return d.raid end },
	}
	for _, r in ipairs(m.rows) do r:Hide() end
	for _, h in ipairs(m.heads) do h:Hide() end
	local y, nr, nh, selY = 4, 0, 0, nil
	for _, sec in ipairs(sections) do
		local items = {}
		for _, d in ipairs(list) do if sec[3](d) then items[#items + 1] = d end end
		if #items > 0 then
			nh = nh + 1
			local h = m.heads[nh]
			if not h then
				h = CreateFrame("Frame", nil, m.body)
				h:SetSize(SB_W - 28, MENU_HEAD)
				h.t = Ink:Text(h, F.latinB or F.semi, 9, C.muted, "LEFT")
				h.t:SetPoint("BOTTOMLEFT", 12, 4)
				h.r = Ink:Text(h, F.sans, 9, C.dim, "LEFT")
				h.r:SetPoint("LEFT", h.t, "RIGHT", 6, 0)
				h.line = h:CreateTexture(nil, "ARTWORK")
				h.line:SetColorTexture(1, 1, 1, 0.06)
				h.line:SetHeight(1)
				h.line:SetPoint("LEFT", h.r, "RIGHT", 8, 0)
				h.line:SetPoint("RIGHT", -10, 0)
				m.heads[nh] = h
			end
			h.t:SetText(sec[1])
			h.r:SetText(sec[2])
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", 0, -y)
			h:Show()
			y = y + MENU_HEAD + 2
			for _, d in ipairs(items) do
				nr = nr + 1
				local r = m.rows[nr] or MenuRow(m.body)
				m.rows[nr] = r
				r.key, r.soon = d.key, d.soon
				r.sel = d.key == cur
				if d.group then
					r.name:SetText("|cff8E939B" .. d.groupKo .. "|r  " .. d.wing)
				else
					r.name:SetText(d.ko)
				end
				local col = LevelColor(d.lo, d.hi)
				r.lvl:SetText(d.lo == d.hi and tostring(d.lo) or (d.lo .. "–" .. d.hi))
				r.lvl:SetTextColor(col[1], col[2], col[3])
				local fit = not d.soon and lv >= d.lo - 1 and lv <= d.hi
				r.dot:SetShown(fit or d.key == here)
				local dc = d.key == here and C.accent or DOWN_C
				r.dot:SetVertexColor(dc[1], dc[2], dc[3])
				r.sub:SetText(d.soon and "개방 예정" or (d.key == here and "지금 여기" or ""))
				r.bar:SetShown(r.sel)
				r.hl:SetVertexColor(1, 1, 1, r.sel and 0.035 or 0)
				r:SetAlpha(d.soon and 0.42 or 1)
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", 0, -y)
				r:Show()
				if r.sel then selY = y end
				y = y + MENU_ROW
			end
			y = y + 4
		end
	end
	-- 열려 있는 동안 아이템 · 퀘스트 갱신으로 다시 그려도 스크롤이 고른 던전으로 튀지 않게 지금 자리를 지킨다
	local keep = m.sf:GetVerticalScroll() or 0
	m.body:SetHeight(y + 4)
	C_Timer.After(0, function()
		local range = m.sf:GetVerticalScrollRange() or 0
		local want = toSel and ((selY or 0) - 80) or keep
		m.sf:SetVerticalScroll(math.max(0, math.min(range, want)))
	end)
end

-- 진행 경로: 보스를 순서대로 뱀 모양(ㄹ자)으로 잇는다. 입구 → 1 → 2 … → 막보(해골)
--  처치한 보스 = 초록 체크 · 다음 보스 = 노란 테 · 내 추천템이 나오는 보스 = 노란 점
local RT_ROW = 54
-- 던전 퀘스트 시작 안내 (DungeonQuestNotes.lua): 좌표가 없는 퀘스트의 짧은 설명 · 근처 보스 · 보고하는 곳
local function DQNote(id) return ns.DUNGEON_QUEST_NOTES and ns.DUNGEON_QUEST_NOTES[id] end
M.DQNote = DQNote

local function RouteNode(route)
	local n = CreateFrame("Button", nil, route)
	n:SetSize(30, 30)
	n.glow = n:CreateTexture(nil, "BACKGROUND")
	n.glow:SetTexture(Ink.tex.glow)
	n.glow:SetSize(44, 44)
	n.glow:SetPoint("CENTER")
	n.glow:SetBlendMode("ADD")
	n.disc = n:CreateTexture(nil, "ARTWORK")
	n.disc:SetTexture(Ink.tex.disc)
	n.disc:SetSize(22, 22)
	n.disc:SetPoint("CENTER")
	n.ring = n:CreateTexture(nil, "OVERLAY")
	n.ring:SetTexture(Ink.tex.ring)
	n.ring:SetAllPoints(n.disc)
	n.num = Ink:Text(n, F.numR or F.semi, 10, C.text, "CENTER")
	n.num:SetPoint("CENTER", n.disc, "CENTER", 0, 0)
	n.icon = n:CreateTexture(nil, "OVERLAY", nil, 2)
	n.icon:SetSize(12, 12)
	n.icon:SetPoint("CENTER", n.disc, "CENTER")
	n.dot = n:CreateTexture(nil, "OVERLAY", nil, 3)
	n.dot:SetTexture(Ink.tex.disc)
	n.dot:SetSize(7, 7)
	n.dot:SetPoint("CENTER", n.disc, "TOPRIGHT", -2, -2)
	n.dot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	-- 이 보스 근처에서 시작하는 퀘스트가 있으면 왼쪽 위에 작은 느낌표
	n.qb = n:CreateTexture(nil, "OVERLAY", nil, 4)
	n.qb:SetTexture(Ink.icon("QuestBang"))
	n.qb:SetSize(11, 11)
	n.qb:SetPoint("CENTER", n.disc, "TOPLEFT", 1, -1)
	n.qb:Hide()
	n.label = Ink:Text(route, F.sans, 9, C.soft, "CENTER")
	n.label:SetWordWrap(true)
	if n.label.SetMaxLines then n.label:SetMaxLines(2) end
	n.label:SetJustifyV("TOP")
	local ag = n.glow:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0.15); a:SetToAlpha(0.55); a:SetDuration(1.1); a:SetSmoothing("IN_OUT")
	n.pulse = ag
	n:SetScript("OnClick", function(self) M:JumpToBoss(self.bi) end)
	n:SetScript("OnEnter", function(self)
		self.disc:SetSize(25, 25)
		M:BossTooltip(self, self.bi)
	end)
	n:SetScript("OnLeave", function(self)
		self.disc:SetSize(22, 22)
		GameTooltip:Hide()
	end)
	return n
end

local function Seg(route)
	local t = route:CreateTexture(nil, "BORDER")
	t:SetColorTexture(1, 1, 1, 1)
	return t
end

function M:BossTooltip(owner, bi)
	local data = self.showing and self:Scan(self.showing)
	local b = data and data.bosses[bi]
	if not b then return end
	local mode = ViewMode()
	local nAll, nCls, nRec = #b.items, 0, 0
	for _, it in ipairs(b.items) do
		if self.ranks[it.id] then nRec = nRec + 1 end
		if ForMyClass(it) then nCls = nCls + 1 end
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine((b.rare and ((b.kind or 1) >= 2 and "선택 · " or "희귀 · ") or (b.order and (b.order .. ". ") or "")) .. BossName(b), 1, 1, 1)
	if b.killed then GameTooltip:AddLine("처치함", DOWN_C[1], DOWN_C[2], DOWN_C[3]) end
	GameTooltip:AddDoubleLine("전리품", nAll .. "개", 0.7, 0.72, 0.75, 1, 1, 1)
	GameTooltip:AddDoubleLine("내 직업", nCls .. "개", 0.7, 0.72, 0.75, 1, 1, 1)
	if nRec > 0 then GameTooltip:AddDoubleLine("추천 (BIS · 대체)", nRec .. "개", 0.7, 0.72, 0.75, 1, 0.96, 0.41) end
	-- 이 근처에서 시작하는 퀘스트
	local nq = b.npc and self:QuestsNearBoss(self.showing)[b.npc]
	if nq and #nq > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("이 근처에서 시작하는 퀘스트", 0.89, 0.75, 0.48)
		for _, e in ipairs(nq) do
			local t = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(e.id)
			local nt = DQNote(e.id)
			GameTooltip:AddLine((e.state == "log" and (M.TipIcon("Wait", { 1, 0.96, 0.41 }) .. " ") or "|cffE3C07A!|r ") .. (t and t ~= "" and t or M.QuestFallback(e.id)), 0.92, 0.92, 0.9)
			if nt and nt[2] then Ink.TipLine(GameTooltip, "   " .. nt[2], 0.56, 0.58, 0.61) end
		end
	end
	GameTooltip:AddLine("클릭: 목록에서 이 보스로", 0.55, 0.57, 0.6)
	GameTooltip:Show()
end

function M:JumpToBoss(bi)
	local f = self.sidebar
	local y = f and f.headY and f.headY[bi]
	if not y then return end
	local range = f.sf:GetVerticalScrollRange() or 0
	f.sf:SetVerticalScroll(math.max(0, math.min(range, y)))
	local h = f.headFor and f.headFor[bi]
	if h and h.flash then h.flash:Stop(); h.flash:Play() end
end

-- 경로 그리기 → 높이 돌려줌
function M:PaintRoute(route, data, W, hidden)
	for _, n in ipairs(route.nodes) do n:Hide(); n.label:Hide() end
	for _, t in ipairs(route.segs) do t:Hide() end
	for _, c in ipairs(route.chips) do c:Hide() end
	if route.door then route.door:Hide() end
	if route.rareT then route.rareT:Hide() end
	if not data or hidden then route:SetHeight(1) return 0 end
	local main, rares = {}, {}
	for bi, b in ipairs(data.bosses) do
		if b.rare then rares[#rares + 1] = bi else main[#main + 1] = bi end
	end
	local n = #main
	local maxCols = math.max(3, math.floor(W / 72))
	local cols = math.min(maxCols, (n <= 4) and math.max(n, 1) or (n <= 12 and 4 or 5))
	if route.big then cols = math.min(maxCols, math.max(1, math.ceil(n / math.ceil(n / maxCols)))) end
	local colW = W / cols
	local PAD = 0
	local rowH = (cols >= 5) and (RT_ROW - 4) or RT_ROW
	local pos = {}
	for i = 1, n do
		local r = math.floor((i - 1) / cols)
		local c = (i - 1) % cols
		if r % 2 == 1 then c = cols - 1 - c end
		pos[i] = { x = PAD + colW * (c + 0.5), y = -(r * rowH + 13), r = r }
	end
	-- 다음 보스 = 순서대로 봤을 때 처음으로 안 잡은 보스 (지금 이 던전 안일 때만)
	local inside = self:MatchInstance() == self.showing
	local nextI
	for i = 1, n do
		if not data.bosses[main[i]].killed then nextI = i break end
	end
	local nseg = 0
	local px = Ink:Px(2)
	local function Line(x1, y1, x2, y2, done)
		nseg = nseg + 1
		local t = route.segs[nseg] or Seg(route)
		route.segs[nseg] = t
		t:ClearAllPoints()
		if y1 == y2 then
			t:SetPoint("TOPLEFT", route, "TOPLEFT", math.min(x1, x2), y1 + px / 2)
			t:SetSize(math.max(1, math.abs(x2 - x1)), px)
		else
			t:SetPoint("TOPLEFT", route, "TOPLEFT", x1 - px / 2, math.max(y1, y2))
			t:SetSize(px, math.max(1, math.abs(y2 - y1)))
		end
		if done then t:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3], 0.75) else t:SetVertexColor(1, 1, 1, 0.13) end
		t:Show()
	end
	local GAP = 13
	-- 입구 → 1번
	if n > 0 then
		if not route.door then
			route.door = route:CreateTexture(nil, "OVERLAY")
			route.door:SetTexture(Ink.icon("Door"))
			route.door:SetSize(12, 12)
		end
		route.door:ClearAllPoints()
		route.door:SetPoint("CENTER", route, "TOPLEFT", 6, pos[1].y)
		route.door:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
		route.door:Show()
		if pos[1].x - GAP > 14 then Line(13, pos[1].y, pos[1].x - GAP, pos[1].y, data.bosses[main[1]].killed) end
	end
	for i = 1, n - 1 do
		local a, b = pos[i], pos[i + 1]
		local done = data.bosses[main[i]].killed and data.bosses[main[i + 1]].killed
		if a.r == b.r then
			local dir = b.x > a.x and 1 or -1
			Line(a.x + dir * GAP, a.y, b.x - dir * GAP, b.y, done)
		else
			-- 줄 끝에서 바깥으로 돌아 다음 줄로 (ㄹ자)
			local right = a.r % 2 == 0
			local ex = right and (W - 3) or 3
			Line(a.x + (right and GAP or -GAP), a.y, ex, a.y, done)
			Line(ex, a.y, ex, b.y, done)
			Line(ex, b.y, b.x + (right and GAP or -GAP), b.y, done)
		end
	end
	local nearQ = self:QuestsNearBoss(self.showing)
	for i = 1, n do
		local bi = main[i]
		local b = data.bosses[bi]
		local nd = route.nodes[i] or RouteNode(route)
		route.nodes[i] = nd
		nd.bi = bi
		nd:ClearAllPoints()
		nd:SetPoint("CENTER", route, "TOPLEFT", pos[i].x, pos[i].y)
		local last = i == n and n > 1
		local isNext = inside and i == nextI
		local rec = false
		for _, it in ipairs(b.items) do if self.ranks[it.id] then rec = true break end end
		nd.dot:SetShown(rec and not b.killed)
		local nq = b.npc and nearQ[b.npc]
		nd.qb:SetShown(nq and #nq > 0 and true or false)
		if nq and #nq > 0 then
			local qc = nq.log and C.accent or C.gold
			nd.qb:SetVertexColor(qc[1], qc[2], qc[3])
		end
		nd.disc:SetVertexColor(0.07, 0.075, 0.09, 1)
		if b.killed then
			nd.disc:SetVertexColor(DOWN_C[1] * 0.22, DOWN_C[2] * 0.22, DOWN_C[3] * 0.22, 1)
			nd.ring:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3], 0.95)
			nd.icon:SetTexture(Ink.icon("Check")); nd.icon:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3]); nd.icon:Show()
			nd.num:SetText("")
		elseif last then
			local c = isNext and C.accent or C.red
			nd.ring:SetVertexColor(c[1], c[2], c[3], isNext and 1 or 0.75)
			nd.icon:SetTexture(Ink.icon("Skull")); nd.icon:SetVertexColor(c[1], c[2], c[3]); nd.icon:Show()
			nd.num:SetText("")
		else
			local c = isNext and C.accent or { 0.78, 0.8, 0.84 }
			nd.ring:SetVertexColor(c[1], c[2], c[3], isNext and 1 or 0.55)
			nd.icon:Hide()
			nd.num:SetText(i)
			nd.num:SetTextColor(c[1], c[2], c[3])
		end
		nd.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
		nd.glow:SetShown(isNext)
		if isNext then nd.pulse:Play() else nd.pulse:Stop() end
		nd:Show()
		nd.label:ClearAllPoints()
		nd.label:SetWidth(math.max(40, colW - 6))
		nd.label:SetPoint("TOP", route, "TOPLEFT", pos[i].x, pos[i].y - 14)
		nd.label:SetText(BossName(b))
		local lc = b.killed and C.dim or (isNext and C.text or C.soft)
		nd.label:SetTextColor(lc[1], lc[2], lc[3])
		nd.label:Show()
	end
	local rows = math.ceil(n / cols)
	local h = math.max(0, rows * rowH - 4)
	-- 희귀 · 선택 보스 (경로 아래 칩)
	if #rares > 0 then
		if not route.rareT then
			route.rareT = Ink:Text(route, F.sans, 9, C.muted, "LEFT")
			route.rareT:SetText("희귀 · 선택")
		end
		route.rareT:ClearAllPoints()
		route.rareT:SetPoint("TOPLEFT", route, "TOPLEFT", 0, -h - 4)
		route.rareT:Show()
		local x, y = route.rareT:GetStringWidth() + 8, h + 1
		for k, bi in ipairs(rares) do
			local b = data.bosses[bi]
			local c = route.chips[k]
			if not c then
				c = Chip(route, 18)
				c.dot = c:CreateTexture(nil, "OVERLAY")
				c.dot:SetTexture(Ink.tex.disc)
				c.dot:SetSize(5, 5)
				c.dot:SetPoint("LEFT", 7, 0)
				c.text:ClearAllPoints()
				c.text:SetPoint("LEFT", 16, 0)
				c.text:SetFont(F.sans, Ink:BoostSize(9), "")
				c:SetScript("OnClick", function(self) M:JumpToBoss(self.bi) end)
				c:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.09); M:BossTooltip(self, self.bi) end)
				c:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0.04); GameTooltip:Hide() end)
				route.chips[k] = c
			end
			c.bi = bi
			c.text:SetText(BossName(b))
			local dc = b.killed and DOWN_C or RARE_C
			c.dot:SetVertexColor(dc[1], dc[2], dc[3])
			c.text:SetTextColor(b.killed and C.dim[1] or C.soft[1], b.killed and C.dim[2] or C.soft[2], b.killed and C.dim[3] or C.soft[3])
			local w = math.ceil(c.text:GetStringWidth()) + 24
			c:SetWidth(w)
			if x + w > W and x > 0 then x, y = 0, y + 22 end
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", route, "TOPLEFT", x, -y)
			c:Show()
			x = x + w + 5
		end
		h = y + 18
	end
	route:SetHeight(math.max(1, h))
	-- 큰 던전 화면의 경로 틀은 왼쪽 위 한 점에만 붙어 있어 폭이 0 이었다 → 지도 없는 던전에서 경로가 안 보임
	if route.big then route:SetWidth(math.max(1, W)) end
	return h
end

-- 머리 부분 그리기 → 목록이 시작할 y 돌려줌
function M:PaintForeverTop(f, data)
	local d = data and data.d or FLoot(self.showing)
	f.tag:SetText(d and d.raid and "RAID LOOT" or "DUNGEON LOOT")
	f.title:SetText(d and d.ko or "던전")
	f.title:SetWidth(0)
	if f.title:GetStringWidth() > SB_W - 64 then f.title:SetWidth(SB_W - 64) end
	-- 레벨
	if d then
		local col, word = LevelColor(d.lo, d.hi)
		f.lvl.text:SetText(d.lo == d.hi and ("Lv " .. d.lo) or ("Lv " .. d.lo .. "–" .. d.hi))
		f.lvl.text:SetTextColor(col[1], col[2], col[3])
		f.lvl.bd:SetVertexColor(col[1], col[2], col[3], 0.35)
		f.lvl:SetWidth(math.ceil(f.lvl.text:GetStringWidth()) + 16)
		f.lvl.tip = "권장 " .. d.lo .. "–" .. d.hi .. " 레벨 · 지금 내 레벨에는 " .. word
		f.lvl:Show()
	else
		f.lvl:Hide()
	end
	local ep = d and ((Ink.modules.Map and Ink.modules.Map.EntrancePoint and Ink.modules.Map:EntrancePoint(d.key)) or d.entr)
	f.entr.e = ep
	f.entr.where = ep and C_Map.GetMapInfo and (C_Map.GetMapInfo(ep[1]) or {}).name
	f.entr:SetShown((ep and not self.boardOn) and true or false)
	-- 처치 표시
	local k = KillSet(self.showing)
	local nMain, nDown = 0, 0
	for _, b in ipairs(data and data.bosses or {}) do
		b.killed = b.npc and k[b.npc] or false
		if not b.rare then
			nMain = nMain + 1
			b.order = nMain
			if b.killed then nDown = nDown + 1 end
		end
	end
	local nRare = data and (#data.bosses - nMain) or 0
	local txt = "보스 " .. nMain .. (nRare > 0 and ("  ·  희귀 " .. nRare) or "")
	if nDown > 0 then txt = txt .. "  ·  |cff6FD39A처치 " .. nDown .. "/" .. nMain .. "|r" end
	f.meta.text:SetText(txt)
	local hidden = Ink.db.dRouteHide
	f.fold.text:SetText(hidden and "경로 보기" or "경로 접기")
	f.fold.icon:SetRotation(hidden and 0 or math.pi)
	f.fold.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
	f.fold:SetShown(not self.boardOn)
	local rh = self:PaintRoute(f.route, data, SB_W - 32, Ink.db.dRouteHide or self.boardOn)
	local y = 78 + (rh > 0 and (rh + 12) or 0)
	-- 전문화 · 보기 방식
	f.pills:ClearAllPoints()
	f.pills:SetPoint("TOPLEFT", 16, -y - 1)
	f.pills:Refresh()
	local mode = ViewMode()
	local cnt = { class = 0, rec = 0, all = 0 }
	for _, b in ipairs(data and data.bosses or {}) do
		for _, it in ipairs(b.items) do
			cnt.all = cnt.all + 1
			if self.ranks[it.id] then cnt.rec = cnt.rec + 1 end
			if ForMyClass(it) then cnt.class = cnt.class + 1 end
		end
	end
	local x = 0
	local a = C.accent
	for _, b in ipairs(f.seg.btns) do
		local on = b.mode == mode
		b.text:SetText(b.label .. "  " .. (cnt[b.mode] or 0))
		b.text:SetTextColor(on and a[1] or C.soft[1], on and a[2] or C.soft[2], on and a[3] or C.soft[3])
		b.bg:SetVertexColor(on and a[1] or 1, on and a[2] or 1, on and a[3] or 1, on and 0.1 or 0.03)
		b.bd:SetVertexColor(on and a[1] or 1, on and a[2] or 1, on and a[3] or 1, on and 0.55 or 0.08)
		local w = math.ceil(b.text:GetStringWidth()) + 16
		b:SetWidth(w)
		b:ClearAllPoints()
		b:SetPoint("LEFT", f.seg, "LEFT", x, 0)
		x = x + w + 4
	end
	f.seg:SetWidth(math.max(10, x - 4))
	f.seg:ClearAllPoints()
	f.seg:SetPoint("TOPRIGHT", -14, -y)
	local _, _, _, specName, class = SpecKey()
	local cr, cg, cb = ns.ClassTint(class)
	f.spec:SetText(specName or "")
	f.spec:SetTextColor(cr, cg, cb)
	f.spec:SetShown(SB_W - 32 - f.seg:GetWidth() - f.pills:GetWidth() > 60)
	y = y + 30
	f.line:ClearAllPoints()
	f.line:SetPoint("TOPLEFT", 12, -y)
	f.line:SetPoint("TOPRIGHT", -12, -y)
	if f.menu:IsShown() then self:PaintMenu() end
	return y
end

local function Head(body, i)
	local h = CreateFrame("Frame", nil, body)
	h:SetSize(SB_W - 16, HEAD_H)
	h.disc = h:CreateTexture(nil, "ARTWORK")
	h.disc:SetTexture(Ink.tex.disc)
	h.disc:SetSize(22, 22)
	h.disc:SetPoint("LEFT", 6, -2)
	h.disc:SetVertexColor(0.07, 0.075, 0.09, 1)
	h.ring = h:CreateTexture(nil, "OVERLAY")
	h.ring:SetTexture(Ink.tex.ring)
	h.ring:SetAllPoints(h.disc)
	h.num = Ink:Text(h, F.numR, 11, C.text, "CENTER")
	h.num:SetPoint("CENTER", h.disc, "CENTER", 0, 0)
	h.name = Ink:Text(h, F.semi, 13, C.text, "LEFT")
	h.name:SetPoint("LEFT", h.disc, "RIGHT", 10, 0)
	h.name:SetWidth(SB_W - 130)
	h.sum = Ink:Text(h, F.sans, 10, C.muted, "RIGHT")
	h.sum:SetPoint("RIGHT", -8, -2)
	-- 희귀 보스: 번호 대신 작은 점
	h.rdot = h:CreateTexture(nil, "OVERLAY", nil, 2)
	h.rdot:SetTexture(Ink.tex.disc)
	h.rdot:SetSize(6, 6)
	h.rdot:SetPoint("CENTER", h.disc, "CENTER")
	h.rdot:Hide()
	-- 경로에서 눌렀을 때 잠깐 빛나기
	h.glow = Ink:Round(h, "BACKGROUND", true, false)
	h.glow:SetAllPoints()
	h.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0)
	local ag = h:CreateAnimationGroup()
	local a1 = ag:CreateAnimation("Alpha")
	a1:SetTarget(h.glow); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.18); a1:SetOrder(1)
	local a2 = ag:CreateAnimation("Alpha")
	a2:SetTarget(h.glow); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.9); a2:SetOrder(2); a2:SetSmoothing("OUT")
	ag:SetScript("OnPlay", function() h.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.12) end)
	ag:SetScript("OnFinished", function() h.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0) end)
	h.flash = ag
	return h
end

local function Row(body)
	local r = CreateFrame("Button", nil, body)
	r:SetSize(SB_W - 16, ROW_H)
	r.hl = Ink:Round(r, "BACKGROUND", true, false)
	r.hl:SetAllPoints()
	r.hl:SetVertexColor(1, 1, 1, 0)
	r.bisBd = Ink:Round(r, "BORDER", true, true)
	r.bisBd:SetAllPoints()
	r.icon = ItemIcon(r, 30)
	r.icon:SetPoint("LEFT", 8, 0)
	r.badge = Badge(r)
	r.badge:SetPoint("RIGHT", -8, 0)
	r.name = Ink:Text(r, F.semi, 12, C.text, "LEFT")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -1)
	r.name:SetPoint("RIGHT", r.badge, "LEFT", -8, 0)
	r.sub = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
	r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 1)
	r.sub:SetPoint("RIGHT", r.badge, "LEFT", -8, 0)
	r:SetScript("OnEnter", function(self)
		self.hl:SetVertexColor(1, 1, 1, 0.05)
		if self.link or self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetItemByID(self.itemID) end
			GameTooltip:Show()
		end
	end)
	r:SetScript("OnLeave", function(self)
		self.hl:SetVertexColor(1, 1, 1, self.isBis and 0.04 or 0)
		GameTooltip:Hide()
	end)
	r:SetScript("OnClick", function(self)
		if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
	end)
	return r
end

function M:PaintSidebar()
	local f = self.sidebar
	if not f or not f:IsShown() then return end
	local jid = self.showing
	if self.sbFor ~= jid then self.sbFor, self.sbRetry = jid, 0 end
	local data = jid and self:Scan(jid)
	self:BuildRanks(jid)
	local mode = ViewMode()
	if FOREVER then
		self:PaintForeverTop(f, data)
	else
		self:PaintRetailTop(f, data, jid)
	end
	self:PaintList(f, data, mode)
	if self.boardOn then self:PaintBoard(data) end
	pcall(self.PaintQuests, self)
end

function M:PaintRetailTop(f, data, jid)
	local key, _, _, specName, class = SpecKey()
	local cr, cg, cb = ns.ClassTint(class)
	f.tag:SetText((self.isRaid and self.isRaid[jid]) and "RAID LOOT" or "DUNGEON LOOT")
	f.title:SetText(data and data.name or "던전")
	f.spec:SetText((UnitClass("player") or "") .. " · " .. (specName or ""))
	f.spec:SetTextColor(cr, cg, cb)
	f.pills:Refresh()
	f.example:SetText(FOREVER and (self:SourceLabel():gsub("\n", " · ")) or (self.isExample and "예시 순위 (BIS 자료 없음)" or ("BIS · " .. self.spec.src)))
	if f.lvl then
		f.lvl:SetText(data and data.lo and string.format("권장 %d–%d 레벨", data.lo, data.hi) or "")
	end
	local cnt = self.rankCount[jid] or { bis = 0, alt = 0 }
	f.nBis:SetText(cnt.bis)
	f.nAlt:SetText(cnt.alt)
	local all = Ink.db.dungeonAll
	f.mine.text:SetText(all and "전부 보기" or "내 장비만")
	local a = C.accent
	f.mine.bg:SetVertexColor(a[1], a[2], a[3], all and 0.02 or 0.1)
	f.mine.bd:SetVertexColor(a[1], a[2], a[3], all and 0.3 or 0.6)
end

function M:PaintList(f, data, mode)
	local a = C.accent
	local body = f.body
	f.headY, f.headFor = f.headY or {}, f.headFor or {}
	wipe(f.headY); wipe(f.headFor)
	for _, h in ipairs(f.heads) do h:Hide() end
	for _, r in ipairs(f.rows) do r:Hide() end
	local y, nh, nr = 0, 0, 0
	if data then
		for _, b in ipairs(data.bosses) do
			local list = {}
			local nb, na = 0, 0
			for _, it in ipairs(b.items) do
				local r = self.ranks[it.id]
				if r then if r.rank == 0 then nb = nb + 1 else na = na + 1 end end
				if mode == "all" or (mode == "rec" and r) or (mode == "class" and ForMyClass(it)) then list[#list + 1] = it end
			end
			table.sort(list, function(x, z)
				local rx, rz = self.ranks[x.id], self.ranks[z.id]
				local ax, az = rx and rx.rank or 9, rz and rz.rank or 9
				if ax ~= az then return ax < az end
				return (x.slot or 99) < (z.slot or 99)
			end)
			nh = nh + 1
			local h = f.heads[nh] or Head(body, nh)
			f.heads[nh] = h
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", 0, -y)
			f.headY[b.index], f.headFor[b.index] = y, h
			local done = b.killed and true or false
			if not FOREVER and C_EncounterJournal and C_EncounterJournal.IsEncounterComplete and b.id then
				local ok, v = pcall(C_EncounterJournal.IsEncounterComplete, b.id)
				done = ok and plain(v) and true or false
			end
			local col = done and C.green or (nb > 0 and a or (b.rare and RARE_C) or { 0.75, 0.77, 0.8 })
			h.ring:SetVertexColor(col[1], col[2], col[3], 1)
			h.num:SetText(FOREVER and (b.rare and "" or (b.order or "")) or b.index)
			h.num:SetTextColor(col[1], col[2], col[3])
			h.rdot:SetShown(b.rare and true or false)
			h.rdot:SetVertexColor(col[1], col[2], col[3])
			h.name:SetText(FOREVER and BossName(b) or b.name)
			local sum = (nb > 0 and ("BIS " .. nb) or "") .. ((nb > 0 and na > 0) and " · " or "") .. (na > 0 and ("대체 " .. na) or "")
			if sum == "" and FOREVER then sum = (#list > 0) and (#list .. "개") or (mode == "class" and "내 직업 없음" or "") end
			if b.rare and FOREVER then sum = ((b.kind or 1) >= 2 and "선택" or "희귀") .. (sum ~= "" and (" · " .. sum) or "") end
			h.sum:SetText(done and "처치함" or sum)
			h:SetAlpha((done or (FOREVER and #list == 0)) and 0.55 or 1)
			h:Show()
			y = y + HEAD_H
			for _, it in ipairs(list) do
				nr = nr + 1
				local row = f.rows[nr] or Row(body)
				f.rows[nr] = row
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -y)
				local r = self.ranks[it.id]
				row.itemID, row.link = it.id, it.link
				row.icon:Set(it.icon, it.quality, SLOT_GLYPH[it.slot or -1])
				local q = QCOL[it.quality or 1] or QCOL[1]
				row.name:SetText(it.name or (((self.sbRetry or 0) >= 40) and ("아이템 #" .. it.id .. " (마우스를 올려 보기)") or "불러오는 중…"))
				row.name:SetTextColor(q[1], q[2], q[3])
				local sub = it.slotText or SLOT_NAME[it.slot or -1] or ""
				if it.armor and it.armor ~= "" then sub = sub .. " · " .. it.armor end
				local cant = FOREVER and mode == "all" and not ForMyClass(it)
				if FOREVER and not it.slotText then
					local _, _, st = C_Item.GetItemInfoInstant(it.id)
					if st and st ~= "" and it.slot and it.slot ~= 1 and it.slot ~= 3 and it.slot ~= 12 and it.slot ~= 13 then sub = sub .. " · " .. st end
					if sub == "" then sub = st or "" end
				end
				if cant then sub = sub .. "  |cff8E939B· 내 직업 X|r" end
				row.sub:SetText(sub)
				row.badge:Set(r)
				row.isBis = r and r.rank == 0
				row.hl:SetVertexColor(1, 1, 1, row.isBis and 0.04 or 0)
				row.bisBd:SetVertexColor(a[1], a[2], a[3], row.isBis and 0.4 or 0)
				row:SetAlpha((done or cant) and 0.5 or 1)
				row:Show()
				y = y + ROW_H + 2
			end
			y = y + 6
		end
	end
	-- 포에버: 아이템 이름이 아직 안 온 게 있으면 잠깐씩 다시 (서버가 늦게 보내 준다)
	if FOREVER and data and data.missing > 0 and (self.sbRetry or 0) < 40 then
		self.sbRetry = (self.sbRetry or 0) + 1
		C_Timer.After(1.5, function()
			if self.sidebar and self.sidebar:IsShown() then self.dirty = true; self:PaintSidebar() end
		end)
	elseif data and data.missing == 0 then
		self.sbRetry = 0
	end
	f.empty:SetShown(nr == 0)
	local emptyText
	if not data or (data.d and data.d.soon) then
		local d = FOREVER and FLoot(self.showing)
		emptyText = (d and d.soon) and "아직 열리지 않은 던전이에요\n열리면 전리품이 여기 나와요" or "전리품 정보를 불러오는 중…"
	elseif mode == "all" then
		emptyText = "전리품 정보가 없어요"
	elseif mode == "class" then
		emptyText = "여기에는 내 직업이 쓰는 장비가 없어요\n(전부 보기에서 다른 아이템 확인)"
	else
		emptyText = FOREVER and "여기선 추천(BIS · 대체)템이 안 나와요\n(내 직업 · 전부 보기로 바꿔 보세요)" or "여기선 내 BIS · 대체템이 안 나와요\n(오른쪽 위 버튼으로 전부 보기)"
	end
	f.empty:SetText(emptyText)
	body:SetHeight(math.max(10, y))
	local maxS = math.max(0, y - (f.sf:GetHeight() or 0))
	if f.sf:GetVerticalScroll() > maxS then f.sf:SetVerticalScroll(maxS) end
end

-------------------------------------------------------------------------------
-- 포에버 던전 안: 지도(던전 지도가 없음) 대신 큰 던전 화면
--  왼쪽 = 크게 그린 진행 경로 · 다음 보스, 오른쪽 = 전리품 (지도 옆 칸을 그대로 안으로)
-------------------------------------------------------------------------------
function M:BuildBoard()
	local wm = WorldMapFrame
	local b = CreateFrame("Frame", "FOADungeonBoard", wm)
	b:SetPoint("CENTER", UIParent, "CENTER")
	b:SetSize(wm:GetWidth(), wm:GetHeight())
	-- 지도 창의 자식(ESC · M 으로 같이 닫히게)이지만, 던전 화면을 펴는 동안 지도 창을 투명하게 하므로
	--  지도 창 투명도는 물려받지 않는다 (안 그러면 던전 화면까지 같이 안 보였다)
	if b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(true) end
	-- 화면 밖으로 안 나가게 · 빈 곳을 끌어서 옮기기 (자리 기억)
	b:SetClampedToScreen(true)
	b:SetMovable(true)
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
	b:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local cx, cy = self:GetCenter()
		local ux, uy = UIParent:GetCenter()
		local k = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
		if cx and ux then Ink.db.boardPos = { cx * k - ux, cy * k - uy } end
		M:SizeBoard()
	end)
	b:SetFrameStrata("DIALOG")
	b:SetFrameLevel(20)
	b:EnableMouse(true)
	b:EnableMouseWheel(true)
	b:SetScript("OnMouseWheel", function() end)
	b:Hide()
	Panel(b)
	b.bg:SetVertexColor(0.03, 0.034, 0.045, 0.985)
	-- 아주 옅은 바닥 무늬 (가운데가 밝은 빛)
	b.shine = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.shine:SetTexture(Ink.tex.glow)
	b.shine:SetPoint("CENTER", b, "LEFT", 0, 0)
	b.shine:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.035)
	b.shine:SetBlendMode("ADD")
	b.tag = Ink:Text(b, F.latinB, 10, C.muted, "LEFT")
	b.tag:SetPoint("TOPLEFT", 28, -24)
	b.name = Ink:Text(b, F.bold, 24, C.text, "LEFT")
	b.name:SetPoint("TOPLEFT", b.tag, "BOTTOMLEFT", 0, -8)
	b.sub = Ink:Text(b, F.sans, 11, C.soft, "LEFT")
	b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 1, -8)
	-- 처치 진행 막대
	b.prog = Ink:Bar(b, 220, 3, DOWN_C, C.track)
	b.prog:SetPoint("TOPLEFT", b.sub, "BOTTOMLEFT", 0, -10)
	b.progT = Ink:Text(b, F.numR or F.semi, 10, C.muted, "LEFT")
	b.progT:SetPoint("LEFT", b.prog, "RIGHT", 10, 0)
	-- 닫기 · 지도 보기
	b.close = CreateFrame("Button", nil, b)
	b.close:SetSize(26, 26)
	b.close:SetPoint("TOPRIGHT", -12, -12)
	b.close.icon = b.close:CreateTexture(nil, "OVERLAY")
	b.close.icon:SetTexture(Ink.icon("Cross"))
	b.close.icon:SetSize(14, 14)
	b.close.icon:SetPoint("CENTER")
	b.close.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
	b.close:SetScript("OnEnter", function(self) self.icon:SetVertexColor(1, 1, 1) end)
	b.close:SetScript("OnLeave", function(self) self.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3]) end)
	b.close:SetScript("OnClick", function()
		-- 지도 창은 애드온 코드로 닫지 않는다 (지도 핀 오염 · 전투 중 막힘 원인). 판만 접고, 지도는 ESC · M 으로
		M.boardOff = true
		M:UpdateMap()
	end)
	b.map = Chip(b, 22)
	b.map:SetPoint("RIGHT", b.close, "LEFT", -8, 0)
	b.map.text:SetText("지도 보기")
	b.map:SetWidth(70)
	b.map:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.09) end)
	b.map:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0.04) end)
	b.map:SetScript("OnClick", function()
		M.boardOff = true
		M:UpdateMap()
	end)
	-- 경로 (크게: 배율로 키운다)
	b.route = CreateFrame("Frame", nil, b)
	b.route.big = true
	b.route.nodes, b.route.segs, b.route.chips = {}, {}, {}
	b.routeT = Ink:Text(b, F.latinB, 9, C.muted, "LEFT")
	b.routeT:SetText("ROUTE")
	-- 다음 보스 안내
	b.next = CreateFrame("Frame", nil, b)
	b.next:SetSize(300, 54)
	b.next.bg = Ink:Round(b.next, "BACKGROUND", false, false)
	b.next.bg:SetAllPoints()
	b.next.bg:SetVertexColor(1, 1, 1, 0.035)
	b.next.bd = Ink:Round(b.next, "BORDER", false, true)
	b.next.bd:SetAllPoints()
	b.next.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.35)
	b.next.k = Ink:Text(b.next, F.sans, 10, C.accent, "LEFT")
	b.next.k:SetPoint("TOPLEFT", 16, -11)
	b.next.t = Ink:Text(b.next, F.bold, 15, C.text, "LEFT")
	b.next.t:SetPoint("TOPLEFT", b.next.k, "BOTTOMLEFT", 0, -5)
	b.next.r = Ink:Text(b.next, F.sans, 11, C.soft, "RIGHT")
	b.next.r:SetPoint("RIGHT", -16, 0)
	b.hint = Ink:Text(b, F.sans, 10, C.dim, "LEFT")
	b.hint:SetPoint("BOTTOMLEFT", 28, 20)
	b.hint:SetText("보스를 누르면 오른쪽 목록이 그 보스로 · 잡으면 자동으로 체크 · 처치 기록은 오른쪽 위 \"보스 n\" 줄을 오른쪽 클릭해서 지우기")
	b:SetScript("OnHide", function() M.boardOn = nil; if M.FadeWorldMap then M.FadeWorldMap(false) end end)
	self.board = b
end

-- 던전 지도 (게임 파일의 던전 지도 타일 · 보스 위치는 게임의 던전 도감 표 · DungeonMaps.lua)
--  층이 여러 개면 위에 층 단추. 처음엔 다음 보스가 있는 층
local MAP_W, MAP_H = 1002, 668
function M:BoardFloors(key, data)
	local dm = ns.DUNGEON_MAPS
	local fl = dm and dm.floors and dm.floors[key]
	if not (fl and #fl > 0) then return end
	local withBoss, any = {}, false
	local nMain, nPos = 0, 0
	for _, u in ipairs(fl) do withBoss[u] = 0 end
	for _, x in ipairs(data.bosses) do
		local ps = x.npc and dm.pos[x.npc]
		if not x.rare then nMain = nMain + 1; if ps then nPos = nPos + 1 end end
		if ps and withBoss[ps[1]] then withBoss[ps[1]] = withBoss[ps[1]] + 1; any = true end
	end
	-- 보스 위치를 절반도 모르면(개편된 던전 등) 지도 대신 순서 그림
	if not any or nPos < math.max(1, nMain / 2) then return end
	local list = {}
	for _, u in ipairs(fl) do if withBoss[u] > 0 then list[#list + 1] = u end end
	return list
end

function M:PaintBoardMap(b, data, leftW, top, avail)
	local dm = ns.DUNGEON_MAPS
	b.dmap = b.dmap or self:BuildBoardMap(b)
	local mf = b.dmap
	local floors = self:BoardFloors(self.showing, data)
	if not floors then
		mf:Hide()
		for _, t in ipairs(mf.tabs) do t:Hide() end
		return
	end
	-- 고른 층: 직접 고른 것 → 다음 보스 층 → 첫 층
	local floor = mf.pick and mf.pickFor == self.showing and mf.pick or nil
	if not floor then
		for _, x in ipairs(data.bosses) do
			local ps = x.npc and dm.pos[x.npc]
			if ps and not x.killed and not x.rare then floor = ps[1] break end
		end
	end
	local okFloor = false
	for _, u in ipairs(floors) do if u == floor then okFloor = true end end
	if not okFloor then floor = floors[1] end
	-- 크기: 왼쪽 칸 폭에 맞추고 높이가 넘치면 줄이기
	local tabsH = #floors > 1 and 30 or 0
	local w = leftW
	local h = w * MAP_H / MAP_W
	if h > avail - tabsH - 70 then h = math.max(160, avail - tabsH - 70); w = h * MAP_W / MAP_H end
	local x0 = 28 + (leftW - w) / 2
	local oy = top + tabsH
	mf:ClearAllPoints()
	mf:SetPoint("TOPLEFT", b, "TOPLEFT", x0, -oy)
	mf:SetSize(w, h)
	mf:Show()
	-- 타일 (4 × 3, 256 단위 · 오른쪽 · 아래 끝은 잘라서)
	local ids = {}
	for id in (dm.tiles[floor] or ""):gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
	local k = w / MAP_W
	for r = 0, 2 do
		for c = 0, 3 do
			local t = mf.tiles[r * 4 + c + 1]
			local fid = ids[r * 4 + c + 1]
			local pw = math.min(256, MAP_W - c * 256)
			local ph = math.min(256, MAP_H - r * 256)
			if fid and pw > 0 and ph > 0 then
				t:SetTexture(fid, nil, nil, "TRILINEAR")
				t:SetTexCoord(0, pw / 256, 0, ph / 256)
				t:SetSize(pw * k, ph * k)
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", mf, "TOPLEFT", c * 256 * k, -r * 256 * k)
				t:Show()
			else
				t:Hide()
			end
		end
	end
	-- 게임에 던전 지도가 없는 곳: FOA 구조도
	self:PaintSketch(mf, floor, w, h)
	-- 층 단추
	for _, t in ipairs(mf.tabs) do t:Hide() end
	if #floors > 1 then
		local tx = 0
		local shownTabs = {}
		for i, u in ipairs(floors) do
			local t = mf.tabs[i]
			if not t then
				t = Chip(b, 22)
				t:SetScript("OnClick", function(self) mf.pick, mf.pickFor = self.floor, M.showing; M:PaintSidebar() end)
				mf.tabs[i] = t
			end
			t.floor = u
			local on = u == floor
			local cnt = 0
			for _, x in ipairs(data.bosses) do local ps = x.npc and dm.pos[x.npc]; if ps and ps[1] == u then cnt = cnt + 1 end end
			t.text:SetText(i .. "구역  ·  보스 " .. cnt)
			local a = C.accent
			t.text:SetTextColor(on and a[1] or C.soft[1], on and a[2] or C.soft[2], on and a[3] or C.soft[3])
			t.bg:SetVertexColor(on and a[1] or 1, on and a[2] or 1, on and a[3] or 1, on and 0.1 or 0.03)
			t.bd:SetVertexColor(on and a[1] or 1, on and a[2] or 1, on and a[3] or 1, on and 0.55 or 0.08)
			t:SetWidth(math.ceil(t.text:GetStringWidth()) + 18)
			t:Show()
			shownTabs[#shownTabs + 1] = t
			tx = tx + t:GetWidth() + 6
		end
		-- 오른쪽 끝에 맞춰 늘어놓는다 (왼쪽 "DUNGEON MAP" 글자와 안 겹치게)
		local cx = x0 + w - (tx - 6)
		for _, t in ipairs(shownTabs) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", b, "TOPLEFT", cx, -(top + 2))
			cx = cx + t:GetWidth() + 6
		end
	end
	-- 보스 핀 + 진행 선 (이 층에 있는 보스만, 순서대로)
	local inside = self:MatchInstance() == self.showing
	local nextB
	for _, x in ipairs(data.bosses) do if not x.rare and not x.killed then nextB = x break end end
	local pts = {}
	local np = 0
	for _, x in ipairs(data.bosses) do
		local ps = x.npc and dm.pos[x.npc]
		if ps and ps[1] == floor then
			np = np + 1
			local nd = mf.pins[np] or RouteNode(mf)
			mf.pins[np] = nd
			nd.bi = x.index
			nd:SetFrameLevel(mf:GetFrameLevel() + 10)
			nd:ClearAllPoints()
			nd:SetPoint("CENTER", mf, "TOPLEFT", ps[2] * w, -ps[3] * h)
			local isNext = inside and x == nextB
			nd.disc:SetVertexColor(0.05, 0.055, 0.07, 0.95)
			nd.dot:Hide()
			if x.killed then
				nd.disc:SetVertexColor(DOWN_C[1] * 0.25, DOWN_C[2] * 0.25, DOWN_C[3] * 0.25, 0.95)
				nd.ring:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3], 1)
				nd.icon:SetTexture(Ink.icon("Check")); nd.icon:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3]); nd.icon:Show()
				nd.num:SetText("")
			elseif x.rare then
				nd.ring:SetVertexColor(RARE_C[1], RARE_C[2], RARE_C[3], 0.9)
				nd.icon:Hide(); nd.num:SetText("·"); nd.num:SetTextColor(RARE_C[1], RARE_C[2], RARE_C[3])
			else
				local c = isNext and C.accent or { 0.92, 0.93, 0.95 }
				nd.ring:SetVertexColor(c[1], c[2], c[3], isNext and 1 or 0.85)
				nd.icon:Hide()
				nd.num:SetText(x.order or "")
				nd.num:SetTextColor(c[1], c[2], c[3])
				local rec = false
				for _, it in ipairs(x.items) do if self.ranks[it.id] then rec = true break end end
				nd.dot:SetShown(rec)
			end
			nd.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
			nd.glow:SetShown(isNext)
			if isNext then nd.pulse:Play() else nd.pulse:Stop() end
			nd.label:ClearAllPoints()
			nd.label:SetWidth(110)
			nd.label:SetPoint("TOP", mf, "TOPLEFT", ps[2] * w, -ps[3] * h - 14)
			nd.label:SetText(BossName(x))
			local lc = x.killed and C.dim or (isNext and C.accent or C.text)
			nd.label:SetTextColor(lc[1], lc[2], lc[3])
			nd.label:Show()
			nd:Show()
			if not x.rare then pts[#pts + 1] = { ps[2] * w, -ps[3] * h, x.killed, npc = x.npc } end
		end
	end
	for i = np + 1, #mf.pins do mf.pins[i]:Hide(); mf.pins[i].label:Hide() end
	-- 진행 선: 입구 → 1번 → 2번 … 통로를 따라 꺾이고(DungeonRoutes.lua) 가운데에 진행 방향 화살표
	self:PaintRouteLines(mf, floor, pts, w, h, data)
	return oy, h
end

-- 진행 선 그리기
--  via[npc] = 그 보스로 가는 길의 꺾이는 점들 (같은 층의 앞 보스 · 입구에서 출발, 다른 층에서 오면 첫 점이 도착 지점)
function M:PaintRouteLines(mf, floor, pts, w, h, data)
	for _, l in ipairs(mf.lines) do l:Hide() end
	for _, a in ipairs(mf.arrows or {}) do a:Hide() end
	if mf.entr then mf.entr:Hide(); mf.entrLabel:Hide() end
	if not mf.CreateLine then return end
	local R = ns.DUNGEON_ROUTES and ns.DUNGEON_ROUTES[self.showing] or {}
	local via = R.via or {}
	local sk = ns.DUNGEON_SKETCH and ns.DUNGEON_SKETCH[floor]
	-- 입구 (이 층에 있을 때)
	local entr
	if R.entr and R.entr[1] == floor then entr = { R.entr[2] / 100, R.entr[3] / 100 }
	elseif sk and sk.entr then entr = sk.entr end
	local firstMain
	for _, x in ipairs(data.bosses) do if not x.rare then firstMain = x break end end
	local nl, na = 0, 0
	local A = C.accent
	local function seg(x1, y1, x2, y2, done)
		nl = nl + 1
		local l = mf.lines[nl]
		if not l then l = mf:CreateLine(nil, "ARTWORK", nil, 2); mf.lines[nl] = l end
		l:SetThickness(2)
		l:SetStartPoint("TOPLEFT", mf, x1, y1)
		l:SetEndPoint("TOPLEFT", mf, x2, y2)
		if done then l:SetColorTexture(DOWN_C[1], DOWN_C[2], DOWN_C[3], 0.8) else l:SetColorTexture(A[1], A[2], A[3], 0.75) end
		l:Show()
	end
	local function arrow(x1, y1, x2, y2, done)
		local dx, dy = x2 - x1, y2 - y1
		local len = math.sqrt(dx * dx + dy * dy)
		if len < 34 then return end
		dx, dy = dx / len, dy / len
		local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
		local tipx, tipy = mx + dx * 5, my + dy * 5
		for _, sgn in ipairs({ 1, -1 }) do
			na = na + 1
			mf.arrows = mf.arrows or {}
			local l = mf.arrows[na]
			if not l then l = mf:CreateLine(nil, "ARTWORK", nil, 3); mf.arrows[na] = l end
			l:SetThickness(2)
			local bx, by = mx - dx * 4 - dy * 5 * sgn, my - dy * 4 + dx * 5 * sgn
			l:SetStartPoint("TOPLEFT", mf, bx, by)
			l:SetEndPoint("TOPLEFT", mf, tipx, tipy)
			if done then l:SetColorTexture(DOWN_C[1], DOWN_C[2], DOWN_C[3], 0.95) else l:SetColorTexture(A[1], A[2], A[3], 1) end
			l:Show()
		end
	end
	local function poly(list, done)
		-- 가장 긴 구간 하나에만 화살표 (너무 많으면 어지러워서)
		local best, bl = nil, 0
		for i = 1, #list - 1 do
			local a, b = list[i], list[i + 1]
			seg(a[1], a[2], b[1], b[2], done)
			local L = (b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2
			if L > bl then best, bl = i, L end
		end
		if best then arrow(list[best][1], list[best][2], list[best + 1][1], list[best + 1][2], done) end
	end
	local prev
	if entr and pts[1] and firstMain and pts[1].npc == firstMain.npc then prev = { entr[1] * w, -entr[2] * h } end
	for _, p in ipairs(pts) do
		local list = {}
		local v = p.npc and via[p.npc]
		if prev then list[1] = prev end
		if v then for i = 1, #v - 1, 2 do list[#list + 1] = { v[i] / 100 * w, -v[i + 1] / 100 * h } end end
		list[#list + 1] = { p[1], p[2] }
		if #list >= 2 then poly(list, p[3]) end
		prev = { p[1], p[2] }
	end
	-- 입구 표시 (구조도는 스스로 그린다)
	if entr and not sk then
		if not mf.entr then
			mf.entr = mf:CreateTexture(nil, "OVERLAY", nil, 2)
			mf.entr:SetTexture(Ink.icon("Door"))
			mf.entr:SetSize(16, 16)
			mf.entrLabel = Ink:Text(mf, F.semi, 10, C.accent, "CENTER")
			mf.entrLabel:SetText("입구")
		end
		mf.entr:ClearAllPoints()
		mf.entr:SetPoint("CENTER", mf, "TOPLEFT", entr[1] * w, -entr[2] * h)
		mf.entr:SetVertexColor(A[1], A[2], A[3], 1)
		mf.entr:Show()
		mf.entrLabel:ClearAllPoints()
		mf.entrLabel:SetPoint("TOP", mf.entr, "BOTTOM", 0, -1)
		mf.entrLabel:Show()
	end
end

-- FOA 구조도 그리기 (DungeonSketch.lua): 어두운 바탕 + 성벽 선 + 통로 + 방 · 물 + 이름 + 입구
function M:PaintSketch(mf, floor, w, h)
	local sk = ns.DUNGEON_SKETCH and ns.DUNGEON_SKETCH[floor]
	mf.sk = mf.sk or { tex = {}, lines = {}, text = {}, ntex = 0, nline = 0, ntext = 0 }
	local P = mf.sk
	for _, t in ipairs(P.tex) do t:Hide() end
	for _, l in ipairs(P.lines) do l:Hide() end
	for _, t in ipairs(P.text) do t:Hide() end
	if P.bg then P.bg:SetShown(sk ~= nil) end
	if P.door then P.door:SetShown(sk ~= nil) end
	if not sk then return end
	if not P.bg then
		P.bg = mf:CreateTexture(nil, "BACKGROUND", nil, -7)
		P.bg:SetAllPoints()
		P.grid = {}
	end
	P.bg:SetColorTexture(0.055, 0.062, 0.078, 1)
	P.bg:Show()
	local nt, nl, nx = 0, 0, 0
	local function Tex(layer, sub)
		nt = nt + 1
		local t = P.tex[nt]
		if not t then t = mf:CreateTexture(nil, layer or "BORDER", nil, sub or 0); P.tex[nt] = t end
		t:SetDrawLayer(layer or "BORDER", sub or 0)
		t:ClearAllPoints()
		t:SetVertexColor(1, 1, 1, 1)
		t:Show()
		return t
	end
	local function Line(x1, y1, x2, y2, th, r, g, b, a, sub)
		if not mf.CreateLine then return end
		nl = nl + 1
		local l = P.lines[nl]
		if not l then l = mf:CreateLine(nil, "BORDER", nil, 1); P.lines[nl] = l end
		l:SetDrawLayer("BORDER", sub or 1)
		l:SetThickness(th)
		l:SetColorTexture(r, g, b, a)
		l:SetStartPoint("TOPLEFT", mf, x1 * w, -y1 * h)
		l:SetEndPoint("TOPLEFT", mf, x2 * w, -y2 * h)
		l:Show()
	end
	local function Label(x, y, txt)
		nx = nx + 1
		local t = P.text[nx]
		if not t then t = Ink:Text(mf, F.semi, 9, C.muted, "CENTER"); P.text[nx] = t end
		t:ClearAllPoints()
		t:SetPoint("CENTER", mf, "TOPLEFT", x * w, -y * h)
		t:SetText(txt)
		t:SetTextColor(0.62, 0.65, 0.70)
		t:Show()
	end
	local k = w / 1002
	-- 성벽
	local o = sk.outline
	if o then
		for i = 1, #o - 3, 2 do Line(o[i], o[i + 1], o[i + 2], o[i + 3], math.max(2, 4 * k), 1, 1, 1, 0.14, 0) end
	end
	-- 통로 (두껍고 옅게 + 가운데 가는 선)
	for _, pth in ipairs(sk.paths or {}) do
		for i = 1, #pth - 3, 2 do
			Line(pth[i], pth[i + 1], pth[i + 2], pth[i + 3], math.max(4, 14 * k), 0.78, 0.80, 0.86, 0.10, 1)
			Line(pth[i], pth[i + 1], pth[i + 2], pth[i + 3], 1, 0.80, 0.83, 0.90, 0.22, 2)
		end
	end
	-- 방 · 물 (네모: 옅은 면 + 가는 테두리 / 원: 원판 + 고리 / 물: 푸른 면)
	for _, r in ipairs(sk.rooms or {}) do
		local x, y, rw, rh, name, shape = r[1], r[2], r[3], r[4], r[5], r[6]
		local fill = Tex("BORDER", 3)
		fill:SetPoint("TOPLEFT", mf, "TOPLEFT", x * w, -y * h)
		fill:SetSize(rw * w, rh * h)
		if shape == "o" then
			fill:SetTexture(Ink.tex.disc)
			fill:SetVertexColor(0.80, 0.82, 0.88, 0.12)
			local edge = Tex("BORDER", 4)
			edge:SetTexture(Ink.tex.ring)
			edge:SetPoint("TOPLEFT", mf, "TOPLEFT", x * w, -y * h)
			edge:SetSize(rw * w, rh * h)
			edge:SetVertexColor(0.80, 0.82, 0.88, 0.35)
		elseif shape == "w" then
			fill:SetColorTexture(0.30, 0.50, 0.72, 0.26)
		else
			fill:SetColorTexture(0.80, 0.82, 0.88, 0.09)
			local x2, y2 = x + rw, y + rh
			for _, e in ipairs({ { x, y, x2, y }, { x2, y, x2, y2 }, { x2, y2, x, y2 }, { x, y2, x, y } }) do
				Line(e[1], e[2], e[3], e[4], 1, 0.80, 0.83, 0.90, 0.30, 4)
			end
		end
		-- 이름: 네모 방은 안쪽 위, 원 · 물은 아래쪽
		if name then
			if shape == "o" or shape == "w" then Label(x + rw / 2, y + rh + 0.035, name) else Label(x + rw / 2, y + 0.035, name) end
		end
	end
	-- 입구
	if sk.entr then
		if not P.door then
			P.door = mf:CreateTexture(nil, "ARTWORK", nil, 1)
			P.door:SetTexture(Ink.icon("Door"))
		end
		P.door:SetSize(16, 16)
		P.door:ClearAllPoints()
		P.door:SetPoint("CENTER", mf, "TOPLEFT", sk.entr[1] * w, -sk.entr[2] * h)
		P.door:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.9)
		P.door:Show()
		Label(sk.entr[1], math.min(0.97, sk.entr[2] + 0.04), "입구")
	elseif P.door then
		P.door:Hide()
	end
	-- 구조도라는 표시
	Label(0.88, 0.05, "FOA 구조도 · 대략")
end

function M:BuildBoardMap(b)
	local mf = CreateFrame("Frame", nil, b)
	mf:SetFrameLevel(b:GetFrameLevel() + 2)
	mf.bd = Ink:Round(mf, "OVERLAY", false, true)
	mf.bd:SetAllPoints()
	mf.bd:SetVertexColor(1, 1, 1, 0.1)
	mf.tiles, mf.pins, mf.lines, mf.tabs = {}, {}, {}, {}
	for i = 1, 12 do mf.tiles[i] = mf:CreateTexture(nil, "BACKGROUND") end
	-- 아래쪽을 살짝 어둡게 (글자가 잘 보이게)
	mf.shade = mf:CreateTexture(nil, "BORDER")
	mf.shade:SetAllPoints()
	mf.shade:SetColorTexture(0, 0, 0, 0.18)
	mf:Hide()
	return mf
end

-- 던전 화면을 펴 두는 동안 뒤의 세계 지도는 안 보이게:
--  지도 창(왼쪽 정렬)과 던전 화면(가운데)이 자리가 달라 지도 가장자리가 옆으로 삐져나와 보였다.
--  지도 창은 애드온 코드로 닫지 않는다(오염) → 투명도만.
--  예전엔 지도 창 자체를 투명하게 하고 던전 화면만 "부모 투명도 무시"로 살렸는데, 포에버에선 그게 안 먹어서
--  던전 화면까지 같이 사라졌다 (0.65.30 · 0.65.38 "맵이 안 나온다") → 지도 창은 그대로 두고,
--  던전 화면을 뺀 지도 창의 자식 틀 · 그림만 하나씩 투명하게 했다가 닫을 때 원래 값으로 되돌린다
local wmFaded
local wmHidden = {}
local function FadeWorldMap(on)
	local wm = WorldMapFrame
	if not wm then return end
	on = on and true or false
	if on == (wmFaded or false) then return end
	wmFaded = on
	if on then
		wipe(wmHidden)
		local board = M.board
		for _, c in ipairs({ wm:GetChildren() }) do
			if c ~= board and c.GetAlpha and c.SetAlpha then
				wmHidden[c] = c:GetAlpha()
				pcall(c.SetAlpha, c, 0)
			end
		end
		for _, r in ipairs({ wm:GetRegions() }) do
			if r.GetAlpha and r.SetAlpha then
				wmHidden[r] = r:GetAlpha()
				pcall(r.SetAlpha, r, 0)
			end
		end
		-- 예전 방식 때문에 지도 창 자체가 투명하게 남아 있으면 되돌린다
		if (wm:GetAlpha() or 1) < 0.05 then pcall(wm.SetAlpha, wm, 1) end
	else
		for obj, a in pairs(wmHidden) do pcall(obj.SetAlpha, obj, a or 1) end
		wipe(wmHidden)
	end
end
M.FadeWorldMap = FadeWorldMap

function M:ShowBoard(key)
	if not self.board then self:BuildBoard() end
	if not self.sidebar then self:BuildSidebar() end
	local b, f = self.board, self.sidebar
	self.boardOn = true
	self.showing = key
	self:SizeBoard()
	b:Show()
	b:SetAlpha(1)
	FadeWorldMap(true)
	f:ClearAllPoints()
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(b:GetFrameLevel() + 10)
	f:SetPoint("TOPRIGHT", b, "TOPRIGHT", -14, -48)
	f:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -14, 14)
	f:SetScale(1)
	f:Show()
	f.sf:SetVerticalScroll(0)
	self:PaintSidebar()
end

-- 던전 화면 크기: 세계 지도보다 크게 (지도를 작게 써도 던전 지도는 크게) · 화면 밖으로는 안 나가게
function M:SizeBoard()
	local b, wm = self.board, WorldMapFrame
	if not (b and wm) then return end
	local k = (wm:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	local maxW, maxH = UIParent:GetWidth() * 0.94 / k, UIParent:GetHeight() * 0.9 / k
	local w = math.min(maxW, math.max(wm:GetWidth() or 0, 1240))
	local h = math.min(maxH, math.max(wm:GetHeight() or 0, 860))
	b:SetSize(w, h)
	-- 자리: 옮겨 둔 곳 (없으면 화면 가운데) · UIParent 기준이라 세계 지도가 어디 있든 화면 안에
	local pos = Ink.db.boardPos
	b:ClearAllPoints()
	b:SetPoint("CENTER", UIParent, "CENTER", (pos and pos[1] or 0) / k, (pos and pos[2] or 0) / k)
end

function M:HideBoard()
	self.boardOn = nil
	if self.board then self.board:Hide() end
	FadeWorldMap(false)
	if self.sidebar then self.sidebar:SetFrameStrata("HIGH") end
end

function M:PaintBoard(data)
	local b = self.board
	if not (b and b:IsShown() and data) then return end
	local d = data.d or FLoot(self.showing)
	b.tag:SetText(d and d.raid and "RAID" or "DUNGEON")
	b.name:SetText(d and d.ko or data.name or "")
	local nMain, nDown, nRare, nextB = 0, 0, 0, nil
	for _, x in ipairs(data.bosses) do
		if x.rare then nRare = nRare + 1 else
			nMain = nMain + 1
			if x.killed then nDown = nDown + 1 elseif not nextB then nextB = x end
		end
	end
	local col = d and LevelColor(d.lo, d.hi) or C.soft
	-- 날개를 아직 추측 중이면 표시 (보스를 보면 자동으로 바뀐다)
	local guess = d and d.group and self.showing == self.hereKey and self.hereSure == false
	b.sub:SetText(string.format("|cff%02x%02x%02x권장 %d–%d 레벨|r   ·   보스 %d%s%s", math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255),
		d and d.lo or 0, d and d.hi or 0, nMain, nRare > 0 and ("   ·   희귀 " .. nRare) or "",
		guess and "   ·   |cffFFB347날개 추측 중 · 보스를 보면 자동으로 · 오른쪽 이름 옆 ∨ 로 고르기|r" or ""))
	b.prog:SetMinMaxValues(0, math.max(1, nMain))
	b.prog:SetValue(nDown)
	b.progT:SetText(nDown >= nMain and nMain > 0 and "|cff6FD39A모두 처치!|r" or (nDown .. " / " .. nMain .. " 처치"))
	-- 경로: 왼쪽 칸 크기에 맞춰 배율을 고른다
	local bw, bh = b:GetWidth(), b:GetHeight()
	local leftW = math.max(260, bw - SB_W - 28 - 56)
	local top, bottom = 150, 96
	local avail = bh - top - bottom
	local oy, h
	-- 던전 지도 그림이 있으면 진짜 지도 위에 보스 위치 · 진행 선, 없으면 순서 그림
	local mapOy, mapH = self:PaintBoardMap(b, data, leftW, top, avail)
	if mapOy then
		self:PaintRoute(b.route, data, leftW, true)
		oy, h = mapOy, mapH
		b.routeT:SetText("DUNGEON MAP")
	else
		local s = math.max(1, math.min(1.6, leftW / 430))
		b.route:SetScale(s)
		local W = leftW / s
		h = self:PaintRoute(b.route, data, W, false) * s
		oy = top + math.max(0, (avail - h) / 2 - 10)
		b.route:ClearAllPoints()
		b.route:SetPoint("TOPLEFT", b, "TOPLEFT", 28 / s, -oy / s)
		b.routeT:SetText("ROUTE")
	end
	b.routeT:ClearAllPoints()
	-- 층 단추가 있으면 그 위로 (겹치지 않게)
	local tabsUp = mapOy and b.dmap and b.dmap.tabs[1] and b.dmap.tabs[1]:IsShown()
	b.routeT:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 28, tabsUp and -(top - 6) or (-oy + 14))
	b.shine:SetSize(leftW * 1.6, bh * 1.2)
	b.shine:ClearAllPoints()
	b.shine:SetPoint("CENTER", b, "TOPLEFT", 28 + leftW / 2, -oy - h / 2)
	-- 다음 보스
	if nextB then
		local nCls, nRec = 0, 0
		for _, it in ipairs(nextB.items) do
			if self.ranks[it.id] then nRec = nRec + 1 end
			if ForMyClass(it) then nCls = nCls + 1 end
		end
		b.next.k:SetText(nDown == 0 and "첫 보스" or "다음 보스")
		b.next.t:SetText((nextB.order and (nextB.order .. ".  ") or "") .. BossName(nextB))
		b.next.r:SetText("내 직업 " .. nCls .. (nRec > 0 and ("  ·  |cffFFF468추천 " .. nRec .. "|r") or ""))
		b.next:SetWidth(math.min(leftW, math.max(300, b.next.t:GetStringWidth() + b.next.r:GetStringWidth() + 70)))
		b.next:ClearAllPoints()
		b.next:SetPoint("TOPLEFT", b, "TOPLEFT", 28, -(oy + h + 22))
		b.next:Show()
	else
		b.next:Hide()
	end
end

-------------------------------------------------------------------------------
-- 던전 퀘스트 (DungeonQuests.lua · AllTheThings MIT): 던전 전리품 옆 칸
--  · 고른 던전의 퀘스트를 상태순으로 (진행 중 · 받을 수 있음 · 레벨 부족 · 선행 필요 · 완료)
--  · 마우스를 올리면 시작 NPC · 위치, 선행 퀘스트 순서, 보상, 경험치 · 돈(게임이 알려 주면)
--  · 클릭하면 시작 위치를 지도에
-------------------------------------------------------------------------------
local DQ_INST = {
	deadmines = 63, shadowfang = 64, ragefire = 226, blackfathom = 227, brd = 228, lbrs = 229, ubrs = 229,
	dm_east = 230, dm_west = 230, dm_north = 230, gnomeregan = 231, maraudon = 232, downs = 233, kraul = 234,
	strat_live = 236, strat_ud = 236, sunken = 237, stockade = 238, uldaman = 239, wailing = 240, zulfarrak = 241,
	scholo = 246, sm_gy = 316, sm_lib = 316, sm_arm = 316, sm_cath = 316, onyxia = 760,
	thanes = 3065, lordaeron = 2999, excavation = 2998, dalaran = 2959,
	drowned = 2970, kroldok = 3039,
}
M.DQ_INST = DQ_INST
-- 붉은십자군 수도원: 네 날개가 던전 번호 하나(316)를 같이 써서 모든 날개에 같은 퀘스트가 떴다
--  → AllTheThings 날개 묶음(묘지 · 도서관 · 무기고 · 대성당)과 퀘스트 목표 보스가 있는 날개로 나눈다
--  값: true = 이 날개 퀘스트, { 보스 이름 … } = 목표 일부만 이 날개 (빛의 이름으로! · 붉은십자군 수도원으로)
local SM_LOKSEY = { "사냥개조련사 록시", "Loksey", short = "사냥개조련사 록시" }
local SM_HEROD = { "헤로드", "Herod", short = "헤로드" }
local SM_CATH = { "모그레인", "화이트메인", "Mograine", "Whitemane", short = "모그레인 · 화이트메인" }
local DQ_WING = {
	sm_gy = { [1051] = true, [1113] = true },
	sm_lib = { [1049] = true, [1050] = true, [1951] = true, [1160] = true, [1113] = true, [1048] = SM_LOKSEY, [1053] = SM_LOKSEY },
	sm_arm = { [1113] = true, [1048] = SM_HEROD, [1053] = SM_HEROD },
	sm_cath = { [1113] = true, [1048] = SM_CATH, [1053] = SM_CATH },
}
M.DQ_WING = DQ_WING
local DQ_W = 300
-- 화면 오른쪽 끝까지 남은 폭 (frame 단위)
local function RoomRight(frame, of)
	local fs = frame:GetEffectiveScale()
	local ur, r = UIParent:GetRight(), of:GetRight()
	if not (ur and r and fs and fs > 0) then return 9999 end
	local sr = ur * UIParent:GetEffectiveScale() / fs
	return sr - r * of:GetEffectiveScale() / fs
end
M.RoomRight = RoomRight
local DQ_ROW = 46

-- 툴팁 글자 속 작은 아이콘 (게임 툴팁 글꼴엔 ✓ ▸ 같은 기호가 없어서 네모로 깨졌다)
local function TipIcon(name, rgb)
	return string.format("|T%s:12:12:0:-1:64:64:0:64:0:64:%d:%d:%d|t", Ink.icon(name),
		math.floor(rgb[1] * 255), math.floor(rgb[2] * 255), math.floor(rgb[3] * 255))
end
M.TipIcon = TipIcon

local dqIndex, qdbIndex
-- 퀘스트 → 선행 목록 (던전 퀘스트 자료 + 전체 퀘스트 시작 자료)
local function PreOf(id)
	if not dqIndex then
		dqIndex = {}
		for _, list in pairs(ns.DUNGEON_QUESTS or {}) do for _, q in ipairs(list) do dqIndex[q[1]] = q end end
	end
	local q = dqIndex[id]
	if q then return q[8], q end
	if not qdbIndex then
		qdbIndex = {}
		for _, r in ipairs(ns.QUEST_DB or {}) do qdbIndex[r[1]] = r end
	end
	local r = qdbIndex[id]
	if r then return r[7], nil, r end
	return {}
end

local function QTitle(id) return QuestTitleOf(id) end
local function QDone(id) return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) end
local function QInLog(id)
	if C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id) end
	return C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end
local function NpcOf(id)
	local Q = Ink.modules.QuestMap
	return id and id > 0 and Q and Q.GiverName and Q:GiverName(id) or nil
end
local function ZoneName(map)
	local info = map and map > 0 and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return info and info.name
end
-- 시작 아이템 이름 (못 불러왔으면 요청만)
local function ItemName(id)
	if not id or id <= 0 then return end
	local name = C_Item.GetItemInfo(id)
	if not name and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
	return name
end
-- 아이템이 나오는 곳: 보스 이름 · 던전 몹
local function DropFrom(q)
	if (q[11] or 0) == -1 then return "던전 몹" end
	return NpcOf(q[11]) or ((q[11] or 0) > 0 and "던전 보스" or nil)
end
-- 위치 종류 (DungeonQuests.lua 14번째): 0 주는 곳 · 1 보고하는 곳 · 2 던전 안 NPC · 3 던전 안 물체 · 4 던전 드랍
local KIND_TURNIN, KIND_IN_NPC, KIND_IN_OBJ, KIND_DROP = 1, 2, 3, 4

-- 선행 퀘스트를 처음부터 순서대로 (깊이 20까지, 갈래는 모두 · 긴 연퀘도 처음까지)
local function Chain(id, out, seen, depth)
	if depth > 20 then return end
	for _, p in ipairs((PreOf(id))) do
		if not seen[p] then
			seen[p] = true
			-- 이미 끝낸 선행의 앞 퀘스트들은 당연히 끝났으니 더 거슬러 올라가지 않는다
			if not QDone(p) then Chain(p, out, seen, depth + 1) end
			out[#out + 1] = p
		end
	end
end

-- 연결 퀘스트: 다른 NPC 에게 안내만 하는 퀘스트 (선택 · 안 해도 다음 퀘스트를 받을 수 있다)
local function IsCrumb(id) return ns.DUNGEON_BREADCRUMB and ns.DUNGEON_BREADCRUMB[id] end
M.IsCrumb = IsCrumb

-- BIS 툴팁용: 아직 안 끝낸 선행 퀘스트 (처음부터 순서대로 · 연결 퀘스트 빼고)
function M.QuestChain(id)
	local all, out = {}, {}
	Chain(id, all, {}, 0)
	for _, p in ipairs(all) do if not QDone(p) and not IsCrumb(p) then out[#out + 1] = p end end
	return out
end
-- 퀘스트 한 단계 정보: 이름 · 필요 레벨 · 주는 NPC · 지역
function M.QuestStep(id)
	local _, dq, qr = PreOf(id)
	local npc = dq and NpcOf(dq[7]) or (qr and NpcOf(qr[14]))
	local zone = ZoneName(dq and dq[4] or (qr and qr[2] and qr[2][1]))
	local lvl = dq and dq[2] or (qr and qr[3])
	return { title = QTitle(id), npc = npc, zone = zone, lvl = lvl }
end

-- 내가 받을 수 있는 퀘스트 목록 + 상태
function M:DungeonQuestList(key)
	local inst = DQ_INST[key or ""]
	local list = inst and ns.DUNGEON_QUESTS and ns.DUNGEON_QUESTS[inst]
	if not list then return {} end
	local wing = DQ_WING[key or ""]
	if wing then
		local only = {}
		for _, q in ipairs(list) do if wing[q[1]] then only[#only + 1] = q end end
		list = only
	end
	local fac = UnitFactionGroup("player")
	local facN = fac == "Horde" and 1 or (fac == "Alliance" and 2 or 0)
	local _, _, classID = UnitClass("player")
	local lvl = UnitLevel("player") or 1
	local out = {}
	for _, q in ipairs(list) do
		local okCls = #q[10] == 0
		if not okCls then for _, c in ipairs(q[10]) do if c == classID then okCls = true break end end end
		if (q[3] == 0 or q[3] == facN) and okCls and q[12] ~= 1 then
			local e = { q = q, id = q[1], lvl = q[2] }
			if wing and type(wing[q[1]]) == "table" then e.wingBoss = wing[q[1]] end
			local miss = 0
			-- 연결 퀘스트(선택)는 선행으로 세지 않는다
			for _, p in ipairs(q[8]) do if not QDone(p) and not IsCrumb(p) then miss = miss + 1 end end
			local crumb = IsCrumb(q[1])
			if QDone(q[1]) then e.state, e.order = "done", 5
			elseif QInLog(q[1]) then e.state, e.order = "log", 1
			elseif crumb then e.state, e.order = "crumb", 3.5
			elseif miss > 0 then e.state, e.order, e.miss = "pre", 4, miss
			elseif q[2] > lvl then e.state, e.order = "soon", 3
			else e.state, e.order = "ok", 2 end
			e.crumb = crumb
			out[#out + 1] = e
		end
	end
	-- 연결 퀘스트: 다음 퀘스트를 찾아 두고, 이미 끝냈거나 다음 퀘스트를 받았으면 목록에서 뺀다
	do
		local keep = {}
		for _, e in ipairs(out) do
			if e.crumb then
				for _, q2 in ipairs(list) do
					for _, p in ipairs(q2[8]) do if p == e.id then e.nextQ = q2[1] end end
				end
				local nx = e.nextQ
				local gone = e.state == "done" or (nx and (QDone(nx) or QInLog(nx)))
				if not gone then keep[#keep + 1] = e end
			else
				keep[#keep + 1] = e
			end
		end
		out = keep
	end
	-- 같은 퀘스트 묶기: 이름이 같은 것(단계 · 아이템별로 나뉜 것)과 직접 묶은 것(DUNGEON_QUEST_GROUP)은 한 줄로
	--  보여 줄 대표: 진행 중 > 받을 수 있음 > 곧 > 선행 필요 > 완료 순, 같으면 번호가 작은 것
	local groups, merged = {}, {}
	for _, e in ipairs(out) do
		local g = ns.DUNGEON_QUEST_GROUP and ns.DUNGEON_QUEST_GROUP[e.id]
		if not g then
			local t = QTitle(e.id)
			if t then g = "t:" .. t end
		end
		local cur = g and groups[g]
		if not g then
			merged[#merged + 1] = e
		elseif not cur then
			e.variants = 1
			groups[g] = e
			merged[#merged + 1] = e
			e.slot = #merged
		else
			local n = cur.variants + 1
			if e.order < cur.order or (e.order == cur.order and e.id < cur.id) then
				e.variants, e.slot = n, cur.slot
				merged[cur.slot] = e
				groups[g] = e
			else
				cur.variants = n
			end
		end
	end
	out = merged
	table.sort(out, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		if a.lvl ~= b.lvl then return a.lvl < b.lvl end
		return a.id < b.id
	end)
	return out
end

-- 보스 NPC → 그 근처에서 시작하는 (아직 안 끝낸) 퀘스트들 · 진행 중인 게 있으면 .log
function M:QuestsNearBoss(key)
	local out = {}
	if not (key and ns.DUNGEON_QUEST_NOTES) then return out end
	for _, e in ipairs(self:DungeonQuestList(key)) do
		local nt = DQNote(e.id)
		if nt and nt[1] and nt[1] > 0 and e.state ~= "done" then
			local t = out[nt[1]] or {}
			out[nt[1]] = t
			t[#t + 1] = e
			if e.state == "log" then t.log = true end
		end
	end
	return out
end

local DQ_STATE = {
	log = { "진행 중", C.accent }, ok = { "받을 수 있음", C.green }, crumb = { "선택", C.soft }, soon = { "", C.orange },
	pre = { "", C.muted }, done = { "완료", C.dim },
}

function M:BuildQuestPanel()
	local p = CreateFrame("Frame", "FOADungeonQuests", UIParent)
	p:SetSize(DQ_W, 600)
	p:SetFrameStrata("HIGH")
	p:SetClampedToScreen(true)
	p:EnableMouse(true)
	p:Hide()
	Panel(p, C.green)
	p.tag = Ink:Text(p, F.latinB, 9, C.muted, "LEFT")
	p.tag:SetPoint("TOPLEFT", 16, -14)
	p.tag:SetText("DUNGEON QUESTS")
	p.title = Ink:Text(p, F.bold, 15, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", p.tag, "BOTTOMLEFT", 0, -4)
	p.sum = Ink:Text(p, F.sans, 10, C.muted, "LEFT")
	p.sum:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -5)
	p.sum:SetWidth(DQ_W - 32)
	p.close = CreateFrame("Button", nil, p)
	p.close:SetSize(24, 24)
	p.close:SetPoint("TOPRIGHT", -10, -10)
	p.close.icon = p.close:CreateTexture(nil, "ARTWORK")
	p.close.icon:SetTexture(Ink.icon("Cross"))
	p.close.icon:SetSize(11, 11)
	p.close.icon:SetPoint("CENTER")
	p.close.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
	p.close:SetScript("OnClick", function() Ink.db.dQuestsHide = true; M:PaintQuests() end)
	p.line = p:CreateTexture(nil, "ARTWORK")
	p.line:SetColorTexture(1, 1, 1, 0.06)
	p.line:SetHeight(1)
	p.line:SetPoint("TOPLEFT", 12, -72)
	p.line:SetPoint("TOPRIGHT", -12, -72)
	local sf = CreateFrame("ScrollFrame", nil, p)
	sf:SetPoint("TOPLEFT", 8, -78)
	sf:SetPoint("BOTTOMRIGHT", -8, 10)
	sf:EnableMouseWheel(true)
	local body = CreateFrame("Frame", nil, sf)
	body:SetSize(DQ_W - 16, 10)
	sf:SetScrollChild(body)
	sf:SetScript("OnMouseWheel", function(self, d)
		local max = math.max(0, body:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * DQ_ROW * 1.5)))
	end)
	p.sf, p.body, p.rows = sf, body, {}
	p.empty = Ink:Text(p, F.sans, 11, C.muted, "CENTER")
	p.empty:SetPoint("TOP", p.line, "BOTTOM", 0, -40)
	p.empty:SetWidth(DQ_W - 40)
	-- 접혀 있을 때 전리품 칸 옆에 붙는 작은 세로 탭
	local tab = CreateFrame("Button", nil, UIParent)
	tab:SetSize(28, 112)
	tab:SetFrameStrata("HIGH")
	tab.bg = Ink:Round(tab, "BACKGROUND", true, false)
	tab.bg:SetAllPoints()
	tab.bg:SetVertexColor(0.035, 0.04, 0.052, 0.96)
	tab.bd = Ink:Round(tab, "BORDER", true, true)
	tab.bd:SetAllPoints()
	tab.bd:SetVertexColor(C.green[1], C.green[2], C.green[3], 0.5)
	tab.t = Ink:Text(tab, F.semi, 11, C.green, "CENTER")
	tab.t:SetPoint("CENTER", 0, 4)
	tab.t:SetWidth(16)
	tab.t:SetWordWrap(true)   -- 세로 글자 (한 줄로 두면 "퀘..." 로 잘린다)
	tab.icon = tab:CreateTexture(nil, "ARTWORK")
	tab.icon:SetTexture(Ink.icon("QuestBang"))
	tab.icon:SetSize(12, 12)
	tab.icon:SetPoint("TOP", 0, -8)
	tab.icon:SetVertexColor(C.green[1], C.green[2], C.green[3])
	tab:SetScript("OnClick", function() Ink.db.dQuestsHide = nil; M:PaintQuests() end)
	tab:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(0.06, 0.075, 0.07, 0.98)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("던전 퀘스트 열기", 1, 1, 1)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function(self)
		self.bg:SetVertexColor(0.035, 0.04, 0.052, 0.96)
		GameTooltip:Hide()
	end)
	tab:Hide()
	p.tab = tab
	self.questPanel = p
	-- 퀘스트 이름이 늦게 도착하면 다시
	local ev = CreateFrame("Frame")
	pcall(ev.RegisterEvent, ev, "QUEST_DATA_LOAD_RESULT")
	pcall(ev.RegisterEvent, ev, "QUEST_LOG_UPDATE")
	pcall(ev.RegisterEvent, ev, "QUEST_TURNED_IN")
	local pend
	ev:SetScript("OnEvent", function()
		if pend or not (p:IsShown() or tab:IsShown()) then return end
		pend = true
		C_Timer.After(0.4, function() pend = nil; M:PaintQuests() end)
	end)
	return p
end

local function QuestRow(p, i)
	local r = p.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, p.body)
	r:SetSize(DQ_W - 16, DQ_ROW)
	r.hl = r:CreateTexture(nil, "BACKGROUND")
	r.hl:SetAllPoints()
	r.hl:SetColorTexture(1, 1, 1, 0.04)
	r.hl:Hide()
	r.lvl = Ink:Text(r, F.latinB, 13, C.text, "CENTER")
	r.lvl:SetPoint("LEFT", 6, 0)
	r.lvl:SetWidth(26)
	r.title = Ink:Text(r, F.semi, 12, C.text, "LEFT")
	r.title:SetPoint("TOPLEFT", 40, -8)
	r.title:SetPoint("RIGHT", -96, 0)
	r.title:SetWordWrap(false)
	r.sub = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
	r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
	r.sub:SetPoint("RIGHT", -8, 0)
	r.sub:SetWordWrap(false)
	-- 상태 칩: 진행 중 = 노란 바탕 · 보고 가능 = 초록 바탕 · 받을 수 있음 = 초록 테두리 · 완료 = 체크
	r.chip = CreateFrame("Frame", nil, r)
	r.chip:SetHeight(18)
	r.chip:SetPoint("TOPRIGHT", -6, -7)
	r.chip.bg = Ink:Round(r.chip, "BACKGROUND", true, false)
	r.chip.bg:SetAllPoints()
	r.chip.bd = Ink:Round(r.chip, "BORDER", true, true)
	r.chip.bd:SetAllPoints()
	r.chip.icon = r.chip:CreateTexture(nil, "ARTWORK")
	r.chip.icon:SetSize(10, 10)
	r.chip.icon:SetPoint("LEFT", 6, 0)
	r.state = Ink:Text(r.chip, F.semi, 10, C.green, "RIGHT")
	r.state:SetPoint("RIGHT", -7, 0)
	r.div = r:CreateTexture(nil, "ARTWORK")
	r.div:SetColorTexture(1, 1, 1, 0.05)
	r.div:SetHeight(1)
	r.div:SetPoint("BOTTOMLEFT", 6, 0)
	r.div:SetPoint("BOTTOMRIGHT", -6, 0)
	r:SetScript("OnEnter", function(self) self.hl:Show(); M:QuestTip(self) end)
	r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
	r:SetScript("OnClick", function(self)
		local q = self.e and self.e.q
		local Q = Ink.modules.QuestMap
		if q and q[4] > 0 and Q and Q.Waypoint then
			Q:Waypoint({ mapID = q[4], wx = q[5] / 100, wy = q[6] / 100 })
		elseif q and Q and Q.Waypoint then
			local nt = DQNote(q[1])
			if nt and nt[3] then Q:Waypoint({ mapID = nt[3], wx = nt[4] / 100, wy = nt[5] / 100 }) end
		end
	end)
	p.rows[i] = r
	return r
end

function M:QuestTip(r)
	local e = r.e
	if not e then return end
	local q = e.q
	local tt = GameTooltip
	tt:SetOwner(r, "ANCHOR_RIGHT")
	tt:AddLine(QTitle(e.id) or M.QuestFallback(e.id), 1, 1, 1)
	local LC = Ink.modules.Quest and Ink.modules.Quest.LevelColor
	local lc = (LC and q[2] > 0) and LC(q[2]) or C.soft
	tt:AddDoubleLine(q[2] > 0 and (q[2] .. "레벨부터") or "레벨 제한 없음", q[3] == 1 and "호드" or (q[3] == 2 and "얼라이언스" or "공통"), lc[1], lc[2], lc[3], 0.7, 0.72, 0.75)
	if Ink.TimerTipLine then Ink.TimerTipLine(tt, e.id) end
	-- 시작
	tt:AddLine(" ")
	local giver, zone = NpcOf(q[7]), ZoneName(q[4])
	local kind, item = q[14] or 0, q[13] or 0
	if item > 0 then
		local from = DropFrom(q)
		tt:AddLine("시작: 아이템 " .. (ItemName(item) and ("[" .. ItemName(item) .. "]") or ("#" .. item)), 1, 0.82, 0.32)
		if from then
			tt:AddLine(from .. " 드랍  ·  던전 안에서 얻어요", 0.7, 0.72, 0.75)
		elseif not DQNote(e.id) then
			tt:AddLine("아이템을 얻는 곳은 자료에 없어요", 0.56, 0.58, 0.61)
		end
	elseif q[7] > 0 then
		Ink.TipLine(tt, "시작: " .. (giver or "퀘스트 주는 NPC") .. (kind == KIND_IN_NPC and "  |cff8E939B(던전 안)|r" or ""), 1, 0.82, 0.32)
	elseif kind == KIND_IN_OBJ then
		tt:AddLine("시작: 던전 안 물체", 1, 0.82, 0.32)
	elseif (q[11] or 0) ~= 0 then
		tt:AddLine("시작: 아이템 (" .. (DropFrom(q) or "던전 몹") .. " 드랍)", 1, 0.82, 0.32)
	end
	local note = DQNote(e.id)
	if note and note[2] then Ink.TipLine(tt, note[2], 0.78, 0.8, 0.84) end
	if note and note[1] and note[1] > 0 and q[4] == 0 then
		local data = self.showing and self:Scan(self.showing)
		for _, bb in ipairs(data and data.bosses or {}) do
			if bb.npc == note[1] then Ink.TipLine(tt, "던전 화면: " .. (BossName(bb) or bb.name) .. " 근처 (경로에 느낌표)", 0.89, 0.75, 0.48) break end
		end
	end
	if note and note[3] and q[4] == 0 then
		local nz = ZoneName(note[3])
		-- 긴 설명은 줄을 나눠서 (툴팁이 옆으로 길게 늘어나 미니맵 · 퀘스트 목록을 덮지 않게)
		Ink.TipLine(tt, "보고: " .. (note[6] or "NPC") .. ((nz and not (note[6] or ""):find(nz, 1, true)) and ("  ·  " .. nz) or "") .. string.format("  %.1f, %.1f", note[4], note[5]), 0.7, 0.72, 0.75)
	end
	if zone then
		if kind == KIND_TURNIN then
			Ink.TipLine(tt, "보고: " .. (NpcOf(q[15]) or "NPC") .. "  ·  " .. zone .. string.format("  %.1f, %.1f", q[5], q[6]), 0.7, 0.72, 0.75)
		else
			tt:AddLine(zone .. string.format("  %.1f, %.1f", q[5], q[6]), 0.7, 0.72, 0.75)
		end
	end
	-- 경험치 · 돈 (게임이 알려 주는 경우만)
	local okX, xp = pcall(GetQuestLogRewardXP, e.id)
	local okM, money = pcall(GetQuestLogRewardMoney, e.id)
	xp, money = okX and plain(xp), okM and plain(money)
	if (type(xp) == "number" and xp > 0) or (type(money) == "number" and money > 0) then
		tt:AddDoubleLine((type(xp) == "number" and xp > 0) and ("경험치 " .. BreakUpLargeNumbers(xp)) or " ",
			(type(money) == "number" and money > 0 and GetCoinTextureString) and GetCoinTextureString(money) or "", 0.56, 0.83, 1, 1, 1, 1)
	end
	-- 선행 퀘스트
	local chain = {}
	Chain(e.id, chain, {}, 0)
	if #chain > 0 then
		tt:AddLine(" ")
		tt:AddLine("선행 퀘스트 " .. #chain .. "개 (순서대로)", 0.96, 0.95, 0.9)
		for i, pid in ipairs(chain) do
			if i > 8 then tt:AddLine("… " .. (#chain - 8) .. "개 더", 0.56, 0.58, 0.61) break end
			local _, dq, qr = PreOf(pid)
			local done, inlog = QDone(pid), QInLog(pid)
			local mark = done and (TipIcon("Check", { 0.44, 0.83, 0.6 }) .. " ") or (inlog and (TipIcon("Wait", { 1, 0.96, 0.41 }) .. " ") or "|cff8E939B·|r ")
			local where = ""
			if not done then
				local npc = dq and NpcOf(dq[7]) or (qr and NpcOf(qr[14]))
				local z = ZoneName(dq and dq[4] or (qr and qr[2] and qr[2][1]))
				if npc or z then where = "  |cff8E939B" .. (npc or "") .. ((npc and z) and " · " or "") .. (z or "") .. "|r" end
				if IsCrumb(pid) then where = where .. "  |cff8E939B(연결 · 선택)|r" end
			end
			tt:AddLine(mark .. (QTitle(pid) or ("#" .. pid)) .. where, done and 0.6 or 0.92, done and 0.62 or 0.92, done and 0.65 or 0.9)
		end
	end
	-- 보상
	if #q[9] > 0 then
		tt:AddLine(" ")
		tt:AddLine("보상", 0.96, 0.95, 0.9)
		for i, iid in ipairs(q[9]) do
			if i > 6 then break end
			local name, _, quality = C_Item.GetItemInfo(iid)
			if not name and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, iid) end
			local cr, cg, cb = 0.8, 0.8, 0.8
			if quality and C_Item.GetItemQualityColor then cr, cg, cb = C_Item.GetItemQualityColor(quality) end
			local mine = ForMyClass({ id = iid })
			tt:AddDoubleLine(name or "불러오는 중…", mine and "내 직업" or "", cr, cg, cb, 0.44, 0.83, 0.55)
		end
	end
	tt:AddLine(" ")
	local hint
	if q[4] == 0 and note and note[3] then
		hint = "클릭: 보고하는 곳을 지도에"
	elseif q[4] > 0 then
		hint = (q[14] == KIND_TURNIN) and "클릭: 보고하는 곳을 지도에" or "클릭: 시작 위치를 지도에"
	elseif q[14] == KIND_IN_NPC or q[14] == KIND_IN_OBJ or (q[14] == KIND_DROP and DropFrom(q)) then
		hint = "던전 안에서 시작해서 지도 안내는 없어요"
	elseif note then
		hint = "지도 안내는 없어요 · 위 설명을 참고하세요"
	else
		hint = "시작 위치 정보가 없어요"
	end
	tt:AddLine(hint, 0.56, 0.58, 0.61)
	tt:Show()
end

function M:PaintQuests()
	local f = self.sidebar
	local p = self.questPanel
	local key = self.showing
	local hasData = FOREVER and ns.DUNGEON_QUESTS and DQ_INST[key or ""]
	if not (f and f:IsShown() and hasData) then
		if p then p:Hide(); p.tab:Hide() end
		return
	end
	p = p or self:BuildQuestPanel()
	local list = self:DungeonQuestList(key)
	-- 자리: 항상 전리품 칸 오른쪽 바깥 (던전 화면에서도 지도를 가리지 않게)
	p:ClearAllPoints()
	p.tab:ClearAllPoints()
	if RoomRight(p, f) >= DQ_W + 8 then
		p:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, 0)
		p:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 8, 0)
		p.tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, -24)
	else
		-- 오른쪽에 자리가 없으면 (지도 최대화 등) 전리품 칸 왼쪽에
		p:SetPoint("TOPRIGHT", f, "TOPLEFT", -8, 0)
		p:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -8, 0)
		p.tab:SetPoint("TOPRIGHT", f, "TOPLEFT", -4, -24)
	end
	p:SetFrameLevel(f:GetFrameLevel() + 1)
	p.tab:SetFrameLevel(f:GetFrameLevel() + 2)
	if Ink.db.dQuestsHide then
		p:Hide()
		p.tab.t:SetText("퀘\n스\n트\n\n" .. #list)
		p.tab:Show()
		return
	end
	p.tab:Hide()
	p:Show()
	local nOk, nLog, nDone, nPre = 0, 0, 0, 0
	for _, e in ipairs(list) do
		if e.state == "ok" then nOk = nOk + 1 elseif e.state == "log" then nLog = nLog + 1
		elseif e.state == "done" then nDone = nDone + 1 elseif e.state == "pre" then nPre = nPre + 1 end
	end
	p.title:SetText("퀘스트 " .. #list)
	p.sum:SetText(string.format("|cff6FD39A가능 %d|r  ·  |cffFFF468진행 %d|r  ·  선행 필요 %d  ·  완료 %d", nOk, nLog, nPre, nDone))
	local LC = Ink.modules.Quest and Ink.modules.Quest.LevelColor
	local y = 0
	-- 상태별 묶음 제목: 진행 중 · 받을 수 있음 · 아직 못 받음 · 완료
	local GROUP = { log = "진행 중", ok = "받을 수 있음", crumb = "연결 퀘스트 · 선택 (던전 밖 전달)", soon = "아직 못 받음", pre = "아직 못 받음", done = "완료" }
	local GCOL = { log = C.accent, ok = C.green, crumb = C.soft, soon = C.muted, pre = C.muted, done = C.dim }
	local gcount = {}
	for _, e in ipairs(list) do gcount[GROUP[e.state]] = (gcount[GROUP[e.state]] or 0) + 1 end
	p.heads = p.heads or {}
	local nh, lastG = 0, nil
	for i, e in ipairs(list) do
		local gname = GROUP[e.state]
		if gname ~= lastG then
			lastG = gname
			nh = nh + 1
			local h = p.heads[nh]
			if not h then
				h = CreateFrame("Frame", nil, p.body)
				h:SetSize(DQ_W - 16, 26)
				h.dot = h:CreateTexture(nil, "ARTWORK")
				h.dot:SetSize(6, 6)
				h.dot:SetPoint("LEFT", 8, -2)
				h.dot:SetTexture(Ink.tex.disc)
				h.t = Ink:Text(h, F.semi, 11, C.text, "LEFT")
				h.t:SetPoint("LEFT", h.dot, "RIGHT", 7, 0)
				h.line = h:CreateTexture(nil, "ARTWORK")
				h.line:SetHeight(1)
				h.line:SetPoint("LEFT", h.t, "RIGHT", 8, 0)
				h.line:SetPoint("RIGHT", -8, -2)
				p.heads[nh] = h
			end
			local gc = GCOL[e.state]
			h.dot:SetVertexColor(gc[1], gc[2], gc[3])
			h.t:SetText(gname .. "  |cff8E939B" .. (gcount[gname] or 0) .. "|r")
			h.t:SetTextColor(gc[1], gc[2], gc[3])
			h.line:SetColorTexture(gc[1], gc[2], gc[3], 0.15)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", p.body, "TOPLEFT", 0, -(y + (nh > 1 and 8 or 0)))
			h:Show()
			y = y + 26 + (nh > 1 and 8 or 0)
		end
		local r = QuestRow(p, i)
		r.e = e
		local q = e.q
		r.lvl:SetText(q[2] > 0 and q[2] or "–")
		local lc = (LC and q[2] > 0) and LC(q[2]) or C.soft
		r.lvl:SetTextColor(lc[1], lc[2], lc[3], e.state == "done" and 0.4 or 1)
		r.title:SetText(QTitle(e.id) or "불러오는 중…")
		local tc = e.state == "done" and C.dim or C.text
		r.title:SetTextColor(tc[1], tc[2], tc[3])
		local giver, zone = NpcOf(q[7]), ZoneName(q[4])
		local kind = q[14] or 0
		local sub
		if kind == KIND_IN_OBJ then
			sub = "던전 안 물체에서 시작"
		elseif (q[13] or 0) > 0 or ((q[11] or 0) ~= 0 and q[7] == 0) then
			local from = DropFrom(q)
			sub = "아이템으로 시작" .. (from and ("  ·  " .. from .. " 드랍") or "")
			if kind == KIND_TURNIN and zone then sub = sub .. "  ·  보고 " .. zone end
		elseif q[7] > 0 then
			sub = (giver or "NPC") .. (zone and ("  ·  " .. zone) or (kind == KIND_IN_NPC and "  ·  던전 안" or ""))
		elseif kind == KIND_IN_OBJ then
			sub = "던전 안 물체에서 시작"
		else sub = zone or "" end
		local nt = DQNote(q[1])
		if nt and q[4] == 0 and nt[1] and nt[1] > 0 then
			local data = self.showing and self:Scan(self.showing)
			for _, bb in ipairs(data and data.bosses or {}) do
				if bb.npc == nt[1] then sub = sub .. "  ·  " .. (BossName(bb) or bb.name) .. " 근처" break end
			end
		end
		local nPre = 0
		for _, pid in ipairs(q[8]) do if not IsCrumb(pid) then nPre = nPre + 1 end end
		if nPre > 0 then sub = sub .. "  ·  선행 " .. nPre end
		if e.state == "pre" then
			-- 선행이 남았으면 주는 NPC 대신: 무엇을 먼저, 누구에게서, 어디서 (가장 앞에 남은 선행 하나)
			--  예) 현자 딥스 퀘스트 → "먼저 <보고서 꾸러미 퀘스트> · <반란군 야영지 NPC> · 가시덤불 골짜기"
			local chain = {}
			Chain(e.id, chain, {}, 0)
			for _, pid in ipairs(chain) do
				if not QDone(pid) and not IsCrumb(pid) then
					local _, dq, qr = PreOf(pid)
					local npc = dq and NpcOf(dq[7]) or (qr and NpcOf(qr[14]))
					local z = ZoneName(dq and dq[4] or (qr and qr[2] and qr[2][1]))
					local t = QTitle(pid) or "선행 퀘스트"
					if QInLog(pid) then
						sub = "먼저 " .. t .. " 끝내기  ·  진행 중"
					else
						sub = "먼저 " .. t .. ((npc or z) and ("  ·  " .. (npc or z) .. ((npc and z) and (" · " .. z) or "")) or "")
					end
					break
				end
			end
		end
		if e.crumb and e.nextQ then
			-- 연결 퀘스트: 어느 던전 퀘스트로 안내하는지
			local nt = QTitle(e.nextQ)
			sub = sub .. "  ·  → " .. (nt or "다음 퀘스트") .. " 안내"
		end
		if (e.variants or 1) > 1 then sub = sub .. "  ·  " .. e.variants .. "개 묶음" end
		-- 여러 날개에 걸친 퀘스트: 이 날개에서 잡을 대상을 맨 앞에
		if e.wingBoss and e.state ~= "done" then sub = "이 날개: " .. e.wingBoss.short .. "  ·  " .. sub end
		r.sub:SetText(sub)
		local st = DQ_STATE[e.state]
		local stText, col, fill, edge, icon = st[1], st[2], 0, 0, nil
		if e.state == "log" then
			local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(e.id)
			if ready then
				stText, col, fill, icon = "보고 가능", C.green, 0.18, "Check"
			else
				local have, need, wHave, wNeed = 0, 0, 0, 0
				for _, ob in ipairs(C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(e.id) or {}) do
					have = have + (ob.numFulfilled or 0); need = need + (ob.numRequired or 0)
					-- 이 날개 보스 목표만 따로 (예: 대성당 = 모그레인 · 화이트메인 2개)
					local txt = type(ob.text) == "string" and ob.text or ""
					for _, nm in ipairs(e.wingBoss or {}) do
						if txt:find(nm, 1, true) then
							wHave = wHave + (ob.numFulfilled or 0); wNeed = wNeed + (ob.numRequired or 0)
							break
						end
					end
				end
				if wNeed > 0 then have, need = wHave, wNeed end
				stText, fill = "진행 중" .. (need > 0 and ("  " .. have .. "/" .. need) or ""), 0.18
				if wNeed > 0 and wHave >= wNeed then stText, col, icon = "이 날개 끝", C.green, "Check" end
			end
		elseif e.state == "ok" then edge = 0.55
		elseif e.state == "done" then stText, icon, fill = "완료", "Check", 0.08; col = C.green
		elseif e.state == "soon" then stText = q[2] .. "레벨부터"
		elseif e.state == "pre" then stText = "선행 " .. e.miss .. "개 남음" end
		r.state:SetText(stText)
		r.state:SetTextColor(col[1], col[2], col[3], e.state == "done" and 0.75 or 1)
		r.chip.bg:SetVertexColor(col[1], col[2], col[3], fill)
		r.chip.bd:SetVertexColor(col[1], col[2], col[3], edge)
		if icon then
			r.chip.icon:SetTexture(Ink.icon(icon))
			r.chip.icon:SetVertexColor(col[1], col[2], col[3])
			r.chip.icon:Show()
		else
			r.chip.icon:Hide()
		end
		r.chip:SetWidth(math.ceil(r.state:GetStringWidth()) + (icon and 28 or 14))
		r:SetAlpha(e.state == "done" and 0.7 or 1)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", p.body, "TOPLEFT", 0, -y)
		r:Show()
		y = y + DQ_ROW
	end
	for i = #list + 1, #p.rows do p.rows[i]:Hide() end
	for i = nh + 1, #(p.heads or {}) do p.heads[i]:Hide() end
	p.body:SetHeight(math.max(10, y))
	-- 스크롤 위치: 다른 던전으로 바뀌면 맨 위로, 목록이 짧아졌으면 끝을 넘지 않게
	--  (긴 목록에서 내려 둔 채 짧은 목록을 열면 위쪽 줄 · 진행 중 퀘스트가 화면 위로 밀려 안 보였다)
	local maxS = math.max(0, y - (p.sf:GetHeight() or 0))
	if p.lastKey ~= key then p.sf:SetVerticalScroll(0)
	elseif (p.sf:GetVerticalScroll() or 0) > maxS then p.sf:SetVerticalScroll(maxS) end
	p.lastKey = key
	p.empty:SetText(#list == 0 and "이 던전에 내가 받을 수 있는 퀘스트가 없어요" or "")
end

-- 지도 옆에 붙이기 / 떼기

function M:ShowFor(jid, anchor)
	if not jid or not Ink.db.dungeon then return self:HideSidebar() end
	if not self.sidebar then self:BuildSidebar() end
	local f = self.sidebar
	self.showing = jid
	if self.boardOn then self:HideBoard() end
	f:ClearAllPoints()
	f:SetFrameStrata("HIGH")
	if anchor then
		f:SetScale(1)
		local sc = anchor.ScrollContainer
		if sc and RoomRight(f, anchor) < SB_W + 8 then
			-- 지도를 최대화하면 오른쪽에 자리가 없어 지도 위 축소 · 닫기 단추를 가렸다
			--  → 지도 그림 칸 안쪽 오른쪽에 (제목 줄 · 단추 줄 아래부터) 붙인다
			f:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -6, -6)
			f:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -6, 6)
			self.sidebarInside = true
		else
			f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
			f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 0)
			self.sidebarInside = nil
		end
	else
		f:SetHeight(620)
		f:SetPoint("RIGHT", Ink.root, "RIGHT", -300, 40)
	end
	f:Show()
	f.sf:SetVerticalScroll(0)
	self:PaintSidebar()
end

function M:HideSidebar()
	if self.questPanel then self.questPanel:Hide(); self.questPanel.tab:Hide() end
	if self.sidebar then
		self.sidebar:Hide()
		if self.sidebar.menu then self.sidebar.menu:Hide() end
	end
	self.showing = nil
end

local function InstanceForUiMap(uiMapID)
	if not uiMapID then return nil end
	if EJ_GetInstanceForMap then
		local ok, j = pcall(EJ_GetInstanceForMap, uiMapID)
		if ok and j and j > 0 then return j end
	end
end

function M:CurrentInstance()
	local inInst, kind = IsInInstance()
	if inInst and (kind == "party" or kind == "raid") then
		local mapID = select(8, GetInstanceInfo())
		if C_EncounterJournal.GetInstanceForGameMap and mapID then
			local ok, j = pcall(C_EncounterJournal.GetInstanceForGameMap, mapID)
			if ok and j and j > 0 then return j end
		end
		return InstanceForUiMap(C_Map.GetBestMapForUnit("player"))
	end
end

-- 포에버: 지금 던전 (안에 있으면 그 던전 — 안에서 직접 다른 던전을 골랐으면 그것, 아니면 고른 것 / 내 레벨에 맞는 것)
function M:ForeverCurrent()
	local list = ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}
	local here = self:MatchInstance()
	local sel = Ink.cdb and Ink.cdb.fDungeon
	if here then
		local iname = GetInstanceInfo()
		local mi = self.manualIn
		if not (type(mi) == "table" and mi.name == iname and mi.visit == self.visit and sel and FLoot(sel)) then return here end
	end
	if sel and FLoot(sel) then return sel end
	local lv, best, bestD = UnitLevel("player") or 1, nil, 999
	for _, d in ipairs(list) do
		if not d.soon then
			local dist = math.abs((d.lo + d.hi) / 2 - lv)
			if dist < bestD then best, bestD = d.key, dist end
		end
	end
	return best
end

-- 예전 ◀ ▶ (단축키 등에서 부를 수 있게 남겨 둠): 열린 던전만 순서대로
function M:StepForever(dir)
	local list = {}
	for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do if not d.soon then list[#list + 1] = d end end
	if #list == 0 then return end
	local cur, i = self.showing or self:ForeverCurrent(), 1
	for k, d in ipairs(list) do if d.key == cur then i = k end end
	i = (i - 1 + dir) % #list + 1
	self:SelectForever(list[i].key)
end

function M:UpdateMap()
	if self.testing then return end
	if FOREVER then
		local wm = WorldMapFrame
		if not wm or not wm:IsShown() then self:HideBoard() return self:HideSidebar() end
		-- 던전 안이면 지도 대신 큰 던전 화면 ("지도 보기" 를 누르면 이번에 연 동안만 원래 지도)
		local here = self:MatchInstance()
		if here and self.hereKey and here ~= self.hereKey then self.hereKey = here end
		if here and not self.boardOff and Ink.db.dungeonBoard ~= false then
			if self.boardOn and self.board and self.board:IsShown() then return end
			return self:ShowBoard(self:ForeverCurrent())
		end
		return self:ShowFor(self:ForeverCurrent(), wm)
	end
	local wm = WorldMapFrame
	if not wm or not wm:IsShown() then return self:HideSidebar() end
	local jid = InstanceForUiMap(wm.GetMapID and wm:GetMapID()) or self:CurrentInstance()
	if jid then self:ShowFor(jid, wm) else self:HideSidebar() end
end

function M:HookMap()
	local wm = WorldMapFrame
	if not wm or self.mapHooked then return end
	self.mapHooked = true
	wm:HookScript("OnShow", function() C_Timer.After(0, function() M:UpdateMap() end) end)
	wm:HookScript("OnHide", function()
		M.boardOff = nil
		if not M.testing then M:HideBoard(); M:HideSidebar() end
	end)
	if wm.OnMapChanged then hooksecurefunc(wm, "OnMapChanged", function() M:UpdateMap() end) end
	-- 최대화 · 원래 크기로 바꾸면 전리품 칸 자리도 다시 (최대화 땐 지도 안쪽으로)
	for _, fn in ipairs({ "Maximize", "Minimize" }) do
		if wm[fn] then hooksecurefunc(wm, fn, function() C_Timer.After(0, function() if wm:IsShown() and not M.boardOn then M:UpdateMap() end end) end) end
	end
end

-------------------------------------------------------------------------------
-- 던전 입장 알림
-------------------------------------------------------------------------------
function M:BuildToast()
	local t = CreateFrame("Frame", nil, Ink.root)
	t:SetSize(380, 58)
	t:SetPoint("TOP", Ink.root, "TOP", 0, -96)
	t:SetFrameStrata("HIGH")
	t:EnableMouse(false)
	Panel(t)
	t.icon = t:CreateTexture(nil, "ARTWORK")
	t.icon:SetSize(20, 20)
	t.icon:SetPoint("LEFT", 18, 0)
	t.icon:SetTexture(Ink.icon("Journal"))
	t.icon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	t.title = Ink:Text(t, F.bold, 14, C.text, "LEFT")
	t.title:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 14, 4)
	t.sub = Ink:Text(t, F.sans, 11, C.soft, "LEFT")
	t.sub:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 14, -4)
	t:Hide()
	local ag = t:CreateAnimationGroup()
	local m0 = ag:CreateAnimation("Translation"); m0:SetOrder(1); m0:SetDuration(0); m0:SetOffset(0, 14)
	local a0 = ag:CreateAnimation("Alpha"); a0:SetOrder(1); a0:SetDuration(0); a0:SetFromAlpha(0); a0:SetToAlpha(0)
	local m1 = ag:CreateAnimation("Translation"); m1:SetOrder(2); m1:SetDuration(0.35); m1:SetSmoothing("OUT"); m1:SetOffset(0, -14)
	local a1 = ag:CreateAnimation("Alpha"); a1:SetOrder(2); a1:SetDuration(0.3); a1:SetFromAlpha(0); a1:SetToAlpha(1)
	local a2 = ag:CreateAnimation("Alpha"); a2:SetOrder(3); a2:SetStartDelay(5); a2:SetDuration(0.6); a2:SetFromAlpha(1); a2:SetToAlpha(0)
	ag:SetScript("OnFinished", function() t:Hide() end)
	t.ag = ag
	self.toast = t
end

function M:Toast(name, nb, na, sub)
	if not self.toast then self:BuildToast() end
	local t = self.toast
	t.title:SetText((name or "던전") .. " 입장")
	t.sub:SetText(sub or string.format("내 장비  |cffFFF468BIS %d|r  ·  대체 %d  ·  지도(M)에서 보스별로 보기", nb or 0, na or 0))
	t:SetWidth(math.max(380, math.ceil(t.sub:GetStringWidth()) + 70))
	t:SetAlpha(1)
	t:Show()
	t.ag:Stop()
	t.ag:Play()
end

-- 포에버: 던전에 들어가면 알림 (보스 수 · 내 직업 장비 · 추천) + 오래된 처치 기록 정리
function M:OnForeverEnter()
	local key, sure = self:MatchInstance()
	self.hereKey = key
	self.hereSure = sure and true or false
	local d = key and FLoot(key)
	-- 막 들어온 순간엔 층 번호가 아직 안 나오거나, 날개를 아직 모를 수 있다 → 잠깐 뒤 다시 (최대 6번)
	local noUi = IsInInstance() and not (C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
	if (noUi or (d and d.group and not sure)) and (self.enterTries or 0) < 6 then
		self.enterTries = (self.enterTries or 0) + 1
		C_Timer.After(3, function() pcall(M.OnForeverEnter, M) end)
	else
		self.enterTries = 0
	end
	if not key then self.lastToast, self.manualIn = nil, nil return end
	if sure and d.group then self:RememberWingSpot(key) end
	local k = KillSet(key)
	if k.t and k.t > 0 and time() - k.t > 90 * 60 and Ink.cdb and Ink.cdb.dKills then Ink.cdb.dKills[key] = nil end
	-- 날개를 아직 모르면 날개 이름 대신 묶음 이름으로 알리고, 알게 되면 그 날개로 한 번 더
	if d.group and not sure then
		local tk = "group:" .. d.group
		if self.lastToast == tk then return end
		self.lastToast = tk
		C_Timer.After(2.5, function()
			M:Toast(d.groupKo, nil, nil, "날개 확인 중  ·  보스를 보면 자동으로  ·  지도(M) 이름 옆 ∨ 로 직접 고르기")
		end)
		return
	end
	if key == self.lastToast then return end
	self.lastToast = key
	C_Timer.After(2.5, function()
		local data = M:Scan(key)
		if not data then return end
		pcall(M.BuildRanks, M)
		local nCls, nRec, nMain = 0, 0, 0
		for _, b in ipairs(data.bosses) do
			if not b.rare then nMain = nMain + 1 end
			for _, it in ipairs(b.items) do
				if M.ranks[it.id] then nRec = nRec + 1 end
				if ForMyClass(it) then nCls = nCls + 1 end
			end
		end
		M:Toast(data.name, nil, nil, string.format("보스 %d  ·  내 직업 장비 %d  ·  |cffFFF468추천 %d|r  ·  지도(M)에서 진행 경로", nMain, nCls, nRec))
	end)
end

-- 보스 처치: 전투 종료 이벤트의 이름 / 대상이 죽은 걸 보고 NPC 번호로
-- 이름 비교: 띄어쓰기 · 기호를 빼고, 한쪽이 다른 쪽에 들어 있어도 같은 보스 (전투 이름이 "남작" ↔ "흉측한 남작" 처럼 다를 때)
local function NormName(s)
	if type(s) ~= "string" then return end
	s = s:lower():gsub("<.->", ""):gsub("[%s%p]", "")
	return s ~= "" and s or nil
end

function M:OnBossKilled(name, encID)
	local key = self.hereKey or self:MatchInstance()
	name = plain(name)
	if not key or type(name) ~= "string" then return end
	local data = self:Scan(key, true)
	local n = NormName(name)
	local best
	for _, b in ipairs(data and data.bosses or {}) do
		if b.npc then
			for _, cand in ipairs({ BossName(b), b.name, b.en }) do
				local c = NormName(cand)
				if c and n then
					if c == n then return self:MarkKill(key, b.npc) end
					if #c >= 2 and #n >= 2 and (n:find(c, 1, true) or c:find(n, 1, true)) then best = best or b end
				end
			end
		end
	end
	if best then return self:MarkKill(key, best.npc) end
	-- 못 맞춘 전투 이름은 기록 (/foa log 로 보고 보스 이름을 맞춘다)
	Ink.db.encLog = Ink.db.encLog or {}
	local log = Ink.db.encLog
	log[#log + 1] = date("%m-%d %H:%M ") .. key .. " · " .. name .. (encID and (" · #" .. tostring(plain(encID))) or "")
	while #log > 20 do table.remove(log, 1) end
end

-- 시체 전리품 창: 전리품이 나온 시체의 NPC 번호로 처치 판정 (전투 밖이라 값이 비공개가 아니다)
function M:CheckLoot()
	local key = self.hereKey
	if not (key and GetNumLootItems and GetLootSourceInfo) then return end
	local d = FLoot(key)
	if not d then return end
	local boss = {}
	for _, b in ipairs(d.bosses or {}) do if b[3] then boss[b[3]] = true end end
	for i = 1, (GetNumLootItems() or 0) do
		local src = { GetLootSourceInfo(i) }
		for j = 1, #src, 2 do
			local guid = plain(src[j])
			if type(guid) == "string" then
				local npc = tonumber((select(6, strsplit("-", guid))))
				if npc and boss[npc] then self:MarkKill(key, npc) end
			end
		end
	end
end

-- 지금 던전의 보스인가 (보스 알림: 블리자드 보스 정보가 없는 옛 던전에서 보스 시전을 알아보려고)
--  희귀몹 · 상자는 빼고 진짜 보스만. 전투 중 GUID 가 비공개면 모른다(false)
function M:IsHereBoss(unit)
	local key = self.hereKey
	if not key then return false end
	local ok, guid = pcall(UnitGUID, unit)
	guid = ok and plain(guid)
	if type(guid) ~= "string" then return false end
	local npc = tonumber((select(6, strsplit("-", guid))))
	if not npc then return false end
	local d = FLoot(key)
	for _, b in ipairs(d and d.bosses or {}) do
		if b[3] == npc and (b[4] or 0) == 0 then return true end
	end
	return false
end

function M:CheckDead(unit)
	local key = self.hereKey
	if not key then return end
	local ok, dead = pcall(UnitIsDead, unit)
	if not (ok and plain(dead)) then return end
	local ok2, guid = pcall(UnitGUID, unit)
	guid = ok2 and plain(guid)
	if type(guid) ~= "string" then return end
	local npc = tonumber((select(6, strsplit("-", guid))))
	if not npc then return end
	local d = FLoot(key)
	for _, b in ipairs(d and d.bosses or {}) do
		if b[3] == npc then return self:MarkKill(key, npc) end
	end
end

function M:OnEnterWorld()
	local jid = self:CurrentInstance()
	if not jid or jid == self.lastToast then
		if not jid then self.lastToast = nil end
		return
	end
	self.lastToast = jid
	C_Timer.After(2, function()
		local data = M:Scan(jid)
		M:BuildRanks(jid)
		local c = M.rankCount[jid] or { bis = 0, alt = 0 }
		M:Toast(data and data.name, c.bis, c.alt)
	end)
end

-------------------------------------------------------------------------------
-- 아이템 툴팁: 순위 · 드랍 위치
-------------------------------------------------------------------------------
function M:HookTooltip()
	if not (TooltipDataProcessor and Enum.TooltipDataType) then return end
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		if not Ink.db.dungeon or not tt.AddLine then return end
		local id = data and plain(data.id)
		local r = id and M.ranks[id]
		if not r then
			-- 포에버: 순위가 없어도 던전 드랍템이면 어디서 나오는지 한 줄
			local src = FOREVER and id and M:DropSource(id)
			if src then Ink.TipLine(tt, "|cff9EA3AB드랍|r  " .. src, 0.85, 0.87, 0.9)
			elseif FOREVER and id and ns.ItemSourceText then
				local w = ns.ItemSourceText(id)
				if w then Ink.TipLine(tt, "|cff9EA3AB획득|r  " .. w, 0.85, 0.87, 0.9) end
			end
			return
		end
		local _, _, _, specName = SpecKey()
		tt:AddLine(" ")
		tt:AddLine("|cffFFF468—|r  |cff8E939BFOA · " .. (UnitClass("player") or "") .. " " .. (specName or "") .. (M.isExample and " · 예시 순위" or "") .. "|r")
		local label = "|cffFFF468" .. RankText(r) .. "|r"
		tt:AddDoubleLine(label .. "  " .. (SLOT_NAME[r.slot] or "") .. " " .. (r.rank + 1) .. "순위", " ", 1, 1, 1)
		Ink.TipLine(tt, "|cff9EA3AB획득|r  " .. (M:SourceText(r.it) or ""), 1, 1, 1)
	end)
end

-------------------------------------------------------------------------------
-- 캐릭터 창 "BIS" 탭 + 부위별 BIS 판
-------------------------------------------------------------------------------
local BP_W = 470

function M:BuildBisPanel()
	local p = CreateFrame("Frame", "FOABisPanel", UIParent)
	p:SetSize(BP_W, 520)
	p:SetFrameStrata("HIGH")
	p:EnableMouse(true)
	p:Hide()
	Panel(p)
	p.title = Ink:Text(p, F.bold, 15, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", 16, -14)
	p.title:SetText("BIS")
	p.spec = Ink:Text(p, F.semi, 11, C.text, "LEFT")
	p.spec:SetPoint("LEFT", p.title, "RIGHT", 10, -1)
	p.pills = SpecPills(p, 24)
	p.pills:SetPoint("TOPRIGHT", -16, -12)
	-- 자료 설명: 큰 숫자 아래 한 줄 (탭 · 숫자와 겹치지 않게 따로 줄을 둔다)
	p.example = Ink:Text(p, F.sans, 10, C.dim, "LEFT")
	p.example:SetPoint("TOPLEFT", 16, -82)
	p.example:SetWidth(BP_W - 32)
	p.head = p:CreateTexture(nil, "ARTWORK")
	p.head:SetColorTexture(1, 1, 1, 0.06)
	p.head:SetHeight(1)
	p.head:SetPoint("TOPLEFT", 12, -100)
	p.head:SetPoint("TOPRIGHT", -12, -100)
	p.sumN = Ink:Text(p, F.num, 26, C.text, "LEFT")
	p.sumN:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -10)
	p.sumL = Ink:Text(p, F.sans, 10, C.muted, "LEFT")
	p.sumL:SetPoint("BOTTOMLEFT", p.sumN, "BOTTOMRIGHT", 6, 4)
	p.sumL:SetText("칸 BIS 착용")
	-- 왼쪽: 부위 목록
	p.slots = {}
	for i, s in ipairs(INV) do
		local b = CreateFrame("Button", nil, p)
		b:SetSize(150, 25)
		b:SetPoint("TOPLEFT", 12, -108 - (i - 1) * 26)
		b.hl = Ink:Round(b, "BACKGROUND", true, false)
		b.hl:SetAllPoints()
		b.hl:SetVertexColor(1, 1, 1, 0)
		b.icon = ItemIcon(b, 21)
		b.icon:SetPoint("LEFT", 4, 0)
		b.label = Ink:Text(b, F.semi, 11, C.text, "LEFT")
		b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
		b.dot = b:CreateTexture(nil, "OVERLAY")
		b.dot:SetTexture(Ink.tex.disc)
		b.dot:SetSize(7, 7)
		b.dot:SetPoint("RIGHT", -8, 0)
		b.inv, b.ej, b.name = s[1], s[2], s[3]
		b:SetScript("OnClick", function() M.bisSel = i; M:PaintBis() end)
		b:SetScript("OnEnter", function(self) if M.bisSel ~= i then self.hl:SetVertexColor(1, 1, 1, 0.05) end end)
		b:SetScript("OnLeave", function(self) if M.bisSel ~= i then self.hl:SetVertexColor(1, 1, 1, 0) end end)
		p.slots[i] = b
	end
	-- 오른쪽: 고른 부위의 순위
	p.sep = p:CreateTexture(nil, "ARTWORK")
	p.sep:SetColorTexture(1, 1, 1, 0.06)
	p.sep:SetWidth(1)
	p.sep:SetPoint("TOPLEFT", 172, -106)
	p.sep:SetPoint("BOTTOMLEFT", 172, 14)
	p.selName = Ink:Text(p, F.bold, 14, C.text, "LEFT")
	p.selName:SetPoint("TOPLEFT", 186, -114)
	p.cur = Ink:Text(p, F.sans, 10, C.muted, "LEFT")
	p.cur:SetPoint("TOPLEFT", p.selName, "BOTTOMLEFT", 0, -4)
	p.cur:SetWidth(BP_W - 204)
	p.ranks = {}
	for i = 1, 5 do
		local r = CreateFrame("Button", nil, p)
		r:SetSize(BP_W - 200, 54)
		r:SetPoint("TOPLEFT", 184, -156 - (i - 1) * 60)
		r.bg = Ink:Round(r, "BACKGROUND", true, false)
		r.bg:SetAllPoints()
		r.bd = Ink:Round(r, "BORDER", true, true)
		r.bd:SetAllPoints()
		r.rank = Ink:Text(r, F.num, 18, C.soft, "CENTER")
		r.rank:SetPoint("LEFT", 6, 0)
		r.rank:SetWidth(26)
		r.badge = Badge(r)
		r.badge:SetPoint("LEFT", 4, 0)
		r.icon = ItemIcon(r, 32)
		r.icon:SetPoint("LEFT", 40, 0)
		r.name = Ink:Text(r, F.semi, 12, C.text, "LEFT")
		r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, 0)
		r.name:SetPoint("RIGHT", -60, 0)
		r.src = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
		r.src:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 0)
		r.src:SetPoint("RIGHT", -8, 0)
		r.state = Ink:Text(r, F.semi, 10, C.green, "RIGHT")
		r.state:SetPoint("TOPRIGHT", -8, -8)
		r:SetScript("OnEnter", function(self)
			if self.link or self.itemID then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetItemByID(self.itemID) end
				if self.it and self.it.craft then pcall(M.CraftTooltip, M, self.it) end
				if self.it and self.it.quest then pcall(M.QuestRewardTooltip, M, self.it) end
				GameTooltip:Show()
			end
		end)
		r:SetScript("OnLeave", GameTooltip_Hide)
		-- 제작템: 클릭하면 제조법 상인 위치를 지도에
		r:SetScript("OnMouseUp", function(self)
			local it = self.it
			-- 퀘스트 보상: 퀘스트 주는 곳을 지도에
			if it and it.quest and it.qmap and it.qmap > 0 then
				local Q = Ink.modules.QuestMap
				if Q and Q.Waypoint then Q:Waypoint({ mapID = it.qmap, wx = it.qx / 100, wy = it.qy / 100 }) end
				return
			end
			if not (it and it.craft and it.spell) then return end
			local rc = M:RecipeFor(it.spell)
			local P = Ink.modules.Professions
			local x = rc and P and P.PickVendor and P.PickVendor(rc)
			if x and P.Waypoint then P.Waypoint(x) end
		end)
		p.ranks[i] = r
	end
	p.hint = Ink:Text(p, F.sans, 10, C.dim, "LEFT")
	p.hint:SetPoint("BOTTOMLEFT", 186, 16)
	p.hint:SetWidth(BP_W - 204)
	p.hint:SetWordWrap(true)
	p.hint:SetText("마우스를 올리면 툴팁 + 획득처. 대체템은 BIS 장비의 능력치 비중으로 이번 시즌 레이드 · 던전 전리품에서 FOA가 고른 거예요.")
	-- 장비 / 준비물 전환 (위 오른쪽, 예시 문구 아래)
	p.modes = {}
	for i, m in ipairs({ { "gear", "장비" }, { "prep", "준비물" } }) do
		local b = CreateFrame("Button", nil, p)
		b:SetSize(58, 24)
		b:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16 - (2 - i) * 60, -48)
		b.label = Ink:Text(b, F.semi, 12, C.muted, "CENTER")
		b.label:SetPoint("CENTER", 0, 1)
		b.label:SetText(m[2])
		b.line = b:CreateTexture(nil, "OVERLAY")
		b.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
		b.line:SetSize(18, 2)
		b.line:SetPoint("BOTTOM", 0, 0)
		b:SetScript("OnClick", function() M.bisMode = m[1]; M:PaintBis() end)
		b.mode = m[1]
		p.modes[i] = b
	end
	self:BuildPrep(p)
	p:SetScript("OnShow", function() M:PaintBis() end)
	self.bisPanel = p
end

-------------------------------------------------------------------------------
-- 준비물: 소모품 · 보석 · 마법부여 (SimC 프로필 기준)
-------------------------------------------------------------------------------
local enchCache = {}
-- 마법부여 이름을 게임 언어로: 그 칸 아이템에 마법부여를 붙인 링크의 툴팁에서 읽는다
local function EnchantName(itemID, enchantID, fallback)
	local key = (itemID or 0) .. ":" .. (enchantID or 0)
	if enchCache[key] then return enchCache[key] end
	local name
	if itemID and enchantID and enchantID > 0 and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		local ok, data = pcall(C_TooltipInfo.GetHyperlink, "item:" .. itemID .. ":" .. enchantID)
		local T = Enum.TooltipDataLineType
		if ok and data and data.lines then
			for _, line in ipairs(data.lines) do
				local t = plain(line.leftText)
				if type(t) == "string" and ((T and line.type == T.ItemEnchantmentPermanent) or t:find("^마법부여") or t:find("^Enchanted")) then
					name = t:gsub("^마법부여:%s*", ""):gsub("^Enchanted:%s*", "")
					break
				end
			end
		end
	end
	if not name then
		name = (fallback or ""):gsub("^Enchant [%a%s]+ %- ", "")
		if name:find("^%+") then name = "능력치 강화" end
		if name == "" then name = "?" end
	else
		enchCache[key] = name
	end
	return name
end

local function EquippedEnchant(inv)
	local link = GetInventoryItemLink("player", inv)
	local e = link and link:match("item:%d+:(%d*)")
	return tonumber(e or "")
end

local PREP_CONS = { { "flask", "영약" }, { "potion", "물약" }, { "food", "음식" }, { "rune", "증강 룬" }, { "oil", "무기 강화" } }

function M:BuildPrep(p)
	local f = CreateFrame("Frame", nil, p)
	f:SetPoint("TOPLEFT", 12, -108)
	f:SetPoint("BOTTOMRIGHT", -12, 12)
	f:Hide()
	local function Header(text, y, x)
		local h = Ink:Text(f, F.semi, 10, C.muted, "LEFT")
		h:SetPoint("TOPLEFT", x or 4, -y)
		h:SetText(text)
		return h
	end
	local function Line(x, y, w)
		local r = CreateFrame("Button", nil, f)
		r:SetSize(w, 28)
		r:SetPoint("TOPLEFT", x, -y)
		r.icon = ItemIcon(r, 24)
		r.icon:SetPoint("LEFT", 0, 0)
		r.label = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
		r.label:SetPoint("LEFT", r.icon, "RIGHT", 8, 6)
		r.name = Ink:Text(r, F.semi, 12, C.text, "LEFT")
		r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, -6)
		r.name:SetPoint("RIGHT", -24, -6)
		r.mark = Ink:Text(r, F.latinB, 12, C.green, "RIGHT")
		r.mark:SetPoint("RIGHT", -2, 0)
		-- ✓ 는 글꼴에 없는 글자라(네모로 깨짐) 아이콘으로
		r.check = r:CreateTexture(nil, "OVERLAY")
		r.check:SetTexture(Ink.icon("Check"))
		r.check:SetSize(14, 14)
		r.check:SetPoint("RIGHT", -2, 0)
		r.check:SetVertexColor(C.green[1], C.green[2], C.green[3])
		r.check:Hide()
		r:SetScript("OnEnter", function(self)
			if self.itemID then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetItemByID(self.itemID)
				GameTooltip:Show()
			elseif self.spellID then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetSpellByID(self.spellID)
				GameTooltip:Show()
			end
		end)
		r:SetScript("OnLeave", GameTooltip_Hide)
		return r
	end
	local half = (BP_W - 24) / 2
	f.h1 = Header("소모품", 0)
	f.cons = {}
	for i = 1, #PREP_CONS do f.cons[i] = Line(4, 18 + (i - 1) * 32, half - 8) end
	f.h2 = Header("보석", 18 + #PREP_CONS * 32 + 8)
	f.gems = {}
	for i = 1, 6 do f.gems[i] = Line(4, 18 + #PREP_CONS * 32 + 26 + (i - 1) * 32, half - 8) end
	f.h3 = Header("마법부여", 0, half + 8)
	f.ench = {}
	for i = 1, 10 do f.ench[i] = Line(half + 8, 18 + (i - 1) * 32, half - 8) end
	f.hint = Ink:Text(f, F.sans, 10, C.dim, "LEFT")
	f.hint:SetPoint("BOTTOMLEFT", 4, 4)
	f.hint:SetWidth(BP_W - 40)
	f.hint:SetWordWrap(true)
	p.prep = f
end

local function SetLine(r, id, label, name, quality)
	r.itemID = id
	r.label:SetText(label or "")
	if id then
		local _, _, _, _, icon = C_Item.GetItemInfoInstant(id)
		local nm = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
		if not nm then
			RequestItem(id)
			M.prepMissing = true
		end
		local q = quality or (C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)) or 1
		r.icon:Set(icon, q, "")
		local c = QCOL[q] or QCOL[1]
		r.name:SetText(nm or name or "불러오는 중…")
		r.name:SetTextColor(c[1], c[2], c[3])
	else
		r.icon:Set(nil, 1, "·")
		r.name:SetText(name or "")
		r.name:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	r.mark:SetText("")
	r.check:Hide()
	r:Show()
end

local CONS_KO = { Flask = "영약", Elixir = "비약", Potion = "물약", Food = "음식", Weapon = "무기 강화", Other = "기타" }
local SLOT_KO = { Head = "머리", Neck = "목", Shoulder = "어깨", Back = "등", Chest = "가슴", Wrist = "손목", Hands = "손",
	Legs = "다리", Feet = "발", ["Main Hand"] = "주장비", ["Off Hand"] = "보조장비", Ranged = "원거리" }
local STAT_KO = {
	{ "Offense:", "공격:" }, { "Defense:", "방어:" },
	{ "Shadow Spell Damage", "암흑 주문력" }, { "Fire Spell Damage", "화염 주문력" },
	{ "Weapon Damage", "무기 공격력" }, { "Weapon DPS", "무기 초당 공격력" }, { "Healing Power", "치유량" }, { "Spell Damage", "주문 공격력" },
	{ "Spell Piercing", "주문 관통" },
	{ "Critical Strike Chance", "치명타" }, { "Critical Strike", "치명타" }, { "Crit Chance", "치명타" }, { "Crit", "치명타" },
	{ "Hit Chance", "적중" }, { "Hit", "적중" }, { "Expertise", "숙련" }, { "Agility", "민첩" }, { "Strength", "힘" },
	{ "Stamina", "체력" }, { "Intellect", "지능" }, { "Spirit", "정신력" }, { "MP5", "5초당 마나" }, { "Haste", "가속" },
	{ "Defense", "방어 숙련" }, { "Block Chance", "방패 막기" }, { "Spell Power", "주문력" }, { "Armor", "방어도" }, { "Dodge", "회피" },
	{ "Feral Combat Skill", "야성 전투 숙련" }, { "with Careful Aim", "신중한 조준 있을 때" }, { "without Careful Aim", "없을 때" },
	{ "to Cap", "상한까지" }, { " and ", " · " },
}
local function KoStats(s)
	if not s or s == "" then return "" end
	for _, r in ipairs(STAT_KO) do s = s:gsub(r[1], r[2]) end
	return s
end

-- 포에버 준비물: 소모품 · 마법부여 (공략 이름 그대로, 게임 언어로)
function M:PaintPrepForever(f, fo)
	f.h2:SetText("")
	local rows = {}
	for _, r in ipairs(f.cons) do rows[#rows + 1] = r end
	for _, r in ipairs(f.gems) do rows[#rows + 1] = r end
	local n = 0
	local last
	for _, c in ipairs(fo.co or {}) do
		n = n + 1
		local r = rows[n]
		if r then
			local label = CONS_KO[c[1]] or c[1]
			SetLine(r, c[2], label ~= last and label or "")
			last = label
		end
	end
	if n == 0 then SetLine(rows[1], nil, "소모품", "자료 준비 중") end
	local e = 0
	for _, en in ipairs(fo.en or {}) do
		e = e + 1
		local r = f.ench[e]
		if r then
			local slot, kind, id = en[1], en[2], en[3]
			if kind == "item" then
				SetLine(r, id, SLOT_KO[slot] or slot)
			else
				local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
				local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id))
				SetLine(r, nil, SLOT_KO[slot] or slot, name or "불러오는 중…")
				if not name then self.prepMissing = true end
				r.icon:Set(icon, 1, "")
				r.spellID = id
			end
		end
	end
	if e == 0 then SetLine(f.ench[1], nil, "마법부여", "자료 준비 중") end
	local st = KoStats(fo.stats)
	f.hint:SetText((st ~= "" and ("능력치: " .. st .. "\n") or "") .. "자료: Method 공략 (포에버 1.60.1)")
end

function M:PaintPrep()
	local p = self.bisPanel
	local f = p.prep
	local spec = self.spec
	if FOREVER then
		for _, list in ipairs({ f.cons, f.gems, f.ench }) do for _, r in ipairs(list) do r:Hide(); r.spellID = nil end end
		self.prepMissing = nil
		if not spec then f.hint:SetText("이 특성은 아직 준비물 자료가 없어요 (공략이 올라오는 대로 추가)."); return end
		self:PaintPrepForever(f, spec.fo)
		if self.prepMissing and (self.prepRetry or 0) < 12 then
			self.prepRetry = (self.prepRetry or 0) + 1
			C_Timer.After(0.6, function() if p:IsShown() and self.bisMode == "prep" then self:PaintPrep() end end)
		end
		return
	end
	for _, list in ipairs({ f.cons, f.gems, f.ench }) do for _, r in ipairs(list) do r:Hide() end end
	self.prepMissing = nil
	if not spec then
		f.hint:SetText("이 전문화는 아직 준비물 자료가 없어요.")
		return
	end
	local n = 0
	for _, c in ipairs(PREP_CONS) do
		local v = spec.co and spec.co[c[1]]
		if v then
			n = n + 1
			if type(v) == "number" then SetLine(f.cons[n], v, c[2]) else SetLine(f.cons[n], nil, c[2], v) end
		end
	end
	if n == 0 then SetLine(f.cons[1], nil, "소모품", "자료 없음") end
	local g = 0
	for _, id in ipairs(spec.gem or {}) do
		g = g + 1
		if f.gems[g] then SetLine(f.gems[g], id, g == 1 and "보석" or "") end
	end
	if g == 0 then SetLine(f.gems[1], nil, "보석", "자료 없음") end
	local e = 0
	local done = 0
	for _, en in ipairs(spec.en or {}) do
		e = e + 1
		local r = f.ench[e]
		if r then
			local inv, eid, fallback = en[1], en[2], en[3]
			local slotName = ""
			for _, s in ipairs(INV) do if s[1] == inv then slotName = s[3] end end
			local baseItem = spec.g[inv] or GetInventoryItemID("player", inv)
			SetLine(r, nil, slotName, EnchantName(baseItem, eid, fallback))
			local tex = GetInventoryItemTexture("player", inv)
			r.icon:Set(tex, GetInventoryItemQuality("player", inv) or 1, "")
			local have = EquippedEnchant(inv)
			if eid and eid > 0 and have == eid then
				r.check:Show()
				done = done + 1
			elseif GetInventoryItemID("player", inv) then
				r.mark:SetText(have and "다름" or "없음")
				r.mark:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
			end
		end
	end
	f.hint:SetText(string.format("마법부여 %d / %d 적용 · 노란 글자 = 바꾸면 좋은 칸 · 자료: %s", done, e, spec.src))
	-- 아이템 이름이 아직 안 온 칸이 있으면 잠깐 뒤 다시 (처음 열 때 "불러오는 중…" 이 남지 않게)
	if self.prepMissing and (self.prepRetry or 0) < 12 then
		self.prepRetry = (self.prepRetry or 0) + 1
		C_Timer.After(0.6, function()
			if p:IsShown() and (self.bisMode == "prep") then self:PaintPrep() end
		end)
	elseif not self.prepMissing then
		self.prepRetry = 0
	end
end

function M:PaintBis()
	local p = self.bisPanel
	if not p or not p:IsShown() then return end
	self:BuildRanks()
	local mode = self.bisMode or "gear"
	for _, b in ipairs(p.modes) do
		local on = b.mode == mode
		b.label:SetTextColor(on and C.text[1] or C.muted[1], on and C.text[2] or C.muted[2], on and C.text[3] or C.muted[3])
		b.line:SetShown(on)
	end
	local gearShown = mode == "gear"
	for _, b in ipairs(p.slots) do b:SetShown(gearShown) end
	for _, r in ipairs(p.ranks) do r:SetShown(gearShown) end
	p.sep:SetShown(gearShown); p.selName:SetShown(gearShown); p.cur:SetShown(gearShown); p.hint:SetShown(gearShown)
	p.prep:SetShown(not gearShown)
	if not gearShown then
		local _, _, _, specName, class = SpecKey()
		local cr, cg, cb = ns.ClassTint(class)
		p.spec:SetText((UnitClass("player") or "") .. " · " .. (specName or ""))
		p.spec:SetTextColor(cr, cg, cb)
		p.pills:Refresh()
		p.example:SetText((self:SourceLabel():gsub("\n", "  ·  ")))
		self:PaintPrep()
		return
	end
	local _, _, _, specName, class = SpecKey()
	local cr, cg, cb = ns.ClassTint(class)
	p.spec:SetText((UnitClass("player") or "") .. " · " .. (specName or ""))
	p.spec:SetTextColor(cr, cg, cb)
	p.pills:Refresh()
	p.example:SetText((self:SourceLabel():gsub("\n", "  ·  ")))
	-- 부위별 목록 (순위 순)
	local bySlot = {}
	if self.levelMode and self.levelRanks then
		for slot, l in pairs(self.levelRanks) do bySlot[slot] = l end
	else
		for id, r in pairs(self.ranks) do
			bySlot[r.slot] = bySlot[r.slot] or {}
			table.insert(bySlot[r.slot], r)
		end
	end
	p.sumL:SetText(self.levelMode and "칸 레벨 최고템 착용" or "칸 BIS 착용")
	p.hint:SetText(self.levelMode and "마우스를 올리면 툴팁 · 획득처\n제작템은 클릭하면 제조법 상인 위치를 지도에 찍어요"
		or "마우스를 올리면 툴팁 · 획득처\n대체템은 BIS 장비의 능력치 비중으로 FOA가 고른 거예요")
	for _, list in pairs(bySlot) do table.sort(list, function(a, b) return a.rank < b.rank end) end
	local wornBis = 0
	self.bisSel = self.bisSel or 1
	for i, b in ipairs(p.slots) do
		local id = GetInventoryItemID("player", b.inv)
		local tex = GetInventoryItemTexture("player", b.inv)
		local q = GetInventoryItemQuality("player", b.inv)
		b.icon:Set(tex, q or 0, SLOT_GLYPH[b.ej])
		b.label:SetText(b.name)
		local r = id and self.ranks[id]
		local list = bySlot[b.ej]
		local a = C.accent
		if self.levelMode then r = nil; for _, x in ipairs(list or {}) do if x.it.id == id and x.rank == 0 then r = x end end end
		if r and r.rank == 0 then
			wornBis = wornBis + 1
			b.dot:SetVertexColor(C.green[1], C.green[2], C.green[3], 1)
			b.dot:Show()
		elseif list and #list > 0 then
			b.dot:SetVertexColor(a[1], a[2], a[3], 1)
			b.dot:Show()
		else
			b.dot:Hide()
		end
		local sel = self.bisSel == i
		b.hl:SetVertexColor(a[1], a[2], a[3], sel and 0.1 or 0)
		b.label:SetTextColor(sel and a[1] or C.text[1], sel and a[2] or C.text[2], sel and a[3] or C.text[3])
	end
	p.sumN:SetText(wornBis .. " / " .. #INV)
	-- 고른 부위
	local sb = p.slots[self.bisSel]
	p.selName:SetText(sb.name)
	local curID = GetInventoryItemID("player", sb.inv)
	local curLink = GetInventoryItemLink("player", sb.inv)
	local curR = curID and self.ranks[curID]
	local other = ViewSpecID() ~= CurrentSpecID()
	p.cur:SetText("지금: " .. (curLink or "비어 있음") .. (curR and ("  (" .. RankText(curR) .. ")") or "") .. (other and "  ·  다른 전문화 보는 중" or ""))
	local list = bySlot[sb.ej] or {}
	local a = C.accent
	for i, row in ipairs(p.ranks) do
		local r = list[i]
		if r then
			local it = r.it
			row.itemID, row.link, row.it = it.id, it.link, it
			row.icon:Set(it.icon, it.quality, SLOT_GLYPH[it.slot or -1])
			local q = QCOL[it.quality or 1] or QCOL[1]
			row.name:SetText(it.name or "불러오는 중…")
			row.name:SetTextColor(q[1], q[2], q[3])
			row.src:SetText(self:SourceText(it))
			local isBis = r.rank == 0
			row.badge:SetShown(isBis)
			if isBis then row.badge:Set(r) end
			row.rank:SetShown(not isBis)
			row.rank:SetText(r.rank)
			row.bg:SetVertexColor(isBis and a[1] or 1, isBis and a[2] or 1, isBis and a[3] or 1, isBis and 0.06 or 0.025)
			local worn = curID == it.id
			row.bd:SetVertexColor(worn and C.green[1] or (isBis and a[1] or 1), worn and C.green[2] or (isBis and a[2] or 1), worn and C.green[3] or (isBis and a[3] or 1), worn and 0.45 or (isBis and 0.45 or 0.06))
			row.state:SetText(worn and "착용 중" or "")
			row:Show()
		else
			row:Hide()
		end
	end
	if #list == 0 then
		p.ranks[1]:Show()
		local row = p.ranks[1]
		row.itemID, row.link, row.it = nil, nil, nil
		row.badge:Hide(); row.rank:Hide(); row.state:SetText("")
		row.icon:Set(nil, 0, "")
		if self.levelMode then
			row.name:SetText(self.levelPending and "아이템 정보를 받아 오는 중…" or "지금 갈 수 있는 던전에 이 부위 템이 없어요")
			row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
			row.src:SetText("내 레벨 + 4 까지의 던전 전리품 · 제작템 · 퀘스트 · 던전 퀘스트 보상에서 골라요")
		else
			row.name:SetText("이 부위는 레이드 · 던전 전리품에 없어요")
			row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
			row.src:SetText("제작 · 평판 · 레이드 등은 진짜 BIS 데이터가 연결되면 같이 나와요")
		end
		row.bg:SetVertexColor(1, 1, 1, 0.02)
		row.bd:SetVertexColor(1, 1, 1, 0.05)
	end
end

-- 캐릭터 창 아래 탭 줄 끝에 BIS 탭 (블리자드 탭은 건드리지 않고 같은 모양으로 따로 만든다)
function M:AttachBisTab()
	local cf = CharacterFrame
	if not cf or self.bisTab then return end
	local last
	for i = 1, 6 do
		local tab = _G["CharacterFrameTab" .. i]
		if tab and tab:IsShown() then last = tab end
	end
	-- 포에버 캐릭터 창: 오른쪽 세로 아이콘 줄(캐릭터 · 평판 · 기술 …) 맨 아래에 같은 크기의 BIS 칸
	local modeTabs = cf.ModeTabs and cf.ModeTabs.Tabs
	local t = CreateFrame("Button", "FOABisTab", cf)
	local side = not last
	local vertical = side and modeTabs and #modeTabs > 0
	t.bg = Ink:Round(t, "BACKGROUND", true, false, -8)
	t.bd = Ink:Round(t, "BORDER", true, true, -8)
	if vertical then
		local function lastTab()
			local lt, lb
			for _, tab in ipairs(modeTabs) do
				if tab:IsShown() then
					local b = tab:GetBottom()
					if not lb or (b and b < lb) then lt, lb = tab, b end
				end
			end
			return lt or modeTabs[#modeTabs]
		end
		local ref = lastTab()
		local w, h = ref:GetSize()
		w, h = (w and w > 10) and w or 44, (h and h > 10) and h or 44
		t:SetSize(w, h)
		t:SetPoint("TOP", ref, "BOTTOM", 0, -8)
		t:SetFrameLevel(ref:GetFrameLevel() + 2)
		t.relayout = function()
			local r = lastTab()
			if r and r ~= t then t:ClearAllPoints(); t:SetPoint("TOP", r, "BOTTOM", 0, -8) end
		end
		t.bg:SetPoint("TOPLEFT", 2, -2)
		t.bg:SetPoint("BOTTOMRIGHT", -2, 2)
		t.bd:SetPoint("TOPLEFT", 2, -2)
		t.bd:SetPoint("BOTTOMRIGHT", -2, 2)
		t.label = Ink:Text(t, F.bold, 13, C.accent, "CENTER")
		t.label:SetPoint("CENTER", 0, 4)
		t.label:SetText("BIS")
		t.sub = Ink:Text(t, F.sans, 8, C.muted, "CENTER")
		t.sub:SetPoint("TOP", t.label, "BOTTOM", 0, -2)
		t.sub:SetText("최고템")
		t.line = t:CreateTexture(nil, "OVERLAY")
		t.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
		t.line:SetSize(2, h - 16)
		t.line:SetPoint("LEFT", 0, 0)
	elseif side then
		t:SetSize(46, 22)
		t:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -30, -3)
		t:SetFrameLevel(cf:GetFrameLevel() + 20)
		t.bg:SetPoint("TOPLEFT", 3, -2); t.bg:SetPoint("BOTTOMRIGHT", -3, 3)
		t.bd:SetAllPoints(t.bg)
	else
		t:SetSize(70, 32)
		t:SetPoint("LEFT", last, "RIGHT", 2, 0)
		t.bg:SetPoint("TOPLEFT", 3, -2); t.bg:SetPoint("BOTTOMRIGHT", -3, 3)
		t.bd:SetAllPoints(t.bg)
	end
	if not t.label then
		t.label = Ink:Text(t, F.semi, 12, C.muted, "CENTER")
		t.label:SetPoint("CENTER")
		t.label:SetText("BIS")
		t.line = t:CreateTexture(nil, "OVERLAY")
		t.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
		t.line:SetSize(18, 2)
		t.line:SetPoint("BOTTOM", 0, side and 2 or 5)
	end
	local a = C.accent
	local function paint(hover)
		local on = M.bisPanel and M.bisPanel:IsShown()
		if vertical then
			-- 늘 노란 BIS 글자로 눈에 띄게, 열려 있으면 칸 전체가 은은하게 노랗게
			t.bg:SetVertexColor(on and 0.12 or (hover and 0.09 or 0.05), on and 0.115 or (hover and 0.09 or 0.055), on and 0.06 or (hover and 0.1 or 0.07), 0.95)
			t.bd:SetVertexColor(a[1], a[2], a[3], on and 0.75 or (hover and 0.5 or 0.28))
			t.label:SetTextColor(a[1], a[2], a[3])
			t.sub:SetTextColor(on and a[1] or C.muted[1], on and a[2] or C.muted[2], on and a[3] or C.muted[3])
		else
			t.label:SetTextColor(on and a[1] or C.muted[1], on and a[2] or C.muted[2], on and a[3] or C.muted[3])
			t.bg:SetVertexColor(on and 0.06 or 0.035, on and 0.065 or 0.04, on and 0.08 or 0.052, 0.94)
			t.bd:SetVertexColor(1, 1, 1, on and 0.14 or 0.06)
		end
		t.line:SetShown(on and true or false)
	end
	t:SetScript("OnClick", function()
		if not M.bisPanel then M:BuildBisPanel() end
		local p = M.bisPanel
		if p:IsShown() then p:Hide() else
			p:ClearAllPoints()
			-- 캐릭터 창 오른쪽 세로 아이콘 줄 바로 너머에, 캐릭터 창과 같은 높이로 붙여서
			local edge = vertical and t or cf
			p:SetPoint("TOP", cf, "TOP", 0, 0)
			p:SetPoint("LEFT", edge, "RIGHT", vertical and 6 or (side and 64 or 10), 0)
			p:SetHeight(math.max(590, cf:GetHeight()))
			p:Show()
		end
		paint()
	end)
	t:SetScript("OnEnter", function(self)
		paint(true)
		if not vertical then t.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("BIS · 부위별 최고템", 1, 1, 1)
		GameTooltip:AddLine("만렙 전에는 지금 레벨에 맞는 최고템", 0.7, 0.72, 0.75)
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function() paint(); GameTooltip:Hide() end)
	cf:HookScript("OnHide", function() if M.bisPanel then M.bisPanel:Hide() end paint() end)
	cf:HookScript("OnShow", function() if t.relayout then pcall(t.relayout) end paint() end)
	paint()
	self.bisTab = t
end

-------------------------------------------------------------------------------
-- 테스트 모드: 지도 없이도 사이드바 · 알림을 볼 수 있게
-------------------------------------------------------------------------------
function M:SetTest(on)
	if FOREVER then
		-- 포에버는 던전 도감이 비어 있어서 지도 옆 칸 예시를 포에버 던전 목록으로
		if not (Ink.db.dungeon and ns.FOREVER_LOOT) then return end
		self.testing = on
		if not on then self:HideSidebar(); self:UpdateMap(); return end
		self:ShowFor(self:ForeverCurrent(), nil)
		return
	end
	if not Available() or not Ink.db.dungeon then return end
	self.testing = on
	if not on then
		self:HideSidebar()
		self:UpdateMap()
		return
	end
	local jid = self:CurrentInstance()
	if not jid then
		local list = self:TierDungeons()
		jid = list[1]
	end
	if not jid then return end
	self:ShowFor(jid, nil)
	local data = self:Scan(jid)
	local c = self.rankCount[jid] or { bis = 0, alt = 0 }
	self:Toast(data and data.name, c.bis, c.alt)
end

-------------------------------------------------------------------------------
function M:Init()
	if Ink.db.dungeon == false then return end
	if FOREVER then
		-- 포에버: 던전 도감이 없어서 지도 옆 전리품 칸은 끄고, 캐릭터 창 BIS 탭(공략 BIS · 준비물)만
		if not ns.BIS_FOREVER then return end
		self:HookTooltip()
		self:AttachBisTab()
		if ns.FOREVER_LOOT then self:HookMap() end
		local e = CreateFrame("Frame")
		for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT",
			"CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT" }) do pcall(e.RegisterEvent, e, ev) end
		-- 던전 입장 · 보스 처치 (진행 경로)
		local w = CreateFrame("Frame")
		for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_END", "BOSS_KILL", "PLAYER_TARGET_CHANGED",
			"LOOT_OPENED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_REGEN_ENABLED" }) do
			pcall(w.RegisterEvent, w, ev)
		end
		pcall(w.RegisterUnitEvent, w, "UNIT_HEALTH", "target")
		w:SetScript("OnEvent", function(_, event, a1, a2, _, _, a5)
			if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
				if event == "PLAYER_ENTERING_WORLD" then M.visit = (M.visit or 0) + 1; M.wingSeen = nil; M.enterTries = 0 end
				C_Timer.After(1, function() pcall(M.OnForeverEnter, M) end)
			elseif event == "ENCOUNTER_END" then
				if plain(a5) == 1 then pcall(M.OnBossKilled, M, a2, a1) end
			elseif event == "BOSS_KILL" then
				pcall(M.OnBossKilled, M, a2, a1)
			elseif event == "LOOT_OPENED" then
				if M.hereKey then pcall(M.CheckLoot, M) end
			elseif event == "UPDATE_MOUSEOVER_UNIT" then
				if IsInInstance() and not InCombatLockdown() then pcall(M.SeeBoss, M, "mouseover") end
				if not M.hereKey and IsInInstance() then pcall(M.LearnHere, M, "mouseover") end
				if M.hereKey and not InCombatLockdown() then pcall(M.CheckDead, M, "mouseover") end
			elseif event == "PLAYER_REGEN_ENABLED" then
				-- 전투 중엔 사망 여부가 비공개라 못 읽은 것: 전투가 끝나면 대상을 다시 본다
				if M.hereKey then C_Timer.After(0.3, function() pcall(M.SeeBoss, M, "target"); pcall(M.CheckDead, M, "target") end) end
			else
				if event == "PLAYER_TARGET_CHANGED" and IsInInstance() then pcall(M.SeeBoss, M, "target") end
				if not M.hereKey and IsInInstance() then pcall(M.LearnHere, M, "target") end
				if M.hereKey then pcall(M.CheckDead, M, "target") end
			end
		end)
		local pending
		e:SetScript("OnEvent", function(_, event, a1, a2)
			if event == "QUEST_DATA_LOAD_RESULT" and a2 == false and a1 then M.questFail[plain(a1) or a1] = true end
			if event == "ADDON_LOADED" then
				if not M.bisTab then M:AttachBisTab() end
				if not M.mapHooked and ns.FOREVER_LOOT then M:HookMap() end
				return
			end
			if event == "QUEST_DATA_LOAD_RESULT" then
				-- 퀘스트 이름이 도착: 순위는 그대로, 글자와 열린 툴팁만 다시
				if M.questNamePend then return end
				M.questNamePend = true
				C_Timer.After(0.3, function()
					M.questNamePend = nil
					if M.bisPanel and M.bisPanel:IsShown() then pcall(M.PaintBis, M) end
					local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
					if owner and owner.it and owner.it.quest and owner:GetScript("OnEnter") then pcall(owner:GetScript("OnEnter"), owner) end
				end)
				return
			end
			if event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then M.dirty = true end
			if pending then return end
			pending = true
			C_Timer.After(0.5, function()
				pending = nil
				if event ~= "PLAYER_EQUIPMENT_CHANGED" then M.dirty = true end
				M:PaintBis()
				M:PaintSidebar()
			end)
		end)
		C_Timer.After(8, function() pcall(M.BuildRanks, M) end)
		return
	end
	if not Available() then return end
	self:HookTooltip()
	self:HookMap()
	self:AttachBisTab()
	-- 툴팁에 순위가 바로 나오게 접속 후 미리 한 번 계산
	C_Timer.After(8, function() pcall(M.BuildRanks, M) end)
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "EJ_LOOT_DATA_RECIEVED", "PLAYER_SPECIALIZATION_CHANGED",
		"ADDON_LOADED", "PLAYER_EQUIPMENT_CHANGED", "ENCOUNTER_END", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local pending
	e:SetScript("OnEvent", function(_, event, arg)
		if event == "PLAYER_ENTERING_WORLD" then
			M:OnEnterWorld()
		elseif event == "ADDON_LOADED" then
			if not M.mapHooked then M:HookMap() end
			if not M.bisTab then M:AttachBisTab() end
		elseif event == "PLAYER_EQUIPMENT_CHANGED" then
			M:PaintBis()
		elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
			-- 아이템 이름 · 능력치가 늦게 도착: 순위(대체템 점수)와 화면만 다시
			if not (M.bisPanel and M.bisPanel:IsShown()) and not (M.sidebar and M.sidebar:IsShown()) then
				M.dirty = true
				return
			end
			if pending then return end
			pending = true
			C_Timer.After(0.5, function()
				pending = nil
				M.dirty = true
				M:PaintSidebar()
				M:PaintBis()
			end)
		else
			-- 아이템 정보 도착 / 전문화 변경 / 보스 처치: 잠깐 모아서 다시 그리기
			if event ~= "ENCOUNTER_END" then
				M.dirty = true
				for _, d in pairs(M.cache) do d.missing = 1 end
			end
			if pending then return end
			pending = true
			C_Timer.After(0.5, function()
				pending = nil
				M:PaintSidebar()
				M:PaintBis()
			end)
		end
	end)
	Ink.ProfFrame(e, "던전")
end
