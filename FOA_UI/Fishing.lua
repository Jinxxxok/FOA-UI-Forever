-- FOA UI · 원터치 낚시 (낚싯대를 들었을 때만 켜진다)
--  · FOA 낚시 단축키 (기본 F · 설정 → 가방 → 편의에서 바꾸기): 찌가 없으면 던지고, 찌가 떠 있으면 낚아챈다
--    키보드 키나 마우스 가운데 · 4 · 5 버튼 · 낚싯대를 들었을 때만 그 키가 낚시로 바뀌고, 내려놓으면 원래 기능으로
--    단축키 저장 방식이 "이 캐릭터만"이면 캐릭터마다 따로 기억
--  · 단축키를 지운 경우에만 오른쪽 두 번 클릭 (오른쪽 버튼으로 시점을 돌리는 사람이 많아서 기본은 단축키)
--  · 게임 메뉴 → 단축키 → FOA UI → 원터치 낚시 도 같은 동작
--  찌 낚아채기는 블리자드 "상호작용 대상" 기능을 쓴다 (찌가 떠 있으면 찌가 상호작용 대상이 된다).
--  전투 중에는 단축키를 바꿀 수 없어서 쉰다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Fishing")
local safe = Ink.safe

BINDING_HEADER_FOA = "FOA UI"
_G["BINDING_NAME_CLICK FOAFishButton:LeftButton"] = "원터치 낚시 (던지기 · 낚아채기)"

local FISH_IDS = { 7620, 7731, 7732, 18248, 33095, 131474 }
local DOUBLE = 0.4 -- 두 번 클릭으로 보는 간격 (초)

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, n = pcall(C_Spell.GetSpellName, id)
		if ok and n then return n end
	end
	if GetSpellInfo then
		local ok, n = pcall(GetSpellInfo, id)
		if ok and n then return n end
	end
end

local function FishName()
	for _, id in ipairs(FISH_IDS) do
		local n = SpellName(id)
		if n then return n end
	end
	return "낚시"
end

local function IsFishSpell(spellID)
	for _, id in ipairs(FISH_IDS) do if id == spellID then return true end end
	local n = spellID and SpellName(spellID)
	return n ~= nil and n == M.fishName
end

local function HasPole()
	local id = GetInventoryItemID and GetInventoryItemID("player", 16)
	if not id then return false end
	local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if not info then return false end
	local _, _, _, _, _, classID, subID = info(id)
	return classID == 2 and subID == 20 -- 무기 · 낚싯대
end

-------------------------------------------------------------------------------
-- 단축키 바꿔 끼우기
-------------------------------------------------------------------------------
-- FOA 낚시 단축키 (캐릭터 전용 단축키를 쓰는 캐릭터는 캐릭터마다 · 아니면 계정 공용)
--  false = 이 캐릭터는 일부러 비워 둠
--  저장 값: nil = 기본(F) · false = 지움 (그때만 오른쪽 두 번 클릭)
M.DEFAULT_KEY = "F"
function M:GetKey()
	local cdb = Ink.cdb
	if cdb and Ink.CharBindings and Ink.CharBindings() and cdb.fishKey ~= nil then
		return cdb.fishKey or nil
	end
	local k = Ink.db.fishKey
	if k == nil then return M.DEFAULT_KEY end
	return k or nil
end

function M:SetKey(k)
	if k == "BUTTON1" or k == "BUTTON2" then return end -- 왼쪽 · 오른쪽 클릭 한 번은 막는다 (이동 · 대상 잡기가 안 됨)
	local cdb = Ink.cdb
	if cdb and Ink.CharBindings and Ink.CharBindings() then cdb.fishKey = k or false
	else Ink.db.fishKey = k or false end
	self:ApplyKey()
end

-- 단축키: 낚싯대를 들었을 때 FOA 낚시 키 = 던지기, 찌가 떠 있는 동안은 "상호작용"(낚아채기)
--  게임 메뉴에서 지정한 원터치 낚시 키는 원래 던지기라서 찌가 떠 있는 동안만 바꾼다
function M:ApplyKey()
	if InCombatLockdown() then self.keyPending = true return end
	self.keyPending = nil
	ClearOverrideBindings(self.keyOwner)
	local k1, k2 = GetBindingKey("CLICK FOAFishButton:LeftButton")
	self.keySig = tostring(k1) .. "|" .. tostring(k2)
	if not self.active then return end
	local own = self:GetKey()
	if own then
		if self.fishing then SetOverrideBinding(self.keyOwner, true, own, "INTERACTTARGET")
		else SetOverrideBindingClick(self.keyOwner, true, own, "FOAFishButton", "LeftButton") end
	end
	if not self.fishing then return end
	for _, k in ipairs({ k1, k2 }) do
		if k and k ~= own then SetOverrideBinding(self.keyOwner, true, k, "INTERACTTARGET") end
	end
end

-- 키 이름 (한글: "마우스 가운데 버튼" 등)
function M.KeyLabel(k)
	if not k then return nil end
	local ok, t = pcall(GetBindingText, k, "KEY_")
	if not (ok and t and t ~= "") then ok, t = pcall(GetBindingText, k) end
	return (ok and t and t ~= "") and t or k
end

