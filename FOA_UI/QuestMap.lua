-- FOA UI · 지도에 받을 수 있는 퀘스트 (포에버)
--  퀘스트 시작 위치 자료(QuestDB.lua, AllTheThings MIT)로 "지금 받을 수 있는" 퀘스트만 골라 지도에 찍는다.
--   · 진영 · 종족 · 직업 · 선행 퀘스트 · 택일 퀘스트 · 전문기술 · 평판 · 이미 깬/진행 중인 퀘스트를 거른다
--   · 너무 낮은 퀘스트(회색)는 뺀다. 1~2레벨 뒤에 받을 수 있는 건 흐리게 미리 보여 준다
--   · 같은 NPC가 여러 개 주면 핀 하나 + 개수 배지, 마우스를 올리면 목록
--   · 클릭하면 그 자리에 길 안내 표시
--  핀: 유리 같은 어두운 원 + 금색 고리 + 직접 그린 느낌표 (반복 = 파랑, 곧 = 회색)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("QuestMap")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local GOLD = { 1.00, 0.80, 0.30 }
local BLUE = { 0.40, 0.75, 1.00 }
local SOON = { 0.62, 0.64, 0.68 }

-------------------------------------------------------------------------------
-- 자료 정리: 지도별로 묶기
-------------------------------------------------------------------------------
local byMap
local function Index()
	if byMap then return byMap end
	byMap = {}
	for _, r in ipairs(ns.QUEST_DB or {}) do
		local pts = r[2]
		for i = 1, #pts, 3 do
			local m = pts[i]
			byMap[m] = byMap[m] or {}
			table.insert(byMap[m], { r = r, x = pts[i + 1] / 100, y = pts[i + 2] / 100 })
		end
	end
	return byMap
end

local function Has(list, v)
	for _, x in ipairs(list) do if x == v then return true end end
	return false
end

local CUR_PATCH = (function()
	local v = GetBuildInfo() or "1.60.1"
	local a, b, c = v:match("(%d+)%.(%d+)%.(%d+)")
	return (tonumber(a) or 1) * 10000 + (tonumber(b) or 60) * 100 + (tonumber(c) or 1)
end)()

local profSkills
local function KnownSkills()
	if profSkills then return profSkills end
	profSkills = {}
	if GetProfessions then
		for _, idx in ipairs({ GetProfessions() }) do
			if idx then
				local _, _, _, _, _, _, line = GetProfessionInfo(idx)
				if line then profSkills[line] = true end
			end
		end
	end
	return profSkills
end

local function RepOK(rep)
	if not rep[1] then return true end
	local fid, need = rep[1], rep[2] or 0
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, d = pcall(C_Reputation.GetFactionDataByID, fid)
		if ok and d and d.currentStanding then return d.currentStanding >= need end
	end
	if GetFactionInfoByID then
		local ok, _, _, _, _, _, bar = pcall(GetFactionInfoByID, fid)
		if ok and bar then return bar >= need end
	end
	return true
end

local function Done(id)
	return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)
end
local function InLog(id)
	if C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id) end
	return C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end

-- 0 = 안 보임, 1 = 받을 수 있음, 2 = 곧(1~2레벨 뒤)
local function State(r, ctx)
	local id, lvl, fac = r[1], r[3], r[4]
	if fac ~= 0 and fac ~= ctx.fac then return 0 end
	if #r[5] > 0 and not Has(r[5], ctx.race) then return 0 end
	if #r[6] > 0 and not Has(r[6], ctx.class) then return 0 end
	if r[11] > CUR_PATCH then return 0 end
	if Done(id) or InLog(id) then return 0 end
	for _, a in ipairs(r[8]) do if Done(a) or InLog(a) then return 0 end end
	for _, s in ipairs(r[7]) do if not Done(s) then return 0 end end
	if r[9] ~= 0 and not KnownSkills()[r[9]] then return 0 end
	if not RepOK(r[10]) then return 0 end
	if lvl > ctx.level then
		return (lvl <= ctx.level + 2 and Ink.db.questMapSoon ~= false) and 2 or 0
	end
	-- 너무 낮은 퀘스트: 필요 레벨이 내 레벨보다 10 넘게 낮으면 회색으로 보고 뺀다 (10레벨 아래는 다 보여 줌)
	if not Ink.db.questMapLow and ctx.level >= 10 and lvl < ctx.level - 9 then return 0 end
	return 1
end

-------------------------------------------------------------------------------
-- 이름 (게임에 물어보고, 아직 없으면 요청해 두고 나중에)
-------------------------------------------------------------------------------
local function QuestName(id)
	local t = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
	if t and t ~= "" then return t end
	if C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, id) end
end

