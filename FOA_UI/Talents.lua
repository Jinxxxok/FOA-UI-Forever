-- FOA UI · 특성 가이드 (포에버)
--  육성(레벨업 순서 · TalentData) · PvE · PvP(60레벨 빌드 · TalentBuilds) 중 고른 빌드를 보고 "다음에 찍을 특성"을 알려 준다.
--  · 특성 창: 다음 특성 칸에 노란 테두리, 오른쪽에 FOA 안내판(다음 8개 · 빌드 고르기)
--  · 특성 포인트가 생기면 채팅에 추천을 한 줄
--  게임 안 특성은 아이콘 파일 번호로 찾는다 → 한글 / 영문 클라이언트 상관없이 맞는다.

local ADDON, ns = ...
local Ink = ns.Ink
local C, F = Ink.c, Ink.font
local M = Ink:Module("Talents")
ns.Talents = M

local GetFileIDFromPath = GetFileIDFromPath

local function TalentInfo(tab, i)
	local name, icon, tier, column, rank, maxRank = GetTalentInfo(tab, i)
	if type(icon) == "string" and GetFileIDFromPath then icon = GetFileIDFromPath(icon) or icon end
	return name, icon, tier, column, tonumber(rank) or 0, tonumber(maxRank) or 0
end

local function Unspent()
	if GetUnspentTalentPoints then return GetUnspentTalentPoints() or 0 end
	if UnitCharacterPoints then return (UnitCharacterPoints("player")) or 0 end
	return 0
end

-------------------------------------------------------------------------------
-- 포에버 특성 체계: 클래식식 함수(GetTalentInfo)가 없고 용군단식 특성(C_ClassTalents · C_Traits)을 쓴다.
--  특성 칸(노드)마다 주문 아이콘을 읽어서, 데이터의 아이콘 번호와 맞춘다.
-------------------------------------------------------------------------------
local function TraitsMode()
	return not GetNumTalentTabs and C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID and true or false
end
M.TraitsMode = TraitsMode

local function ConfigID()
	local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
	return ok and id or nil
end

local function SpellIcon(spellID)
	if not spellID then return end
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
	if GetSpellTexture then return GetSpellTexture(spellID) end
end

local function SpellName(spellID)
	if not spellID then return end
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
	if GetSpellInfo then return (GetSpellInfo(spellID)) end
end

