-- InkUI · 퀘스트 목록 (시안 스타일로 직접 그림. 던전/시나리오 안에서는 블리자드 목표 추적기를 그대로 사용)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Quest")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

local W, MAX_QUESTS, MAX_OBJ = 240, 8, 3

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
	-- 8개보다 많으면 휠로 넘겨 보기
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
	o.bar = Ink:Bar(o, W, 2, C.text, C.track)
	o.bar:SetPoint("TOPLEFT", 0, -19)
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
	r:SetScript("OnClick", function(self, btn)
		local id = self.questID
		if not id then return end
		if btn == "RightButton" then
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(id) end
		elseif IsShiftKeyDown() then
			if C_QuestLog.RemoveQuestWatch then C_QuestLog.RemoveQuestWatch(id) end
		elseif QuestMapFrame_OpenToQuestDetails then
			QuestMapFrame_OpenToQuestDetails(id)
		end
	end)
	r:SetScript("OnEnter", function(self)
		self.title:SetAlpha(0.8)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(self.title:GetText() or "", 1, 1, 1)
		GameTooltip:AddLine("클릭: 퀘스트 보기 · 우클릭: 추적 지점 · Shift 클릭: 목록에서 빼기", 0.7, 0.7, 0.7, true)
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
local function WatchedQuests()
	local list = {}
	local n = C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches() or 0
	for i = 1, n do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
		if id then table.insert(list, id) end
	end
	return list
end

function M:Update()
	local f = self.frame
	if not f or not f:IsShown() then return end
	local quests = WatchedQuests()
	if #quests == 0 and self.testing then quests = { "test1", "test2" } end
	local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
	local maxQ = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 35
	f.count:SetText(string.format("%d / %d", numQuests or 0, maxQ))
	local super = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	local combat = InCombatLockdown()
	if combat and #quests ~= (self.lastCount or 0) then self.dirty = true end

	local y = -32
	local shown = 0
	local total = #quests
	local offset = math.max(0, math.min(self.offset or 0, total - MAX_QUESTS))
	if combat then offset = self.shownOffset or offset end
	self.offset, self.shownOffset = offset, offset
	for qi, id in ipairs(quests) do
		if qi > offset + MAX_QUESTS then break end
		if qi > offset then
		local idx = qi - offset
		shown = idx
		local r = Row(idx)
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
		end
		local tag = QuestTag(id)
		if tag then
			r.title:SetText(string.format("%s |cff%02x%02x%02x(%s)|r", title, TAG_COLOR[1] * 255, TAG_COLOR[2] * 255, TAG_COLOR[3] * 255, tag))
		else
			r.title:SetText(title)
		end
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
						o.bar:Show()
						oy = oy - 23
					else
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
		f:SetHeight(-y)
	end
	self.lastCount = #quests
	f:SetAlpha(shown > 0 and 1 or 0)
end

-- 던전 / 시나리오 / 전장에서는 블리자드 목표 추적기를 쓰고, 그 밖에서는 Ink 목록을 쓴다
function M:UpdateMode()
	if InCombatLockdown() then
		self.modeDirty = true
		return
	end
	local inInstance, kind = IsInInstance()
	local scenario = C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario()
	local useBlizzard = (inInstance and kind ~= "none") or scenario
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
	}) do
		e:RegisterEvent(ev)
	end
	local pending
	e:SetScript("OnEvent", function(_, event)
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
