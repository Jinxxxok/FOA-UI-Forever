-- FOA UI · 경매장 가격
--  · 경매장을 열면 위쪽에 "가격 스캔" 단추 → 전체 목록을 한 번에 받아 아이템마다 최저 단가를 기억 (서버별)
--  · 평소에 검색 · 둘러본 결과도 조용히 기억해서 갱신
--  · 아이템 툴팁에 경매장 단가 (묶음이면 묶음 가격도) · 오래된 값은 며칠 전인지 같이
--  · 다른 기능(전문기술 안내의 재료비)에서 이름이나 번호로 가격을 물어볼 수 있다: ns.AHPrice(itemOrName)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("AHPrice")
M.seen = {}
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local function Money(c)
	if not c or c <= 0 then return "" end
	if GetCoinTextureString then return GetCoinTextureString(math.floor(c + 0.5)) end
	local g, s, b = math.floor(c / 10000), math.floor(c / 100) % 100, math.floor(c % 100)
	return (g > 0 and (g .. "g ") or "") .. (s > 0 and (s .. "s ") or "") .. (b > 0 and (b .. "c") or "")
end
M.Money = Money

local function Realm()
	local r = GetRealmName and GetRealmName() or "?"
	local f = UnitFactionGroup and UnitFactionGroup("player") or ""
	return r .. "-" .. f
end

function M:Store()
	Ink.db.ah = Ink.db.ah or {}
	local k = Realm()
	local s = Ink.db.ah[k]
	if not s then s = { p = {}, n = {}, t = {}, scan = 0 }; Ink.db.ah[k] = s end
	s.p, s.n, s.t = s.p or {}, s.n or {}, s.t or {}
	return s
end

-- 한 아이템 가격 기록 (단가 · 그때 시각). 같은 스캔에서는 가장 싼 값만
function M:Record(id, name, unit, now, fresh)
	if not (id and unit and unit > 0) then return end
	local s = self.cur or self:Store()
	if fresh then
		-- 전체 스캔: 이번 스캔에서 처음 보면 새 값, 또 보면 더 싼 값
		if self.seen[id] then
			if unit < s.p[id] then s.p[id] = unit end
		else
			s.p[id] = unit
			self.seen[id] = true
		end
	else
		-- 둘러보기: 없거나 · 더 싸거나 · 한 시간 넘은 값이면 바꾼다
		local old = s.p[id]
		if not old or unit < old or (now - (s.t[id] or 0)) > 3600 then s.p[id] = unit end
	end
	s.t[id] = now
	if name and name ~= "" then s.n[name] = id end
end

-- 가격 물어보기: 아이템 번호 · 링크 · 이름
function M:Price(item)
	local s = self:Store()
	local id = type(item) == "number" and item or nil
	if not id and type(item) == "string" then
		id = tonumber(item:match("item:(%d+)")) or s.n[item]
		if not id and C_Item and C_Item.GetItemInfoInstant then
			id = C_Item.GetItemInfoInstant(item)
		end
	end
	if not id then return end
	return s.p[id], s.t[id], id
end
ns.AHPrice = function(item) return M:Price(item) end

-------------------------------------------------------------------------------
-- 스캔: 본섭식(C_AuctionHouse) / 클래식식(QueryAuctionItems) 둘 다
-------------------------------------------------------------------------------
local function Modern() return C_AuctionHouse and C_AuctionHouse.ReplicateItems and true or false end

local SCAN_GAP = 15 * 60 + 5
local WAIT_MAX = 45          -- 서버 응답을 이만큼(초) 기다린다
local READ_STEP = 2500       -- 한 번(한 프레임)에 읽는 매물 수 (한꺼번에 읽으면 화면이 멈춘다)

-- 마지막으로 서버에 전체 목록을 "요청"한 때 기준 (응답이 없었던 요청도 서버는 15분 제한에 센다)
local function LastAsk(s) return math.max(s.scan or 0, s.tryAt or 0) end

function M:CanScan()
	if time() - LastAsk(self:Store()) < SCAN_GAP then return false end
	if Modern() then return true end
	if CanSendAuctionQuery then
		local ok, _, all = pcall(CanSendAuctionQuery)
		return ok and all and true or false
	end
	return false
end

local function Open()
	local f = _G.AuctionHouseFrame or _G.AuctionFrame
	return f and f:IsShown()
end

