-- InkUI · 퀘스트 목록 (시안 스타일로 직접 그림. 던전/시나리오 안에서는 블리자드 목표 추적기를 그대로 사용)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Quest")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

local W, MAX_OBJ = 240, 3
-- 한 번에 보이는 퀘스트 수 (설정 → 지도 · 퀘스트 → 한 번에 보이는 수, 3~10)
local function MaxQuests() return math.max(3, math.min(10, tonumber(Ink.db and Ink.db.questMax) or 6)) end

local function CleanObjective(text)
	if not text then return "" end
	local t = text
	t = t:gsub("^%s*%d+%s*/%s*%d+%s*", "")
	t = t:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
	t = t:gsub("^%s*%-%s*", "")
	return t
end

-------------------------------------------------------------------------------
-- 생성
-------------------------------------------------------------------------------
function M:Build()
	local f = CreateFrame("Frame", "InkUIQuest", Ink.root)
	f:SetSize(W, 40)
	f.title = Ink:Text(f, F.semi, 11, C.muted, "LEFT")
	f.title:SetPoint("TOPLEFT", 0, 0)
	f.title:SetText("퀘스트")
	f.count = Ink:Text(f, F.latin, 11, C.muted, "RIGHT")
	f.count:SetPoint("TOPRIGHT", 0, 0)
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetColorTexture(1, 1, 1, 0.10)
	f.line:SetHeight(1)
	f.line:SetPoint("TOPLEFT", 0, -20)
	f.line:SetPoint("TOPRIGHT", 0, -20)
	f.rows = {}
	-- 6개보다 많으면 휠로 넘겨 보기
	f.more = Ink:Text(f, F.sans, 10, C.muted, "LEFT")
	f.more:Hide()
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta)
		if InCombatLockdown() then return end
		M.offset = math.max(0, (M.offset or 0) - delta)
		M:Update()
	end)
	self.frame = f
end

-- 퀘스트 종류 표시: (정예) (던전) (공격대) …
local TAG_COLOR = { 1.00, 0.72, 0.35 }
local function QuestTag(id)
	if type(id) ~= "number" or not C_QuestLog.GetQuestTagInfo then return end
	local ok, info = pcall(C_QuestLog.GetQuestTagInfo, id)
	if ok and info and info.tagName and info.tagName ~= "" then return info.tagName end
end

local function ObjectiveLine(row, i)
	local o = row.objs[i]
	if o then return o end
	o = CreateFrame("Frame", nil, row)
	o:SetSize(W, 16)
	o.text = Ink:Text(o, F.sans, 11, C.soft, "LEFT")
	o.text:SetPoint("TOPLEFT")
	o.text:SetWidth(W - 50)
	o.count = Ink:Text(o, F.latin, 10, C.soft, "RIGHT")
	o.count:SetPoint("TOPRIGHT")
	-- 진행 막대: 숫자 아래 짧게 (전체 폭이면 퀘스트 사이 구분선처럼 보여서)
	o.bar = Ink:Bar(o, 54, 3, C.accent, { 1, 1, 1, 0.1 })
	o.bar:SetPoint("TOPRIGHT", 0, -15)
	row.objs[i] = o
	return o
end

