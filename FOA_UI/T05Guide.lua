-- FOA UI · 던전 세트 2 (0.5티) 가이드 — BIS 창의 "0.5티" 탭 (포에버)
--  · 4단계 강화(손목 → 허리띠·장갑 → 장화·바지·어깨 → 모자·튜닉) 카드: 받은 것 · 내야 하는 0티 장비 보유
--  · 지금 할 일: 퀘스트 · 주는 NPC 자리(누르면 지도) · 목표 · 필요한 재료와 가진 개수 · 골드
--  · 전체 29단계 목록: 끝낸 것 · 진행 중 · 다음 (내 직업 · 진영 갈래만)
--  자료: T05Data.lua (AllTheThings 단계 · 재료 · 보상 + QuestieDB 한글 이름 · NPC 자리)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("T05")
local F, C = Ink.font, Ink.c
local plain = Ink.plain or function(v) return v end

local W = 446
local UP_LABEL = { "손목", "허리띠·장갑", "장화·바지·어깨", "모자·튜닉" }
-- 자리 글 대신 쓸 설명 (대륙 지도 좌표 · 유령 NPC)
local LOC_NOTE = {
	[16033] = "검은바위 산 · 검은바위 첨탑 입구 바로 앞 (유령 · 4차원 유령 탐색기로 보여요)",
	[16016] = "동부 역병지대 · 스트라솔름 입구 앞 (유령 · 4차원 유령 탐색기로 보여요)",
}
-- 단계 안내 (공략 · 알려진 문제)
local QUEST_NOTE = {
	[8922] = "진지한 제안을 끝내면 델리아나에게 다시 말을 걸어 받아요. 안 보이면 재접속해 보세요. 시즌 오브 디스커버리에서 이 퀘스트가 안 뜨던 문제가 핫픽스로 고쳐진 적이 있어서, 그래도 없으면 GM 문의를 해 주세요",
	[8923] = "진지한 제안을 끝내면 모크바르에게 다시 말을 걸어 받아요. 안 보이면 재접속해 보세요. 시즌 오브 디스커버리에서 이 퀘스트가 안 뜨던 문제가 핫픽스로 고쳐진 적이 있어서, 그래도 없으면 GM 문의를 해 주세요",
	[8945] = "스트라솔름 정비용 입구 · 남작 리븐데어를 45분 안에 (들어가면 시간이 시작돼요)",
	[9015] = "검은바위 나락 투기장에서 도전의 깃발을 꽂으면 텔드렌 무리가 나와요",
	[8995] = "검은바위 첨탑 상층에서 부름의 화로로 군주 발타라크를 불러내 처치",
}
local QCOL = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }

local function D() return ns.T05 end
local function MyFac()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	return f == "Horde" and 1 or 2
end
local function MyClass() return select(2, UnitClass("player")) end

-------------------------------------------------------------------------------
-- 상태
-------------------------------------------------------------------------------
local function Done(q) return q and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q) or false end
local function InLog(q)
	if not q or not C_QuestLog.GetLogIndexForQuestID then return false end
	local i = C_QuestLog.GetLogIndexForQuestID(q)
	return i ~= nil and i > 0
end
local function Ready(q) return InLog(q) and C_QuestLog.IsComplete and C_QuestLog.IsComplete(q) or false end

local function Have(id)
	local n = 0
	if C_Item.GetItemCount then
		local ok, c = pcall(C_Item.GetItemCount, id, true)
		if ok and type(c) == "number" then n = c end
	elseif GetItemCount then
		n = GetItemCount(id, true) or 0
	end
	if n == 0 then
		local eq = (C_Item.IsEquippedItem and C_Item.IsEquippedItem(id)) or (IsEquippedItem and IsEquippedItem(id))
		if eq then n = 1 end
	end
	return n
end

local function ItemName(id)
	local n = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not n and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
	return n or (D().item and D().item[id]) or ("아이템 #" .. id)
end
local function ItemIconOf(id)
	local ic = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
	if not ic and C_Item.GetItemInfoInstant then ic = select(5, C_Item.GetItemInfoInstant(id)) end
	return ic or 134400
end
local function ItemQ(id) return (C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)) or 3 end

