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
--  접속 · 순간이동 직후엔 게임이 특성 정보를 아직 안 줘서 함수가 오류를 내거나 엉뚱한 값을 줄 수 있다.
--  예전엔 그때 1 로 쳐서 "특성이 바뀌었다"고 착각하고 다른 특성 단축바를 덮어써 스킬이 빠졌다 → 모르면 nil
local function Group()
	local f = GetActiveSpecGroup or (C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup) or GetActiveTalentGroup
	if not f then return 1 end
	local ok, g = pcall(f)
	if ok and type(g) == "number" and g >= 1 and g <= 2 then return g end
	return nil
end
M.Group = function() return Group() or M.group or 1 end

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

local INSLOT = {}
for _, s in ipairs(SLOTS) do INSLOT[s] = true end

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

local nameCache = {}
local function SpellName(id)
	if type(id) ~= "number" then return nil end
	local n = nameCache[id]
	if n == nil then
		local ok, v = pcall(function()
			if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
			return GetSpellInfo and (GetSpellInfo(id)) or nil
		end)
		n = (ok and type(v) == "string" and v ~= "") and v or false
		nameCache[id] = n
	end
	return n or nil
end

-- 같은 칸 내용인가 · 주문은 이름이 같으면 같은 걸로 (새 등급을 배우면 번호만 바뀐다)
--  예전엔 번호만 봐서, 특성을 바꿀 때 새 등급 주문을 지우고 예전 등급 번호로 다시 올리려다 못 올리면 빈칸이 됐다
local function Same(a, b)
	if not a or not b then return a == b end
	if a[1] ~= b[1] then return false end
	if a[1] == "macro" and (a[4] or b[4]) then return a[4] == b[4] end
	if a[2] == b[2] then return true end
	if a[1] == "spell" then
		local na = SpellName(a[2])
		return na ~= nil and na == SpellName(b[2])
	end
	return false
end

-- 특성을 바꾼 직후 단축바가 기억(이전 특성)과 어떻게 다른가
--  changed = 다른 것으로 바뀐 칸 (게임이 특성마다 단축바를 따로 갖고 있다는 증거)
--  removed = 비워진 칸 (게임이 새 특성에서 못 쓰는 특성 주문을 뺀 것 · 따로 갖고 있다는 증거가 아니다)
local function Classify(cur, before)
	local changed, removed = 0, 0
	for _, s in ipairs(SLOTS) do
		local was, now = before[s], cur[s]
		if not Same(was, now) then
			if now == nil then removed = removed + 1 else changed = changed + 1 end
		end
	end
	return changed, removed
end
M.Classify = Classify

-- 커서에 올릴 수 있는 종류만 다룬다 (나머지 칸은 건드리지 않는다)
local PICK = {
	spell = function(e)
		local f = (C_Spell and C_Spell.PickupSpell) or PickupSpell
		if f and e[2] then pcall(f, e[2]) end
		-- 번호로 못 올리면 이름으로 (등급이 바뀐 주문 → 지금 아는 가장 높은 등급)
		if not GetCursorInfo() and PickupSpell then
			local n = SpellName(e[2])
			if n then PickupSpell(n) end
		end
	end,
	macro = function(e)
		local idx = e[4] and GetMacroIndexByName and GetMacroIndexByName(e[4])
		if idx and idx > 0 then PickupMacro(idx) elseif e[2] and not e[4] then PickupMacro(e[2]) end
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

-- 바꿀 칸만 바꾼다
--  올릴 것을 먼저 커서에 올리고, 올라왔을 때만 그 칸에 놓는다 (원래 있던 건 커서로 밀려났다가 버려진다)
--  못 올린 것(이 특성에서 안 배운 주문 · 지운 매크로)은 지금 칸을 그대로 둔다
--  (예전엔 지금 칸을 먼저 지우고 나서 올려 봐서, 못 올리면 스킬이 빈칸으로 사라졌다)
function M:Restore(set)
	if InCombatLockdown() then self.pendingRestore = set; return 0 end
	self.restoring = true
	local missed = 0
	ClearCursor()
	for _, s in ipairs(SLOTS) do
		local want, cur = set[s], Read(s)
		if not Same(want, cur) and Handled(want) and Handled(cur) then
			if want then
				pcall(PICK[want[1]], want)
				if GetCursorInfo() then
					PlaceAction(s)
				else
					missed = missed + 1
				end
				ClearCursor()
			else
				-- 이 특성 단축바에선 빈칸
				PickupAction(s)
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
	if self.restoring or self.switching or self.confirming or Ink.db.specBars == false then return end
	local g = Group()
	if not g or g ~= self.group then return end -- 바뀌는 중 (게임이 단축바를 먼저 보낸 경우) · 아직 모름
	Ink.cdb.specBars = Ink.cdb.specBars or {}
	Ink.cdb.specBars[g] = Snapshot()
end

-------------------------------------------------------------------------------
-- 단축바에서 빠진 칸 기록 (원인 추적용 · 저장 파일 FOA_UI.lua 의 barLog, 최근 40개)
--  who: drag = 내가 끌어서 뺌(커서에 들려 있음) · talent = 특성을 바꾸거나 배우는 중 게임이 뺌
--       restore = 특성 단축바 불러오기 · game = 그 밖 (게임 · 다른 애드온) → 채팅에 한 줄 알림
-------------------------------------------------------------------------------
local live, liveReady = {}, false
local talentAt = -100
local pendingLost, lostQueued = {}, nil

local function SlotName(e)
	if not e then return "?" end
	if e[1] == "spell" then return SpellName(e[2]) or ("주문 " .. tostring(e[2])) end
	if e[1] == "macro" then return e[4] or ("매크로 " .. tostring(e[2])) end
	if e[1] == "item" then
		local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(e[2])) or (GetItemInfo and GetItemInfo(e[2]))
		return n or ("아이템 " .. tostring(e[2]))
	end
	return e[1] .. " " .. tostring(e[2])
