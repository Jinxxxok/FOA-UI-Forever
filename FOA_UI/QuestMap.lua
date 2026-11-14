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

-- 지역 지도를 볼 때 그 안의 도시(아이언포지 · 오그리마 …) 퀘스트도 보이게:
--  도시 지도 좌표를 지금 보는 지역 지도 좌표로 바꿔서 더한다 (미니맵은 서 있는 도시 지도로 봐서 보였는데 세계 지도엔 안 보였다)
local cityRect = {}
local function CityRect(child, parent)
	local key = child * 100000 + parent
	local v = cityRect[key]
	if v == nil then
		v = false
		if C_Map.GetMapRectOnMap then
			local ok, l, r, t, b = pcall(C_Map.GetMapRectOnMap, child, parent)
			if ok and l and r and t and b and r > l and b > t and l > -0.02 and r < 1.02 and t > -0.02 and b < 1.02 and (r - l) < 0.5 then
				v = { l, r, t, b }
			end
		end
		cityRect[key] = v
	end
	return v or nil
end

local cityMaps
local function CityMaps()
	if cityMaps then return cityMaps end
	cityMaps = {}
	local CITY = Enum.UIMapType and Enum.UIMapType.City or 4
	for m in pairs(Index()) do
		local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
		if info and info.mapType == CITY then cityMaps[#cityMaps + 1] = m end
	end
	return cityMaps
end

-- 이 지도에 그릴 퀘스트 목록 (지역 지도면 안에 든 도시 것까지)
local function MapEntries(mapID)
	local own = Index()[mapID]
	local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
	local ZONE = Enum.UIMapType and Enum.UIMapType.Zone or 3
	if not (info and info.mapType == ZONE) then return own end
	local out
	for _, cm in ipairs(CityMaps()) do
		if cm ~= mapID then
			local rc = CityRect(cm, mapID)
			if rc then
				if not out then
					out = {}
					for i, e in ipairs(own or {}) do out[i] = e end
				end
				for _, e in ipairs(Index()[cm]) do
					out[#out + 1] = { r = e.r, x = rc[1] + e.x * (rc[2] - rc[1]), y = rc[3] + e.y * (rc[4] - rc[3]), city = cm }
				end
			end
		end
	end
	return out or own
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

-- 전문기술 숙련도 [기술 번호] = 숙련도 (모르면 false)
--  포에버: C_SkillInfo (번호로 바로) · 그 밖: GetProfessions
local profSkills
local function KnownSkills()
	if profSkills then return profSkills end
	profSkills = {}
	if GetProfessions and GetProfessionInfo then
		local list = { GetProfessions() }
		for i = 1, 6 do
			local idx = list[i]
			if idx then
				local ok, _, _, rank, _, _, _, line = pcall(GetProfessionInfo, idx)
				if ok and line then profSkills[line] = rank or 1 end
			end
		end
	end
	return profSkills
end
local function SkillRank(line)
	local t = KnownSkills()
	local v = t[line]
	if v == nil then
		v = false
		local SI = C_SkillInfo
		if SI and SI.GetSkillLineInfoByID then
			local ok, d = pcall(SI.GetSkillLineInfoByID, line)
			if ok and type(d) == "table" and not d.isHeader and (d.rank or 0) > 0 then v = d.rank end
		end
		t[line] = v
	end
	return v or nil
end

-- 평판 값 (모르면 nil)
local function Standing(fid)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, d = pcall(C_Reputation.GetFactionDataByID, fid)
		if ok and d and d.currentStanding then return d.currentStanding end
	end
	if GetFactionInfoByID then
		local ok, _, _, _, _, _, bar = pcall(GetFactionInfoByID, fid)
		if ok and bar then return bar end
	end
end
local function RepOK(rep)
	if not rep[1] then return true end
	local v = Standing(rep[1])
	if v == nil then return true end
	return v >= (rep[2] or 0)
end

local function KnowsSpell(id)
	if IsPlayerSpell then
		local ok, v = pcall(IsPlayerSpell, id)
		if ok and v then return true end
	end
	if IsSpellKnown then
		local ok, v = pcall(IsSpellKnown, id)
		if ok and v then return true end
	end
	return false
end

local function Done(id)
	return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)
end
local function InLog(id)
	if C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id) end
	return C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end

-- 주는 NPC 에게 직접 말을 걸었는데 그 퀘스트를 안 주면 (자료와 포에버가 다를 때) 이 캐릭터에선 숨긴다
--  레벨이 오르면 다시 보여 주고, 다음에 말을 걸 때 또 확인한다
local function NotOffered(id, level)
	local t = Ink.cdb and Ink.cdb.qNotOffered
	local at = t and t[id]
	return at and level <= at
end

-- 선행 퀘스트: 보통은 모두, 자료에 "몇 개 중 하나" 가 있으면 그만큼만
local function PreOK(r)
	local pre = r[7]
	if #pre == 0 then return true end
	local need = (r[15] and r[15][3]) or 0
	if need <= 0 then
		for _, s in ipairs(pre) do if not Done(s) then return false end end
		return true
	end
	local n = 0
	for _, s in ipairs(pre) do if Done(s) then n = n + 1 end end
	return n >= need
end

