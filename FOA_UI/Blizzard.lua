-- InkUI · 기본 UI 배치와 스킨 (미니맵 / 버프 / 퀘스트 / 채팅 / 가방 / 메뉴 / 행동단축바 / 경험치)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Blizzard")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

local function hideTextures(frame)
	if not frame or not frame.GetRegions then return end
	for _, r in ipairs({ frame:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
	end
end

-------------------------------------------------------------------------------
-- 미니맵: 각진 사각형 + 위/아래 반투명 띠, 주변 버튼 정리
-------------------------------------------------------------------------------
function M:BuildMinimap()
	local a = Ink:Anchor(200, 200)
	self.mmAnchor = a

	local o = CreateFrame("Frame", "InkUIMinimapOverlay", Ink.root)
	o:SetAllPoints(a)
	o:SetFrameStrata("MEDIUM")
	o:EnableMouse(false)
	Ink:Border(o, { 1, 1, 1, 0.16 })

	o.top = o:CreateTexture(nil, "BACKGROUND")
	o.top:SetPoint("TOPLEFT")
	o.top:SetPoint("TOPRIGHT")
	o.top:SetHeight(26)
	o.top:SetColorTexture(0.03, 0.035, 0.045, 0.6)
	o.zone = Ink:Text(o, F.semi, 12, C.text, "LEFT")
	o.zone:SetPoint("TOPLEFT", 10, -6)
	o.zone:SetWidth(150)
	o.north = Ink:Text(o, F.latinB, 10, C.muted, "RIGHT")
	o.north:SetPoint("TOPRIGHT", -32, -8)
	o.north:SetText("N")

	o.bottom = o:CreateTexture(nil, "BACKGROUND")
	o.bottom:SetPoint("BOTTOMLEFT")
	o.bottom:SetPoint("BOTTOMRIGHT")
	o.bottom:SetHeight(22)
	o.bottom:SetColorTexture(0.03, 0.035, 0.045, 0.6)
	o.coords = Ink:Text(o, F.latin, 10, C.soft, "LEFT")
	o.coords:SetPoint("BOTTOMLEFT", 10, 5)
	self.mmOverlay = o

	local t, scan = 0, 0
	o:SetScript("OnUpdate", function(_, e)
		t = t + e
		scan = scan + e
		if t < 0.5 then return end
		t = 0
		M:UpdateMinimapText()
		-- 미니맵 밑 중복 좌표는 늦게 생기기도 해서 가끔 다시 찾는다
		if scan > 5 then
			scan = 0
			pcall(M.HideExtraCoords, M)
		end
	end)

	for _, n in ipairs({ "MinimapCompassTexture", "TimeManagerClockButton", "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag", "MinimapBackdrop" }) do
		if _G[n] then Ink:Fade(_G[n]) end
	end
	local mc = MinimapCluster
	if mc then
		for _, k in ipairs({ "BorderTop", "ZoneTextButton", "Tracking", "TrackingFrame" }) do
			if mc[k] then Ink:KeepHidden(mc[k]) end
		end
	end
	-- 달력 / 추적 / 확장팩 / 애드온 묶음 버튼 숨김
	for _, n in ipairs({ "GameTimeFrame", "MiniMapTrackingButton", "MiniMapTracking", "ExpansionLandingPageMinimapButton", "AddonCompartmentFrame" }) do
		if _G[n] then Ink:KeepHidden(_G[n]) end
	end
	if Minimap.ZoomIn then Ink:KeepHidden(Minimap.ZoomIn) end
	if Minimap.ZoomOut then Ink:KeepHidden(Minimap.ZoomOut) end

	-- 마우스 휠 확대/축소, 우클릭으로 추적 메뉴
	Minimap:EnableMouseWheel(true)
	Minimap:HookScript("OnMouseWheel", function(self, d)
		local z, max = self:GetZoom(), self:GetZoomLevels()
		if d > 0 and z < max - 1 then self:SetZoom(z + 1)
		elseif d < 0 and z > 0 then self:SetZoom(z - 1) end
	end)
	Minimap:HookScript("OnMouseUp", function(_, btn)
		if btn ~= "RightButton" then return end
		local tr = mc and (mc.Tracking or mc.TrackingFrame)
		local b = tr and (tr.Button or tr)
		if b and b.OpenMenu then safe(b.OpenMenu, b) elseif b and b.Click then safe(b.Click, b) end
	end)
end

-------------------------------------------------------------------------------
-- 파티 찾기 대기열 눈 버튼: 원래는 메뉴 버튼 묶음 안에 있어서 (FOA가 숨김) 같이 사라진다.
--  미니맵 왼쪽 아래 모서리로 옮긴다. (엘브UI와 같은 방식)
-------------------------------------------------------------------------------
function M:AnchorQueue()
	local q = QueueStatusButton
	if not q or not self.mmAnchor then return end
	if q:IsProtected() and InCombatLockdown() then return end
	safe(function()
		if q:GetParent() ~= self.mmOverlay then q:SetParent(self.mmOverlay) end
		q:SetFrameStrata("MEDIUM")
		q:SetFrameLevel(self.mmOverlay:GetFrameLevel() + 10)
		q:SetScale(0.82)
		q:ClearAllPoints()
		-- 미니맵 왼쪽 바깥 (좌표 글자를 가리지 않게)
		q:SetPoint("CENTER", self.mmAnchor, "BOTTOMLEFT", -20, 18)
	end)
end

function M:SetupQueue()
	local q = QueueStatusButton
	if not q or self.queueHooked then return end
	self.queueHooked = true
	if q.UpdatePosition then
		hooksecurefunc(q, "UpdatePosition", function() M:AnchorQueue() end)
	end
	-- 대기열 정보 창은 버튼 왼쪽 아래로
	local qf = QueueStatusFrame
	if qf and qf.UpdatePosition then
		hooksecurefunc(qf, "UpdatePosition", function(self)
			safe(function()
				self:ClearAllPoints()
				self:SetPoint("TOPRIGHT", q, "BOTTOMLEFT", 0, 4)
			end)
		end)
	end
	self:AnchorQueue()
end

-------------------------------------------------------------------------------
-- 애드온 버튼 목록: 미니맵 오른쪽 위 버튼을 누르면 아래로 주르륵
--  · LibDBIcon 미니맵 버튼 (대부분의 애드온)
--  · 블리자드 애드온 묶음(AddonCompartment)에 등록된 애드온
--  · 그 밖에 미니맵에 붙은 이름 있는 버튼
--  원래 미니맵 버튼들은 숨기고 목록에서 대신 누른다.
-------------------------------------------------------------------------------
local ROW_H, LIST_W = 26, 210
local BLIZZ_BUTTON = { "^Minimap", "^MiniMap", "^GameTime", "^QueueStatus", "^Expansion", "^AddonCompartment",
	"^TimeManager", "^HybridMinimap", "^InkUI", "^FOA", "^GarrisonLandingPage" }

local function StripColor(s)
	if type(s) ~= "string" then return "" end
	return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function IconOf(btn)
	if btn.icon and btn.icon.GetTexture then return btn.icon:GetTexture(), btn.icon end
	local best, size
	for _, r in ipairs({ btn:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") and r:GetTexture() then
			local w = r:GetWidth() or 0
			local tex = r:GetTexture()
			-- 테두리(Border) / 배경 / 하이라이트는 건너뛴다
			local layer = r:GetDrawLayer()
			if layer ~= "HIGHLIGHT" and w < 40 and (not size or w > size) and not tostring(tex):lower():find("border") and not tostring(tex):lower():find("background") then
				best, size = r, w
			end
		end
	end
	if best then return best:GetTexture(), best end
end

-- 목록에 넣을 항목 모으기 (원래 미니맵 버튼은 여기서 숨긴다)
function M:CollectAddonButtons()
	local list, seen = {}, {}
	local function add(e)
		local key = StripColor(e.text):lower()
		if key == "" or seen[key] then return end
		seen[key] = true
		list[#list + 1] = e
	end

	-- 1) LibDBIcon
	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	if lib and lib.objects then
		for name, btn in pairs(lib.objects) do
			local obj = btn.dataObject
			if obj then
				Ink:Fade(btn)
				local tex = btn.icon and btn.icon:GetTexture() or obj.icon
				add({
					text = obj.label or name, icon = tex, iconRef = btn.icon,
					click = function(row, mb) if obj.OnClick then obj.OnClick(row, mb) end end,
					enter = function(row)
						if obj.OnEnter then obj.OnEnter(row)
						elseif obj.OnTooltipShow then
							GameTooltip:SetOwner(row, "ANCHOR_LEFT")
							obj.OnTooltipShow(GameTooltip)
							GameTooltip:Show()
						end
					end,
					leave = function(row) if obj.OnLeave then obj.OnLeave(row) else GameTooltip:Hide() end end,
				})
			end
		end
		if not self.dbiHooked and lib.RegisterCallback then
			self.dbiHooked = true
			lib.RegisterCallback(M, "LibDBIcon_IconCreated", function() C_Timer.After(0.1, function() M:CollectAddonButtons() end) end)
		end
	end

	-- 2) 블리자드 애드온 묶음
	local ac = AddonCompartmentFrame
	if ac and ac.registeredAddons then
		for _, d in ipairs(ac.registeredAddons) do
			add({
				text = d.text or "?", icon = d.icon,
				click = function(row, mb) if d.func then d.func(d, { buttonName = mb }, nil) end end,
				enter = function(row) if d.funcOnEnter then d.funcOnEnter(row) end end,
				leave = function(row) if d.funcOnLeave then d.funcOnLeave(row) end GameTooltip:Hide() end,
			})
		end
	end

	-- 3) 미니맵에 직접 붙은 다른 버튼들
	for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
		if parent then
			for _, c in ipairs({ parent:GetChildren() }) do
				local n = c:GetName()
				local blizz = not n
				if n then
					for _, pat in ipairs(BLIZZ_BUTTON) do if n:find(pat) then blizz = true break end end
					if n:find("^LibDBIcon") then blizz = true end
				end
				if not blizz and c.IsObjectType and c:IsObjectType("Button") and not c:IsProtected() and c:GetScript("OnClick") then
					local tex, ref = IconOf(c)
					Ink:Fade(c)
					local label = n:gsub("_?[Mm]inimap[Bb]utton", ""):gsub("_?Mini[Mm]ap", ""):gsub("[_%-]", " ")
					add({
						text = label, icon = tex, iconRef = ref,
						click = function(_, mb) c:Click(mb) end,
						enter = function(row) local f = c:GetScript("OnEnter"); if f then f(c) end end,
						leave = function() local f = c:GetScript("OnLeave"); if f then f(c) end GameTooltip:Hide() end,
					})
				end
			end
		end
	end

	table.sort(list, function(a, b) return StripColor(a.text):lower() < StripColor(b.text):lower() end)
	-- 맨 위는 FOA 설정
	table.insert(list, 1, {
		text = "FOA UI 설정", icon = Ink.tex.logo, foa = true,
		click = function()
			local cfg = Ink.modules.Config
			if cfg and cfg.OpenPanel and not InCombatLockdown() then cfg:OpenPanel() end
		end,
	})
	self.addonList = list
	return list
end

local function NewRow(parent)
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(LIST_W - 12, ROW_H)
	r:RegisterForClicks("AnyUp")
	r.hl = r:CreateTexture(nil, "BACKGROUND")
	r.hl:SetAllPoints()
	r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.1)
	r.hl:Hide()
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(18, 18)
	r.icon:SetPoint("LEFT", 8, 0)
	r.name = Ink:Text(r, F.semi, 12, C.text, "LEFT")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 9, 0)
	r.name:SetPoint("RIGHT", -8, 0)
	r.name:SetWordWrap(false)
	-- 주르륵: 위에서 살짝 내려오며 나타난다
	local ag = r:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0)
	a:SetToAlpha(1)
	a:SetDuration(0.16)
	local t = ag:CreateAnimation("Translation")
	t:SetOffset(0, 0)
	t:SetDuration(0.16)
	t:SetSmoothing("OUT")
	r.anim, r.animA, r.animT = ag, a, t
	r:SetScript("OnEnter", function(self)
		self.hl:Show()
		if self.entry and self.entry.enter then pcall(self.entry.enter, self) end
	end)
	r:SetScript("OnLeave", function(self)
		self.hl:Hide()
		if self.entry and self.entry.leave then pcall(self.entry.leave, self) else GameTooltip:Hide() end
	end)
	r:SetScript("OnClick", function(self, mb)
		local e = self.entry
		-- 애드온이 띄우는 메뉴가 목록과 같이 닫히지 않게, 목록 밖의 대리 프레임을 넘긴다
		local proxy = M.clickProxy
		if not proxy then
			proxy = CreateFrame("Frame", "FOAAddonListAnchor", Ink.root)
			M.clickProxy = proxy
		end
		proxy:ClearAllPoints()
		proxy:SetPoint("TOPLEFT", self, "TOPLEFT")
		proxy:SetSize(self:GetWidth(), self:GetHeight())
		local l, t = self:GetLeft(), self:GetTop()
		if l and t then
			proxy:ClearAllPoints()
			local k = self:GetEffectiveScale() / proxy:GetEffectiveScale()
			proxy:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * k, t * k)
		end
		if self.entry and self.entry.leave then pcall(self.entry.leave, self) end
		M:ToggleAddonList(false)
		if e and e.click then
			local ok, err = pcall(e.click, proxy, mb)
			if not ok then Ink:LogError("애드온 목록: " .. tostring(err)) end
		end
	end)
	return r
