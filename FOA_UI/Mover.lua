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

local function Start(f)
	local s = S[f]
	if not s or not On() or Blocked(f) then return end
	if not f:IsMovable() then f:SetMovable(true) end
	s.moving = true
	f:StartMoving()
end

local function Stop(f)
	local s = S[f]
	if not (s and s.moving) then return end
	s.moving = nil
	f:StopMovingOrSizing()
	-- 게임이 창 자리를 따로 저장(layout-local)하지 않게: 자리 기억은 FOA 가 한다
	if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end
	local l, t, e = f:GetLeft(), f:GetTop(), f:GetEffectiveScale()
	if l and t and e then
		Ink.db.winPos = Ink.db.winPos or {}
		Ink.db.winPos[s.name] = { math.floor(l * e + 0.5), math.floor(t * e + 0.5) }
	end
	Place(f)
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
	hooksecurefunc(f, "SetPoint", function(self) if not (S[self] and S[self].busy) and self:IsShown() then Place(self) end end)
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
