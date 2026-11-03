-- InkUI · 설정 / 편집 모드 / 테스트 모드

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Config")
local F, C = Ink.font, Ink.c

-------------------------------------------------------------------------------
-- 버튼 / 체크박스 (Ink 스타일)
-------------------------------------------------------------------------------
local function Button(parent, text, w, onClick, primary)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w or 120, 30)
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bd = Ink:Round(b, "BORDER", true, true)
	b.bd:SetAllPoints()
	b.text = Ink:Text(b, F.semi, 12, C.text, "CENTER")
	b.text:SetPoint("CENTER")
	b.text:SetText(text)
	function b:SetActive(on)
		self.active = on
		if on or primary then
			self.bg:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], on and 0.22 or 0.14)
			self.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
			self.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		else
			self.bg:SetVertexColor(1, 1, 1, 0.05)
			self.bd:SetVertexColor(1, 1, 1, 0.16)
			self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
		end
	end
	b:SetActive(false)
	b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.10) end)
	b:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
	b:SetScript("OnClick", onClick)
	return b
end

local function Check(parent, label, desc, key)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(420, 36)
	f.box = CreateFrame("Frame", nil, f)
	f.box:SetSize(16, 16)
	f.box:SetPoint("TOPLEFT", 0, -2)
	f.box.bd = Ink:Round(f.box, "BORDER", true, true)
	f.box.bd:SetAllPoints()
	f.box.bd:SetVertexColor(1, 1, 1, 0.3)
	f.box.fill = Ink:Round(f.box, "ARTWORK", true, false)
	f.box.fill:SetPoint("TOPLEFT", 3, -3)
	f.box.fill:SetPoint("BOTTOMRIGHT", -3, 3)
	f.box.fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	f.label = Ink:Text(f, F.semi, 13, C.text, "LEFT")
	f.label:SetPoint("TOPLEFT", f.box, "TOPRIGHT", 10, 1)
	f.label:SetText(label)
	f.desc = Ink:Text(f, F.sans, 11, C.muted, "LEFT")
	f.desc:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -3)
	f.desc:SetText(desc)
	local function refresh() f.box.fill:SetShown(Ink.db[key] and true or false) end
	f:SetScript("OnShow", refresh)
	f:SetScript("OnClick", function()
		Ink.db[key] = not Ink.db[key]
		refresh()
		M:NeedReload()
	end)
	refresh()
	return f
end

-------------------------------------------------------------------------------
-- 편집 모드: 내 프레임마다 이동용 상자를 띄운다
-------------------------------------------------------------------------------
M.overlays = {}

local function MoverSize(m)
	local w, h = m.frame:GetSize()
	if m.w then w = m.w end
	if m.h then h = m.h end
	if not w or w < 20 then w = 120 end
	if not h or h < 14 then h = 24 end
	return w, h
end

local function BuildOverlay(m)
	local o = CreateFrame("Frame", nil, Ink.root)
	o:SetFrameStrata("DIALOG")
	o:SetMovable(true)
	o:EnableMouse(true)
	o:RegisterForDrag("LeftButton")
	o:SetClampedToScreen(true)
	o.bg = o:CreateTexture(nil, "BACKGROUND")
	o.bg:SetAllPoints()
	o.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08)
	Ink:Border(o, { C.accent[1], C.accent[2], C.accent[3], 0.7 })
	o.label = Ink:Text(o, F.semi, 11, C.accent, "LEFT")
	o.label:SetPoint("BOTTOMLEFT", o, "TOPLEFT", 0, 3)
	o.label:SetText(m.label)
	o.coords = Ink:Text(o, F.sans, 10, C.muted, "RIGHT")
	o.coords:SetPoint("BOTTOMRIGHT", o, "TOPRIGHT", 0, 3)
	o:SetScript("OnEnter", function(self) self.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.18) end)
	o:SetScript("OnLeave", function(self) self.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08) end)
	o:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then return end
		self.dragging = true
		self:StartMoving()
		self:SetScript("OnUpdate", function()
			if InCombatLockdown() then return end
			m.frame:ClearAllPoints()
			m.frame:SetPoint("TOPLEFT", self, "TOPLEFT")
		end)
	end)
	o:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetScript("OnUpdate", nil)
		self.dragging = nil
		if InCombatLockdown() then return end
		Ink:SavePos(m.key)
		Ink:Relayout()
		M:SyncOverlay(m)
	end)
	-- 우클릭: 이 요소만 기본 위치로
	o:SetScript("OnMouseUp", function(_, btn)
		if btn == "RightButton" and not InCombatLockdown() then
			Ink:ResetPos(m.key)
			Ink:Relayout()
			M:SyncOverlay(m)
		end
	end)
	return o