end

function M:BuildAddonList()
	local o = self.mmOverlay
	-- 목록 버튼 (미니맵 오른쪽 위)
	local b = CreateFrame("Button", "FOAAddonListButton", o)
	b:SetSize(20, 20)
	b:SetPoint("TOPRIGHT", -5, -3)
	b:SetFrameLevel(o:GetFrameLevel() + 5)
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(1, 1, 1, 0.06)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(Ink.icon("Menu"))
	b.icon:SetSize(13, 13)
	b.icon:SetPoint("CENTER")
	b.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3])
	b:SetScript("OnEnter", function(self)
		self.icon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("애드온 목록")
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		if not (M.listFrame and M.listFrame:IsShown()) then self.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3]) end
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function() M:ToggleAddonList() end)
	self.listButton = b

	-- 목록 창
	local f = CreateFrame("Frame", "FOAAddonList", Ink.root)
	f:SetFrameStrata("DIALOG")
	f:SetWidth(LIST_W)
	f:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 5, -6)
	f:EnableMouse(true)
	f.bg = Ink:Round(f, "BACKGROUND", false, false, -7)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.96)
	f.bd = Ink:Round(f, "BORDER", false, true)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.08)
	f.accent = f:CreateTexture(nil, "ARTWORK")
	f.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	f.accent:SetSize(18, 2)
	f.accent:SetPoint("TOPLEFT", 12, -1)
	f.title = Ink:Text(f, F.semi, 11, C.muted, "LEFT")
	f.title:SetPoint("TOPLEFT", 12, -10)
	f.title:SetText("애드온")
	f.empty = Ink:Text(f, F.sans, 11, C.dim, "LEFT")
	f.empty:SetPoint("TOPLEFT", 12, -60)
	f.empty:SetText("미니맵 버튼을 쓰는 애드온이 없어요")
	f.rows = {}
	f:Hide()
	-- ESC로 닫힘 (블리자드 창 닫기 목록에 등록) / 밖을 누르면 닫힘
	tinsert(UISpecialFrames, "FOAAddonList")
	f:SetScript("OnHide", function()
		if M.listButton then M.listButton.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3]) end
	end)
	f:SetScript("OnUpdate", function(self)
		if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
			and not self:IsMouseOver() and not M.listButton:IsMouseOver() then
			M:ToggleAddonList(false)
		end
	end)
	self.listFrame = f
end