local npcName = {}
local function NpcName(id)
	if not id or id == 0 then return end
	if npcName[id] ~= nil then return npcName[id] or nil end
	if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		local ok, d = pcall(C_TooltipInfo.GetHyperlink, ("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
		local t = ok and d and d.lines and d.lines[1] and plain(d.lines[1].leftText)
		if type(t) == "string" and t ~= "" then npcName[id] = t; return t end
	end
end

-------------------------------------------------------------------------------
-- 내 직업 퀘스트 (퀘스트 목록에서 씀)
--  · 직업이 정해진 퀘스트(1~3개 직업만)만, 진영 · 종족 · 선행 · 택일 · 이미 깬 것 거르기
--  · 너무 낮은 것(필요 레벨 + 10 < 내 레벨)은 빼고, 지금 받을 수 있는 것 + 다음 레벨에 열리는 것 하나
-------------------------------------------------------------------------------
local classSet
function M:ClassSet()
	if classSet then return classSet end
	classSet = {}
	local _, _, classID = UnitClass("player")
	for _, r in ipairs(ns.QUEST_DB or {}) do
		if #r[6] > 0 and #r[6] <= 3 and Has(r[6], classID) then classSet[r[1]] = r end
	end
	return classSet
end

local function ClassState(r, ctx)
	local id, lvl, fac = r[1], r[3], r[4]
	if fac ~= 0 and fac ~= ctx.fac then return 0 end
	if #r[5] > 0 and not Has(r[5], ctx.race) then return 0 end
	if r[11] > CUR_PATCH then return 0 end
	if Done(id) or InLog(id) then return 0 end
	for _, a in ipairs(r[8]) do if Done(a) or InLog(a) then return 0 end end
	-- 직업 퀘스트 줄기는 도시마다 갈래가 나뉘었다 합쳐져서, 선행이 여러 개면 하나만 깨도 열린 걸로
	if #r[7] > 0 then
		local any = false
		for _, q in ipairs(r[7]) do if Done(q) then any = true break end end
		if not any then return 0 end
	end
	if r[9] ~= 0 and not KnownSkills()[r[9]] then return 0 end
	if not RepOK(r[10]) then return 0 end
	if lvl + 10 < ctx.level then return 0 end
	return lvl > ctx.level and 2 or 1
end

function M:ClassQuests()
	local avail, nextQ = {}, nil
	if not ns.QUEST_DB then return avail end
	local _, _, raceID = UnitRace("player")
	local fg = UnitFactionGroup("player")
	local ctx = { level = UnitLevel("player") or 1, race = raceID, fac = fg == "Horde" and 1 or (fg == "Alliance" and 2 or 0) }
	for id, r in pairs(self:ClassSet()) do
		local st = ClassState(r, ctx)
		if st > 0 and r[2][1] then
			local e = { id = id, lvl = r[3], map = r[2][1], x = r[2][2] / 100, y = r[2][3] / 100, npc = r[14], rep = r[12] == 1 }
			if st == 1 then avail[#avail + 1] = e
			elseif not nextQ or e.lvl < nextQ.lvl or (e.lvl == nextQ.lvl and e.id < nextQ.id) then nextQ = e end
		end
	end
	table.sort(avail, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a.id < b.id end)
	-- 같은 곳으로 이어지는 갈래(예: 스톰윈드 · 아이언포지 · 다르나서스에서 각각 시작)는 가장 가까운 하나만
	local groups = {}
	for _, e in ipairs(avail) do
		local d = self:Descend(e.id)
		local g
		for _, gg in ipairs(groups) do
			for k in pairs(d) do if gg.d[k] then g = gg break end end
			if g then break end
		end
		if g then
			g.list[#g.list + 1] = e
			for k in pairs(d) do g.d[k] = true end
		else
			groups[#groups + 1] = { list = { e }, d = d }
		end
	end
	local out = {}
	for _, g in ipairs(groups) do
		local best, bd = g.list[1], math.huge
		for _, e in ipairs(g.list) do
			local dist = self:DistTo(e)
			if dist < bd then best, bd = e, dist end
		end
		best.alts = #g.list - 1
		out[#out + 1] = best
	end
	if nextQ then nextQ.alts = 0 end
	return out, nextQ
end

-- 이 퀘스트 뒤로 이어지는 직업 퀘스트들 (8단계까지)
function M:Descend(id)
	if not self.classFol then
		self.classFol = {}
		for qid, r in pairs(self:ClassSet()) do
			for _, p in ipairs(r[7]) do
				self.classFol[p] = self.classFol[p] or {}
				table.insert(self.classFol[p], qid)
			end
		end
	end
	local out, frontier = {}, { id }
	for _ = 1, 8 do
		local nxt = {}
		for _, q in ipairs(frontier) do
			for _, f in ipairs(self.classFol[q] or {}) do
				if not out[f] then out[f] = true; nxt[#nxt + 1] = f end
			end
		end
		if #nxt == 0 then break end
		frontier = nxt
	end
	return out
end

-- 내 위치에서 퀘스트 주는 곳까지 (다른 대륙이면 아주 멀게)
function M:DistTo(e)
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D and C_Map.GetBestMapForUnit) then return e.id end
	local pm = C_Map.GetBestMapForUnit("player")
	local pp = pm and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(pm, "player")
	if not pp then return e.id end
	local ok1, c1, w1 = pcall(C_Map.GetWorldPosFromMapPos, pm, pp)
	local ok2, c2, w2 = pcall(C_Map.GetWorldPosFromMapPos, e.map, CreateVector2D(e.x, e.y))
	if not (ok1 and ok2 and w1 and w2) then return e.id end
	if c1 ~= c2 then return 1e7 + e.id end
	local x1, y1 = w1:GetXY()
	local x2, y2 = w2:GetXY()
	return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end
function M:QuestTitle(id) return QuestName(id) end
function M:GiverName(id) return NpcName(id) end

-------------------------------------------------------------------------------
-- 핀
-------------------------------------------------------------------------------
local function Canvas()
	local wm = WorldMapFrame
	return wm and wm.ScrollContainer and wm.ScrollContainer.Child
end

local function NewPin(parent)
	local p = CreateFrame("Button", nil, parent)
	p:SetSize(24, 24)
	p:RegisterForClicks("LeftButtonUp")
	-- 그림은 따로 둔 틀(art)에: 마우스 올렸을 때 그림만 커지고 누르는 범위는 그대로 (깜빡임 방지)
	p.art = CreateFrame("Frame", nil, p)
	p.art:SetPoint("CENTER")
	p.art:SetSize(24, 24)
	p.art:EnableMouse(false)
	local A = p.art
	p.glow = A:CreateTexture(nil, "BACKGROUND", nil, -1)
	p.glow:SetTexture(Ink.tex.glow)
	p.glow:SetPoint("TOPLEFT", -9, 9)
	p.glow:SetPoint("BOTTOMRIGHT", 9, -9)
	p.glow:SetBlendMode("ADD")
	p.disc = A:CreateTexture(nil, "BACKGROUND")
	p.disc:SetTexture(Ink.tex.disc)
	p.disc:SetAllPoints()
	p.disc:SetVertexColor(0.035, 0.04, 0.055, 0.94)
	p.shine = A:CreateTexture(nil, "BORDER")
	p.shine:SetTexture(Ink.tex.disc)
	p.shine:SetPoint("TOPLEFT", 3, -2)
	p.shine:SetPoint("BOTTOMRIGHT", -3, 10)
	p.shine:SetVertexColor(1, 1, 1, 0.06)
	p.ring = A:CreateTexture(nil, "ARTWORK")
	p.ring:SetTexture(Ink.tex.ring)
	p.ring:SetAllPoints()
	p.bang = A:CreateTexture(nil, "OVERLAY")
	p.bang:SetTexture(Ink.icon("QuestBang"))
	p.bang:SetSize(16, 16)
	p.bang:SetPoint("CENTER", 0, 0)
	-- 여러 퀘스트 배지
	p.badge = CreateFrame("Frame", nil, A)
	p.badge:SetSize(14, 14)
	p.badge:SetPoint("CENTER", p, "TOPRIGHT", -3, -3)
	p.badge.bg = p.badge:CreateTexture(nil, "ARTWORK")
	p.badge.bg:SetTexture(Ink.tex.disc)
	p.badge.bg:SetAllPoints()
	p.badge.t = Ink:Text(p.badge, F.latinB, 9, { 0.05, 0.05, 0.06 }, "CENTER")
	p.badge.t:SetPoint("CENTER", 0, 0)
	p.badge:Hide()
	-- 곧 받을 수 있는 퀘스트 레벨
	p.lv = Ink:Text(A, F.latinB, 9, SOON, "CENTER")
	p.lv:SetPoint("TOP", p, "BOTTOM", 0, -1)
	p.lv:SetShadowColor(0, 0, 0, 1)
	-- 마우스 올리면 살짝 커짐
	local ag = A:CreateAnimationGroup()
	local sc = ag:CreateAnimation("Scale")
	sc:SetDuration(0.12); sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.18, 1.18); sc:SetSmoothing("OUT")
	ag:SetScript("OnFinished", function() A:SetScale(1.18) end)
	p.hover = ag
	p:SetScript("OnEnter", function(self) self.hover:Play(); M:Tip(self) end)
	p:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.hover:Stop(); self.art:SetScale(1) end)
	p:SetScript("OnClick", function(self) M:Waypoint(self) end)
	return p
end

function M:Pin(i)
	self.pins = self.pins or {}
	local p = self.pins[i]
	if not p then p = NewPin(self.layer); self.pins[i] = p end
	return p
end

local function Paint(p, col, soon, count)
	p.ring:SetVertexColor(col[1], col[2], col[3], soon and 0.55 or 1)
	p.bang:SetVertexColor(col[1], col[2], col[3], soon and 0.7 or 1)
	p.glow:SetVertexColor(col[1], col[2], col[3], soon and 0 or 0.28)
	p.disc:SetAlpha(soon and 0.75 or 1)
	if count and count > 1 then
		p.badge.bg:SetVertexColor(col[1], col[2], col[3], 1)
		p.badge.t:SetText(count > 9 and "9+" or tostring(count))
		p.badge:Show()
	else
		p.badge:Hide()
	end
end

-------------------------------------------------------------------------------
-- 툴팁 · 길 안내
-------------------------------------------------------------------------------
function M:Tip(p)
	GameTooltip:SetOwner(p, "ANCHOR_RIGHT", 4, 0)
	local giver = NpcName(p.giver)
	GameTooltip:AddLine(giver or (p.state == 2 and "곧 받을 수 있는 퀘스트" or "받을 수 있는 퀘스트"), 1, 0.82, 0.32)
	for _, q in ipairs(p.list) do
		local r = q.r
		local name = QuestName(r[1]) or ("퀘스트 #" .. r[1] .. " (불러오는 중)")
		local tag = {}
		if q.state == 2 then tag[#tag + 1] = "|cffA0A4AA" .. r[3] .. "레벨부터|r" else tag[#tag + 1] = "|cff8E939B필요 " .. r[3] .. "|r" end
		if bit.band(r[12], 1) ~= 0 then tag[#tag + 1] = "|cff66BFFF반복|r" end
		if bit.band(r[12], 2) ~= 0 then tag[#tag + 1] = "|cffB4B8BF다른 지역으로 안내|r" end
		if r[13] ~= 0 then tag[#tag + 1] = "|cffE3C07A아이템으로 시작|r" end
		local c = q.state == 2 and SOON or (bit.band(r[12], 1) ~= 0 and BLUE or { 0.96, 0.95, 0.90 })
		GameTooltip:AddDoubleLine(name, table.concat(tag, "  "), c[1], c[2], c[3], 1, 1, 1)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("클릭: 길 안내 표시", 0.56, 0.58, 0.61)
	GameTooltip:Show()
end

function M:Waypoint(p)
	if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(p.mapID)) then return end
	local pt = UiMapPoint.CreateFromCoordinates(p.mapID, p.wx, p.wy)
	C_Map.SetUserWaypoint(pt)
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	PlaySound(SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK or 170270)
end

-------------------------------------------------------------------------------
-- 지도 위 범례 (받을 수 있음 n · 곧 n · 반복 n), 누르면 켜고 끄기
-------------------------------------------------------------------------------
function M:BuildLegend()
	local wm = WorldMapFrame
	-- 지도 위 핀을 가리지 않게 지도 창 바로 아래 오른쪽에
	local b = CreateFrame("Button", nil, wm)
	b:SetSize(10, 24)
	b:SetPoint("TOPRIGHT", wm, "BOTTOMRIGHT", 0, -6)
	b:SetFrameStrata("HIGH")
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(0.04, 0.045, 0.06, 0.88)
	b.bd = Ink:Round(b, "BORDER", true, true)
	b.bd:SetAllPoints()
	b.bd:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.45)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(Ink.icon("QuestBang"))
	b.icon:SetSize(12, 12)
	b.icon:SetPoint("LEFT", 9, 0)
	b.icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	b.t = Ink:Text(b, F.semi, 11, C.text, "LEFT")
	b.t:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
	b:SetScript("OnClick", function()
		Ink.db.questMapHide = not Ink.db.questMapHide or nil
		M:Refresh()
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:AddLine("받을 수 있는 퀘스트", 1, 0.82, 0.32)
		GameTooltip:AddLine("금색 = 지금 받을 수 있음 · 파랑 = 반복 · 회색 = 1~2레벨 뒤", 0.75, 0.77, 0.8, true)
		GameTooltip:AddLine("누르면 지도에서 숨기기 / 보이기", 0.56, 0.58, 0.61)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	self.legend = b
end

function M:PaintLegend(nOn, nSoon, nRep)
	local b = self.legend
	if not b then return end
	local wm = WorldMapFrame
	b:ClearAllPoints()
	if wm.IsMaximized and wm:IsMaximized() then
		b:SetPoint("BOTTOMRIGHT", wm.ScrollContainer, "BOTTOMRIGHT", -10, 10)
	else
		b:SetPoint("TOPRIGHT", wm, "BOTTOMRIGHT", 0, -6)
	end
	local Map = Ink.modules.Map
	if nOn + nSoon + nRep == 0 and not Ink.db.questMapHide then b:Hide() if Map and Map.LayoutUnder then Map:LayoutUnder() end return end
	local parts
	if Ink.db.questMapHide then
		parts = "|cff8E939B퀘스트 숨김 · 눌러서 보기|r"
	else
		parts = string.format("받을 수 있는 퀘스트 |cffFFCC4D%d|r", nOn)
		if nRep > 0 then parts = parts .. string.format("  |cff66BFFF반복 %d|r", nRep) end
		if nSoon > 0 then parts = parts .. string.format("  |cffA0A4AA곧 %d|r", nSoon) end
	end
	b.t:SetText(parts)
	b:SetWidth(b.t:GetStringWidth() + 36)
	b.icon:SetDesaturated(Ink.db.questMapHide and true or false)
	b:Show()
	if Map and Map.LayoutUnder then Map:LayoutUnder() end
end

-------------------------------------------------------------------------------
-- 지도 하나의 받을 수 있는 퀘스트 묶음 (같은 NPC끼리)
-------------------------------------------------------------------------------
function M:Groups(mapID)
	local list = mapID and Index()[mapID]
	local order, cnt = {}, { on = 0, soon = 0, rep = 0 }
	if not list then return order, cnt end
	local _, _, raceID = UnitRace("player")
	local _, _, classID = UnitClass("player")
	local fg = UnitFactionGroup("player")
	local ctx = { level = UnitLevel("player") or 1, race = raceID, class = classID, fac = fg == "Horde" and 1 or (fg == "Alliance" and 2 or 0) }
	local groups = {}
	for _, e in ipairs(list) do
		local st = State(e.r, ctx)
		if st > 0 then
			local key = (e.r[14] ~= 0 and ("n" .. e.r[14])) or string.format("%.3f:%.3f", e.x, e.y)
			local g = groups[key]
			if not g then
				g = { x = e.x, y = e.y, list = {}, giver = e.r[14], state = 2, rep = true }
				groups[key] = g
				order[#order + 1] = g
			end
			g.list[#g.list + 1] = { r = e.r, state = st }
			if st == 1 then g.state = 1 end
			if bit.band(e.r[12], 1) == 0 then g.rep = false end
			if st == 2 then cnt.soon = cnt.soon + 1 elseif bit.band(e.r[12], 1) ~= 0 then cnt.rep = cnt.rep + 1 else cnt.on = cnt.on + 1 end
		end
	end
	return order, cnt
end

-- 보고할 퀘스트 (다 끝낸 것): 게임이 알려 주는 보고 위치 → 없으면 받은 NPC 자리(보통 같은 NPC에게 보고)
local byQuest
local function QuestRow(id)
	if not byQuest then
		byQuest = {}
		for _, r in ipairs(ns.QUEST_DB or {}) do byQuest[r[1]] = r end
	end
	return byQuest[id]
end
local function Ready(id)
	if C_QuestLog.ReadyForTurnIn then return C_QuestLog.ReadyForTurnIn(id) end
	return C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
end
-- 게임이 보고 위치를 알려 주는 퀘스트 (어느 지역 지도에든 표시가 있으면)
--  → 그런 퀘스트는 "받은 곳" 대신 게임 표시만 쓴다 (받은 곳과 보고하는 곳이 다른 퀘스트에서 엉뚱한 물음표가 뜨던 문제)
local zoneMaps
local function ZoneMaps()
	if zoneMaps then return zoneMaps end
	zoneMaps = {}
	if C_Map.GetMapChildrenInfo then
		for _, cont in ipairs({ 1414, 1415, 1945, 113 }) do
			local ok, kids = pcall(C_Map.GetMapChildrenInfo, cont, 3, true)
			for _, k in ipairs(ok and kids or {}) do zoneMaps[#zoneMaps + 1] = k.mapID end
		end
	end
	return zoneMaps
end
function M:PoiQuests()
	if self.poiSet and not self.poiDirty then return self.poiSet end
	self.poiDirty = nil
	local set = {}
	if C_QuestLog.GetQuestsOnMap then
		for _, m in ipairs(ZoneMaps()) do
			local ok, list = pcall(C_QuestLog.GetQuestsOnMap, m)
			for _, q in ipairs(ok and list or {}) do if q.questID and q.x then set[q.questID] = true end end
		end
	end
	self.poiSet = set
	return set
end

function M:TurnIns(mapID)
	local out, seen = {}, {}
	local poi = self:PoiQuests()
	if not mapID then return out end
	if C_QuestLog.GetQuestsOnMap then
		local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
		for _, q in ipairs(ok and list or {}) do
			if q.questID and q.x and q.y and Ready(q.questID) then
				seen[q.questID] = true
				out[#out + 1] = { x = q.x, y = q.y, ids = { q.questID }, poi = true }
			end
		end
	end
	local n = C_QuestLog.GetNumQuestLogEntries and select(1, C_QuestLog.GetNumQuestLogEntries()) or 0
	for i = 1, n do
		local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
		local id = info and not info.isHeader and info.questID
		if id and not seen[id] and not poi[id] and Ready(id) then
			local r = QuestRow(id)
			local pts = r and r[2] or {}
			for k = 1, #pts, 3 do
				if pts[k] == mapID then
					local x, y = pts[k + 1] / 100, pts[k + 2] / 100
					local host
					for _, o in ipairs(out) do if not o.poi and math.abs(o.x - x) < 0.004 and math.abs(o.y - y) < 0.004 then host = o end end
					if host then host.ids[#host.ids + 1] = id else out[#out + 1] = { x = x, y = y, ids = { id }, giver = r[14] } end
					break
				end
			end
		end
	end
	return out
end

-------------------------------------------------------------------------------
-- 그리기
-------------------------------------------------------------------------------
function M:Refresh()
	local wm = WorldMapFrame
	local cv = Canvas()
	if not (wm and cv and wm:IsShown() and self.layer) then return end
	local mapID = wm:GetMapID()
	local list = mapID and Index()[mapID]
	local n, nOn, nSoon, nRep = 0, 0, 0, 0
	if list and not Ink.db.questMapHide then
		local order, cnt = self:Groups(mapID)
		nOn, nSoon, nRep = cnt.on, cnt.soon, cnt.rep
		local W, H = cv:GetWidth(), cv:GetHeight()
		local scale = (wm.GetCanvasScale and wm:GetCanvasScale()) or 1
		-- 가까이 붙은 핀(마을 한가운데 여러 NPC)은 하나로 합친다. 확대할수록 덜 합친다
		local R = 0.016 / math.max(1, scale)
		local merged = {}
		for _, g in ipairs(order) do
			local host
			for _, h in ipairs(merged) do
				local dx, dy = (g.x - h.x) * W / H, g.y - h.y
				if dx * dx + dy * dy < R * R then host = h break end
			end
			if host then
				for _, q in ipairs(g.list) do host.list[#host.list + 1] = q end
				if g.state == 1 then host.state = 1 end
				if not g.rep then host.rep = false end
				if host.giver ~= g.giver then host.giver = 0 end
			else
				merged[#merged + 1] = g
			end
		end
		order = merged
		local pinScale = math.max(0.5, math.min(1.5, 1.05 / scale))
		for _, g in ipairs(order) do
			table.sort(g.list, function(a, b)
				if a.state ~= b.state then return a.state < b.state end
				return a.r[3] > b.r[3]
			end)
			n = n + 1
			local p = self:Pin(n)
			p:ClearAllPoints()
			p.baseScale = pinScale * (g.state == 2 and 0.85 or 1)
			p:SetScale(p.baseScale)
			-- 크기를 바꾼 틀의 위치 값은 그 크기만큼 곱해지므로 나눠서 제자리에
			p:SetPoint("CENTER", cv, "TOPLEFT", g.x * W / p.baseScale, -g.y * H / p.baseScale)
			p.list, p.giver, p.state, p.mapID, p.wx, p.wy = g.list, g.giver, g.state, mapID, g.x, g.y
			local col = (g.state == 2) and SOON or (g.rep and BLUE or GOLD)
			Paint(p, col, g.state == 2, #g.list)
			p.lv:SetText(g.state == 2 and ("Lv" .. g.list[1].r[3]) or "")
			p:SetFrameLevel(self.layer:GetFrameLevel() + (g.state == 2 and 1 or 5))
			p:Show()
		end
	end
	for i = n + 1, #(self.pins or {}) do self.pins[i]:Hide() end
	-- 보고할 퀘스트 "?"
	local nt = 0
	if mapID and not Ink.db.questMapHide and Ink.db.questTurnIn ~= false then
		local W, H = cv:GetWidth(), cv:GetHeight()
		local scale = (wm.GetCanvasScale and wm:GetCanvasScale()) or 1
		local pinScale = math.max(0.5, math.min(1.5, 1.05 / scale))
		for _, t in ipairs(self:TurnIns(mapID)) do
			nt = nt + 1
			self.tpins = self.tpins or {}
			local p = self.tpins[nt]
			if not p then
				p = NewPin(self.layer)
				p.bang:SetTexture(Ink.icon("QuestTurnIn"))
				p:SetScript("OnEnter", function(self) self.hover:Play(); M:TurnTip(self) end)
				self.tpins[nt] = p
			end
			p:ClearAllPoints()
			p.baseScale = pinScale * 1.06
			p:SetScale(p.baseScale)
			p:SetPoint("CENTER", cv, "TOPLEFT", t.x * W / p.baseScale, -t.y * H / p.baseScale)
			p.ids, p.giver, p.poi, p.mapID, p.wx, p.wy = t.ids, t.giver, t.poi, mapID, t.x, t.y
			Paint(p, GOLD, false, #t.ids)
			p.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.45)
			p.lv:SetText("")
			p:SetFrameLevel(self.layer:GetFrameLevel() + 8)
			p:Show()
		end
	end
	for i = nt + 1, #(self.tpins or {}) do self.tpins[i]:Hide() end
	self:PaintLegend(nOn, nSoon, nRep)
	local Map = Ink.modules.Map
	if Map and Map.QueueDeclutter then Map:QueueDeclutter() end
end

function M:TurnTip(p)
	GameTooltip:SetOwner(p, "ANCHOR_RIGHT", 4, 0)
	GameTooltip:AddLine((NpcName(p.giver) and (NpcName(p.giver) .. " · ") or "") .. "보고할 퀘스트", 1, 0.82, 0.32)
	for _, id in ipairs(p.ids or {}) do
		GameTooltip:AddLine("|T" .. Ink.icon("Check") .. ":12:12:0:0:64:64:0:64:0:64:111:211:154|t " .. (QuestName(id) or ("퀘스트 #" .. id)), 0.96, 0.95, 0.9)
	end
	if not p.poi then GameTooltip:AddLine("퀘스트를 받은 곳 · 보통 같은 NPC에게 보고해요", 0.56, 0.58, 0.61, true) end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("클릭: 길 안내 표시", 0.56, 0.58, 0.61)
	GameTooltip:Show()
end

local refreshQueued
function M:Queue()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.3, function()
		refreshQueued = nil
		profSkills = nil
		if WorldMapFrame and WorldMapFrame:IsShown() then M:Refresh() end
	end)
end

function M:Hook()
	local wm = WorldMapFrame
	if not wm or self.hooked or not Canvas() then return end
	self.hooked = true
	self.layer = CreateFrame("Frame", nil, Canvas())
	self.layer:SetAllPoints()
	self.layer:SetFrameLevel(Canvas():GetFrameLevel() + 2300)
	self:BuildLegend()
	wm:HookScript("OnShow", function() M:Queue() end)
	if wm.OnMapChanged then hooksecurefunc(wm, "OnMapChanged", function() M:Refresh() end) end
	if wm.OnCanvasScaleChanged then hooksecurefunc(wm, "OnCanvasScaleChanged", function() M:Refresh() end) end
end


-------------------------------------------------------------------------------
-- 미니맵: 받을 수 있는 퀘스트(느낌표) · 보고할 퀘스트(물음표)
--  미니맵 범위 안이면 그 자리에 항상, 밖이면 가까운 몇 개만 테두리에 작게 (방향)
-------------------------------------------------------------------------------
local MINI_OUT = { 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 }   -- 미니맵 확대 단계별 지름(야드) · 바깥
local MINI_IN = { 300, 240, 180, 120, 80, 50 }                          -- 실내
local MAX_EDGE = 3

local function MiniPin(parent)
	local p = CreateFrame("Button", nil, parent)
	p:SetSize(16, 16)
	p:RegisterForClicks("LeftButtonUp")
	p.disc = p:CreateTexture(nil, "BACKGROUND")
	p.disc:SetTexture(Ink.tex.disc)
	p.disc:SetAllPoints()
	p.disc:SetVertexColor(0.035, 0.04, 0.055, 0.92)
	p.ring = p:CreateTexture(nil, "BORDER")
	p.ring:SetTexture(Ink.tex.ring)
	p.ring:SetAllPoints()
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetSize(10, 10)
	p.icon:SetPoint("CENTER")
	p:SetScript("OnEnter", function(self)
		if self.turn then M:TurnTip(self) else M:Tip(self) end
	end)
	p:SetScript("OnLeave", GameTooltip_Hide)
	p:SetScript("OnClick", function(self) M:Waypoint(self) end)
	p.hover = { Play = function() end }
	return p
end

function M:MiniPoints()
	local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not mapID then return end
	if self.miniFor ~= mapID or self.miniDirty then
		self.miniFor, self.miniDirty = mapID, nil
		local pts = {}
		if not Ink.db.questMapHide then
			for _, g in ipairs(self:Groups(mapID)) do
				if g.state == 1 then pts[#pts + 1] = { x = g.x, y = g.y, list = g.list, giver = g.giver, state = g.state, rep = g.rep } end
			end
			if Ink.db.questTurnIn ~= false then
				for _, t in ipairs(self:TurnIns(mapID)) do
					pts[#pts + 1] = { x = t.x, y = t.y, ids = t.ids, giver = t.giver, poi = t.poi, turn = true }
				end
			end
		end
		self.miniPts = pts
	end
	return mapID, self.miniPts
end

function M:MiniUpdate()
	local mm = Minimap
	if not (mm and mm:IsVisible()) or Ink.db.questMinimap == false then
		for _, p in ipairs(self.mpins or {}) do p:Hide() end
		return
	end
	local mapID, pts = self:MiniPoints()
	local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
	local px, py
	if pos then px, py = pos:GetXY() end
	px, py = plain(px), plain(py)
	local ww, wh
	if C_Map.GetMapWorldSize and mapID then ww, wh = C_Map.GetMapWorldSize(mapID) end
	if not (px and py and ww and ww > 0 and pts and #pts > 0) then
		for _, p in ipairs(self.mpins or {}) do p:Hide() end
		return
	end
	local zoom = (mm:GetZoom() or 0) + 1
	local diam = (IsIndoors and IsIndoors()) and (MINI_IN[zoom] or 300) or (MINI_OUT[zoom] or 466)
	local rad = diam / 2
	local half = mm:GetWidth() / 2
	local k = half / rad
	local rot = GetCVar and GetCVar("rotateMinimap") == "1"
	local face = rot and GetPlayerFacing and plain(GetPlayerFacing()) or 0
	local cs, sn = math.cos(face or 0), math.sin(face or 0)
	local round = not (GetMinimapShape and GetMinimapShape() == "SQUARE") and not mm.foaSquare
	-- 거리 계산
	local list = {}
	for _, q in ipairs(pts) do
		local dx, dy = (q.x - px) * ww, (q.y - py) * wh
		if rot then dx, dy = dx * cs - dy * sn, dx * sn + dy * cs end
		q.dx, q.dy, q.d = dx, dy, math.sqrt(dx * dx + dy * dy)
		list[#list + 1] = q
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	self.mpins = self.mpins or {}
	local n, edge = 0, 0
	local superWP = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
	for _, q in ipairs(list) do
		local inside = q.d <= rad * 0.94
		if inside or edge < MAX_EDGE then
			if not inside then edge = edge + 1 end
			n = n + 1
			local p = self.mpins[n] or MiniPin(mm)
			self.mpins[n] = p
			p:SetFrameLevel(mm:GetFrameLevel() + 12)
			local x, y = q.dx * k, -q.dy * k
			if not inside then
				-- 테두리에 붙이기 (둥근 미니맵 = 원, 네모 = 네모)
				local lim = half - 8
				if round then
					local d = math.sqrt(x * x + y * y)
					x, y = x / d * lim, y / d * lim
				else
					local m = math.max(math.abs(x), math.abs(y))
					x, y = x / m * lim, y / m * lim
				end
			end
			p:ClearAllPoints()
			p:SetPoint("CENTER", mm, "CENTER", x, y)
			p.turn = q.turn
			p.list, p.giver, p.state, p.ids, p.poi = q.list, q.giver, q.state, q.ids, q.poi
			p.mapID, p.wx, p.wy = mapID, q.x, q.y
			p.icon:SetTexture(Ink.icon(q.turn and "QuestTurnIn" or "QuestBang"))
			local col = q.turn and GOLD or (q.rep and BLUE or GOLD)
			p.icon:SetVertexColor(col[1], col[2], col[3])
			p.ring:SetVertexColor(col[1], col[2], col[3], inside and 1 or 0.6)
			local sz = inside and (q.turn and 17 or 16) or 11
			p:SetSize(sz, sz)
			p.icon:SetSize(sz * 0.62, sz * 0.62)
			p:SetAlpha(inside and 1 or 0.75)
			p:Show()
		end
	end
	for i = n + 1, #self.mpins do self.mpins[i]:Hide() end
end

function M:InitMinimap()
	if Ink.db.questMinimap == false or not Minimap then return end
	local f = CreateFrame("Frame")
	local acc = 0
	f:SetScript("OnUpdate", function(_, el)
		acc = acc + el
		if acc < 0.15 then return end
		acc = 0
		pcall(M.MiniUpdate, M)
	end)
	self.miniTicker = f
end

function M:Init()
	if not ns.QUEST_DB or Ink.db.questMap == false then return end
	self:Hook()
	self:InitMinimap()
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "ADDON_LOADED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE",
		"PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "QUEST_DATA_LOAD_RESULT", "UPDATE_FACTION" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	e:SetScript("OnEvent", function(_, event)
		if event == "ADDON_LOADED" then
			if not M.hooked then M:Hook() end
			return
		end
		if event == "QUEST_DATA_LOAD_RESULT" then
			-- 이름이 도착하면 열린 툴팁만 다시
			local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
			if owner and owner.list and owner.hover then M:Tip(owner) end
			return
		end
		M.miniDirty = true
		M.poiDirty = true
		M:Queue()
	end)
end