end

function M:SyncOverlay(m)
	local o = self.overlays[m.key]
	if not o then return end
	local w, h = MoverSize(m)
	o:ClearAllPoints()
	o:SetPoint("TOPLEFT", m.frame, "TOPLEFT")
	o:SetSize(w, h)
	local p = Ink.cdb.pos[m.key]
	o.coords:SetText(p and string.format("%d, %d", p.x, p.y) or "기본 위치")
end

function M:SetEdit(on)
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투 중에는 편집 모드를 쓸 수 없어요.")
		return
	end
	self.editing = on
	for _, key in ipairs(Ink.moverOrder) do
		local m = Ink.movers[key]
		local o = self.overlays[key]
		if on then
			if not o then
				o = BuildOverlay(m)
				self.overlays[key] = o
			end
			self:SyncOverlay(m)
			o:Show()
		elseif o then
			o:Hide()
		end
	end
	self:ShowBar(on)
	if on and not self.testing then self:SetTest(true) end
	if not on and self.testFromEdit then self:SetTest(false) end
	self:SyncButtons()
end

-------------------------------------------------------------------------------
-- 테스트 모드: 파티 / 레이드 / 대상 프레임 등을 예시 데이터로 띄운다
-------------------------------------------------------------------------------
function M:SetTest(on)
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투 중에는 테스트 모드를 바꿀 수 없어요.")
		return
	end
	self.testing = on
	self.testFromEdit = on and self.editing or nil
	for _, mod in ipairs(Ink.modules) do
		if mod ~= self and mod.SetTest then
			local ok, err = pcall(mod.SetTest, mod, on)
			if not ok then
				print("|cffFF6B5EFOA|r " .. mod.name .. ".SetTest: " .. tostring(err))
				Ink:LogError(mod.name .. ".SetTest: " .. tostring(err))
			end
		end
	end
	self:SyncButtons()
end

-------------------------------------------------------------------------------
-- 화면 위쪽 편집 도구 막대
-------------------------------------------------------------------------------
function M:ShowBar(on)
	if not self.bar then
		local bar = CreateFrame("Frame", nil, Ink.root)
		bar:SetFrameStrata("FULLSCREEN_DIALOG")
		bar:SetSize(700, 52)
		bar:SetPoint("TOP", Ink.root, "TOP", 0, -260)
		bar.bg = Ink:Round(bar, "BACKGROUND", false, false)
		bar.bg:SetAllPoints()
		bar.bg:SetVertexColor(0.05, 0.06, 0.08, 0.94)
		bar.bd = Ink:Round(bar, "BORDER", false, true)
		bar.bd:SetAllPoints()
		bar.bd:SetVertexColor(1, 1, 1, 0.12)
		bar.title = Ink:Text(bar, F.bold, 13, C.text, "LEFT")
		bar.title:SetPoint("TOPLEFT", 16, -10)
		bar.title:SetText("FOA 편집 모드")
		bar.hint = Ink:Text(bar, F.sans, 10, C.muted, "LEFT")
		bar.hint:SetPoint("TOPLEFT", bar.title, "BOTTOMLEFT", 0, -3)
		bar.hint:SetText("드래그로 이동 · 우클릭은 기본 위치로")
		bar.done = Button(bar, "완료", 70, function() M:SetEdit(false) end, true)
		bar.done:SetPoint("RIGHT", -12, 0)
		bar.reset = Button(bar, "전체 초기화", 96, function() M:ResetAll() end)
		bar.reset:SetPoint("RIGHT", bar.done, "LEFT", -8, 0)
		bar.test = Button(bar, "예시 표시", 84, function() M:SetTest(not M.testing) end)
		bar.test:SetPoint("RIGHT", bar.reset, "LEFT", -8, 0)
		bar.group = Button(bar, "파티 예시", 84, function() M:ToggleGroup() end)
		bar.group:SetPoint("RIGHT", bar.test, "LEFT", -8, 0)
		self.bar = bar
	end
	self.bar:SetShown(on)