function M:ToggleAddonList(show)
	local f = self.listFrame
	if not f then return end
	if show == nil then show = not f:IsShown() end
	if not show then
		f:Hide()
		self.listButton.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3])
		return
	end
	local list = self:CollectAddonButtons()
	for i, e in ipairs(list) do
		local r = f.rows[i] or NewRow(f)
		f.rows[i] = r
		r.entry = e
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 6, -28 - (i - 1) * ROW_H - (i > 1 and 6 or 0))
		local icon = e.icon
		if type(icon) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(icon) then
			r.icon:SetAtlas(icon)
		else
			r.icon:SetTexture(icon or Ink.icon("Menu"))
		end
		-- 아이콘 원본이 잘라 쓰는 좌표가 있으면 그대로
		if e.iconRef and e.iconRef.GetTexCoord then
			r.icon:SetTexCoord(e.iconRef:GetTexCoord())
		else
			r.icon:SetTexCoord(0, 1, 0, 1)
		end
		r.name:SetText(e.text)
		r.name:SetTextColor(e.foa and C.accent[1] or C.text[1], e.foa and C.accent[2] or C.text[2], e.foa and C.accent[3] or C.text[3])
		r:Show()
		-- 위에서부터 차례로 내려온다
		r.anim:Stop()
		r.animA:SetStartDelay((i - 1) * 0.025)
		r.animT:SetStartDelay((i - 1) * 0.025)
		r.animT:SetOffset(0, 0)
		r:SetAlpha(1)
		r.anim:Play()
	end
	for i = #list + 1, #f.rows do f.rows[i]:Hide() end
	-- 첫 줄(FOA) 아래 구분선
	if not f.sep then
		f.sep = f:CreateTexture(nil, "ARTWORK")
		f.sep:SetColorTexture(1, 1, 1, 0.06)
		f.sep:SetHeight(1)
	end
	f.sep:ClearAllPoints()
	f.sep:SetPoint("TOPLEFT", 12, -28 - ROW_H - 3)
	f.sep:SetPoint("TOPRIGHT", -12, -28 - ROW_H - 3)
	f.empty:SetShown(#list <= 1)
	local h = 28 + #list * ROW_H + (#list > 1 and 6 or 0) + 8
	if #list <= 1 then h = h + 24 end
	f:SetHeight(h)
	f:Show()
	self.listButton.icon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
end

-- 미니맵 밑에 따로 붙는 좌표 글자(다른 기능이 만든 것)를 찾아 숨긴다
function M:HideExtraCoords()
	local mc = MinimapCluster
	if not mc then return end
	local pattern = "^%s*%-?%d+%.%d+%s*,%s*%-?%d+%.%d+%s*$"
	local function scan(f, depth)
		if not f or depth > 3 or f == self.mmOverlay or f == Minimap then return end
		for _, r in ipairs({ f:GetRegions() }) do
			if r.IsObjectType and r:IsObjectType("FontString") then
				local txt = plain(r:GetText())
				if txt and txt:match(pattern) then r:SetAlpha(0) end
			end
		end
		for _, c in ipairs({ f:GetChildren() }) do scan(c, depth + 1) end
	end
	scan(mc, 0)
end

function M:UpdateMinimapText()
	local o = self.mmOverlay
	o.zone:SetText(GetMinimapZoneText() or "")
	local x, y
	safe(function()
		local map = C_Map.GetBestMapForUnit("player")
		local pos = map and C_Map.GetPlayerMapPosition(map, "player")
		if pos then x, y = pos:GetXY() end
	end)
	if x and y then o.coords:SetFormattedText("%.1f, %.1f", x * 100, y * 100) else o.coords:SetText("") end
end

function M:LayoutMinimap()
	Ink:Fit(Minimap, self.mmAnchor, "TOPRIGHT", 200, 200)
	safe(Minimap.SetMaskTexture, Minimap, 130937)
	if Minimap.SetArchBlobRingScalar then safe(Minimap.SetArchBlobRingScalar, Minimap, 0) end
	if Minimap.SetQuestBlobRingScalar then safe(Minimap.SetQuestBlobRingScalar, Minimap, 0) end
	local mc = MinimapCluster
	if mc then
		-- 우편/제작 주문 표시는 미니맵 안 오른쪽 위, 난이도는 왼쪽 아래로
		local ind = mc.IndicatorFrame
		if ind then
			safe(function()
				ind:ClearAllPoints()
				ind:SetPoint("TOPRIGHT", self.mmAnchor, "TOPRIGHT", -24, -30)
			end)
		end
		local diff = mc.InstanceDifficulty
		if diff then
			safe(function()
				diff:ClearAllPoints()
				diff:SetPoint("BOTTOMLEFT", self.mmAnchor, "BOTTOMLEFT", 4, 26)
			end)
		end
	end
	self:UpdateMinimapText()
	C_Timer.After(1, function() M:HideExtraCoords() end)
end

-------------------------------------------------------------------------------
-- 버프 / 가방 / 메뉴
-------------------------------------------------------------------------------
local function SkinBagButton(b)
	if not b or b.inkSkinned then return end
	b.inkSkinned = true
	local icon = b.icon or b.Icon or (b.GetName and _G[b:GetName() .. "IconTexture"])
	if b.GetNormalTexture and b:GetNormalTexture() then b:GetNormalTexture():SetAlpha(0) end
	for _, k in ipairs({ "CircleMask", "IconMask", "SlotHighlightTexture" }) do
		local r = b[k]
		if r then
			if icon and icon.RemoveMaskTexture and r.IsObjectType and r:IsObjectType("MaskTexture") then
				safe(icon.RemoveMaskTexture, icon, r)
			end
			if r.SetAlpha then r:SetAlpha(0) end
		end
	end
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		Ink:IconSkin(b, icon, true)
	end
	if b.SetHighlightTexture then
		safe(b.SetHighlightTexture, b, Ink.tex.round4)
		local h = b:GetHighlightTexture()
		if h then h:SetVertexColor(1, 1, 1, 0.12); h:SetAllPoints() end
	end
	if b.SetPushedTexture then safe(b.SetPushedTexture, b, "") end
	local count = b.Count or (b.GetName and _G[b:GetName() .. "Count"])
	if count then count:SetFont(F.latinB, 9, "OUTLINE") end
end

function M:PlaceDurability()
	local d = DurabilityFrame
	if not (d and self.duraAnchor) or d.inkPlacing then return end
	if d:IsProtected() and InCombatLockdown() then return end
	d.inkPlacing = true
	safe(function()
		d:ClearAllPoints()
		d:SetPoint("TOPRIGHT", self.duraAnchor, "TOPRIGHT", 0, 0)
	end)
	d.inkPlacing = nil
end

function M:HookDurability()
	local d = DurabilityFrame
	if not d or self.duraHooked then return end
	self.duraHooked = true
	-- 블리자드가 오른쪽 정렬 묶음 안에서 다시 자리를 잡을 때마다 FOA 위치로 되돌린다
	hooksecurefunc(d, "SetPoint", function() M:PlaceDurability() end)
	if d.HookScript then d:HookScript("OnShow", function() M:PlaceDurability() end) end
	self:PlaceDurability()
end

function M:BuildAnchors()
	self.buffAnchor = Ink:Anchor(300, 40)
	self.questAnchor = Ink:Anchor(240, 400)
	self.chatAnchor = Ink:Anchor(340, 140)
	self.bagAnchor = Ink:Anchor(180, 24)

	Ink:Movable("minimap", "미니맵", self.mmAnchor, "right", 16, 16)
	Ink:Movable("buffs", "버프", self.buffAnchor, "right", 236, 20)
	Ink:Movable("quest", "퀘스트 목록", self.questAnchor, "right", 60, 240)
	Ink:Movable("chat", "채팅", self.chatAnchor, "bottomleft", 16, 48)
	-- 장비 내구도 경고(노란 갑옷 인형): 퀘스트 목록을 가리지 않게 미니맵 왼쪽 아래 빈 곳으로
	self.duraAnchor = Ink:Anchor(60, 75)
	Ink:Movable("durability", "내구도", self.duraAnchor, "right", 236, 140)
	self:HookDurability()
	-- 가방 칸 줄은 진영 문양 메뉴(Launcher.lua)로 대신한다
	if Ink.db.launcher == false then
		Ink:Movable("bags", "가방", self.bagAnchor, "left", 12, 12)
	end

	-- 메뉴 버튼(캐릭터/마법책/특성...)은 기본 숨김
	if MicroMenuContainer then Ink:KeepHidden(MicroMenuContainer) end
	if MicroMenu then Ink:KeepHidden(MicroMenu) end
	if BagBarExpandToggle then Ink:KeepHidden(BagBarExpandToggle) end
end

function M:LayoutAnchors()
	Ink:Fit(BuffFrame, self.buffAnchor, "TOPRIGHT")
	Ink:Fit(ObjectiveTrackerFrame, self.questAnchor, "TOPRIGHT")
	if ChatFrame1 then
		safe(function()
			if ChatFrame1.SetUserPlaced then ChatFrame1:SetUserPlaced(true) end
		end)
		Ink:Fit(ChatFrame1, self.chatAnchor, "BOTTOMLEFT", 340, 140)
	end
	if BagsBar and Ink.db.launcher ~= false then
		Ink:Fade(BagsBar)
	elseif BagsBar then
		local bags = { MainMenuBarBackpackButton, CharacterBag0Slot, CharacterBag1Slot, CharacterBag2Slot, CharacterBag3Slot, CharacterReagentBag0Slot }
		for _, b in ipairs(bags) do SkinBagButton(b) end
		safe(function()
			local btn = MainMenuBarBackpackButton
			if btn and btn:GetHeight() > 0 then
				local want = 24 * Ink.root:GetEffectiveScale()
				local have = btn:GetHeight() * btn:GetEffectiveScale()
				if math.abs(want - have) > 0.5 then BagsBar:SetScale(BagsBar:GetScale() * want / have) end
			end
		end)
		Ink:Fit(BagsBar, self.bagAnchor, "TOPLEFT")
	end
end

-------------------------------------------------------------------------------
-- 미니맵 옆 버프 / 디버프 스킨: 둥근 칸 + 아래 작은 회색 시간
-------------------------------------------------------------------------------
local function SkinAura(b)
	if not b then return end
	local icon = b.Icon or b.icon
	if not (icon and icon.IsObjectType and icon:IsObjectType("Texture")) then return end
	if b.inkSkinned then
		-- 빈 칸(아이콘 없음)에는 테두리를 그리지 않는다
		b.inkSkin.top:SetShown(icon:GetTexture() ~= nil)
		b.inkSkin.bg:SetShown(icon:GetTexture() ~= nil)
		return
	end
	b.inkSkinned = true
	local s = Ink:IconSkin(b, icon, true)
	s.bg:SetVertexColor(0, 0, 0, 0.5)
	s.border:SetVertexColor(1, 1, 1, 0.16)
	-- 버튼 크기와 아이콘 크기가 다를 수 있어 아이콘 기준으로 맞춘다
	s.bg:ClearAllPoints()
	s.bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	s.bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	s.border:ClearAllPoints()
	s.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	s.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	-- 디버프 / 무기 강화 테두리 색은 둥근 테두리로 옮긴다
	for _, k in ipairs({ "DebuffBorder", "TempEnchantBorder", "Border" }) do
		local bd = b[k]
		if bd and bd.SetAlpha then
			bd:SetAlpha(0)
			if bd.GetVertexColor then
				local function copy()
					local r, g, bl = bd:GetVertexColor()
					if r then s.border:SetVertexColor(r, g, bl, 1) end
				end
				if bd:IsShown() then copy() end
				hooksecurefunc(bd, "SetVertexColor", copy)
				hooksecurefunc(bd, "Show", copy)
				hooksecurefunc(bd, "Hide", function() s.border:SetVertexColor(1, 1, 1, 0.16) end)
			end
		end
	end
	if b.Symbol then b.Symbol:SetAlpha(0) end
	local d = b.Duration or b.duration
	if d then
		d:SetFont(F.sans, 10, "")
		d:SetShadowOffset(1, -1)
		d:ClearAllPoints()
		d:SetPoint("TOP", icon, "BOTTOM", 0, -3)
		local function mute()
			if d.inkColoring then return end
			d.inkColoring = true
			d:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
			d:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
			d.inkColoring = nil
		end
		mute()
		hooksecurefunc(d, "SetTextColor", mute)
		hooksecurefunc(d, "SetVertexColor", mute)
	end
	local c = b.Count or b.count
	if c then
		c:SetFont(F.latinB, 10, "OUTLINE")
		c:SetParent(s.top)
		c:SetDrawLayer("OVERLAY", 7)
		c:ClearAllPoints()
		c:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
	end
	s.top:SetShown(icon:GetTexture() ~= nil)
	s.bg:SetShown(icon:GetTexture() ~= nil)
end

function M:SkinBuffs()
	for _, holder in ipairs({ BuffFrame, DebuffFrame }) do
		if holder then
			for _, b in ipairs(holder.auraFrames or {}) do SkinAura(b) end
			if not holder.inkHooked then
				holder.inkHooked = true
				for _, fn in ipairs({ "UpdateAuraButtons", "Update", "RefreshAuras" }) do
					if type(holder[fn]) == "function" then
						hooksecurefunc(holder, fn, function() M:SkinBuffs() end)
					end
				end
			end
		end
	end
	if BuffFrame and BuffFrame.CollapseAndExpandButton then BuffFrame.CollapseAndExpandButton:SetAlpha(0.35) end
end

-------------------------------------------------------------------------------
-- 퀘스트 목록 스킨: 헤더 장식 제거, 얇은 구분선 + Ink 글꼴
-------------------------------------------------------------------------------
local TRACKERS = {
	"ObjectiveTrackerFrame", "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
	"QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker", "MonthlyActivitiesObjectiveTracker",
	"ProfessionsRecipeTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker", "InitiativeTasksObjectiveTracker",
}

local function SkinTrackerHeader(h)
	if not h or h.inkSkinned then return end
	h.inkSkinned = true
	if h.Background then h.Background:SetAlpha(0) end
	for _, r in ipairs({ h:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
	end
	if h.Text then
		h.Text:SetFont(F.semi, 11, "")
		h.Text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		h.Text:SetShadowOffset(1, -1)
	end
	local line = h:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, 0.10)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 2)
	line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 2)
	if h.MinimizeButton then h.MinimizeButton:SetAlpha(0.5) end