local function Row(i)
	local f = M.frame
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, f)
	r:SetSize(W, 20)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r.title = Ink:Text(r, F.semi, 12, C.text, "LEFT")
	r.title:SetPoint("TOPLEFT")
	r.title:SetWidth(W - 30)
	r.mark = r:CreateTexture(nil, "ARTWORK")
	r.mark:SetSize(5, 5)
	r.mark:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	r.mark:SetPoint("RIGHT", r.title, "LEFT", -6, 0)
	r.mark:SetRotation(math.rad(45))
	r.objs = {}
	-- 퀘스트 사이 구분선 (모든 퀘스트 사이에 똑같이, 아주 옅게)
	r.div = r:CreateTexture(nil, "BACKGROUND")
	r.div:SetColorTexture(1, 1, 1, 0.07)
	r.div:SetHeight(1)
	r.div:SetPoint("BOTTOMLEFT", r, "TOPLEFT", 0, 6)
	r.div:SetPoint("BOTTOMRIGHT", r, "TOPRIGHT", 0, 6)
	r:SetScript("OnClick", function(self, btn)
		local id = self.questID
		if not id then return end
		if btn == "RightButton" then
			M:AbandonQuest(id)
		elseif IsShiftKeyDown() then
			if C_QuestLog.RemoveQuestWatch then C_QuestLog.RemoveQuestWatch(id) end
		else
			M:ShowQuest(id)
		end
	end)
	r:SetScript("OnEnter", function(self)
		self.title:SetAlpha(0.8)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(self.title:GetText() or "", 1, 1, 1)
		Ink.TipLine(GameTooltip, "클릭: 퀘스트 보기 · 우클릭: 퀘스트 포기 · Shift 클릭: 목록에서 빼기", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function(self) self.title:SetAlpha(1); GameTooltip:Hide() end)

	-- 퀘스트 아이템 사용 버튼 (전투 밖에서만 갱신)
	-- 보안 버튼이라 줄(r)의 자식으로 두면 줄 전체가 보호 프레임이 되어 전투 중 Show가 막힌다 → 목록 프레임의 자식으로
	r.item = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
	r.item:SetSize(22, 22)
	-- 위치는 Update에서 목록 프레임(f) 기준으로 잡는다. 줄(r)에 붙이면 줄도 보호 프레임이 된다.
	r.item:SetAttribute("type", "item")
	r.item:RegisterForClicks("AnyUp", "AnyDown")
	r.item.icon = r.item:CreateTexture(nil, "ARTWORK")
	r.item.icon:SetPoint("TOPLEFT", 1, -1)
	r.item.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	Ink:IconSkin(r.item, r.item.icon, true)
	r.item.cd = CreateFrame("Cooldown", nil, r.item, "CooldownFrameTemplate")
	r.item.cd:SetAllPoints(r.item.icon)
	Ink:SkinCooldown(r.item.cd, true)
	r.item:SetScript("OnEnter", function(self)
		if not self.link then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end)
	r.item:SetScript("OnLeave", GameTooltip_Hide)
	r.item:Hide()

	f.rows[i] = r
	return r
end

-------------------------------------------------------------------------------
-- 갱신
-------------------------------------------------------------------------------
-- 퀘스트 포기: 블리자드 확인 창을 띄운다 (바로 지우지 않는다)
-- 퀘스트 보기: 퀘스트 상세 창(팝업)으로. 지도 속 퀘스트 목록을 애드온 코드로 열면 지도 핀이 오염돼서
--  전투 중 막힘(SetPassThroughButtons)이 생기므로, 팝업이 없으면 지도만 깨끗하게 열고 그 퀘스트를 추적으로
function M:ShowQuest(id)
	local idx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
	if idx and QuestLogPopupDetailFrame_Show and not InCombatLockdown() then
		local ok = pcall(QuestLogPopupDetailFrame_Show, idx)
		if ok then return end
	end
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then pcall(C_SuperTrack.SetSuperTrackedQuestID, id) end
	local mapID = (GetQuestUiMapID and GetQuestUiMapID(id)) or C_Map.GetBestMapForUnit("player")
	if mapID and mapID ~= 0 then Ink:OpenMap(mapID) end
end

function M:AbandonQuest(id)
	if type(id) ~= "number" then return end
	if QuestMapQuestOptions_AbandonQuest and pcall(QuestMapQuestOptions_AbandonQuest, id) then return end
	local title = C_QuestLog.GetTitleForQuestID(id) or ""
	if C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest then
		C_QuestLog.SetSelectedQuest(id)
		C_QuestLog.SetAbandonQuest()
		local items = C_QuestLog.GetAbandonQuestItems and C_QuestLog.GetAbandonQuestItems()
		if items and StaticPopupDialogs and StaticPopupDialogs["ABANDON_QUEST_WITH_ITEMS"] then
			StaticPopup_Hide("ABANDON_QUEST")
			StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", title, items)
		else
			if StaticPopup_Hide then StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS") end
			StaticPopup_Show("ABANDON_QUEST", title)
		end
	elseif SelectQuestLogEntry and SetAbandonQuest then
		local idx = C_QuestLog.GetLogIndexForQuestID(id)
		if not idx then return end
		SelectQuestLogEntry(idx)
		SetAbandonQuest()
		StaticPopup_Show("ABANDON_QUEST", (GetAbandonQuestName and GetAbandonQuestName()) or title)
	end
end

-- 퀘스트 레벨 색 (이름표 레벨과 같은 색): 빨강 +5 · 주황 +3 · 노랑 ±2 · 초록 · 회색
local LVL_COL = {
	red = { 1.00, 0.42, 0.37 }, orange = { 1.00, 0.62, 0.30 }, yellow = { 1.00, 0.86, 0.36 },
	green = { 0.44, 0.83, 0.55 }, gray = { 0.56, 0.58, 0.61 },
}
local function LevelColor(lv)
	local me = UnitLevel("player") or 1
	local d = lv - me
	if d >= 5 then return LVL_COL.red elseif d >= 3 then return LVL_COL.orange elseif d >= -2 then return LVL_COL.yellow end
	local green = (GetQuestGreenRange and GetQuestGreenRange()) or ((me <= 5) and 5 or (me <= 39 and (math.floor(me / 10) + 5) or (math.floor(me / 5) + 1)))
	return (-d <= green) and LVL_COL.green or LVL_COL.gray
end
M.LevelColor = LevelColor

-- 퀘스트 목록의 지역 머리줄 → [퀘스트] = { 지역, 레벨 }, 지역 순서
local function QuestLogInfo()
	local map, order, zone = {}, {}, nil
	local n = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
	for i = 1, n do
		local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
		if info then
			if info.isHeader then
				zone = info.title
				if zone and not order[zone] then order[#order + 1] = zone; order[zone] = #order end
			elseif info.questID then
				map[info.questID] = { zone = zone, level = info.level }
			end
		end
	end
	return map, order
end

local function WatchedQuests()
	local list = {}
	local n = C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches() or 0
	for i = 1, n do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
		if id then table.insert(list, id) end
	end
	return list
end

-------------------------------------------------------------------------------
-- 직업 퀘스트 (포에버): 지금 받을 수 있는 내 직업 퀘스트 + 다음에 열리는 것 → 목록 맨 위에
--  · 진행 중인 직업 퀘스트는 자동으로 추적하고 목록 맨 위로, 이름 옆에 (직업)
-------------------------------------------------------------------------------
local function ClassRGB()
	local _, cls = UnitClass("player")
	local c = cls and (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(cls) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]))
	if c then return { c.r, c.g, c.b } end
	return { C.accent[1], C.accent[2], C.accent[3] }
