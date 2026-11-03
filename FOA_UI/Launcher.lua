-- InkUI · 진영 문양 메뉴
--  화면 왼쪽 위, 화면 위 끝에 매달린 진영 깃발(얼라이언스: 남색+금테 / 호드: 진홍+금테).
--  누르면 오른쪽으로 메뉴 줄이 좌르륵 펼쳐지고, 다시 누르면 좌르륵 접힌다.
--  메뉴: 가방 / 캐릭터 / 전문기술 / 마법책·특성 / 업적 / 퀘스트 / 하우징 / 길드 / 파티 찾기 / 수집품 / 모험 안내서 / 상점 / 게임 메뉴
--  문양 아래 가운데에는 지금 전문화(특성) 문장.
--  메뉴 버튼은 블리자드 메뉴 버튼을 "보안 클릭"으로 대신 눌러 준다 → 전투 중에도 되고, 창이 오염되지 않는다.
--  펼치기/접기도 보안 처리라 전투 중에 된다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Launcher")
local F, C = Ink.font, Ink.c

local BW, BH, BTN, GAP = 44, 64, 30, 3

local ITEMS = {
	{ icon = "Bag", label = "가방", click = "MainMenuBarBackpackButton" },
	{ icon = "Character", label = "캐릭터 정보", click = "CharacterMicroButton" },
	{ icon = "Professions", label = "전문기술", click = "ProfessionMicroButton" },
	{ icon = "Spells", label = "마법책 · 특성", click = "PlayerSpellsMicroButton" },
	{ icon = "Achievements", label = "업적", click = "AchievementMicroButton" },
	{ icon = "Quests", label = "퀘스트 일지", click = "QuestLogMicroButton" },
	{ icon = "Housing", label = "하우징", click = "HousingMicroButton" },
	{ icon = "Guild", label = "길드 · 커뮤니티", click = "GuildMicroButton" },
	{ icon = "Group", label = "파티 찾기", click = "LFDMicroButton" },
	{ icon = "Collections", label = "수집품", click = "CollectionsMicroButton" },
	{ icon = "Journal", label = "모험 안내서", click = "EJMicroButton" },
	{ icon = "Shop", label = "상점", click = "StoreMicroButton" },
	{ icon = "Menu", label = "게임 메뉴", click = "MainMenuMicroButton" },
}

local FACTION = {
	Alliance = { glow = { 0.36, 0.6, 1 }, file = "Interface\\Timer\\Alliance-Logo",
		crest = { "UI-HUD-UnitFrame-Player-PVP-AllianceIcon" } },
	Horde = { glow = { 0.95, 0.32, 0.28 }, file = "Interface\\Timer\\Horde-Logo",
		crest = { "UI-HUD-UnitFrame-Player-PVP-HordeIcon" } },
}
local TRIM = { 0.89, 0.75, 0.48 }   -- 금테

local function HasAtlas(a)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(a) ~= nil
end

local function Tex(parent, layer, sub, file, size)
	local t = parent:CreateTexture(nil, layer, nil, sub)
	t:SetTexture(file)
	if size then t:SetSize(size, size) end
	return t
end

-------------------------------------------------------------------------------
-- 문양
-------------------------------------------------------------------------------
function M:UpdateFaction()
	local e = self.emblem
	local fd = FACTION[UnitFactionGroup("player") or ""]
	local glow = fd and fd.glow or C.accent
	if fd then
		-- 전장 시작 타이머에 쓰이는 배경 없는 진영 문양
		e.logo:SetTexture(fd.file)
		e.shine:SetTexture(fd.file)
		if not e.logo:GetTexture() then
			for _, a in ipairs(fd.crest) do
				if HasAtlas(a) then e.logo:SetAtlas(a); e.shine:SetAtlas(a); break end
			end
		end
	else
		e.logo:SetTexture(Ink.icon("Menu"))
	end
	e.glow:SetVertexColor(glow[1], glow[2], glow[3])
	self.color = glow
end

function M:UpdateSpec()
	local e = self.emblem
	local idx = GetSpecialization and GetSpecialization()
	local icon = idx and select(4, GetSpecializationInfo(idx))
	local _, class = UnitClass("player")
	if icon then
		e.spec.icon:SetTexCoord(0, 1, 0, 1)
		e.spec.icon:SetTexture(icon)
		e.spec:Show()
	elseif class and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("classicon-" .. class:lower()) then
		-- 전문화가 없으면(포에버 저레벨 등) 직업 문양으로
		e.spec.icon:SetAtlas("classicon-" .. class:lower())
		e.spec:Show()
	else
		e.spec:Hide()
	end
	local r, g, b = ns.ClassTint(class)
	e.spec.ring:SetVertexColor(r, g, b, 1)
