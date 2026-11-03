-- InkUI · 캐릭터 창
--  블리자드 캐릭터 창(장비 / 평판 / 화폐)을 그대로 쓰되 모양만 Ink 결로 바꾼다.
--  · 어두운 둥근 판 + 옅은 테두리 + 포인트 선, 캐릭터 뒤에 직업색 은은한 빛
--  · 장비 칸: 둥근 아이콘 + 등급색 테두리/빛 + 옆에 아이템 이름 · 레벨 · 업그레이드 단계 · 마법부여 · 보석
--  · 오른쪽 능력치: Ink 폰트, 줄무늬 배경 제거, 평균 아이템 레벨 크게
--  블리자드 프레임에는 키를 쓰지 않고 바깥 표에 둔다 (오염 방지). 크기·위치는 건드리지 않는다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Character")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local S = setmetatable({}, { __mode = "k" })   -- 프레임 → Ink 꾸밈 정보

local function Strip(frame, keep)
	if not frame or not frame.GetRegions then return end
	for _, r in ipairs({ frame:GetRegions() }) do
		if r ~= keep and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
	end
end

local function Hide(x)
	if type(x) == "string" then x = _G[x] end
	if x then x:SetAlpha(0) end
end

local function FontOf(fs, file, size, color, flags)
	if not fs or not fs.SetFont then return end
	fs:SetFont(file, size, flags or "")
	fs:SetShadowColor(0, 0, 0, 0.85)
	fs:SetShadowOffset(1, -1)
	if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
end