end

function M:SkinQuest()
	for _, n in ipairs({ "ObjectiveTrackerHeaderFont", "ObjectiveTrackerLineFont", "ObjectiveFont", "ObjectiveTrackerFont" }) do
		local fo = _G[n]
		if fo and fo.GetFont then
			local _, size = fo:GetFont()
			local file = (n == "ObjectiveTrackerHeaderFont") and F.semi or F.sans
			safe(fo.SetFont, fo, file, (size and size > 0) and size or 12, "")
			safe(fo.SetShadowOffset, fo, 1, -1)
			safe(fo.SetShadowColor, fo, 0, 0, 0, 0.8)
		end
	end
	for _, n in ipairs(TRACKERS) do
		local t = _G[n]
		if t then
			SkinTrackerHeader(t.Header)
			if t.NineSlice then t.NineSlice:SetAlpha(0) end
			if not t.inkHooked and t.Update then
				t.inkHooked = true
				hooksecurefunc(t, "Update", function(self) SkinTrackerHeader(self.Header) end)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- 채팅 스킨: 배경/탭/버튼 정리, 입력창은 아래에 딱 붙인다
-------------------------------------------------------------------------------
local function SkinTab(tab)
	if not tab or tab.inkSkinned then return end
	tab.inkSkinned = true
	hideTextures(tab)
	for _, k in ipairs({ "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight", "glow", "conversationIcon" }) do
		if tab[k] then tab[k]:SetAlpha(0) end
	end
	local text = tab.Text or (tab.GetFontString and tab:GetFontString())
	if text then
		text:SetFont(F.semi, 12, "")
		text:SetShadowOffset(1, -1)
	end
	tab.inkLine = tab:CreateTexture(nil, "OVERLAY")
	tab.inkLine:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	tab.inkLine:SetHeight(1)
	if text then
		tab.inkLine:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -3)
		tab.inkLine:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 0, -3)
	end
	tab.inkLine:Hide()
end

local function TabColors(tab, selected)
	if not tab or not tab.inkLine then return end
	tab.inkLine:SetShown(selected and true or false)
	local text = tab.Text or (tab.GetFontString and tab:GetFontString())
	if text then
		local col = selected and C.text or C.muted
		text:SetTextColor(col[1], col[2], col[3])
	end
	for _, k in ipairs({ "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight" }) do
		if tab[k] then tab[k]:SetAlpha(0) end
	end
end

local function SkinEditBox(eb, cf)
	if not eb or eb.inkSkinned then return end
	eb.inkSkinned = true
	hideTextures(eb)
	for _, k in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
		if eb[k] then eb[k]:SetAlpha(0) end
		local g = eb.GetName and _G[eb:GetName() .. k]
		if g then g:SetAlpha(0) end
	end
	eb.inkBg = Ink:Round(eb, "BACKGROUND", true, false)
	eb.inkBg:SetAllPoints()
	eb.inkBg:SetVertexColor(0, 0, 0, 0.45)
	eb.inkBd = Ink:Round(eb, "BORDER", true, true)
	eb.inkBd:SetAllPoints()
	eb.inkBd:SetVertexColor(1, 1, 1, 0.14)
	eb:SetFont(F.sans, 13, "")
	if eb.header then eb.header:SetFont(F.semi, 13, "") end
	if eb.headerSuffix then eb.headerSuffix:SetFont(F.semi, 13, "") end
	safe(function()
		eb:ClearAllPoints()
		eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -4, -6)
		eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 4, -6)
		eb:SetHeight(28)
	end)
	-- 입력창이 닫혀 있을 때도 자리를 보여주는 안내 칸
	if cf == ChatFrame1 then
		local ph = CreateFrame("Frame", nil, cf)
		ph:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -4, -6)
		ph:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 4, -6)
		ph:SetHeight(28)
		ph.bd = Ink:Round(ph, "BORDER", true, true)
		ph.bd:SetAllPoints()
		ph.bd:SetVertexColor(1, 1, 1, 0.10)
		ph.text = Ink:Text(ph, F.sans, 12, C.dim, "LEFT")
		ph.text:SetPoint("LEFT", 10, 0)
		ph.text:SetText("Enter로 채팅 입력")
		ph:SetShown(not eb:IsShown())
		eb:HookScript("OnShow", function() ph:Hide() end)
		eb:HookScript("OnHide", function() ph:Show() end)
	end
end

local function SkinChatFrame(cf)
	if not cf or cf.inkSkinned then return end
	cf.inkSkinned = true
	local name = cf:GetName()
	-- 블리자드 기본 배경은 마우스를 올리면 다시 밝아지므로 투명도를 고정한다
	for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
		local t = _G[name .. suffix]
		if t then Ink:Fade(t) end
	end
	if cf.Background then Ink:Fade(cf.Background) end
	for _, k in ipairs({ "NineSlice", "BackgroundFrame" }) do
		if cf[k] then Ink:Fade(cf[k]) end
	end
	if cf.ScrollBar then Ink:Fade(cf.ScrollBar) end
	local rb = cf.ResizeButton or _G[name .. "ResizeButton"]
	if rb then Ink:Fade(rb) end
	if cf.ScrollToBottomButton then Ink:Fade(cf.ScrollToBottomButton) end
	local bf = cf.buttonFrame or _G[name .. "ButtonFrame"]
	if bf then Ink:KeepHidden(bf) end
	cf.inkBg = Ink:Round(cf, "BACKGROUND", false, false, -7)
	cf.inkBg:SetPoint("TOPLEFT", -10, 30)
	cf.inkBg:SetPoint("BOTTOMRIGHT", 10, -40)
	cf.inkBg:SetVertexColor(0, 0, 0, 0.28)
	local _, size = cf:GetFont()
	cf:SetFont(F.sans, (size and size > 0) and size or 13, "")
	cf:SetShadowOffset(1, -1)
	cf:SetShadowColor(0, 0, 0, 0.8)
	SkinTab(_G[name .. "Tab"])
	SkinEditBox(cf.editBox or _G[name .. "EditBox"], cf)
end