end
local function ClassSet()
	local Q = Ink.modules.QuestMap
	if Ink.db.questClass == false or not (Q and Q.ClassSet and ns.QUEST_DB) then return nil end
	return Q:ClassSet()
end

local function ClassRow(i)
	local f = M.frame
	f.crow = f.crow or {}
	local r = f.crow[i]
	if r then return r end
	r = CreateFrame("Button", nil, f)
	r:SetSize(W, 32)
	r.title = Ink:Text(r, F.semi, 12, C.text, "LEFT")
	r.title:SetPoint("TOPLEFT", 0, 0)
	r.title:SetPoint("RIGHT", -22, 0)
	r.title:SetWordWrap(false)
	r.sub = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
	r.sub:SetPoint("TOPLEFT", 0, -17)
	r.sub:SetPoint("RIGHT", -22, 0)
	r.sub:SetWordWrap(false)
	r.pin = r:CreateTexture(nil, "ARTWORK")
	r.pin:SetTexture(Ink.icon("MapPin"))
	r.pin:SetSize(12, 12)
	r.pin:SetPoint("TOPRIGHT", -2, -2)
	r:SetScript("OnClick", function(self)
		local Q = Ink.modules.QuestMap
		if self.e and Q and Q.Waypoint then Q:Waypoint({ mapID = self.e.map, wx = self.e.x, wy = self.e.y }) end
	end)
	r:SetScript("OnEnter", function(self)
		self.pin:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
		self.title:SetAlpha(0.85)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(self.title:GetText() or "", 1, 1, 1)
		if self.giver then GameTooltip:AddLine(self.giver, 1, 0.82, 0.32) end
		GameTooltip:AddLine(self.where or "", 0.7, 0.72, 0.75)
		if self.alts and self.alts > 0 then GameTooltip:AddLine("다른 도시에서도 " .. self.alts .. "곳 더 시작할 수 있어요 (가장 가까운 곳)", 0.7, 0.72, 0.75) end
		GameTooltip:AddLine(self.soon and "레벨이 되면 받을 수 있어요 · 클릭: 길 안내 표시" or "클릭: 길 안내 표시", 0.56, 0.58, 0.61)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function(self)
		self.pin:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.7)
		self.title:SetAlpha(1)
		GameTooltip:Hide()
	end)
	f.crow[i] = r
	return r
end

