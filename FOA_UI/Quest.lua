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
		elseif self.autoDone then
			-- 어디서든 보고하는 퀘스트 (블리자드 "눌러서 완료"): 보상 창을 연다
			M:CompleteAuto(id)
		else
			M:ShowQuest(id)
		end
	end)
	r:SetScript("OnEnter", function(self)
		self.title:SetAlpha(0.8)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(self.title:GetText() or "", 1, 1, 1)
		if Ink.TimerTipLine then Ink.TimerTipLine(GameTooltip, self.questID) end
		if self.autoDone then
			Ink.TipLine(GameTooltip, "어디서든 보고할 수 있는 퀘스트예요 · 클릭: 보고하기 (보상 창)", 1, 0.95, 0.41)
			Ink.TipLine(GameTooltip, "우클릭: 퀘스트 포기 · Shift 클릭: 목록에서 빼기", 0.7, 0.7, 0.7)
		else
			Ink.TipLine(GameTooltip, "클릭: 퀘스트 보기 · 우클릭: 퀘스트 포기 · Shift 클릭: 목록에서 빼기", 0.7, 0.7, 0.7)
		end
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
-- 퀘스트 보기: 지도 속 퀘스트 상세로 (원래 방식)
--  애드온 코드로 여는 거라 지도 표시가 FOA 로 찍혀서, 나중에 전투 중 지도를 열면 블리자드가
--  지도 표시의 "오른쪽 클릭 통과" 설정(SetPassThroughButtons)을 못 하는 일이 생긴다.
--  화면 · 기능엔 영향이 거의 없어서(표시 위에서 오른쪽 클릭으로 지도 축소가 안 될 뿐) 채팅에는 안 띄운다.
-- 남은 시간 글자 (1분 아래면 빨강)
function M:PaintTimer(o)
	local left = (o.deadline or 0) - GetTime()
	if left <= 0 then
		o.count:SetText("시간 초과")
		o.count:SetTextColor(C.red[1], C.red[2], C.red[3])
		return
	end
	local m, s = math.floor(left / 60), math.floor(left % 60)
	o.count:SetText(m >= 60 and string.format("%d:%02d:%02d", math.floor(m / 60), m % 60, s) or string.format("%d:%02d", m, s))
	local c = left < 60 and C.red or { 1, 0.72, 0.35 }
	o.count:SetTextColor(c[1], c[2], c[3])
end

function M:TickTimers()
	local f = self.frame
	if not (f and f:IsShown()) then return end
	for _, r in ipairs(f.rows or {}) do
		if r:IsShown() and r.timerLine and r.timerLine:IsShown() then self:PaintTimer(r.timerLine) end
	end
end

function M:ShowQuest(id)
	if QuestMapFrame_OpenToQuestDetails then
		local ok = pcall(QuestMapFrame_OpenToQuestDetails, id)
		if ok then return end
	end
	local idx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
	if idx and QuestLogPopupDetailFrame_Show then pcall(QuestLogPopupDetailFrame_Show, idx) end
end

-- 퀘스트 포기: FOA 확인 창으로 (블리자드 확인 창을 애드온이 띄우면 그 창이 오염돼서
--  은행 칸 사기 같은 다른 블리자드 확인이 "FOA_UI 가 차단되었습니다"로 막혔다)
function M:AbandonQuest(id)
	if type(id) ~= "number" then return end
	local title = C_QuestLog.GetTitleForQuestID(id) or ""
	local sub = "포기하면 진행 상황이 사라져요."
	if C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest then
		C_QuestLog.SetSelectedQuest(id)
		C_QuestLog.SetAbandonQuest()
		local items = C_QuestLog.GetAbandonQuestItems and C_QuestLog.GetAbandonQuestItems()
		if type(items) == "string" and items ~= "" then sub = "퀘스트 아이템도 함께 사라져요: " .. items end
	end
	Ink:Confirm("'" .. title .. "' 퀘스트를 포기할까요?", sub, "포기하기", function()
		if C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest then
			C_QuestLog.SetSelectedQuest(id)
			C_QuestLog.SetAbandonQuest()
			C_QuestLog.AbandonQuest()
		elseif SelectQuestLogEntry and SetAbandonQuest and AbandonQuest then
			local idx = C_QuestLog.GetLogIndexForQuestID(id)
			if not idx then return end
			SelectQuestLogEntry(idx)
			SetAbandonQuest()
			AbandonQuest()
		end
	end, true)
end

-- 블리자드 "퀘스트 포기" 확인 창이 뜨자마자 닫혀 버리는 경우 대비 (윈도우에서 제보)
--  블리자드 창은 건드리지 않고(오염 방지) 보기만 한다: 0.35초 뒤에도 퀘스트가 그대로인데 확인 창이 사라졌으면
--  FOA 확인 창을 대신 띄운다. 누가 닫았는지 원인 추적용으로 호출 경로를 Ink.db.abandonTrace 에 남긴다.
local ABANDON = { ABANDON_QUEST = true, ABANDON_QUEST_WITH_ITEMS = true }
function M:GuardAbandon()
	if self.abandonGuarded or not hooksecurefunc or type(StaticPopup_Show) ~= "function" then return end
	self.abandonGuarded = true
	hooksecurefunc("StaticPopup_Show", function(which)
		if not ABANDON[which] then return end
		local qid = C_QuestLog.GetAbandonQuest and C_QuestLog.GetAbandonQuest()
		if not (type(qid) == "number" and qid > 0) then
			qid = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
		end
		if not (type(qid) == "number" and qid > 0) then return end
		local shownAt = GetTime()
		M.abandonShownAt = shownAt
		C_Timer.After(0.35, function()
			if M.abandonShownAt ~= shownAt then return end
			if StaticPopup_Visible("ABANDON_QUEST") or StaticPopup_Visible("ABANDON_QUEST_WITH_ITEMS") then return end
			if not (C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid)) then return end -- 이미 포기됨
			M:AbandonQuest(qid)
		end)
	end)
	if type(StaticPopup_Hide) == "function" then
		hooksecurefunc("StaticPopup_Hide", function(which)
			if not ABANDON[which] or not M.abandonShownAt or GetTime() - M.abandonShownAt > 0.5 then return end
			local t = Ink.db.abandonTrace
			if type(t) ~= "table" then t = {}; Ink.db.abandonTrace = t end
			if #t >= 5 then table.remove(t, 1) end
			t[#t + 1] = date("%m-%d %H:%M:%S") .. " " .. tostring(which) .. "\n" .. (debugstack and debugstack(2, 8, 0) or "")
		end)
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
				map[info.questID] = { zone = zone, level = info.level, auto = info.isAutoComplete }
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
		-- 머리줄을 누르면 접기 · 펴기 (직업 퀘스트는 늘 떠 있어서 자리를 차지하니까)
		local h = CreateFrame("Button", nil, f)
		h:SetSize(W, 14)
		h:RegisterForClicks("LeftButtonUp")
		h.chev = h:CreateTexture(nil, "ARTWORK")
		h.chev:SetTexture(Ink.icon("Chevron"))
		h.chev:SetSize(10, 10)
		h.chev:SetPoint("RIGHT", 0, 0)
		h.n = Ink:Text(h, F.latin, 10, C.muted, "RIGHT")
		h.n:SetPoint("RIGHT", h.chev, "LEFT", -4, 0)
		h:SetScript("OnClick", function()
			Ink.db.questClassFold = not Ink.db.questClassFold
			M:Update()
		end)
		h:SetScript("OnEnter", function(self)
			self.t:SetAlpha(0.8)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:AddLine(Ink.db.questClassFold and "눌러서 직업 퀘스트 펴기" or "눌러서 직업 퀘스트 접기", 1, 1, 1)
			GameTooltip:Show()
		end)
		h:SetScript("OnLeave", function(self) self.t:SetAlpha(1); GameTooltip:Hide() end)
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
		h.line:SetPoint("RIGHT", h.n, "LEFT", -6, 0)
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
	local fold = Ink.db.questClassFold
	h.n:SetText(tostring(#list))
	h.chev:SetRotation(fold and math.rad(90) or 0)
	h.chev:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
	h:Show()
	if fold then return 22 end
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

-- 지역 머리줄: 표시 · 지역 이름(굵게) · 선 · 개수 — 지금 있는 지역은 노란 띠 + 위치 핀으로 눈에 띄게
function M:ZoneHead(i)
	local f = self.frame
	f.zheads = f.zheads or {}
	local h = f.zheads[i]
	if h then return h end
	h = CreateFrame("Frame", nil, f)
	h:SetSize(W, 18)
	h.band = h:CreateTexture(nil, "BACKGROUND")
	h.band:SetTexture(Ink.tex.white)
	h.band:SetPoint("TOPLEFT", -6, 1)
	h.band:SetPoint("BOTTOMRIGHT", 4, -1)
	if h.band.SetGradient and CreateColor then
		h.band:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.10), CreateColor(1, 1, 1, 0))
	end
	h.icon = h:CreateTexture(nil, "ARTWORK")
	h.icon:SetSize(11, 11)
	h.icon:SetPoint("LEFT", 0, 0)
	h.t = Ink:Text(h, F.bold, 12, C.soft, "LEFT")
	h.t:SetPoint("LEFT", h.icon, "RIGHT", 5, 0)
	h.n = Ink:Text(h, F.latin, 10, C.muted, "RIGHT")
	h.n:SetPoint("RIGHT", 0, 0)
	h.line = h:CreateTexture(nil, "ARTWORK")
	h.line:SetHeight(1)
	h.line:SetPoint("LEFT", h.t, "RIGHT", 8, 0)
	h.line:SetPoint("RIGHT", h.n, "LEFT", -6, 0)
	f.zheads[i] = h
	return h
end

-- 머리줄 모양: kind = "class" · "here" · "zone"
function M:PaintHead(h, kind, text, count)
	local col, icon, lineA, bandA
	if kind == "class" then
		col, icon, lineA, bandA = ClassRGB(), "Diamond", 0.30, 0.10
	elseif kind == "here" then
		col, icon, lineA, bandA = C.accent, "MapPin", 0.35, 0.12
	else
		col, icon, lineA, bandA = C.soft, "Diamond", 0.14, 0
	end
	h.t:SetText(text)
	h.t:SetTextColor(col[1], col[2], col[3])
	if icon == "Diamond" then
		-- 마름모: 작은 네모를 45도 돌려서
		h.icon:SetTexture(Ink.tex.white)
		h.icon:SetSize(5, 5)
		h.icon:SetRotation(math.rad(45))
		h.icon:ClearAllPoints()
		h.icon:SetPoint("LEFT", 3, 0)
	else
		h.icon:SetTexture(Ink.icon(icon))
		h.icon:SetSize(11, 11)
		h.icon:SetRotation(0)
		h.icon:ClearAllPoints()
		h.icon:SetPoint("LEFT", 0, 0)
	end
	h.icon:SetVertexColor(col[1], col[2], col[3], 1)
	h.line:SetColorTexture(col[1], col[2], col[3], lineA)
	h.band:SetVertexColor(col[1], col[2], col[3], 1)
	h.band:SetAlpha(bandA > 0 and 1 or 0)
	if bandA > 0 and h.band.SetGradient and CreateColor then
		h.band:SetGradient("HORIZONTAL", CreateColor(col[1], col[2], col[3], bandA), CreateColor(col[1], col[2], col[3], 0))
	end
	h.n:SetText(count and tostring(count) or "")
	local nc = kind == "zone" and C.muted or col
	h.n:SetTextColor(nc[1], nc[2], nc[3])
end

-------------------------------------------------------------------------------
-- 가까운 순 정렬
--  퀘스트 자리: 다 끝냈으면 보고하는 곳 · 게임 표시 · 목표가 마지막으로 오른 자리 · 받은 자리
--  (움직일 때마다 순서가 흔들리지 않게 50야드 단위로 묶고, 같은 묶음 안에선 원래 순서)
-------------------------------------------------------------------------------
local function WorldOf(m, x, y)
	if not (m and x and y and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
	local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
	if not (ok and cont and wp) then return end
	local wx, wy = wp:GetXY()
	return cont, wx, wy
end

local function PlayerWorld()
	local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local p = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
	if not p then return end
	local x, y = p:GetXY()
	x, y = plain(x), plain(y)
	if not (x and y) then return end
	return WorldOf(m, x, y)
end

function M:QuestSpot(id)
	if type(id) ~= "number" then return end
	local Q = Ink.modules.QuestMap
	local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id)
	if ready and Q and Q.TurnSpot then
		local sp = Q:TurnSpot(id)
		if sp then return sp end
	end
	if Q and Q.PoiQuests then
		local sp = Q:PoiQuests()[id]
		if sp then return sp end
	end
	local t = Ink.cdb and Ink.cdb.qSpot and Ink.cdb.qSpot[id]
	if type(t) == "table" and t[1] then return t end
	if Q and Q.GiverSpot then return Q.GiverSpot(id) end
end

-- 거리(야드) · 다른 대륙이거나 모르면 nil
function M:QuestDist(id, pc, px, py)
	if not pc then return end
	local sp = self:QuestSpot(id)
	if not sp then return end
	local c, x, y = WorldOf(sp[1], sp[2], sp[3])
	if not c or c ~= pc then return end
	return math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
end

-- 지금 있는 곳의 이름들 (세부 지역 · 지역 · 상위 지도) — 퀘스트 목록 머리줄 이름과 맞춰 본다
local function HereNames()
	local out = {}
	local function add(n) if type(n) == "string" and n ~= "" then out[n] = true end end
	add(GetRealZoneText and GetRealZoneText())
	add(GetZoneText and GetZoneText())
	add(GetSubZoneText and GetSubZoneText())
	local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local CONT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
	for _ = 1, 4 do
		local info = m and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
		if not info or (info.mapType and info.mapType <= CONT) then break end
		add(info.name)
		m = info.parentMapID
	end
	return out
end

-- 목표가 오를 때 그 자리를 적어 둔다 (가까운 순 정렬에 씀)
function M:NoteProgress(id, sum)
	self.progSum = self.progSum or {}
	local last = self.progSum[id]
	self.progSum[id] = sum
	if last == nil or sum <= last then return end
	local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local p = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
	if not p then return end
	local x, y = p:GetXY()
	x, y = plain(x), plain(y)
	if not (x and y) then return end
	Ink.cdb.qSpot = Ink.cdb.qSpot or {}
	Ink.cdb.qSpot[id] = { m, math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000 }
end

-------------------------------------------------------------------------------
-- 블리자드 퀘스트 알림 카드
--  · "눌러서 완료": 어디서든 보고하는 퀘스트 (목표를 채우면 그 자리에서 보상 창)
--  · "새 퀘스트": 아이템 · 지역에서 자동으로 제안된 퀘스트
--  블리자드 목표 추적기를 숨기고 FOA 목록을 써서 이 알림이 안 보였다 (보고할 NPC 가 없는데 "?"만 남던 퀘스트)
-------------------------------------------------------------------------------
function M:CompleteAuto(id)
	if RemoveAutoQuestPopUp then pcall(RemoveAutoQuestPopUp, id) end
	if ShowQuestComplete then pcall(ShowQuestComplete, id) end
end

local function AutoList()
	local out, seen = {}, {}
	local n = GetNumAutoQuestPopUps and GetNumAutoQuestPopUps() or 0
	for i = 1, n do
		local id, kind = GetAutoQuestPopUp(i)
		if id and not seen[id] then seen[id] = true; out[#out + 1] = { id = id, kind = kind } end
	end
	-- 알림 목록에서 빠졌어도 다 채운 "어디서든 보고" 퀘스트는 카드로
	local num = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
	for i = 1, num do
		local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
		local id = info and not info.isHeader and info.questID
		if id and info.isAutoComplete and not seen[id] and not M:Fresh(id)
			and ((C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id)) or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id))) then
			seen[id] = true
			out[#out + 1] = { id = id, kind = "COMPLETE" }
		end
	end
	return out
end

function M:PopCard(i)
	local f = self.frame
	f.pops = f.pops or {}
	local c = f.pops[i]
	if c then return c end
	c = CreateFrame("Button", nil, f)
	c:SetSize(W, 38)
	c:RegisterForClicks("LeftButtonUp")
	c.bg = Ink:Round(c, "BACKGROUND", true, false)
	c.bg:SetAllPoints()
	c.bd = Ink:Round(c, "BORDER", true, true)
	c.bd:SetAllPoints()
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetSize(16, 16)
	c.icon:SetPoint("LEFT", 9, 0)
	c.tag = Ink:Text(c, F.semi, 10, C.accent, "LEFT")
	c.tag:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 6)
	c.title = Ink:Text(c, F.semi, 12, C.text, "LEFT")
	c.title:SetPoint("TOPLEFT", c.tag, "BOTTOMLEFT", 0, -2)
	c.title:SetPoint("RIGHT", -8, 0)
	c.title:SetWordWrap(false)
	c:SetScript("OnClick", function(self)
		if not self.qid then return end
		if self.kind == "OFFER" then
			if RemoveAutoQuestPopUp then pcall(RemoveAutoQuestPopUp, self.qid) end
			if ShowQuestOffer then pcall(ShowQuestOffer, self.qid) end
		else
			M:CompleteAuto(self.qid)
		end
		C_Timer.After(0.3, function() M:Update() end)
	end)
	c:SetScript("OnEnter", function(self)
		self.bd:SetAlpha(1)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(self.title:GetText() or "", 1, 1, 1)
		Ink.TipLine(GameTooltip, self.kind == "OFFER" and "클릭: 퀘스트 내용 보기 · 수락" or "클릭: 보상 창 열기 (NPC 에게 가지 않아도 돼요)", 0.75, 0.77, 0.8)
		GameTooltip:Show()
	end)
	c:SetScript("OnLeave", function(self) self.bd:SetAlpha(0.7); GameTooltip:Hide() end)
	f.pops[i] = c
	return c