end

function M:ResetAll()
	if InCombatLockdown() then return end
	Ink:ResetPos()
	Ink:Relayout()
	local B = Ink.modules.Bags
	if B and B.frame and B.ApplyPos then B:ApplyPos() end
	for _, key in ipairs(Ink.moverOrder) do self:SyncOverlay(Ink.movers[key]) end
end

M.testGroup = "party"
function M:ToggleGroup()
	self.testGroup = (self.testGroup == "party") and "raid" or "party"
	if not self.testing then self:SetTest(true) end
	local g = Ink.modules.Group
	if g and g.SetTest then g:SetTest(true) end
	self:SyncButtons()
end

function M:SyncButtons()
	if self.bar then
		self.bar.test:SetActive(self.testing)
		self.bar.group.text:SetText(self.testGroup == "raid" and "레이드 예시" or "파티 예시")
	end
	if self.panel then
		self.panel.edit:SetActive(self.editing)
		self.panel.test:SetActive(self.testing)
	end
end

function M:NeedReload()
	if self.panel then self.panel.reload:Show() end
end

-------------------------------------------------------------------------------
-- 설정 창 (게임 메뉴 > 설정 > 애드온 > InkUI)
-------------------------------------------------------------------------------
function M:BuildPanel()
	local p = CreateFrame("Frame")
	p.name = "FOA UI"
	p:Hide()

	-- 제목: 기하 모노그램 마크 + FOA 도형 글자
	local brand, ui = Ink:Brand(p, 20)
	brand:SetPoint("TOPLEFT", 18, -16)
	local ver = Ink:Text(p, F.latin, 11, C.muted, "LEFT")
	ver:SetPoint("LEFT", ui, "RIGHT", 10, -1)
	ver:SetText("v" .. Ink.version .. "  ·  First of All")
	local h1 = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
	h1:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 2, -20)
	h1:SetText("배치")
	p.edit = Button(p, "편집 모드", 130, function()
		M:SetEdit(not M.editing)
		if M.editing and SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	end)
	p.edit:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -10)
	p.test = Button(p, "테스트 모드", 130, function() M:SetTest(not M.testing) end)
	p.test:SetPoint("LEFT", p.edit, "RIGHT", 8, 0)
	p.reset = Button(p, "위치 초기화", 130, function() M:ResetAll() end)
	p.reset:SetPoint("LEFT", p.test, "RIGHT", 8, 0)
	p.kb = Button(p, "단축키 설정", 130, function() Ink:OpenQuickKeybind() end)
	p.kb:SetPoint("LEFT", p.reset, "RIGHT", 8, 0)

	-- 두 칸으로: 왼쪽 = 화면 구성, 오른쪽 = 편의 기능 + 명령어
	local function Column(anchor, x, header, list)
		local h = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
		h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -26)
		h:SetText(header)
		local prev = h
		for i, it in ipairs(list) do
			local c = Check(p, it[1], it[2], it[3])
			c:SetWidth(300)
			c.desc:SetWidth(270)
			c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -10 or -6)
			prev = c
		end
		return prev
	end
	local left = Column(p.edit, 0, "화면 구성 (바꾸면 /reload 필요)", {
		{ "파티 프레임", "FOA 파티 프레임을 씁니다.", "party" },
		{ "레이드 프레임", "FOA 레이드 프레임을 씁니다.", "raid" },
		{ "경험치 바", "얇은 FOA 경험치 바를 씁니다.", "xp" },
		{ "네임플레이트", "FOA 네임플레이트를 씁니다.", "plates" },
		{ "가방", "분류별로 정리되는 FOA 가방을 씁니다.", "bags" },
		{ "캐릭터 창", "캐릭터 창을 FOA 스타일로 꾸밉니다.", "charSheet" },
		{ "진영 메뉴", "왼쪽 위 진영 문양 메뉴를 씁니다.", "launcher" },
		{ "튜토리얼 끄기", "노란 안내 상자 · 화살표 · 도움말 말풍선을 숨깁니다.", "hideTutorials" },
		{ "기본 창 / 글꼴 (실험)", "기본 창 껍데기와 글꼴 변경. 기본은 꺼짐.", "windows" },
	})
	local right = Column(p.edit, 330, "편의 기능", {
		{ "잡동사니 자동 판매", "상인 창을 열면 회색 아이템을 팝니다.", "sellJunk" },
		{ "자동 수리", "상인 창을 열면 장비를 수리합니다.", "autoRepair" },
		{ "길드 자금으로 수리", "가능하면 길드 자금을 먼저 씁니다.", "guildRepair" },
		{ "미터기", "피해량 / 치유량 미터기를 씁니다.", "meter" },
		{ "위협 수준", "미터기 왼쪽에 어그로(위협) 미터를 붙입니다.", "threat" },
		{ "보스 알림", "보스 패턴 타이머와 경고를 FOA 디자인으로.", "bossMod" },
		{ "NPC 역할 아이콘", "상인 · 수리 · 경매장 · 은행 · 여관 등 NPC 머리 위에 아이콘.", "npcIcons" },
	})

	p.reload = Button(p, "지금 다시 불러오기 (/reload)", 220, function() ReloadUI() end, true)
	p.reload:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -16)
	p.reload:Hide()

	local h3 = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
	h3:SetPoint("TOPLEFT", right, "BOTTOMLEFT", 0, -22)
	h3:SetText("명령어")
	local cmds = Ink:Text(p, F.sans, 11, C.soft, "LEFT")
	cmds:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -8)
	cmds:SetSpacing(4)
	cmds:SetWordWrap(true)
	cmds:SetWidth(280)
	cmds:SetText("/foa  설정 창\n/foa edit  편집 모드\n/foa test  테스트 모드\n/foa reset  위치 초기화\n/foa kb  단축키 설정\n/foa layout  배치 다시 적용")

	p:SetScript("OnShow", function() M:SyncButtons() end)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(p, "FOA UI")
		Settings.RegisterAddOnCategory(cat)
		self.category = cat
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(p)
	end
	self.panel = p