-- 직업 퀘스트 칸을 그리고 높이를 돌려준다
function M:PaintClass(y)
	local f = self.frame
	local Q = Ink.modules.QuestMap
	local list = {}
	if ClassSet() and Q.ClassQuests then
		local avail, nextQ = Q:ClassQuests()
		for i = 1, math.min(3, #avail) do list[#list + 1] = avail[i] end
		if nextQ and #list < 3 then nextQ.soon = true; list[#list + 1] = nextQ end
	end
	if self.testing and #list == 0 then
		list = { { id = 0, lvl = 16, map = 1453, x = 0.78, y = 0.7, test = "도적의 시험" }, { id = 0, lvl = 20, map = 1453, x = 0.78, y = 0.7, soon = true, test = "데피아즈 밀서" } }
	end
	if not f.chead then
		local h = CreateFrame("Frame", nil, f)
		h:SetSize(W, 14)
		h.dot = h:CreateTexture(nil, "ARTWORK")
		h.dot:SetSize(5, 5)
		h.dot:SetPoint("LEFT", 1, 0)
		h.dot:SetColorTexture(1, 1, 1, 1)
		h.dot:SetRotation(math.rad(45))
		h.t = Ink:Text(h, F.semi, 10, C.muted, "LEFT")
		h.t:SetPoint("LEFT", h.dot, "RIGHT", 6, 0)
		h.line = h:CreateTexture(nil, "ARTWORK")
		h.line:SetHeight(1)
		h.line:SetPoint("LEFT", h.t, "RIGHT", 8, 0)
		h.line:SetPoint("RIGHT", 0, 0)
		f.chead = h
	end
	local h = f.chead
	for _, r in ipairs(f.crow or {}) do r:Hide() end
	if #list == 0 then h:Hide() return 0 end
	local rgb = ClassRGB()
	local cname = UnitClass("player") or ""
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	h.dot:SetVertexColor(rgb[1], rgb[2], rgb[3], 1)
	h.t:SetText("직업 퀘스트  |cff" .. string.format("%02x%02x%02x", math.floor(rgb[1] * 255), math.floor(rgb[2] * 255), math.floor(rgb[3] * 255)) .. cname .. "|r")
	h.line:SetColorTexture(rgb[1], rgb[2], rgb[3], 0.18)
	h:Show()
	local cy = y - 20
	for i, e in ipairs(list) do
		local r = ClassRow(i)
		r.e = e
		local title = e.test or (Q and Q.QuestTitle and Q:QuestTitle(e.id)) or "직업 퀘스트"
		r.title:SetText(title)
		local col = e.soon and C.muted or C.text
		r.title:SetTextColor(col[1], col[2], col[3])
		local info = C_Map.GetMapInfo and C_Map.GetMapInfo(e.map)
		local zone = info and info.name or ""
		r.giver = e.npc and e.npc ~= 0 and Q and Q.GiverName and Q:GiverName(e.npc) or nil
		r.where = zone .. string.format("  %.1f, %.1f", e.x * 100, e.y * 100)
		r.soon = e.soon
		local lv = e.soon and ("|cffFFB75A" .. e.lvl .. "레벨부터|r") or (e.lvl .. "레벨")
		r.sub:SetText(lv .. "  ·  " .. zone .. (r.giver and ("  ·  " .. r.giver) or ""))
		r.alts = e.alts
		r.pin:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.7)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, cy)
		r:Show()
		cy = cy - 36
	end
	return -(cy - y) + 6
end

-- 지역 머리줄: 점 · 지역 이름 · 옅은 선 · 개수
function M:ZoneHead(i)
	local f = self.frame
	f.zheads = f.zheads or {}
	local h = f.zheads[i]
	if h then return h end
	h = CreateFrame("Frame", nil, f)
	h:SetSize(W, 14)
	h.t = Ink:Text(h, F.semi, 10, C.muted, "LEFT")
	h.t:SetPoint("LEFT", 0, 0)
	h.n = Ink:Text(h, F.latin, 10, C.dim, "RIGHT")
	h.n:SetPoint("RIGHT", 0, 0)
	h.line = h:CreateTexture(nil, "ARTWORK")
	h.line:SetHeight(1)
	h.line:SetPoint("LEFT", h.t, "RIGHT", 8, 0)
	h.line:SetPoint("RIGHT", h.n, "LEFT", -6, 0)
	f.zheads[i] = h
	return h
end