local function Money(c)
	local A = Ink.modules.AHPrice
	if A and A.Money then return A.Money(c) end
	return string.format("%d골드", math.floor((c or 0) / 10000))
end

-- 이 칸에서 내 직업 · 진영 갈래 하나
local function Pick(step)
	local fac, cls = MyFac(), MyClass()
	for _, v in ipairs(step) do
		local okF = (v.fac or 0) == 0 or v.fac == fac
		local okC = not v.cls
		if v.cls then for _, c in ipairs(v.cls) do if c == cls then okC = true end end end
		if okF and okC then return v end
	end
end

-- 전체 단계 → { q, npc, e(보고 NPC), items, gold, up(강화 단계), reward, title, obj }
function M:Steps()
	local d = D()
	local cd = d and d.class[MyClass()]
	if not cd then return nil end
	local fac = MyFac()
	local out = {}
	for _, st in ipairs(d.chain) do
		if st.up then
			local u = cd[st.up]
			if u then
				-- 포에버 번호(SoD식 84xxx)와 옛 클래식 번호 둘 다 본다 (어느 쪽으로 끝냈든 끝낸 걸로)
				local q = fac == 1 and u.H or u.A
				local q0 = fac == 1 and u.H0 or u.A0
				local items = {}
				for _, c in ipairs((fac == 1 and u.costH or u.costA) or {}) do items[#items + 1] = c end
				out[#out + 1] = { q = q, q0 = (q0 and q0 ~= q) and q0 or nil, npc = fac == 1 and u.nH or u.nA, e = fac == 1 and u.eH or u.eA,
					items = items, gold = u.gold, up = st.up, reward = u.reward }
			end
		else
			local v = Pick(st)
			if v then out[#out + 1] = { q = v.q, npc = v.npc, e = v.e, items = v.items or {}, gold = v.gold } end
		end
	end
	for _, s in ipairs(out) do
		local t = d.quest[s.q] or (s.q0 and d.quest[s.q0])
		s.title = t and t[1] or ("퀘스트 #" .. s.q)
		s.obj = t and t[2] or ""
		s.done = Done(s.q) or (s.q0 and Done(s.q0)) or false
		local lq = InLog(s.q) and s.q or ((s.q0 and InLog(s.q0)) and s.q0 or nil)
		s.log = lq ~= nil
		s.ready = lq and Ready(lq) or false
		s.note = QUEST_NOTE[s.q]
	end
	return out
end

-- 보상 묶음 고르기: 지금 보고 있는 특성 BIS 에 든 묶음 (없으면 첫 묶음)
function M:Block(cd)
	local D2 = Ink.modules.Dungeon
	local key = D2 and D2.ViewKey and D2.ViewKey()
	if not key and ns.Score and ns.Score.Spec then local _, k = ns.Score:Spec(); key = k end
	local spec = key and ns.BIS_FOREVER and ns.BIS_FOREVER.specs[MyClass() .. ":" .. key]
	if not spec then return 1 end
	local want = {}
	for _, id in pairs(spec.g or {}) do want[id] = true end
	for _, a in ipairs(spec.alt or {}) do if a[2] then want[a[2]] = true end end
	local cnt, best, bn = {}, 1, 0
	for u = 1, 4 do
		for b, ids in ipairs(cd[u] and cd[u].reward or {}) do
			for _, id in ipairs(ids) do
				if want[id] then
					cnt[b] = (cnt[b] or 0) + 1
					if cnt[b] > bn then best, bn = b, cnt[b] end
				end
			end
		end
	end
	return best
end

-- 지금 할 일 = 처음으로 안 끝낸 단계
local function Current(steps)
	for i, s in ipairs(steps) do if not s.done then return i, s end end
end

-- NPC 자리 → 글 · 지도 찍을 수 있나
local function Where(nid)
	local n = nid and D().npc[nid]
	if not n then return nil end
	local name, map, x, y = n[1], n[2], n[3], n[4]
	local zone = map > 0 and C_Map.GetMapInfo and (C_Map.GetMapInfo(map) or {}).name or ""
	local txt
	if LOC_NOTE[nid] then txt = LOC_NOTE[nid]
	elseif x < 0 then txt = (zone ~= "" and zone or "던전") .. " 안"
	else txt = string.format("%s %.0f, %.0f", zone, x, y) end
	local D2 = Ink.modules.Dungeon
	local gname = D2 and D2.BossName and D2.BossName({ npc = nid })
	if type(gname) ~= "string" or gname == "" then gname = name end
	return gname, txt, (x > 0 and map > 0) and { nid, map, x, y, label = gname } or nil
end

-------------------------------------------------------------------------------
-- 화면
-------------------------------------------------------------------------------
local function Icon(parent, size)
	local h = CreateFrame("Button", nil, parent)
	h:SetSize(size, size)
	h.bg = h:CreateTexture(nil, "BACKGROUND")
	h.bg:SetAllPoints()
	h.bg:SetColorTexture(0, 0, 0, 0.5)
	h.tex = h:CreateTexture(nil, "ARTWORK")
	h.tex:SetPoint("TOPLEFT", 1, -1)
	h.tex:SetPoint("BOTTOMRIGHT", -1, 1)
	h.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	h.bd = Ink:Round(h, "OVERLAY", true, true)
	h.bd:SetAllPoints()
	h:SetScript("OnEnter", function(self)
		if not self.itemID then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.itemID)
		if self.extra then GameTooltip:AddLine(self.extra, 0.7, 0.72, 0.75, true) end
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", GameTooltip_Hide)
	function h:SetItem(id, dim)
		self.itemID = id
		self.tex:SetTexture(ItemIconOf(id))
		self.tex:SetDesaturated(dim and true or false)
		self.tex:SetAlpha(dim and 0.55 or 1)
		local c = QCOL[ItemQ(id)] or QCOL[1]
		self.bd:SetVertexColor(c[1], c[2], c[3], dim and 0.4 or 0.9)
	end
	return h
end

function M:Build(p)
	if self.f then return self.f end
	local f = CreateFrame("Frame", nil, p)
	f:SetPoint("TOPLEFT", 12, -108)
	f:SetPoint("BOTTOMRIGHT", -12, 12)
	f:Hide()
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, d) M:Scroll(-d * 3) end)
	-- 세트 이름 · 단계 수는 BIS 창 머리말(큰 숫자 자리)에 쓴다 (M:Head)
	-- 4단계 카드
	f.cards = {}
	local cw = (W - 3 * 6) / 4
	for i = 1, 4 do
		local c = CreateFrame("Frame", nil, f)
		c:SetSize(cw, 66)
		c:SetPoint("TOPLEFT", (i - 1) * (cw + 6), 0)
		c.bg = c:CreateTexture(nil, "BACKGROUND")
		c.bg:SetAllPoints()
		c.bg:SetColorTexture(1, 1, 1, 0.04)
		c.top = c:CreateTexture(nil, "ARTWORK")
		c.top:SetPoint("TOPLEFT"); c.top:SetPoint("TOPRIGHT")
		c.top:SetHeight(2)
		c.label = Ink:Text(c, F.semi, 10, C.soft, "LEFT")
		c.label:SetPoint("TOPLEFT", 6, -6)
		c.label:SetPoint("RIGHT", -18, 0)
		c.check = c:CreateTexture(nil, "OVERLAY")
		c.check:SetTexture(Ink.icon("Check"))
		c.check:SetSize(12, 12)
		c.check:SetPoint("TOPRIGHT", -5, -5)
		c.icons = {}
		for k = 1, 3 do
			c.icons[k] = Icon(c, 22)
			c.icons[k]:SetPoint("TOPLEFT", 6 + (k - 1) * 25, -22)
		end
		c.state = Ink:Text(c, F.sans, 9, C.muted, "LEFT")
		c.state:SetPoint("BOTTOMLEFT", 6, 6)
		c.state:SetPoint("RIGHT", -4, 0)
		f.cards[i] = c
	end
	-- 지금 할 일
	local now = CreateFrame("Frame", nil, f)
	now:SetPoint("TOPLEFT", 0, -74)
	now:SetSize(W, 132)
	now.bg = now:CreateTexture(nil, "BACKGROUND")
	now.bg:SetAllPoints()
	now.bg:SetColorTexture(1, 0.96, 0.41, 0.05)
	now.bar = now:CreateTexture(nil, "ARTWORK")
	now.bar:SetPoint("TOPLEFT"); now.bar:SetPoint("BOTTOMLEFT")
	now.bar:SetWidth(2)
	now.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	now.k = Ink:Text(now, F.semi, 9, C.accent, "LEFT")
	now.k:SetPoint("TOPLEFT", 10, -7)
	now.name = Ink:Text(now, F.semi, 13, C.text, "LEFT")
	now.name:SetPoint("TOPLEFT", 10, -20)
	now.name:SetPoint("RIGHT", -70, 0)
	now.where = CreateFrame("Button", nil, now)
	now.where:SetPoint("TOPLEFT", 10, -38)
	now.where:SetSize(W - 20, 14)
	now.where.t = Ink:Text(now.where, F.sans, 10, C.soft, "LEFT")
	now.where.t:SetAllPoints()
	now.where:SetScript("OnClick", function(self) if self.x then local P = Ink.modules.Professions; if P and P.Waypoint then P.Waypoint(self.x) end end end)
	now.where:SetScript("OnEnter", function(self) if self.x then self.t:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end end)
	now.where:SetScript("OnLeave", function(self) self.t:SetTextColor(C.soft[1], C.soft[2], C.soft[3]) end)
	now.obj = Ink:Text(now, F.sans, 10, C.muted, "LEFT")
	now.obj:SetPoint("TOPLEFT", 10, -55)
	now.obj:SetWidth(W - 20)
	now.obj:SetWordWrap(true)
	now.obj:SetJustifyV("TOP")
	now.chips = {}
	f.now = now
	-- 전체 목록
	f.lh = Ink:Text(f, F.semi, 10, C.muted, "LEFT")
	f.lh:SetPoint("TOPLEFT", now, "BOTTOMLEFT", 4, -8)
	f.lh:SetText("전체 단계")
	f.rows = {}
	f.list = CreateFrame("Frame", nil, f)
	f.list:SetPoint("TOPLEFT", now, "BOTTOMLEFT", 0, -24)
	f.list:SetPoint("BOTTOMRIGHT", 0, 0)
	f.list:SetClipsChildren(true)
	self.f = f
	self.off = 0
	return f