end

-------------------------------------------------------------------------------
-- 펼침 / 접힘 애니메이션 ("좌르륵")
--  판은 왼쪽부터 길어지고, 아이콘은 하나씩 미끄러져 들어온다. 접힐 땐 거꾸로.
--  그림(텍스처)만 움직이고 보안 버튼 자체는 건드리지 않는다.
-------------------------------------------------------------------------------
local OPEN_T, CLOSE_T, STAGGER = 0.32, 0.24, 0.35

local function Ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

function M:Apply(p)
	local tray = self.tray
	local n = #self.icons
	local w = 8 + (tray.fullW - 8) * Ease(p)
	tray.bg:SetWidth(w)
	tray.bd:SetWidth(w)
	tray.accent:SetAlpha(Ease(p))
	for i, ic in ipairs(self.icons) do
		-- 아이콘마다 조금씩 늦게 (접힐 땐 오른쪽 것부터)
		local start = (i - 1) / n * STAGGER
		local q = (p - start) / (1 - STAGGER)
		local e = Ease(q)
		ic:SetAlpha(e)
		ic:SetPoint("CENTER", ic:GetParent(), "CENTER", -14 * (1 - e), 0)
	end
end

function M:Animate(dir)
	self.dir = dir
	self.p = self.p or (dir > 0 and 0 or 1)
	self:Apply(self.p)
	self.driver:Show()
end

function M:BuildDriver()
	local d = CreateFrame("Frame")
	d:Hide()
	d:SetScript("OnUpdate", function(self, el)
		local m = M
		local dur = m.dir > 0 and OPEN_T or CLOSE_T
		m.p = math.max(0, math.min(1, m.p + m.dir * el / dur))
		m:Apply(m.p)
		if (m.dir > 0 and m.p >= 1) or (m.dir < 0 and m.p <= 0) then
			self:Hide()
			if m.dir < 0 and not InCombatLockdown() then m.tray:Hide() end
		end
	end)
	self.driver = d
end

