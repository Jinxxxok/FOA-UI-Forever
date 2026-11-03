-- InkUI · 파티 / 레이드 프레임 (+ 테스트 모드 예시)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Group")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

Ink.dispel[0] = { 1, 1, 1, 0.16 } -- 종류 없는 디버프 테두리

local P_W, P_H, P_GAP = 240, 66, 12
local R_W, R_H, R_GAP, R_COLGAP = 66, 38, 3, 4

-------------------------------------------------------------------------------
-- 공용
-------------------------------------------------------------------------------
local ROLE = {
	TANK = { tex = Ink.tex.roleTank, col = C.tank, label = "탱커" },
	HEALER = { tex = Ink.tex.roleHealer, col = C.healer, label = "힐러" },
	DAMAGER = { tex = Ink.tex.roleDps, col = C.dps, label = "딜러" },
}

local function RoleIcon(parent, size)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetSize(size, size)
	t:Hide()
	return t
end

local function SetRole(t, role, onlyTankHealer)
	local r = ROLE[role or ""]
	if not r or (onlyTankHealer and role == "DAMAGER") then
		t:Hide()
		return
	end
	t:SetTexture(r.tex)
	t:SetVertexColor(r.col[1], r.col[2], r.col[3])
	t:Show()
end

-- 해제 가능한 디버프가 있으면 그 종류 색을 돌려준다 (플레이어가 해제할 수 있는 것만)
local function DispelColor(unit)
	if not (C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDispelTypeColor) then return end
	local curve = ns.DispelCurve()
	if not curve then return end
	local ok, col = pcall(function()
		local slots = { C_UnitAuras.GetAuraSlots(unit, "HARMFUL|RAID", 1) }
		if #slots < 2 then return nil end
		local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[2])
		if not data then return nil end
		return C_UnitAuras.GetAuraDispelTypeColor(unit, data.auraInstanceID, curve)
	end)
	if ok then return col end
end

-------------------------------------------------------------------------------
-- 파티 멤버 칸 (시안 04-1)
-------------------------------------------------------------------------------
local function BuildPartyVisual(f)
	f.aggro = f:CreateTexture(nil, "OVERLAY")
	f.aggro:SetColorTexture(C.red[1], C.red[2], C.red[3], 1)
	f.aggro:SetPoint("TOPLEFT", -10, 0)
	f.aggro:SetSize(2, 34)
	f.aggro:SetAlpha(0)

	f.name = Ink:Text(f, F.bold, 13, C.text, "LEFT")
	f.name:SetPoint("TOPLEFT", 0, -2)
	f.name:SetWidth(96)
	f.level = Ink:Text(f, F.sans, 10, C.muted, "LEFT")
	f.level:SetPoint("LEFT", f.name, "RIGHT", 5, -1)
	f.role = RoleIcon(f, 13)
	f.role:SetPoint("LEFT", f.level, "RIGHT", 5, 1)

	f.spec = CreateFrame("Frame", nil, f)
	f.spec:SetHeight(16)
	f.spec:SetPoint("LEFT", f.role, "RIGHT", 5, 0)
	f.spec.bd = Ink:Round(f.spec, "BORDER", true, true)
	f.spec.bd:SetAllPoints()
	f.spec.bd:SetVertexColor(1, 1, 1, 0.14)
	f.spec.icon = f.spec:CreateTexture(nil, "ARTWORK")
	f.spec.icon:SetSize(12, 12)
	f.spec.icon:SetPoint("LEFT", 3, 0)
	f.spec.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.spec.text = Ink:Text(f.spec, F.semi, 10, C.soft, "LEFT")
	f.spec.text:SetPoint("LEFT", f.spec.icon, "RIGHT", 3, 0)
	f.spec:Hide()

	f.pct = Ink:Text(f, F.num, 20, C.text, "RIGHT")
	f.pct:SetPoint("TOPRIGHT", f, "TOPRIGHT", -9, 2)
	f.pctSign = Ink:Text(f, F.num, 10, C.muted, "LEFT")
	f.pctSign:SetPoint("BOTTOMLEFT", f.pct, "BOTTOMRIGHT", 1, 2)
	f.pctSign:SetText("%")

	f.hpGlow = f:CreateTexture(nil, "BACKGROUND")
	f.hpGlow:SetTexture(Ink.tex.glow)
	f.hp = Ink:Bar(f, P_W, 5, C.text)
	f.hp:SetPoint("TOPLEFT", 0, -22)
	f.hpGlow:SetPoint("TOPLEFT", f.hp, "TOPLEFT", -14, 14)
	f.hpGlow:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", 14, -14)
	f.hpGlow:SetAlpha(0)

	f.power = Ink:Bar(f, P_W, 2, C.mana, C.trackSoft)
	f.power:SetPoint("TOPLEFT", 0, -31)

	f.auras = ns.AuraRow(f, 18, 7)
	f.auras:SetPoint("TOPLEFT", 0, -38)