-------------------------------------------------------------------------------
-- 장비 칸
-------------------------------------------------------------------------------
local LEFT = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local SLOTS = {}
for _, n in ipairs(LEFT) do SLOTS[#SLOTS + 1] = { name = n, side = "R" } end   -- 글자는 칸 오른쪽
for _, n in ipairs(RIGHT) do SLOTS[#SLOTS + 1] = { name = n, side = "L" } end  -- 글자는 칸 왼쪽
SLOTS[#SLOTS + 1] = { name = "MainHand", side = "L" }
SLOTS[#SLOTS + 1] = { name = "SecondaryHand", side = "R" }
local NO_TEXT = { Shirt = true, Tabard = true }
local TEXT_W = 94

-- 툴팁 줄에서 마법부여 / 업그레이드 단계 찾기 (한국어 문구 패턴은 블리자드 전역 문자열로 만든다)
local function ToPattern(fmt)
	if not fmt then return nil end
	local p = fmt:gsub("([%(%)%.%[%]%^%$%*%+%-%?])", "%%%1")
	p = p:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
	p = p:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
	return "^" .. p .. "$"
end
local ENCHANT_PAT = ToPattern(ENCHANTED_TOOLTIP_LINE)
local UPGRADE_PAT = ToPattern(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
local ENCHANT_TYPE = Enum.TooltipDataLineType and (Enum.TooltipDataLineType.ItemEnchantmentPermanent) or 15

local function CleanText(t)
	t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return t
end

local function ScanSlot(id)
	if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return end
	local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", id)
	if not ok or not data or not data.lines then return end
	local enchant, track
	for _, line in ipairs(data.lines) do
		local text = plain(line.leftText)
		if type(text) == "string" then
			if not enchant and (line.type == ENCHANT_TYPE or (ENCHANT_PAT and text:match(ENCHANT_PAT))) then
				enchant = ENCHANT_PAT and text:match(ENCHANT_PAT) or text
				enchant = CleanText(enchant)
			end
			if not track and UPGRADE_PAT then
				local name, cur, max = text:match(UPGRADE_PAT)
				if name and cur then track = string.format("%s %s/%s", name, cur, max) end
			end
		end
	end
	return enchant, track
end

-- 보석: 아이템 링크의 보석 칸 번호(item:ID:마부:보석1:보석2:보석3:보석4)를 직접 읽는다
-- (보석 정보가 아직 캐시에 없어도 아이콘은 바로 나온다)
local function Gems(link)
	local icons, empty = {}, 0
	local body = link:match("item:([%-%d:]+)")
	if body then
		local f = {}
		for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
		for i = 3, 6 do
			local id = tonumber(f[i] or "")
			if id and id > 0 then
				local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
				if not icon and GetItemIcon then icon = GetItemIcon(id) end
				if icon then icons[#icons + 1] = icon end
			end
		end
	end
	local stats = C_Item.GetItemStats and C_Item.GetItemStats(link)
	if stats then
		for k, v in pairs(stats) do
			if type(k) == "string" and k:find("^EMPTY_SOCKET") then empty = empty + (v or 0) end
		end
	end
	return icons, math.max(0, empty - #icons)
end

local function SkinSlot(info)
	local b = _G["Character" .. info.name .. "Slot"]
	if not b or S[b] then return end
	local s = { info = info }
	S[b] = s
	Hide("Character" .. info.name .. "SlotFrame")
	Hide(b:GetNormalTexture())
	Hide(b.IconBorder)
	local pushed = b:GetPushedTexture()
	if pushed then pushed:SetTexture(Ink.tex.round4); pushed:SetVertexColor(0, 0, 0, 0.35) end
	local hl = b:GetHighlightTexture()
	if hl then
		hl:SetTexture(Ink.tex.round4)
		if hl.SetTextureSliceMargins then hl:SetTextureSliceMargins(5, 5, 5, 5) end
		hl:SetVertexColor(1, 1, 1, 0.12)
		hl:SetBlendMode("ADD")
	end

	-- 무기 칸 등에 남는 블리자드 장식 그림 지우기 (아이콘 / 눌림 / 강조 제외)
	local keep = { [b:GetPushedTexture() or 0] = true, [b:GetHighlightTexture() or 0] = true,
		[b.icon or 0] = true, [b.Icon or 0] = true }
	for _, r in ipairs({ b:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") and not keep[r] then r:SetAlpha(0) end
	end

	s.glow = b:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.glow:SetTexture(Ink.tex.glow)
	s.glow:SetPoint("TOPLEFT", -12, 12)
	s.glow:SetPoint("BOTTOMRIGHT", 12, -12)
	s.glow:SetAlpha(0)
	s.bg = Ink:Round(b, "BACKGROUND", true, false, -7)
	s.bg:SetAllPoints()
	s.bg:SetVertexColor(0, 0, 0, 0.55)

	local icon = b.icon or b.Icon or _G[b:GetName() .. "IconTexture"]
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		if b.CreateMaskTexture and icon.AddMaskTexture then
			local mask = b:CreateMaskTexture()
			mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(icon)
			icon:AddMaskTexture(mask)
		end
	end
	s.icon = icon

	local top = CreateFrame("Frame", nil, b)
	top:SetAllPoints()
	top:SetFrameLevel(b:GetFrameLevel() + 3)
	top:EnableMouse(false)
	s.border = Ink:Round(top, "OVERLAY", true, true)
	s.border:SetAllPoints()

	if not NO_TEXT[info.name] then
		local t = CreateFrame("Frame", nil, b)
		t:SetSize(TEXT_W, 28)
		t:EnableMouse(false)
		local right = info.side == "R"
		-- 무기는 위 칸 글자와 겹치지 않게 칸 아래쪽에 맞추고 (레벨 위, 이름 아래)
		local weapon = (info.name == "MainHand" or info.name == "SecondaryHand")
		t.weapon = weapon
		if weapon then
			if right then t:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 9, -4) else t:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -9, -4) end
		elseif right then
			t:SetPoint("LEFT", b, "RIGHT", 9, 0)
		else
			t:SetPoint("RIGHT", b, "LEFT", -9, 0)
		end
		local just = right and "LEFT" or "RIGHT"
		-- 글자 뒤 옅은 그늘 (모델 위에서도 읽히게)
		t.shade = t:CreateTexture(nil, "BACKGROUND")
		t.shade:SetTexture(Ink.tex.white)
		t.shade:SetPoint("TOPLEFT", -6, 2)
		t.shade:SetPoint("BOTTOMRIGHT", 6, -2)
		if t.shade.SetGradient and CreateColor then
			local a, z = CreateColor(0, 0, 0, 0.45), CreateColor(0, 0, 0, 0)
			if right then t.shade:SetGradient("HORIZONTAL", a, z) else t.shade:SetGradient("HORIZONTAL", z, a) end
		else
			t.shade:SetVertexColor(0, 0, 0, 0.25)
		end
		t.name = Ink:Text(t, F.semi, 11, C.text, just)
		if weapon then
			t.name:SetPoint("BOTTOM" .. just, 0, 1)
		else
			t.name:SetPoint("TOP" .. just, 0, -1)
		end
		t.name:SetWidth(TEXT_W)
		t.sub = Ink:Text(t, F.sans, 10, C.muted, just)
		if weapon then
			t.sub:SetPoint("BOTTOM" .. just, t.name, "TOP" .. just, 0, 2)
		else
			t.sub:SetPoint("TOP" .. just, t.name, "BOTTOM" .. just, 0, -2)
		end
		t.sub:SetWidth(TEXT_W)
		-- 마법부여 표시: 작은 초록 점 (자세한 이름은 툴팁에서)
		t.ench = t:CreateTexture(nil, "ARTWORK")
		t.ench:SetTexture(Ink.tex.round4)
		t.ench:SetSize(5, 5)
		t.ench:SetVertexColor(0.45, 0.9, 0.62, 1)
		t.ench:Hide()
		t.gems = {}
		for i = 1, 4 do
			local g = t:CreateTexture(nil, "ARTWORK")
			g:SetSize(11, 11)
			g:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			g:Hide()
			t.gems[i] = g
		end
		t.right = right
		s.text = t
	end
end

local function PaintSlot(b)
	local s = S[b]
	if not s then return end
	local id = b:GetID()
	local link = GetInventoryItemLink("player", id)
	local t = s.text
	if not link then
		s.border:SetVertexColor(1, 1, 1, 0.08)
		s.glow:SetAlpha(0)
		if s.icon then s.icon:SetDesaturated(true); s.icon:SetAlpha(0.35) end
		if t then t:Hide() end
		return
	end
	if s.icon then s.icon:SetDesaturated(false); s.icon:SetAlpha(1) end
	local q = GetInventoryItemQuality("player", id) or 1
	local r, g, bl = 1, 1, 1
	if C_Item.GetItemQualityColor then r, g, bl = C_Item.GetItemQualityColor(q) end
	if q >= 2 then
		s.border:SetVertexColor(r, g, bl, 0.95)
		s.glow:SetVertexColor(r, g, bl)
		s.glow:SetAlpha(q >= 4 and 0.42 or 0.24)
	else
		s.border:SetVertexColor(1, 1, 1, 0.14)
		s.glow:SetAlpha(0)
	end
	if not t then return end
	t:Show()

	local name = C_Item.GetItemInfo and C_Item.GetItemInfo(link)
	name = name or link:match("%[(.-)%]") or ""
	t.name:SetText(name)
	t.name:SetTextColor(r, g, bl)

	local lvl
	if ItemLocation and C_Item.GetCurrentItemLevel then
		local ok, v = pcall(function() return C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(id)) end)
		if ok then lvl = plain(v) end
	end
	local enchant, track = ScanSlot(id)
	local sub = lvl and tostring(lvl) or ""
	if track then sub = sub .. "  " .. track end
	t.sub:SetText(sub)
	local w = t.sub:GetStringWidth() or 0
	if issecretvalue and issecretvalue(w) then w = 40 end
	w = math.min(w, TEXT_W)

	-- 레벨 줄 끝: 마법부여 점 → 보석 아이콘 (빈 홈은 회색 점)
	local off = w + 6
	local function Place(r, size)
		r:ClearAllPoints()
		if t.right then
			r:SetPoint("LEFT", t.sub, "LEFT", off, 0)
		else
			r:SetPoint("RIGHT", t.sub, "RIGHT", -off, 0)
		end
		off = off + size + 3
	end
	if enchant and enchant ~= "" then
		Place(t.ench, 5)
		t.ench:Show()
	else
		t.ench:Hide()
	end
	local icons, empty = Gems(link)
	for i, g in ipairs(t.gems) do
		local icon = icons[i]
		local isEmpty = not icon and (i - #icons) <= empty
		if icon or isEmpty then
			Place(g, 11)
			if icon then
				g:SetTexture(icon)
				g:SetVertexColor(1, 1, 1, 1)
			else
				g:SetTexture(Ink.tex.round4)
				g:SetVertexColor(1, 1, 1, 0.18)
			end
			g:Show()
		else
			g:Hide()
		end
	end
end

function M:PaintAll()
	for _, info in ipairs(SLOTS) do
		local b = _G["Character" .. info.name .. "Slot"]
		if b then PaintSlot(b) end
	end
end

-------------------------------------------------------------------------------
-- 오른쪽 능력치
-------------------------------------------------------------------------------
local function SkinStats()
	local pane = CharacterStatsPane
	if not pane then return end
	Hide(pane.ClassBackground)
	local ilf = pane.ItemLevelFrame
	if ilf then
		Hide(ilf.Background)
		FontOf(ilf.Value, F.num, 24, C.accent)
	end
	for _, key in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
		local cat = pane[key]
		if cat then
			Hide(cat.Background)
			FontOf(cat.Title, F.semi, 12, C.soft)
			if not S[cat] and cat.Title then
				S[cat] = true
				local line = cat:CreateTexture(nil, "ARTWORK")
				line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
				line:SetSize(16, 2)
				line:SetPoint("TOP", cat.Title, "BOTTOM", 0, -3)
			end
		end
	end
	for _, child in ipairs({ pane:GetChildren() }) do
		if child.Label and child.Value then
			Hide(child.Background)
			FontOf(child.Label, F.sans, 12, C.muted)
			FontOf(child.Value, F.semi, 12, C.text)
		end
	end
end

-------------------------------------------------------------------------------
-- 아래 탭 (장비 / 평판 / 화폐)
-------------------------------------------------------------------------------
-- 탭은 공통 창 꾸미기(Windows.lua)와 같은 모양
local function SkinTabs()
	if ns.Win then ns.Win.Tabs(CharacterFrame); ns.Win.TabUpdateAll() end
end

-------------------------------------------------------------------------------
-- 창 전체
-------------------------------------------------------------------------------
function M:UpdateTitle()
	local f = CharacterFrame
	local s = S[f]
	if not s then return end
	local _, class = UnitClass("player")
	local r, g, b = ns.ClassTint(class)
	s.glowModel:SetVertexColor(r, g, b)
	local title = CharacterFrameTitleText or (f.TitleContainer and f.TitleContainer.TitleText)
	if title then
		FontOf(title, F.bold, 15)
		title:SetTextColor(r, g, b)
	end
	if CharacterLevelText then FontOf(CharacterLevelText, F.sans, 11, C.muted) end
	s.accent:SetVertexColor(r, g, b, 1)
end

function M:Skin()
	local f = CharacterFrame
	if not f or S[f] then return end
	local s = {}
	S[f] = s

	-- 블리자드 틀 숨기기
	Strip(f)
	Hide(f.NineSlice)
	Hide(f.Bg)
	Hide(f.Background)
	Hide(f.TitleBg)
	Hide(f.TopTileStreaks)
	if f.PortraitContainer then f.PortraitContainer:SetAlpha(0) end
	Hide(f.Portrait)
	Hide(CharacterFramePortrait)
	if f.TitleContainer then Strip(f.TitleContainer) end
	for _, inset in ipairs({ CharacterFrameInset, CharacterFrameInsetRight }) do
		if inset then
			Hide(inset.NineSlice)
			Hide(inset.Bg)
			Hide(inset.AbsBg)
			Strip(inset)
		end
	end
	Hide(CharacterFrameInsetBG)
	for _, n in ipairs({ "TopLeft", "TopRight", "BotLeft", "BotRight", "Overlay" }) do
		Hide("CharacterModelFrameBackground" .. n)
	end
	if CharacterModelScene then
		for _, n in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }) do
			Hide(CharacterModelScene[n])
		end
	end
	for _, n in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right", "Bottom2" }) do
		Hide("PaperDollInnerBorder" .. n)
	end
	if f.PaperDollFrame and f.PaperDollFrame.InnerBorder then Strip(f.PaperDollFrame.InnerBorder) end
	Hide(CharacterModelFrameHelpText)
	if PaperDollItemsFrame then Strip(PaperDollItemsFrame) end

	-- Ink 판
	s.bg = Ink:Round(f, "BACKGROUND", false, false, -8)
	s.bg:SetAllPoints()
	s.bg:SetVertexColor(0.035, 0.04, 0.052, 0.96)
	s.bd = Ink:Round(f, "BORDER", false, true, -8)
	s.bd:SetAllPoints()
	s.bd:SetVertexColor(1, 1, 1, 0.08)
	s.shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.shadow:SetTexture(Ink.tex.glow)
	s.shadow:SetPoint("TOPLEFT", -26, 26)
	s.shadow:SetPoint("BOTTOMRIGHT", 26, -26)
	s.shadow:SetVertexColor(0, 0, 0, 0.65)
	s.accent = f:CreateTexture(nil, "ARTWORK")
	s.accent:SetTexture(Ink.tex.white)
	s.accent:SetSize(28, 2)
	s.accent:SetPoint("TOPLEFT", 16, -1)

	-- 캐릭터 뒤 직업색 빛
	local host = CharacterFrameInset or f
	s.glowModel = host:CreateTexture(nil, "BACKGROUND", nil, -6)
	s.glowModel:SetTexture(Ink.tex.glow)
	s.glowModel:SetSize(340, 400)
	s.glowModel:SetPoint("CENTER", host, "CENTER", 0, 10)
	s.glowModel:SetAlpha(0.16)
	s.floor = host:CreateTexture(nil, "BACKGROUND", nil, -5)
	s.floor:SetTexture(Ink.tex.glow)
	s.floor:SetSize(220, 40)
	s.floor:SetPoint("BOTTOM", host, "BOTTOM", 0, 52)
	s.floor:SetVertexColor(0, 0, 0, 0.7)
	if CharacterFrameInsetRight then
		s.right = Ink:Round(CharacterFrameInsetRight, "BACKGROUND", false, false, -7)
		s.right:SetPoint("TOPLEFT", 4, -4)
		s.right:SetPoint("BOTTOMRIGHT", -4, 4)
		s.right:SetVertexColor(1, 1, 1, 0.025)
	end

	-- 닫기 버튼: 블리자드 그림 대신 ×
	local close = CharacterFrameCloseButton or f.CloseButton
	if close then
		Hide(close:GetNormalTexture())
		Hide(close:GetPushedTexture())
		Hide(close:GetDisabledTexture())
		local hl = close:GetHighlightTexture()
		if hl then hl:SetTexture(Ink.tex.round4); hl:SetVertexColor(1, 1, 1, 0.1) end
		local x = Ink:Text(close, F.semi, 15, C.soft, "CENTER")
		x:SetPoint("CENTER", 0, 1)
		x:SetText("×")
	end

	-- 옆 작은 탭 (능력치 / 칭호 / 장비 관리)
	for i = 1, 4 do
		local st = _G["PaperDollSidebarTab" .. i]
		if st then
			Hide(st.TabBg)
			Hide(st.Hider)
			local b = Ink:Round(st, "BACKGROUND", true, false, -8)
			b:SetAllPoints()
			b:SetVertexColor(1, 1, 1, 0.05)
		end
	end

	for _, info in ipairs(SLOTS) do SkinSlot(info) end
	SkinStats()
	SkinTabs()
	self:UpdateTitle()
	self:PaintAll()

	-- 블리자드가 칸을 다시 그릴 때마다 Ink 모양 다시 입히기
	if PaperDollItemSlotButton_Update then
		hooksecurefunc("PaperDollItemSlotButton_Update", function(b)
			if S[b] then
				Hide(b.IconBorder)
				PaintSlot(b)
			end
		end)
	end
	if PaperDollFrame_UpdateStats then hooksecurefunc("PaperDollFrame_UpdateStats", SkinStats) end
	if PanelTemplates_SetTab then
		hooksecurefunc("PanelTemplates_SetTab", function(frame) if frame == CharacterFrame then SkinTabs() end end)
	end
	f:HookScript("OnShow", function()
		SkinTabs()
		SkinStats()
		M:UpdateTitle()
		M:PaintAll()
	end)
end

function M:Init()
	if Ink.db.charSheet == false then return end
	local e = CreateFrame("Frame")
	e:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	e:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	e:RegisterEvent("SOCKET_INFO_UPDATE")
	e:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
	e:RegisterEvent("ADDON_LOADED")
	e:SetScript("OnEvent", function(_, event)
		if event == "ADDON_LOADED" then
			if CharacterFrame and not S[CharacterFrame] then M:Skin() end
			return
		end
		if CharacterFrame and CharacterFrame:IsShown() then
			C_Timer.After(0.05, function() M:PaintAll() end)
		end
	end)
	if CharacterFrame then self:Skin() end
end