-------------------------------------------------------------------------------
-- 만들기
-------------------------------------------------------------------------------
function M:Build()
	local anchor = Ink:Anchor(BW, BH)
	self.anchor = anchor

	local e = CreateFrame("Button", "InkUILauncher", Ink.root, "SecureHandlerClickTemplate")
	e:SetSize(BW, BH)
	e:SetPoint("TOP", anchor, "TOP")
	e:RegisterForClicks("AnyUp")
	e:SetFrameStrata("MEDIUM")
	self.emblem = e

	-- 배경 없이 진영 문양만 + 뒤에 은은한 진영색 빛
	e.glow = Tex(e, "BACKGROUND", -8, Ink.tex.glow)
	e.glow:SetPoint("TOPLEFT", e, "TOPLEFT", -16, 12)
	e.glow:SetPoint("BOTTOMRIGHT", e, "TOPRIGHT", 16, -BW - 12)
	e.glow:SetAlpha(0.22)
	e.logo = e:CreateTexture(nil, "ARTWORK")
	e.logo:SetSize(BW, BW)
	e.logo:SetPoint("TOP", e, "TOP", 0, 0)
	e.shine = e:CreateTexture(nil, "OVERLAY")
	e.shine:SetAllPoints(e.logo)
	e.shine:SetBlendMode("ADD")
	e.shine:SetAlpha(0)

	-- 전문화 문장 (진영 문양 아래 가운데)
	local sp = CreateFrame("Frame", nil, e)
	sp:SetSize(20, 20)
	sp:SetPoint("TOP", e.logo, "BOTTOM", 0, 1)
	sp:SetFrameLevel(e:GetFrameLevel() + 3)
	sp.disc = Tex(sp, "BACKGROUND", 0, Ink.tex.disc)
	sp.disc:SetAllPoints()
	sp.disc:SetVertexColor(0.02, 0.022, 0.03, 1)
	sp.icon = sp:CreateTexture(nil, "ARTWORK")
	sp.icon:SetPoint("TOPLEFT", 3, -3)
	sp.icon:SetPoint("BOTTOMRIGHT", -3, 3)
	sp.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local mask = sp:CreateMaskTexture()
	mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(sp.icon)
	sp.icon:AddMaskTexture(mask)
	sp.ring = Tex(sp, "OVERLAY", 0, Ink.tex.ring)
	sp.ring:SetAllPoints()
	e.spec = sp

	-- 메뉴 줄
	local tray = CreateFrame("Frame", "InkUILauncherTray", e)
	tray:SetHeight(BTN + 10)
	-- 보안 프레임은 텍스처에 붙일 수 없어서 문양 버튼(프레임) 기준으로 문양 높이 가운데에 맞춘다
	tray:SetPoint("LEFT", e, "TOPRIGHT", 12, -BW / 2)
	self.tray = tray
	tray.bg = Ink:Round(tray, "BACKGROUND", false, false, -8)
	tray.bg:SetAllPoints()
	tray.bg:SetVertexColor(0.035, 0.04, 0.052, 0.92)
	tray.bd = Ink:Round(tray, "BORDER", false, true, -8)
	tray.bd:SetAllPoints()
	tray.bd:SetVertexColor(1, 1, 1, 0.08)
	tray.accent = tray:CreateTexture(nil, "ARTWORK")
	tray.accent:SetColorTexture(1, 1, 1, 0.9)
	tray.accent:SetSize(18, 2)
	tray.accent:SetPoint("TOPLEFT", 12, -1)

	self.icons = {}
	tray.bg:ClearAllPoints()
	tray.bg:SetPoint("TOPLEFT")
	tray.bg:SetPoint("BOTTOMLEFT")
	tray.bd:ClearAllPoints()
	tray.bd:SetPoint("TOPLEFT")
	tray.bd:SetPoint("BOTTOMLEFT")
	local x, n = 6, 0
	for _, it in ipairs(ITEMS) do
		local target = _G[it.click]
		if target then
			n = n + 1
			local b = CreateFrame("Button", nil, tray, "SecureActionButtonTemplate")
			b:SetSize(BTN, BTN)
			b:SetPoint("LEFT", tray, "LEFT", x, 0)
			b:RegisterForClicks("AnyUp")
			b:SetAttribute("useOnKeyDown", false)
			b:SetAttribute("type", "click")
			b:SetAttribute("clickbutton", target)
			b.hl = b:CreateTexture(nil, "BACKGROUND")
			b.hl:SetTexture(Ink.tex.round4)
			if b.hl.SetTextureSliceMargins then b.hl:SetTextureSliceMargins(5, 5, 5, 5) end
			b.hl:SetAllPoints()
			b.hl:SetVertexColor(1, 1, 1, 0)
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetTexture(Ink.icon(it.icon))
			b.icon:SetSize(18, 18)
			b.icon:SetPoint("CENTER")
			b.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3], 1)
			b.dot = b:CreateTexture(nil, "OVERLAY")
			b.dot:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
			b.dot:SetSize(10, 2)
			b.dot:SetPoint("BOTTOM", 0, 1)
			b.dot:Hide()
			b:SetScript("OnEnter", function(self)
				self.hl:SetVertexColor(1, 1, 1, 0.08)
				self.icon:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
				self.dot:Show()
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -6)
				GameTooltip:SetText(it.label, 1, 1, 1)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function(self)
				self.hl:SetVertexColor(1, 1, 1, 0)
				self.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3], 1)
				self.dot:Hide()
				GameTooltip:Hide()
			end)
			self.icons[#self.icons + 1] = b.icon
			if it.click == "MainMenuMicroButton" then self.menuSlot = b end
			x = x + BTN + GAP
		end
	end
	tray:SetWidth(x - GAP + 6)
	tray.fullW = x - GAP + 6
	self:BuildDriver()

	-- 펼치기 / 접기 (보안 처리 → 전투 중에도 동작)
	e:SetFrameRef("tray", tray)
	-- 접을 때: 전투 중이면 바로 숨기고, 아니면 Lua 쪽에 "접기"를 알려 애니메이션 후 숨긴다
	e:SetAttribute("_onclick", [[
		local t = self:GetFrameRef("tray")
		if t:IsShown() and not self:GetAttribute("inkClosing") then
			if PlayerInCombat() then
				t:Hide()
			else
				self:SetAttribute("inkClosing", true)
				self:SetAttribute("inkClose", (self:GetAttribute("inkClose") or 0) + 1)
			end
		else
			self:SetAttribute("inkClosing", nil)
			t:Show()
			self:SetAttribute("inkOpen", (self:GetAttribute("inkOpen") or 0) + 1)
		end
	]])
	e:HookScript("OnAttributeChanged", function(self, name)
		if name == "inkclose" then
			Ink.db.launcherOpen = false
			M:Animate(-1)
		elseif name == "inkopen" then
			Ink.db.launcherOpen = true
			M:Animate(1)
		end
	end)
	tray:HookScript("OnHide", function()
		if not InCombatLockdown() then e:SetAttribute("inkClosing", nil) end
		M.p = 0
		M:Apply(0)
	end)
	e:SetScript("OnEnter", function(self)
		self.shine:SetAlpha(0.3)
		self.glow:SetAlpha(0.45)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 4, 4)
		GameTooltip:SetText("메뉴", 1, 1, 1)
		GameTooltip:AddLine(tray:IsShown() and "눌러서 접기" or "눌러서 펼치기", C.muted[1], C.muted[2], C.muted[3])
		GameTooltip:Show()
	end)
	e:SetScript("OnLeave", function(self)
		self.shine:SetAlpha(0)
		self.glow:SetAlpha(0.28)
		GameTooltip:Hide()
	end)

	self:SetupGameMenuSlot()
	self:SetupCombatHide()

	if Ink.db.launcherOpen then
		tray:Show()
		self.p = 0
		self:Animate(1)
	else
		tray:Hide()
	end
	Ink:Movable("launcher", "메뉴", anchor, "left", 14, 10)