end

local function Log(entry)
	local cdb = Ink.cdb
	if not cdb then return end
	local L = cdb.barLog
	if type(L) ~= "table" then L = {}; cdb.barLog = L end
	L[#L + 1] = entry
	while #L > 40 do table.remove(L, 1) end
end

local function Stamp() return date and date("%m-%d %H:%M:%S") or "" end

local function Who()
	if M.restoring then return "restore" end
	if M.switching or M.confirming or GetTime() - talentAt < 4 then return "talent" end
	if GetCursorInfo and GetCursorInfo() then return "drag" end
	return "game"
end

function M:OnSlotChanged(slot)
	if not liveReady then return end
	if type(slot) ~= "number" or slot < 1 then
		local now, lost = Snapshot(), 0
		for _, s in ipairs(SLOTS) do if live[s] and not now[s] then lost = lost + 1 end end
		if lost > 0 then Log({ t = Stamp(), s = 0, n = lost .. "칸", who = Who(), g = self.group }) end
		live = now
		return
	end
	if not INSLOT[slot] then return end
	local was, now = live[slot], Read(slot)
	live[slot] = now
	if was and not now then
		local who = Who()
		local entry = { t = Stamp(), s = slot, k = was[1], id = was[2], n = SlotName(was), who = who,
			c = (InCombatLockdown and InCombatLockdown()) and 1 or nil, g = self.group }
		Log(entry)
		if who == "game" then
			-- 특성을 바꿀 때 게임이 특성 주문을 먼저 빼고 특성 이벤트가 뒤에 올 수도 있어서, 잠깐 뒤에 다시 본다
			--  그 사이 특성이 바뀌었으면 정상(talent) · 아니면 한 번에 모아서 채팅에 한 줄
			pendingLost[#pendingLost + 1] = entry
			if not lostQueued then
				lostQueued = true
				C_Timer.After(2.5, function()
					lostQueued = nil
					local list = pendingLost
					pendingLost = {}
					local names = {}
					for _, e in ipairs(list) do
						if M.switching or M.confirming or GetTime() - talentAt < 6 then e.who = "talent"
						else names[#names + 1] = string.format("|cffF3F2EE%s|r(%d번)", e.n, e.s) end
					end
					if #names > 0 then
						print("|cffFFF468FOA|r 단축바에서 " .. table.concat(names, ", ") .. " 이(가) 빠졌어요 · 원인을 기록해 뒀어요")
					end
				end)
			end
		end
	end
end

function M:TrackStart()
	live = Snapshot()
	liveReady = true
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
		-- 그 사이 다시 읽었더니 새 특성이 아니면(잘못 읽었거나 되돌아감) 아무것도 바꾸지 않는다
		if Group() ~= new then
			M.switching = nil
			LoadPrefs(old)
			M:RefreshAll()
			return
		end
		M.group = new
		M.switching = nil
		local bars = Ink.cdb.specBars or {}
		Ink.cdb.specBars = bars
		local spec = ns.Score and select(2, ns.Score:Spec())
		local sn = spec and ns.Score.SPEC_NAME and ns.Score.SPEC_NAME[spec]
		local head = (GROUP_NAME[new] or "특성 " .. new) .. (sn and (" · " .. sn) or "")
		if Ink.db.specBars == false then
			Say(head .. " · 아이템 점수 · BIS · 특성 가이드도 함께 바꿨어요")
			M:TrackStart()
			return
		end
		local cur = Snapshot()
		local before = bars[old]
		local changed = before and Classify(cur, before) or 0
		if changed >= 3 then
			-- 여러 칸이 다른 것으로 바뀌었다 = 게임이 특성마다 단축바를 따로 갖고 있다 → 그대로 두고 기억만
			--  (칸이 비기만 한 건 게임이 새 특성에서 못 쓰는 특성 주문을 뺀 것이라 여기에 넣지 않는다.
			--   예전엔 그것도 "게임이 바꿔 줬다"로 쳐서, 새 특성 단축바를 불러오지 않고 빈칸 난 단축바를 새 특성 것으로 저장했다)
			bars[new] = cur
			Ink.cdb.specBarsNative = true
			Say(head .. " · 단축바 · 아이템 점수 · BIS · 특성 가이드도 함께 바꿨어요")
			M:TrackStart()
			return
		end
		-- 게임은 그대로 → 바꾸기 직전에 고친 칸까지 이전 특성에 저장 (게임이 방금 뺀 특성 주문은 이전 특성 기억에 남긴다)
		local keep = Copy(cur)
		if before then
			for _, s in ipairs(SLOTS) do
				if keep[s] == nil and before[s] then keep[s] = Copy(before[s]) end
			end
		end
		bars[old] = keep
		if bars[new] then
			local missed = M:Restore(bars[new]) or 0
			Say(head .. " · 이 특성 단축바 · 아이템 점수 · BIS · 특성 가이드로 바꿨어요"
				.. (missed > 0 and string.format(" (이 특성에서 못 쓰는 %d칸은 그대로 뒀어요)", missed) or ""))
		else
			bars[new] = Copy(cur)
			Say(head .. " · 이 특성 단축바를 새로 시작해요 — 지금 단축바에서 출발, 이제부터 바꾸는 건 이 특성에만 저장돼요")
		end
		C_Timer.After(0.8, function() M:TrackStart() end)
	end)
end

-- 특성 묶음이 정말 바뀌었나: 접속 · 순간이동 직후 몇 초는 기다리고, 0.5초 간격으로 세 번 같은 값이 나와야 바뀐 걸로
function M:Check()
	if self.switching or self.confirming then return end
	local now = GetTime()
	if now < (self.settleUntil or 0) then
		if not self.settleQueued then
			self.settleQueued = true
			C_Timer.After(self.settleUntil - now + 0.1, function() M.settleQueued = nil; M:Check() end)
		end
		return
	end
	local g = Group()
	if not g then return end
	if not self.group then self.group = g return end
	if g == self.group then return end
	talentAt = now
	self.confirming = true
	local n = 0
	local function step()
		if Group() ~= g then M.confirming = nil return end
		n = n + 1
		if n < 2 then C_Timer.After(0.5, step) return end
		M.confirming = nil
		if g ~= M.group and not M.switching then M:OnSwitch(M.group, g) end
	end
	C_Timer.After(0.5, step)
end

function M:Init()
	local build = select(4, GetBuildInfo()) or 0
	if not (build >= 16001 and build < 20000) then return end -- 포에버 전용 (본섭은 게임이 특성마다 단축바를 나눠 둔다)
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
		"PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIONBAR_SLOT_CHANGED",
		"PLAYER_REGEN_ENABLED", "PLAYER_LEAVING_WORLD" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	local saveQueued
	ev:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_ENTERING_WORLD" then
			-- 접속 · 순간이동 직후엔 특성 · 단축바 정보가 늦게 온다 → 잠깐 기다렸다가
			M.settleUntil = GetTime() + 4
			C_Timer.After(4.2, function()
				M:Check()
				local g = Group()
				if g and M.group == g and (NumGroups() > 1 or Ink.cdb.specBars) then
					Ink.cdb.specBars = Ink.cdb.specBars or {}
					if not Ink.cdb.specBars[g] then M:SaveBars() end
				end
				if not M.switching and not M.confirming then M:TrackStart() end
			end)
		elseif event == "PLAYER_LEAVING_WORLD" then
			liveReady = false
		elseif event == "ACTIONBAR_SLOT_CHANGED" then
			pcall(M.OnSlotChanged, M, arg1)
			if M.restoring or M.switching or M.confirming or saveQueued then return end
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
			talentAt = GetTime()
			C_Timer.After(0.3, function() M:Check() end)
		end
	end)
end