end

local function ApplyDispelLook(f, col)
	if col then
		f.hp:SetStatusBarColor(col:GetRGB())
		local r, g, b = col:GetRGB()
		f.hp.bg:SetColorTexture(r, g, b, 0.18)
		f.hpGlow:SetVertexColor(r, g, b)
		f.hpGlow:SetAlpha(0.55)
		return true
	end
	f.hp.bg:SetColorTexture(1, 1, 1, 0.08)
	f.hpGlow:SetAlpha(0)
	return false
end

function M:UpdateParty(f)
	local u = f.unit
	if not u or not UnitExists(u) then return end
	f.name:SetText((UnitName(u)))
	f.name:SetTextColor(ns.ClassColor(u))
	local lvl = plain(UnitLevel(u))
	f.level:SetText((lvl and lvl > 0) and tostring(lvl) or "??")
	SetRole(f.role, UnitGroupRolesAssigned(u))
	self:UpdateSpec(f)
	self:UpdatePartyHealth(f)
	self:UpdatePartyPower(f)
	self:UpdatePartyAuras(f)
	self:UpdatePartyRange(f)
end

function M:UpdatePartyHealth(f)
	local u = f.unit
	safe(function()
		f.hp:SetMinMaxValues(0, UnitHealthMax(u))
		f.hp:SetValue(UnitHealth(u))
	end)
	local dead = plain(UnitIsDeadOrGhost(u))
	local off = plain(UnitIsConnected(u)) == false
	if off then
		f.pct:SetText("오프")
		f.pct:SetFont(F.semi, 13, "")
		f.pctSign:Hide()
	elseif dead then
		f.pct:SetText("사망")
		f.pct:SetFont(F.semi, 13, "")
		f.pctSign:Hide()
	else
		f.pct:SetFont(F.num, 20, "")
		f.pct:SetText(ns.HealthPercentText(u))
		f.pctSign:Show()
	end
	local r, g, b = ns.LowColor(u)
	f.pct:SetTextColor(r, g, b)
	if not ApplyDispelLook(f, (not f.dispelWatch) and DispelColor(u) or nil) then
		f.hp:SetStatusBarColor(r, g, b)
	end
end

function M:UpdatePartyPower(f)
	local u = f.unit
	local ptype = plain(UnitPowerType(u)) or 0
	local col = Ink.powerColor[ptype] or C.mana
	f.power:SetStatusBarColor(col[1], col[2], col[3])
	safe(function()
		f.power:SetMinMaxValues(0, UnitPowerMax(u, ptype))
		f.power:SetValue(UnitPower(u, ptype))
	end)
end

-- 12.1 오라 컨테이너: 디버프 줄 + 해제 가능한 디버프 색 덮개 (엔진이 그려 준다)
function M:AttachPartyAuras(f)
	local box = ns.AuraBox(f, 18, 7)
	if box:IsLive() then
		f.auras:Hide()
		box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -38)
		f.auraBox = box
	end
	f.dispelWatch = ns.DispelWatch(f, function(btn)
		local fill = btn:CreateTexture(nil, "OVERLAY", nil, 2)
		fill:SetTexture(Ink.tex.white)
		fill:SetAllPoints(f.hp:GetStatusBarTexture())
		fill:SetAlpha(0.9)
		local track = btn:CreateTexture(nil, "OVERLAY", nil, 1)
		track:SetTexture(Ink.tex.white)
		track:SetAllPoints(f.hp)
		track:SetAlpha(0.18)
		local glow = btn:CreateTexture(nil, "BACKGROUND")
		glow:SetTexture(Ink.tex.glow)
		glow:SetAllPoints(f.hpGlow)
		glow:SetAlpha(0.55)
		return { fill, track, glow }
	end, f.hp:GetFrameLevel() + 2)
