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

local function Available()
	return C_EncounterJournal and EJ_SelectInstance and EJ_GetNumLoot and C_EncounterJournal.GetLootInfoByIndex and true or false
end

-- 내 직업의 전문화 목록 { {id, name, icon}, ... }
local function Specs()
	local list = {}
	if FOREVER then
		-- 포에버: 전문화 대신 특성 트리 (FOA 아이템 점수와 같은 이름표)
		local sc = ns.Score
		local _, class = UnitClass("player")
		local tabs = sc and sc.TABS and sc.TABS[class] or {}
		for t, key in ipairs(tabs) do
			local a, b, c, d = GetTalentTabInfo and GetTalentTabInfo(t)
			local icon = (type(b) == "number" and b) or (type(d) == "number" and d) or nil
			list[#list + 1] = { id = key, name = sc.SPEC_NAME[key] or key, icon = icon }
			if class == "DRUID" and key == "feral" then
				list[#list + 1] = { id = "guardian", name = sc.SPEC_NAME.guardian or "수호", icon = icon }
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
		local _, spec = ns.Score and ns.Score:Spec()
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

function M:Scan(jid)
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
		elseif C_Item.RequestLoadItemDataByID then
			pcall(C_Item.RequestLoadItemDataByID, id)
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
	if not name and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
	local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
	local _, link = C_Item.GetItemInfo(id)
	local data = ns.BIS
	local src = (data and data.crafted[id]) and "전문기술 제작"
		or (data and data.tier[id]) and "티어 세트 · 레이드 / 촉매"
		or "기타 (평판 · 상점 · 월드 드랍 등)"
	return { id = id, name = name, icon = icon, quality = q or 4, link = link, srcText = src }
end

-- 아이템 출처 글자
function M:SourceText(it)
	if it.srcText then return it.srcText end
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

-- 포에버: 공략 BIS (g) = BIS, 공략 대체(alt) 순서 = 대체 1~3 (던전 도감이 없어서 전리품 표 대신 공략 목록)
function M:BuildRanksForever()
	local key = SpecKey()
	if self.rankKey == key and not self.dirty then return end
	self.rankKey, self.dirty = key, nil
	wipe(self.ranks)
	wipe(self.rankCount)
	local spec = ns.BIS_FOREVER and ns.BIS_FOREVER.specs[key]
	self.spec = spec and { src = ns.BIS_FOREVER.src, g = spec.g, fo = spec } or nil
	self.isExample = false
	if not spec then return end
	local per = {}
	for inv, id in pairs(spec.g) do
		local slot = INV2EJ[inv]
		if slot then
			local it = LooseItem(id)
			it.slot, it.srcText = slot, KoSource(spec.src[id])
			self.ranks[id] = { rank = 0, slot = slot, it = it, inv = inv }
		end
	end
	for _, a in ipairs(spec.alt) do
		local inv, id = a[1], a[2]
		local slot = INV2EJ[inv]
		if slot and not self.ranks[id] then
			per[slot] = (per[slot] or 0) + 1
			if per[slot] <= 3 then
				local it = LooseItem(id)
				it.slot, it.srcText = slot, KoSource(spec.src[id])
				self.ranks[id] = { rank = per[slot], slot = slot, it = it, inv = inv }
			end
		end
	end
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
	if FOREVER then
		return self.spec and ("BIS · 대체: " .. self.spec.src .. " (레이드 전)") or "이 특성은 공략 자료 준비 중"
	end
	if self.spec then return "BIS: " .. self.spec.src .. " · 대체: FOA 계산" end
	return "예시 순위 (BIS 자료 없음)"
end

local function RankText(r)
	if not r then return nil end
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
			self.text:SetFont(F.latinB, 10, "")
			self.text:SetTextColor(0.05, 0.055, 0.07)
			self.text:SetText("BIS")
			self:SetWidth(34)
		else
			self.fill:SetVertexColor(a[1], a[2], a[3], 0.06)
			self.line:SetVertexColor(a[1], a[2], a[3], 0.6)
			self.text:SetFont(F.semi, 10, "")
			self.text:SetTextColor(a[1], a[2], a[3])
			self.text:SetText("대체 " .. r.rank)
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
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetColorTexture(1, 1, 1, 0.06)
	f.line:SetHeight(1)
	f.line:SetPoint("TOPLEFT", 12, -150)
	f.line:SetPoint("TOPRIGHT", -12, -150)
	-- 목록 (휠로 스크롤)
	local sf = CreateFrame("ScrollFrame", nil, f)
	sf:SetPoint("TOPLEFT", 8, -156)
	sf:SetPoint("BOTTOMRIGHT", -8, 10)
	local body = CreateFrame("Frame", nil, sf)
	body:SetSize(SB_W - 16, 10)
	sf:SetScrollChild(body)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, d)
		local r = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(math.max(0, math.min(r, self:GetVerticalScroll() - d * 44)))
	end)
	f.sf, f.body = sf, body
	f.heads, f.rows = {}, {}
	f.empty = Ink:Text(body, F.sans, 11, C.dim, "CENTER")
	f.empty:SetPoint("TOP", 0, -30)
	f.empty:SetWidth(SB_W - 40)
	f.empty:SetWordWrap(true)
	self.sidebar = f
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
	local data = jid and self:Scan(jid)
	self:BuildRanks(jid)
	local key, _, _, specName, class = SpecKey()
	local cr, cg, cb = ns.ClassTint(class)
	f.tag:SetText((self.isRaid and self.isRaid[jid]) and "RAID LOOT" or "DUNGEON LOOT")
	f.title:SetText(data and data.name or "던전")
	f.spec:SetText((UnitClass("player") or "") .. " · " .. (specName or ""))
	f.spec:SetTextColor(cr, cg, cb)
	f.pills:Refresh()
	f.example:SetText(self.isExample and "예시 순위 (BIS 자료 없음)" or ("BIS · " .. self.spec.src))
	local cnt = self.rankCount[jid] or { bis = 0, alt = 0 }
	f.nBis:SetText(cnt.bis)
	f.nAlt:SetText(cnt.alt)
	local all = Ink.db.dungeonAll
	f.mine.text:SetText(all and "전부 보기" or "내 장비만")
	local a = C.accent
	f.mine.bg:SetVertexColor(a[1], a[2], a[3], all and 0.02 or 0.1)
	f.mine.bd:SetVertexColor(a[1], a[2], a[3], all and 0.3 or 0.6)

	local body = f.body
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
				if all or r then list[#list + 1] = it end
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
			local done = false
			if C_EncounterJournal.IsEncounterComplete and b.id then
				local ok, v = pcall(C_EncounterJournal.IsEncounterComplete, b.id)
				done = ok and plain(v) and true or false
			end
			local col = done and C.green or (nb > 0 and a or { 0.75, 0.77, 0.8 })
			h.ring:SetVertexColor(col[1], col[2], col[3], 1)
			h.num:SetText(b.index)
			h.num:SetTextColor(col[1], col[2], col[3])
			h.name:SetText(b.name)
			h.sum:SetText(done and "처치함" or ((nb > 0 and ("BIS " .. nb) or "") .. ((nb > 0 and na > 0) and " · " or "") .. (na > 0 and ("대체 " .. na) or "")))
			h:SetAlpha(done and 0.55 or 1)
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
				row.name:SetText(it.name or "불러오는 중…")
				row.name:SetTextColor(q[1], q[2], q[3])
				local sub = it.slotText or SLOT_NAME[it.slot or -1] or ""
				if it.armor and it.armor ~= "" then sub = sub .. " · " .. it.armor end
				row.sub:SetText(sub)
				row.badge:Set(r)
				row.isBis = r and r.rank == 0
				row.hl:SetVertexColor(1, 1, 1, row.isBis and 0.04 or 0)
				row.bisBd:SetVertexColor(a[1], a[2], a[3], row.isBis and 0.4 or 0)
				row:SetAlpha(done and 0.55 or 1)
				row:Show()
				y = y + ROW_H + 2
			end
			y = y + 6
		end
	end
	f.empty:SetShown(nr == 0)
	f.empty:SetText(data and (all and "여기에는 내 직업 전리품이 없어요" or "여기선 내 BIS · 대체템이 안 나와요\n(오른쪽 위 버튼으로 전부 보기)") or "전리품 정보를 불러오는 중…")
	body:SetHeight(math.max(10, y))
end

-- 지도 옆에 붙이기 / 떼기
function M:ShowFor(jid, anchor)
	if not jid or not Ink.db.dungeon then return self:HideSidebar() end
	if not self.sidebar then self:BuildSidebar() end
	local f = self.sidebar
	self.showing = jid
	f:ClearAllPoints()
	if anchor then
		f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
		f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 0)
		f:SetScale(1)
	else
		f:SetHeight(620)
		f:SetPoint("RIGHT", Ink.root, "RIGHT", -300, 40)
	end
	f:Show()
	f.sf:SetVerticalScroll(0)
	self:PaintSidebar()