function M:Scan()
	if self.scanning then return end
	local s = self:Store()
	self.scanning = true
	self.reading = nil
	self.seen = {}
	self.cur = s
	self.scanT0 = GetTime()
	self.scanID = (self.scanID or 0) + 1
	s.tryAt = time()
	self:Busy(true)
	self:Status("서버에 전체 목록 요청 중…")
	if Modern() then
		pcall(C_AuctionHouse.ReplicateItems)
		self:PollReplicate(self.scanID)
	elseif QueryAuctionItems then
		pcall(QueryAuctionItems, "", nil, nil, 0, false, 0, true)
		local id = self.scanID
		C_Timer.After(WAIT_MAX + 15, function()
			if M.scanning and M.scanID == id and not M.reading then M:Abort("no") end
		end)
	else
		self:Abort("none")
	end
end

-- 받는 중 / 기다리는 중을 1초마다 숫자로 보여 주고, 매물 수가 더 늘지 않으면 읽는다
--  (예전엔 이벤트 한 번만 기다려서, 이벤트가 안 오거나 0개일 때 막대만 계속 흘렀다)
function M:PollReplicate(id)
	local last, same = -1, 0
	local function tick()
		if not M.scanning or M.scanID ~= id or M.reading then return end
		if not Open() then M:Abort("closed") return end
		local ok, n = pcall(C_AuctionHouse.GetNumReplicateItems)
		n = (ok and tonumber(n)) or 0
		local el = math.floor(GetTime() - (M.scanT0 or GetTime()))
		if n > 0 and n == last then same = same + 1 else same = 0 end
		last = n
		if n > 0 then
			M:Status(string.format("목록 받는 중… 매물 %d개", n))
		else
			M:Status(string.format("서버 응답 기다리는 중… %d초", el))
		end
		if n > 0 and (same >= 2 or (M.repEvent and same >= 1)) then M:ReadReplicate(n) return end
		if el >= WAIT_MAX then
			if n > 0 then M:ReadReplicate(n) else M:Abort("no") end
			return
		end
		C_Timer.After(1, tick)
	end
	M.repEvent = nil
	C_Timer.After(1, tick)
end

-- 나눠서 읽기 (매물이 수만 개여도 화면이 안 멈추게)
function M:ReadReplicate(n)
	if self.reading then return end
	self.reading = true
	local id, now = self.scanID, time()
	local i, cnt = 0, 0
	local function step()
		if M.scanID ~= id then return end
		local stop = math.min(n - 1, i + READ_STEP - 1)
		for k = i, stop do
			local ok, name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(C_AuctionHouse.GetReplicateItemInfo, k)
			if ok and itemID and buyout and buyout > 0 and (count or 0) > 0 then
				M:Record(itemID, name, buyout / count, now, true)
				cnt = cnt + 1
			end
		end
		i = stop + 1
		if i < n then
			M:Status(string.format("가격 읽는 중… %d / %d", i, n))
			C_Timer.After(0, step)
		else
			M.reading = nil
			M:Finish(cnt)
		end
	end
	step()
end

-- 멈춤: 응답 없음 · 창 닫음
function M:Abort(why)
	self.scanning, self.reading, self.cur = nil, nil, nil
	self.scanID = (self.scanID or 0) + 1
	self:Busy(false)
	if why == "closed" then
		-- 창을 닫아서 멈춘 것: 요청은 이미 서버가 셌을 수 있지만 다음에 열면 다시 해 본다
		self:Store().tryAt = nil
		return
	end
	local wait = math.max(1, math.ceil((SCAN_GAP - (time() - LastAsk(self:Store()))) / 60))
	self:Status(string.format("|cffFFB75A서버가 목록을 안 보내 줬어요|r · 전체 목록은 15분에 한 번만 돼요 · %d분 뒤 자동으로 다시", wait))
end

function M:ReadClassicList(full)
	local n = GetNumAuctionItems and GetNumAuctionItems("list") or 0
	if n == 0 then return end
	local now = time()
	local cnt = 0
	for i = 1, n do
		local ok, name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(GetAuctionItemInfo, "list", i)
		if ok and itemID and buyout and buyout > 0 and (count or 0) > 0 then
			self:Record(itemID, name, buyout / count, now, full)
			cnt = cnt + 1
		end
	end
	if full then self:Finish(cnt) end
end

function M:Finish(cnt)
	local s = self:Store()
	s.scan = time()
	s.tryAt = nil
	local total = 0
	for _ in pairs(s.p) do total = total + 1 end
	self.scanning = nil
	self.reading = nil
	self.cur = nil
	self.scanID = (self.scanID or 0) + 1
	self:Busy(false)
	self:Status(string.format("|cff6FD39A스캔 완료|r · 매물 %d개 · 아이템 %d종 가격", cnt, total))
	print(string.format("|cffFFF468FOA|r 경매장 가격 스캔 완료 · 아이템 %d종", total))