function M:SkinChat()
	for _, n in ipairs({ "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "TextToSpeechButton", "ChatAlertFrame" }) do
		if _G[n] and n ~= "ChatAlertFrame" then Ink:KeepHidden(_G[n]) end
	end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do SkinChatFrame(_G["ChatFrame" .. i]) end
	if not self.chatHooked then
		self.chatHooked = true
		if FCF_OpenTemporaryWindow then
			hooksecurefunc("FCF_OpenTemporaryWindow", function()
				for _, n in ipairs(CHAT_FRAMES or {}) do SkinChatFrame(_G[n]) end
			end)
		end
		if FCFTab_UpdateColors then
			hooksecurefunc("FCFTab_UpdateColors", TabColors)
		end
		if FCF_SetChatWindowFontSize then
			hooksecurefunc("FCF_SetChatWindowFontSize", function(_, cf, size)
				cf = cf or (FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame())
				if cf and size then cf:SetFont(F.sans, size, "") end
			end)
		end
	end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local tab = _G["ChatFrame" .. i .. "Tab"]
		if tab then TabColors(tab, SELECTED_CHAT_FRAME == _G["ChatFrame" .. i] or (i == 1 and not SELECTED_CHAT_FRAME)) end
	end
end

-------------------------------------------------------------------------------
-- 행동단축바 버튼 스킨 (위치는 편집 모드 그대로, 모양만 Ink 스타일)
-------------------------------------------------------------------------------
local skinnedButtons = {}

-- 단축키 표기를 짧은 영문으로 (한글이 남으면 한글 글꼴로)
local KEY_REPL = {
	{ "마우스 휠 위로", "WU" }, { "마우스 휠 아래로", "WD" }, { "가운데 마우스 버튼", "M3" },
	{ "마우스 버튼 (%d+)", "M%1" }, { "마우스 (%d+)", "M%1" }, { "숫자패드 ", "N" }, { "숫자 패드 ", "N" },
	{ "SHIFT%-", "s" }, { "CTRL%-", "c" }, { "ALT%-", "a" }, { "s%-", "s" }, { "c%-", "c" }, { "a%-", "a" },
	{ "Mouse Wheel Up", "WU" }, { "Mouse Wheel Down", "WD" }, { "Middle Mouse", "M3" }, { "Mouse Button (%d+)", "M%1" },
	{ "Num Pad ", "N" }, { "Spacebar", "Spc" }, { "스페이스 바", "Spc" }, { "스페이스", "Spc" },
}

-- 단축키 글자 모양: 평소엔 오른쪽 위 작게(밝은 회색), 빠른 단축키 설정 중엔 가운데 크게(노랑)
local function StyleHotkey(hk, txt)
	local b = hk.inkButton
	local kb = Ink.kbMode
	local hangul = txt and txt:find("[\128-\255]")
	hk:ClearAllPoints()
	if kb then
		hk:SetPoint("CENTER", b or hk:GetParent(), "CENTER", 0, 0)
		hk:SetJustifyH("CENTER")
		if hangul then hk:SetFont(F.bold, 12, "OUTLINE") else hk:SetFont(F.latinB, 15, "OUTLINE") end
		hk:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	else
		hk:SetPoint("TOPRIGHT", b or hk:GetParent(), "TOPRIGHT", -4, -4)
		hk:SetJustifyH("RIGHT")
		if hangul then hk:SetFont(F.semi, 10, "") else hk:SetFont(F.latinB, 11, "") end
		hk:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
	end
end

local function FixHotkey(hk)
	if not hk or hk.inkFixing then return end
	local txt = plain(hk:GetText())
	if not txt then return end
	hk.inkFixing = true
	local out = txt
	if txt == RANGE_INDICATOR or txt == "●" then
		out = ""
		hk:SetText("")
	else
		for _, r in ipairs(KEY_REPL) do out = out:gsub(r[1], r[2]) end
		if out ~= txt then hk:SetText(out) end
	end
	StyleHotkey(hk, out)
	hk.inkFixing = nil
end

local function SkinActionButton(b, small)
	if not b or skinnedButtons[b] then return end
	skinnedButtons[b] = true
	local icon = b.icon or b.Icon or (b.GetName and _G[b:GetName() .. "Icon"])
	local nt = b.GetNormalTexture and b:GetNormalTexture()
	if nt then nt:SetAlpha(0) end
	if b.SetNormalAtlas then hooksecurefunc(b, "SetNormalAtlas", function(self) local t = self:GetNormalTexture(); if t then t:SetAlpha(0) end end) end
	if b.SetNormalTexture then hooksecurefunc(b, "SetNormalTexture", function(self) local t = self:GetNormalTexture(); if t then t:SetAlpha(0) end end) end
	if icon and b.IconMask and icon.RemoveMaskTexture then safe(icon.RemoveMaskTexture, icon, b.IconMask) end
	for _, k in ipairs({ "SlotArt", "SlotBackground", "IconMask", "Border", "FloatingBG", "NewActionTexture" }) do
		local r = b[k]
		if r and r.SetAlpha then r:SetAlpha(0) end
	end
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
	end
	local s = Ink:IconSkin(b, icon, small)
	s.bg:SetVertexColor(1, 1, 1, 0.035)
	s.border:SetVertexColor(1, 1, 1, 0.10)
	-- 눌림 / 강조 / 체크 텍스처도 둥근 모양으로
	safe(function()
		local file = small and Ink.tex.round4 or Ink.tex.round
		if b.SetPushedTexture then
			b:SetPushedTexture(file)
			local p = b:GetPushedTexture()
			p:SetVertexColor(0, 0, 0, 0.35); p:ClearAllPoints(); p:SetAllPoints(b)
		end
		if b.SetHighlightTexture then
			b:SetHighlightTexture(file, "ADD")
			local h = b:GetHighlightTexture()
			h:SetVertexColor(1, 1, 1, 0.10); h:ClearAllPoints(); h:SetAllPoints(b)
		end
		if b.SetCheckedTexture then
			b:SetCheckedTexture(small and Ink.tex.roundBorder4 or Ink.tex.roundBorder)
			local ck = b:GetCheckedTexture()
			ck:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.9); ck:ClearAllPoints(); ck:SetAllPoints(b)
		end
	end)
	local cd = b.cooldown or b.Cooldown
	Ink:SkinCooldown(cd, small)
	local hk = b.HotKey or (b.TextOverlayContainer and b.TextOverlayContainer.HotKey) or (b.GetName and _G[b:GetName() .. "HotKey"])
	if b.QuickKeybindHighlightTexture then
		-- 네모난 기본 강조 대신 FOA 둥근 테두리로 (SetKeybindMode)
		b.QuickKeybindHighlightTexture:SetAlpha(0)
	end
	if hk then
		hk.inkButton = b
		b.inkHK = hk
		hk:ClearAllPoints()
		hk:SetPoint("TOPRIGHT", -4, -4)
		hk:SetJustifyH("RIGHT")
		hk:SetShadowOffset(1, -1)
		hk:SetShadowColor(0, 0, 0, 0.9)
		FixHotkey(hk)
		hooksecurefunc(hk, "SetText", FixHotkey)
	end
	local name = b.Name or (b.GetName and _G[b:GetName() .. "Name"])
	if name then name:SetAlpha(0) end
	local count = b.Count or (b.TextOverlayContainer and b.TextOverlayContainer.Count) or (b.GetName and _G[b:GetName() .. "Count"])
	if count then count:SetFont(F.latinB, 11, "OUTLINE") end
end

-- 블리자드 "빠른 단축키 설정" 모드와 맞추기
--  설정 중에는 모든 버튼의 단축키를 가운데 크게 노랗게, 테두리도 노랗게 → 어떤 키가 어디에 있는지 한눈에
function M:SetKeybindMode(on)
	Ink.kbMode = on and true or nil
	for b in pairs(skinnedButtons) do
		local s = b.inkSkin
		if s and s.border then
			if on then
				s.border:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.55)
			else
				s.border:SetVertexColor(1, 1, 1, 0.10)
			end
		end
		if b.inkHK then
			FixHotkey(b.inkHK)
			if on then b.inkHK:SetAlpha(1) end
		end
	end
end

function M:HookKeybindMode()
	if self.kbHooked or not EventRegistry then return end
	self.kbHooked = true
	EventRegistry:RegisterCallback("QuickKeybindFrame.QuickKeybindModeEnabled", function() M:SetKeybindMode(true) end, M)
	EventRegistry:RegisterCallback("QuickKeybindFrame.QuickKeybindModeDisabled", function() M:SetKeybindMode(false) end, M)
end

-- 빠른 단축키 설정 열기 (FOA 설정창 버튼 / /foa kb)
function Ink:OpenQuickKeybind()
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투 중에는 단축키를 바꿀 수 없어요.")
		return
	end
	if not QuickKeybindFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_QuickKeybind") end
	if not QuickKeybindFrame then return end
	if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
	QuickKeybindFrame:Show()
end

-------------------------------------------------------------------------------
-- 새로 배운 주문 자동 배치
--  FOA가 직접 주문을 집어서 놓으면(PickupSpell / PlaceAction) 블리자드 행동단축바 코드가
--  오염돼 전투 중 "MultiBar...:HideBase() 막힘"이 생긴다. 그래서 블리자드(서버)의
--  자동 배치 설정만 켜 두고, FOA는 들어간 자리를 알려 주기만 한다.
-------------------------------------------------------------------------------
local function FlashSlot(slot)
	local b = _G["ActionButton" .. slot]
	local s = b and b.inkSkin
	if not (s and s.border) then return end
	s.border:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
	C_Timer.After(1.4, function()
		if not Ink.kbMode then s.border:SetVertexColor(1, 1, 1, 0.10) end
	end)
end

function M:ApplyAutoPush()
	if InCombatLockdown() then return end
	local want = Ink.db.autoPush == false and "0" or "1"
	if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("AutoPushSpellToActionBar") ~= nil
		and C_CVar.GetCVar("AutoPushSpellToActionBar") ~= want then
		pcall(C_CVar.SetCVar, "AutoPushSpellToActionBar", want)
	end
end

function M:SetupAutoPush()
	self:ApplyAutoPush()
	local e = CreateFrame("Frame")
	pcall(e.RegisterEvent, e, "SPELL_PUSHED_TO_ACTIONBAR")
	pcall(e.RegisterEvent, e, "PLAYER_ENTERING_WORLD")
	e:SetScript("OnEvent", function(_, event, spellID, slot, page)
		if event == "PLAYER_ENTERING_WORLD" then M:ApplyAutoPush() return end
		if Ink.db.autoPush == false then return end
		local link = spellID and C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID)
		if slot then
			print("|cffFFF468FOA|r 새 주문 " .. (link or "") .. " → " .. (page and page > 1 and (page .. "번 바 ") or "기본 바 ") .. slot .. "번")
			if not page or page == 1 then C_Timer.After(0.6, function() FlashSlot(slot) end) end
		end
	end)
end

-------------------------------------------------------------------------------
-- 주문 강조(발동 효과 반짝임)가 FOA 테두리 아래에 묻히지 않게 위로 올린다
-------------------------------------------------------------------------------
function M:HookSpellAlerts()
	local mgr = ActionButtonSpellAlertManager
	if not mgr or self.alertHooked then return end
	self.alertHooked = true
	local function raise(_, button)
		local a = button and button.SpellActivationAlert
		if a and a.SetFrameLevel and not (a.IsProtected and a:IsProtected() and InCombatLockdown()) then
			local top = button.inkSkin and button.inkSkin.top
			local lvl = (top and top:GetFrameLevel() or button:GetFrameLevel()) + 2
			if a:GetFrameLevel() < lvl then a:SetFrameLevel(lvl) end
		end
	end
	if mgr.ShowAlert then hooksecurefunc(mgr, "ShowAlert", raise) end
end

-------------------------------------------------------------------------------
-- 탈것 좌석 표시(오른쪽에 뜨는 회색 탈것 그림) 숨김
-------------------------------------------------------------------------------
function M:HideVehicleSeats()
	if VehicleSeatIndicator then Ink:KeepHidden(VehicleSeatIndicator) end