-- 오른쪽 클릭 한 번 → 잠깐 동안 다음 오른쪽 클릭을 낚시 동작으로 바꿔 둔다
function M:OnWorldDown(button)
	if button ~= "RightButton" or not self.active or InCombatLockdown() then return end
	-- 단축키가 있으면 그 키만 (오른쪽 버튼은 시점 돌리기에 그대로)
	if self:GetKey() then return end
	local now = GetTime()
	if self.armedUntil and now < self.armedUntil then return end
	self.armedUntil = now + DOUBLE
	if self.fishing then
		SetOverrideBinding(self.mouseOwner, true, "BUTTON2", "INTERACTTARGET")
	else
		SetOverrideBindingClick(self.mouseOwner, true, "BUTTON2", "FOAFishButton", "LeftButton")
	end
	local token = now
	self.armToken = token
	C_Timer.After(DOUBLE, function()
		if M.armToken ~= token then return end
		M.armedUntil = nil
		if not InCombatLockdown() then ClearOverrideBindings(M.mouseOwner) end
	end)
end

-------------------------------------------------------------------------------
-- 켜기 · 끄기 (낚싯대를 들었는지)
-------------------------------------------------------------------------------
function M:Refresh()
	if InCombatLockdown() then self.refreshPending = true return end
	self.refreshPending = nil
	local want = Ink.db.oneTouchFish ~= false and HasPole()
	if want == self.active then return self:ApplyKey() end
	self.active = want
	self.fishName = FishName()
	self.btn:SetAttribute("spell", self.fishName)
	if want then
		-- 찌를 상호작용 대상으로 잡으려면 "상호작용 대상" 기능이 켜져 있어야 한다
		local cur = GetCVar and GetCVar("SoftTargetInteract")
		if cur and cur ~= "3" then
			self.softBackup = cur
			safe(SetCVar, "SoftTargetInteract", "3")
		end
		if not self.told then
			self.told = true
			local parts = {}
			local own = self:GetKey()
			if own then parts[#parts + 1] = M.KeyLabel(own) else parts[#parts + 1] = "오른쪽 두 번 클릭" end
			local k = GetBindingKey("CLICK FOAFishButton:LeftButton")
			if k and k ~= own then parts[#parts + 1] = M.KeyLabel(k) end
			if #parts > 0 then
				print("|T" .. Ink.tex.logo .. ":14:14|t |cffFFF468FOA|r 원터치 낚시 켜짐  ·  " .. table.concat(parts, " / ") .. "  →  던지기 · 낚아채기" ..
					"  |cff8E939B(바꾸기: 설정 → 가방 → 편의)|r")
			else
				print("|T" .. Ink.tex.logo .. ":14:14|t |cffFFF468FOA|r 원터치 낚시: 설정 → 가방 → 편의 에서 단축키를 정해 주세요")
			end
		end
	else
		ClearOverrideBindings(self.mouseOwner)
		self.armedUntil, self.fishing = nil, nil
		if self.softBackup then
			safe(SetCVar, "SoftTargetInteract", self.softBackup)
			self.softBackup = nil
		end
	end
	self:ApplyKey()
end

function M:Init()
	self.fishName = FishName()
	local b = CreateFrame("Button", "FOAFishButton", UIParent, "SecureActionButtonTemplate")
	b:SetSize(1, 1)
	b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("useOnKeyDown", false)
	b:SetAttribute("type", "spell")
	b:SetAttribute("spell", self.fishName)
	self.btn = b
	self.mouseOwner = CreateFrame("Frame")
	self.keyOwner = CreateFrame("Frame")

	if WorldFrame and WorldFrame.HookScript then
		WorldFrame:HookScript("OnMouseDown", function(_, button) pcall(M.OnWorldDown, M, button) end)
	end

	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
		"UPDATE_BINDINGS", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	e:SetScript("OnEvent", function(_, ev, unit, _, spellID)
		if ev == "UNIT_SPELLCAST_CHANNEL_START" then
			if unit == "player" and M.active and IsFishSpell(spellID) then
				M.fishing = true
				M:ApplyKey()
			end
		elseif ev == "UNIT_SPELLCAST_CHANNEL_STOP" then
			if unit == "player" and M.fishing then
				M.fishing = nil
				M:ApplyKey()
			end
		elseif ev == "PLAYER_REGEN_DISABLED" then
			-- 전투에 들어가는 순간(아직 바꿀 수 있는 마지막 때): 바꿔 둔 오른쪽 클릭 · 단축키를 되돌린다
			M.armedUntil, M.armToken = nil, nil
			ClearOverrideBindings(M.mouseOwner)
			ClearOverrideBindings(M.keyOwner)
		elseif ev == "PLAYER_REGEN_ENABLED" then
			ClearOverrideBindings(M.mouseOwner)
			-- 전투 시작 때 걷어 낸 낚시 단축키를 다시 (낚싯대를 들고 있으면)
			if M.refreshPending then M:Refresh() else M:ApplyKey() end
		elseif ev == "UPDATE_BINDINGS" then
			-- 단축키 설정이 바뀐 때만 (덮어쓰기를 할 때도 이 알림이 와서 같은 키면 넘긴다)
			local k1, k2 = GetBindingKey("CLICK FOAFishButton:LeftButton")
			if tostring(k1) .. "|" .. tostring(k2) ~= M.keySig then M:ApplyKey() end
		else
			M:Refresh()
		end
	end)
	self:Refresh()
end