end

-- 둘러보기 결과 (본섭식)
function M:ReadBrowse()
	if not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then return end
	local ok, res = pcall(C_AuctionHouse.GetBrowseResults)
	if not ok or not res then return end
	local now = time()
	for _, r in ipairs(res) do
		local id = r.itemKey and r.itemKey.itemID
		if id and r.minPrice and r.minPrice > 0 then self:Record(id, nil, r.minPrice, now, false) end
	end
end

-------------------------------------------------------------------------------
-- 경매장 창 위 작은 줄: 가격 스캔 단추 + 상태
-------------------------------------------------------------------------------
function M:Status(t)
	if self.bar then self.bar.status:SetText(t or self:LastText()) end
end

-- 받는 동안 막대 위로 빛이 흐른다
function M:Busy(on)
	local b = self.bar
	if not b then return end
	b.track:SetShown(on)
	b.shine:SetShown(on)
	if on then
		local t0 = GetTime()
		b:SetScript("OnUpdate", function(self)
			local w = self.track:GetWidth()
			local x = ((GetTime() - t0) * 160) % (w + 60) - 60
			self.shine:ClearAllPoints()
			self.shine:SetPoint("LEFT", self.track, "LEFT", math.max(0, x), 0)
			self.shine:SetWidth(math.max(1, math.min(60, w - math.max(0, x), x + 60)))
		end)
	else
		b:SetScript("OnUpdate", nil)
	end
end

-- 경매장에 들어오면 자동으로 (마지막 스캔이 15분 넘었으면) · 열려 있는 동안 15분마다
function M:AutoScan()
	if Ink.db.ahAuto == false or self.scanning then return end
	local f = _G.AuctionHouseFrame or _G.AuctionFrame
	if not (f and f:IsShown()) then return end
	if self:CanScan() then
		self:Scan()
	else
		local s = self:Store()
		local wait = math.max(1, math.ceil((SCAN_GAP - (time() - LastAsk(s))) / 60))
		self:Status(self:LastText() .. string.format("  ·  %d분 뒤 자동 스캔", wait))
	end
end

function M:LastText()
	local s = self:Store()
	if not s.scan or s.scan == 0 then return "아직 스캔 안 함 · 툴팁에 경매장 가격이 나와요" end
	local m = math.floor((time() - s.scan) / 60)
	local ago = m < 1 and "방금" or (m < 60 and (m .. "분 전") or (m < 1440 and (math.floor(m / 60) .. "시간 전") or (math.floor(m / 1440) .. "일 전")))
	return "마지막 스캔 " .. ago
end

function M:BuildBar(parent)
	if self.bar then return end
	local b = CreateFrame("Frame", "FOAAuctionBar", parent)
	b:SetSize(330, 28)
	b:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, 4)
	b:SetFrameStrata("HIGH")
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(0.04, 0.045, 0.06, 0.94)
	b.bd = Ink:Round(b, "BORDER", true, true)
	b.bd:SetAllPoints()
	b.bd:SetVertexColor(1, 1, 1, 0.1)
	b.btn = CreateFrame("Button", nil, b)
	b.btn:SetSize(78, 20)
	b.btn:SetPoint("LEFT", 4, 0)
	b.btn.bg = Ink:Round(b.btn, "BACKGROUND", true, false)
	b.btn.bg:SetAllPoints()
	b.btn.bg:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.14)
	b.btn.bd = Ink:Round(b.btn, "BORDER", true, true)
	b.btn.bd:SetAllPoints()
	b.btn.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
	b.btn.t = Ink:Text(b.btn, F.semi, 10, C.accent, "CENTER")
	b.btn.t:SetPoint("CENTER")
	b.btn.t:SetText("가격 스캔")
	b.btn:SetScript("OnClick", function()
		if M.scanning then return end
		-- Shift+클릭: 15분이 안 지났어도 다시 요청해 본다 (서버가 거절하면 45초 뒤 알려 줌)
		if not M:CanScan() and not IsShiftKeyDown() then M:AutoScan() return end
		M:Scan()
	end)
	b.btn:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.24)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("경매장 전체 가격 스캔", 1, 1, 1)
		Ink.TipLine(GameTooltip, "모든 매물의 최저 단가를 기억해서 아이템 툴팁에 보여 줘요", 0.7, 0.72, 0.75)
		Ink.TipLine(GameTooltip, "경매장에 들어오면 자동으로 해요 (서버가 15분에 한 번만 허락)", 0.55, 0.57, 0.6)
		Ink.TipLine(GameTooltip, "Shift+클릭: 15분이 안 지났어도 다시 요청", 0.55, 0.57, 0.6)
		GameTooltip:Show()
	end)
	b.btn:SetScript("OnLeave", function(self) self.bg:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.14); GameTooltip:Hide() end)
	b.status = Ink:Text(b, F.sans, 10, C.soft, "LEFT")
	b.status:SetPoint("LEFT", b.btn, "RIGHT", 10, 2)
	b.status:SetPoint("RIGHT", -8, 2)
	b.track = b:CreateTexture(nil, "ARTWORK")
	b.track:SetColorTexture(1, 1, 1, 0.08)
	b.track:SetHeight(2)
	b.track:SetPoint("BOTTOMLEFT", b.btn, "BOTTOMRIGHT", 10, 1)
	b.track:SetPoint("BOTTOMRIGHT", -8, 5)
	b.track:Hide()
	b.shine = b:CreateTexture(nil, "OVERLAY")
	b.shine:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
	b.shine:SetHeight(2)
	b.shine:Hide()
	self.bar = b