end

-------------------------------------------------------------------------------
-- 튜토리얼 끄기 (노란 안내 상자 / 화살표 / 도움말 말풍선)
-------------------------------------------------------------------------------
function M:DisableTutorials()
	if Ink.db.hideTutorials == false then return end
	for _, cv in ipairs({ "showTutorials", "showNPETutorials" }) do
		if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(cv) ~= nil and C_CVar.GetCVar(cv) ~= "0" then
			pcall(C_CVar.SetCVar, cv, "0")
		end
	end
	-- 한 번 닫으면 다시 안 뜨는 안내창들도 전부 "본 것"으로
	if C_CVar and C_CVar.SetCVarBitfield and NUM_LE_FRAME_TUTORIALS then
		for i = 1, NUM_LE_FRAME_TUTORIALS do pcall(C_CVar.SetCVarBitfield, "closedInfoFrames", i, true) end
	end
	if NUM_LE_FRAME_TUTORIAL_ACCCOUNTS and C_CVar and C_CVar.SetCVarBitfield then
		for i = 1, NUM_LE_FRAME_TUTORIAL_ACCCOUNTS do pcall(C_CVar.SetCVarBitfield, "closedInfoFramesAccountWide", i, true) end
	end
	-- 도움말 말풍선(HelpTip)은 뜨는 즉시 닫는다
	if HelpTip and not self.helpHooked then
		self.helpHooked = true
		hooksecurefunc(HelpTip, "Show", function(_, parent, info)
			if Ink.db.hideTutorials == false then return end
			C_Timer.After(0, function()
				if info and info.text then pcall(HelpTip.Hide, HelpTip, parent, info.text) end
			end)
		end)
	end
	-- 초보자 안내 화살표·상자 (이미 떠 있는 것)
	for _, n in ipairs({ "NPE_TutorialPointerFrame", "NPE_TutorialMainFrame", "NPE_TutorialKeyboardMouseFrame",
		"TutorialPointerFrame", "TutorialMainFrame_Frame", "NPE_TutorialWalk_Frame", "NPE_TutorialSingleKey_Frame" }) do
		local f = _G[n]
		if type(f) == "table" and f.GetObjectType and f.IsProtected and not f:IsProtected() then
			pcall(Ink.KeepHidden, Ink, f)
		end
	end
end

local function HideDividers(bar)
	if not bar then return end
	for _, c in ipairs({ bar:GetChildren() }) do
		for _, r in ipairs({ c:GetRegions() }) do
			if r.IsObjectType and r:IsObjectType("Texture") then
				local atlas = r.GetAtlas and r:GetAtlas()
				if atlas and atlas:lower():find("divider") then r:SetAlpha(0) end
			end
		end
	end
	for _, r in ipairs({ bar:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") then
			local atlas = r.GetAtlas and r:GetAtlas()
			if atlas and atlas:lower():find("divider") then r:SetAlpha(0) end
		end
	end
end

function M:SkinActionBars()
	local bars = {
		{ "ActionButton", 12 }, { "MultiBarBottomLeftButton", 12 }, { "MultiBarBottomRightButton", 12 },
		{ "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 }, { "MultiBar5Button", 12 },
		{ "MultiBar6Button", 12 }, { "MultiBar7Button", 12 },
	}
	for _, def in ipairs(bars) do
		for i = 1, def[2] do SkinActionButton(_G[def[1] .. i]) end
	end
	for i = 1, 10 do
		SkinActionButton(_G["StanceButton" .. i], true)
		SkinActionButton(_G["PetActionButton" .. i], true)
	end
	for _, holder in ipairs({ _G.MainActionBar, _G.MainMenuBar }) do
		if holder then
			for _, k in ipairs({ "EndCaps", "BorderArt", "Background" }) do
				if holder[k] and holder[k].SetAlpha then holder[k]:SetAlpha(0) end
			end
			if holder.ActionBarPageNumber and holder.ActionBarPageNumber.SetAlpha then
				holder.ActionBarPageNumber:SetAlpha(0)
			end
			HideDividers(holder)
			if not holder.inkDivHook and holder.UpdateDividers then
				holder.inkDivHook = true
				hooksecurefunc(holder, "UpdateDividers", HideDividers)
			end
		end
	end
	for _, n in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "StanceBar" }) do HideDividers(_G[n]) end
end

-------------------------------------------------------------------------------
-- 경험치 바 (기본 바 대신 얇은 Ink 바)
-------------------------------------------------------------------------------
function M:BuildXP()
	local f = CreateFrame("Frame", "InkUIXPBar", Ink.root)
	f:SetSize(560, 18)
	f.bar = Ink:Bar(f, 560, 3, C.text)
	f.bar:SetPoint("BOTTOMLEFT")
	f.bar:SetStatusBarColor(0.62, 0.55, 1)
	f.rest = Ink:Bar(f, 560, 3, { 0.62, 0.55, 1, 0.35 }, { 0, 0, 0, 0 })
	f.rest:SetPoint("BOTTOMLEFT")
	f.rest:SetFrameLevel(f.bar:GetFrameLevel() - 1)
	f.label = Ink:Text(f, F.sans, 10, C.muted, "LEFT")
	f.label:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", 0, 4)
	f.value = Ink:Text(f, F.sans, 10, C.muted, "RIGHT")
	f.value:SetPoint("BOTTOMRIGHT", f.bar, "TOPRIGHT", 0, 4)
	f:SetAlpha(0.85)
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
	f:SetScript("OnLeave", function(self) self:SetAlpha(0.85) end)
	self.xp = f

	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN" }) do
		e:RegisterEvent(ev)
	end
	e:SetScript("OnEvent", function() M:UpdateXP() end)

	for _, n in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "StatusTrackingBarManager" }) do
		if _G[n] then Ink:Disable(_G[n]) end
	end
	Ink:Movable("xp", "경험치", f, "center", 680, 1056)
end

function M:UpdateXP()
	local f = self.xp
	if not f then return end
	local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 80
	local lvl = UnitLevel("player")
	if (lvl >= maxLevel or (IsXPUserDisabled and IsXPUserDisabled())) and not self.testing then
		f:Hide()
		return
	end
	f:Show()
	local cur, max = UnitXP("player"), UnitXPMax("player")
	if self.testing and (max or 0) <= 0 then cur, max = 4210, 10590 end
	max = (max and max > 0) and max or 1
	local rested = GetXPExhaustion() or 0
	f.bar:SetMinMaxValues(0, max)
	f.bar:SetValue(cur)
	f.rest:SetMinMaxValues(0, max)
	f.rest:SetValue(math.min(max, cur + rested))
	f.label:SetText("경험치 · " .. lvl .. " 레벨")
	local txt = BreakUpLargeNumbers(cur) .. " / " .. BreakUpLargeNumbers(max) .. string.format("  %.1f%%", cur / max * 100)
	if rested > 0 then txt = txt .. string.format("  ·  휴식 %d%%", rested / max * 100) end
	f.value:SetText(txt)
end

-------------------------------------------------------------------------------
function M:Init()
	-- 기본 배치(미니맵 / 채팅 / 메뉴 / 바)를 먼저
	self:BuildMinimap()
	self:BuildAnchors()
	if Ink.db.xp then self:BuildXP() end
	self:SkinActionBars()
	self:SkinChat()
	self:SkinQuest()
	self:SkinBuffs()
	-- 부가 기능은 하나가 실패해도 나머지에 영향이 없게 따로따로
	for _, fn in ipairs({ "BuildAddonList", "SetupQueue", "HookKeybindMode", "SetupAutoPush", "HookSpellAlerts", "HideVehicleSeats", "DisableTutorials", "SetupTalk", "BuildClock" }) do
		local ok, err = pcall(self[fn], self)
		if not ok then Ink:LogError("Blizzard." .. fn .. ": " .. tostring(err)) end
	end
	-- 초보자 튜토리얼은 늦게 불러와지기도 해서 한 번 더
	C_Timer.After(5, function() pcall(M.DisableTutorials, M) end)
	-- 늦게 만들어지는 미니맵 버튼까지 숨기려고 몇 번 더 모은다
	for _, d in ipairs({ 2, 6, 15 }) do
		C_Timer.After(d, function() pcall(M.CollectAddonButtons, M) end)
	end
end

function M:SetTest(on)
	self.testing = on
	self:UpdateXP()
	pcall(M.TestTalk, M, on)
end

-------------------------------------------------------------------------------
-- NPC 대사 창 (토킹 헤드): 배경 · 초상화 없이 이름 + 대사가 한 글자씩 써지듯
--  블리자드 대사 창은 숨기되(음성은 그대로 나온다) 같은 대사를 FOA 글자로 보여 준다.
--  위치는 FOA 편집 모드에서 "대사"로 옮긴다.
-------------------------------------------------------------------------------
local TYPE_SPEED = 42 -- 초당 글자 수

local function Utf8Len(t)
	if strlenutf8 then return strlenutf8(t) end
	local _, n = t:gsub("[^\128-\191]", "")
	return n
end