end

function M:PaintPopups(y)
	local f = self.frame
	local list = AutoList()
	local h = 0
	for i, e in ipairs(list) do
		if i > 3 then break end
		local c = self:PopCard(i)
		c.qid, c.kind = e.id, e.kind
		local offer = e.kind == "OFFER"
		local col = offer and { 1.00, 0.80, 0.30 } or C.accent
		c.bg:SetVertexColor(0.04, 0.045, 0.06, 0.92)
		c.bd:SetVertexColor(col[1], col[2], col[3], 1)
		c.bd:SetAlpha(0.7)
		c.icon:SetTexture(Ink.icon(offer and "QuestBang" or "QuestTurnIn"))
		c.icon:SetVertexColor(col[1], col[2], col[3])
		c.tag:SetText(offer and "새 퀘스트 · 눌러서 보기" or "퀘스트 완료 · 눌러서 보고")
		c.tag:SetTextColor(col[1], col[2], col[3])
		c.title:SetText(C_QuestLog.GetTitleForQuestID(e.id) or ("퀘스트 #" .. e.id))
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - h)
		c:Show()
		h = h + 44
	end
	for i = #list + 1, #(f.pops or {}) do f.pops[i]:Hide() end
	if #list > 3 then for i = 4, #(f.pops or {}) do f.pops[i]:Hide() end end
	return h
