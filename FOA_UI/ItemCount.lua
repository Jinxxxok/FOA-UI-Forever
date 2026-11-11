-- FOA UI · 아이템 툴팁에 보유 개수 (가방 · 은행 · 착용 · 다른 캐릭터)
--  캐릭터마다 가방 · 은행 · 착용 아이템 수를 계정 저장 파일(Ink.db.inv)에 남겨 두고
--  아이템에 마우스를 올리면 툴팁 아래에 "누가 어디에 몇 개" 를 보여 준다.
--  은행은 은행 창을 열었을 때만 읽을 수 있어서, 마지막으로 열었을 때 기준이다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("ItemCount")
local plain = Ink.plain

local function Realm() return GetRealmName and GetRealmName() or "?" end
local function Me() return UnitName("player") or "?" end

function M:Store()
	Ink.db.inv = Ink.db.inv or {}
	local r = Realm()
	Ink.db.inv[r] = Ink.db.inv[r] or {}
	local me = Me()
	local s = Ink.db.inv[r][me]
	if not s then
		s = {}
		Ink.db.inv[r][me] = s
	end
	local _, cls = UnitClass("player")
	s.class = cls
	s.faction = UnitFactionGroup and UnitFactionGroup("player")
	return s
end

-- 가방 번호 목록
local function BagIDs()
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	local t = {}
	for b = 0, last do t[#t + 1] = b end
	return t
end

local function BankIDs()
	local t, seen = {}, {}
	local function add(b) if b and not seen[b] then seen[b] = true; t[#t + 1] = b end end
	add(BANK_CONTAINER or -1)
	if REAGENTBANK_CONTAINER then add(REAGENTBANK_CONTAINER) end
	local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
	for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do add(b) end
	local E = Enum and Enum.BagIndex
	if E then
		for i = 1, 6 do add(E["CharacterBankTab_" .. i]) end
	end
	return t
end

local function Scan(ids)
	local out = {}
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out end
	for _, bag in ipairs(ids) do
		local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (ok and n or 0) do
			local ok2, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			local id = ok2 and info and plain(info.itemID)
			if id then out[id] = (out[id] or 0) + (plain(info.stackCount) or 1) end
		end
	end
	return out
end

function M:ScanBags()
	local s = self:Store()
	s.bags = Scan(BagIDs())
	local eq = {}
	for slot = 1, 19 do
		local id = GetInventoryItemID and GetInventoryItemID("player", slot)
		if id then eq[id] = (eq[id] or 0) + 1 end
	end
	s.equip = eq
	s.at = time()
end

function M:ScanBank()
	if not self.bankOpen then return end
	local s = self:Store()
	s.bank = Scan(BankIDs())
	s.bankAt = time()
end

-------------------------------------------------------------------------------
-- 툴팁
-------------------------------------------------------------------------------
local function ClassRGB(cls)
	local c = cls and (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls])
	if c then return c.r, c.g, c.b end
	return 0.85, 0.86, 0.88
end

local function Parts(rec, id, live)
	local bags = live and live.bags or (rec.bags and rec.bags[id]) or 0
	local bank = (rec.bank and rec.bank[id]) or 0
	local equip = live and live.equip or (rec.equip and rec.equip[id]) or 0
	return bags, bank, equip
end

local function Words(bags, bank, equip)
	local w = {}
	if bags > 0 then w[#w + 1] = "가방 " .. bags end
	if bank > 0 then w[#w + 1] = "은행 " .. bank end
	if equip > 0 then w[#w + 1] = "착용 " .. equip end
	return table.concat(w, "  ·  ")
end

function M:OnTooltip(tt, data)
	if Ink.db.itemCountTip == false or not tt.AddDoubleLine then return end
	local id = data and plain(data.id)
	if type(id) ~= "number" then return end
	local inv = Ink.db.inv and Ink.db.inv[Realm()]
	if not inv then return end
	local me = Me()
	-- 지금 캐릭터 가방은 실시간 (방금 주운 것도 바로)
	local live = { bags = 0, equip = 0 }
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, id, false)
		if ok and type(n) == "number" then live.bags = n end
	end
	local myRec = inv[me] or {}
	live.equip = (myRec.equip and myRec.equip[id]) or 0
	if live.equip > 0 then live.bags = math.max(0, live.bags - live.equip) end

	local rows, total, others = {}, 0, false
	local b, k, e = Parts(myRec, id, live)
	if b + k + e > 0 then
		rows[#rows + 1] = { name = me, cls = myRec.class, b = b, k = k, e = e, me = true }
		total = total + b + k + e
	end
	local names = {}
	for name in pairs(inv) do if name ~= me then names[#names + 1] = name end end
	table.sort(names)
	for _, name in ipairs(names) do
		local rec = inv[name]
		local b2, k2, e2 = Parts(rec, id)
		if b2 + k2 + e2 > 0 then
			rows[#rows + 1] = { name = name, cls = rec.class, b = b2, k = k2, e = e2 }
			total = total + b2 + k2 + e2
			others = true
		end
	end
	if #rows == 0 then return end
	-- 지금 가방에만 있으면 굳이 안 보여 준다 (보고 있는 그대로라서)
	local mine = rows[1].me and rows[1] or nil
	if not others and mine and mine.k == 0 then return end

	tt:AddLine(" ")
	for _, r in ipairs(rows) do
		local cr, cg, cb = ClassRGB(r.cls)
		tt:AddDoubleLine((r.me and "|cffE3C07A·|r " or "  ") .. r.name, Words(r.b, r.k, r.e), cr, cg, cb, 0.85, 0.86, 0.88)
	end
	if #rows > 1 then
		tt:AddDoubleLine("  모두", tostring(total), 0.6, 0.62, 0.66, 1, 0.82, 0.3)
	end
end

-------------------------------------------------------------------------------
function M:Init()
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
		"BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local pending
	local function later(fn)
		if pending then return end
		pending = true
		C_Timer.After(0.3, function()
			pending = nil
			pcall(fn, M)
		end)
	end
	e:SetScript("OnEvent", function(_, ev)
		if ev == "BANKFRAME_OPENED" then
			M.bankOpen = true
			C_Timer.After(0.2, function() pcall(M.ScanBank, M) end)
		elseif ev == "BANKFRAME_CLOSED" then
			pcall(M.ScanBank, M)
			M.bankOpen = nil
		elseif ev == "PLAYERBANKSLOTS_CHANGED" or ev == "PLAYERREAGENTBANKSLOTS_CHANGED" then
			later(M.ScanBank)
		else
			later(function()
				M:ScanBags()
				if M.bankOpen then M:ScanBank() end
			end)
		end
	end)
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
			local ok, err = pcall(M.OnTooltip, M, tt, data)
			if not ok then Ink:LogError("ItemCount: " .. tostring(err)) end
		end)
	end
end
