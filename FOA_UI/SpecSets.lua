-- FOA UI · 특성 묶음 (포에버 이중 특성)
--  주 특성 ↔ 보조 특성을 바꾸면 FOA 의 특성별 기능이 다 함께 따라간다.
--  · 행동단축바: 특성마다 따로 기억했다가 바꿀 때 불러온다 (게임이 스스로 바꿔 주면 FOA 는 손대지 않는다)
--  · 직접 고른 값(점수 기준 특성 · PvE/PvP 점수 · BIS 보기 · 특성 가이드 빌드)도 특성마다 따로
--  · 아이템 점수 · 가방 화살표 · BIS · 전리품 추천 · 특성 가이드를 새 특성 기준으로 다시

local ADDON, ns = ...
local Ink = ns.Ink
local M = Ink:Module("SpecSets")
ns.SpecSets = M

local GROUP_NAME = { "주 특성", "보조 특성" }

-- 지금 특성 묶음 번호 (1 = 주 · 2 = 보조). 이중 특성이 없으면 1
local function Group()
	local f = GetActiveSpecGroup or (C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup) or GetActiveTalentGroup
	if f then
		local ok, g = pcall(f)
		if ok and type(g) == "number" and g >= 1 then return g end
	end
	return 1
end
M.Group = Group

local function NumGroups()
	local f = GetNumSpecGroups or GetNumTalentGroups
	if f then
		local ok, n = pcall(f)
		if ok and type(n) == "number" then return n end
	end
	return 1
end

-------------------------------------------------------------------------------
-- 직접 고른 값: 특성 묶음마다 따로
-------------------------------------------------------------------------------
local PREF_KEYS = { "scoreSpec", "scoreMode", "bisSpec", "bisView", "talentPick", "talentMode", "talentBuild" }

local function Copy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = Copy(x) end
	return t
end

local function SavePrefs(g)
	local cdb = Ink.cdb
	if not cdb then return end
	cdb.groupPrefs = cdb.groupPrefs or {}
	local p = {}
	for _, k in ipairs(PREF_KEYS) do p[k] = Copy(cdb[k]) end
	cdb.groupPrefs[g] = p
end

-- 처음 가 보는 묶음이면 비워 둔다 → 모두 그 특성을 자동으로 따라간다
local function LoadPrefs(g)
	local cdb = Ink.cdb
	if not cdb then return end
	local p = cdb.groupPrefs and cdb.groupPrefs[g]
	for _, k in ipairs(PREF_KEYS) do cdb[k] = p and Copy(p[k]) or nil end
end