end

function M:HideSidebar()
	if self.sidebar then self.sidebar:Hide() end
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

function M:UpdateMap()
	if self.testing then return end
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
	wm:HookScript("OnHide", function() if not M.testing then M:HideSidebar() end end)
	if wm.OnMapChanged then hooksecurefunc(wm, "OnMapChanged", function() M:UpdateMap() end) end
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

function M:Toast(name, nb, na)
	if not self.toast then self:BuildToast() end
	local t = self.toast
	t.title:SetText((name or "던전") .. " 입장")
	t.sub:SetText(string.format("내 장비  |cffFFF468BIS %d|r  ·  대체 %d  ·  지도(M)에서 보스별로 보기", nb or 0, na or 0))
	t:SetAlpha(1)
	t:Show()
	t.ag:Stop()
	t.ag:Play()
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
		if not r then return end
		local _, _, _, specName = SpecKey()
		tt:AddLine(" ")
		tt:AddLine("|cffFFF468—|r  |cff8E939BFOA · " .. (UnitClass("player") or "") .. " " .. (specName or "") .. (M.isExample and " · 예시 순위" or "") .. "|r")
		local label = r.rank == 0 and "|cffFFF468BIS|r" or ("|cffFFF468대체 " .. r.rank .. "|r")
		tt:AddDoubleLine(label .. "  " .. (SLOT_NAME[r.slot] or "") .. " " .. (r.rank + 1) .. "순위", " ", 1, 1, 1)
		tt:AddDoubleLine("|cff9EA3AB획득|r", M:SourceText(r.it), 1, 1, 1, 1, 1, 1)
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
	p.example = Ink:Text(p, F.sans, 10, C.dim, "RIGHT")
	p.example:SetPoint("TOPRIGHT", p.pills, "BOTTOMRIGHT", 0, -12)
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
		b:SetPoint("TOPLEFT", 12, -78 - (i - 1) * 26)
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
	p.sep:SetPoint("TOPLEFT", 172, -76)
	p.sep:SetPoint("BOTTOMLEFT", 172, 14)
	p.selName = Ink:Text(p, F.bold, 14, C.text, "LEFT")
	p.selName:SetPoint("TOPLEFT", 186, -84)
	p.cur = Ink:Text(p, F.sans, 10, C.muted, "LEFT")
	p.cur:SetPoint("TOPLEFT", p.selName, "BOTTOMLEFT", 0, -4)
	p.cur:SetWidth(BP_W - 204)
	p.ranks = {}
	for i = 1, 5 do
		local r = CreateFrame("Button", nil, p)
		r:SetSize(BP_W - 200, 54)
		r:SetPoint("TOPLEFT", 184, -126 - (i - 1) * 60)
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
				GameTooltip:Show()
			end
		end)
		r:SetScript("OnLeave", GameTooltip_Hide)
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
		b:SetPoint("TOPLEFT", 186 + (i - 1) * 62, -48)
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
	f:SetPoint("TOPLEFT", 12, -82)
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
			if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
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
		p.example:SetText(self:SourceLabel())
		self:PaintPrep()
		return
	end
	local _, _, _, specName, class = SpecKey()
	local cr, cg, cb = ns.ClassTint(class)
	p.spec:SetText((UnitClass("player") or "") .. " · " .. (specName or ""))
	p.spec:SetTextColor(cr, cg, cb)
	p.pills:Refresh()
	p.example:SetText(self:SourceLabel())
	-- 부위별 목록 (순위 순)
	local bySlot = {}
	for id, r in pairs(self.ranks) do
		bySlot[r.slot] = bySlot[r.slot] or {}
		table.insert(bySlot[r.slot], r)
	end
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
			row.itemID, row.link = it.id, it.link
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
		row.itemID, row.link = nil, nil
		row.badge:Hide(); row.rank:Hide(); row.state:SetText("")
		row.icon:Set(nil, 0, "")
		row.name:SetText("이 부위는 레이드 · 던전 전리품에 없어요")
		row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		row.src:SetText("제작 · 평판 · 레이드 등은 진짜 BIS 데이터가 연결되면 같이 나와요")
		row.bg:SetVertexColor(1, 1, 1, 0.02)
		row.bd:SetVertexColor(1, 1, 1, 0.05)
	end