end

function M:UpdatePartyAuras(f)
	if f.auraBox then
		f.auraBox:SetUnit(UnitExists(f.unit) and f.unit or "none", true)
	else
		ns.UpdateAuras(f.auras, f.unit, "HARMFUL", true)
	end
	if f.dispelWatch then f.dispelWatch:SetUnit(UnitExists(f.unit) and f.unit or "none", true) end
	self:UpdatePartyHealth(f)
end

function M:UpdatePartyRange(f)
	local u = f.unit
	local inRange, checked = UnitInRange(u)
	if f.SetAlphaFromBoolean and inRange ~= nil and (plain(checked) ~= false) then
		safe(f.SetAlphaFromBoolean, f, inRange, 1, 0.45)
	else
		f:SetAlpha(1)
	end
	local threat = plain(UnitThreatSituation(u))
	f.aggro:SetAlpha((threat and threat >= 2) and 1 or 0)
end

-------------------------------------------------------------------------------
-- 특성 확인 (살펴보기 대기열)
-------------------------------------------------------------------------------
M.specCache = {}
local inspectQueue, inspecting = {}, nil

function M:UpdateSpec(f)
	local u = f.unit
	local guid = plain(UnitGUID(u))
	local id = guid and self.specCache[guid]
	if not id and guid then
		inspectQueue[guid] = u
		self:RunInspect()
	end
	if id and GetSpecializationInfoByID then
		local _, name, _, icon = GetSpecializationInfoByID(id)
		if name then
			f.spec.icon:SetTexture(icon)
			f.spec.text:SetText(name)
			f.spec:SetWidth(f.spec.text:GetStringWidth() + 23)
			f.spec:Show()
			return
		end
	end
	f.spec:Hide()
end

function M:RunInspect()
	if inspecting or InCombatLockdown() then return end
	if InspectFrame and InspectFrame:IsShown() then return end
	for guid, unit in pairs(inspectQueue) do
		inspectQueue[guid] = nil
		if UnitExists(unit) and plain(UnitGUID(unit)) == guid and CanInspect(unit) and plain(UnitIsConnected(unit)) then
			inspecting = guid
			NotifyInspect(unit)
			C_Timer.After(3, function()
				if inspecting == guid then
					inspecting = nil
					M:RunInspect()
				end
			end)
			return
		end
	end
end

function M:OnInspectReady(guid)
	if guid ~= inspecting then return end
	inspecting = nil
	for _, f in ipairs(self.party or {}) do
		if plain(UnitGUID(f.unit)) == guid then
			local id = GetInspectSpecialization(f.unit)
			if id and id > 0 then self.specCache[guid] = id end
			self:UpdateSpec(f)
		end
	end
	if ClearInspectPlayer then ClearInspectPlayer() end
	C_Timer.After(1, function() M:RunInspect() end)
end

