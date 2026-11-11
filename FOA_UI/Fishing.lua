-- FOA UI · 원터치 낚시 (낚싯대를 들었을 때만 켜진다)
--  · 오른쪽 두 번 클릭: 찌가 없으면 던지고, 찌가 떠 있으면 낚아챈다
--  · 단축키 (게임 메뉴 → 단축키 → FOA UI → 원터치 낚시) 도 같은 동작
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
-- 단축키: 찌가 떠 있는 동안은 같은 키가 "상호작용"(낚아채기)으로 바뀐다
function M:ApplyKey()
	if InCombatLockdown() then self.keyPending = true return end
	self.keyPending = nil
	ClearOverrideBindings(self.keyOwner)
	local k1, k2 = GetBindingKey("CLICK FOAFishButton:LeftButton")
	self.keySig = tostring(k1) .. "|" .. tostring(k2)
	if not (self.active and self.fishing) then return end
	for _, k in ipairs({ k1, k2 }) do
		if k then SetOverrideBinding(self.keyOwner, true, k, "INTERACTTARGET") end
	end
end

-- 오른쪽 클릭 한 번 → 잠깐 동안 다음 오른쪽 클릭을 낚시 동작으로 바꿔 둔다
function M:OnWorldDown(button)
	if button ~= "RightButton" or not self.active or InCombatLockdown() then return end
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
			local k = GetBindingKey("CLICK FOAFishButton:LeftButton")
			print("|T" .. Ink.tex.logo .. ":14:14|t |cffFFF468FOA|r 원터치 낚시: 오른쪽 두 번 클릭" ..
				(k and (" · " .. k) or " (단축키: 게임 메뉴 → 단축키 → FOA UI)") .. " 로 던지고 낚아채기")
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
			if M.refreshPending then M:Refresh() elseif M.keyPending then M:ApplyKey() end
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