function M:BuildTalk()
	local f = CreateFrame("Button", "FOATalkingHead", Ink.root)
	f:SetSize(640, 96)
	f:SetFrameStrata("MEDIUM")
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- 글자가 배경에 묻히지 않게 아주 옅은 그림자만 (상자는 없음)
	f.shade = f:CreateTexture(nil, "BACKGROUND")
	f.shade:SetTexture(Ink.tex.glow)
	f.shade:SetPoint("TOPLEFT", -60, 34)
	f.shade:SetPoint("BOTTOMRIGHT", 60, -34)
	f.shade:SetVertexColor(0, 0, 0, 0.55)
	f.bar = f:CreateTexture(nil, "ARTWORK")
	f.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	f.bar:SetSize(18, 2)
	f.bar:SetPoint("TOPLEFT", 0, 0)
	f.name = Ink:Text(f, F.bold, 16, C.accent, "LEFT")
	f.name:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -7)
	f.name:SetShadowOffset(1, -1)
	f.name:SetShadowColor(0, 0, 0, 1)
	f.count = Ink:Text(f, F.latin, 10, C.muted, "LEFT")
	f.count:SetPoint("LEFT", f.name, "RIGHT", 8, -1)
	f.text = Ink:Text(f, F.semi, 15, C.text, "LEFT")
	f.text:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -8)
	f.text:SetWidth(640)
	f.text:SetSpacing(4)
	f.text:SetWordWrap(true)
	f.text:SetShadowOffset(1, -1)
	f.text:SetShadowColor(0, 0, 0, 1)
	f:SetAlpha(0)
	f:Hide()

	local ag = f:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0)
	a:SetToAlpha(1)
	a:SetDuration(0.25)
	local t = ag:CreateAnimation("Translation")
	t:SetOffset(0, 6)
	t:SetDuration(0.25)
	t:SetSmoothing("OUT")
	ag:SetScript("OnFinished", function() f:SetAlpha(1) end)
	f.intro = ag

	f:SetScript("OnUpdate", function(self, el)
		if self.fading then
			local a2 = self:GetAlpha() - el / 0.4
			if a2 <= 0 then self.fading = nil; self:SetAlpha(0); self:Hide() else self:SetAlpha(a2) end
			return
		end
		if self.len and self.pos < self.len then
			self.pos = math.min(self.len, self.pos + el * TYPE_SPEED)
			self.text:SetAlphaGradient(math.floor(self.pos), 18)
		end
		if self.untilT and GetTime() > self.untilT then M:CloseTalk() end
	end)
	-- 클릭: 쓰는 중이면 끝까지 보여 주고, 다 보였으면 닫기
	f:SetScript("OnClick", function(self, btn)
		if btn == "LeftButton" and self.len and self.pos < self.len then
			self.pos = self.len
			self.text:SetAlphaGradient(self.len, 1)
			return
		end
		if TalkingHeadFrame and TalkingHeadFrame.CloseImmediately then pcall(TalkingHeadFrame.CloseImmediately, TalkingHeadFrame) end
		M:CloseTalk(true)
	end)
	self.talk = f
	Ink:Movable("talk", "대사", f, "center", 640, 640, 640, 96)
end

function M:ShowTalk(name, text, idx, total, duration)
	local f = self.talk
	if not f or not text or text == "" then return end
	f.name:SetText(name or "")
	f.count:SetText((total and total > 1) and string.format("%d / %d", idx or 1, total) or "")
	f.text:SetText(text)
	f.len = Utf8Len(text)
	f.pos = 0
	f.text:SetAlphaGradient(0, 18)
	local readT = f.len / TYPE_SPEED + 2.5 + f.len * 0.03
	f.untilT = GetTime() + math.max(duration or 0, readT)
	f.fading = nil
	local wasShown = f:IsShown() and f:GetAlpha() > 0.5
	f:Show()
	if not wasShown then
		f:SetAlpha(0)
		f.intro:Stop()
		f.intro:Play()
	end
end

function M:CloseTalk(now)
	local f = self.talk
	if not f or not f:IsShown() then return end
	f.untilT, f.len = nil, nil
	if now then f.fading = nil; f:SetAlpha(0); f:Hide() else f.fading = true end
end

function M:OnTalkingHead(event)
	if event == "TALKINGHEAD_CLOSE" then
		if not self.testing then self:CloseTalk() end
		return
	end
	if not (C_TalkingHead and C_TalkingHead.GetCurrentLineInfo) then return end
	local _, _, _, duration, line, numLines, name, text = C_TalkingHead.GetCurrentLineInfo()
	text, name = plain(text), plain(name)
	if type(text) ~= "string" then return end
	self:ShowTalk(name, text, line, numLines, plain(duration))
end

function M:HideBlizzardTalk()
	local th = TalkingHeadFrame
	if not th or self.talkHidden then return end
	self.talkHidden = true
	-- 이벤트는 그대로 받게(음성 재생) 두고 화면에서만 뺀다
	Ink:Disable(th, true)
end

function M:SetupTalk()
	self:BuildTalk()
	self:HideBlizzardTalk()
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "TALKINGHEAD_REQUESTED", "TALKINGHEAD_CLOSE", "ADDON_LOADED" }) do pcall(e.RegisterEvent, e, ev) end
	e:SetScript("OnEvent", function(_, event, arg1)
		if event == "ADDON_LOADED" then
			if arg1 == "Blizzard_TalkingHeadUI" then M:HideBlizzardTalk() end
			return
		end
		-- 블리자드 쪽이 먼저 정보를 채우도록 한 프레임 뒤에
		C_Timer.After(0, function() pcall(M.OnTalkingHead, M, event) end)
	end)
end

-- 테스트 모드: 예시 대사
local TALK_SAMPLES = {
	{ "여군주 제이나 프라우드무어", "서두르세요. 래시온과 칼렉고스를 모두 구하려면 시간이 없어요." },
	{ "린디 스프링스톡", "아니면... 과학의 힘을 빌리죠! 크기 조정기로 주변 멧돼지를 크게 키워서 괴물들을 납작하게 짓밟는 거예요!" },
}
function M:TestTalk(on)
	if not self.talk then return end
	if self.talkTicker then self.talkTicker:Cancel(); self.talkTicker = nil end
	if not on then self:CloseTalk(true) return end
	local i = 0
	local function nextLine()
		i = i % #TALK_SAMPLES + 1
		local d = TALK_SAMPLES[i]
		M:ShowTalk(d[1], d[2], i, #TALK_SAMPLES, 6)
		M.talk.untilT = nil
	end
	nextLine()
	self.talkTicker = C_Timer.NewTicker(7, nextLine)
end

function M:PostLayout()
	self:LayoutMinimap()
	self:AnchorQueue()
	self:PlaceDurability()
	self:LayoutAnchors()
	self:SkinActionBars()
	self:SkinChat()
	self:SkinQuest()
	self:SkinBuffs()
	self:UpdateXP()
end

-------------------------------------------------------------------------------
-- 툴팁 (아이템 / 유닛 / 주문 등 모든 마우스오버 설명창)
--  어두운 둥근 판 + 옅은 테두리 + 왼쪽 위 짧은 포인트 선 (가방 창과 같은 결)
--  아이템은 등급 색, 플레이어는 직업 색, NPC는 관계 색으로 포인트 선과 테두리를 칠한다.
--  블리자드 툴팁 표에 키를 쓰지 않고 바깥 표에 둔다 (오염 방지).
-------------------------------------------------------------------------------
local T = Ink:Module("Tooltip")
local tipSkin = setmetatable({}, { __mode = "k" })

local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
	"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip", "WorldMapTooltip" }

local function TipColor(tt, r, g, b, strong)
	local s = tipSkin[tt]
	if not s then return end
	s.accent:SetVertexColor(r, g, b, 1)
	s.border:SetVertexColor(r, g, b, strong and 0.45 or 0.1)
	if not strong then s.border:SetVertexColor(1, 1, 1, 0.09) end
end

local function TipReset(tt)
	TipColor(tt, C.accent[1], C.accent[2], C.accent[3], false)
end

local function SkinTip(tt)
	if not tt or tipSkin[tt] or (tt.IsForbidden and tt:IsForbidden()) then return end
	local s = {}
	tipSkin[tt] = s
	if tt.NineSlice then tt.NineSlice:SetAlpha(0) end
	s.bg = Ink:Round(tt, "BACKGROUND", false, false, -8)
	s.bg:SetAllPoints()
	s.bg:SetVertexColor(0.035, 0.04, 0.052, 0.96)
	s.border = Ink:Round(tt, "BACKGROUND", false, true, -7)
	s.border:SetAllPoints()
	s.accent = tt:CreateTexture(nil, "BACKGROUND", nil, -6)
	s.accent:SetTexture(Ink.tex.white)
	s.accent:SetSize(24, 2)
	s.accent:SetPoint("TOPLEFT", 12, -1)
	TipReset(tt)
	if tt.HookScript then
		tt:HookScript("OnTooltipCleared", TipReset)
		tt:HookScript("OnShow", function(self) if self.NineSlice then self.NineSlice:SetAlpha(0) end end)
	end
end

local function SkinStatusBar()
	local sb = GameTooltipStatusBar
	if not sb or tipSkin[sb] then return end
	tipSkin[sb] = true
	sb:SetStatusBarTexture(Ink.tex.white)
	sb:SetHeight(3)
	sb:ClearAllPoints()
	-- 툴팁 바로 아래 얇은 밑줄처럼
	sb:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 6, -3)
	sb:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -6, -3)
	local bg = sb:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 1, 1, 0.08)
	for _, r in ipairs({ sb:GetRegions() }) do
		if r ~= bg and r.IsObjectType and r:IsObjectType("Texture") and r ~= sb:GetStatusBarTexture() then r:SetAlpha(0) end
	end
	if sb.Border then sb.Border:SetAlpha(0) end
	if sb.TextString then sb.TextString:SetAlpha(0) end
end

local function SetFonts()
	local function Set(obj, file, size)
		if obj and obj.SetFont then
			obj:SetFont(file, size, "")
			obj:SetShadowColor(0, 0, 0, 0.9)
			obj:SetShadowOffset(1, -1)
		end
	end
	Set(GameTooltipHeaderText, F.bold, 14)
	Set(GameTooltipText, F.sans, 12)
	Set(GameTooltipTextSmall, F.sans, 11)
	Set(Tooltip_Med, F.sans, 12)
	Set(Tooltip_Small, F.sans, 11)