-------------------------------------------------------------------------------
-- 레이드 칸 (시안 04-2)
-------------------------------------------------------------------------------
local function BuildRaidVisual(f)
	f:SetSize(R_W, R_H)
	f.bg = Ink:Round(f, "BACKGROUND", true, false)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(1, 1, 1, 0.03)
	f.hp = CreateFrame("StatusBar", nil, f)
	f.hp:SetPoint("TOPLEFT", 1, -1)
	f.hp:SetPoint("BOTTOMRIGHT", -1, 1)
	f.hp:SetStatusBarTexture(Ink.tex.white)
	f.hp:SetMinMaxValues(0, 1)
	f.line = CreateFrame("StatusBar", nil, f)
	f.line:SetPoint("BOTTOMLEFT", 1, 1)
	f.line:SetPoint("BOTTOMRIGHT", -1, 1)
	f.line:SetHeight(2)
	f.line:SetStatusBarTexture(Ink.tex.white)
	f.line:SetMinMaxValues(0, 1)
	f.top = CreateFrame("Frame", nil, f)
	f.top:SetAllPoints()
	f.top:SetFrameLevel(f.hp:GetFrameLevel() + 3)
	f.bd = Ink:Round(f.top, "OVERLAY", true, true)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.06)
	f.glow = f:CreateTexture(nil, "BACKGROUND", nil, -2)
	f.glow:SetTexture(Ink.tex.glow)
	f.glow:SetPoint("TOPLEFT", -10, 10)
	f.glow:SetPoint("BOTTOMRIGHT", 10, -10)
	f.glow:SetAlpha(0)
	f.name = Ink:Text(f.top, F.semi, 11, C.text, "LEFT")
	f.name:SetPoint("TOPLEFT", 5, -4)
	f.name:SetWidth(R_W - 20)
	f.status = Ink:Text(f.top, F.sans, 9, C.muted, "RIGHT")
	f.status:SetPoint("BOTTOMRIGHT", -5, 5)
	f.role = RoleIcon(f.top, 10)
	f.role:SetPoint("TOPRIGHT", -5, -5)
end

-- 직업색 → 35% 미만이면 빨강 (secret 체력에도 안전한 곡선)
local classCurves = {}
local function ClassLowColor(u, cr, cg, cb)
	if not (C_CurveUtil and UnitHealthPercent) then return cr, cg, cb end
	local key = string.format("%.2f%.2f%.2f", cr, cg, cb)
	local c = classCurves[key]
	if not c then
		c = C_CurveUtil.CreateColorCurve()
		c:SetType(Enum.LuaCurveType.Step)
		c:AddPoint(0, CreateColor(C.red[1], C.red[2], C.red[3], 1))
		c:AddPoint(0.35, CreateColor(cr, cg, cb, 1))
		classCurves[key] = c
	end
	local ok, col = pcall(UnitHealthPercent, u, true, c)
	if ok and col then return col:GetRGB() end
	return cr, cg, cb
end

local function RaidLook(f, r, g, b, dispel)
	if dispel then
		local dr, dg, db = dispel:GetRGB()
		f.hp:SetStatusBarColor(dr, dg, db, 0.30)
		f.line:SetStatusBarColor(dr, dg, db, 1)
		f.bd:SetVertexColor(dr, dg, db, 1)
		f.glow:SetVertexColor(dr, dg, db)
		f.glow:SetAlpha(0.4)
		return true
	end
	f.glow:SetAlpha(0)
	f.hp:SetStatusBarColor(r, g, b, 0.16)
	f.line:SetStatusBarColor(r, g, b, 1)
	return false
end

function M:UpdateRaid(f)
	local u = f:GetAttribute("unit")
	f.unit = u
	if not u or not UnitExists(u) then return end
	f.name:SetText((UnitName(u)))
	local cr, cg, cb = ns.ClassColor(u)
	f.name:SetTextColor(cr, cg, cb)
	safe(function()
		local mx = UnitHealthMax(u)
		f.hp:SetMinMaxValues(0, mx)
		f.line:SetMinMaxValues(0, mx)
		f.hp:SetValue(UnitHealth(u))
		f.line:SetValue(UnitHealth(u))
	end)
	local dead = plain(UnitIsDeadOrGhost(u))
	local off = plain(UnitIsConnected(u)) == false
	if off then
		f.status:SetText("오프")
		f.status:SetFont(F.semi, 9, "")
		f.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	elseif dead then
		f.status:SetText("사망")
		f.status:SetFont(F.semi, 9, "")
		f.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	else
		f.status:SetFont(F.sans, 9, "")
		local ok = pcall(function()
			local missing = UnitHealthMissing and UnitHealthMissing(u)
			if missing then f.status:SetText("-" .. Ink.Abbrev(missing)) else f.status:SetText(ns.HealthPercentText(u) .. "%") end
		end)
		if not ok then f.status:SetText("") end
	end
	local lr, lg, lb = ClassLowColor(u, cr, cg, cb)
	if f.dispelWatch then f.dispelWatch:SetUnit(u) end
	local hasDispel = RaidLook(f, lr, lg, lb, (not f.dispelWatch) and DispelColor(u) or nil)
	SetRole(f.role, UnitGroupRolesAssigned(u), true)
	if not hasDispel then
		local threat = plain(UnitThreatSituation(u))
		if threat and threat >= 2 then
			f.bd:SetVertexColor(C.red[1], C.red[2], C.red[3], 1)
		elseif UnitIsUnit(u, "player") then
			f.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.55)
		else
			f.bd:SetVertexColor(1, 1, 1, 0.06)
		end
	end
	local inRange = UnitInRange(u)
	if f.SetAlphaFromBoolean and inRange ~= nil then safe(f.SetAlphaFromBoolean, f, inRange, 1, 0.4) else f:SetAlpha(1) end
