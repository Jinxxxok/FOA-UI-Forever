-- FOA UI · 기본 창 옮기기 (블리즈무브처럼)
--  · 블리자드 창(특성 · 마법책 · 은행 · 상인 · 우편 · 경매장 · 전문기술 · 친구 · 파티 찾기 · 업적 · 수집품 …)의
--    빈 곳이나 제목 줄을 끌면 옮겨지고, 다음에 열 때도 그 자리
--  · 제목 줄 Shift+오른쪽 클릭 = 원래 자리 (다시 열면 적용)
--  · 블리자드 창 관리자가 왼쪽 기본 자리에 다시 붙이면 바로 내 자리로 되돌린다 (지도 · 캐릭터 창과 같은 방식)
--  · 블리자드 창에는 값을 쓰지 않는다 (상태는 바깥 표 S) · 보호된 창은 전투 중에 건드리지 않는다
--  지도(Map.lua) · 캐릭터 창(Character.lua)은 따로 옮긴다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Mover")

-- 옮길 창 (없는 이름은 건너뛴다 · 나중에 불러오는 창은 ADDON_LOADED 때 다시 찾는다)
local NAMES = {
	-- 특성 · 마법책
	"PlayerTalentFrame", "TalentFrame", "PlayerSpellsFrame", "ClassTalentFrame", "SpellBookFrame", "ProfessionsBookFrame",
	-- 마을 창
	"BankFrame", "GuildBankFrame", "MerchantFrame", "GossipFrame", "QuestFrame", "QuestLogFrame", "QuestLogDetailFrame",
	"MailFrame", "OpenMailFrame", "TradeFrame", "TaxiFrame", "FlightMapFrame", "ClassTrainerFrame", "StableFrame", "PetStableFrame",
	"TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "ItemTextFrame", "BlackMarketFrame", "ItemSocketingFrame", "ItemUpgradeFrame",
	-- 경매장 · 전문기술
	"AuctionHouseFrame", "AuctionFrame", "ProfessionsFrame", "TradeSkillFrame", "CraftFrame", "ProfessionsCustomerOrdersFrame",
	-- 소셜 · 파티
	"FriendsFrame", "CommunitiesFrame", "GuildFrame", "PVEFrame", "LFGParentFrame", "PVPUIFrame", "ChannelFrame", "InspectFrame",
	-- 모음 · 기타
	"AchievementFrame", "CollectionsJournal", "WardrobeFrame", "EncounterJournal", "DressUpFrame", "MacroFrame",
	"CalendarFrame", "TimeManagerFrame", "HelpFrame", "SettingsPanel", "AddonList", "ArchaeologyFrame",
}

local S = setmetatable({}, { __mode = "k" })   -- 프레임 → { name, handle, busy, moving }
local pending = {}                              -- 전투 중이라 못 붙인 창

-------------------------------------------------------------------------------
-- 끌기: 게임의 StartMoving 대신 커서를 직접 따라가게 한다 (캐릭터 창 · 지도도 이걸 쓴다)
--  StartMoving 으로 옮기던 때, 제목 줄을 잡으면 창이 화면 맨 위로 튀고 안 움직이는 일이 있었다
--  (블리자드 창 관리자가 끄는 중에 창을 다시 붙이면 게임의 끌기가 끊기고, 다시 붙인 자리를 FOA 가 되돌리며 엉킨다)
--  → 잡은 순간 커서와 창 왼쪽 위의 거리를 기억해 두고, 매 프레임 그 거리대로 TOPLEFT 를 다시 붙인다
--    끄는 중에 다른 코드가 창을 옮겨도 다음 프레임에 커서 자리로 돌아온다 · 왼쪽 단추를 떼면 끝
-------------------------------------------------------------------------------
local drag = {}
local drv = CreateFrame("Frame")
drv:Hide()
local function DragApply()
	local f = drag.f
	if not f or drag.busy then return end
	if f:IsProtected() and InCombatLockdown() then return end
	local cx, cy = GetCursorPosition()
	if not (cx and cy) then return end
	drag.busy = true
	pcall(function()
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / drag.e + drag.dx, cy / drag.e + drag.dy)
		if drag.w and drag.w > 0 and drag.h and drag.h > 0 then f:SetSize(drag.w, drag.h) end
	end)
	drag.busy = false
end
M.DragApply = DragApply
-- 끌기 시작 (onStop(f) = 끝났을 때 자리 저장)
function M.DragStart(f, onStop)
	if drag.f then M.DragStop() end
	if not f or (f:IsProtected() and InCombatLockdown()) then return false end
	local e, l, t = f:GetEffectiveScale(), f:GetLeft(), f:GetTop()
	local cx, cy = GetCursorPosition()
	if not (e and e > 0 and l and t and cx and cy) then return false end
	-- 블리자드가 원래 끌기(StartMoving)를 걸어 둔 창이면 그건 멈추고 FOA 끌기만
	if f.StopMovingOrSizing then pcall(f.StopMovingOrSizing, f) end
	local w, h = f:GetSize()
	drag.f, drag.e, drag.dx, drag.dy, drag.w, drag.h, drag.onStop = f, e, l - cx / e, t - cy / e, w, h, onStop
	drv:Show()
	return true
end
function M.DragStop()
	local f, onStop = drag.f, drag.onStop
	if not f then return end
	DragApply()
	drag.f, drag.onStop = nil, nil
	drv:Hide()
	if onStop then pcall(onStop, f) end