-- 그 밖의 조건 (QuestDB 15번째 · 있을 때만)
--  전문기술 숙련도 · 연결 퀘스트(목적지 퀘스트를 받았거나 깼으면 더는 안 줌) · 평판이 너무 높음 · 잠그는 퀘스트 · 잠그는 주문
local function ExtraBlocked(r)
	local x = r[15]
	if not x then return false end
	if (x[1] or 0) > 0 and r[9] ~= 0 and (SkillRank(r[9]) or 0) < x[1] then return true end
	if x[2] then for _, q in ipairs(x[2]) do if Done(q) or InLog(q) then return true end end end
	if x[4] and x[4][1] then
		local v = Standing(x[4][1])
		if v and v > x[4][2] then return true end
	end
	if x[5] then for _, q in ipairs(x[5]) do if Done(q) then return true end end end
	if x[6] then for _, s in ipairs(x[6]) do if KnowsSpell(s) then return true end end end
	return false
end
M.ExtraBlocked = ExtraBlocked

-- 0 = 안 보임, 1 = 받을 수 있음, 2 = 곧(1~2레벨 뒤)
local function State(r, ctx)
	local id, lvl, fac = r[1], r[3], r[4]
	if fac ~= 0 and fac ~= ctx.fac then return 0 end
	if #r[5] > 0 and not Has(r[5], ctx.race) then return 0 end
	if #r[6] > 0 and not Has(r[6], ctx.class) then return 0 end
	if r[11] > CUR_PATCH then return 0 end
	if Done(id) or InLog(id) then return 0 end
	for _, a in ipairs(r[8]) do if Done(a) or InLog(a) then return 0 end end
	if not PreOK(r) then return 0 end
	if r[9] ~= 0 and not SkillRank(r[9]) then return 0 end
	if not RepOK(r[10]) then return 0 end
	if ExtraBlocked(r) then return 0 end
	if NotOffered(id, ctx.level) then return 0 end
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