end

-------------------------------------------------------------------------------
-- 생성
-------------------------------------------------------------------------------
function M:BuildParty()
	local holder = CreateFrame("Frame", "InkUIParty", Ink.root, "SecureHandlerStateTemplate")
	holder:SetSize(P_W, 4 * (P_H + P_GAP))
	RegisterStateDriver(holder, "visibility", "[group:raid] hide; [group:party] show; hide")
	self.party = {}
	for i = 1, 4 do
		local f = CreateFrame("Button", "InkUIParty" .. i, holder, "SecureUnitButtonTemplate")
		f:SetSize(P_W, P_H)
		f:SetPoint("TOPLEFT", 0, -(i - 1) * (P_H + P_GAP))
		f.unit = "party" .. i
		f:SetAttribute("unit", f.unit)
		f:SetAttribute("*type1", "target")
		f:SetAttribute("*type2", "togglemenu")
		f:RegisterForClicks("AnyUp")
		f:SetScript("OnEnter", UnitFrame_OnEnter)
		f:SetScript("OnLeave", UnitFrame_OnLeave)
		f:SetScript("OnShow", function(self) M:UpdateParty(self) end)
		BuildPartyVisual(f)
		M:AttachPartyAuras(f)
		RegisterUnitWatch(f)
		self.party[i] = f
	end
	self.partyHolder = holder
	Ink:Movable("party", "파티", holder, "left", 24, 280)
end

function M:BuildRaid()
	local h = CreateFrame("Frame", "InkUIRaid", Ink.root, "SecureGroupHeaderTemplate")
	h:SetAttribute("template", "SecureUnitButtonTemplate")
	h:SetAttribute("showRaid", true)
	h:SetAttribute("showParty", false)
	h:SetAttribute("showPlayer", true)
	h:SetAttribute("groupBy", "GROUP")
	h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
	h:SetAttribute("maxColumns", 8)
	h:SetAttribute("unitsPerColumn", 5)
	h:SetAttribute("point", "TOP")
	h:SetAttribute("yOffset", -R_GAP)
	h:SetAttribute("columnAnchorPoint", "LEFT")
	h:SetAttribute("columnSpacing", R_COLGAP)
	h:SetAttribute("initialConfigFunction", ([[
		self:SetWidth(%d)
		self:SetHeight(%d)
		self:SetAttribute("*type1", "target")
		self:SetAttribute("*type2", "togglemenu")
		self:GetParent():CallMethod("InitButton", self:GetName())
	]]):format(R_W, R_H))
	h.InitButton = function(_, name)
		local f = _G[name]
		if not f or f.inkBuilt then return end
		f.inkBuilt = true
		BuildRaidVisual(f)
		f.dispelWatch = ns.DispelWatch(f, function(btn)
			local fill = btn:CreateTexture(nil, "ARTWORK")
			fill:SetTexture(Ink.tex.white)
			fill:SetAllPoints(f.hp:GetStatusBarTexture())
			fill:SetAlpha(0.3)
			local line = btn:CreateTexture(nil, "ARTWORK", nil, 1)
			line:SetTexture(Ink.tex.white)
			line:SetAllPoints(f.line:GetStatusBarTexture())
			local bd = Ink:Round(btn, "OVERLAY", true, true)
			bd:SetAllPoints(f)
			local glow = btn:CreateTexture(nil, "BACKGROUND")
			glow:SetTexture(Ink.tex.glow)
			glow:SetAllPoints(f.glow)
			glow:SetAlpha(0.4)
			return { fill, line, bd, glow }
		end, f.hp:GetFrameLevel() + 1)
		if not InCombatLockdown() then f:RegisterForClicks("AnyUp") end
		f:SetScript("OnEnter", UnitFrame_OnEnter)
		f:SetScript("OnLeave", UnitFrame_OnLeave)
		f:HookScript("OnAttributeChanged", function(self, key)
			if key == "unit" then M:UpdateRaid(self) end
		end)
		f:HookScript("OnShow", function(self) M:UpdateRaid(self) end)
		table.insert(M.raidButtons, f)
	end
	self.raidButtons = {}
	RegisterAttributeDriver(h, "state-visibility", "[group:raid] show; hide")
	self.raid = h
	Ink:Movable("raid", "레이드", h, "left", 16, 290, 8 * (R_W + R_COLGAP), 5 * (R_H + R_GAP))
