-- FOA UI · 상인 편의 기능
--  상인 창을 열면 잡동사니(회색 아이템) 자동 판매 + 자동 수리 (길드 수리 가능하면 길드 자금 먼저)
--  결과는 채팅창에 한 줄로: "잡동사니 7개 판매 +1골드 · 수리 -45골드 (길드)"

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Merchant")

local PREFIX = "|cffFFF468FOA|r "
local REAGENT_BAG = Enum.BagIndex and Enum.BagIndex.ReagentBag or 5

-- 동(구리) 단위 숫자 → "37골 28은 5동" (아이콘 포함)
local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"
local function Coins(v)
	v = math.floor(v or 0)
	local g, sv, c = math.floor(v / 10000), math.floor(v / 100) % 100, v % 100
	local t = {}
	if g > 0 then t[#t + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g) .. GOLD end
	if sv > 0 then t[#t + 1] = sv .. SILVER end
	if c > 0 or #t == 0 then t[#t + 1] = c .. COPPER end
	return table.concat(t, " ")
end

function M:Repair()
	if Ink.db.autoRepair == false or not CanMerchantRepair or not CanMerchantRepair() then return end
	local cost, can = GetRepairAllCost()
	if not can or not cost or cost <= 0 then return end
	local guild = false
	if Ink.db.guildRepair ~= false and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair() then
		local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
		local bank = GetGuildBankMoney and GetGuildBankMoney() or 0
		if (limit == -1 or limit >= cost) and bank >= cost then guild = true end
	end
	if guild then
		RepairAllItems(true)
		return cost, true
	elseif GetMoney() >= cost then
		RepairAllItems()
		return cost, false
	end
	return nil, nil, cost
end

-- 잡동사니 판매: 한 번에 너무 많이 팔면 서버가 무시하므로 나눠서 판다
function M:SellPass()
	if not (MerchantFrame and MerchantFrame:IsShown()) then return end
	local sold = 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.quality == 0 and not info.hasNoValue and not info.isLocked then
				local price = select(11, C_Item.GetItemInfo(info.itemID)) or 0
				if price > 0 then
					self.junkGold = (self.junkGold or 0) + price * (info.stackCount or 1)
					self.junkCount = (self.junkCount or 0) + 1
					C_Container.UseContainerItem(bag, slot)
					sold = sold + 1
					if sold >= 10 then
						C_Timer.After(0.4, function() M:SellPass() end)
						return
					end
				end
			end
		end
	end
	self:Report()
end

function M:Report()
	local parts = {}
	if (self.junkCount or 0) > 0 then
		parts[#parts + 1] = string.format("잡동사니 %d개 판매 |cff6FD39A+%s|r", self.junkCount, Coins(self.junkGold or 0))
	end
	if self.repairCost then
		parts[#parts + 1] = string.format("수리 |cffFF6B5E-%s|r%s", Coins(self.repairCost), self.repairGuild and " (길드)" or "")
	elseif self.repairShort then
		parts[#parts + 1] = string.format("|cffFF6B5E수리비 부족 (%s 필요)|r", Coins(self.repairShort))
	end
	if #parts > 0 then print(PREFIX .. table.concat(parts, "  ·  ")) end
	self.junkCount, self.junkGold, self.repairCost, self.repairGuild, self.repairShort = nil, nil, nil, nil, nil
end

function M:OnMerchant()
	self.junkCount, self.junkGold = 0, 0
	local cost, guild, short = self:Repair()
	self.repairCost, self.repairGuild, self.repairShort = cost, guild, short
	if Ink.db.sellJunk ~= false then
		self:SellPass()
	else
		self:Report()
	end
end

function M:Init()
	local e = CreateFrame("Frame")
	e:RegisterEvent("MERCHANT_SHOW")
	e:SetScript("OnEvent", function()
		-- 상인 창이 다 열린 다음에
		C_Timer.After(0.2, function() M:OnMerchant() end)
	end)
end