function M:Update()
	local f = self.frame
	if not f or not f:IsShown() then return end
	local quests = WatchedQuests()
	if #quests == 0 and self.testing then quests = { "test1", "test2" } end
	-- 지역별로 묶기: 진행 중인 직업 퀘스트 → 지금 있는 지역 → 퀘스트 목록 순서
	local cset = ClassSet()
	local qinfo, zorder = QuestLogInfo()
	local here = GetRealZoneText and GetRealZoneText() or ""
	local CLASSG, OTHER = "\001직업", "기타"
	local group = {}
	if self.testing and not next(qinfo) then
		qinfo = { test1 = { zone = "죽음의 폐광", level = 20 }, test2 = { zone = "서부 몰락지대", level = 16 } }
	end
	for _, id in ipairs(quests) do
		local q = qinfo[id]
		group[id] = (cset and cset[id]) and CLASSG or (q and q.zone) or OTHER
	end
	local function rank(g)
		if g == CLASSG then return 0 elseif g == here then return 1 elseif zorder[g] then return 2 + zorder[g] end
		return 999
	end
	local pos = {}
	for i, id in ipairs(quests) do pos[id] = i end
	table.sort(quests, function(a, b)
		local ra, rb = rank(group[a]), rank(group[b])
		if ra ~= rb then return ra < rb end
		return pos[a] < pos[b]
	end)
	local gcount = {}
	for _, id in ipairs(quests) do gcount[group[id]] = (gcount[group[id]] or 0) + 1 end
	local lastG
	local nh = 0
	local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
	local maxQ = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 35
	f.count:SetText(string.format("%d / %d", numQuests or 0, maxQ))
	local super = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	local combat = InCombatLockdown()
	if combat and #quests ~= (self.lastCount or 0) then self.dirty = true end

	local y = -32
	if not combat then self.classH = self:PaintClass(y) end
	y = y - (self.classH or 0)
	local shown = 0
	local total = #quests
	local MAX_QUESTS = MaxQuests()
	local offset = math.max(0, math.min(self.offset or 0, total - MAX_QUESTS))
	if combat then offset = self.shownOffset or offset end
	self.offset, self.shownOffset = offset, offset
	for qi, id in ipairs(quests) do
		if qi > offset + MAX_QUESTS then break end
		if qi > offset then
		local idx = qi - offset
		shown = idx
		local r = Row(idx)
		local g = group[id]
		local newG = (g ~= lastG)
		if newG then
			lastG = g
			nh = nh + 1
			if not combat then
				local h = self:ZoneHead(nh)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - ((idx > 1 or (self.classH or 0) > 0) and 4 or 0))
				if g == CLASSG then
					local rgb = ClassRGB()
					h.t:SetText("직업 퀘스트 진행 중")
					h.t:SetTextColor(rgb[1], rgb[2], rgb[3])
					h.line:SetColorTexture(rgb[1], rgb[2], rgb[3], 0.18)
				else
					h.t:SetText(g)
					local hc = (g == here) and C.soft or C.muted
					h.t:SetTextColor(hc[1], hc[2], hc[3])
					h.line:SetColorTexture(1, 1, 1, 0.08)
				end
				h.n:SetText(tostring(gcount[g] or ""))
				h:Show()
			end
			y = y - ((idx > 1 or (self.classH or 0) > 0) and 26 or 22)
		end
		if not combat then
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
			r.item:ClearAllPoints()
			r.item:SetPoint("TOPRIGHT", f, "TOPLEFT", -12, y + 2)
		end
		r.questID = type(id) == "number" and id or nil
		local title, objs, complete
		if id == "test1" then
			title, complete = "데피아즈단 소탕", false
			objs = { { text = "데피아즈단 마법사 처치", numFulfilled = 3, numRequired = 8, type = "monster" } }
		elseif id == "test2" then
			title, complete = "광산 조사", false
			objs = { { text = "광산 입구 탐색", numFulfilled = 0, numRequired = 1, type = "event" } }
		else
			title = C_QuestLog.GetTitleForQuestID(id) or ""
			objs = C_QuestLog.GetQuestObjectives(id) or {}
			complete = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id) or C_QuestLog.IsComplete(id)
			if complete and #objs == 0 and self:Fresh(id) then complete = false end
		end
		local tag = QuestTag(id)
		local qi2 = qinfo[id]
		local lvp = ""
		if qi2 and type(qi2.level) == "number" and qi2.level > 0 then
			local lc = LevelColor(qi2.level)
			lvp = string.format("|cff%02x%02x%02x%d|r  ", math.floor(lc[1] * 255), math.floor(lc[2] * 255), math.floor(lc[3] * 255), qi2.level)
		end
		title = lvp .. title
		if cset and cset[id] then
			local rgb = ClassRGB()
			r.title:SetText(string.format("%s |cff%02x%02x%02x(직업)|r", title, math.floor(rgb[1] * 255), math.floor(rgb[2] * 255), math.floor(rgb[3] * 255)))
		elseif tag then
			r.title:SetText(string.format("%s |cff%02x%02x%02x(%s)|r", title, TAG_COLOR[1] * 255, TAG_COLOR[2] * 255, TAG_COLOR[3] * 255, tag))
		else
			r.title:SetText(title)
		end
		r.div:SetShown(not newG and (idx > 1 or (self.classH or 0) > 0))
		local isSuper = (super == id)
		r.title:SetTextColor(isSuper and C.accent[1] or C.text[1], isSuper and C.accent[2] or C.text[2], isSuper and C.accent[3] or C.text[3])
		r.mark:SetShown(isSuper)

		local oy = -20
		local used = 0
		if complete then
			used = 1
			local o = ObjectiveLine(r, 1)
			o:ClearAllPoints()
			o:SetPoint("TOPLEFT", r, "TOPLEFT", 0, oy)
			o.text:SetText("완료 · 보고하러 가기")
			o.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
			o.count:SetText("")
			o.bar:Hide()
			o:Show()
			oy = oy - 18
		else
			for oi, ob in ipairs(objs) do
				if used < MAX_OBJ and (not ob.finished or #objs <= MAX_OBJ) then
					used = used + 1
					local o = ObjectiveLine(r, used)
					o:ClearAllPoints()
					o:SetPoint("TOPLEFT", r, "TOPLEFT", 0, oy)
					local req, ful = ob.numRequired or 0, ob.numFulfilled or 0
					o.text:SetText(CleanObjective(ob.text))
					local col = ob.finished and C.dim or C.soft
					o.text:SetTextColor(col[1], col[2], col[3])
					o.count:SetTextColor(col[1], col[2], col[3])
					if ob.type == "progressbar" and GetQuestProgressBarPercent then
						local pct = GetQuestProgressBarPercent(id) or 0
						o.count:SetFont(F.latin, 10, "")
						o.count:SetText(math.floor(pct) .. "%")
						req, ful = 100, pct
					elseif req >= 1 then
						-- 1개짜리 목표도 0/1 처럼 숫자는 보여준다 (진행바는 2개 이상일 때만)
						o.count:SetFont(F.latin, 10, "")
						o.count:SetText(ful .. "/" .. req)
					else
						o.count:SetText(ob.finished and "완료" or "")
						o.count:SetFont(F.sans, 10, "")
					end
					if req > 1 then
						o.bar:SetMinMaxValues(0, req)
						o.bar:SetValue(ful)
						local bc = ob.finished and C.green or C.accent
						o.bar:SetStatusBarColor(bc[1], bc[2], bc[3], ob.finished and 0.8 or 0.9)
						o.text:SetWidth(W - 66)
						o.bar:Show()
						oy = oy - 20
					else
						o.text:SetWidth(W - 50)
						o.bar:Hide()
						oy = oy - 16
					end
					o:Show()
				end
			end
		end
		for oi = used + 1, #r.objs do r.objs[oi]:Hide() end

		-- 퀘스트 아이템
		if not combat then
			local link, icon
			if r.questID then
				local logIndex = C_QuestLog.GetLogIndexForQuestID(r.questID)
				if logIndex and GetQuestLogSpecialItemInfo then link, icon = GetQuestLogSpecialItemInfo(logIndex) end
			end
			if link then
				r.item.link = link
				r.item.icon:SetTexture(icon)
				r.item:SetAttribute("item", link)
				r.item:Show()
				local start, dur
				if GetQuestLogSpecialItemCooldown then
					start, dur = GetQuestLogSpecialItemCooldown(C_QuestLog.GetLogIndexForQuestID(r.questID))
				end
				if plain(start) and plain(dur) and dur > 0 then r.item.cd:SetCooldown(start, dur) else r.item.cd:Clear() end
			else
				r.item.link = nil
				r.item:SetAttribute("item", nil)
				r.item:Hide()
			end
			r:SetHeight(-oy)
		end
		r:Show()
		y = y + oy - 10
		end
	end
	-- 위 · 아래에 더 있으면 안내
	local above, below = offset, math.max(0, total - offset - MAX_QUESTS)
	if (above > 0 or below > 0) and not combat then
		f.more:ClearAllPoints()
		f.more:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y + 4)
		local parts = {}
		if above > 0 then parts[#parts + 1] = "위에 " .. above .. "개" end
		if below > 0 then parts[#parts + 1] = "아래 " .. below .. "개 더" end
		f.more:SetText(table.concat(parts, "  ·  ") .. "  (휠로 넘기기)")
		f.more:Show()
		y = y - 14
	elseif not combat then
		f.more:Hide()
	end
	if not combat then
		for i = shown + 1, #f.rows do
			f.rows[i]:Hide()
			f.rows[i].item:Hide()
		end
		for i = nh + 1, #(f.zheads or {}) do f.zheads[i]:Hide() end
		f:SetHeight(-y)
	end
	self.lastCount = #quests
	f:SetAlpha((shown > 0 or (self.classH or 0) > 0) and 1 or 0)
end

-- 진행 중인 내 직업 퀘스트는 자동으로 추적
function M:WatchClass(id)
	local cset = ClassSet()
	if not cset then return end
	local function watch(qid)
		if not cset[qid] then return end
		if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(qid) ~= nil then return end
		if C_QuestLog.IsQuestWatched and C_QuestLog.IsQuestWatched(qid) then return end
		if C_QuestLog.AddQuestWatch then
			pcall(C_QuestLog.AddQuestWatch, qid)
		elseif AddQuestWatch and C_QuestLog.GetLogIndexForQuestID then
			local idx = C_QuestLog.GetLogIndexForQuestID(qid)
			if idx then pcall(AddQuestWatch, idx) end
		end
	end
	if id then watch(id) return end
	local n = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
	for i = 1, n do
		local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID then watch(info.questID) end
	end
end

-- 던전 / 시나리오 / 전장에서는 블리자드 목표 추적기를 쓰고, 그 밖에서는 Ink 목록을 쓴다
function M:UpdateMode()
	if InCombatLockdown() then
		self.modeDirty = true
		return
	end
	local inInstance, kind = IsInInstance()
	local scenario = C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario()
	-- 던전 · 공격대 안에서도 FOA 목록을 쓴다. 블리자드 목표 추적기는 시나리오(던전 · 공격대가 아닌 것)에서만
	local useBlizzard = scenario and not (inInstance and (kind == "party" or kind == "raid"))
	local otf = ObjectiveTrackerFrame
	M.hideOTF = not useBlizzard
	if otf and not M.otfAlphaHook then
		-- 파티에 들어가거나 블리자드가 다시 보이게 해도 FOA 목록을 쓰는 동안은 투명하게
		M.otfAlphaHook = true
		hooksecurefunc(otf, "SetAlpha", function(self, a)
			if M.hideOTF and a and a > 0 and not M.otfBusy then
				M.otfBusy = true; self:SetAlpha(0); M.otfBusy = nil
			end
		end)
		otf:HookScript("OnShow", function(self)
			if M.hideOTF then
				M.otfBusy = true; self:SetAlpha(0); M.otfBusy = nil
				if InCombatLockdown() then M.modeDirty = true end
			end
		end)
	end
	if otf then
		if useBlizzard then
			M.otfBusy = true
			otf:SetAlpha(1)
			M.otfBusy = nil
			if not otf:IsShown() then safe(otf.Show, otf) end
		else
			otf:SetAlpha(0)
			if otf:IsShown() then safe(otf.Hide, otf) end
		end
	end
	self.frame:SetShown(not useBlizzard)
	self:Update()
end

-------------------------------------------------------------------------------
-- 퀘스트 목표를 다 채우면: 소리 + 화면 위에 잠깐 알림 (레벨업 알림처럼)
-------------------------------------------------------------------------------
function M:BuildToast()
	local t = CreateFrame("Frame", "FOAQuestDone", Ink.root)
	t:SetSize(340, 64)
	t:SetPoint("TOP", Ink.root, "TOP", 0, -210)
	t:SetFrameStrata("HIGH")
	t:EnableMouse(false)
	t.bg = Ink:Round(t, "BACKGROUND", false, false)
	t.bg:SetAllPoints()
	t.bg:SetVertexColor(0.04, 0.045, 0.06, 0.92)
	t.bd = Ink:Round(t, "BORDER", false, true)
	t.bd:SetAllPoints()
	t.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.55)
	t.glow = t:CreateTexture(nil, "BACKGROUND", nil, -2)
	t.glow:SetTexture(Ink.tex.glow)
	t.glow:SetPoint("TOPLEFT", -24, 20)
	t.glow:SetPoint("BOTTOMRIGHT", 24, -20)
	t.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.35)
	t.ring = t:CreateTexture(nil, "ARTWORK")
	t.ring:SetTexture(Ink.tex.ring)
	t.ring:SetSize(34, 34)
	t.ring:SetPoint("LEFT", 16, 0)
	t.ring:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
	t.icon = t:CreateTexture(nil, "OVERLAY")
	t.icon:SetTexture(Ink.icon("Check"))
	t.icon:SetSize(16, 16)
	t.icon:SetPoint("CENTER", t.ring, "CENTER")
	t.icon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	t.tag = Ink:Text(t, F.latinB, 10, C.accent, "LEFT")
	t.tag:SetPoint("TOPLEFT", t.ring, "TOPRIGHT", 14, 2)
	t.tag:SetText("QUEST COMPLETE")
	t.title = Ink:Text(t, F.bold, 14, C.text, "LEFT")
	t.title:SetPoint("TOPLEFT", t.tag, "BOTTOMLEFT", 0, -3)
	t.title:SetWidth(250)
	t.sub = Ink:Text(t, F.sans, 10, C.soft, "LEFT")
	t.sub:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -3)
	t.sub:SetText("목표 완료 · 보고하러 가세요")
	t:Hide()
	local ag = t:CreateAnimationGroup()
	local m0 = ag:CreateAnimation("Translation"); m0:SetOrder(1); m0:SetDuration(0); m0:SetOffset(0, 16)
	local a0 = ag:CreateAnimation("Alpha"); a0:SetOrder(1); a0:SetDuration(0); a0:SetFromAlpha(0); a0:SetToAlpha(0)
	local s0 = ag:CreateAnimation("Scale"); s0:SetOrder(1); s0:SetDuration(0); s0:SetScaleFrom(0.92, 0.92); s0:SetScaleTo(0.92, 0.92)
	local m1 = ag:CreateAnimation("Translation"); m1:SetOrder(2); m1:SetDuration(0.35); m1:SetSmoothing("OUT"); m1:SetOffset(0, -16)
	local a1 = ag:CreateAnimation("Alpha"); a1:SetOrder(2); a1:SetDuration(0.3); a1:SetFromAlpha(0); a1:SetToAlpha(1)
	local s1 = ag:CreateAnimation("Scale"); s1:SetOrder(2); s1:SetDuration(0.35); s1:SetSmoothing("OUT"); s1:SetScaleFrom(0.92, 0.92); s1:SetScaleTo(1, 1)
	local a2 = ag:CreateAnimation("Alpha"); a2:SetOrder(3); a2:SetStartDelay(3.2); a2:SetDuration(0.6); a2:SetFromAlpha(1); a2:SetToAlpha(0)
	ag:SetScript("OnFinished", function() t:Hide() end)
	t.ag = ag
	self.toast = t