end

function M:Update()
	local f = self.frame
	if not f or not f:IsShown() then return end
	local quests = WatchedQuests()
	if #quests == 0 and self.testing then quests = { "test1", "test2" } end
	-- 지역별로 묶기: 진행 중인 직업 퀘스트 → 지금 있는 지역 → 가까운 지역 순 (같은 지역 안에선 가까운 퀘스트부터)
	local cset = ClassSet()
	local qinfo, zorder = QuestLogInfo()
	local hereSet = HereNames()
	local CLASSG, OTHER = "\001직업", "기타"
	local group = {}
	if self.testing and not next(qinfo) then
		qinfo = { test1 = { zone = "죽음의 폐광", level = 20 }, test2 = { zone = "서부 몰락지대", level = 16 } }
	end
	for _, id in ipairs(quests) do
		local q = qinfo[id]
		group[id] = (cset and cset[id]) and CLASSG or (q and q.zone) or OTHER
	end
	local nearOn = Ink.db.questNear ~= false
	local dist, gmin = {}, {}
	if nearOn then
		local pc, px, py = PlayerWorld()
		for _, id in ipairs(quests) do
			local d = self:QuestDist(id, pc, px, py)
			dist[id] = d
			local g = group[id]
			if d and (not gmin[g] or d < gmin[g]) then gmin[g] = d end
		end
	end
	local function rank(g)
		if g == CLASSG then return 0 elseif hereSet[g] then return 1 end
		if gmin[g] then return 2 + math.floor(gmin[g] / 200) * 0.001 end
		if zorder[g] then return 10 + zorder[g] end
		return 999
	end
	-- 지난번 순서 (같은 거리 묶음 안에서 순서를 지키려고)
	local prev = self.prevPos or {}
	local pos = {}
	for i, id in ipairs(quests) do pos[id] = (nearOn and prev[id]) or (1000 + i) end
	table.sort(quests, function(a, b)
		local ra, rb = rank(group[a]), rank(group[b])
		if ra ~= rb then return ra < rb end
		if group[a] ~= group[b] then return tostring(group[a]) < tostring(group[b]) end
		if nearOn then
			local da, db = dist[a], dist[b]
			if da and db then
				local ba, bb = math.floor(da / 50), math.floor(db / 50)
				if ba ~= bb then return ba < bb end
			elseif da or db then
				return da ~= nil
			end
		end
		return pos[a] < pos[b]
	end)
	self.prevPos = {}
	for i, id in ipairs(quests) do self.prevPos[id] = i end
	self.orderSig = table.concat((function() local t = {} for i, id in ipairs(quests) do t[i] = tostring(id) end return t end)(), ",")
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
	-- 직업 퀘스트 칸도 보호 프레임이 아니라 전투 중에도 다시 그린다 (접기 · 펴기가 바로 보이게)
	-- 블리자드 퀘스트 알림(눌러서 완료 · 새 퀘스트 제안): 블리자드 목표 추적기를 숨겨서 안 보이던 것 → 맨 위 카드로
	local popH = self:PaintPopups(y)
	self.classH = self:PaintClass(y - popH)
	y = y - popH - (self.classH or 0)
	if popH > 0 then self.classH = (self.classH or 0) + popH end
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
			do
				-- 지역 머리글 · 퀘스트 줄은 보호 프레임이 아니라 전투 중에도 자리를 다시 잡는다
				--  (예전엔 전투 중엔 자리를 안 옮겨서, 목표 줄 수가 바뀌면 다음 퀘스트와 겹쳐 보였다)
				local h = self:ZoneHead(nh)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - ((idx > 1 or (self.classH or 0) > 0) and 6 or 0))
				if g == CLASSG then
					self:PaintHead(h, "class", "직업 퀘스트 진행 중", gcount[g])
				else
					self:PaintHead(h, hereSet[g] and "here" or "zone", g, gcount[g])
				end
				h:Show()
			end
			y = y - ((idx > 1 or (self.classH or 0) > 0) and 32 or 26)
		end
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
		-- 퀘스트 아이템 단추는 보안 단추라 전투 밖에서만 옮긴다 (전투가 끝나면 다시 맞춘다)
		if not combat then
			r.item:ClearAllPoints()
			r.item:SetPoint("TOPRIGHT", f, "TOPLEFT", -12, y + 2)
		else
			self.dirty = true
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
		r.autoDone = complete and qinfo[id] and qinfo[id].auto or nil
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
			o.text:SetText(r.autoDone and "완료 · 눌러서 보고하기 (어디서든)" or "완료 · 보고하러 가기")
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
		-- 시간 제한 퀘스트: 남은 시간 (1초마다 글자만 갱신)
		r.timerLine = nil
		local tAll, tGone
		if type(id) == "number" and C_QuestLog.GetTimeAllowed then
			local okT, a, b = pcall(C_QuestLog.GetTimeAllowed, id)
			tAll, tGone = okT and plain(a), okT and plain(b)
		end
		if type(tAll) == "number" and tAll > 0 and not complete then
			used = used + 1
			local o = ObjectiveLine(r, used)
			o:ClearAllPoints()
			o:SetPoint("TOPLEFT", r, "TOPLEFT", 0, oy)
			o.text:SetWidth(W - 50)
			o.text:SetText("|T" .. Ink.icon("Wait") .. ":11:11:0:-1:64:64:0:64:0:64:255:184:90|t 남은 시간")
			o.text:SetTextColor(1, 0.72, 0.35)
			o.count:SetFont(F.latin, 10, "")
			o.bar:Hide()
			o.deadline = GetTime() + (tAll - (type(tGone) == "number" and tGone or 0))
			o:Show()
			r.timerLine = o
			M:PaintTimer(o)
			oy = oy - 16
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
		end
		r:SetHeight(-oy)
		r:Show()
		y = y + oy - 10
		end
	end
	-- 위 · 아래에 더 있으면 안내
	local above, below = offset, math.max(0, total - offset - MAX_QUESTS)
	if above > 0 or below > 0 then
		f.more:ClearAllPoints()
		f.more:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y + 4)
		local parts = {}
		if above > 0 then parts[#parts + 1] = "위에 " .. above .. "개" end
		if below > 0 then parts[#parts + 1] = "아래 " .. below .. "개 더" end
		f.more:SetText(table.concat(parts, "  ·  ") .. "  (휠로 넘기기)")
		f.more:Show()
		y = y - 14
	else
		f.more:Hide()
	end
	for i = shown + 1, #f.rows do
		f.rows[i]:Hide()
		if not combat then f.rows[i].item:Hide() end
	end
	for i = nh + 1, #(f.zheads or {}) do f.zheads[i]:Hide() end
	-- 목록 틀은 보안 단추(퀘스트 아이템)의 부모라 전투 중엔 크기를 못 바꾼다
	if not combat then f:SetHeight(-y) end
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
		-- 블리자드가 추적기 자리를 다시 잡으면 곧바로 다시 화면 밖으로:
		--  추적기는 블리자드 "오른쪽 관리 틀"이라 퀘스트 갱신 · 파티 변화 · 행동단축바 변화 때마다
		--  미니맵 아래 화면 오른쪽 끝(세로로 길게)으로 되돌아간다. 투명(알파 0)이어도 클릭은 받아서
		--  그 자리에 둔 세로 행동단축바를 누르면 단축바 대신 추적기 퀘스트가 눌려 지도가 열렸다 (11-12)
		hooksecurefunc(otf, "SetPoint", function()
			if not M.hideOTF or M.otfPlacing or M.otfQueued then return end
			-- 같은 순간 여러 번 불려도 한 번만 · 1초에 10번 넘게 되돌려지면 잠깐 쉰다 (서로 계속 옮기는 일 방지)
			local now = GetTime()
			if (M.otfWin or 0) ~= math.floor(now) then M.otfWin, M.otfN = math.floor(now), 0 end
			M.otfN = (M.otfN or 0) + 1
			if M.otfN > 10 then
				if not M.otfRetry then
					M.otfRetry = true
					C_Timer.After(2, function() M.otfRetry = nil; if M.hideOTF then M:PlaceOTF() end end)
				end
				return
			end
			M.otfQueued = true
			C_Timer.After(0, function()
				M.otfQueued = nil
				if M.hideOTF then M:PlaceOTF() end
			end)
		end)
	end
	-- 블리자드 목표 추적기는 FOA 코드에서 Show/Hide 하지 않는다:
	--  Show 를 부르면 추적기가 그 자리에서 다시 그려지면서 블리자드 상태 값이 FOA 로 오염돼
	--  시나리오에서 "GetAuraDataByIndex … tainted by FOA_UI" 오류가 났다 (오류 기록 11-09 · 11-10)
	--  → 투명도와 자리만 바꾼다: 쓰는 동안은 원래 자리, 안 쓰는 동안은 화면 밖 (투명해도 클릭이 걸리지 않게)
	if otf then
		M.otfBusy = true
		otf:SetAlpha(useBlizzard and 1 or 0)
		M.otfBusy = nil
		self:PlaceOTF()
	end
	self.frame:SetShown(not useBlizzard)
	self:Update()
end

-- 블리자드 목표 추적기 자리: FOA 목록을 쓰는 동안은 화면 밖으로 (전투 중에는 못 옮겨서 전투 뒤에)
function M:PlaceOTF()
	local otf = ObjectiveTrackerFrame
	if not otf then return end
	if otf.IsProtected and otf:IsProtected() and InCombatLockdown() then self.modeDirty = true return end
	local blz = Ink.modules.Blizzard
	if M.hideOTF then
		M.otfPlacing = true
		safe(function()
			-- 편집 모드 틀은 "화면 안에 묶기"가 켜져 있어서, 화면 밖 자리가 오른쪽 아래 구석으로 끌려 들어와
			--  투명한 채 화면 오른쪽 아래를 덮고 있었다 → 숨기는 동안은 묶기를 끈다
			if otf.SetClampedToScreen then otf:SetClampedToScreen(false) end
			otf:ClearAllPoints()
			otf:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 400, -400)
		end)
		M.otfPlacing = nil
	elseif blz and blz.questAnchor then
		safe(function() if otf.SetClampedToScreen then otf:SetClampedToScreen(true) end end)
		Ink:Fit(otf, blz.questAnchor, "TOPRIGHT")
	end
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

function M:QuestDone(title, demo, auto)
	if Ink.db.questToast == false and not demo then return end
	if not self.toast then self:BuildToast() end
	local t = self.toast
	t.title:SetText(title or "")
	t.sub:SetText(auto and "어디서든 보고 · 퀘스트 목록 맨 위 카드를 누르세요" or "목표 완료 · 보고하러 가세요")
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
			if objs and #objs > 0 then
				local sum = 0
				for _, ob in ipairs(objs) do sum = sum + (tonumber(ob.numFulfilled) or (ob.finished and 1 or 0)) end
				pcall(self.NoteProgress, self, id, sum)
			end
			-- 목표가 없는 퀘스트(바로 보고하는 심부름)는 받자마자 완료라 알리지 않는다
			if done and self.doneState and self.doneState[id] == false and objs and #objs > 0 then
				self:QuestDone(info.title, nil, info.isAutoComplete)
			end
		end
	end
	self.doneState = now
end

function M:NearTick()
	local f = self.frame
	if Ink.db.questNear == false or not (f and f:IsShown()) or InCombatLockdown() then return end
	local pc, px, py = PlayerWorld()
	if not pc then return end
	local l = self.nearAt
	if l and l[1] == pc and math.sqrt((l[2] - px) ^ 2 + (l[3] - py) ^ 2) < 30 then return end
	self.nearAt = { pc, px, py }
	if l then self:Update() end
end

function M:SetTest(on)
	self.testing = on
	self:Update()
end

-------------------------------------------------------------------------------
function M:Init()
	pcall(self.GuardAbandon, self)
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
		"PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT", "QUEST_AUTOCOMPLETE",
	}) do
		pcall(e.RegisterEvent, e, ev)
	end
	C_Timer.After(4, function() pcall(M.WatchClass, M) M:Update() end)
	-- 시간 제한 퀘스트 남은 시간: 1초마다 글자만
	C_Timer.NewTicker(1, function() pcall(M.TickTimers, M) end)
	-- 가까운 순: 30야드 넘게 움직였으면 4초마다 다시 정렬 (전투 중엔 쉼)
	C_Timer.NewTicker(4, function() pcall(M.NearTick, M) end)
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
				-- 받은 자리 (목표가 오르기 전까지 가까운 순 정렬에 씀)
				local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
				local p = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
				if p then
					local x, y = p:GetXY()
					x, y = plain(x), plain(y)
					if x and y then
						Ink.cdb.qSpot = Ink.cdb.qSpot or {}
						Ink.cdb.qSpot[qid] = { m, math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000 }
					end
				end
			end
		end
		if (event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN") and type(arg1) == "number" then
			if Ink.cdb.qSpot then Ink.cdb.qSpot[arg1] = nil end
			if M.progSum then M.progSum[arg1] = nil end
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
		C_Timer.After(InCombatLockdown() and 0.3 or 0.1, function()
			pending = nil
			M:Update()
		end)
	end)
	Ink.ProfFrame(e, "퀘스트 목록 이벤트")
end

function M:PostLayout()
	self:UpdateMode()
end