end

-------------------------------------------------------------------------------
-- "게임 메뉴" 칸
--  블리자드 게임 메뉴 버튼은 "마우스가 실제로 그 버튼 위에 있을 때만" 열린다.
--  그래서 대신 눌러 주는 방식이 안 먹힌다 → 진짜 버튼을 투명하게 만들어 이 칸 위에 그대로 얹는다.
--  (클릭은 진짜 버튼이 받으니 접속 종료 · 게임 종료도 오염 없이 정상 동작)
-------------------------------------------------------------------------------
function M:PlaceGameMenuButton()
	local mb, slot = MainMenuMicroButton, self.menuSlot
	if not (mb and slot) or mb.inkPlacing then return end
	if mb:IsProtected() and InCombatLockdown() then return end
	mb.inkPlacing = true
	pcall(function()
		if mb:GetParent() ~= slot then mb:SetParent(slot) end
		mb:ClearAllPoints()
		mb:SetAllPoints(slot)
		mb:SetFrameLevel(slot:GetFrameLevel() + 5)
		mb:SetAlpha(0)
		mb:Show()
	end)
	mb.inkPlacing = nil
end

function M:SetupGameMenuSlot()
	local mb, slot = MainMenuMicroButton, self.menuSlot
	if not (mb and slot) then return end
	-- 진짜 버튼에 마우스가 올라가면 FOA 칸이 반응하게
	mb:HookScript("OnEnter", function()
		slot.hl:SetVertexColor(1, 1, 1, 0.08)
		slot.icon:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
		slot.dot:Show()
	end)
	mb:HookScript("OnLeave", function()
		slot.hl:SetVertexColor(1, 1, 1, 0)
		slot.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3], 1)
		slot.dot:Hide()
	end)
	-- 메뉴 줄 배치가 다시 잡혀도 이 칸으로 되돌린다
	hooksecurefunc(mb, "SetPoint", function() M:PlaceGameMenuButton() end)
	hooksecurefunc(mb, "SetParent", function() M:PlaceGameMenuButton() end)
	if mb.SetAlpha then hooksecurefunc(mb, "SetAlpha", function(self, a) if a ~= 0 and not self.inkPlacing then M:PlaceGameMenuButton() end end) end
	self:PlaceGameMenuButton()
end

-------------------------------------------------------------------------------
-- 전투 중 숨기기: 전투가 시작되면 문양 · 특성 문장이 사라지고, 끝나면 스르륵 다시
--  (보안 숨김이라 전투 중에도 클릭이 엉뚱하게 먹지 않는다)
-------------------------------------------------------------------------------
function M:SetupCombatHide()
	local e = self.emblem
	if Ink.db.combatHide == false then return end
	RegisterStateDriver(e, "visibility", "[combat] hide; show")
	e:HookScript("OnShow", function(self)
		self:SetAlpha(0)
		local t = 0
		Ink:Loop("launcherFadeIn", function()
			t = t + 0.05
			local a = math.min(1, t / 0.35)
			self:SetAlpha(a)
			if a >= 1 then Ink:Loop("launcherFadeIn", nil) end
		end)
	end)
end

function M:Init()
	if Ink.db.launcher == false then return end
	self:Build()
	self:UpdateFaction()
	self:UpdateSpec()
	-- 숨긴 가방 칸 줄이 문양 위에서 클릭을 가로채지 않게
	for _, b in ipairs({ MainMenuBarBackpackButton, CharacterBag0Slot, CharacterBag1Slot, CharacterBag2Slot,
		CharacterBag3Slot, CharacterReagentBag0Slot, BagBarExpandToggle }) do
		if b and b.EnableMouse and not (b:IsProtected() and InCombatLockdown()) then pcall(b.EnableMouse, b, false) end
	end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT")
	ev:RegisterEvent("PLAYER_TALENT_UPDATE")
	ev:SetScript("OnEvent", function()
		M:UpdateFaction()
		M:UpdateSpec()
	end)
end