end

local function Chip(now, i)
	local c = now.chips[i]
	if c then return c end
	c = CreateFrame("Frame", nil, now)
	c:SetSize(140, 20)
	c.icon = Icon(c, 18)
	c.icon:SetPoint("LEFT", 0, 0)
	c.t = Ink:Text(c, F.sans, 10, C.soft, "LEFT")
	c.t:SetPoint("LEFT", c.icon, "RIGHT", 5, 0)
	c.t:SetPoint("RIGHT", 0, 0)
	now.chips[i] = c
	return c
end

local function Row(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, f.list)
	r:SetSize(W, 18)
	r.hl = r:CreateTexture(nil, "BACKGROUND")
	r.hl:SetAllPoints()
	r.hl:SetColorTexture(1, 1, 1, 0)
	r.mark = r:CreateTexture(nil, "ARTWORK")
	r.mark:SetSize(10, 10)
	r.mark:SetPoint("LEFT", 6, 0)
	r.dot = r:CreateTexture(nil, "ARTWORK")
	r.dot:SetTexture(Ink.tex.disc)
	r.dot:SetSize(6, 6)
	r.dot:SetPoint("CENTER", r.mark, "CENTER")
	r.num = Ink:Text(r, F.latinB, 9, C.dim, "RIGHT")
	r.num:SetPoint("LEFT", 18, 0)
	r.num:SetWidth(16)
	r.name = Ink:Text(r, F.sans, 10, C.soft, "LEFT")
	r.name:SetPoint("LEFT", 40, 0)
	r.name:SetWidth(230)
	r.where = Ink:Text(r, F.sans, 9, C.dim, "RIGHT")
	r.where:SetPoint("RIGHT", -6, 0)
	r.where:SetWidth(170)
	r:SetScript("OnEnter", function(self)
		self.hl:SetColorTexture(1, 1, 1, 0.05)
		local s = self.s
		if not s then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(s.title, 1, 1, 1)
		local gname, txt = Where(s.npc)
		if gname then GameTooltip:AddDoubleLine("시작", gname .. " · " .. txt, 0.7, 0.72, 0.75, 1, 1, 1) end
		if s.e and s.e ~= s.npc then
			local en, et = Where(s.e)
			if en then GameTooltip:AddDoubleLine("보고", en .. " · " .. et, 0.7, 0.72, 0.75, 1, 1, 1) end
		end
		if s.obj ~= "" then Ink.TipLine(GameTooltip, s.obj, 0.7, 0.72, 0.75) end
		if s.note then Ink.TipLine(GameTooltip, s.note, 0.89, 0.75, 0.48) end
		for _, it in ipairs(s.items or {}) do
			local h = Have(it[1])
			GameTooltip:AddDoubleLine("  " .. ItemName(it[1]), h .. " / " .. it[2], 0.85, 0.85, 0.85, h >= it[2] and 0.44 or 1, h >= it[2] and 0.83 or 1, h >= it[2] and 0.6 or 1)
		end
		if (s.gold or 0) > 0 then GameTooltip:AddDoubleLine("  골드", Money(s.gold), 0.85, 0.85, 0.85, 1, 0.82, 0.32) end
		GameTooltip:AddLine(s.done and "끝냄" or (s.ready and "보고할 수 있어요" or (s.log and "진행 중" or "아직")), 0.56, 0.58, 0.61)
		if self.wp then GameTooltip:AddLine("클릭: 지도에 시작 NPC 위치", 0.56, 0.58, 0.61) end
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function(self) self.hl:SetColorTexture(1, 1, 1, 0); GameTooltip:Hide() end)
	r:SetScript("OnClick", function(self) if self.wp then local P = Ink.modules.Professions; if P and P.Waypoint then P.Waypoint(self.wp) end end end)
	f.rows[i] = r
	return r
