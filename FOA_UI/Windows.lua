-- InkUI · 기본 창 꾸미기 (연락처 / 길드 / 파티 찾기 / 마법책·특성 / 업적 / 수집품 / 상점 / 우편 …)
--  블리자드 창은 그대로 쓰고 "껍데기"만 Ink 결로 바꾼다.
--  · 테두리·초상화·양피지 같은 블리자드 장식 숨김 → 어두운 둥근 판 + 옅은 테두리 + 그림자 + 포인트 선
--  · 제목 / 닫기(×) / 아래 탭 / 빨간 버튼 / 검색창을 Ink 모양으로
--  · 게임 전체 기본 글꼴을 Ink 글꼴(IBM Plex Sans KR)로 (크기는 그대로)
--  블리자드 프레임에 키를 쓰지 않고 바깥 표(S)에 둔다. 위치·크기는 건드리지 않는다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Windows")
local F, C = Ink.font, Ink.c

local S = setmetatable({}, { __mode = "k" })
local W = {}
ns.Win = W

local function Forbidden(f)
	return not f or (f.IsForbidden and f:IsForbidden())
end

local function Fade(x)
	if type(x) == "string" then x = _G[x] end
	if x and x.SetAlpha then x:SetAlpha(0) end
end

local function FadeRegions(f, keep)
	if Forbidden(f) or not f.GetRegions then return end
	for _, r in ipairs({ f:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") and not (keep and keep[r]) then r:SetAlpha(0) end
	end
end

local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local function FadeNine(n)
	if not n then return end
	FadeRegions(n)
	for _, k in ipairs(NINE) do Fade(n[k]) end
	n:SetAlpha(0)
end
W.FadeNine = FadeNine

-------------------------------------------------------------------------------
-- 탭 (아래쪽 탭 / 위쪽 탭 시스템 공통)
--  블리자드 글자는 투명하게 두고 Ink 글자를 위에 얹는다 (블리자드가 글꼴을 바꿔도 안 보임)
-------------------------------------------------------------------------------
local hiddenFont = CreateFont("InkUIHiddenFont")
hiddenFont:SetFont(F.sans, 12, "")
hiddenFont:SetTextColor(0, 0, 0, 0)
hiddenFont:SetShadowColor(0, 0, 0, 0)

local tabs = setmetatable({}, { __mode = "k" })

local function TabSelected(tab)
	local p = tab:GetParent()
	if p and p.selectedTabID ~= nil and tab.tabID ~= nil then return p.selectedTabID == tab.tabID end
	if tab.isSelected ~= nil then return tab.isSelected and true or false end
	if p and PanelTemplates_GetSelectedTab and tab.GetID then
		local ok, sel = pcall(PanelTemplates_GetSelectedTab, p)
		if ok and sel ~= nil then return sel == tab:GetID() end
	end
	if tab.IsEnabled then return not tab:IsEnabled() end
	return false
end

local function HideBlizLabel(tab, s)
	if tab.SetNormalFontObject then
		tab:SetNormalFontObject(hiddenFont)
		tab:SetHighlightFontObject(hiddenFont)
		tab:SetDisabledFontObject(hiddenFont)
	end
	if s.bliz then
		s.bliz:SetAlpha(0)
		s.bliz:SetTextColor(0, 0, 0, 0)
	end
	for _, r in ipairs({ tab:GetRegions() }) do
		if r ~= s.bg and r ~= s.line and r ~= s.label and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0)
		end
	end
end

local function TabUpdate(tab)
	local s = S[tab]
	if not s or Forbidden(tab) then return end
	HideBlizLabel(tab, s)
	if s.bliz and s.bliz.GetText then s.label:SetText(s.bliz:GetText() or "") end
	local on = TabSelected(tab)
	local c = on and C.text or C.muted
	s.label:SetTextColor(c[1], c[2], c[3])
	s.line:SetShown(on)
	s.bg:SetVertexColor(on and 0.06 or 0.035, on and 0.065 or 0.04, on and 0.08 or 0.052, 0.94)
end

local function TabUpdateAll()
	for tab in pairs(tabs) do TabUpdate(tab) end
	if W.RailUpdate then W.RailUpdate() end
end
W.TabUpdateAll = TabUpdateAll

local hooked
local function TabHooks()
	if hooked then return end
	hooked = true
	for _, fn in ipairs({ "PanelTemplates_SetTab", "PanelTemplates_UpdateTabs", "PanelTemplates_SelectTab",
		"PanelTemplates_DeselectTab", "PanelTemplates_TabResize" }) do
		if _G[fn] then hooksecurefunc(fn, TabUpdateAll) end
	end
end

function W.Tab(tab)
	if Forbidden(tab) then return end
	if S[tab] then TabUpdate(tab) return end
	local s = {}
	S[tab] = s
	tabs[tab] = true
	s.bliz = tab.Text or (tab.GetFontString and tab:GetFontString())
	s.bg = Ink:Round(tab, "BACKGROUND", true, false, -8)
	s.bg:SetPoint("TOPLEFT", 3, -2)
	s.bg:SetPoint("BOTTOMRIGHT", -3, 3)
	s.label = Ink:Text(tab, F.semi, 12, C.muted, "CENTER")
	s.label:SetPoint("CENTER", 0, 0)
	s.line = tab:CreateTexture(nil, "OVERLAY")
	s.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	s.line:SetSize(18, 2)
	s.line:SetPoint("BOTTOM", 0, 5)
	local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
	if hl then hl:SetAlpha(0) end
	local function Sync() if s.bliz and s.bliz.GetText then s.label:SetText(s.bliz:GetText() or "") end end
	if tab.SetText then hooksecurefunc(tab, "SetText", Sync) end
	if s.bliz and s.bliz.SetText then hooksecurefunc(s.bliz, "SetText", Sync) end
	tab:HookScript("OnClick", function()
		C_Timer.After(0, TabUpdateAll)
		if W.DeepAllShown then W.DeepAllShown() end
	end)
	tab:HookScript("OnEnter", function() if not TabSelected(tab) then s.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end end)
	tab:HookScript("OnLeave", function() TabUpdate(tab) end)
	TabHooks()
	TabUpdate(tab)
end

function W.Tabs(f)
	if Forbidden(f) then return end
	local name = f.GetName and f:GetName()
	if type(f.Tabs) == "table" then
		for _, t in pairs(f.Tabs) do if type(t) == "table" and t.GetObjectType then W.Tab(t) end end
	end
	if name then
		for i = 1, 12 do
			local t = _G[name .. "Tab" .. i]
			if t then W.Tab(t) end
		end
	end
	local ts = f.TabSystem
	if ts and ts.GetChildren then
		for _, c in ipairs({ ts:GetChildren() }) do
			if c.GetObjectType and c:GetObjectType() == "Button" then W.Tab(c) end
		end
		if ts.SetTab and not S[ts] then
			S[ts] = true
			hooksecurefunc(ts, "SetTab", TabUpdateAll)
		end
	end
end

-------------------------------------------------------------------------------
-- 닫기 / 버튼 / 검색창
-------------------------------------------------------------------------------
function W.Close(b)
	if Forbidden(b) or S[b] then return end
	S[b] = true
	Fade(b.GetNormalTexture and b:GetNormalTexture())
	Fade(b.GetPushedTexture and b:GetPushedTexture())
	Fade(b.GetDisabledTexture and b:GetDisabledTexture())
	FadeRegions(b)
	local hl = b.GetHighlightTexture and b:GetHighlightTexture()
	if hl then
		hl:SetTexture(Ink.tex.round4)
		hl:SetVertexColor(1, 1, 1, 0.1)
		hl:SetAlpha(1)
	end
	local x = Ink:Text(b, F.semi, 15, C.soft, "CENTER")
	x:SetPoint("CENTER", 0, 1)
	x:SetText("×")
end

-- 빨간 3조각 버튼 (UIPanelButtonTemplate 등) → Ink 둥근 버튼
local function IsThreeSlice(b)
	return b.Left and b.Middle and b.Right and b.Left.IsObjectType and b.Left:IsObjectType("Texture")
end

function W.Button(b)
	if Forbidden(b) or S[b] or tabs[b] then return end
	S[b] = true
	Fade(b.Left); Fade(b.Middle); Fade(b.Right)
	Fade(b.LeftDisabled); Fade(b.MiddleDisabled); Fade(b.RightDisabled)
	Fade(b.GetNormalTexture and b:GetNormalTexture())
	Fade(b.GetPushedTexture and b:GetPushedTexture())
	Fade(b.GetDisabledTexture and b:GetDisabledTexture())
	local bg = Ink:Round(b, "BACKGROUND", true, false, -8)
	bg:SetAllPoints()
	bg:SetVertexColor(1, 1, 1, 0.06)
	local bd = Ink:Round(b, "BORDER", true, true, -8)
	bd:SetAllPoints()
	bd:SetVertexColor(1, 1, 1, 0.1)
	local hl = b.GetHighlightTexture and b:GetHighlightTexture()
	if hl then
		hl:SetTexture(Ink.tex.round4)
		if hl.SetTextureSliceMargins then hl:SetTextureSliceMargins(5, 5, 5, 5) end
		hl:SetVertexColor(1, 1, 1, 0.08)
		hl:SetAlpha(1)
	end
end

function W.EditBox(e)
	if Forbidden(e) or S[e] then return end
	S[e] = true
	Fade(e.Left); Fade(e.Middle); Fade(e.Right)
	Fade(e.TopLeft); Fade(e.TopRight); Fade(e.BottomLeft); Fade(e.BottomRight)
	Fade(e.TopMiddle); Fade(e.BottomMiddle); Fade(e.MiddleLeft); Fade(e.MiddleRight); Fade(e.MiddleMiddle)
	local bg = Ink:Round(e, "BACKGROUND", true, false, -8)
	bg:SetPoint("TOPLEFT", -4, 0)
	bg:SetPoint("BOTTOMRIGHT", 0, 0)
	bg:SetVertexColor(1, 1, 1, 0.05)
	local bd = Ink:Round(e, "BORDER", true, true, -8)
	bd:SetAllPoints(bg)
	bd:SetVertexColor(1, 1, 1, 0.09)
end

-------------------------------------------------------------------------------
-- 깊게 훑기: 장식 그림 지우기 + 버튼 / 탭 / 검색창 / 드롭다운 / 스크롤바 / 목록 줄 / 왼쪽 메뉴 버튼
-------------------------------------------------------------------------------
-- 이름(아틀라스·파일 경로)에 이런 말이 들어간 그림은 장식으로 보고 지운다
local ART = { "background", "parchment", "wood", "metal", "filigree", "corner", "-bg", "bg-", "_bg", "watermark",
	"plaque", "border", "frame", "divider", "inset", "shadow", "edge", "ornate", "tile", "header", "nineslice",
	"panel", "gradient", "streak", "trim", "scrollbar", "slider", "dropdown", "ui-panel", "common-", "insetframe",
	"dialog", "marble", "stone", "sheen" }
-- 이런 말이 들어가면 내용(아이콘·초상화·특성 배경 등)이라 남긴다
local KEEP = { "icons", "icon", "portrait", "class", "role", "spec", "talent", "model", "inkui", "statusbar",
	"achievement_", "coin", "currency", "emblem", "raidtarget", "flag", "glow", "check", "radio", "arrow" }

local function IsArt(r)
	local hay = (r.GetAtlas and r:GetAtlas()) or (r.GetTexture and r:GetTexture())
	if type(hay) ~= "string" or hay == "" then return false end
	if issecretvalue and issecretvalue(hay) then return false end
	hay = hay:lower()
	for _, k in ipairs(KEEP) do if hay:find(k, 1, true) then return false end end
	for _, k in ipairs(ART) do if hay:find(k, 1, true) then return true end end
	return false
end

local function FadeArt(f, depth)
	if Forbidden(f) or depth > 10 or not f.GetRegions then return end
	local sbTex = f.GetStatusBarTexture and f:GetStatusBarTexture()
	for _, r in ipairs({ f:GetRegions() }) do
		if r ~= sbTex and r.IsObjectType and r:IsObjectType("Texture") and (r:GetAlpha() or 0) > 0 and IsArt(r) then
			r:SetAlpha(0)
		end
	end
	for _, c in ipairs({ f:GetChildren() }) do FadeArt(c, depth + 1) end
end
W.FadeArt = FadeArt

-- 드롭다운 (유형 선택 등)
function W.Dropdown(d)
	if Forbidden(d) or S[d] then return end
	S[d] = true
	Fade(d.Background)
	Fade(d.GetNormalTexture and d:GetNormalTexture())
	Fade(d.GetPushedTexture and d:GetPushedTexture())
	Fade(d.Left); Fade(d.Middle); Fade(d.Right)
	local bg = Ink:Round(d, "BACKGROUND", true, false, -8)
	bg:SetAllPoints()
	bg:SetVertexColor(1, 1, 1, 0.05)
	local bd = Ink:Round(d, "BORDER", true, true, -8)
	bd:SetAllPoints()
	bd:SetVertexColor(1, 1, 1, 0.1)
	if d.Arrow then d.Arrow:SetVertexColor(C.muted[1], C.muted[2], C.muted[3]) end
	local t = d.Text or (d.GetFontString and d:GetFontString())
	if t and t.SetFont then
		local _, size = t:GetFont()
		t:SetFont(F.sans, size or 12, "")
		t:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	local hl = d.GetHighlightTexture and d:GetHighlightTexture()
	if hl then hl:SetTexture(Ink.tex.round4); hl:SetVertexColor(1, 1, 1, 0.06) end
end

-- 스크롤바: 홈은 지우고 손잡이만 얇은 둥근 막대로
function W.ScrollBar(sb)
	if Forbidden(sb) or S[sb] then return end
	S[sb] = true
	FadeRegions(sb)
	if sb.Track then
		FadeRegions(sb.Track)
		for _, k in ipairs({ "Begin", "Middle", "End" }) do Fade(sb.Track[k]) end
	end
	local th = sb.Thumb or (sb.GetThumbTexture and sb:GetThumbTexture())
	if th and th.GetRegions then
		FadeRegions(th)
		for _, k in ipairs({ "Begin", "Middle", "End" }) do Fade(th[k]) end
		local pill = th:CreateTexture(nil, "OVERLAY")
		pill:SetTexture(Ink.tex.round4)
		if pill.SetTextureSliceMargins then pill:SetTextureSliceMargins(5, 5, 5, 5) end
		pill:SetPoint("TOP", 0, -1)
		pill:SetPoint("BOTTOM", 0, 1)
		pill:SetWidth(4)
		pill:SetVertexColor(1, 1, 1, 0.28)
	end
	for _, k in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
		local b = sb[k]
		if b and b.SetAlpha then b:SetAlpha(0.35) end
	end
end

-- 왼쪽 큰 메뉴 버튼 (파티 찾기의 던전 찾기 / 공격대 찾기 …): 둥근 판 + 선택 시 노란 세로선
local rails = setmetatable({}, { __mode = "k" })
function W.Rail(b)
	if Forbidden(b) or S[b] then return end
	local s = {}
	S[b] = s
	rails[b] = true
	Fade(b.bg); Fade(b.Background); Fade(b.ring); Fade(b.Ring); Fade(b.CircleMask)
	Fade(b.GetNormalTexture and b:GetNormalTexture())
	Fade(b.GetPushedTexture and b:GetPushedTexture())
	local icon = b.icon or b.Icon
	if icon and b.CreateMaskTexture and icon.AddMaskTexture then
		local m = b:CreateMaskTexture()
		m:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		m:SetAllPoints(icon)
		icon:AddMaskTexture(m)
	end
	s.bg = Ink:Round(b, "BACKGROUND", false, false, -8)
	s.bg:SetPoint("TOPLEFT", 2, -2)
	s.bg:SetPoint("BOTTOMRIGHT", -2, 2)
	s.bar = b:CreateTexture(nil, "OVERLAY")
	s.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	s.bar:SetPoint("TOPLEFT", 2, -10)
	s.bar:SetPoint("BOTTOMLEFT", 2, 10)
	s.bar:SetWidth(2)
	local hl = b.GetHighlightTexture and b:GetHighlightTexture()
	if hl then
		hl:SetTexture(Ink.tex.round)
		if hl.SetTextureSliceMargins then hl:SetTextureSliceMargins(8, 8, 8, 8) end
		hl:ClearAllPoints()
		hl:SetPoint("TOPLEFT", 2, -2)
		hl:SetPoint("BOTTOMRIGHT", -2, 2)
		hl:SetVertexColor(1, 1, 1, 0.05)
	end
	local t = b.name or b.Name or b.Label
	if t and t.SetFont then
		t:SetFont(F.semi, 13, "")
		t:SetShadowColor(0, 0, 0, 0.8)
	end
	s.label = t
end

-- 블리자드 선택 함수에서 알려 준 선택 상태 (버튼 목록, 선택 번호)
function W.RailSelect(list, index)
	for i, b in ipairs(list) do
		if S[b] then S[b].forced = (i == index) end
	end
	W.RailUpdate()
end

function W.RailUpdate()
	for b in pairs(rails) do
		local s = S[b]
		if s and not Forbidden(b) then
			local sel = s.forced
			if sel == nil then
				sel = (b.GetChecked and b:GetChecked()) or (b.selected == true)
					or (b.Selected and b.Selected.IsShown and b.Selected:IsShown())
			end
			Fade(b.Selected or b.SelectedTexture)
			s.bar:SetShown(sel and true or false)
			s.bg:SetVertexColor(1, 1, 1, sel and 0.07 or 0.03)
			if s.label and s.label.SetTextColor then
				local c = sel and C.text or C.soft
				s.label:SetTextColor(c[1], c[2], c[3])
			end
		end
	end
end

-- 목록 한 줄 (친구 목록 등 ScrollBox 로 계속 새로 만들어지는 줄)
local function SkinRow(row)
	if Forbidden(row) then return end
	FadeArt(row, 6)
	for _, k in ipairs({ "background", "Background", "BG", "Bg" }) do
		local r = row[k]
		if r and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
	end
	if not S[row] then
		S[row] = true
		local hl = row.GetHighlightTexture and row:GetHighlightTexture()
		if hl then
			hl:SetTexture(Ink.tex.round4)
			if hl.SetTextureSliceMargins then hl:SetTextureSliceMargins(5, 5, 5, 5) end
			hl:SetVertexColor(1, 1, 1, 0.06)
			hl:SetBlendMode("ADD")
		end
		local line = row:CreateTexture(nil, "BACKGROUND", nil, -7)
		line:SetColorTexture(1, 1, 1, 0.04)
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT", 4, 0)
		line:SetPoint("BOTTOMRIGHT", -4, 0)
	end
end

local boxes = setmetatable({}, { __mode = "k" })
local function WatchBox(box)
	if boxes[box] or not (ScrollUtil and ScrollUtil.AddAcquiredFrameCallback) then return end
	boxes[box] = true
	pcall(ScrollUtil.AddAcquiredFrameCallback, box, function(_, row) pcall(SkinRow, row) end, M, true)
end

local function Sweep(f, depth)
	if Forbidden(f) or depth > 10 or not f.GetChildren then return end
	for _, c in ipairs({ f:GetChildren() }) do
		if not Forbidden(c) and c.GetObjectType then
			local t = c:GetObjectType()
			local n = c.GetName and c:GetName()
			if tabs[c] or rails[c] then
				-- 이미 정리됨
			elseif (t == "Button" or t == "CheckButton") and (c.ring or c.Ring) and (c.icon or c.Icon) then
				W.Rail(c)
			elseif t == "Button" and IsThreeSlice(c) and n and n:find("Tab%d") then
				W.Tab(c)
			elseif t == "Button" and IsThreeSlice(c) then
				W.Button(c)
			elseif t == "EditBox" and (c.Left or c.Middle or c.TopLeft) then
				W.EditBox(c)
			elseif t == "DropdownButton" or (c.Arrow and c.Background and t == "Button") then
				W.Dropdown(c)
			elseif (c.Track and c.Thumb) or t == "Slider" and n and n:find("ScrollBar") then
				W.ScrollBar(c)
			end
			if c.ScrollTarget and c.RegisterCallback then WatchBox(c) end
			if (n and n:find("Inset$")) or (f.Inset == c) then
				FadeNine(c.NineSlice)
				Fade(c.Bg)
				if not S[c] then
					S[c] = true
					local p = Ink:Round(c, "BACKGROUND", false, false, -8)
					p:SetPoint("TOPLEFT", 2, -2)
					p:SetPoint("BOTTOMRIGHT", -2, 2)
					p:SetVertexColor(1, 1, 1, 0.025)
				end
			elseif c.NineSlice and not S[c] then
				FadeNine(c.NineSlice)
			end
			Sweep(c, depth + 1)
		end
	end
end
W.Sweep = Sweep

-- 창 하나 깊게 정리 (열릴 때 / 탭 바꿀 때 다시)
local shells = setmetatable({}, { __mode = "k" })
local function Deep(f)
	local o = shells[f]
	if not o or Forbidden(f) then return end
	if not o.noSweep then Sweep(f, 0) end
	if not o.noArt then FadeArt(f, 0) end
	W.Tabs(f)
	TabUpdateAll()
	W.RailUpdate()
end
local pendingDeep = {}
function W.DeepSoon(f)
	if pendingDeep[f] then return end
	pendingDeep[f] = true
	C_Timer.After(0.05, function()
		pendingDeep[f] = nil
		pcall(Deep, f)
	end)
end
function W.DeepAllShown()
	for f in pairs(shells) do
		if f:IsShown() then W.DeepSoon(f) end
	end
end

-------------------------------------------------------------------------------
-- 창 껍데기
-------------------------------------------------------------------------------
function W.Shell(f, opts)
	if Forbidden(f) or S[f] then return end
	opts = opts or {}
	local s = {}
	S[f] = s
	local name = f.GetName and f:GetName()

	FadeNine(f.NineSlice)
	for _, k in ipairs({ "Bg", "Background", "TitleBg", "TopTileStreaks", "portrait", "Portrait", "PortraitFrame", "PortraitOverlay" }) do
		local r = f[k]
		if r and r.SetAlpha then r:SetAlpha(0) end
	end
	if f.PortraitContainer then f.PortraitContainer:SetAlpha(0) end
	if f.TitleContainer then FadeRegions(f.TitleContainer) end
	if f.Border then FadeNine(f.Border) end
	if not opts.keepRegions then FadeRegions(f) end
	if name then
		for _, k in ipairs({ "Bg", "TitleBg", "Portrait", "PortraitFrame", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder" }) do
			Fade(name .. k)
		end
	end

	s.shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.shadow:SetTexture(Ink.tex.glow)
	s.shadow:SetPoint("TOPLEFT", -26, 26)
	s.shadow:SetPoint("BOTTOMRIGHT", 26, -26)
	s.shadow:SetVertexColor(0, 0, 0, 0.6)
	s.bg = Ink:Round(f, "BACKGROUND", false, false, -8)
	s.bg:SetAllPoints()
	s.bg:SetVertexColor(0.035, 0.04, 0.052, opts.alpha or 0.96)
	s.bd = Ink:Round(f, "BORDER", false, true, -8)
	s.bd:SetAllPoints()
	s.bd:SetVertexColor(1, 1, 1, 0.08)
	s.accent = f:CreateTexture(nil, "ARTWORK")
	s.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	s.accent:SetSize(28, 2)
	s.accent:SetPoint("TOPLEFT", 16, -1)

	local title = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText or (name and _G[name .. "TitleText"])
	if title and title.SetFont then
		title:SetFont(F.bold, 14, "")
		title:SetTextColor(C.text[1], C.text[2], C.text[3])
		title:SetShadowColor(0, 0, 0, 0.85)
		title:SetShadowOffset(1, -1)
	end
	W.Close(f.CloseButton or f.closeButton or (name and _G[name .. "CloseButton"]))
	shells[f] = opts
	pcall(Deep, f)
	if f.HookScript then
		-- 열릴 때마다 새로 생긴 내용까지 다시 정리
		f:HookScript("OnShow", function() W.DeepSoon(f) end)
	end
	return s
end

-------------------------------------------------------------------------------
-- 창 목록 (지금 있으면 바로, 나중에 불러와지면 그때)
-------------------------------------------------------------------------------
local LIST = {
	{ "FriendsFrame" },                                  -- 연락처 (O)
	{ "SocialUIFrame" },                                 -- 12.1 새 연락처 창
	{ "CommunitiesFrame" },                              -- 길드 / 커뮤니티 (J)
	{ "PVEFrame" },                                      -- 파티 찾기 (I)
	{ "PlayerSpellsFrame", { keepRegions = true } },    -- 마법책 / 특성 (P, N)
	{ "AchievementFrame", { art = true, keepRegions = true } }, -- 업적 (Y)
	{ "CollectionsJournal" },                            -- 수집품
	{ "EncounterJournal" },                              -- 모험 안내서
	{ "WeeklyRewardsFrame", { art = true, keepRegions = true } }, -- 위대한 금고
	{ "MerchantFrame" }, { "MailFrame" }, { "OpenMailFrame" },
	{ "GossipFrame", { noArt = true } }, { "QuestFrame", { noArt = true } }, { "ItemTextFrame", { noArt = true } },
	{ "BankFrame" }, { "DressUpFrame" }, { "ClassTrainerFrame" }, { "MacroFrame" }, { "AuctionHouseFrame" },
	{ "ItemUpgradeFrame" }, { "ProfessionsFrame" }, { "ProfessionsBookFrame" }, { "AddonList" },
	{ "ChannelFrame" }, { "TimeManagerFrame" }, { "LootFrame" }, { "SettingsPanel" },
	{ "GameMenuFrame", { keepRegions = true } },
	{ "GuildBankFrame" }, { "ItemSocketingFrame" }, { "InspectFrame" }, { "TabardFrame" },
}

-- 창별 손질
local EXTRA = {}
EXTRA.FriendsFrame = function()
	local bn = FriendsFrameBattlenetFrame
	if bn and not S[bn] then
		S[bn] = true
		FadeRegions(bn)
		local bg = Ink:Round(bn, "BACKGROUND", true, false, -8)
		bg:SetAllPoints()
		bg:SetVertexColor(1, 1, 1, 0.05)
		if bn.Tag and bn.Tag.SetFont then bn.Tag:SetFont(F.semi, 12, "") end
	end
end
EXTRA.PVEFrame = function()
	local gf = GroupFinderFrame
	if gf then
		local list = {}
		for i = 1, 4 do
			local b = gf["groupButton" .. i] or _G["GroupFinderFrameGroupButton" .. i]
			if b then W.Rail(b); list[#list + 1] = b end
		end
		if GroupFinderFrame_SelectGroupButton and not S.gfHook then
			S.gfHook = true
			hooksecurefunc("GroupFinderFrame_SelectGroupButton", function(index) W.RailSelect(list, index) end)
		end
		W.RailSelect(list, gf.selectionIndex or 1)
	end
	local pvp = PVPQueueFrame
	if pvp then
		local list = {}
		for i = 1, 4 do
			local b = pvp["CategoryButton" .. i]
			if b then W.Rail(b); list[#list + 1] = b end
		end
		if PVPQueueFrame_SelectButton and not S.pvpHook then
			S.pvpHook = true
			hooksecurefunc("PVPQueueFrame_SelectButton", function(index) W.RailSelect(list, index) end)
		end
	end
	if PVEFrame_ShowFrame and not S.pveHook then
		S.pveHook = true
		hooksecurefunc("PVEFrame_ShowFrame", function() W.DeepSoon(PVEFrame) end)
	end
end

function M:SkinAll()
	for _, e in ipairs(LIST) do
		local f = _G[e[1]]
		if f and not S[f] then
			local ok, err = pcall(W.Shell, f, e[2])
			if not ok then Ink.winErr = e[1] .. ": " .. tostring(err) end
			if EXTRA[e[1]] then
				ok, err = pcall(EXTRA[e[1]])
				if not ok then Ink.winErr = e[1] .. " extra: " .. tostring(err) end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- 게임 전체 글꼴 → Ink 글꼴 (크기·외곽선은 그대로, 숫자 전용 글꼴은 제외)
-------------------------------------------------------------------------------
local SKIP = { "Number", "Combat", "InkUI", "Chat", "Damage", "Mono" }
function M:GlobalFonts()
	local done = 0
	for name, obj in pairs(_G) do
		if type(name) == "string" and type(obj) == "table" and (name:find("Font") or name:find("^Game") or name:find("^Quest"))
			and not name:find("^InkUI") then
			local ok, isFont = pcall(function() return obj.GetObjectType and obj:GetObjectType() == "Font" end)
			if ok and isFont then
				local skip = false
				for _, k in ipairs(SKIP) do if name:find(k) then skip = true break end end
				if not skip then
					local file, size, flags = obj:GetFont()
					if size and size > 0 then
						local big = name:find("Large") or name:find("Huge") or name:find("Title") or name:find("Header")
						pcall(obj.SetFont, obj, big and F.semi or F.sans, size, flags or "")
						done = done + 1
					end
				end
			end
		end
	end
	self.fontCount = done
end

function M:Init()
	-- 0.9.x 에서 켜져 있던 값은 한 번 꺼 둔다 (블리자드 원래 창으로 복귀)
	if not Ink.db.winReset then
		Ink.db.winReset = true
		Ink.db.windows = false
	end
	if Ink.db.windows ~= true then return end
	pcall(self.GlobalFonts, self)
	self:SkinAll()
	local e = CreateFrame("Frame")
	e:RegisterEvent("ADDON_LOADED")
	e:SetScript("OnEvent", function()
		C_Timer.After(0, function() M:SkinAll() end)
	end)
end
