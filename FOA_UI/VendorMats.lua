-- FOA UI · 상인에게 살 수 있는 제작 재료 (실타래 · 약병 · 염료 · 소금 · 융해촉진제 · 양념 · 독 재료 …)
--  · 아이템 툴팁에 "상인  개당 가격" + 가까운 상인 (이름 · 지역 좌표 · 수량 한정)
--  · 자료: VendorMatsData.lua (QuestieDB 포에버 상인 · cMaNGOS 클래식 가격) — 포에버 전용
--  · 상인 창을 열면 실제 가격 · 그 상인 자리를 기억해서 자료보다 먼저 쓴다 (계정 공유 · Ink.db.vendMats)
--  · 다른 기능(전문기술 재료비)에서 ns.VendorPrice(아이템 번호 또는 이름) 으로 개당 값을 물어본다

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("VendorMats")
local plain = Ink.plain or function(v) return v end

local CAPITAL = { [1453] = 2, [1455] = 2, [1457] = 2, [1454] = 1, [1456] = 1, [1458] = 1 }

local function Money(c)
	local A = Ink.modules.AHPrice
	if A and A.Money then return A.Money(c) end
	return tostring(c or 0)
end
local function Data() return ns.VENDOR_MATS end
local function Saved()
	if not Ink.db then return {} end
	Ink.db.vendMats = Ink.db.vendMats or {}
	return Ink.db.vendMats
end
local function MyFac()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	return f == "Horde" and 1 or (f == "Alliance" and 2 or 0)
end

-- 개당 값 · 한 번에 사는 개수 · 그 묶음 값 · 게임에서 본 값인가
function M:Price(id)
	local s = Saved()[id]
	if s and s.p and s.p > 0 then
		local n = math.max(1, s.n or 1)
		return s.p / n, n, s.p, true
	end
	local d = Data()
	local e = d and d.items[id]
	if e and e[1] > 0 then
		local n = math.max(1, e[2] or 1)
		return e[1] / n, n, e[1], false
	end
end
function M:Known(id)
	local d = Data()
	return (d and d.items[id]) or Saved()[id]
end

-- 이름 → 번호 (전문기술 경로 자료는 재료를 이름으로만 안다)
local byName, byNameT = nil, 0
local function IdByName(name)
	if not byName or (not byName[name] and GetTime() - byNameT > 30) then
		byName, byNameT = {}, GetTime()
		local d = Data()
		for id, e in pairs(d and d.items or {}) do
			byName[e[3]] = id
			local n = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
			if n then byName[n] = id end
		end
		for id, s in pairs(Saved()) do if s.name then byName[s.name] = id end end
	end
	return byName[name]
end

-- 다른 기능에서: 개당 값 (모르면 nil)
function ns.VendorPrice(key)
	local id = type(key) == "number" and key or (type(key) == "string" and IdByName(key))
	if not id then return end
	local u = M:Price(id)
	return u
end

-------------------------------------------------------------------------------
-- 가까운 상인: 같은 대륙이면 세계 좌표 거리 · 아니면 내 진영 수도 · 수량 한정 상인은 다른 상인이 없을 때만
-------------------------------------------------------------------------------
local wcache = {}
local function World(map, x, y)
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
	local key = map * 1000000 + math.floor(x * 10) * 1000 + math.floor(y * 10)
	local c = wcache[key]
	if c == nil then
		local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
		if ok and cont and v and v.GetXY then
			local wx, wy = v:GetXY()
			c = { cont, wx, wy }
		else
			c = false
		end
		wcache[key] = c
	end
	return c or nil
end
local function PlayerWorld()
	local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not map then return end
	local ok, p = pcall(C_Map.GetPlayerMapPosition, map, "player")
	if not (ok and p) then return nil, map end
	local x, y = p:GetXY()
	if not x or x <= 0 then return nil, map end
	local ok2, cont, v = pcall(C_Map.GetWorldPosFromMapPos, map, p)
	if ok2 and cont and v and v.GetXY then
		local wx, wy = v:GetXY()
		return { cont, wx, wy }, map
	end
	return nil, map
end