local npcName, npcMiss = {}, {}
local function NpcName(id)
	if not id or id == 0 then return end
	if npcName[id] ~= nil then return npcName[id] or nil end
	-- 아직 모르는 NPC 는 30초에 한 번만 다시 물어본다 (보고 NPC 찾기에서 여러 NPC 를 훑어서)
	if npcMiss[id] and GetTime() - npcMiss[id] < 30 then return end
	if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		local ok, d = pcall(C_TooltipInfo.GetHyperlink, ("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
		local t = ok and d and d.lines and d.lines[1] and plain(d.lines[1].leftText)
		if type(t) == "string" and t ~= "" then npcName[id] = t; return t end
	end
	npcMiss[id] = GetTime()
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
	if r[9] ~= 0 and not SkillRank(r[9]) then return 0 end
	if not RepOK(r[10]) then return 0 end
	if ExtraBlocked(r) then return 0 end
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

-- 핀 자리: 같은 자리를 다시 그릴 땐 지도 정리(Map:Declutter)가 올려 둔 높이를 그대로 유지
--  (매번 원래 자리로 내렸다가 다음 순간 다시 올리면 지도 위에서 위아래로 요동친다)
function M.Place(p, cv, x, y)
	local ob = p.foaBase
	local same = ob and ob[1] == cv and math.abs(ob[2] - x) < 0.5 and math.abs(ob[3] - y) < 0.5
	local up = same and (p.foaUp or 0) or 0
	p.foaBase = { cv, x, y }
	p.foaUp, p.foaUpFor = up, p.foaBase
	p:SetPoint("CENTER", cv, "TOPLEFT", x, y + up)
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
-- 찾기 어려운 NPC (지도 자리 바로 아래 동굴 안 등)
local GIVER_NOTE = {
	[256831] = "지하 동굴 안 (이 자리 바로 아래층) · 햇살숲 49.9, 46.0 무너진 집 지하실로 내려가요",
}
M.GIVER_NOTE = GIVER_NOTE
-- 그런 NPC 는 길 안내를 입구로 {지도, x, y} (0~1)
local GIVER_ENTRANCE = {
	[256831] = { 2548, 0.499, 0.460 },
}
M.GIVER_ENTRANCE = GIVER_ENTRANCE

function M:Tip(p)
	GameTooltip:SetOwner(p, "ANCHOR_RIGHT", 4, 0)
	local giver = NpcName(p.giver)
	GameTooltip:AddLine(giver or (p.state == 2 and "곧 받을 수 있는 퀘스트" or "받을 수 있는 퀘스트"), 1, 0.82, 0.32)
	if p.giver and GIVER_NOTE[p.giver] then Ink.TipLine(GameTooltip, GIVER_NOTE[p.giver], 1, 0.72, 0.35) end
	for _, q in ipairs(p.list) do
		local r = q.r
		local name = QuestName(r[1]) or ("퀘스트 #" .. r[1] .. " (불러오는 중)")
		local tag = {}
		if q.state == 2 then tag[#tag + 1] = "|cffA0A4AA" .. r[3] .. "레벨부터|r" else tag[#tag + 1] = "|cff8E939B필요 " .. r[3] .. "|r" end
		if bit.band(r[12], 1) ~= 0 then tag[#tag + 1] = "|cff66BFFF반복|r" end
		if bit.band(r[12], 2) ~= 0 then tag[#tag + 1] = "|cffB4B8BF다른 지역으로 안내|r" end
		if r[13] ~= 0 then tag[#tag + 1] = "|cffE3C07A아이템으로 시작|r" end
		local tm = Ink.TimerTag and Ink.TimerTag(r[1])
		if tm then tag[#tag + 1] = tm end
		local c = q.state == 2 and SOON or (bit.band(r[12], 1) ~= 0 and BLUE or { 0.96, 0.95, 0.90 })
		GameTooltip:AddDoubleLine(name, table.concat(tag, "  "), c[1], c[2], c[3], 1, 1, 1)
		-- 시간 제한 퀘스트: 바로 아래 강조 한 줄
		if Ink.TimerTipLine then Ink.TimerTipLine(GameTooltip, r[1], "   ") end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine((p.giver and GIVER_ENTRANCE[p.giver]) and "클릭: 동굴 입구로 길 안내" or "클릭: 길 안내 표시", 0.56, 0.58, 0.61)
	GameTooltip:Show()
end

function M:Waypoint(p)
	if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(p.mapID)) then return end
	local wx, wy = p.wx, p.wy
	local ent = p.giver and GIVER_ENTRANCE[p.giver]
	if ent and M.ToMap then
		local ex, ey = M.ToMap(ent, p.mapID)
		if ex then wx, wy = ex, ey end
	end
	local pt = UiMapPoint.CreateFromCoordinates(p.mapID, wx, wy)
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
		Ink.TipLine(GameTooltip, "금색 = 지금 받을 수 있음 · 파랑 = 반복 · 회색 = 1~2레벨 뒤", 0.75, 0.77, 0.8)
		Ink.TipLine(GameTooltip, "조건(선행 · 전문기술 숙련도 · 평판 · 연결 퀘스트)이 안 맞는 퀘스트는 숨기고, 열리면 보여요", 0.75, 0.77, 0.8)
		local unk = M.turnUnknown
		if unk and #unk > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("보고 위치를 모르는 퀘스트 (한 번 보고하면 기억)", 1, 0.82, 0.32)
			for i, u in ipairs(unk) do
				if i > 6 then GameTooltip:AddLine("… " .. (#unk - 6) .. "개 더", 0.56, 0.58, 0.61) break end
				GameTooltip:AddLine((QuestName(u.id) or ("퀘스트 #" .. u.id)), 0.96, 0.95, 0.9)
				if u.txt and u.txt ~= "" then Ink.TipLine(GameTooltip, "   " .. u.txt, 0.62, 0.64, 0.68) end
			end
		end
		GameTooltip:AddLine(" ")
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
	if nOn + nSoon + nRep == 0 and not (self.turnUnknown and #self.turnUnknown > 0) and not Ink.db.questMapHide then b:Hide() if Map and Map.LayoutUnder then Map:LayoutUnder() end return end
	local parts
	if Ink.db.questMapHide then
		parts = "|cff8E939B퀘스트 숨김 · 눌러서 보기|r"
	else
		parts = string.format("받을 수 있는 퀘스트 |cffFFCC4D%d|r", nOn)
		if nRep > 0 then parts = parts .. string.format("  |cff66BFFF반복 %d|r", nRep) end
		if nSoon > 0 then parts = parts .. string.format("  |cffA0A4AA곧 %d|r", nSoon) end
		local unk = self.turnUnknown and #self.turnUnknown or 0
		if unk > 0 then parts = parts .. string.format("  |cff8E939B보고 위치 모름 %d|r", unk) end
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
	local list = mapID and MapEntries(mapID)
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

-- 보고할 퀘스트 (다 끝낸 것) "?" 자리 — 받은 곳과 보고하는 곳이 다른 퀘스트가 많아서(약 절반) 차례대로 찾는다
--  1) 게임이 알려 주는 보고 위치
--  2) 이 캐릭터(계정)가 전에 그 퀘스트를 보고한 자리 (보고할 때마다 배운다)
--  3) 다음 퀘스트를 주는 NPC (퀘스트 줄기: 보고 받은 NPC 가 다음 퀘스트를 준다 · 연결 퀘스트는 목적지 퀘스트를 주는 NPC)
--  4) 퀘스트 목표 글에 이름이 나온 NPC ("…에게 돌아가십시오")
--  5) 목표 글이 없는 퀘스트만 받은 NPC
--  모르면 지도에 찍지 않고 범례에 "보고 위치 모름"으로 (엉뚱한 자리에 "?"를 찍지 않게)
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
--  → 그런 퀘스트는 게임 표시만 쓴다
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
	-- 새 지역(강물터 등)은 대륙 아래 목록에 없을 수 있어서 퀘스트 자료에 있는 지역 지도도 더한다
	local seen = {}
	for _, m in ipairs(zoneMaps) do seen[m] = true end
	local ZONE = Enum.UIMapType and Enum.UIMapType.Zone or 3
	for m in pairs(Index()) do
		if not seen[m] then
			local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
			if info and info.mapType == ZONE then seen[m] = true; zoneMaps[#zoneMaps + 1] = m end
		end
	end
	return zoneMaps
end
function M:PoiQuests()
	-- 모든 지역 지도의 퀘스트 표시를 훑는 일이라 10초에 한 번까지만 (전투 중엔 있던 것 그대로)
	if self.poiSet and (not self.poiDirty or InCombatLockdown() or GetTime() - (self.poiAt or 0) < 10) then return self.poiSet end
	self.poiDirty, self.poiAt = nil, GetTime()
	local set = {}
	if C_QuestLog.GetQuestsOnMap then
		for _, m in ipairs(ZoneMaps()) do
			local ok, list = pcall(C_QuestLog.GetQuestsOnMap, m)
			for _, q in ipairs(ok and list or {}) do
				if q.questID and q.x and not set[q.questID] then set[q.questID] = { m, q.x, q.y } end
			end
		end
	end
	self.poiSet = set
	return set
end

-- 퀘스트 줄기: [퀘스트] = 그 뒤에 이어지는 퀘스트 줄들 (연결 퀘스트는 목적지 퀘스트)
local followers
local function Followers()
	if followers then return followers end
	followers = {}
	for _, r in ipairs(ns.QUEST_DB or {}) do
		for _, p in ipairs(r[7]) do
			followers[p] = followers[p] or {}
			table.insert(followers[p], r)
		end
	end
	for _, r in ipairs(ns.QUEST_DB or {}) do
		local x = r[15]
		if x and x[2] and bit.band(r[12], 2) ~= 0 then
			followers[r[1]] = {}
			for _, nq in ipairs(x[2]) do
				local nr = QuestRow(nq)
				if nr then table.insert(followers[r[1]], nr) end
			end
		end
	end
	return followers
end

-- NPC 가 서 있는 자리 {지도, x, y} (0~1): 직접 말을 걸어 본 자리 → 그 NPC 가 주는 퀘스트 자리
local giverSpot
local function NpcSpot(npc)
	if not npc or npc == 0 then return end
	local learned = Ink.db.npcSpot and Ink.db.npcSpot[npc]
	if type(learned) == "table" and learned[1] then return learned end
	if not giverSpot then
		giverSpot = {}
		for _, r in ipairs(ns.QUEST_DB or {}) do
			local g = r[14]
			if g ~= 0 and not giverSpot[g] and r[2][1] then giverSpot[g] = { r[2][1], r[2][2] / 100, r[2][3] / 100 } end
		end
	end
	return giverSpot[npc]
end
M.NpcSpot = NpcSpot
-- 퀘스트를 주는 자리 {지도, x, y} (0~1)
function M.GiverSpot(id)
	local r = QuestRow(id)
	if r and r[2][1] then return { r[2][1], r[2][2] / 100, r[2][3] / 100 } end
end

-- 목표 글 (퀘스트 로그 "목표" 문단)
local function ObjectiveText(id)
	local idx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
	if not (idx and GetQuestLogQuestText) then return end
	local ok, _, obj = pcall(GetQuestLogQuestText, idx)
	obj = ok and plain(obj)
	if type(obj) == "string" then return obj end
end
M.ObjectiveText = ObjectiveText

-- 목표 글에 이름이 나올 만한 NPC: 그 지역(받은 곳 · 지금 있는 곳)에서 퀘스트를 주는 NPC + 말을 걸어 본 NPC
local npcByMap
local function MapNpcs(map)
	if not npcByMap then
		npcByMap = {}
		for _, r in ipairs(ns.QUEST_DB or {}) do
			local g, pts = r[14], r[2]
			if g ~= 0 then
				for i = 1, #pts, 3 do
					local t = npcByMap[pts[i]] or {}
					npcByMap[pts[i]] = t
					t[g] = true
				end
			end
		end
	end
	local out = {}
	for g in pairs(npcByMap[map] or {}) do out[g] = true end
	for id, s in pairs(Ink.db.npcSpot or {}) do
		if type(s) == "table" and s[1] == map then out[id] = true end
	end
	return out
end
local function NameOf(id)
	local s = Ink.db.npcSpot and Ink.db.npcSpot[id]
	if type(s) == "table" and s[4] then return s[4] end
	return NpcName(id)
end

-- 보고 받는 NPC 와 자리: npc, spot{지도,x,y}, 근거
--  근거: "learned" 전에 보고한 곳 · "follow" 다음 퀘스트를 주는 NPC · "text" 목표 글의 NPC · "giver" 받은 NPC
function M:Ender(id)
	local e = Ink.db.questEnd and Ink.db.questEnd[id]
	if type(e) == "table" and e[1] then return e[4], e, "learned" end
	local r = QuestRow(id)
	local giver = r and r[14] or 0
	-- 다음 퀘스트를 주는 NPC (모두 같은 NPC 일 때만 · 받은 NPC 가 그중에 있으면 받은 NPC)
	local fol = Followers()[id]
	if fol and #fol > 0 then
		local set, n, one = {}, 0, nil
		for _, fr in ipairs(fol) do
			if fr[14] ~= 0 and not set[fr[14]] then set[fr[14]] = true; n = n + 1; one = fr[14] end
		end
		if n == 1 and one ~= giver then
			local sp = NpcSpot(one)
			if sp then return one, sp, "follow" end
		elseif (n == 1 and one == giver) or (n > 1 and set[giver]) then
			local sp = NpcSpot(giver)
			if sp then return giver, sp, "follow" end
		end
	end
	-- 목표 글
	local txt = ObjectiveText(id)
	if txt and txt ~= "" then
		local gname = giver ~= 0 and NameOf(giver)
		if gname and #gname >= 4 and txt:find(gname, 1, true) then
			local sp = NpcSpot(giver)
			if sp then return giver, sp, "text" end
		end
		local maps = {}
		if r and r[2][1] then maps[r[2][1]] = true end
		local pm = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
		if pm then maps[pm] = true end
		local found = {}
		for m in pairs(maps) do
			for npc in pairs(MapNpcs(m)) do
				if npc ~= giver and not found[npc] then
					local nm = NameOf(npc)
					if nm and #nm >= 4 and txt:find(nm, 1, true) then found[npc] = nm end
				end
			end
		end
		-- 다른 이름 안에 든 짧은 이름은 빼고, 남은 이름이 하나(같은 이름 여럿이면 그중 직접 만난 NPC)일 때만
		local list = {}
		for npc, nm in pairs(found) do
			local inside = false
			for npc2, nm2 in pairs(found) do
				if npc2 ~= npc and #nm2 > #nm and nm2:find(nm, 1, true) then inside = true break end
			end
			if not inside then list[#list + 1] = npc end
		end
		local hit
		if #list == 1 then
			hit = list[1]
		elseif #list > 1 then
			local same = true
			for _, npc in ipairs(list) do if found[npc] ~= found[list[1]] then same = false break end end
			if same then
				hit = list[1]
				for _, npc in ipairs(list) do if Ink.db.npcSpot and Ink.db.npcSpot[npc] then hit = npc break end end
			end
		end
		if hit then
			local sp = NpcSpot(hit)
			if sp then return hit, sp, "text" end
		end
		return nil, nil, nil, txt
	end
	-- 목표 글이 없는 퀘스트(바로 보고하는 것)는 대개 받은 NPC
	if giver ~= 0 and txt == "" then
		local sp = NpcSpot(giver)
		if sp then return giver, sp, "giver" end
	end
end

-- 다른 지도 좌표를 이 지도 좌표로 (도시 → 지역은 사각형, 그 밖은 세계 좌표로 · 지도 밖이면 nil)
local function ToMap(sp, mapID)
	local m, x, y = sp[1], sp[2], sp[3]
	if m == mapID then return x, y end
	local rc = CityRect(m, mapID)
	if rc then return rc[1] + x * (rc[2] - rc[1]), rc[3] + y * (rc[4] - rc[3]) end
	if C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D then
		local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
		if ok and cont and wp then
			local ok2, _, mp = pcall(C_Map.GetMapPosFromWorldPos, cont, wp, mapID)
			if ok2 and mp then
				local mx, my = mp:GetXY()
				if mx and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then return mx, my end
			end
		end
	end
end
M.ToMap = ToMap

-- 퀘스트 하나의 보고 자리 (퀘스트 목록 가까운 순 정렬에서도 씀): spot{지도,x,y}, 근거
function M:TurnSpot(id)
	local poi = self:PoiQuests()[id]
	if poi then return poi, "poi" end
	local c = self.enderCache and self.enderCache[id]
	if c and GetTime() - c.at < (c.spot and 60 or 15) then return c.spot, c.src, c.npc, c.txt end
	local npc, spot, src, txt = self:Ender(id)
	self.enderCache = self.enderCache or {}
	self.enderCache[id] = { at = GetTime(), spot = spot, src = src, npc = npc, txt = txt }
	return spot, src, npc, txt
end

function M:TurnIns(mapID)
	local out, unknown = {}, {}
	self.turnUnknown = unknown
	if not mapID then return out end
	local seen = {}
	if C_QuestLog.GetQuestsOnMap then
		local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
		for _, q in ipairs(ok and list or {}) do
			if q.questID and q.x and q.y and Ready(q.questID) then
				seen[q.questID] = true
				out[#out + 1] = { x = q.x, y = q.y, ids = { q.questID }, poi = true, src = "poi" }
			end
		end
	end
	local n = C_QuestLog.GetNumQuestLogEntries and select(1, C_QuestLog.GetNumQuestLogEntries()) or 0
	for i = 1, n do
		local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
		local id = info and not info.isHeader and info.questID
		-- 막 받은 퀘스트는 목표 정보가 오기 전 잠깐 "완료"로 보여서 내 자리에 물음표가 떴다 사라졌다 → 몇 초 기다린다
		local fresh = id and M.acceptedAt and M.acceptedAt[id] and (GetTime() - M.acceptedAt[id] < 6)
		-- 어디서든 보고하는 퀘스트(눌러서 완료)는 보고할 NPC 가 없어서 지도에 "?"를 찍지 않는다 (퀘스트 목록 맨 위 카드)
		if id and info.isAutoComplete then seen[id] = true end
		if id and not seen[id] and not fresh and Ready(id) then
			local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id) or {}
			local spot, src, npc, txt = self:TurnSpot(id)
			-- 목표가 없는 심부름(편지 배달 · 누구와 대화)은 받은 NPC 로 짐작하지 않는다 (보고는 다른 NPC)
			if spot and src == "giver" and #objs == 0 then spot = nil end
			if spot then
				local x, y = ToMap(spot, mapID)
				if x then
					local host
					for _, o in ipairs(out) do if not o.poi and math.abs(o.x - x) < 0.004 and math.abs(o.y - y) < 0.004 then host = o end end
					if host then
						host.ids[#host.ids + 1] = id
						if host.giver ~= npc then host.giver = 0 end
					else
						out[#out + 1] = { x = x, y = y, ids = { id }, giver = npc or 0, src = src }
					end
				end
			elseif #objs > 0 or txt then
				unknown[#unknown + 1] = { id = id, txt = txt }
			end
		end
	end
	return out
end

-- 보고한 자리 배우기: 보상 창이 열릴 때 NPC · 내 자리를 적어 두고, 보고가 끝나면 저장
--  말을 건 NPC 자리도 적어 둔다 (목표 글에 이름이 나온 NPC 를 찾을 때 씀)
local function TalkGuid()
	local g = plain(UnitGUID("npc")) or plain(UnitGUID("questnpc"))
	if type(g) ~= "string" then return end
	local kind, _, _, _, _, id = strsplit("-", g)
	return kind, tonumber(id)
end
local function PlayerSpot()
	local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local p = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
	if not p then return end
	local x, y = p:GetXY()
	x, y = plain(x), plain(y)
	if not (x and y) or (x == 0 and y == 0) then return end
	return m, math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000
end
M.PlayerSpot = PlayerSpot
function M:LearnNpc()
	local kind, id = TalkGuid()
	if kind ~= "Creature" or not id then return end
	local m, x, y = PlayerSpot()
	if not m then return end
	Ink.db.npcSpot = Ink.db.npcSpot or {}
	local name = plain(UnitName("npc"))
	Ink.db.npcSpot[id] = { m, x, y, type(name) == "string" and name or nil }
end
function M:NoteTurnIn()
	local qid = GetQuestID and GetQuestID()
	if not (qid and qid > 0) then return end
	local m, x, y = PlayerSpot()
	if not m then return end
	local kind, id = TalkGuid()
	self.pendingEnd = { id = qid, at = GetTime(), m = m, x = x, y = y, npc = kind == "Creature" and id or 0 }
end
function M:SaveTurnIn(qid)
	local p = self.pendingEnd
	if not (p and p.id == qid and GetTime() - p.at < 120) then return end
	self.pendingEnd = nil
	Ink.db.questEnd = Ink.db.questEnd or {}
	Ink.db.questEnd[qid] = { p.m, p.x, p.y, p.npc }
end

-------------------------------------------------------------------------------
-- 그리기
-------------------------------------------------------------------------------
function M:Refresh()
	local wm = WorldMapFrame
	local cv = Canvas()
	if not (wm and cv and wm:IsShown() and self.layer) then return end
	local mapID = wm:GetMapID()
	local list = mapID and MapEntries(mapID)
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
			M.Place(p, cv, g.x * W / p.baseScale, -g.y * H / p.baseScale)
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
			M.Place(p, cv, t.x * W / p.baseScale, -t.y * H / p.baseScale)
			p.ids, p.giver, p.poi, p.src, p.mapID, p.wx, p.wy = t.ids, t.giver, t.poi, t.src, mapID, t.x, t.y
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

local SRC_NOTE = {
	learned = "전에 이 퀘스트를 보고한 자리",
	follow = "다음 퀘스트를 주는 NPC 자리 (보고 받는 NPC)",
	text = "퀘스트 목표 글에 나온 NPC 자리",
	giver = "받은 NPC 자리",
}
function M:TurnTip(p)
	GameTooltip:SetOwner(p, "ANCHOR_RIGHT", 4, 0)
	local who = p.giver and p.giver ~= 0 and NameOf(p.giver)
	GameTooltip:AddLine((who and (who .. " · ") or "") .. "보고할 퀘스트", 1, 0.82, 0.32)
	for _, id in ipairs(p.ids or {}) do
		GameTooltip:AddLine("|T" .. Ink.icon("Check") .. ":12:12:0:0:64:64:0:64:0:64:111:211:154|t " .. (QuestName(id) or ("퀘스트 #" .. id)), 0.96, 0.95, 0.9)
	end
	if not p.poi and SRC_NOTE[p.src] then GameTooltip:AddLine(SRC_NOTE[p.src], 0.56, 0.58, 0.61) end
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
	-- FOA 지도 표시(+2500: 훈련사 · 상인 · 편의 시설) 위에: 퀘스트 주는 NPC 가 훈련사이기도 하면 느낌표가 그 아이콘에 가려졌다
	self.layer:SetFrameLevel(Canvas():GetFrameLevel() + 2600)
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
	-- 다시 계산(퀘스트 자료 전체 · 지역 지도들의 보고 위치)은 무거워서:
	--  전투 중엔 지역이 바뀐 게 아니면 미루고(전투가 끝나면), 평소에도 2초에 한 번까지만
	--  (전투 중 퀘스트 로그 갱신이 잦아서 기술을 누를 때마다 다시 계산 → "애드온이 성능을 떨어뜨린다" 경고가 떴다)
	local now = GetTime()
	local changed = self.miniFor ~= mapID
	if self.miniDirty and not changed and (InCombatLockdown() or now - (self.miniAt or 0) < 2) then
		return mapID, self.miniPts
	end
	if changed or self.miniDirty then
		self.miniFor, self.miniDirty, self.miniAt = mapID, nil, now
		local pts = {}
		if not Ink.db.questMapHide then
			for _, g in ipairs(self:Groups(mapID)) do
				if g.state == 1 then pts[#pts + 1] = { x = g.x, y = g.y, list = g.list, giver = g.giver, state = g.state, rep = g.rep } end
			end
			if Ink.db.questTurnIn ~= false then
				for _, t in ipairs(self:TurnIns(mapID)) do
					pts[#pts + 1] = { x = t.x, y = t.y, ids = t.ids, giver = t.giver, poi = t.poi, src = t.src, turn = true }
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
			p.list, p.giver, p.state, p.ids, p.poi, p.src = q.list, q.giver, q.state, q.ids, q.poi, q.src
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
	Ink.ProfFrame(f, "퀘스트 미니맵")
	self.miniTicker = f
end

-------------------------------------------------------------------------------
-- 퀘스트 주는 NPC 와 대화할 때: 자료상 받을 수 있는 퀘스트를 실제로 주는지 확인
-------------------------------------------------------------------------------
local function TalkNpcID()
	local g = plain(UnitGUID("npc"))
	if type(g) ~= "string" then return end
	local kind, _, _, _, _, id = strsplit("-", g)
	if kind ~= "Creature" then return end
	return tonumber(id)
end

function M:CheckOffered(event)
	local npc = TalkNpcID()
	if not npc then return end
	-- 이 NPC 가 주는 퀘스트 (자료)
	local mine = {}
	for _, r in ipairs(ns.QUEST_DB or {}) do if r[14] == npc then mine[#mine + 1] = r end end
	if #mine == 0 then return end
	-- 지금 실제로 주는 퀘스트 · 진행 중인 퀘스트
	local offered, names, known = {}, {}, false
	M.listAt = M.listAt or {}
	if event == "QUEST_DETAIL" then
		-- 목록에서 하나를 골라 연 상세창이면 그 NPC 의 다른 퀘스트는 모른다 → 바로 상세가 뜬 경우만 (주는 게 그것 하나)
		if M.listAt[npc] and GetTime() - M.listAt[npc] < 120 then return end
		local q = GetQuestID and GetQuestID()
		if q and q ~= 0 then offered[q] = true; known = true end
	elseif event == "GOSSIP_SHOW" and C_GossipInfo and C_GossipInfo.GetAvailableQuests then
		for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do if q.questID then offered[q.questID] = true end end
		for _, q in ipairs(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) do if q.questID then offered[q.questID] = true end end
		known = true
	elseif event == "QUEST_GREETING" and GetNumAvailableQuests then
		for i = 1, GetNumAvailableQuests() do
			local qid = GetAvailableQuestInfo and select(5, GetAvailableQuestInfo(i))
			if type(qid) == "number" and qid > 0 then offered[qid] = true end
			local t = GetAvailableTitle and GetAvailableTitle(i)
			if t then names[t] = true end
		end
		for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
			local t = GetActiveTitle and GetActiveTitle(i)
			if t then names[t] = true end
		end
		known = true
	end
	if not known then return end
	if event ~= "QUEST_DETAIL" then M.listAt[npc] = GetTime() end
	local _, _, classID = UnitClass("player")
	local _, _, raceID = UnitRace("player")
	local fg = UnitFactionGroup("player")
	local level = UnitLevel("player") or 1
	local ctx = { level = level, race = raceID, class = classID, fac = fg == "Horde" and 1 or (fg == "Alliance" and 2 or 0) }
	Ink.cdb.qNotOffered = Ink.cdb.qNotOffered or {}
	local t, changed = Ink.cdb.qNotOffered, false
	for _, r in ipairs(mine) do
		local id = r[1]
		local name = QuestName(id)
		local isOffered = offered[id] or (name and names[name])
		if isOffered then
			if t[id] then t[id] = nil; changed = true end
		else
			t[id] = nil
			-- 자료상 지금 받을 수 있어야 하는데 안 주는 것만 (곧 받을 수 있는 것 · 이미 받은 것은 그대로)
			if State(r, ctx) == 1 then t[id] = level; changed = true end
		end
	end
	if changed then M.miniDirty = true; M.poiDirty = true; M:Queue() end
end

-------------------------------------------------------------------------------
-- 말을 걸어도 아무 창이 안 뜨는 NPC (지금 줄 퀘스트가 하나도 없을 때)
--  오른쪽 클릭(짧게) 뒤 1.5초 동안 대화 · 퀘스트 · 상점 창이 안 뜨고 "너무 멀다" 같은 오류도 없으면
--  자료상 그 NPC 가 지금 줄 퀘스트를 이 캐릭터 · 이 레벨에서 숨긴다 (선행 퀘스트가 자료에 빠진 경우)
--  레벨이 오르거나, 그 NPC 에게 퀘스트를 보고하거나, 선행이 될 만한 퀘스트를 끝내면 다시 보여 준다
-------------------------------------------------------------------------------
local giverSet
local function IsGiver(npc)
	if not giverSet then
		giverSet = {}
		for _, r in ipairs(ns.QUEST_DB or {}) do if r[14] ~= 0 then giverSet[r[14]] = true end end
	end
	return giverSet[npc]
end
local function Ctx()
	local _, _, classID = UnitClass("player")
	local _, _, raceID = UnitRace("player")
	local fg = UnitFactionGroup("player")
	return { level = UnitLevel("player") or 1, race = raceID, class = classID, fac = fg == "Horde" and 1 or (fg == "Alliance" and 2 or 0) }
end

function M:WorldDown(button)
	if button ~= "RightButton" then return end
	self.rdown = { at = GetTime(), guid = plain(UnitGUID("mouseover")) }
end
function M:WorldUp(button)
	if button ~= "RightButton" or InCombatLockdown() then return end
	local d = self.rdown
	self.rdown = nil
	if not d or GetTime() - d.at > 0.35 or type(d.guid) ~= "string" then return end
	if plain(UnitGUID("mouseover")) ~= d.guid then return end
	local kind, _, _, _, _, id = strsplit("-", d.guid)
	id = tonumber(id)
	if kind ~= "Creature" or not id or not IsGiver(id) then return end
	if UnitCanAttack and UnitCanAttack("player", "mouseover") then return end
	local ok, near = pcall(CheckInteractDistance, "mouseover", 3)
	if not (ok and near) then return end
	local name = plain(UnitName("mouseover"))
	local token = GetTime()
	self.silentTry = token
	C_Timer.After(1.5, function()
		if M.silentTry ~= token then return end
		M.silentTry = nil
		if (M.lastOpen or 0) >= token or (M.lastErr or 0) >= token then return end
		M:MarkSilent(id, name)
	end)
end
function M:MarkSilent(npc, name)
	local ctx = Ctx()
	Ink.cdb.qNotOffered = Ink.cdb.qNotOffered or {}
	local t, n = Ink.cdb.qNotOffered, 0
	for _, r in ipairs(ns.QUEST_DB or {}) do
		if r[14] == npc and State(r, ctx) == 1 then t[r[1]] = ctx.level; n = n + 1 end
	end
	if n == 0 then return end
	print("|T" .. Ink.tex.logo .. ":14:14|t |cffFFF468FOA|r " .. (type(name) == "string" and name or "이 NPC") ..
		": 지금 줄 퀘스트가 없어서 지도에서 " .. n .. "개를 숨겼어요 |cff8E939B(먼저 할 퀘스트가 있는 경우 · 조건이 풀리면 다시 보여요)|r")
	M.miniDirty, M.poiDirty, M.miniAt = true, true, 0
	M:Queue()
end
-- 보고한 뒤: 보고 받은 NPC 가 주는 퀘스트와 이 퀘스트 뒤에 이어지는 퀘스트는 "안 줌" 기록을 지운다
function M:Unlock(qid, npc)
	local t = Ink.cdb and Ink.cdb.qNotOffered
	if not (t and next(t)) then return end
	for _, r in ipairs(ns.QUEST_DB or {}) do
		if t[r[1]] and ((npc and npc ~= 0 and r[14] == npc) or Has(r[7], qid)) then t[r[1]] = nil end
	end
	for _, fr in ipairs(Followers()[qid] or {}) do t[fr[1]] = nil end
end

function M:Init()
	if not ns.QUEST_DB or Ink.db.questMap == false then return end
	self:Hook()
	self:InitMinimap()
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "ADDON_LOADED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE",
		"PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "QUEST_DATA_LOAD_RESULT", "UPDATE_FACTION",
		"GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "MERCHANT_SHOW", "TRAINER_SHOW",
		"TAXIMAP_OPENED", "BANKFRAME_OPENED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "UI_ERROR_MESSAGE" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	if WorldFrame and WorldFrame.HookScript then
		WorldFrame:HookScript("OnMouseDown", function(_, b) pcall(M.WorldDown, M, b) end)
		WorldFrame:HookScript("OnMouseUp", function(_, b) pcall(M.WorldUp, M, b) end)
	end
	e:SetScript("OnEvent", function(_, event, a1, a2)
		if event == "ADDON_LOADED" then
			if not M.hooked then M:Hook() end
			return
		end
		if event == "QUEST_ACCEPTED" then
			-- 본섭은 (퀘스트ID), 클래식은 (로그 번호, 퀘스트ID)
			local id = (type(a2) == "number" and a2 > 0) and a2 or a1
			if type(id) == "number" then
				M.acceptedAt = M.acceptedAt or {}
				M.acceptedAt[id] = GetTime()
			end
			-- 목표 · 게임 보고 위치가 도착한 뒤에 다시 그린다
			C_Timer.After(6.5, function() M.miniDirty = true; M.poiDirty = true; M:Queue() end)
		end
		if event == "UI_ERROR_MESSAGE" then M.lastErr = GetTime() return end
		if event == "TAXIMAP_OPENED" or event == "BANKFRAME_OPENED" or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
			M.lastOpen = GetTime()
			return
		end
		if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" or event == "QUEST_PROGRESS"
			or event == "QUEST_COMPLETE" or event == "MERCHANT_SHOW" or event == "TRAINER_SHOW" then
			M.lastOpen = GetTime()
			-- 말을 건 NPC 자리 기억 (보고하는 NPC 찾기에 씀)
			pcall(M.LearnNpc, M)
			if event == "QUEST_COMPLETE" then pcall(M.NoteTurnIn, M) end
			-- 대화창 목록이 다 채워진 뒤에 확인
			if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" then
				C_Timer.After(0.2, function() pcall(M.CheckOffered, M, event) end)
			end
			return
		end
		if event == "QUEST_TURNED_IN" and type(a1) == "number" then
			local pe = M.pendingEnd
			pcall(M.Unlock, M, a1, pe and pe.id == a1 and pe.npc or nil)
			pcall(M.SaveTurnIn, M, a1)
			M.turnedAt = M.turnedAt or {}
			M.turnedAt[a1] = GetTime()
			if M.enderCache then M.enderCache[a1] = nil end
		end
		if event == "QUEST_REMOVED" and type(a1) == "number" then
			-- 포기한 퀘스트(보고 없이 빠진 것): "안 준다"고 적어 둔 것도 지우고 바로 다시 보이게
			local t = M.turnedAt and M.turnedAt[a1]
			if not (t and GetTime() - t < 3) then
				if Ink.cdb and Ink.cdb.qNotOffered then Ink.cdb.qNotOffered[a1] = nil end
				if M.enderCache then M.enderCache[a1] = nil end
				M.miniAt = 0
				C_Timer.After(1, function() M.miniDirty = true; M.miniAt = 0; M:Queue() end)
			end
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