end

function M:Scroll(d)
	self.userScrolled = true
	local n = self.steps and #self.steps or 0
	local vis = self.f and math.floor((self.f.list:GetHeight() or 140) / 18) or 8
	self.off = math.max(0, math.min(math.max(0, n - vis), (self.off or 0) + d))
	self:PaintList()
end

function M:PaintList()
	local f, steps = self.f, self.steps
	if not (f and steps) then return end
	local cur = self.curI
	local vis = math.max(1, math.floor((f.list:GetHeight() or 140) / 18))
	for _, r in ipairs(f.rows) do r:Hide() end
	for k = 1, vis do
		local i = (self.off or 0) + k
		local s = steps[i]
		if not s then break end
		local r = Row(f, k)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, -(k - 1) * 18)
		r.s = s
		r.num:SetText(i)
		local up = s.up and ("|cffE3C07A" .. UP_LABEL[s.up] .. " 강화|r  ") or ""
		r.name:SetText(up .. s.title)
		local gname, txt, wp = Where(s.npc)
		r.where:SetText(gname and (gname .. (wp and "" or (" · " .. txt))) or "")
		r.wp = wp
		r.mark:Hide(); r.dot:Hide()
		if s.done then
			r.mark:SetTexture(Ink.icon("Check")); r.mark:SetVertexColor(C.green[1], C.green[2], C.green[3]); r.mark:Show()
			r.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
		elseif i == cur then
			r.dot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3]); r.dot:Show()
			r.name:SetTextColor(C.text[1], C.text[2], C.text[3])
		else
			r.dot:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 0.6); r.dot:Show()
			r.name:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
		end
		r:Show()
	end
	f.lh:SetText(string.format("전체 단계  |cff5E636B%d–%d / %d · 휠로 넘기기|r", (self.off or 0) + 1, math.min(#steps, (self.off or 0) + vis), #steps))
end

function M:Paint()
	local f = self.f
	if not (f and f:IsShown()) then return end
	local steps = self:Steps()
	self.steps = steps
	if not steps then
		self.head = { "-", "0.5티 세트 자료가 없는 직업이에요", "" }
		return
	end
	local d, fac = D(), MyFac()
	local cd = d.class[MyClass()]
	local curI, cur = Current(steps)
	if self.curI ~= curI then self.userScrolled = nil end   -- 단계가 바뀌면 목록을 다시 지금 단계로
	self.curI = curI
	-- 세트 이름: 첫 보상 이름 앞 낱말 (검은장막 팔보호구 → 검은장막)
	self.block = self:Block(cd)
	local rb = cd[1] and cd[1].reward and (cd[1].reward[self.block] or cd[1].reward[1])
	local first = (rb and rb[1]) or (cd[1] and cd[1].old and cd[1].old[1])
	-- (검은장막의 팔보호구 → 검은장막 · 무용의 → 무용)
	local setName = first and (ItemName(first):match("^(%S+)") or ""):gsub("의$", "") or "0.5티"
	if setName == "" then setName = "0.5티" end
	local nUp = 0
	for _, s in ipairs(steps) do if s.up and s.done then nUp = nUp + 1 end end
	local doneN = curI and (curI - 1) or #steps
	-- 머리말: 큰 숫자 = 강화 단계 · 옆 글 · 아래 한 줄
	self.head = { nUp .. " / 4", string.format("단계 · 퀘스트 %d/%d", doneN, #steps),
		setName .. " 세트  ·  손목 → 허리띠·장갑 → 장화·바지·어깨 → 모자·튜닉  ·  자료: AllTheThings · QuestieDB" }
	-- 카드
	local upStep = {}
	for i, s in ipairs(steps) do if s.up then upStep[s.up] = { i = i, s = s } end end
	for u = 1, 4 do
		local c, us = f.cards[u], upStep[u]
		c.label:SetText(UP_LABEL[u])
		local s = us and us.s
		local done = s and s.done
		local a = done and C.green or ((curI and us and curI == us.i) and C.accent or C.dim)
		c.top:SetColorTexture(a[1], a[2], a[3], done and 0.9 or 0.6)
		c.check:SetVertexColor(C.green[1], C.green[2], C.green[3])
		c.check:SetShown(done and true or false)
		for k = 1, 3 do
			local blocks = s and s.reward or {}
			local ids = blocks[self.block] or blocks[1] or {}
			local id = ids[k]
			local ic = c.icons[k]
			if id then
				ic:SetItem(id, not done)
				ic.extra = (done and "받음" or ("이 단계에서 받는 장비 · " .. UP_LABEL[u] .. " 강화"))
					.. (#blocks > 1 and string.format("\n특성마다 다른 묶음 중에서 골라 받아요 (%d가지) · 지금 특성 BIS 기준 묶음을 보여 줘요", #blocks) or "")
				ic:Show()
			else
				ic:Hide()
			end
		end
		if done then
			c.state:SetText("|cff6FD39A받음|r")
		elseif s then
			local need, have = 0, 0
			for _, it in ipairs(s.items) do
				-- 0티 장비(개수 1)만 센다 (재료 15개 등은 지금 할 일에서)
				if it[2] == 1 then need = need + 1; if Have(it[1]) > 0 then have = have + 1 end end
			end
			local nowTxt = (curI and us.i == curI) and "|cffFFF468지금|r · " or ""
			c.state:SetText(string.format("%s0티 %s%d/%d|r", nowTxt, have >= need and "|cff6FD39A" or "|cffDCE0E6", have, need))
		end
	end
	-- 지금 할 일
	local now = f.now
	for _, ch in ipairs(now.chips) do ch:Hide() end
	if not cur then
		now.k:SetText("다 끝냈어요")
		now.name:SetText(setName .. " 세트 8부위 강화 완료")
		now.where.t:SetText("")
		now.where.x = nil
		now.obj:SetText("")
	else
		now.k:SetText(string.format("지금 할 일  ·  %d단계%s", curI, cur.up and ("  ·  " .. UP_LABEL[cur.up] .. " 강화") or ""))
		local state = cur.ready and "  |cff6FD39A보고할 수 있어요|r" or (cur.log and "  |cffFFF468진행 중|r" or "  |cff8E939B받을 차례|r")
		now.name:SetText(cur.title .. state)
		-- 받기 전이거나 진행 중이면 시작 NPC, 다 했으면 보고 NPC
		local nid = (cur.ready and cur.e) or cur.npc
		local gname, txt, wp = Where(nid)
		now.where.t:SetText(gname and ((cur.ready and cur.e and "보고: " or "") .. gname .. "  ·  " .. txt .. (wp and "  |cff5E636B(누르면 지도)|r" or "")) or "")
		now.where.x = wp
		local objT = cur.obj ~= "" and cur.obj or "퀘스트 내용은 받은 뒤 퀘스트 목록에서 확인해 주세요"
		if cur.note and not cur.log then objT = objT .. "\n|cffE3C07A" .. cur.note .. "|r" end
		now.obj:SetText(objT)
		-- 재료 칩: 2열
		local k = 0
		local objH = math.min(42, (now.obj:GetStringHeight() or 12))
		local y0 = 55 + objH + 6
		for _, it in ipairs(cur.items) do
			k = k + 1
			local ch = Chip(now, k)
			local h = Have(it[1])
			ch.icon:SetItem(it[1], h < it[2])
			ch.icon.extra = nil
			ch.t:SetText(ItemName(it[1]) .. "  " .. (h >= it[2] and "|cff6FD39A" or "|cffDCE0E6") .. math.min(h, 999) .. "/" .. it[2] .. "|r")
			ch:SetWidth((W - 30) / 2)
			ch:ClearAllPoints()
			ch:SetPoint("TOPLEFT", 10 + ((k - 1) % 2) * ((W - 20) / 2), -(y0 + math.floor((k - 1) / 2) * 22))
			ch:Show()
		end
		if (cur.gold or 0) > 0 then
			k = k + 1
			local ch = Chip(now, k)
			ch.icon.itemID = nil
			ch.icon.tex:SetTexture(133784)
			ch.icon.tex:SetDesaturated(false); ch.icon.tex:SetAlpha(1)
			ch.icon.bd:SetVertexColor(1, 0.82, 0.32, 0.9)
			local ok = (GetMoney and GetMoney() or 0) >= cur.gold
			ch.t:SetText(Money(cur.gold) .. "  " .. (ok and "|cff6FD39A있음|r" or "|cffFF6B5E모자람|r"))
			ch:SetWidth((W - 30) / 2)
			ch:ClearAllPoints()
			ch:SetPoint("TOPLEFT", 10 + ((k - 1) % 2) * ((W - 20) / 2), -(y0 + math.floor((k - 1) / 2) * 22))
			ch:Show()
		end
	end
	-- 지금 할 일 상자 높이 = 글 + 재료 칩 줄 (아래 목록이 그만큼 내려간다)
	do
		local nChip = 0
		for _, ch in ipairs(now.chips) do if ch:IsShown() then nChip = nChip + 1 end end
		local objH = math.min(42, (now.obj:GetStringHeight() or 12))
		now:SetHeight(math.max(78, 55 + objH + 6 + math.ceil(nChip / 2) * 22 + 4))
	end
	-- 목록: 지금 단계가 보이게
	local vis = math.max(1, math.floor((f.list:GetHeight() or 140) / 18))
	if curI and (curI <= (self.off or 0) or curI > (self.off or 0) + vis) and not self.userScrolled then
		self.off = math.max(0, math.min(#steps - vis, curI - 2))
	end
	self:PaintList()
end

-- BIS 창이 부른다: 이 보기면 만들고 그리기, 아니면 숨김
function M:Show(p, on)
	if not D() then
		if self.f then self.f:Hide() end
		return
	end
	if not on then
		if self.f then self.f:Hide() end
		return
	end
	self.p = p
	self:Build(p)
	self.f:Show()
	self:Paint()
	local h = self.head
	if h and p.sumN then
		p.sumN:SetText(h[1]); p.sumL:SetText(h[2]); p.example:SetText(h[3])
	end
end

function M:Init()
	if not D() then return end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "GET_ITEM_INFO_RECEIVED" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local pend
	e:SetScript("OnEvent", function()
		if not (M.f and M.f:IsShown()) or pend then return end
		pend = true
		C_Timer.After(0.4, function() pend = nil; if M.p and M.f and M.f:IsShown() then pcall(M.Show, M, M.p, true) end end)
	end)
end
