-- InkUI · 중앙 묶음 (쿨다운 추적 / 연계 점수 / 주 자원 / 플레이어 시전바)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Center")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

local SEG_TOTAL, SEG_GAP, SEG_H = 280, 5, 6

-------------------------------------------------------------------------------
-- 직업 자원 칸 (버블바)
--  직업·전문화마다 알맞은 자원을 칸으로 보여 준다. 각 칸이 StatusBar 라 값이 비공개여도 채워진다.
--   도적·야드(표범) 연계 점수 / 성기사 신성한 힘 / 흑마 영혼의 조각(파괴는 조각 단위까지)
--   수도사(풍운) 기 / 마법사(비전) 비전 충전물 / 기원사 정수 / 죽기 룬 6개(재충전 진행까지)
--  해당 자원이 없는 직업·전문화는 칸을 숨긴다.
-------------------------------------------------------------------------------
local PT = Enum.PowerType or {}
local P_COMBO, P_RUNES, P_SHARDS, P_HOLY, P_CHI, P_ARCANE, P_ESSENCE =
	PT.ComboPoints or 4, PT.Runes or 5, PT.SoulShards or 7, PT.HolyPower or 9, PT.Chi or 12, PT.ArcaneCharges or 16, PT.Essence or 19

local RES_COLOR = {
	[P_COMBO] = C.accent,
	[P_HOLY] = Ink.hex("FFD45E"),
	[P_SHARDS] = Ink.hex("B98CFF"),
	[P_CHI] = Ink.hex("3EE0A6"),
	[P_ARCANE] = Ink.hex("7FB2FF"),
	[P_ESSENCE] = Ink.hex("4FD1B8"),
}
local RUNE_COLOR = { Ink.hex("FF5D6C"), Ink.hex("6EC6FF"), Ink.hex("8BE06C") } -- 혈기 / 냉기 / 부정

-- 지금 보여 줄 자원: 자원 종류, 색, 방식("normal" / "shard" / "rune")
local function Resource()
	local _, class = UnitClass("player")
	local spec = GetSpecialization and GetSpecialization()
	if class == "ROGUE" then return P_COMBO, C.accent, "normal" end
	if class == "DRUID" then
		-- 표범 변신(기력 사용)일 때만 연계 점수
		if plain(UnitPowerType("player")) == (PT.Energy or 3) then return P_COMBO, Ink.hex("FF9A4D"), "normal" end
		return nil
	end
	if class == "PALADIN" then return P_HOLY, RES_COLOR[P_HOLY], "normal" end
	if class == "WARLOCK" then return P_SHARDS, RES_COLOR[P_SHARDS], "shard" end
	if class == "MONK" and spec == 3 then return P_CHI, RES_COLOR[P_CHI], "normal" end
	if class == "MAGE" and spec == 1 then return P_ARCANE, RES_COLOR[P_ARCANE], "normal" end
	if class == "EVOKER" then return P_ESSENCE, RES_COLOR[P_ESSENCE], "normal" end
	if class == "DEATHKNIGHT" then return P_RUNES, RUNE_COLOR[spec or 1] or RUNE_COLOR[1], "rune" end
	return nil
end
ns.ClassResource = Resource

function M:BuildCombo()
	local holder = CreateFrame("Frame", "InkUIComboBar", Ink.root)
	holder:SetSize(320, 16)
	holder.segs = {}
	self.combo = holder
	-- 죽기 룬 재충전 진행은 매 프레임
	holder:SetScript("OnUpdate", function()
		if holder.kind == "rune" then M:UpdateCombo() end
	end)
end