-- 후보: { npc, 지도, x, y, 수량 한정, 이름 }
local function Candidates(id)
	local out, fac = {}, MyFac()
	local d = Data()
	local e = d and d.items[id]
	local seen = {}
	local s = Saved()[id]
	for npc, v in pairs(s and s.v or {}) do
		if type(v) == "table" and ((v[4] or 0) == 0 or v[4] == fac) then
			out[#out + 1] = { npc, v[1], v[2], v[3], v[5] and true or false, v[6] }
			seen[npc] = true
		end
	end
	for _, raw in ipairs(e and e[4] or {}) do
		local npc = math.abs(raw)
		local n = d.npcs[npc]
		if n and not seen[npc] and (n[1] == 0 or n[1] == fac) then
			out[#out + 1] = { npc, n[2], n[3], n[4], raw < 0, n[5] }
		end
	end
	return out
end

local nearCache = {}
function M:Nearest(id)
	local pw, pmap = PlayerWorld()
	local c = nearCache[id]
	if c and c.map == pmap and GetTime() - c.t < 15 then return c.best, c.count end
	local list = Candidates(id)
	local best, bestD
	local fac = MyFac()
	for pass = 1, 2 do   -- 1) 수량 한정이 아닌 상인 2) 그래도 없으면 수량 한정 상인
		for _, v in ipairs(list) do
			if (pass == 1) ~= v[5] then
				local dist
				if v[2] == pmap then
					dist = 0
				end
				local w = pw and World(v[2], v[3], v[4])
				if w and w[1] == pw[1] then
					dist = math.sqrt((w[2] - pw[2]) ^ 2 + (w[3] - pw[3]) ^ 2)
				elseif not dist then
					dist = (CAPITAL[v[2]] == fac) and 1e8 or 1e9   -- 다른 대륙 · 위치를 모름: 내 진영 수도 먼저
				end
				if not bestD or dist < bestD then best, bestD = v, dist end
			end
		end
		if best then break end
	end
	nearCache[id] = { map = pmap, t = GetTime(), best = best, count = #list }
	return best, #list
end

local function NpcName(v)
	local D = Ink.modules.Dungeon
	local n = D and D.BossName and D.BossName({ npc = v[1] })
	if type(n) == "string" and n ~= "" then return n end
	return v[6] or "상인"
end
local function ZoneName(map)
	local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return info and info.name or ""
end

-------------------------------------------------------------------------------
-- 툴팁
-------------------------------------------------------------------------------
function M:OnTooltip(tt, data)
	if Ink.db.vendTooltip == false or not tt.AddDoubleLine then return end
	local id = data and plain(data.id)
	if type(id) ~= "number" or not self:Known(id) then return end
	local unit, n, stack = self:Price(id)
	local right
	if unit then
		right = Money(unit)
		if n > 1 then right = right .. "  |cff8E939B(" .. n .. "개 " .. Money(stack) .. ")|r" end
	else
		right = "|cff8E939B값은 상인 창을 열면 기억|r"
	end
	tt:AddDoubleLine("|cff9EA3AB상인|r", right, 1, 1, 1, 1, 1, 1)
	local v, count = self:Nearest(id)
	if v then
		local where = string.format("%s %.0f, %.0f", ZoneName(v[2]), v[3], v[4])
		local more = count > 1 and string.format("  · 외 %d곳", count - 1) or ""
		tt:AddLine("  " .. NpcName(v) .. "  ·  " .. where .. (v[5] and "  · 수량 한정" or "") .. more, 0.6, 0.62, 0.66)
	end
end

-------------------------------------------------------------------------------
-- 상인 창: 실제 값 · 상인 자리 기억
-------------------------------------------------------------------------------
local function MerchantInfo(i)
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
		if ok and type(info) == "table" then return info.price, info.stackCount, info.numAvailable, info.hasExtendedCost end
	end
	if GetMerchantItemInfo then
		local _, _, price, qty, avail, _, _, ext = GetMerchantItemInfo(i)
		return price, qty, avail, ext
	end
end

function M:ReadMerchant()
	if not (GetMerchantNumItems and GetMerchantItemID) then return end
	local guid = plain(UnitGUID and UnitGUID("npc"))
	local npc = type(guid) == "string" and tonumber((select(6, strsplit("-", guid))))
	local nname = plain(UnitName and UnitName("npc"))
	if type(nname) ~= "string" then nname = nil end
	local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local x, y
	if map then
		local ok, p = pcall(C_Map.GetPlayerMapPosition, map, "player")
		if ok and p then x, y = p:GetXY() end
	end
	local S, fac, changed = Saved(), MyFac(), false
	for i = 1, (GetMerchantNumItems() or 0) do
		local id = plain(GetMerchantItemID(i))
		local price, qty, avail, ext = MerchantInfo(i)
		price, qty, avail, ext = plain(price), plain(qty), plain(avail), plain(ext)
		if type(id) == "number" and type(price) == "number" and price > 0 and not ext then
			local tg = Data() and Data().items[id]
			if not tg and C_Item.GetItemInfoInstant then
				local cls = select(6, C_Item.GetItemInfoInstant(id))
				tg = cls == 7   -- 직업용품 (자료에 없는 포에버 새 재료도 배운다)
			end
			if tg then
				local s = S[id] or {}
				S[id] = s
				s.p, s.n, s.t = price, math.max(1, qty or 1), time()
				s.name = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or s.name
				if npc and map and x and x > 0 then
					s.v = s.v or {}
					s.v[npc] = { map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10, fac, (type(avail) == "number" and avail >= 0) and 1 or false, nname }
				end
				nearCache[id] = nil
				changed = true
			end
		end
	end
	if changed then byName = nil end
end

function M:Init()
	if not ns.VENDOR_MATS then return end   -- 포에버 전용 자료
	if TooltipDataProcessor and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(M.OnTooltip, M, tt, data) end)
	end
	local e = CreateFrame("Frame")
	e:RegisterEvent("MERCHANT_SHOW")
	e:SetScript("OnEvent", function()
		C_Timer.After(0.4, function() pcall(M.ReadMerchant, M) end)
	end)
end
