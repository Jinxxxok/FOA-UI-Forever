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

-- 마법부여 · 보석 효과를 짧게: "민첩성 +7" → "민+7", "체력 +8 및 지능 +2" → "체+8 지+2"
local STAT_SHORT = {
	{ "모든 능력치", "모능" }, { "모든 저항", "모저" }, { "민첩성", "민" }, { "민첩", "민" }, { "힘", "힘" }, { "체력", "체" },
	{ "지능", "지" }, { "정신력", "정" }, { "원거리 전투력", "원전" }, { "공격 전투력", "전투력" }, { "전투력", "전투력" },
	{ "주문 공격력", "주공" }, { "주문 피해", "주피" }, { "주문력", "주문력" }, { "치유", "치유" }, { "치명타", "치명" }, { "적중", "적중" },
	{ "방어 숙련", "방숙" }, { "방어", "방어" }, { "회피", "회피" }, { "막기", "막기" }, { "생명력", "생명" }, { "마나", "마나" },
	{ "이동 속도", "이속" }, { "화염 저항", "화저" }, { "냉기 저항", "냉저" }, { "자연 저항", "자저" }, { "비전 저항", "비저" },
	{ "암흑 저항", "암저" }, { "무기 공격력", "무공" }, { "공격력", "공" }, { "가속", "가속" }, { "숙련", "숙련" },
	{ "All Stats", "All" }, { "All Resistances", "Res" }, { "Agility", "Agi" }, { "Strength", "Str" }, { "Stamina", "Sta" },
	{ "Intellect", "Int" }, { "Spirit", "Spi" }, { "Attack Power", "AP" }, { "Spell Power", "SP" }, { "Healing", "Heal" },
	{ "Critical", "Crit" }, { "Hit", "Hit" }, { "Defense", "Def" }, { "Dodge", "Dodge" }, { "Armor", "Armor" },
	{ "Health", "HP" }, { "Mana", "Mana" }, { "Damage", "Dmg" },
}
local function ShortStats(text)
	if type(text) ~= "string" or text == "" then return nil end
	text = CleanText(text):gsub("^%s+", ""):gsub("%s+$", "")
	local list = text:gsub(" 및 ", ","):gsub(" and ", ","):gsub("/", ",")
	local parts = {}
	for chunk in (list .. ","):gmatch("([^,]+),") do
		local num = chunk:match("([%+%-]?%d+%%?)")
		local short
		for _, p in ipairs(STAT_SHORT) do
			if chunk:find(p[1], 1, true) then short = p[2] break end
		end
		if num and short then
			if not num:find("^[%+%-]") then num = "+" .. num end
			parts[#parts + 1] = short .. num
		end
	end
	if #parts > 0 then return table.concat(parts, " ") end
	-- 숫자가 없는 마법부여(예: 십자군)는 이름 그대로
	return text
end

-- 박힌 보석 효과 (짧게) · 빈 홈 수
local function GemStats(link)
	local out = {}
	local getGem = (C_Item and C_Item.GetItemGem) or GetItemGem
	if getGem and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		for i = 1, 4 do
			local ok, _, glink = pcall(getGem, link, i)
			if ok and glink then
				local ok2, data = pcall(C_TooltipInfo.GetHyperlink, glink)
				for j, line in ipairs(ok2 and data and data.lines or {}) do
					local t = j > 1 and plain(line.leftText)
					if type(t) == "string" and t:find("%d") and (t:find("^%+") or t:find("%+%d")) then
						out[#out + 1] = ShortStats(t)
						break
					end
				end
			end
		end
	end
	local _, empty = Gems(link)
	return (#out > 0) and table.concat(out, " ") or nil, empty
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

	-- 아이템 이름 대신 마법부여 · 보석 효과만 짧게 (이름은 길어서 옆 칸과 겹쳤다 · 이름은 툴팁에서)
	if Ink.db.charSlotText ~= "name" then
		local enchant = ScanSlot(id)
		local es = ShortStats(enchant)
		t.name:SetText(es or "")
		t.name:SetTextColor(0.45, 0.9, 0.62)
		local gs, empty = GemStats(link)
		local sub = gs or ""
		if empty > 0 then sub = (sub ~= "" and (sub .. "  ") or "") .. "빈 홈 " .. empty end
		t.sub:SetText(sub)
		t.sub:SetTextColor(0.6, 0.82, 1)
		t.ench:Hide()
		for _, gm in ipairs(t.gems) do gm:Hide() end
		t.shade:SetShown((es and es ~= "") or sub ~= "")
		return
	end
	t.shade:Show()
	t.sub:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
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

-------------------------------------------------------------------------------
-- 포에버(Camelot) 캐릭터 창: 왼쪽 장비 판 · 오른쪽 능력치 판 · 오른쪽 세로 아이콘 줄
--  블리자드 배경 그림(갈색 돌 · 금색 띠)을 지우고 FOA 판 하나로, 능력치는 제목 + 옅은 줄
-------------------------------------------------------------------------------
local function StripDeep(frame, depth)
	if not frame or (depth or 0) > 4 then return end
	Strip(frame)
	for _, c in ipairs({ frame:GetChildren() }) do
		if not (c.IsObjectType and (c:IsObjectType("Button") or c:IsObjectType("ScrollFrame") or c:IsObjectType("ModelScene"))) then
			StripDeep(c, (depth or 0) + 1)
		end
	end
end

local function SkinStatElem(fr)
	if not fr then return end
	if fr.Background then fr.Background:SetAlpha(0) end
	if fr.Stripe then fr.Stripe:SetAlpha(0) end
	local st = S[fr]
	if fr.Title then
		FontOf(fr.Title, F.semi, 12, C.text)
		if not st then
			st = {}
			S[fr] = st
			st.line = fr:CreateTexture(nil, "ARTWORK")
			st.line:SetColorTexture(1, 1, 1, 0.07)
			st.line:SetHeight(1)
			st.line:SetPoint("BOTTOMLEFT", 6, 2)
			st.line:SetPoint("BOTTOMRIGHT", -6, 2)
			st.acc = fr:CreateTexture(nil, "OVERLAY")
			st.acc:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
			st.acc:SetSize(16, 2)
			st.acc:SetPoint("BOTTOMLEFT", st.line, "TOPLEFT", 0, 0)
		end
		fr.Title:ClearAllPoints()
		fr.Title:SetPoint("BOTTOMLEFT", 6, 7)
		fr.Title:SetJustifyH("LEFT")
		return
	end
	if fr.Label then
		local _, size = fr.Label:GetFont()
		fr.Label:SetFont(F.sans, 11, "")
		fr.Label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		fr.Label:SetShadowColor(0, 0, 0, 0.8)
	end
	if fr.Value then
		fr.Value:SetFont(F.semi, 11, "")
		fr.Value:SetShadowColor(0, 0, 0, 0.8)
	end
	if not st and (fr.Label or fr.Value) then
		st = {}
		S[fr] = st
		st.hl = fr:CreateTexture(nil, "BACKGROUND")
		st.hl:SetTexture(Ink.tex.white)
		st.hl:SetPoint("TOPLEFT", 4, 0)
		st.hl:SetPoint("BOTTOMRIGHT", -4, 0)
		st.hl:SetVertexColor(1, 1, 1, 0.025)
	end
end

local function SkinModeTab(tab)
	if not tab or S[tab] then return end
	local st = {}
	S[tab] = st
	local icon = tab.Icon
	for _, r in ipairs({ tab:GetRegions() }) do
		if r ~= icon and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
	end
	for _, k in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture" }) do
		local t = tab[k] and tab[k](tab)
		if t then t:SetAlpha(0) end
	end
	st.bg = Ink:Round(tab, "BACKGROUND", true, false, -8)
	st.bg:SetPoint("TOPLEFT", 2, -2)
	st.bg:SetPoint("BOTTOMRIGHT", -2, 2)
	st.bd = Ink:Round(tab, "BORDER", true, true, -8)
	st.bd:SetAllPoints(st.bg)
	st.bar = tab:CreateTexture(nil, "OVERLAY")
	st.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	st.bar:SetWidth(2)
	st.bar:SetPoint("TOPLEFT", 0, -8)
	st.bar:SetPoint("BOTTOMLEFT", 0, 8)
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 7, -7)
		icon:SetPoint("BOTTOMRIGHT", -7, 7)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		if tab.CreateMaskTexture and icon.AddMaskTexture then
			local mask = tab:CreateMaskTexture()
			mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(icon)
			icon:AddMaskTexture(mask)
		end
	end
	local function paint(hover)
		local on = tab.GetChecked and tab:GetChecked()
		st.bg:SetVertexColor(on and 0.09 or (hover and 0.075 or 0.045), on and 0.095 or (hover and 0.08 or 0.05), on and 0.115 or (hover and 0.095 or 0.065), 0.95)
		st.bd:SetVertexColor(1, 1, 1, on and 0.22 or 0.07)
		st.bar:SetShown(on and true or false)
		if icon then icon:SetDesaturated(not on and not hover); icon:SetAlpha((on or hover) and 1 or 0.7) end
	end
	st.paint = paint
	if tab.SetChecked then hooksecurefunc(tab, "SetChecked", function() paint() end) end
	tab:HookScript("OnEnter", function() paint(true) end)
	tab:HookScript("OnLeave", function() paint() end)
	paint()
end

function M:SkinForever(f, s)
	if not f.LeftPaneHost then return end
	StripDeep(f.LeftPaneHost)
	StripDeep(f.RightPaneHost)
	-- 능력치 칸 (스크롤 목록)
	local box = _G.CharacterStatsPaneScrollBox
	if box then
		Hide(box.Border)
		Hide(box.ClassBackground)
		local sb = box.ScrollBox
		local function each()
			if sb and sb.ForEachFrame then pcall(sb.ForEachFrame, sb, SkinStatElem) end
		end
		if sb and sb.Update then hooksecurefunc(sb, "Update", each) end
		box:HookScript("OnShow", function() C_Timer.After(0, each) end)
		each()
		if box.ScrollBar then box.ScrollBar:SetAlpha(0.55) end
	end
	-- 능력치 판 바탕: 아주 옅은 판 하나
	if f.RightPaneHost and not s.rightPane then
		s.rightPane = Ink:Round(f.RightPaneHost, "BACKGROUND", false, false, -6)
		s.rightPane:SetPoint("TOPLEFT", 6, -6)
		s.rightPane:SetPoint("BOTTOMRIGHT", -6, 8)
		s.rightPane:SetVertexColor(1, 1, 1, 0.025)
		s.rightLine = f.RightPaneHost:CreateTexture(nil, "ARTWORK")
		s.rightLine:SetColorTexture(1, 1, 1, 0.06)
		s.rightLine:SetWidth(1)
		s.rightLine:SetPoint("TOPLEFT", 0, -10)
		s.rightLine:SetPoint("BOTTOMLEFT", 0, 10)
	end
	-- 장비 판 위쪽 돌 띠 · 테두리 지우기
	local pd = _G.PaperDollFrame
	if pd then
		for _, c in ipairs({ pd:GetChildren() }) do
			if c.Border then Hide(c.Border) end
			if c.TopBackgroundStrip then Hide(c.TopBackgroundStrip); Hide(c.TopBackgroundStripBottomEdge) end
		end
		for _, k in ipairs({ "TopBackgroundStrip", "TopBackgroundStripBottomEdge" }) do Hide(pd[k]) end
	end
	-- 레벨 · 직업 줄
	if CharacterLevelText then FontOf(CharacterLevelText, F.sans, 11, C.muted) end
	-- 접기 단추
	local tb = f.RightPaneToggleButton
	if tb then
		for _, k in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do local t = tb[k](tb); if t then t:SetAlpha(0.6) end end
	end
	-- 오른쪽 세로 아이콘 줄
	if f.ModeTabs and f.ModeTabs.Tabs then
		for _, tab in ipairs(f.ModeTabs.Tabs) do pcall(SkinModeTab, tab) end
	end
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

	pcall(self.SkinForever, self, f, s)
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

-- 캐릭터 창 옮기기: 위쪽 제목 줄을 끌면 옮겨지고, 다음에 열 때도 그 자리 · 제목 줄 오른쪽 클릭 = 원래 자리
--  (블리자드 창 관리자가 왼쪽 기본 자리에 다시 붙이면 바로 내 자리로 되돌린다 · 지도 창과 같은 방식)
function M:MakeMovable()
	local f = CharacterFrame
	if not f or self.moveHandle then return end
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	local h = CreateFrame("Frame", nil, f)
	h:SetPoint("TOPLEFT", f, "TOPLEFT", 50, 0)
	h:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, 0)
	h:SetHeight(26)
	h:SetFrameLevel(f:GetFrameLevel() + 40)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	local busy
	local function place()
		local pos = Ink.db.charPos
		if busy or not pos or (f:IsProtected() and InCombatLockdown()) then return end
		busy = true
		local sc = f:GetScale() or 1
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1] / sc, pos[2] / sc)
		busy = false
	end
	h:SetScript("OnDragStart", function()
		if f:IsProtected() and InCombatLockdown() then return end
		f:StartMoving()
	end)
	h:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local l, t = f:GetLeft(), f:GetTop()
		local sc = f:GetScale() or 1
		if l and t then Ink.db.charPos = { l * sc, t * sc } end
		place()
	end)
	h:SetScript("OnMouseUp", function(_, button)
		if button ~= "RightButton" or not Ink.db.charPos then return end
		-- 블리자드 창 관리자를 애드온이 부르면 오염될 수 있어서, 기억만 지우고 다음에 열 때 원래 자리로
		Ink.db.charPos = nil
		print("|cffFFF468FOA|r 캐릭터 창 위치를 지웠어요 · 다시 열면 원래 자리로 돌아가요")
	end)
	h:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("끌어서 캐릭터 창 옮기기", 1, 1, 1)
		if Ink.db.charPos then GameTooltip:AddLine("오른쪽 클릭: 원래 자리로 (다시 열면 적용)", 0.56, 0.58, 0.61) end
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", GameTooltip_Hide)
	hooksecurefunc(f, "SetPoint", function() if not busy and f:IsShown() then place() end end)
	f:HookScript("OnShow", function() place(); C_Timer.After(0, place) end)
	self.moveHandle = h
end

-- 장비 도우미(GearAdvisor)가 지금 발린 마법부여를 읽을 때 쓴다
M.ScanSlot = ScanSlot
M.ShortStats = ShortStats

function M:Init()
	if CharacterFrame then pcall(self.MakeMovable, self) end
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
			if CharacterFrame and not M.moveHandle then pcall(M.MakeMovable, M) end
			return
		end
		if CharacterFrame and CharacterFrame:IsShown() then
			C_Timer.After(0.05, function() M:PaintAll() end)
		end
	end)
	if CharacterFrame then self:Skin() end
end
