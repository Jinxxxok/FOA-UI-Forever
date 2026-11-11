-- FOA UI · 빠른 자동 줍기
--  자동 줍기가 켜져 있으면 전리품 창이 열리기를 기다리지 않고 바로 한꺼번에 줍는다.
--  (블리자드 자동 줍기는 한 칸씩 천천히 줍고 창이 깜빡인다)
--  가방이 꽉 찼거나 잠긴 물건이 남으면 원래 전리품 창이 그대로 뜬다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("SpeedyLoot")

local function AutoLootOn()
	local def = (C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("autoLootDefault")) or (GetCVarBool and GetCVarBool("autoLootDefault"))
	local mod = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")
	return (def and true or false) ~= (mod and true or false)
end

function M:OnLootReady()
	if Ink.db.speedyLoot == false or not AutoLootOn() then return end
	local now = GetTime()
	if now - (self.last or 0) < 0.25 then return end
	self.last = now
	local n = GetNumLootItems and GetNumLootItems() or 0
	if n == 0 then return end
	-- 던전 진행(보스 처치 확인)은 전리품 칸을 읽으므로 줍기 전에 먼저 읽게 한다
	local D = Ink.modules.Dungeon
	if D and D.hereKey and D.CheckLoot then pcall(D.CheckLoot, D) end
	-- 줍는 동안 창이 잠깐 비치지 않게 투명하게 (남는 게 있으면 다시 보이게)
	if LootFrame then LootFrame:SetAlpha(0) end
	for i = n, 1, -1 do
		local ok, locked = pcall(function() return select(6, GetLootSlotInfo(i)) end)
		if not (ok and locked) then LootSlot(i) end
	end
	C_Timer.After(0.15, function()
		if LootFrame then LootFrame:SetAlpha(1) end
	end)
end

function M:Init()
	local e = CreateFrame("Frame")
	pcall(e.RegisterEvent, e, "LOOT_READY")
	e:SetScript("OnEvent", function() pcall(M.OnLootReady, M) end)
end