end

local function OnItem(tt)
	if not tipSkin[tt] then return end
	local ok, _, link = pcall(tt.GetItem, tt)
	link = ok and plain(link)
	if not link then return end
	local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
	q = plain(q)
	if q and q >= 2 then
		local r, g, b = C_Item.GetItemQualityColor(q)
		TipColor(tt, r, g, b, true)
	elseif q then
		local r, g, b = C_Item.GetItemQualityColor(q)
		TipColor(tt, r, g, b, false)
	end
end

local function OnUnit(tt)
	if not tipSkin[tt] then return end
	local ok, _, unit = pcall(tt.GetUnit, tt)
	unit = ok and plain(unit)
	if not unit then return end
	local r, g, b
	if plain(UnitIsPlayer(unit)) then
		r, g, b = ns.ClassColor(unit)
	else
		local re = plain(UnitReaction(unit, "player"))
		local c = (re and re >= 5) and C.green or (re == 4) and C.orange or C.red
		r, g, b = c[1], c[2], c[3]
	end
	if r then TipColor(tt, r, g, b, false) end
	local sb = GameTooltipStatusBar
	if sb and r and tt == GameTooltip then sb:SetStatusBarColor(r, g, b) end
end

-- 기본 툴팁 위치: 오른쪽 아래 구석 대신 미터기 위쪽 (편집 모드에서 "툴팁"으로 옮길 수 있음)
function T:BuildAnchor()
	local a = Ink:Anchor(240, 60)
	self.anchor = a
	Ink:Movable("tooltip", "툴팁", a, "bottomright", 16, 300)
	if GameTooltip_SetDefaultAnchor then
		hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt)
			if tt ~= GameTooltip or (tt.IsForbidden and tt:IsForbidden()) then return end
			tt:ClearAllPoints()
			tt:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, 0)
		end)
	end
end

function T:Init()
	SetFonts()
	self:BuildAnchor()
	for _, n in ipairs(TIPS) do SkinTip(_G[n]) end
	SkinStatusBar()
	if hooksecurefunc and SharedTooltip_SetBackdropStyle then
		hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tt)
			if tipSkin[tt] and tt.NineSlice then tt.NineSlice:SetAlpha(0) end
		end)
	end
	if TooltipDataProcessor and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt) pcall(OnItem, tt) end)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) pcall(OnUnit, tt) end)
	end
end

-------------------------------------------------------------------------------
-- 화면 위 가운데 시계: 배경 없이 큰 숫자 + 노란 짧은 선 + 날짜
--  왼쪽 클릭: 내 컴퓨터 시간 <-> 서버 시간, 오른쪽 클릭: 달력
--  위치는 FOA 편집 모드에서 "시계"로 옮긴다.
-------------------------------------------------------------------------------
local WEEKDAY = { "일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일" }

local function ServerHM()
	if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
		local t = C_DateAndTime.GetCurrentCalendarTime()
		if t and t.hour then return t.hour, t.minute end
	end
	if GetGameTime then return GetGameTime() end
	return tonumber(date("%H")), tonumber(date("%M"))
end

function M:UpdateClock()
	local f = self.clock
	if not f then return end
	local h, m
	if Ink.db.clockServer then h, m = ServerHM() else h, m = tonumber(date("%H")), tonumber(date("%M")) end
	f.time:SetFormattedText("%02d:%02d", h or 0, m or 0)
	local wd = WEEKDAY[(tonumber(date("%w")) or 0) + 1]
	f.date:SetText(date("%m.%d") .. "  " .. wd .. (Ink.db.clockServer and "  ·  서버" or ""))
end

function M:ClockTip(f)
	GameTooltip:SetOwner(f, "ANCHOR_BOTTOM", 0, -6)
	GameTooltip:AddLine("시계", 1, 1, 1)
	local sh, sm = ServerHM()
	GameTooltip:AddDoubleLine("내 시간", date("%H:%M"), 0.7, 0.72, 0.75, 1, 1, 1)
	GameTooltip:AddDoubleLine("서버 시간", string.format("%02d:%02d", sh or 0, sm or 0), 0.7, 0.72, 0.75, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("왼쪽 클릭: " .. (Ink.db.clockServer and "내 시간으로" or "서버 시간으로"), 0.56, 0.58, 0.61)
	GameTooltip:AddLine("오른쪽 클릭: 달력", 0.56, 0.58, 0.61)
	GameTooltip:Show()
end

-- 블리자드 화면 위 가운데 위젯(점령 막대 · 진행도 등)은 시계 밑으로
function M:PlaceTopWidgets()
	local w = UIWidgetTopCenterContainerFrame
	if not (w and self.clock and self.clock:IsShown()) or w.inkPlacing then return end
	if w:IsProtected() and InCombatLockdown() then return end
	w.inkPlacing = true
	safe(function()
		w:ClearAllPoints()
		w:SetPoint("TOP", self.clock, "BOTTOM", 0, -6)
	end)
	w.inkPlacing = nil
end

function M:BuildClock()
	if Ink.db.clock == false then return end
	local f = CreateFrame("Button", "FOAClock", Ink.root)
	f:SetSize(180, 58)
	f:SetFrameStrata("LOW")
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	f.time = Ink:Text(f, F.num, 32, C.text, "CENTER")
	f.time:SetPoint("TOP", 0, -2)
	f.time:SetShadowOffset(0, -1)
	f.time:SetShadowColor(0, 0, 0, 0.6)

	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetSize(18, 2)
	f.line:SetPoint("TOP", f.time, "BOTTOM", 0, -4)
	f.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)

	f.date = Ink:Text(f, F.latin, 10, C.soft, "CENTER")
	f.date:SetPoint("TOP", f.line, "BOTTOM", 0, -5)

	f:SetScript("OnClick", function(self, btn)
		if btn == "RightButton" then
			if ToggleCalendar then pcall(ToggleCalendar) end
			return
		end
		Ink.db.clockServer = not Ink.db.clockServer
		M:UpdateClock()
		if GameTooltip:IsOwned(self) then M:ClockTip(self) end
	end)
	f:SetScript("OnEnter", function(self)
		self.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
		self.line:SetWidth(30)
		M:ClockTip(self)
	end)
	f:SetScript("OnLeave", function(self)
		self.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
		self.line:SetWidth(18)
		GameTooltip:Hide()
	end)

	-- 시계 오른쪽: 키보드 아이콘 → FOA 빠른 단축키 설정
	local kb = CreateFrame("Button", nil, f)
	kb:SetSize(24, 24)
	kb:SetPoint("LEFT", f.time, "RIGHT", 10, -1)
	kb.bg = Ink:Round(kb, "BACKGROUND", true, false)
	kb.bg:SetAllPoints()
	kb.bg:SetVertexColor(1, 1, 1, 0)
	kb.bd = Ink:Round(kb, "BORDER", true, true)
	kb.bd:SetAllPoints()
	kb.bd:SetVertexColor(1, 1, 1, 0.14)
	kb.icon = kb:CreateTexture(nil, "ARTWORK")
	kb.icon:SetSize(14, 14)
	kb.icon:SetPoint("CENTER")
	kb.icon:SetTexture(Ink.icon("Keyboard"))
	kb.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3], 0.85)
	kb:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.07)
		self.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
		self.icon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -6)
		GameTooltip:AddLine("빠른 단축키 설정", 1, 1, 1)
		GameTooltip:AddLine("행동 단축바 칸에 마우스를 올리고 키를 누르면 바로 지정돼요", 0.56, 0.58, 0.61, true)
		GameTooltip:Show()
	end)
	kb:SetScript("OnLeave", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0)
		self.bd:SetVertexColor(1, 1, 1, 0.14)
		self.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3], 0.85)
		GameTooltip:Hide()
	end)
	kb:SetScript("OnClick", function()
		GameTooltip:Hide()
		if InCombatLockdown() then return end
		if Ink.OpenQuickKeybind then Ink:OpenQuickKeybind() end
	end)
	f.kb = kb

	local t = 1
	f:SetScript("OnUpdate", function(_, e)
		t = t + e
		-- 전투 중에는 사라졌다가 전투가 끝나면 스르륵
		if f.fadeTo then
			local a = f:GetAlpha()
			local step = e / 0.3
			a = (f.fadeTo > a) and math.min(f.fadeTo, a + step) or math.max(f.fadeTo, a - step)
			f:SetAlpha(a)
			if a == f.fadeTo then f.fadeTo = nil end
		end
		if t < 1 then return end
		t = 0
		M:UpdateClock()
	end)
	if Ink.db.combatHide ~= false then
		local ev = CreateFrame("Frame")
		ev:RegisterEvent("PLAYER_REGEN_DISABLED")
		ev:RegisterEvent("PLAYER_REGEN_ENABLED")
		ev:SetScript("OnEvent", function(_, event)
			local fight = event == "PLAYER_REGEN_DISABLED"
			f.fadeTo = fight and 0 or 1
			f:EnableMouse(not fight)
			kb:EnableMouse(not fight)
			if fight and GameTooltip:IsOwned(f) then GameTooltip:Hide() end
		end)
		if InCombatLockdown() then f:SetAlpha(0); f:EnableMouse(false); kb:EnableMouse(false) end
	end
	self.clock = f
	Ink:Movable("clock", "시계", f, "center", 870, 10, 180, 58)
	self:UpdateClock()

	local w = UIWidgetTopCenterContainerFrame
	if w then
		hooksecurefunc(w, "SetPoint", function() M:PlaceTopWidgets() end)
		self:PlaceTopWidgets()
	end
end