end

function M:OpenPanel()
	if self.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(self.panel)
	end
end

-------------------------------------------------------------------------------
-- ESC 게임 메뉴 안에 "FOA UI" 버튼 끼워 넣기 (엘브UI와 같은 방식)
--  블리자드 메뉴 함수(AddButton)로 넣으면 접속 종료·게임 종료 버튼이 오염될 수 있어서,
--  같은 모양의 버튼을 따로 만들고 메뉴가 배치를 마친 뒤 "매크로" 아래 자리를 벌려 끼운다.
local GAP = 35
local EXIT = {}
local function IsExit(text)
	if not next(EXIT) then
		for _, k in ipairs({ "LOGOUT", "LOG_OUT", "EXIT_GAME", "RETURN_TO_GAME" }) do
			if _G[k] then EXIT[_G[k]] = true end
		end
	end
	return text and EXIT[text]
end
local function Nudge(b, dy)
	local p, rel, rp, x, y = b:GetPoint(1)
	if p then b:SetPoint(p, rel, rp, x, (y or 0) + dy) end
end

function M:PlaceGameMenuButton()
	local gm, me = GameMenuFrame, self.gmButton
	if not (gm and me and gm.buttonPool) then return end
	local anchor, support
	for b in gm.buttonPool:EnumerateActive() do
		local text = b:GetText()
		if IsExit(text) then
			Nudge(b, -(GAP - 10))
		else
			Nudge(b, 10)
			if text == MACROS then anchor = b end
			if text == GAMEMENU_SUPPORT then support = b end
		end
	end
	anchor = anchor or support
	if not anchor then me:Hide() return end
	me:ClearAllPoints()
	me:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
	me:SetSize(anchor:GetWidth(), anchor:GetHeight())
	me:Show()
	gm:SetHeight(gm:GetHeight() + 10)
