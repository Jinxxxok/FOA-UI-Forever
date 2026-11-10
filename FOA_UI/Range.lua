-- FOA UI · 사거리 표시
--  대상까지 거리를 "25–30" 처럼 작게 보여 준다. 색으로 바로 알 수 있게:
--   빨강 = 내 주문 사거리 밖 · 노랑 = 사거리 끝자락 · 초록 = 사거리 안 · 주황 = 바짝 붙음(근접)
--  거리는 내가 배운 주문들의 사거리(시전 가능 여부)로 좁혀서 잰다. 파티원은 정확한 거리.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Range")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local W, H = 96, 24

-------------------------------------------------------------------------------
-- 주문 목록: 사거리가 있는 내 주문 (최소 사거리 없는 것만), 사거리마다 하나씩
-------------------------------------------------------------------------------
local harmList, helpList = {}, {}
local harmMax, helpMax = 0, 0

local function AddSpell(id, seenH, seenF)
	local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
	if not info then return end
	local mx, mn = info.maxRange, info.minRange or 0
	if not mx or mx <= 0 or mx > 100 or mn > 0 then return end
	mx = math.floor(mx + 0.5)
	local harm = C_Spell.IsSpellHarmful and C_Spell.IsSpellHarmful(id)
	local help = C_Spell.IsSpellHelpful and C_Spell.IsSpellHelpful(id)
	if harm and not seenH[mx] then seenH[mx] = true; harmList[#harmList + 1] = { id = id, max = mx } end
	if help and not seenF[mx] then seenF[mx] = true; helpList[#helpList + 1] = { id = id, max = mx } end
end

function M:ScanSpells()
	wipe(harmList); wipe(helpList)
	local seenH, seenF = {}, {}
	pcall(function()
		local SB = C_SpellBook
		if not (SB and SB.GetNumSpellBookSkillLines) then return end
		local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
		for i = 1, SB.GetNumSpellBookSkillLines() do
			local li = SB.GetSpellBookSkillLineInfo(i)
			if li and not li.shouldHide then
				local off = li.itemIndexOffset or 0
				for j = off + 1, off + (li.numSpellBookItems or 0) do
					local it = SB.GetSpellBookItemInfo(j, bank)
					if it and it.spellID and not it.isPassive and not it.isOffSpec
						and (not spellType or it.itemType == spellType) then
						AddSpell(it.spellID, seenH, seenF)
					end
				end
			end
		end
	end)
	table.sort(harmList, function(a, b) return a.max < b.max end)
	table.sort(helpList, function(a, b) return a.max < b.max end)
	harmMax = harmList[#harmList] and math.min(40, harmList[#harmList].max) or 0
	helpMax = helpList[#helpList] and math.min(40, helpList[#helpList].max) or 0
end

-------------------------------------------------------------------------------
-- 거리 재기: lo(이보다 멀다) ~ hi(이보다 가깝다)
-------------------------------------------------------------------------------
local function Exact(unit)
	if not UnitDistanceSquared then return end
	local ok, d2, checked = pcall(UnitDistanceSquared, unit)
	d2, checked = ok and plain(d2), ok and plain(checked)
	if d2 and checked and d2 > 0 then return math.sqrt(d2) end
end

local function InteractAllowed()
	if InCombatLockdown() then return false end
	local inInst, kind = IsInInstance()
	return not (inInst and kind ~= "none")
end

function M:Measure(unit)
	local d = Exact(unit)
	if d then return d, d, true end
	local friendly = plain(UnitIsFriend("player", unit))
	local list = friendly and helpList or harmList
	local lo, hi = 0, nil
	for _, e in ipairs(list) do
		local ok, v = pcall(C_Spell.IsSpellInRange, e.id, unit)
		v = ok and plain(v)
		if v == true then
			if not hi or e.max < hi then hi = e.max end
		elseif v == false then
			if e.max > lo then lo = e.max end
		end
	end
	-- 전투 밖 · 필드에서는 상호작용 거리도 쓴다 (약 10미터 · 28미터)
	if InteractAllowed() and CheckInteractDistance then
		for _, p in ipairs({ { 3, 10 }, { 4, 28 } }) do
			local ok, v = pcall(CheckInteractDistance, unit, p[1])
			v = ok and plain(v)
			if v == true then
				if not hi or p[2] < hi then hi = p[2] end
			elseif v == false then
				if p[2] > lo then lo = p[2] end
			end
		end
	end
	if hi and lo >= hi then lo = 0 end
	if not hi and lo == 0 then return end
	return lo, hi, false
end

-------------------------------------------------------------------------------
-- 화면
-------------------------------------------------------------------------------
local COL = {
	far = { 1.00, 0.42, 0.37 },   -- 사거리 밖
	edge = { 1.00, 0.84, 0.35 },  -- 끝자락
	ok = { 0.44, 0.83, 0.60 },    -- 사거리 안
	close = { 1.00, 0.66, 0.30 }, -- 근접
}

function M:Build()
	local f = CreateFrame("Frame", "FOARangeDisplay", Ink.root)
	f:SetSize(W, H)
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(false)
	f.dot = f:CreateTexture(nil, "ARTWORK")
	f.dot:SetTexture(Ink.tex.disc)
	f.dot:SetSize(6, 6)
	f.txt = Ink:Text(f, F.latinB, 15, C.text, "CENTER")
	f.txt:SetPoint("CENTER", 4, 0)
	f.dot:SetPoint("RIGHT", f.txt, "LEFT", -5, 0)
	f.unit = Ink:Text(f, F.latin, 10, C.muted, "LEFT")
	f.unit:SetPoint("BOTTOMLEFT", f.txt, "BOTTOMRIGHT", 2, 1)
	f.unit:SetText("m")
	f:Hide()
	self.frame = f
	Ink:Movable("range", "사거리", f, "center", (1920 - W) / 2, 600)
end

function M:Paint(lo, hi, exact, unit)
	local f = self.frame
	local friendly = plain(UnitIsFriend("player", unit))
	local maxR = friendly and helpMax or harmMax
	if maxR <= 0 then maxR = 30 end
	local text, col
	if exact then
		text = tostring(math.floor(lo + 0.5))
		hi = lo
	elseif hi then
		text = (lo > 0) and string.format("%d–%d", lo, hi) or string.format("0–%d", hi)
	else
		text = lo .. "+"
	end
	if not hi or hi > maxR then
		col = COL.far
	elseif hi <= 8 then
		col = COL.close
	elseif (exact and hi >= maxR - 5) or (not exact and lo >= maxR - 5) then
		col = COL.edge
	else
		col = COL.ok
	end
	f.txt:SetText(text)
	f.txt:SetTextColor(col[1], col[2], col[3])
	f.dot:SetVertexColor(col[1], col[2], col[3], 1)
	f:Show()
end

function M:Update()
	local f = self.frame
	if not f or self.testing then return end
	local u = "target"
	if not UnitExists(u) or plain(UnitIsUnit(u, "player")) then f:Hide() return end
	local lo, hi, exact = self:Measure(u)
	if not lo then f:Hide() return end
	self:Paint(lo, hi, exact, u)
end

function M:SetTest(on)
	if not self.frame then return end
	self.testing = on
	if on then
		self.frame.txt:SetText("25–30")
		self.frame.txt:SetTextColor(COL.ok[1], COL.ok[2], COL.ok[3])
		self.frame.dot:SetVertexColor(COL.ok[1], COL.ok[2], COL.ok[3], 1)
		self.frame:Show()
	else
		self:Update()
	end
end

function M:Init()
	if Ink.db.range == false then return end
	self:Build()
	self:ScanSpells()
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_TARGET_CHANGED", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "LEARNED_SPELL_IN_TAB",
		"PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local rescan
	e:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_TARGET_CHANGED" then M:Update() return end
		if rescan then return end
		rescan = true
		C_Timer.After(1, function() rescan = nil; M:ScanSpells(); M:Update() end)
	end)
	local t = 0
	e:SetScript("OnUpdate", function(_, el)
		t = t + el
		if t < 0.1 then return end
		t = 0
		if UnitExists("target") then M:Update() elseif M.frame:IsShown() and not M.testing then M.frame:Hide() end
	end)
	Ink.ProfFrame(e, "거리 표시")
end