end

function M:OnShow()
	local parent = _G.AuctionHouseFrame or _G.AuctionFrame
	if not parent then return end
	self:BuildBar(parent)
	self.bar:SetParent(parent)
	self.bar:ClearAllPoints()
	self.bar:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, 4)
	self.bar:Show()
	self:Status()
	-- 창이 다 뜬 뒤 자동 스캔, 열려 있는 동안 1분마다 확인
	C_Timer.After(1.2, function() pcall(M.AutoScan, M) end)
	if not self.ticker and C_Timer.NewTicker then
		self.ticker = C_Timer.NewTicker(60, function()
			local f = _G.AuctionHouseFrame or _G.AuctionFrame
			if not (f and f:IsShown()) then if M.ticker then M.ticker:Cancel(); M.ticker = nil end return end
			pcall(M.AutoScan, M)
		end)
	end
end

-------------------------------------------------------------------------------
-- 툴팁
-------------------------------------------------------------------------------
local function StackCount(tt)
	local owner = tt.GetOwner and tt:GetOwner()
	if not owner then return 1 end
	local bag, slot
	if owner.GetBagID and owner.GetID then
		local ok, b = pcall(owner.GetBagID, owner)
		if ok then bag, slot = b, owner:GetID() end
	end
	if not bag then
		local p = owner:GetParent()
		if p and p.bag and p.slot then bag, slot = p.bag, p.slot end
	end
	if bag and slot and C_Container and C_Container.GetContainerItemInfo then
		local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
		if ok and info and info.stackCount then return info.stackCount end
	end
	return 1
end

function M:OnTooltip(tt, data)
	if Ink.db.ahTooltip == false or not tt.AddDoubleLine then return end
	local id = data and plain(data.id)
	if type(id) ~= "number" then return end
	local p, t = self:Price(id)
	if not p then return end
	local n = StackCount(tt)
	local days = t and math.floor((time() - t) / 86400) or 0
	local left = "|cff9EA3AB경매장|r" .. (days >= 2 and string.format("  |cff5E636B(%d일 전)|r", days) or "")
	local right = Money(p)
	if n > 1 then right = right .. "  |cff8E939B×" .. n .. " = |r" .. Money(p * n) end
	tt:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
end

-------------------------------------------------------------------------------
function M:Init()
	if TooltipDataProcessor and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(M.OnTooltip, M, tt, data) end)
	end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "REPLICATE_ITEM_LIST_UPDATE", "AUCTION_ITEM_LIST_UPDATE",
		"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" }) do pcall(e.RegisterEvent, e, ev) end
	e:SetScript("OnEvent", function(_, event)
		if event == "AUCTION_HOUSE_SHOW" then
			C_Timer.After(0.1, function() pcall(M.OnShow, M) end)
		elseif event == "AUCTION_HOUSE_CLOSED" then
			if M.bar then M.bar:Hide() end
			if M.scanning and not M.reading then M:Abort("closed") end
		elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
			-- 목록이 왔다는 신호: 1초마다 보는 쪽(PollReplicate)이 개수가 멈추면 읽는다
			if M.scanning then M.repEvent = true end
		elseif event == "AUCTION_ITEM_LIST_UPDATE" then
			local full = M.scanning
			pcall(M.ReadClassicList, M, full)
		else
			pcall(M.ReadBrowse, M)
		end
	end)
end