end

function M:BuildGameMenuButton()
	local gm = GameMenuFrame
	if not gm or self.gmButton or not gm.buttonPool then return end
	local ok, b = pcall(CreateFrame, "Button", "FOAGameMenuButton", gm, "MainMenuFrameButtonTemplate")
	if not ok or not b then return end
	b:SetSize(200, 35)
	-- 글자 대신 FOA 로고 묶음 (마크 + 도형 글자 + UI)
	b:SetText("")
	local brand = Ink:Brand(b, 12, C.text)
	brand:SetPoint("CENTER", 0, 0)
	b.brand = brand
	b:SetScript("OnClick", function()
		if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) end
		if InCombatLockdown() then
			print("|cffFFF468FOA|r 전투가 끝난 뒤에 설정 창을 열 수 있어요.")
			return
		end
		HideUIPanel(GameMenuFrame)
		M:OpenPanel()
	end)
	self.gmButton = b
	hooksecurefunc(gm, "Layout", function() M:PlaceGameMenuButton() end)
end

function M:Init()
	self:BuildPanel()
	self:BuildGameMenuButton()
end

function M:CombatStart()
	if self.editing then
		for _, o in pairs(self.overlays) do o:Hide() end
		if self.bar then self.bar:Hide() end
		self.pausedEdit = true
		self.editing = false
	end
end

function M:CombatEnd()
	if self.pausedEdit then
		self.pausedEdit = nil
		self:SetEdit(true)
	end
end

function M:PostLayout()
	if self.editing then
		for _, key in ipairs(Ink.moverOrder) do self:SyncOverlay(Ink.movers[key]) end
	end
end

SLASH_INKUI1 = "/foa"
SLASH_INKUI2 = "/ink"
SlashCmdList.INKUI = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "edit" or msg == "편집" then
		M:SetEdit(not M.editing)
	elseif msg == "test" or msg == "테스트" then
		M:SetTest(not M.testing)
	elseif msg == "reset" then
		M:ResetAll()
		print("|cffFFF468FOA|r 모든 위치를 기본값으로 되돌렸어요.")
	elseif msg == "debug" then
		print("|cffFFF468FOA|r 마지막 오라 오류: " .. tostring(Ink.auraErr or "없음"))
	elseif msg == "log" then
		if not Ink.blocked or #Ink.blocked == 0 then
			print("|cffFFF468FOA|r 막힌 동작 기록이 없어요.")
		else
			for _, line in ipairs(Ink.blocked) do print("|cffFFF468FOA|r " .. line) end
		end
		local errs = Ink.db and Ink.db.errors
		if errs and #errs > 0 then
			print("|cffFFF468FOA|r 최근 오류 (최대 8개):")
			for i = math.max(1, #errs - 7), #errs do print("|cffFF6B5EFOA|r " .. errs[i]) end
		else
			print("|cffFFF468FOA|r 기록된 오류가 없어요.")
		end
	elseif msg == "kb" or msg == "단축키" then
		Ink:OpenQuickKeybind()
	elseif msg == "layout" then
		Ink:Relayout()
		print("|cffFFF468FOA|r 배치를 다시 적용했어요.")
	else
		M:OpenPanel()
	end
end