end

function M:QuestDone(title, demo)
	if Ink.db.questToast == false and not demo then return end
	if not self.toast then self:BuildToast() end
	local t = self.toast
	t.title:SetText(title or "")
	t:SetAlpha(1)
	t:Show()
	t.ag:Stop()
	t.ag:Play()
	M:PlayDoneSound()
end

-- 완료 소리: random(목소리 셋 중 하나) / done("완료~") / gg("GG~") / next("다음은 어디야?") / game(게임 효과음) / off
local VOICE = { done = "QuestDone_done", gg = "QuestDone_gg", next = "QuestDone_next" }
M.SOUNDS = { "random", "done", "gg", "next", "game", "off" }
M.SOUND_NAME = { random = "목소리 랜덤", done = "완료~", gg = "GG~", next = "다음은 어디야?", game = "게임 효과음", off = "끔" }
function M:PlayDoneSound(which)
	local k = which or Ink.db.questSound or "random"
	if k == "off" then return end
	if k == "random" then
		local keys = { "done", "gg", "next" }
		k = keys[math.random(#keys)]
	end
	if VOICE[k] then
		pcall(PlaySoundFile, "Interface\\AddOns\\FOA_UI\\Media\\Sounds\\" .. VOICE[k] .. ".ogg", "Master")
	else
		local kit = (SOUNDKIT and (SOUNDKIT.UI_QUEST_COMPLETE or SOUNDKIT.IG_QUEST_LIST_COMPLETE)) or 878
		pcall(PlaySound, kit, "Master")
	end
end

-- 퀘스트 로그를 훑어서 "방금 완료 상태가 된" 퀘스트를 찾는다
function M:Fresh(id)
	local t = self.acceptedAt and self.acceptedAt[id]
	return t and (GetTime() - t < 6) or false
end

function M:CheckDone()
	local now = {}
	local n = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
	for i = 1, n do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID and info.questID > 0 and not info.isHidden then
			local id = info.questID
			local done = (C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id)) or C_QuestLog.IsComplete(id)
			if M:Fresh(id) then done = nil end
			now[id] = (done == nil) and nil or (done and true or false)
			local objs = C_QuestLog.GetQuestObjectives(id)
			-- 목표가 없는 퀘스트(바로 보고하는 심부름)는 받자마자 완료라 알리지 않는다
			if done and self.doneState and self.doneState[id] == false and objs and #objs > 0 then
				self:QuestDone(info.title)
			end
		end
	end
	self.doneState = now
end

function M:SetTest(on)
	self.testing = on
	self:Update()
end

-------------------------------------------------------------------------------
function M:Init()
	self:Build()
	local blz = Ink.modules.Blizzard
	self.anchor = blz and blz.questAnchor
	if self.anchor then
		self.frame:SetPoint("TOPRIGHT", self.anchor, "TOPRIGHT")
	end
	if ObjectiveTrackerFrame then
		hooksecurefunc(ObjectiveTrackerFrame, "Show", function()
			if not InCombatLockdown() and M.frame:IsShown() then
				C_Timer.After(0, function() M:UpdateMode() end)
			end
		end)
	end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({
		"QUEST_WATCH_LIST_CHANGED", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
		"SUPER_TRACKING_CHANGED", "UNIT_QUEST_LOG_CHANGED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
		"SCENARIO_UPDATE", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN",
		"PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT",
	}) do
		pcall(e.RegisterEvent, e, ev)
	end
	C_Timer.After(4, function() pcall(M.WatchClass, M) M:Update() end)
	local pending, donePending
	C_Timer.After(3, function() M:CheckDone() end)
	e:SetScript("OnEvent", function(_, event, arg1, arg2)
		if event == "QUEST_ACCEPTED" then
			-- 클래식: (logIndex, questID) · 최신: (questID)
			local qid = arg2 or arg1
			C_Timer.After(0.3, function() pcall(M.WatchClass, M, qid) end)
			-- 막 받은 퀘스트는 목표 정보가 오기 전 잠깐 "완료"로 보인다 → 몇 초 동안은 완료로 치지 않는다
			if type(qid) == "number" then
				M.acceptedAt = M.acceptedAt or {}
				M.acceptedAt[qid] = GetTime()
				C_Timer.After(6.5, function() M:CheckDone(); M:Update() end)
			end
		end
		if event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" or event == "QUEST_ACCEPTED" then
			if not donePending then
				donePending = true
				C_Timer.After(0.4, function() donePending = nil; M:CheckDone() end)
			end
		end
		if event == "PLAYER_REGEN_ENABLED" then
			if M.modeDirty then M.modeDirty = nil; M:UpdateMode() return end
			if M.dirty then M.dirty = nil end
			M:Update()
			return
		end
		if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "SCENARIO_UPDATE" then
			M:UpdateMode()
			return
		end
		if pending then return end
		pending = true
		C_Timer.After(0.1, function()
			pending = nil
			M:Update()
		end)
	end)
end

function M:PostLayout()
	self:UpdateMode()
end