-- 노드 목록: { node, icon, rank, max, name }
local function TraitNodes()
	local cfg = ConfigID()
	if not cfg then return {} end
	local okc, info = pcall(C_Traits.GetConfigInfo, cfg)
	if not okc or not info or not info.treeIDs then return {} end
	local out = {}
	for _, tree in ipairs(info.treeIDs) do
		local okn, nodes = pcall(C_Traits.GetTreeNodes, tree)
		for _, nodeID in ipairs(okn and nodes or {}) do
			local ok, n = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
			if ok and n and n.ID and n.ID ~= 0 and (n.isVisible ~= false) then
				local entryID = (n.activeEntry and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
				local icon, name
				if entryID then
					local oke, e = pcall(C_Traits.GetEntryInfo, cfg, entryID)
					if oke and e and e.definitionID then
						local okd, d = pcall(C_Traits.GetDefinitionInfo, e.definitionID)
						if okd and d then
							icon = d.overrideIcon or SpellIcon(d.spellID)
							name = d.overrideName or SpellName(d.spellID)
						end
					end
				end
				out[#out + 1] = { node = nodeID, entry = entryID, icon = icon, name = name,
					rank = n.currentRank or n.ranksPurchased or 0, bought = n.ranksPurchased, max = n.maxRanks or 1 }
			end
		end
	end
	return out
end
M.TraitNodes = TraitNodes

local IconMap, PickFor -- 아래에서 정의 (위의 빌드 비교 함수들이 먼저 쓴다)

local function NodeRank(nodeID)
	local cfg = ConfigID()
	if not cfg then return 0 end
	local ok, n = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
	return ok and n and (n.currentRank or n.ranksPurchased) or 0
end

-- 찍은 특성으로 특성(빌드) 짐작: 각 빌드의 단계 아이콘과 겹치는 찍은 단계 수가 가장 많은 것
function M:GuessSpec()
	if not TraitsMode() then return end
	local _, class = UnitClass("player")
	local byIcon = {}
	local spent = 0
	for _, n in ipairs(TraitNodes()) do
		if n.icon and n.rank > 0 then byIcon[n.icon] = (byIcon[n.icon] or 0) + n.rank; spent = spent + n.rank end
	end
	if spent == 0 then return end
	local best, bestN = nil, 0
	for key, b in pairs(ns.TalentData and ns.TalentData.builds or {}) do
		local cls, spec = key:match("^(%u+):(%w+)$")
		if cls == class then
			local seen, n = {}, 0
			for _, st in ipairs(b.steps) do
				if not seen[st[1]] then seen[st[1]] = true; n = n + (byIcon[st[1]] or 0) end
			end
			if n > bestN then best, bestN = spec, n end
		end
	end
	return best
end

-------------------------------------------------------------------------------
-- PvE · PvP 빌드 (TalentBuilds) → TalentData.builds 에 "직업:전문화:모드:번호" 로 넣는다
--  단계 = { 아이콘 파일, 목표 단계, 최대, 시작 레벨, 끝 레벨, 영문 이름, false, 노드 번호 }
-------------------------------------------------------------------------------
local MODES = { "lvl", "pve", "pvp" }
local MODE_NAME = { lvl = "육성", pve = "PvE", pvp = "PvP" }
M.MODES, M.MODE_NAME = MODES, MODE_NAME

local function LoadBuilds()
	local data = ns.TalentData and ns.TalentData.builds
	if not data or M.loaded then return end
	M.loaded = true
	for key, b in pairs(data) do
		if not b.mode then b.mode = "lvl"; b.spec = key:match(":(%w+)$"); b.src = b.src or "wowf.io" end
	end
	local src = ns.TalentBuilds
	if not src then return end
	local nodes = {}
	for cls, str in pairs(src.nodes) do
		for part in str:gmatch("[^;]+") do
			local id, fid, mx, t, r, name = part:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(.*)$")
			if id then nodes[tonumber(id)] = { tonumber(fid), tonumber(mx), tonumber(t), tonumber(r), name, cls } end
		end
	end
	M.nodeInfo = nodes
	local count = {}
	for _, e in ipairs(src.list) do
		local key, mode, label, origin, runs = e[1], e[2], e[3], e[4], e[5]
		local spec = key:match(":(%w+)$")
		local steps, split, final, total, ok = {}, { 0, 0, 0 }, {}, 0, true
		for sid, stg in runs:gmatch("(%d+):(%d+)") do
			local id, tg = tonumber(sid), tonumber(stg)
			local n = nodes[id]
			local add = n and (tg - (final[id] or 0)) or 0
			if not n or add <= 0 then ok = false break end
			steps[#steps + 1] = { n[1], tg, n[2], 10 + total, 9 + total + add, n[5], false, id }
			total = total + add
			split[n[3] + 1] = split[n[3] + 1] + add
			final[id] = tg
		end
		if ok and #steps > 0 then
			local c = (count[key .. mode] or 0) + 1
			count[key .. mode] = c
			data[key .. ":" .. mode .. ":" .. c] = { label = label, steps = steps, mode = mode, spec = spec, src = origin, split = split, total = total }
		end
	end
end
M.LoadBuilds = LoadBuilds

-------------------------------------------------------------------------------
-- 빌드 고르기 · 게임 특성과 맞추기
-------------------------------------------------------------------------------
function M:Mode()
	local m = Ink.cdb and Ink.cdb.talentMode
	if m == "pve" or m == "pvp" then return m end
	return "lvl"
end

function M:SetMode(mode)
	if not Ink.cdb then return end
	Ink.cdb.talentMode = mode
	self.resolved, self.autoKey = nil, nil
end

-- 전문화 순서: 게임 특성 탭 순서 (야성 곰은 야성 다음)
local function SpecOrder(class)
	local t = {}
	for i, sp in ipairs(ns.Score and ns.Score.TABS and ns.Score.TABS[class] or {}) do t[sp] = i end
	if t.feral then t.guardian = t.feral + 0.5 end
	return t
end

function M:Builds(mode)
	LoadBuilds()
	mode = mode or self:Mode()
	local _, class = UnitClass("player")
	local list = {}
	local data = ns.TalentData and ns.TalentData.builds or {}
	for key, b in pairs(data) do
		if key:match("^" .. class .. ":") and (b.mode or "lvl") == mode then list[#list + 1] = key end
	end
	local ord = SpecOrder(class)
	table.sort(list, function(a, b)
		local oa, ob = ord[data[a].spec or ""] or 9, ord[data[b].spec or ""] or 9
		if oa ~= ob then return oa < ob end
		return a < b
	end)
	return list
end

-- 아이콘 → 트리 (이 직업 1.60.1 특성 칸 표 · 두 트리에 같은 아이콘이 있으면 쓰지 않는다)
local iconTreeCache = {}
function M.IconTree(class)
	if iconTreeCache[class] then return iconTreeCache[class] end
	LoadBuilds()
	local t, dup = {}, {}
	for _, n in pairs(M.nodeInfo or {}) do
		if n[6] == class then
			if t[n[1]] and t[n[1]] ~= n[3] then dup[n[1]] = true end
			t[n[1]] = n[3]
		end
	end
	for icon in pairs(dup) do t[icon] = nil end
	iconTreeCache[class] = t
	return t
end

-- 지금 찍은 트리별 점수 { 1트리, 2트리, 3트리 } · 칸 번호 → 트리, 없으면 아이콘 → 트리
function M.TreePoints(class)
	if not TraitsMode() then return end
	LoadBuilds()
	class = class or select(2, UnitClass("player"))
	local info, byIcon = M.nodeInfo or {}, M.IconTree(class)
	local pts, any = { 0, 0, 0 }, false
	for _, n in ipairs(TraitNodes()) do
		local r = n.bought or n.rank or 0
		if r > 0 then
			local ni = info[n.node]
			local t = (ni and ni[6] == class and ni[3]) or (n.icon and byIcon[n.icon])
			if t then pts[t + 1] = pts[t + 1] + r; any = true end
		end
	end
	return any and pts or nil
end

-- 지금 찍은 특성 중 이 빌드와 맞는 점수 (빌드마다) · 지금 찍은 전체 점수
function M:OverlapFor(key, map, byNode)
	local b = key and ns.TalentData.builds[key]
	if not b then return 0 end
	if not map then map, byNode = IconMap() end
	local final, where = {}, {}
	for _, s in ipairs(b.steps) do
		local pick = PickFor(s, map, byNode)
		if pick then
			local k = pick.node and ("n" .. pick.node) or (pick.t .. ":" .. pick.i)
			final[k] = math.max(final[k] or 0, math.min(s[2], pick.max or s[2]))
			where[k] = pick
		end
	end
	local match = 0
	for k, tg in pairs(final) do
		local p = where[k]
		local cur = p.node and NodeRank(p.node) or select(5, TalentInfo(p.t, p.i))
		match = match + math.min(tonumber(cur) or 0, tg)
	end
	return match
end

-- 이 모드에서 지금 특성과 가장 잘 맞는 빌드 (같은 전문화 우선)
function M:BestMatch(mode, sameSpec)
	local list = self:Builds(mode)
	local map, byNode = IconMap()
	local best, bestN = nil, -1
	for _, k in ipairs(list) do
		if not sameSpec or ns.TalentData.builds[k].spec == sameSpec then
			local n = self:OverlapFor(k, map, byNode)
			if n > bestN then best, bestN = k, n end
		end
	end
	return best, bestN
end

function M:BuildKey()
	local mode = self:Mode()
	local list = self:Builds(mode)
	if #list == 0 then return end
	local data = ns.TalentData.builds
	local pick = Ink.cdb and Ink.cdb.talentPick
	local want = pick and pick[mode]
	if not want and mode == "lvl" then want = Ink.cdb and Ink.cdb.talentBuild end
	if want and data[want] and (data[want].mode or "lvl") == mode then
		for _, k in ipairs(list) do if k == want then return want end end
	end
	-- 고른 적이 없으면: 지금 전문화의 빌드 중 지금 찍은 특성과 가장 잘 맞는 것
	if self.autoKey and self.autoMode == mode and self.autoAt and GetTime() - self.autoAt < 3 then return self.autoKey end
	local spec
	if ns.Score then spec = select(2, ns.Score:Spec()) end
	local key
	if spec then
		local ok, k = pcall(self.BestMatch, self, mode, spec)
		key = ok and k or nil
		if not key then for _, k2 in ipairs(list) do if data[k2].spec == spec then key = k2 break end end end
	end
	key = key or list[1]
	self.autoKey, self.autoMode, self.autoAt = key, mode, GetTime()
	return key
end

function M:PickBuild(key)
	if not (Ink.cdb and key) then return end
	local mode = (ns.TalentData.builds[key] or {}).mode or "lvl"
	Ink.cdb.talentPick = Ink.cdb.talentPick or {}
	Ink.cdb.talentPick[mode] = key
	if mode == "lvl" then Ink.cdb.talentBuild = key end
	self.resolved = nil
end

-- 보여 줄 이름: 육성은 원래 이름 ("전투 · 레벨업"), PvE · PvP 는 "잠행 · 뒤치기 표준"
function M:BuildLabel(key)
	local b = key and ns.TalentData.builds[key]
	if not b then return "빌드 없음" end
	if b.mode == "lvl" then return b.label end
	local sn = ns.Score and ns.Score.SPEC_NAME and ns.Score.SPEC_NAME[b.spec or ""] or b.spec or ""
	return sn ~= "" and (sn .. " · " .. b.label) or b.label
end

-- 아이콘 → 게임 특성 위치
IconMap = function()
	local map, byNode = {}, {}
	if TraitsMode() then
		for _, n in ipairs(TraitNodes()) do
			local c = { node = n.node, max = n.max, name = n.name, icon = n.icon }
			byNode[n.node] = c
			if n.icon then
				map[n.icon] = map[n.icon] or {}
				table.insert(map[n.icon], c)
			end
		end
		return map, byNode
	end
	local tabs = GetNumTalentTabs and GetNumTalentTabs() or 0
	for t = 1, tabs do
		for i = 1, (GetNumTalents(t) or 0) do
			local name, icon, _, _, _, maxRank = TalentInfo(t, i)
			if icon then
				map[icon] = map[icon] or {}
				table.insert(map[icon], { t = t, i = i, max = maxRank, name = name })
			end
		end
	end
	return map, byNode
end

-- 데이터 단계 하나 → 게임 특성 칸 (노드 번호가 있으면 그것으로, 없으면 아이콘 + 최대 단계로)
PickFor = function(s, map, byNode)
	local pick = s[8] and byNode[s[8]]
	if not pick then
		local cands = map[s[1]]
		if cands then
			for _, c in ipairs(cands) do if c.max == s[3] then pick = c break end end
			pick = pick or cands[1]
		end
	end
	return pick
end

function M:Resolve()
	local key = self:BuildKey()
	if not key then return end
	if self.resolved and self.resolvedKey == key then return self.resolved end
	local map, byNode = IconMap()
	local steps = {}
	local prev = {}
	local miss = 0
	for _, s in ipairs(ns.TalentData.builds[key].steps) do
		local fid, target, max, lo, hi, en = s[1], s[2], s[3], s[4], s[5], s[6]
		-- 노드 번호가 있으면 그것으로 (같은 아이콘 특성이 여럿이어도 정확), 없으면 아이콘 + 최대 단계로
		local pick = PickFor(s, map, byNode)
		local r = { lo = lo, hi = hi, en = en, icon = (pick and pick.icon) or fid }
		if pick then
			r.t, r.i, r.node, r.max, r.name = pick.t, pick.i, pick.node, pick.max, pick.name
			local k = pick.node and ("n" .. pick.node) or (pick.t .. ":" .. pick.i)
			r.k = k
			r.from = prev[k] or 0
			r.target = math.min(target, pick.max)
			prev[k] = r.target
		else
			miss = miss + 1
		end
		steps[#steps + 1] = r
	end
	self.resolved, self.resolvedKey, self.missing = steps, key, miss
	return steps
end

-- 다음에 찍을 특성 n개 (지금 찍힌 단계부터 이어서)
function M:Next(n)
	local steps = self:Resolve()
	if not steps then return {} end
	local out, sim = {}, {}
	for _, s in ipairs(steps) do
		if s.k then
			local k = s.k
			local cur = sim[k]
			if cur == nil then
				if s.node then cur = NodeRank(s.node) else cur = select(5, TalentInfo(s.t, s.i)) end
			end
			while cur < s.target and #out < n do
				cur = cur + 1
				out[#out + 1] = { t = s.t, i = s.i, node = s.node, name = s.name or s.en, icon = s.icon, rank = cur, max = s.max,
					level = math.max(s.lo, math.min(s.hi, s.lo + (cur - s.from) - 1)) }
			end
			sim[k] = cur
			if #out >= n then break end
		end
	end
	return out
end

-- 지금 찍은 특성 중 이 빌드와 겹치는 점수 · 전체 찍은 점수
function M:Overlap()
	local steps = self:Resolve()
	if not steps then return end
	local final, where = {}, {}
	for _, s in ipairs(steps) do
		if s.k then final[s.k] = math.max(final[s.k] or 0, s.target); where[s.k] = s end
	end
	local match = 0
	for k, tg in pairs(final) do
		local s = where[k]
		local cur
		if s.node then cur = NodeRank(s.node) else cur = select(5, TalentInfo(s.t, s.i)) end
		match = match + math.min(tonumber(cur) or 0, tg)
	end
	local spent = 0
	if TraitsMode() then
		for _, n in ipairs(TraitNodes()) do spent = spent + (n.bought or n.rank or 0) end
	elseif GetNumTalentTabs then
		for t = 1, GetNumTalentTabs() do
			for i = 1, (GetNumTalents(t) or 0) do spent = spent + select(5, TalentInfo(t, i)) end
		end
	end
	return match, math.max(spent, match)
end

-- 빌드의 트리별 목표 점수 (PvE · PvP 는 자료에 있음, 육성은 게임 특성 칸 → 트리로 계산)
function M:SplitOf(key)
	local b = key and ns.TalentData.builds[key]
	if not b then return end
	if b.split then return b.split end
	if key ~= self:BuildKey() then return end
	local steps = self:Resolve()
	if not steps then return end
	local _, class = UnitClass("player")
	local info, byIcon = M.nodeInfo or {}, M.IconTree(class)
	local final, tree = {}, {}
	for _, r in ipairs(steps) do
		if r.k then
			final[r.k] = math.max(final[r.k] or 0, r.target or 0)
			local ni = r.node and info[r.node]
			tree[r.k] = (ni and ni[6] == class and ni[3]) or (r.icon and byIcon[r.icon]) or tree[r.k]
		end
	end
	local sp, any = { 0, 0, 0 }, false
	for k, v in pairs(final) do
		local t = tree[k]
		if t then sp[t + 1] = sp[t + 1] + v; any = true end
	end
	return any and sp or nil
end

-------------------------------------------------------------------------------
-- 특성 창: 다음 특성 테두리 + 안내판
-------------------------------------------------------------------------------
local function TalentFrame()
	return _G.PlayerTalentFrame or _G.TalentFrame
end

-- 용군단식 특성 창 (불러온 뒤에만 있다)
local function TraitFrame()
	local psf = _G.PlayerSpellsFrame
	if psf and psf.TalentsFrame then return psf.TalentsFrame, psf end
	local ctf = _G.ClassTalentFrame
	if ctf and ctf.TalentsTab then return ctf.TalentsTab, ctf end
end

local function SelectedTab(f)
	if PanelTemplates_GetSelectedTab then
		local t = PanelTemplates_GetSelectedTab(f)
		if t then return t end
	end
	return f.selectedTab or f.talentTabIndex or 1
end

local function Glow(b)
	if b.foaNext then return b.foaNext end
	local g = CreateFrame("Frame", nil, b)
	g:SetPoint("TOPLEFT", -3, 3)
	g:SetPoint("BOTTOMRIGHT", 3, -3)
	g:SetFrameLevel(b:GetFrameLevel() + 5)
	g.edge = Ink:Round(g, "OVERLAY", true, true)
	g.edge:SetAllPoints()
	g.edge:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
	g.tag = Ink:Text(g, F.bold, 10, C.accent, "CENTER")
	g.tag:SetPoint("BOTTOM", g, "TOP", 0, 1)
	g.tag:SetText("다음")
	local ag = g:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.7)
	a:SetSmoothing("IN_OUT")
	ag:Play()
	g.ag = ag
	b.foaNext = g
	return g
end

function M:PaintTraitFrame()
	local tf, host = TraitFrame()
	-- 특성 탭이 보일 때만 (같은 창의 마법책 탭에서는 숨김 → 거기엔 배울 주문 안내가 뜬다)
	if not tf or not host or not host:IsShown() or not tf:IsVisible() then if self.panel then self.panel:Hide() end return end
	local nxt = self:Next(8)
	local first = nxt[1]
	-- 이전 강조 지우기
	for b in pairs(self.glowed or {}) do if b.foaNext then b.foaNext:Hide() end end
	self.glowed = {}
	if first and first.node and tf.GetTalentButtonByNodeID and Ink.db.talentGuide ~= false then
		local ok, b = pcall(tf.GetTalentButtonByNodeID, tf, first.node)
		if ok and b then Glow(b):Show(); self.glowed[b] = true end
	end
	self:PaintPanel(host, nxt)
end

function M:PaintFrame()
	if TraitsMode() then return self:PaintTraitFrame() end
	local f = TalentFrame()
	if not f or not f:IsShown() then if self.panel then self.panel:Hide() end return end
	local nxt = self:Next(8)
	local first = nxt[1]
	local tab = SelectedTab(f)
	local prefix = (f == _G.PlayerTalentFrame) and "PlayerTalentFrameTalent" or "TalentFrameTalent"
	for i = 1, 40 do
		local b = _G[prefix .. i]
		if not b then break end
		local on = first and first.t == tab and b:GetID() == first.i and Ink.db.talentGuide ~= false
		if on then Glow(b):Show() elseif b.foaNext then b.foaNext:Hide() end
	end
	-- 추천이 다른 탭이면 그 탭 버튼에 점
	local tabPrefix = (f == _G.PlayerTalentFrame) and "PlayerTalentFrameTab" or "TalentFrameTab"
	for t = 1, 3 do
		local tb = _G[tabPrefix .. t]
		if tb then
			if not tb.foaDot then
				tb.foaDot = tb:CreateTexture(nil, "OVERLAY", nil, 7)
				tb.foaDot:SetTexture(Ink.tex.round4)
				tb.foaDot:SetSize(7, 7)
				tb.foaDot:SetPoint("TOPRIGHT", -6, -4)
				tb.foaDot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
			end
			tb.foaDot:SetShown(first and first.t == t and Ink.db.talentGuide ~= false and true or false)
		end
	end
	self:PaintPanel(f, nxt)
end

local W = 222  -- 안내판 안쪽 너비

local function Paint(tex, c, a) tex:SetVertexColor(c[1], c[2], c[3], a or 1) end

function M:BuildPanel(f)
	local p = CreateFrame("Frame", "FOATalentGuide", f)
	p:SetSize(250, 400)
	Ink:PanelPoint(p, "talent", f, 6, -12)
	Ink:MakeDraggable(p, "talent", f)
	p.foaResetPos = function() Ink:PanelPoint(p, "talent", f, 6, -12) end
	p:SetFrameStrata(f:GetFrameStrata())
	p.bg = Ink:Round(p, "BACKGROUND", false, false)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(0.05, 0.06, 0.08, 0.96)
	p.bd = Ink:Round(p, "BORDER", false, true)
	p.bd:SetAllPoints()
	p.bd:SetVertexColor(1, 1, 1, 0.1)
	local acc = p:CreateTexture(nil, "ARTWORK")
	acc:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	acc:SetSize(22, 2)
	acc:SetPoint("TOPLEFT", 14, -1)
	p.title = Ink:Text(p, F.bold, 13, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", 14, -12)
	p.title:SetText("FOA 특성 가이드")

	-- 육성 · PvE · PvP: 한 줄 세그먼트 (고른 칸만 채운 알약)
	p.seg = CreateFrame("Frame", nil, p)
	p.seg:SetSize(W, 24)
	p.seg:SetPoint("TOPLEFT", 14, -34)
	p.seg.bg = Ink:Round(p.seg, "BACKGROUND", true, false)
	p.seg.bg:SetAllPoints()
	p.seg.bg:SetVertexColor(1, 1, 1, 0.04)
	p.modes = {}
	local sw = (W - 4) / 3
	for i, mode in ipairs(MODES) do
		local b = CreateFrame("Button", nil, p.seg)
		b:SetSize(sw, 20)
		b:SetPoint("LEFT", 2 + (i - 1) * sw, 0)
		b.fill = Ink:Round(b, "ARTWORK", true, false)
		b.fill:SetAllPoints()
		b.text = Ink:Text(b, F.semi, 11, C.muted, "CENTER")
		b.text:SetPoint("CENTER", 0, 0)
		b.text:SetText(MODE_NAME[mode])
		b.mode = mode
		b:SetScript("OnClick", function(self)
			if self.off then return end
			M:SetMode(self.mode)
			M:PaintFrame()
		end)
		b:SetScript("OnEnter", function(self) self.hover = true; M:PaintModes() end)
		b:SetScript("OnLeave", function(self) self.hover = nil; M:PaintModes() end)
		p.modes[i] = b
	end

	-- 빌드 카드: 이름 · n / m / 트리 세 칸 (빌드 목표 · 지금 찍은 만큼 막대) / 상태 한 줄
	local CARD_H = 96
	p.build = CreateFrame("Button", nil, p)
	p.build:SetSize(W, CARD_H)
	p.build:SetPoint("TOPLEFT", 14, -64)
	p.build:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	p.build.bg = Ink:Round(p.build, "BACKGROUND", true, false)
	p.build.bg:SetAllPoints()
	p.build.bg:SetVertexColor(1, 1, 1, 0.045)
	p.build.text = Ink:Text(p.build, F.semi, 12, C.accent, "LEFT")
	p.build.text:SetPoint("TOPLEFT", 10, -9)
	p.build.text:SetWidth(W - 64)
	p.build.text:SetWordWrap(false)
	p.build.hint = Ink:Text(p.build, F.latinB, 10, C.dim, "RIGHT")
	p.build.hint:SetPoint("TOPRIGHT", -10, -10)
	-- 트리 세 칸
	local GAP = 10
	local colW = math.floor((W - 20 - GAP * 2) / 3)
	p.build.cols = {}
	for t = 1, 3 do
		local c = CreateFrame("Frame", nil, p.build)
		c:SetSize(colW, 34)
		c:SetPoint("TOPLEFT", 10 + (t - 1) * (colW + GAP), -31)
		c.name = Ink:Text(c, F.sans, 10, C.muted, "LEFT")
		c.name:SetPoint("TOPLEFT", 0, 0)
		c.tgt = Ink:Text(c, F.latinB, 12, C.text, "RIGHT")
		c.tgt:SetPoint("TOPRIGHT", 0, 1)
		c.track = c:CreateTexture(nil, "ARTWORK")
		c.track:SetTexture(Ink.tex.white or "Interface\\Buttons\\WHITE8X8")
		c.track:SetPoint("TOPLEFT", 0, -16)
		c.track:SetSize(colW, 3)
		c.track:SetVertexColor(1, 1, 1, 0.08)
		c.fill = c:CreateTexture(nil, "OVERLAY")
		c.fill:SetTexture(Ink.tex.white or "Interface\\Buttons\\WHITE8X8")
		c.fill:SetPoint("TOPLEFT", 0, -16)
		c.fill:SetHeight(3)
		c.cur = Ink:Text(c, F.sans, 9, C.dim, "LEFT")
		c.cur:SetPoint("TOPLEFT", 0, -23)
		c.over = Ink:Text(c, F.latinB, 9, C.orange, "RIGHT")
		c.over:SetPoint("TOPRIGHT", 0, -23)
		c.w = colW
		p.build.cols[t] = c
	end
	-- 상태 한 줄 (지금 특성과 더 맞는 빌드가 있으면 눌러서 바로 바꾼다)
	p.build.sep = p.build:CreateTexture(nil, "ARTWORK")
	p.build.sep:SetColorTexture(1, 1, 1, 0.06)
	p.build.sep:SetHeight(1)
	p.build.sep:SetPoint("TOPLEFT", 10, -69)
	p.build.sep:SetPoint("TOPRIGHT", -10, -69)
	p.build.status = CreateFrame("Button", nil, p.build)
	p.build.status:SetSize(W - 20, 18)
	p.build.status:SetPoint("TOPLEFT", 10, -73)
	p.build.status.dot = p.build.status:CreateTexture(nil, "OVERLAY")
	p.build.status.dot:SetTexture(Ink.tex.round4 or Ink.tex.disc)
	p.build.status.dot:SetSize(6, 6)
	p.build.status.dot:SetPoint("LEFT", 0, 0)
	p.build.status.text = Ink:Text(p.build.status, F.sans, 10, C.soft, "LEFT")
	p.build.status.text:SetPoint("LEFT", p.build.status.dot, "RIGHT", 6, 0)
	p.build.status.text:SetWidth(W - 34)
	p.build.status.text:SetWordWrap(false)
	p.build.status:SetScript("OnClick", function(self, btn)
		if self.suggest then
			M:PickBuild(self.suggest)
			M:PaintFrame()
		else
			p.build:GetScript("OnClick")(p.build, btn)
		end
	end)
	p.build.status:SetScript("OnEnter", function(self)
		if self.suggest then self.text:SetTextColor(C.text[1], C.text[2], C.text[3]) end
		p.build.bg:SetVertexColor(1, 1, 1, 0.075)
		M:BuildTip(p.build)
	end)
	p.build.status:SetScript("OnLeave", function(self)
		if self.suggest then self.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end
		p.build.bg:SetVertexColor(1, 1, 1, 0.045)
		GameTooltip:Hide()
	end)
	p.build:SetScript("OnClick", function(_, btn)
		local list = M:Builds()
		if #list < 2 then return end
		local cur = M:BuildKey()
		local idx = 1
		for n, k in ipairs(list) do if k == cur then idx = n end end
		idx = btn == "RightButton" and ((idx - 2) % #list + 1) or (idx % #list + 1)
		M:PickBuild(list[idx])
		M:PaintFrame()
		if GameTooltip:IsOwned(p.build) then M:BuildTip(p.build) end
	end)
	p.build:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.075)
		M:BuildTip(self)
	end)
	p.build:SetScript("OnLeave", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.045)
		GameTooltip:Hide()
	end)
	local ROW_TOP = 64 + CARD_H + 6
	p.rowTop = ROW_TOP

	p.rows = {}
	for i = 1, 8 do
		local r = CreateFrame("Frame", nil, p)
		r:SetSize(W, 28)
		r:SetPoint("TOPLEFT", 14, -ROW_TOP - (i - 1) * 30)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(24, 24)
		r.icon:SetPoint("LEFT", 0, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.name = Ink:Text(r, F.semi, 11, C.text, "LEFT")
		r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 5)
		r.name:SetWidth(150)
		r.name:SetWordWrap(false)
		r.sub = Ink:Text(r, F.sans, 10, C.dim, "LEFT")
		r.sub:SetPoint("LEFT", r.icon, "RIGHT", 8, -7)
		r.lv = Ink:Text(r, F.latinB, 10, C.muted, "RIGHT")
		r.lv:SetPoint("RIGHT", 0, 0)
		p.rows[i] = r
	end
	p.foot = Ink:Text(p, F.sans, 9, C.dim, "LEFT")
	p.foot:SetPoint("TOPLEFT", 14, -ROW_TOP - 8 * 30 - 4)
	p.foot:SetWidth(W)
	p.foot:SetWordWrap(true)
	self.panel = p
	return p
end

-- 세그먼트 색: 고른 칸 = 강조색 알약 · 빌드가 없는 칸은 흐리게
function M:PaintModes()
	local p = self.panel
	if not p then return end
	local cur = self:Mode()
	for _, b in ipairs(p.modes) do
		b.off = #self:Builds(b.mode) == 0
		if b.mode == cur then
			Paint(b.fill, C.accent, 0.16)
			b.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		else
			b.fill:SetVertexColor(1, 1, 1, b.hover and not b.off and 0.06 or 0)
			local c = b.off and C.dim or (b.hover and C.text or C.muted)
			b.text:SetTextColor(c[1], c[2], c[3], b.off and 0.5 or 1)
		end
	end
end

-- 빌드 목록 툴팁: 이 모드의 빌드 전부 · 지금 것 강조
function M:BuildTip(owner)
	local list = self:Builds()
	local cur = self:BuildKey()
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 6, 0)
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cffFFF468FOA|r  " .. MODE_NAME[self:Mode()] .. " 빌드")
	local map, byNode = IconMap()
	for _, k in ipairs(list) do
		local b = ns.TalentData.builds[k]
		local split = b.split and string.format("  |cff5E636B%d/%d/%d|r", b.split[1], b.split[2], b.split[3]) or ""
		local ok, n = pcall(self.OverlapFor, self, k, map, byNode)
		local fit = (ok and n and n > 0) and string.format("  |cff8E939B맞는 점수 %d|r", n) or ""
		if k == cur then
			GameTooltip:AddLine("|cffFFF468●|r  " .. self:BuildLabel(k) .. split .. fit, 1, 1, 1)
		else
			GameTooltip:AddLine("|cff5E636B○|r  " .. self:BuildLabel(k) .. split .. fit, 0.71, 0.72, 0.75)
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("트리 칸: 큰 숫자 = 빌드 목표 점수 · 막대 = 지금 찍은 만큼", 0.56, 0.58, 0.61)
	if #list > 1 then GameTooltip:AddLine("클릭: 다음  ·  오른쪽 클릭: 이전", 0.56, 0.58, 0.61) end
	GameTooltip:Show()
end

local SRC_NOTE = {
	["wowf.io"] = "wowf.io 레벨업 순서 · 출시 후 바뀔 수 있음",
}

local TREE_NAMES
function M:PaintPanel(f, nxt)
	if Ink.db.talentGuide == false then if self.panel then self.panel:Hide() end return end
	local p = self.panel or self:BuildPanel(f)
	p:Show()
	self:PaintModes()
	local key = self:BuildKey()
	local b = key and ns.TalentData.builds[key]
	local list = self:Builds()
	p.build.text:SetText(self:BuildLabel(key))
	local idx = 0
	for n, k in ipairs(list) do if k == key then idx = n end end
	p.build.hint:SetText(#list > 1 and string.format("%d / %d", idx, #list) or "")

	-- 트리 세 칸: 빌드 목표 점수 · 지금 찍은 점수
	local split = self:SplitOf(key)
	local now = M.TreePoints()
	local _, class = UnitClass("player")
	local tabs = ns.Score and ns.Score.TABS and ns.Score.TABS[class] or {}
	local deep = 1
	if split then for t = 2, 3 do if split[t] > split[deep] then deep = t end end end
	for t, c in ipairs(p.build.cols) do
		local sk = tabs[t]
		c.name:SetText(sk and ns.Score.SPEC_NAME and ns.Score.SPEC_NAME[sk] or ("트리 " .. t))
		local tg = split and split[t]
		local cur = now and now[t] or 0
		c.tgt:SetText(tg and tostring(tg) or "–")
		local main = split and t == deep
		local col = main and C.accent or C.soft
		c.name:SetTextColor((main and C.accent or C.muted)[1], (main and C.accent or C.muted)[2], (main and C.accent or C.muted)[3])
		c.tgt:SetTextColor((main and C.accent or C.text)[1], (main and C.accent or C.text)[2], (main and C.accent or C.text)[3], (tg and tg > 0) and 1 or 0.45)
		local f = (tg and tg > 0) and math.min(cur, tg) / tg or 0
		c.fill:SetWidth(math.max(0.01, c.w * f))
		c.fill:SetVertexColor(col[1], col[2], col[3], main and 0.95 or 0.6)
		c.fill:SetShown(f > 0)
		c.cur:SetText(now and ("지금 " .. cur) or "")
		c.over:SetText((now and tg and cur > tg) and ("+" .. (cur - tg)) or "")
	end

	-- 상태 한 줄
	local over, spent = self:Overlap()
	over, spent = over or 0, spent or 0
	local total = (b and b.total) or (split and (split[1] + split[2] + split[3])) or 0
	local st = p.build.status
	st.suggest = nil
	local bestKey, bestN
	if spent > 0 then
		local ok, k, n = pcall(self.BestMatch, self, self:Mode())
		if ok then bestKey, bestN = k, n end
	end
	local dotC, txtC, msg
	if spent == 0 then
		dotC, txtC, msg = C.dim, C.muted, "아직 찍은 특성이 없어요 · 아래 순서대로 찍으세요"
	elseif bestKey and bestKey ~= key and (bestN or 0) >= over + 5 then
		st.suggest = bestKey
		dotC, txtC, msg = C.accent, C.accent, "지금 찍은 특성과 더 맞는 빌드  ·  " .. self:BuildLabel(bestKey) .. "  ›"
	elseif spent > over then
		dotC, txtC, msg = C.orange, C.soft, string.format("빌드와 다른 점수 %d점 · 초기화하면 이대로 맞춰져요", spent - over)
	else
		dotC, txtC = C.green, C.soft
		msg = total > 0 and string.format("빌드대로 가는 중 · %d / %d점", over, total) or "빌드대로 가는 중"
	end
	st.dot:SetVertexColor(dotC[1], dotC[2], dotC[3], 1)
	st.text:SetText(msg)
	st.text:SetTextColor(txtC[1], txtC[2], txtC[3])

	TREE_NAMES = TREE_NAMES or {}
	for i, r in ipairs(p.rows) do
		local n = nxt[i]
		if n then
			r:Show()
			r.icon:SetTexture(n.icon or 134400)
			r.name:SetText(n.name or "?")
			if n.t and not TREE_NAMES[n.t] and GetTalentTabInfo then
				local a, b2 = GetTalentTabInfo(n.t)
				TREE_NAMES[n.t] = type(a) == "string" and a or (type(b2) == "string" and b2) or ""
			end
			local tree = n.t and TREE_NAMES[n.t] or ""
			r.sub:SetText(tree ~= "" and string.format("%s · %d/%d", tree, n.rank, n.max) or string.format("%d/%d 단계", n.rank, n.max))
			r.lv:SetText("Lv " .. n.level)
			if i == 1 then
				r.name:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
				r.icon:SetDesaturated(false)
			else
				r.name:SetTextColor(C.text[1], C.text[2], C.text[3])
			end
		else
			r:Hide()
		end
	end
	if #nxt == 0 then
		local r = p.rows[1]
		r:Show()
		r.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		r.name:SetText("이 빌드를 다 찍었어요")
		r.name:SetTextColor(C.green[1], C.green[2], C.green[3])
		r.sub:SetText("")
		r.lv:SetText("")
	end

	local foot
	if b and b.mode ~= "lvl" then
		local by = (b.src or ""):find("^Mobalytics") and "찍는 순서: 공략 작성자" or "찍는 순서: 위 줄부터 (FOA 정리)"
		foot = (b.src or "") .. " · 게임 1.60.1 · 60레벨 완성\n" .. by
	else
		foot = SRC_NOTE[b and b.src or "wowf.io"] or ((b and b.src or "") .. " 레벨업 순서")
	end
	if (self.missing or 0) > 0 then foot = foot .. string.format("\n게임 특성과 안 맞는 단계 %d개는 건너뜀", self.missing) end
	p.foot:SetText(foot)
	local fh = p.foot.GetStringHeight and p.foot:GetStringHeight() or 24
	p:SetHeight((p.rowTop or 166) + 8 * 30 + math.ceil(tonumber(fh) or 24) + 14)
end

function M:HookTraitFrame()
	if self.traitHooked then return end
	local tf, host = TraitFrame()
	if not tf or not host then return end
	self.traitHooked = true
	host:HookScript("OnShow", function() C_Timer.After(0.1, function() M:PaintFrame() end) end)
	host:HookScript("OnHide", function() if M.panel then M.panel:Hide() end end)
	if tf.HookScript then
		tf:HookScript("OnShow", function() C_Timer.After(0.1, function() M:PaintFrame() end) end)
		tf:HookScript("OnHide", function() if M.panel then M.panel:Hide() end end)
	end
end

function M:HookFrame()
	if TraitsMode() then return self:HookTraitFrame() end
	if self.hooked then return end
	local f = TalentFrame()
	if not f then return end
	self.hooked = true
	f:HookScript("OnShow", function() M:PaintFrame() end)
	f:HookScript("OnHide", function() if M.panel then M.panel:Hide() end end)
	for _, fn in ipairs({ "TalentFrame_Update", "PlayerTalentFrame_Update", "PlayerTalentFrame_Refresh" }) do
		if type(_G[fn]) == "function" then hooksecurefunc(fn, function() M:PaintFrame() end) end
	end
end

-------------------------------------------------------------------------------
-- 포인트가 생기면 채팅에 추천
-------------------------------------------------------------------------------
function M:Remind()
	if Ink.db.talentGuide == false then return end
	local pts = Unspent()
	if pts <= 0 then return end
	local n = self:Next(1)[1]
	if not n then return end
	local mode = self:Mode()
	local tag = mode == "lvl" and "" or ("(" .. MODE_NAME[mode] .. ") ")
	print(string.format("|cffFFF468FOA|r 특성 포인트 %d · 추천 %s|cffFFF468%s|r (%d/%d) · N 키로 특성 창", pts, tag, n.name or "?", n.rank, n.max))
end

function M:Init()
	local build = select(4, GetBuildInfo()) or 0
	if not (build >= 16001 and build < 20000) then return end -- 포에버 전용 (본섭은 특성 체계가 다름)
	if not ns.TalentData then return end
	if not ((GetNumTalentTabs and GetTalentInfo) or TraitsMode()) then return end
	if #self:Builds("lvl") + #self:Builds("pve") + #self:Builds("pvp") == 0 then return end
	self:HookFrame()
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED",
		"TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event, arg)
		if event == "ADDON_LOADED" then
			if type(arg) == "string" and (arg:find("Talent") or arg:find("PlayerSpells")) then
				C_Timer.After(0, function() M:HookFrame() end)
			end
			return
		end
		M.resolved, M.autoKey = nil, nil
		if event == "PLAYER_LEVEL_UP" then
			C_Timer.After(1, function() M:Remind() end)
		elseif event == "CHARACTER_POINTS_CHANGED" or event:find("^TRAIT_") then
			C_Timer.After(0.2, function() M:PaintFrame() end)
		else
			M:PaintFrame()
		end
	end)
	C_Timer.After(5, function() M:Remind() end)
end