function M:LayoutCombo()
	local holder = self.combo
	local ptype, color, kind = Resource()
	local n = 0
	if kind == "rune" then
		n = 6
	elseif ptype then
		n = plain(UnitPowerMax("player", ptype)) or 0
	end
	if self.testing and n <= 0 then ptype, color, kind, n = P_COMBO, C.accent, "normal", 5 end
	holder.ptype, holder.color, holder.kind = ptype, color, kind
	if n <= 0 then
		holder.n = nil
		for _, s in ipairs(holder.segs) do s:Hide() end
		return
	end
	-- 조각 단위 (파괴 흑마: 한 칸 = 10)
	local mod = 1
	if kind == "shard" then
		mod = (UnitPowerDisplayMod and plain(UnitPowerDisplayMod(ptype))) or 1
		if mod <= 0 then mod = 1 end
	end
	holder.mod = mod
	local segW = (SEG_TOTAL - (n - 1) * SEG_GAP) / n
	local startX = (320 - SEG_TOTAL) / 2
	for i = 1, math.max(n, #holder.segs) do
		local s = holder.segs[i]
		if i <= n then
			if not s then
				s = CreateFrame("Frame", nil, holder)
				s.bg = s:CreateTexture(nil, "BACKGROUND")
				s.bg:SetAllPoints()
				s.bg:SetTexture(Ink.tex.seg)
				s.bg:SetVertexColor(1, 1, 1, 0.12)
				s.glow = CreateFrame("StatusBar", nil, s)
				s.glow:SetStatusBarTexture(Ink.tex.segGlow)
				s.glow:SetFrameLevel(s:GetFrameLevel())
				s.fill = CreateFrame("StatusBar", nil, s)
				s.fill:SetAllPoints()
				s.fill:SetStatusBarTexture(Ink.tex.seg)
				s.fill:SetFrameLevel(s:GetFrameLevel() + 1)
				holder.segs[i] = s
			end
			s:SetSize(segW, SEG_H)
			s:ClearAllPoints()
			s:SetPoint("LEFT", holder, "LEFT", startX + (i - 1) * (segW + SEG_GAP), 0)
			s.glow:ClearAllPoints()
			s.glow:SetSize(segW * 2, SEG_H * 4)
			s.glow:SetPoint("CENTER", s, "CENTER")
			s.fill:SetMinMaxValues((i - 1) * mod, i * mod)
			s.glow:SetMinMaxValues((i - 1) * mod, i * mod)
			s:Show()
		elseif s then
			s:Hide()
		end
	end
	holder.n = n
	self:UpdateCombo()
end

-- 죽기 룬: 준비된 룬은 꽉, 재충전 중인 룬은 진행만큼 (준비된 것이 앞으로)
local function RuneValues()
	local now, list = GetTime(), {}
	for i = 1, 6 do
		local ok, start, dur, ready = pcall(GetRuneCooldown, i)
		start, dur, ready = plain(start), plain(dur), plain(ready)
		local p = 1
		if ok and not ready and start and dur and dur > 0 then p = math.max(0, math.min(1, (now - start) / dur)) end
		list[#list + 1] = p
	end
	table.sort(list, function(a, b) return a > b end)
	return list
end

function M:UpdateCombo()
	local holder = self.combo
	if not holder.n then return end
	local a = holder.color or C.accent
	if holder.kind == "rune" and not self.testing then
		local vals = RuneValues()
		for i = 1, holder.n do
			local s = holder.segs[i]
			local p = vals[i] or 0
			s.fill:SetValue(i - 1 + p)
			s.glow:SetValue(i - 1 + p)
			local ready = p >= 1
			s.fill:SetStatusBarColor(a[1], a[2], a[3], ready and 1 or 0.45)
			s.glow:SetStatusBarColor(a[1], a[2], a[3], ready and 0.55 or 0)
		end
		return
	end
	local cp
	if self.testing then
		cp = (self.testCP or 3) * (holder.mod or 1)
	elseif holder.kind == "shard" then
		cp = UnitPower("player", holder.ptype, true)
	else
		cp = UnitPower("player", holder.ptype)
	end
	for i = 1, holder.n do
		local s = holder.segs[i]
		safe(s.fill.SetValue, s.fill, cp)
		safe(s.glow.SetValue, s.glow, cp)
	end
	local v = plain(cp)
	local full = v and v >= holder.n * (holder.mod or 1)
	local pts = v and math.floor(v / (holder.mod or 1))
	if ns.FX then ns.FX.Combo(holder, pts) end
	-- 모일수록 진하게 (효과를 끄거나 값이 비공개면 늘 가장 진하게)
	local k = ns.FX and ns.FX.ComboIntensity(pts, holder.n) or 1
	for i = 1, holder.n do
		holder.segs[i].fill:SetStatusBarColor(a[1], a[2], a[3], k)
		holder.segs[i].glow:SetStatusBarColor(a[1], a[2], a[3], (full and 0.9 or 0.5) * k)
	end
end

-------------------------------------------------------------------------------
-- 주 자원 바
-------------------------------------------------------------------------------
function M:BuildPower()
	local f = CreateFrame("Frame", "InkUIPowerBar", Ink.root)
	f:SetSize(320, 26)
	f.bar = Ink:Bar(f, 320, 8, C.accent)
	f.bar:SetPoint("TOP")
	f.glow = f.bar:CreateTexture(nil, "BACKGROUND", nil, -1)
	f.glow:SetTexture(Ink.tex.glow)
	f.glow:SetPoint("TOPLEFT", f.bar:GetStatusBarTexture(), "TOPLEFT", -12, 12)
	f.glow:SetPoint("BOTTOMRIGHT", f.bar:GetStatusBarTexture(), "BOTTOMRIGHT", 12, -12)
	f.glow:SetAlpha(0.35)
	for i = 1, 3 do
		local t = f.bar:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(0.03, 0.035, 0.045, 0.55)
		t:SetSize(1, 8)
		t:SetPoint("LEFT", f.bar, "LEFT", 320 * i / 4, 0)
	end
	f.value = Ink:Text(f, F.numR, 13, C.accent, "LEFT")
	f.value:SetPoint("TOPLEFT", f, "TOP", -20, -13)
	f.max = Ink:Text(f, F.numR, 10, C.muted, "LEFT")
	f.max:SetPoint("BOTTOMLEFT", f.value, "BOTTOMRIGHT", 2, 1)
	if ns.FX then pcall(ns.FX.AttachPower, f) end
	self.power = f
end

function M:UpdatePower()
	if self.testing then return end
	local f = self.power
	local ptype = plain(UnitPowerType("player")) or 3
	local col = Ink.powerColor[ptype] or C.accent
	f.bar:SetStatusBarColor(col[1], col[2], col[3])
	f.glow:SetVertexColor(col[1], col[2], col[3])
	f.value:SetTextColor(col[1], col[2], col[3])
	safe(function()
		f.bar:SetMinMaxValues(0, UnitPowerMax("player", ptype))
		f.bar:SetValue(UnitPower("player", ptype))
	end)
	if ptype == (Enum.PowerType and Enum.PowerType.Mana or 0) then
		-- 마나는 숫자가 커서 % 로
		safe(function()
			f.value:SetText(string.format("%d", UnitPowerPercent("player", ptype, true, CurveConstants.ScaleTo100)))
		end)
		f.max:SetText("%")
	else
		safe(function() f.value:SetText(Ink.Num(UnitPower("player", ptype))) end)
		safe(function() f.max:SetText("/ " .. Ink.Num(UnitPowerMax("player", ptype))) end)
	end
	safe(M.CenterPowerText, M)
	if ns.FX then pcall(ns.FX.UpdatePower, f, ptype) end
end

-- "100 / 100" 묶음을 바 가운데에 맞춘다
-- 전투 중에는 글자 폭이 비공개 값이라 잴 수 없다 → 재지 않고 "/" 를 바 가운데에 고정한다.
-- 현재값은 가운데 왼쪽에 오른쪽 정렬, "/ 최대값"은 가운데부터 왼쪽 정렬.
function M:CenterPowerText()
	local f = self.power
	if f.centered then return end
	f.centered = true
	f.value:ClearAllPoints()
	f.value:SetJustifyH("RIGHT")
	f.value:SetPoint("TOPRIGHT", f, "TOP", -3, -13)
	f.max:ClearAllPoints()
	f.max:SetJustifyH("LEFT")
	f.max:SetPoint("BOTTOMLEFT", f.value, "BOTTOMRIGHT", 2, 1)
end

-------------------------------------------------------------------------------
-- 쿨다운 추적 (블리자드 쿨다운 매니저를 데이터로 쓰고, 모양과 배치는 InkUI가 직접)
--  · 칸 배치는 블리자드 대신 InkUI가 가운데 정렬로 다시 놓는다 (전투 중에도 고정)
--  · 둥근 아이콘, 효과 유지 중이면 노란 테두리 + 은은한 빛
--  · 남은 시간은 블리자드가 그리는 스와이프와 숫자를 그대로 쓴다 (12.x 비공개 값이라 직접 계산하지 않음)
-------------------------------------------------------------------------------
local function SlotState(s, state)
	s.state = state
	local a = C.accent
	if state == "aura" then
		s.border:SetVertexColor(a[1], a[2], a[3], 1)
		s.glow:SetVertexColor(a[1], a[2], a[3])
		s.glow:SetAlpha(0.35)
	else
		s.border:SetVertexColor(1, 1, 1, 0.16)
		s.glow:SetAlpha(0)
	end
end

local function StyleSlot(holder, icon, cd, small)
	local s = Ink:IconSkin(holder, icon, small)
	if s.glow then return s end
	s.glow = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.glow:SetTexture(Ink.tex.glow)
	s.glow:SetPoint("TOPLEFT", -12, 12)
	s.glow:SetPoint("BOTTOMRIGHT", 12, -12)
	s.glow:SetAlpha(0)
	if cd then Ink:SkinCooldown(cd, small) end
	SlotState(s, "ready")
	return s
end
ns.StyleSlot, ns.SlotState = StyleSlot, SlotState

local skinned = setmetatable({}, { __mode = "k" })

local function SkinItem(item, small)
	if not item or skinned[item] then return end
	skinned[item] = true
	for _, k in ipairs({ "Border", "Shadow", "IconShadow", "DebuffBorder", "CooldownFlash" }) do
		if item[k] and item[k].SetAlpha then item[k]:SetAlpha(0) end
	end
	local icon = item.Icon
	if icon and icon.Icon then icon = icon.Icon end
	for _, r in ipairs({ item:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("MaskTexture") then
			if icon and icon.RemoveMaskTexture then safe(icon.RemoveMaskTexture, icon, r) end
			r:Hide()
		elseif r ~= icon and r.IsObjectType and r:IsObjectType("Texture") then
			local atlas = r.GetAtlas and r:GetAtlas()
			local tex = r.GetTexture and r:GetTexture()
			if (atlas and atlas:find("CoolDownManager")) or tex == 6707800 then r:SetAlpha(0) end
		end
	end
	local cd = item.Cooldown
	if cd then
		for _, r in ipairs({ cd:GetRegions() }) do
			if r.IsObjectType and r:IsObjectType("MaskTexture") then r:Hide() end
		end
	end
	for _, k in ipairs({ "ChargeCount", "Applications" }) do
		local holder = item[k]
		local fs = holder and (holder.Current or holder.Text or (holder.IsObjectType and holder:IsObjectType("FontString") and holder))
		if fs and fs.SetFont then fs:SetFont(F.latinB, small and 10 or 12, "OUTLINE") end
	end
	if not icon then return end
	local s = StyleSlot(item, icon, cd, small)
	if ns.FX and cd then pcall(ns.FX.AttachCooldown, item, cd, small and 30 or 40, s.top) end
	-- 효과(오라) 표시 중인지: 블리자드가 오라 시간 표시로 바꿀 때 알려준다
	if cd and cd.SetUseAuraDisplayTime and not cd.inkHooked then
		cd.inkHooked = true
		hooksecurefunc(cd, "SetUseAuraDisplayTime", function(_, v)
			SlotState(s, plain(v) and "aura" or "ready")
		end)
	end
end

local function ForEachItem(v, fn)
	if not (v and v.itemFramePool and v.itemFramePool.EnumerateActive) then return end
	for item in v.itemFramePool:EnumerateActive() do fn(item) end
end

-- key: 앵커, px: 아이콘 크기, gap: 간격, per: 한 줄 최대 칸 수
local VIEWERS = {
	{ name = "BuffIconCooldownViewer", key = "cdmBuff", px = 30, gap = 4, per = 10, small = true },
	{ name = "EssentialCooldownViewer", key = "cdmMain", px = 40, gap = 6, per = 8, small = false },
	{ name = "UtilityCooldownViewer", key = "cdmUtil", px = 28, gap = 4, per = 12, small = true },
}

local function canMove(v)
	return v and not (InCombatLockdown() and v:IsProtected())
end

-- 블리자드 배치 대신 InkUI가 직접 칸을 가운데 정렬로 놓는다
local function SamePoint(f, point, rel, relPoint, x, y)
	local p, r, rp, px, py = f:GetPoint(1)
	return f:GetNumPoints() == 1 and p == point and r == rel and rp == relPoint
		and math.abs((px or 0) - x) < 0.5 and math.abs((py or 0) - y) < 0.5
end

-- 블리자드 배치 대신 InkUI가 직접 칸을 가운데 정렬로 놓는다.
-- 이미 제자리면 아무것도 건드리지 않아서, 전투 중 반복 호출돼도 깜빡이지 않는다.
function M:ArrangeViewer(info)
	local v = _G[info.name]
	local anchor = self[info.key]
	if not v or not anchor or not canMove(v) then return end
	if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
	if v.inkArranging then return end
	v.inkArranging = true
	safe(function()
		local items = {}
		ForEachItem(v, function(it)
			SkinItem(it, info.small)
			if it:IsShown() then table.insert(items, it) end
		end)
		table.sort(items, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
		local first = items[1]
		-- 아이콘이 시안 크기가 되도록 뷰어 스케일 조정 (2% 이상 차이날 때만)
		if first and first:GetHeight() > 0 then
			local want = info.px * Ink.root:GetEffectiveScale()
			local have = first:GetHeight() * first:GetEffectiveScale()
			if have > 0 and math.abs(want / have - 1) > 0.02 then v:SetScale(v:GetScale() * want / have) end
		end
		if not SamePoint(v, "TOP", anchor, "TOP", 0, 0) then
			v:ClearAllPoints()
			v:SetPoint("TOP", anchor, "TOP")
		end
		if not first then return end
		local k = Ink.root:GetEffectiveScale() / v:GetEffectiveScale() -- 루트 px → 뷰어 단위
		local size, h = first:GetWidth(), first:GetHeight()
		local gap = info.gap * k
		local n = #items
		for i, it in ipairs(items) do
			local row = math.floor((i - 1) / info.per)
			local col = (i - 1) % info.per
			local inRow = math.min(info.per, n - row * info.per)
			local rowW = inRow * size + (inRow - 1) * gap
			local x = math.floor((-rowW / 2 + col * (size + gap)) * 2 + 0.5) / 2
			local y = math.floor((-row * (h + gap)) * 2 + 0.5) / 2
			if not SamePoint(it, "TOPLEFT", v, "TOP", x, y) then
				it:ClearAllPoints()
				it:SetPoint("TOPLEFT", v, "TOP", x, y)
			end
		end
	end)
	v.inkArranging = nil
end

function M:HookViewer(info)
	local v = _G[info.name]
	if not v or v.inkHooked then return end
	v.inkHooked = true
	-- 블리자드가 배치를 바꾸는 즉시(같은 화면 프레임 안에서) 다시 맞춘다
	local function again()
		if v.inkArranging then return end
		M:ArrangeViewer(info)
	end
	hooksecurefunc(v, "SetPoint", again)
	hooksecurefunc(v, "SetScale", again)
	for _, fn in ipairs({ "Layout", "RefreshLayout" }) do
		if type(v[fn]) == "function" then hooksecurefunc(v, fn, again) end
	end
	if v.itemFramePool then
		hooksecurefunc(v.itemFramePool, "Acquire", function() C_Timer.After(0, again) end)
		hooksecurefunc(v.itemFramePool, "Release", function() C_Timer.After(0, again) end)
	end
	-- 버프 아이콘처럼 칸이 보였다 숨었다 하면 바로 다시 정렬
	v:HookScript("OnUpdate", function()
		local count = 0
		ForEachItem(v, function(it) if it:IsShown() then count = count + 1 end end)
		if count ~= v.inkCount then
			v.inkCount = count
			again()
		end
	end)
end

function M:BuildCooldowns()
	self.cdmBuff = Ink:Anchor(340, 30)
	self.cdmMain = Ink:Anchor(340, 40)
	self.cdmUtil = Ink:Anchor(340, 60)
	if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("cooldownViewerEnabled") == "0" then
		safe(C_CVar.SetCVar, "cooldownViewerEnabled", "1")
	end
	for _, info in ipairs(VIEWERS) do self:HookViewer(info) end
	-- 추적 막대(우측 상단 "목조르기 연마" 같은 버프 바)는 쓰지 않는다
	if BuffBarCooldownViewer then Ink:Fade(BuffBarCooldownViewer) end
end

-------------------------------------------------------------------------------
-- 테스트 모드용 쿨다운 추적 예시 (도적 기준)
-------------------------------------------------------------------------------
local PREVIEW_MAIN = {
	{ 132306, "aura", 20 }, { 132302, "aura", 16 }, { 132219, "ready" },
	{ 132155, "cd", 10 }, { 132298, "ready" }, { 136206, "cd", 180 },
}
local PREVIEW_UTIL = {
	{ 136175, "ready" }, { 136205, "ready" }, { 132331, "cd", 120 }, { 132307, "cd", 60 },
	{ 132289, "ready" }, { 135988, "cd", 90 }, { 132310, "ready" },
}

local function BuildPreviewRow(anchor, list, size, gap, small)
	local row = CreateFrame("Frame", nil, Ink.root)
	row:SetAllPoints(anchor)
	row.slots = {}
	local total = #list * size + (#list - 1) * gap
	for i, d in ipairs(list) do
		local f = CreateFrame("Frame", nil, row)
		f:SetSize(size, size)
		f:SetPoint("TOPLEFT", row, "TOP", -total / 2 + (i - 1) * (size + gap), 0)
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetPoint("TOPLEFT", 1, -1)
		f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		f.icon:SetTexture(d[1])
		f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
		f.cd:SetAllPoints(f.icon)
		f.s = StyleSlot(f, f.icon, f.cd, small)
		f.fxPreview = true
		if ns.FX then pcall(ns.FX.AttachCooldown, f, f.cd, size, f.s.top) end
		f.data = d
		row.slots[i] = f
	end
	row:Hide()
	return row
end

function M:PreviewTick()
	local now = GetTime()
	for _, row in ipairs({ self.pvMain, self.pvUtil }) do
		for i, f in ipairs(row.slots) do
			local d = f.data
			local state, dur = d[2], d[3]
			local phase = dur and ((now + i * 3.7) % (dur + 2)) or 0
			if state == "ready" or phase > dur then
				if f.state ~= "ready" then
					f.state = "ready"
					SlotState(f.s, "ready")
					f.cd:Clear()
					f.icon:SetDesaturated(false)
				end
			else
				local started = now - phase
				if f.state ~= state or math.abs(started - (f.started or 0)) > 0.2 then
					f.state, f.started = state, started
					SlotState(f.s, state == "aura" and "aura" or "ready")
					f.cd:SetReverse(state == "aura")
					f.cd:SetCooldown(started, dur)
					f.icon:SetDesaturated(state == "cd")
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- 전투 알림: "Combat +" / "Combat -" 가 잠깐 떴다가 사라진다
-------------------------------------------------------------------------------
function M:BuildCombatAlert()
	local f = CreateFrame("Frame", "InkUICombatAlert", Ink.root)
	f:SetSize(360, 60)
	f:SetFrameStrata("HIGH")
	f.word = Ink:Text(f, F.num, 34, C.text, "LEFT")
	f.word:SetPoint("TOPLEFT", f, "TOP", -60, 0)
	f.word:SetText("Combat")
	f.sign = Ink:Text(f, F.numR, 34, C.red, "LEFT")
	f.sign:SetPoint("LEFT", f.word, "RIGHT", 8, 0)
	f.sub = Ink:Text(f, F.semi, 12, C.muted, "CENTER")
	f.sub:SetPoint("TOP", f, "TOP", 0, -42)
	f.lineL = f:CreateTexture(nil, "ARTWORK")
	f.lineL:SetSize(56, 1)
	f.lineL:SetPoint("RIGHT", f.word, "LEFT", -14, 0)
	f.lineR = f:CreateTexture(nil, "ARTWORK")
	f.lineR:SetSize(56, 1)
	f.lineR:SetPoint("LEFT", f.sign, "RIGHT", 14, 0)

	local ag = f:CreateAnimationGroup()
	local fadeIn = ag:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.18); fadeIn:SetOrder(1)
	local rise = ag:CreateAnimation("Translation")
	rise:SetOffset(0, 10); rise:SetDuration(0.18); rise:SetOrder(1)
	local hold = ag:CreateAnimation("Alpha")
	hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(0.9); hold:SetOrder(2)
	local fadeOut = ag:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.45); fadeOut:SetOrder(3)
	ag:SetScript("OnFinished", function() f:Hide() end)
	f.ag = ag
	f:Hide()
	self.alert = f
	Ink:Movable("combatAlert", "전투 알림", f, "center", 780, 300)
end

function M:ShowCombatAlert(enter)
	local f = self.alert
	if not f then return end
	local col = enter and C.red or C.green
	f.sign:SetText(enter and "+" or "-")
	f.sign:SetTextColor(col[1], col[2], col[3])
	f.word:SetTextColor(enter and C.text[1] or C.soft[1], enter and C.text[2] or C.soft[2], enter and C.text[3] or C.soft[3])
	f.sub:SetText(enter and "전투 시작" or "전투 종료")
	-- "Combat +" 묶음 전체가 화면 가운데에 오도록 글자 폭으로 위치를 다시 계산
	local total = f.word:GetStringWidth() + 8 + f.sign:GetStringWidth()
	f.word:ClearAllPoints()
	f.word:SetPoint("TOPLEFT", f, "TOP", -total / 2, 0)
	f.lineL:SetColorTexture(col[1], col[2], col[3], 0.6)
	f.lineR:SetColorTexture(col[1], col[2], col[3], 0.6)
	f.ag:Stop()
	f:SetAlpha(0)
	f:Show()
	f.ag:Play()
end

function M:CombatStart() self:ShowCombatAlert(true) end
function M:CombatEnd() self:ShowCombatAlert(false) end

-------------------------------------------------------------------------------
-- 초기화 / 배치 / 이벤트
-------------------------------------------------------------------------------
function M:Init()
	self:BuildCombo()
	self:BuildPower()
	self.cast = ns.CastBar(Ink.root, 280, 2, C.text, C.text)
	self.cast.bar.bg:SetColorTexture(1, 1, 1, 0.08)
	if ns.FX then pcall(ns.FX.AttachCast, self.cast, C.text) end
	self:BuildCooldowns()
	self:BuildCombatAlert()
	-- 내 캐릭터 쪽에 뜨는 전투 문자(받은 피해/치유 등)도 같은 글꼴로
	if CombatTextFont then safe(CombatTextFont.SetFont, CombatTextFont, F.semi, 24, "OUTLINE") end

	Ink:Movable("cdmBuff", "추적 버프", self.cdmBuff, "center", 790, 652)
	Ink:Movable("cdmMain", "주기술 쿨다운", self.cdmMain, "center", 790, 692)
	Ink:Movable("cdmUtil", "보조기술 쿨다운", self.cdmUtil, "center", 790, 742)
	Ink:Movable("combo", "연계 점수", self.combo, "center", 800, 816)
	Ink:Movable("power", "주 자원", self.power, "center", 800, 836)
	Ink:Movable("cast", "플레이어 시전바", self.cast, "center", 820, 870)

	if PlayerCastingBarFrame then
		PlayerCastingBarFrame:UnregisterAllEvents()
		Ink:KeepHidden(PlayerCastingBarFrame)
	end

	local e = CreateFrame("Frame")
	for _, ev in ipairs({
		"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
		"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
		"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
		"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
		"UNIT_SPELLCAST_SUCCEEDED",
	}) do
		e:RegisterUnitEvent(ev, "player")
	end
	e:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	e:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	e:RegisterEvent("RUNE_POWER_UPDATE")
	e:RegisterEvent("PLAYER_ENTERING_WORLD")
	e:SetScript("OnEvent", function(_, event)
		if event == "UNIT_POWER_FREQUENT" or event == "RUNE_POWER_UPDATE" then
			M:UpdatePower()
			M:UpdateCombo()
		elseif event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "PLAYER_SPECIALIZATION_CHANGED"
			or event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_ENTERING_WORLD" then
			M:UpdatePower()
			M:LayoutCombo()
		else
			-- 시전이 끝나면 성공(섬광) / 차단(흔들림)을 잠깐 보여 준다
			local refresh = function() ns.CastUpdate(M.cast, "player") end
			if not (ns.FX and ns.FX.CastEvent(M.cast, event, refresh)) then refresh() end
		end
	end)
end

function M:SetTest(on)
	self.testing = on
	if on then self:ShowCombatAlert(true) end
	if on and not self.pvMain then
		self.pvMain = BuildPreviewRow(self.cdmMain, PREVIEW_MAIN, 40, 6, false)
		self.pvUtil = BuildPreviewRow(self.cdmUtil, PREVIEW_UTIL, 28, 4, true)
	end
	if self.pvMain then
		self.pvMain:SetShown(on)
		self.pvUtil:SetShown(on)
	end
	for _, info in ipairs(VIEWERS) do
		if _G[info.name] then _G[info.name]:SetAlpha(on and 0 or 1) end
	end
	self:LayoutCombo()
	local cb = self.cast
	if on then
		cb.preview = true
		cb.name:SetText("순간 효과 독")
		cb.bar:SetMinMaxValues(0, 3)
		cb:Show()
		local t0 = GetTime()
		local f = self.power
		Ink:Loop("center", function()
			local now = GetTime()
			-- 플레이어 시전 (3초 시전, 1초 쉬고 반복)
			local e = (now - t0) % 4
			local cyc = math.floor((now - t0) / 4)
			if e > 3 then
				if ns.FX and ns.FX.demoOn("castFinish") and cb.fxDemoCycle ~= cyc then
					cb.fxDemoCycle = cyc
					cb:Show()
					ns.FX.CastResult(cb, (cyc % 2 == 0) and "ok" or "fail", function() cb:Show() end)
				elseif not cb.fxState then
					cb:SetAlpha(0)
				end
			else
				if cb.fxState then ns.FX.CastReset(cb) end
				cb:Show()
				cb.name:SetText("순간 효과 독")
				cb:SetAlpha(1)
				cb.bar:SetMinMaxValues(0, 3)
				cb.bar:SetValue(e)
				cb.time:SetFormattedText("%.1f", 3 - e)
			end
			-- 연계 점수 0→5 순환, 기력 오르내림
			local cp = math.floor(((now - t0) / 0.8) % 7)
			if cp > 5 then cp = 5 end
			self.testCP = cp
			self:UpdateCombo()
			local en = math.floor(60 + 40 * math.sin((now - t0) * 0.9))
			f.bar:SetMinMaxValues(0, 100)
			f.bar:SetValue(en)
			f.value:SetText(en)
			f.max:SetText("/ 100")
			M:CenterPowerText()
			M:PreviewTick()
		end)
	else
		Ink:Loop("center", nil)
		cb.preview = nil
		cb:SetAlpha(1)
		ns.CastUpdate(cb, "player")
		self:UpdatePower()
	end
end

function M:Layout()
	self:LayoutCombo()
	self:UpdatePower()
end

function M:PostLayout()
	for _, info in ipairs(VIEWERS) do self:ArrangeViewer(info) end
end

function M:Refresh()
	self:UpdatePower()
	self:UpdateCombo()
end