end

-- 캐릭터 창 아래 탭 줄 끝에 BIS 탭 (블리자드 탭은 건드리지 않고 같은 모양으로 따로 만든다)
function M:AttachBisTab()
	local cf = CharacterFrame
	if not cf or self.bisTab then return end
	local last
	for i = 1, 6 do if _G["CharacterFrameTab" .. i] then last = _G["CharacterFrameTab" .. i] end end
	if not last then return end
	local t = CreateFrame("Button", "FOABisTab", cf)
	t:SetSize(70, 32)
	t:SetPoint("LEFT", last, "RIGHT", 2, 0)
	t.bg = Ink:Round(t, "BACKGROUND", true, false, -8)
	t.bg:SetPoint("TOPLEFT", 3, -2)
	t.bg:SetPoint("BOTTOMRIGHT", -3, 3)
	t.label = Ink:Text(t, F.semi, 12, C.muted, "CENTER")
	t.label:SetPoint("CENTER")
	t.label:SetText("BIS")
	t.line = t:CreateTexture(nil, "OVERLAY")
	t.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	t.line:SetSize(18, 2)
	t.line:SetPoint("BOTTOM", 0, 5)
	local function paint()
		local on = M.bisPanel and M.bisPanel:IsShown()
		t.label:SetTextColor(on and C.accent[1] or C.muted[1], on and C.accent[2] or C.muted[2], on and C.accent[3] or C.muted[3])
		t.line:SetShown(on and true or false)
		t.bg:SetVertexColor(on and 0.06 or 0.035, on and 0.065 or 0.04, on and 0.08 or 0.052, 0.94)
	end
	t:SetScript("OnClick", function()
		if not M.bisPanel then M:BuildBisPanel() end
		local p = M.bisPanel
		if p:IsShown() then p:Hide() else
			p:ClearAllPoints()
			p:SetPoint("TOPLEFT", cf, "TOPRIGHT", 10, 0)
			p:SetHeight(math.max(570, cf:GetHeight()))
			p:Show()
		end
		paint()
	end)
	t:SetScript("OnEnter", function() t.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
	t:SetScript("OnLeave", paint)
	cf:HookScript("OnHide", function() if M.bisPanel then M.bisPanel:Hide() end paint() end)
	paint()
	self.bisTab = t
end

-------------------------------------------------------------------------------
-- 테스트 모드: 지도 없이도 사이드바 · 알림을 볼 수 있게
-------------------------------------------------------------------------------
function M:SetTest(on)
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
		local e = CreateFrame("Frame")
		for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT",
			"CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do pcall(e.RegisterEvent, e, ev) end
		local pending
		e:SetScript("OnEvent", function(_, event)
			if event == "ADDON_LOADED" then
				if not M.bisTab then M:AttachBisTab() end
				return
			end
			if event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then M.dirty = true end
			if pending then return end
			pending = true
			C_Timer.After(0.5, function()
				pending = nil
				if event ~= "PLAYER_EQUIPMENT_CHANGED" then M.dirty = true end
				M:PaintBis()
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
end