end

-------------------------------------------------------------------------------
-- 테스트 모드 예시
-------------------------------------------------------------------------------
local FAKE_CLASS = {
	WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, PRIEST = { 1, 1, 1 }, MAGE = { 0.25, 0.78, 0.92 },
	ROGUE = { 1, 0.96, 0.41 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 }, HUNTER = { 0.67, 0.83, 0.45 },
}

local function FakeColor(hexDispel)
	local c = Ink.dispel[hexDispel]
	return { GetRGB = function() return c[1], c[2], c[3] end, GetRGBA = function() return c[1], c[2], c[3], 1 end }
end

function M:BuildPreview()
	if self.preview then return end
	local pv = CreateFrame("Frame", nil, Ink.root)
	pv:SetAllPoints(self.partyHolder)
	pv.members = {}
	local fake = {
		{ "방패벽", "WARRIOR", "TANK", "방어", 132355, 92, 40, 1, 3, { { 3, 136207 }, { nil, 132358 } } },
		{ "빛의서약", "PALADIN", "HEALER", "신성", 135920, 68, 54, 0, 1, { { 1, 136085 } } },
		{ "새벽바람", "PRIEST", "HEALER", "수양", 135940, 100, 81, 0, 2, { { 2, 136139 } }, true },
		{ "별똥별", "MAGE", "DAMAGER", "냉기", 135846, 24, 33, 0, 4, { { 4, 132274 }, { nil, 136071 } } },
	}
	for i, d in ipairs(fake) do
		local f = CreateFrame("Frame", nil, pv)
		f:SetSize(P_W, P_H)
		f:SetPoint("TOPLEFT", 0, -(i - 1) * (P_H + P_GAP))
		BuildPartyVisual(f)
		local cc = FAKE_CLASS[d[2]]
		f.name:SetText(d[1]); f.name:SetTextColor(cc[1], cc[2], cc[3])
		f.level:SetText("60")
		SetRole(f.role, d[3])
		f.spec.icon:SetTexture(d[5]); f.spec.text:SetText(d[4])
		f.spec:SetWidth(f.spec.text:GetStringWidth() + 23); f.spec:Show()
		f.pct:SetText(d[6])
		local low = d[6] < 35
		f.pct:SetTextColor(low and C.red[1] or C.text[1], low and C.red[2] or C.text[2], low and C.red[3] or C.text[3])
		f.hp:SetMinMaxValues(0, 100); f.hp:SetValue(d[6])
		f.power:SetMinMaxValues(0, 100); f.power:SetValue(d[7])
		f.power:SetStatusBarColor(d[1] == "방패벽" and C.rage[1] or C.mana[1], d[1] == "방패벽" and C.rage[2] or C.mana[2], d[1] == "방패벽" and C.rage[3] or C.mana[3])
		f.aggro:SetAlpha(d[8])
		if not ApplyDispelLook(f, FakeColor(d[9])) then f.hp:SetStatusBarColor(1, 1, 1) end
		for j, a in ipairs(d[10]) do
			local b = ns.AuraButton(f.auras, j)
			b.icon:SetTexture(a[2])
			local col = Ink.dispel[a[1] or 0]
			b.skin.border:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
			b.cd:SetCooldown(GetTime() - 6, 20 + j * 6)
			b:Show()
		end
		if d[11] then f:SetAlpha(0.45) end
		pv.members[i] = f
	end
	pv:Hide()

	local rv = CreateFrame("Frame", nil, Ink.root)
	self.raidPreviewFrame = rv
	self:PlaceRaidPreview()
	rv:SetSize(8 * (R_W + R_COLGAP), 5 * (R_H + R_GAP))
	local roster = {
		{ "WARRIOR", 8 }, { "PRIEST", 6 }, { "PALADIN", 4 }, { "DRUID", 4 }, { "MAGE", 6 }, { "WARLOCK", 5 }, { "ROGUE", 4 }, { "HUNTER", 3 },
	}
	local names = { "방패벽", "철벽수호", "강철심장", "분노폭발", "투사의혼", "붉은도끼", "돌주먹", "사자후", "새벽바람", "빛무리", "은총", "성스러운손", "신의가호", "치유의샘",
		"빛의서약", "은빛맹세", "정의구현", "성전사", "달빛곰", "숲수호자", "별가루", "이끼발", "별똥별", "얼음꽃", "불꽃놀이", "비전술사", "서리발", "화염장인",
		"어둠불꽃", "그림자손", "영혼수확", "공포의밤", "저주꾼", "일단테스트도적", "그림자칼", "독침", "소리없이", "바람사냥꾼", "매의눈", "야수조련" }
	local list = {}
	for _, r in ipairs(roster) do for _ = 1, r[2] do table.insert(list, r[1]) end end
	local special = { [1] = "aggro", [2] = "aggro", [6] = "dead", [14] = "off", [21] = 18, [28] = 31, [4] = 1, [12] = 4, [23] = 2, [31] = 3, [18] = "oor", [34] = "oor", [39] = "oor" }
	for i = 1, 40 do
		local f = CreateFrame("Frame", nil, rv)
		BuildRaidVisual(f)
		local g, slot = (i - 1) % 8, math.floor((i - 1) / 8)
		f:SetPoint("TOPLEFT", g * (R_W + R_COLGAP), -slot * (R_H + R_GAP))
		local cls = list[i]
		local cc = FAKE_CLASS[cls]
		local sp = special[i]
		local hp = (sp == "dead" or sp == "off") and 0 or (type(sp) == "number" and sp > 4 and sp) or (i % 4 == 0 and 100 or ((i * 37) % 55) + 45)
		f.name:SetText(names[i]); f.name:SetTextColor(cc[1], cc[2], cc[3])
		f.hp:SetValue(hp / 100); f.line:SetValue(hp / 100)
		local dispel = (type(sp) == "number" and sp <= 4) and FakeColor(sp) or nil
		if hp > 0 and hp < 35 then RaidLook(f, C.red[1], C.red[2], C.red[3], dispel) else RaidLook(f, cc[1], cc[2], cc[3], dispel) end
		if sp == "dead" or sp == "off" then
			f.status:SetFont(F.semi, 9, ""); f.status:SetText(sp == "dead" and "사망" or "오프")
			f.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
		else
			f.status:SetText(hp < 100 and ("-" .. string.format("%.1fk", (100 - hp) * 0.42)) or "")
		end
		if sp == "aggro" and not dispel then f.bd:SetVertexColor(C.red[1], C.red[2], C.red[3], 1) end
		if names[i] == "일단테스트도적" then f.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.55) end
		if sp == "oor" then f:SetAlpha(0.4) end
		local role = (i == 1 or i == 2 or i == 19) and "TANK" or ((cls == "PRIEST" or cls == "PALADIN" or i == 20) and "HEALER") or nil
		SetRole(f.role, role, true)
	end
	rv:Hide()
	self.preview = { party = pv, raid = rv }