end
-- 지금 이 창을 끄는 중인가 (끄는 중에 FOA 가 창을 다시 붙이는 중인가)
function M.Dragging(f) return f ~= nil and drag.f == f, drag.busy end
drv:SetScript("OnUpdate", function()
	if not drag.f then drv:Hide() return end
	if not IsMouseButtonDown("LeftButton") or not drag.f:IsShown() then M.DragStop() return end
	DragApply()
end)

local function On() return Ink.db and Ink.db.moveWindows ~= false end
local function Blocked(f) return f:IsProtected() and InCombatLockdown() end
local function Saved(name) return Ink.db.winPos and Ink.db.winPos[name] end

-- 저장한 자리로 (화면 기준 좌표 · 창 배율이 바뀌어도 같은 자리)
local function Place(f)
	local s = S[f]
	local p = s and On() and Saved(s.name)
	if not p or s.busy or s.moving or Blocked(f) then return end
	local e = f:GetEffectiveScale()
	if not e or e <= 0 then return end
	s.busy = true
	pcall(function()
		local w, h = f:GetSize()
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1] / e, p[2] / e)
		-- 두 점으로 크기가 정해지던 창은 한 점으로 바꾸면 크기가 0이 될 수 있어서 지금 크기를 그대로
		if w and h and w > 0 and h > 0 then f:SetSize(w, h) end
	end)
	s.busy = false
end
M.Place = Place

local function Done(f)
	local s = S[f]
	if not s then return end
	s.moving = nil
	-- 게임이 창 자리를 따로 저장(layout-local)하지 않게: 자리 기억은 FOA 가 한다
	if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end
	local l, t, e = f:GetLeft(), f:GetTop(), f:GetEffectiveScale()
	if l and t and e then
		Ink.db.winPos = Ink.db.winPos or {}
		Ink.db.winPos[s.name] = { math.floor(l * e + 0.5), math.floor(t * e + 0.5) }
	end
	Place(f)
end

local function Start(f)
	local s = S[f]
	if not s or not On() or Blocked(f) or s.moving then return end
	if M.DragStart(f, Done) then s.moving = true end
end

local function Stop(f)
	local s = S[f]
	if not (s and s.moving) then return end
	if M.Dragging(f) then M.DragStop() else Done(f) end
end

local function Forget(f)
	local s = S[f]
	if not (s and Ink.db.winPos and Ink.db.winPos[s.name]) then return end
	Ink.db.winPos[s.name] = nil
	print("|cffFFF468FOA|r 창 위치를 지웠어요 · 다시 열면 원래 자리로 돌아가요")
end

-- 제목 줄 손잡이: 창 안의 단추를 가리지 않게 위쪽 얇은 띠만 (왼쪽 초상화 · 오른쪽 닫기 단추는 비움)
local function Handle(f)
	local h = CreateFrame("Frame", nil, f)
	h:SetPoint("TOPLEFT", f, "TOPLEFT", 58, -1)
	h:SetPoint("TOPRIGHT", f, "TOPRIGHT", -58, -1)
	h:SetHeight(20)
	h:SetFrameLevel(f:GetFrameLevel() + 20)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", function() Start(f) end)
	h:SetScript("OnDragStop", function() Stop(f) end)
	h:SetScript("OnHide", function() Stop(f) end)
	h:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and IsShiftKeyDown() then Forget(f) end
	end)
	return h
end

local function Attach(f, name)
	if not f or S[f] or not f.GetObjectType then return end
	if f.IsForbidden and f:IsForbidden() then return end
	if Blocked(f) then pending[f] = name return end
	local s = { name = name }
	S[f] = s
	pcall(function()
		f:SetMovable(true)
		f:SetClampedToScreen(true)
		-- 창 빈 곳 끌기 (블리즈무브와 같은 느낌) · 원래 끌기 동작이 있으면 그 뒤에 이어 붙는다
		if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
		f:HookScript("OnDragStart", function(self) Start(self) end)
		f:HookScript("OnDragStop", function(self) Stop(self) end)
	end)
	s.handle = Handle(f)
	f:HookScript("OnShow", function(self) Place(self); C_Timer.After(0, function() Place(self) end) end)
	f:HookScript("OnHide", function(self) Stop(self) end)
	hooksecurefunc(f, "SetPoint", function(self)
		local dragging, busy = M.Dragging(self)
		if dragging then if not busy then DragApply() end return end
		if not (S[self] and S[self].busy) and self:IsShown() then Place(self) end
	end)
	if f:IsShown() then Place(f) end
end

function M:Scan()
	if not On() then return end
	for _, name in ipairs(NAMES) do
		local f = _G[name]
		if type(f) == "table" and f.GetObjectType and not S[f] then Attach(f, name) end
	end
end

function M:Init()
	local e = CreateFrame("Frame")
	e:RegisterEvent("PLAYER_LOGIN")
	e:RegisterEvent("ADDON_LOADED")
	e:RegisterEvent("PLAYER_REGEN_ENABLED")
	e:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			for f, name in pairs(pending) do pending[f] = nil; Attach(f, name) end
			return
		end
		-- 블리자드 창이 막 만들어진 직후라 한 박자 뒤에
		C_Timer.After(0, function() pcall(M.Scan, M) end)
	end)
	pcall(self.Scan, self)
end

-- 설정에서 껐다 켤 때
function M:Apply()
	if On() then self:Scan() end
	for f in pairs(S) do
		if S[f].handle then S[f].handle:SetShown(On()) end
	end
end