-------------------------------------------------------------------------------
-- 행동단축바 기억 · 불러오기
--  칸 1~120 (기본 · 오른쪽 · 형태 · 은신 바) + 145~180 (추가 바). 121~144 는 탈것 · 조종 바라 뺀다
-------------------------------------------------------------------------------
local SLOTS = {}
for i = 1, 120 do SLOTS[#SLOTS + 1] = i end
for i = 145, 180 do SLOTS[#SLOTS + 1] = i end

local function Read(slot)
	if not (GetActionInfo and HasAction and HasAction(slot)) then return nil end
	local kind, id, sub = GetActionInfo(slot)
	if not kind then return nil end
	local e = { kind, id, sub }
	if kind == "macro" and GetMacroInfo and id then e[4] = (GetMacroInfo(id)) end
	return e
end

local function Snapshot()
	local t = {}
	for _, s in ipairs(SLOTS) do t[s] = Read(s) end
	return t
end

local function Same(a, b)
	if not a or not b then return a == b end
	if a[1] ~= b[1] then return false end
	if a[1] == "macro" and (a[4] or b[4]) then return a[4] == b[4] end
	return a[2] == b[2]
end

local function DiffCount(x, y)
	local n = 0
	for _, s in ipairs(SLOTS) do
		if not Same(x[s], y[s]) then n = n + 1 end
	end
	return n
end

-- 커서에 올릴 수 있는 종류만 다룬다 (나머지 칸은 건드리지 않는다)
local PICK = {
	spell = function(e)
		local f = (C_Spell and C_Spell.PickupSpell) or PickupSpell
		if f and e[2] then f(e[2]) end
	end,
	macro = function(e)
		local idx = e[4] and GetMacroIndexByName and GetMacroIndexByName(e[4])
		if idx and idx > 0 then PickupMacro(idx) elseif e[2] then PickupMacro(e[2]) end
	end,
	item = function(e)
		local f = (C_Item and C_Item.PickupItem) or PickupItem
		if f and e[2] then f(e[2]) end
	end,
	equipmentset = function(e)
		if not C_EquipmentSet then return end
		local id = type(e[2]) == "number" and e[2] or (C_EquipmentSet.GetEquipmentSetID and C_EquipmentSet.GetEquipmentSetID(e[2]))
		if id then C_EquipmentSet.PickupEquipmentSet(id) end
	end,
	summonpet = function(e)
		if C_PetJournal and C_PetJournal.PickupPet and e[2] then C_PetJournal.PickupPet(e[2]) end
	end,
}

local function Handled(e) return e == nil or PICK[e[1]] ~= nil end

-- 바꿀 칸만 바꾼다 · 못 올린 주문(이 특성에서 안 배운 것)은 빈칸으로 두고 센다
function M:Restore(set)
	if InCombatLockdown() then self.pendingRestore = set; return end
	self.restoring = true
	local missed = 0
	for _, s in ipairs(SLOTS) do
		local want, cur = set[s], Read(s)
		if not Same(want, cur) and Handled(want) and Handled(cur) then
			if cur then PickupAction(s); ClearCursor() end
			if want then
				pcall(PICK[want[1]], want)
				if GetCursorInfo() then PlaceAction(s) else missed = missed + 1 end
				ClearCursor()
			end
		end
	end
	ClearCursor()
	C_Timer.After(0.6, function()
		M.restoring = nil
		M:SaveBars()
	end)
	return missed
end

function M:SaveBars()
	if self.restoring or self.switching or Ink.db.specBars == false then return end
	local g = Group()
	if g ~= self.group then return end -- 바뀌는 중 (게임이 단축바를 먼저 보낸 경우)
	Ink.cdb.specBars = Ink.cdb.specBars or {}
	Ink.cdb.specBars[g] = Snapshot()
end

-------------------------------------------------------------------------------
-- 특성이 바뀌면: 직접 고른 값 · 단축바 · 특성별 기능 모두
-------------------------------------------------------------------------------
local function Say(msg) print("|cffFFF468FOA|r " .. msg) end

-- 특성별 기능 새로 고침 (점수 · 가방 화살표 · BIS · 전리품 추천 · 특성 가이드 · 새 장비 알림)
function M:RefreshAll()
	local sc = ns.Score
	if sc then
		if sc.ResetSpec then pcall(sc.ResetSpec, sc) end
		if sc.Invalidate then pcall(sc.Invalidate, sc) end
	end
	local d = Ink.modules.Dungeon
	if d then
		d.dirty, d.rankKey = true, nil
		if d.sidebar and d.sidebar:IsShown() then pcall(d.PaintSidebar, d) end
		if d.bisPanel and d.bisPanel:IsShown() then pcall(d.PaintBis, d) end
	end
	local t = ns.Talents
	if t then
		t.resolved = nil
		pcall(t.PaintFrame, t)
	end
	local ga = Ink.modules.GearAdvisor
	if ga and ga.popup and ga.popup:IsShown() and ga.Paint then pcall(ga.Paint, ga) end
	local tr = Ink.modules.Training
	if tr and tr.Refresh then pcall(tr.Refresh, tr) end
end

function M:OnSwitch(old, new)
	self.switching = true
	-- 1) 직접 고른 값
	SavePrefs(old)
	LoadPrefs(new)
	-- 2) 특성별 기능: 게임이 새 특성 칸을 다 바꾼 뒤에 (바로 한 번 · 조금 뒤 한 번 더)
	self:RefreshAll()
	C_Timer.After(1.5, function() M:RefreshAll() end)
	-- 3) 단축바: 게임이 바꿔 줬는지 보고, 안 바꿨으면 FOA 가 불러온다
	C_Timer.After(1.0, function()
		M.group = new
		M.switching = nil
		local bars = Ink.cdb.specBars or {}
		Ink.cdb.specBars = bars
		local spec = ns.Score and select(2, ns.Score:Spec())
		local sn = spec and ns.Score.SPEC_NAME and ns.Score.SPEC_NAME[spec]
		local head = (GROUP_NAME[new] or "특성 " .. new) .. (sn and (" · " .. sn) or "")
		if Ink.db.specBars == false then
			Say(head .. " · 아이템 점수 · BIS · 특성 가이드도 함께 바꿨어요")
			return
		end
		local cur = Snapshot()
		local before = bars[old]
		if before and DiffCount(cur, before) >= 3 then
			-- 여러 칸이 한꺼번에 바뀌었다 = 게임이 특성마다 단축바를 따로 갖고 있다 → 그대로 두고 기억만
			bars[new] = cur
			Ink.cdb.specBarsNative = true
			Say(head .. " · 단축바 · 아이템 점수 · BIS · 특성 가이드도 함께 바꿨어요")
			return
		end
		-- 게임은 그대로 → 바꾸기 직전에 고친 칸까지 이전 특성에 저장하고, 새 특성 단축바를 불러온다
		bars[old] = cur
		if bars[new] then
			local missed = M:Restore(bars[new]) or 0
			Say(head .. " · 이 특성 단축바 · 아이템 점수 · BIS · 특성 가이드로 바꿨어요"
				.. (missed > 0 and string.format(" (이 특성에서 안 배운 주문 %d칸은 비워 둠)", missed) or ""))
		else
			bars[new] = Copy(cur)
			Say(head .. " · 이 특성 단축바를 새로 시작해요 — 지금 단축바에서 출발, 이제부터 바꾸는 건 이 특성에만 저장돼요")
		end
	end)
end

function M:Check()
	local g = Group()
	if not self.group then self.group = g return end
	if g ~= self.group and not self.switching then self:OnSwitch(self.group, g) end
end

function M:Init()
	local build = select(4, GetBuildInfo()) or 0
	if not (build >= 16001 and build < 20000) then return end -- 포에버 전용 (본섭은 게임이 특성마다 단축바를 나눠 둔다)
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
		"PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIONBAR_SLOT_CHANGED",
		"PLAYER_REGEN_ENABLED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	local saveQueued
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			C_Timer.After(2, function()
				M:Check()
				if NumGroups() > 1 or Ink.cdb.specBars then
					Ink.cdb.specBars = Ink.cdb.specBars or {}
					if not Ink.cdb.specBars[M.group] then M:SaveBars() end
				end
			end)
		elseif event == "ACTIONBAR_SLOT_CHANGED" then
			if M.restoring or M.switching or saveQueued then return end
			saveQueued = true
			C_Timer.After(1, function() saveQueued = nil; M:SaveBars() end)
		elseif event == "PLAYER_REGEN_ENABLED" then
			if M.pendingRestore then
				local set = M.pendingRestore
				M.pendingRestore = nil
				M:Restore(set)
			end
		else
			-- 특성 관련 이벤트: 묶음이 정말 바뀌었는지 조금 뒤에 확인
			C_Timer.After(0.3, function() M:Check() end)
		end
	end)
end