end

-- 레이드 예시는 레이드 칸과 같은 자리에 (레이드 칸이 숨겨져 있거나 위치가 없으면 기본 자리)
function M:PlaceRaidPreview()
	local rv = self.raidPreviewFrame
	if not rv then return end
	rv:ClearAllPoints()
	local point, rel, relPoint, x, y
	if self.raid and self.raid.GetPoint then point, rel, relPoint, x, y = self.raid:GetPoint(1) end
	if point then
		rv:SetPoint(point, rel, relPoint, x, y)
	else
		Ink:PlaceLeft(rv, 16, 290)
	end
end

function M:SetTest(on)
	self.testing = on
	if on then self:BuildPreview() end
	self:PlaceRaidPreview()
	if not self.preview then return end
	local cfg = Ink.modules.Config
	local which = cfg and cfg.testGroup or "party"
	self.preview.party:SetShown(on and Ink.db.party and which == "party")
	self.preview.raid:SetShown(on and Ink.db.raid and which == "raid")
end

-------------------------------------------------------------------------------
function M:Init()
	-- 파티 / 레이드를 따로 만든다 (한쪽에서 오류가 나도 다른 쪽은 살아 있게)
	if Ink.db.party then
		local ok, err = pcall(self.BuildParty, self)
		if not ok then Ink:LogError("BuildParty: " .. tostring(err)); print("|cffFF6B5EFOA|r 파티 프레임: " .. tostring(err)) end
		for _, n in ipairs({ "PartyFrame", "CompactPartyFrame" }) do Ink:Disable(n) end
	end
	if Ink.db.raid then
		local ok, err = pcall(self.BuildRaid, self)
		if not ok then Ink:LogError("BuildRaid: " .. tostring(err)); print("|cffFF6B5EFOA|r 레이드 프레임: " .. tostring(err)) end
		for _, n in ipairs({ "CompactRaidFrameContainer", "CompactRaidFrameManager" }) do Ink:Disable(n) end
	end
	if not (self.party or self.raid) then return end

	local e = CreateFrame("Frame")
	for _, ev in ipairs({
		"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_AURA",
		"UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_FLAGS", "UNIT_IN_RANGE_UPDATE",
		"GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "INSPECT_READY", "PLAYER_REGEN_ENABLED",
	}) do
		e:RegisterEvent(ev)
	end
	e:SetScript("OnEvent", function(_, event, arg)
		if event == "INSPECT_READY" then
			M:OnInspectReady(arg)
			return
		elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_REGEN_ENABLED" then
			for _, f in ipairs(M.party or {}) do if f:IsShown() then M:UpdateParty(f) end end
			for _, f in ipairs(M.raidButtons or {}) do if f:IsShown() then M:UpdateRaid(f) end end
			M:RunInspect()
			return
		end
		if not arg then return end
		for _, f in ipairs(M.party or {}) do
			if f.unit == arg and f:IsShown() then
				if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then M:UpdatePartyHealth(f)
				elseif event == "UNIT_AURA" then
					if f.auraBox then M:UpdatePartyHealth(f) else M:UpdatePartyAuras(f) end
				elseif event:find("POWER") then M:UpdatePartyPower(f)
				elseif event == "UNIT_IN_RANGE_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then M:UpdatePartyRange(f)
				else M:UpdateParty(f) end
			end
		end
		if not event:find("POWER") then
			for _, f in ipairs(M.raidButtons or {}) do
				if f.unit == arg and f:IsShown() then M:UpdateRaid(f) end
			end
		end
	end)

	-- 사거리는 이벤트가 드물어서 주기적으로 갱신
	local t = 0
	e:SetScript("OnUpdate", function(_, el)
		t = t + el
		if t < 0.5 then return end
		t = 0
		for _, f in ipairs(M.party or {}) do if f:IsShown() then M:UpdatePartyRange(f) end end
	end)
end

function M:Refresh()
	for _, f in ipairs(self.party or {}) do if f:IsShown() then self:UpdateParty(f) end end
	for _, f in ipairs(self.raidButtons or {}) do if f:IsShown() then self:UpdateRaid(f) end end
end
