-- FOA UI · 현황 아이콘 (전문기술 · 무기 숙련 · 평판을 창을 열지 않고 둥근 아이콘으로)
--  · 전문기술 / 보조 기술 (요리 · 응급치료 · 낚시) / 자물쇠 따기: 아이콘 + 숙련 + 아래 진행 막대
--  · 무기 숙련 · 방어: 자동이면 써 본 무기 중 아직 다 안 올린 것 4개까지
--  · 평판: 자동이면 추적 중인 평판 + 이번 접속에서 오른 평판
--  · 설정 "일반 → 현황 아이콘 고르기" 에서 하나씩 켜고 끄기 (캐릭터별 · 고른 것이 자동보다 먼저)
--  숙련이 오르면 아이콘이 톡 튀고 "+1" 이 떠오른다. 마우스를 올리면 자세히.
--  위치: FOA 편집 모드 "현황 아이콘"

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Tracker")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local SIZE, GAP = 28, 8
local GOLD = { 0.89, 0.75, 0.48 }

-- 이름 → 아이콘 (그 기술을 배우는 주문의 아이콘. 이름은 게임 언어 그대로라 한국어 · 영어 다 맞는다)
local PROF_SPELLS = { 2259, 2018, 7411, 4036, 2366, 2108, 2575, 8613, 3908, 2550, 3273, 7620, 1804 }
local WEAPON_SPELLS = { 196, 197, 264, 266, 198, 199, 200, 201, 202, 227, 15590, 1180, 2567, 5011, 5009, 203, 204 }

local function SpellInfo(id)
	local name, icon
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, i = pcall(C_Spell.GetSpellInfo, id)
		if ok and i then name, icon = i.name, i.iconID end
	end
	if not name and GetSpellInfo then
		local ok, n, _, ic = pcall(GetSpellInfo, id)
		if ok then name, icon = n, ic end
	end
	return name, icon
end

local ICONS, KIND
local function BuildIcons()
	if ICONS then return end
	ICONS, KIND = {}, {}
	for _, id in ipairs(PROF_SPELLS) do
		local n, ic = SpellInfo(id)
		if n then ICONS[n] = ic; KIND[n] = "prof" end
	end
	for _, id in ipairs(WEAPON_SPELLS) do
		local n, ic = SpellInfo(id)
		if n then ICONS[n] = ic; KIND[n] = "weapon" end
	end
end

local function Section(h)
	h = h or ""
	if h:find("전문") or h:find("Profession") then return "prof" end
	if h:find("보조") or h:find("Secondary") then return "prof" end
	if h:find("무기") or h:find("Weapon") then return "weapon" end
	return "other"
end

-- 기술 번호 → 아이콘 주문 · 종류 (포에버 C_SkillInfo 는 기술 번호를 준다)
local SKILL_SPELL = {
	[171] = 2259, [164] = 2018, [333] = 7411, [202] = 4036, [182] = 2366, [165] = 2108, [186] = 2575, [393] = 8613,
	[197] = 3908, [185] = 2550, [129] = 3273, [356] = 7620, [633] = 1804,
	[173] = 1180, [43] = 201, [55] = 202, [44] = 196, [172] = 197, [54] = 198, [160] = 199, [229] = 200, [136] = 227,
	[162] = 203, [473] = 15590, [45] = 264, [46] = 266, [226] = 5011, [176] = 2567, [228] = 5009, [95] = 204,
}
local PROF_ORDER = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 185, 129, 356, 633 }
local WEAPON_ORDER = { 173, 43, 55, 44, 172, 54, 160, 229, 136, 162, 473, 45, 46, 226, 176, 228, 3014, 95 }
local PROF_ID, WEAPON_ID = {}, {}
for _, id in ipairs(PROF_ORDER) do PROF_ID[id] = true end
for _, id in ipairs(WEAPON_ORDER) do WEAPON_ID[id] = true end
-- 기술 분류 번호: 6 무기 · 9 보조 기술 · 11 전문기술
local CAT_KIND = { [6] = "weapon", [9] = "prof", [11] = "prof" }

local function SkillIcon(id, name)
	local sp = id and SKILL_SPELL[id]
	if sp then
		local _, ic = SpellInfo(sp)
		if ic then return ic end
	end
	BuildIcons()
	return name and ICONS[name]
end

local function AddSkill(out, seen, kind, name, rank, max, mod, id, icon)
	if not name or seen[name] or (max or 0) < 1 then return end
	seen[name] = true
	out[#out + 1] = { key = "s:" .. name, name = name, rank = rank or 0, max = max, mod = mod or 0, kind = kind,
		icon = icon or SkillIcon(id, name), skillID = id }
end

-- 기술 목록 읽기 (캐릭터 창 "기술" 탭과 같은 자료)
--  포에버: C_SkillInfo (번호 · 표) · 오리지널식: GetSkillLineInfo · 본섭: GetProfessions (전문기술만)
local function Skills()
	local out, seen = {}, {}
	local SI = C_SkillInfo
	if SI and SI.GetSkillLineInfo then
		local sec = "other"
		local n = SI.GetNumSkillLines and SI.GetNumSkillLines() or 0
		for i = 1, n do
			local ok, d = pcall(SI.GetSkillLineInfo, i)
			if ok and type(d) == "table" then
				if d.isHeader then
					sec = Section(d.name)
				elseif (d.parentSkillLineID or 0) == 0 then
					local id = d.skillID
					local kind = (WEAPON_ID[id] and "weapon") or (PROF_ID[id] and "prof") or CAT_KIND[d.skillLineCategoryID]
						or (sec ~= "other" and sec) or nil
					if kind then AddSkill(out, seen, kind, d.name, d.rank, d.maxRank, d.modifier, id) end
				end
			end
		end
		-- 기술 창에서 접어 둔 묶음 안의 기술은 위 목록에 안 나와서 번호로 한 번 더 찾는다
		if SI.GetSkillLineInfoByID then
			for _, grp in ipairs({ { PROF_ORDER, "prof" }, { WEAPON_ORDER, "weapon" } }) do
				for _, id in ipairs(grp[1]) do
					local ok, d = pcall(SI.GetSkillLineInfoByID, id)
					if ok and type(d) == "table" and not d.isHeader and (d.rank or 0) > 0 then
						AddSkill(out, seen, grp[2], d.name, d.rank, d.maxRank, d.modifier, id)
					end
				end
			end
		end
		if #out > 0 then return out end
	end
	if GetNumSkillLines and GetSkillLineInfo then
		BuildIcons()
		local sec = "other"
		for i = 1, GetNumSkillLines() do
			local name, header, _, rank, _, mod, max = GetSkillLineInfo(i)
			if header then
				sec = Section(name)
			elseif name and (max or 0) > 1 then
				local kind = (sec ~= "other" and sec) or KIND[name]
				if kind then AddSkill(out, seen, kind, name, rank, max, mod, nil, ICONS[name]) end
			end
		end
		if #out > 0 then return out end
	end
	if GetProfessions and GetProfessionInfo then
		local t = { GetProfessions() }
		for i = 1, 6 do
			local idx = t[i]
			if idx then
				local ok, name, icon, rank, max, _, _, line, mod = pcall(GetProfessionInfo, idx)
				if ok and name then AddSkill(out, seen, "prof", name, rank, max, mod, line, icon) end
			end
		end
	end
	return out
end

-- 평판 (추적 중 + 이번 접속에서 오른 것)
local STANDING_RGB = {
	[1] = { 0.8, 0.13, 0.13 }, [2] = { 0.8, 0.3, 0.22 }, [3] = { 0.75, 0.27, 0 }, [4] = { 0.9, 0.7, 0 },
	[5] = { 0, 0.6, 0.1 }, [6] = { 0, 0.7, 0.4 }, [7] = { 0, 0.7, 0.7 }, [8] = { 0.3, 0.6, 1 },
}

local function FactionByID(id)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, d = pcall(C_Reputation.GetFactionDataByID, id)
		if ok and d and d.name then
			return { id = id, name = d.name, standing = d.reaction, min = d.currentReactionThreshold, max = d.nextReactionThreshold, val = d.currentStanding }
		end
	end
	if GetFactionInfoByID then
		local ok, name, _, standing, bmin, bmax, val = pcall(GetFactionInfoByID, id)
		if ok and name then return { id = id, name = name, standing = standing, min = bmin, max = bmax, val = val } end
	end
end

local function Watched()
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local ok, d = pcall(C_Reputation.GetWatchedFactionData)
		if ok and d and d.factionID and d.factionID > 0 then return FactionByID(d.factionID) end
	end
	if GetWatchedFactionInfo then
		local name, standing, bmin, bmax, val, id = GetWatchedFactionInfo()
		if name then return { id = id, name = name, standing = standing, min = bmin, max = bmax, val = val } end
	end
end

local function FactionIDByName(name)
	if not name then return end
	local n = (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetNumFactions()) or (GetNumFactions and GetNumFactions()) or 0
	for i = 1, n do
		local fname, fid
		if C_Reputation and C_Reputation.GetFactionDataByIndex then
			local d = C_Reputation.GetFactionDataByIndex(i)
			fname, fid = d and d.name, d and d.factionID
		elseif GetFactionInfo then
			local r = { GetFactionInfo(i) }
			fname, fid = r[1], r[14]
		end
		if fname == name then return fid end
	end
end

-------------------------------------------------------------------------------
-- 직접 고르기 (캐릭터별 InkUICharDB.trackerPick)
--  [키] = 숫자(고정 · 고른 차례) / false(빼기) / 없음(자동)
--  키: 기술 "s:이름" · 평판 "f:진영번호" (번호를 못 얻으면 "r:이름")
-------------------------------------------------------------------------------
local function Picks(make)
	local c = Ink.cdb
	if not c then return {} end
	if make and type(c.trackerPick) ~= "table" then c.trackerPick = {} end
	return c.trackerPick or {}
end

local function Pick(key)
	local v = Picks()[key]
	if v == nil then return nil end
	return v and true or false
end

local function RepKey(f) return f.id and ("f:" .. f.id) or ("r:" .. (f.name or "?")) end

local function RepEntry(f)
	f.key = "r:" .. f.name
	f.pick = RepKey(f)
	f.kind = "rep"
	f.rank = (f.val or 0) - (f.min or 0)
	f.max = math.max(1, (f.max or 1) - (f.min or 0))
	return f
end

local function Reps()
	local out, seen = {}, {}
	local function add(f)
		if not f or not f.name then return end
		local k = RepKey(f)
		if seen[k] then return end
		seen[k] = true
		out[#out + 1] = RepEntry(f)
	end
	-- 고정한 평판 먼저 (고른 차례대로)
	local pins = {}
	for k, v in pairs(Picks()) do
		if type(v) == "number" then
			local id = tonumber(k:match("^f:(%d+)$"))
			local name = not id and k:match("^r:(.+)$")
			if id or name then pins[#pins + 1] = { id = id, name = name, n = v } end
		end
	end
	table.sort(pins, function(a, b) return a.n < b.n end)
	for _, p in ipairs(pins) do
		local id = p.id or FactionIDByName(p.name)
		if id then add(FactionByID(id)) end
	end
	-- 자동: 추적 중 + 이번 접속에서 오른 것 (뺀 것은 건너뜀 · 자동은 3개까지)
	if Ink.db.trackerReps ~= false then
		local auto = {}
		local w = Watched()
		if w then auto[#auto + 1] = w end
		for _, id in ipairs(M.recentRep or {}) do auto[#auto + 1] = FactionByID(id) end
		local n = 0
		for _, f in ipairs(auto) do
			if f and f.name and n < 3 and Pick(RepKey(f)) == nil and not seen[RepKey(f)] then
				add(f)
				n = n + 1
			end
		end
	end
	return out
end

-- 평판 창의 모든 진영 (접힌 묶음은 잠깐 펼쳐 읽고 다시 접어 둔다)
local function FactionRows()
	local CR = C_Reputation
	local useC = CR and CR.GetFactionDataByIndex and true or false
	local function num()
		if useC and CR.GetNumFactions then return CR.GetNumFactions() or 0 end
		return GetNumFactions and GetNumFactions() or 0
	end
	local function info(i)
		if useC then
			local d = CR.GetFactionDataByIndex(i)
			if not d then return end
			return { name = d.name, header = d.isHeader, collapsed = d.isCollapsed, hasRep = d.isHeaderWithRep, id = d.factionID,
				standing = d.reaction, min = d.currentReactionThreshold, max = d.nextReactionThreshold, val = d.currentStanding }
		elseif GetFactionInfo then
			local name, _, standing, bmin, bmax, val, _, _, isHeader, isCollapsed, hasRep, _, _, fid = GetFactionInfo(i)
			if not name then return end
			return { name = name, header = isHeader, collapsed = isCollapsed, hasRep = hasRep, id = fid,
				standing = standing, min = bmin, max = bmax, val = val }
		end
	end
	local expand = (useC and CR.ExpandFactionHeader) or ExpandFactionHeader
	local collapse = (useC and CR.CollapseFactionHeader) or CollapseFactionHeader
	local opened = {}
	if expand then
		local i, guard = 1, 0
		while i <= num() and guard < 400 do
			guard = guard + 1
			local d = info(i)
			if d and d.header and d.collapsed and d.name then
				if pcall(expand, i) then opened[d.name] = true end
			end
			i = i + 1
		end
	end
	local rows = {}
	for i = 1, num() do
		local d = info(i)
		if d and d.name then rows[#rows + 1] = d end
	end
	-- 펼쳤던 묶음은 뒤에서부터 다시 접는다 (앞 번호가 밀리지 않게)
	if collapse and next(opened) then
		for i = num(), 1, -1 do
			local d = info(i)
			if d and d.header and not d.collapsed and opened[d.name] then pcall(collapse, i) end
		end
	end
	return rows
end

-------------------------------------------------------------------------------
-- 아이콘 칩
-------------------------------------------------------------------------------
local function NewChip(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(SIZE, SIZE + 12)
	b.disc = b:CreateTexture(nil, "BACKGROUND")
	b.disc:SetTexture(Ink.tex.disc)
	b.disc:SetSize(SIZE, SIZE)
	b.disc:SetPoint("TOP")
	b.disc:SetVertexColor(0.035, 0.04, 0.052, 0.85)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(SIZE - 6, SIZE - 6)
	b.icon:SetPoint("CENTER", b.disc, "CENTER")
	if b.CreateMaskTexture and b.icon.AddMaskTexture then
		b.mask = b:CreateMaskTexture()
		b.mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		b.mask:SetAllPoints(b.icon)
		b.icon:AddMaskTexture(b.mask)
	end
	b.letter = Ink:Text(b, F.bold, 11, C.text, "CENTER")
	b.letter:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
	b.ring = b:CreateTexture(nil, "BORDER")
	b.ring:SetTexture(Ink.tex.ring)
	b.ring:SetAllPoints(b.disc)
	-- 진행 막대 (아이콘 아래)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetTexture(Ink.tex.white)
	b.bar:SetSize(SIZE - 6, 2)
	b.bar:SetPoint("TOP", b.disc, "BOTTOM", 0, -3)
	b.bar:SetVertexColor(1, 1, 1, 0.12)
	b.fill = b:CreateTexture(nil, "OVERLAY")
	b.fill:SetTexture(Ink.tex.white)
	b.fill:SetHeight(2)
	b.fill:SetPoint("LEFT", b.bar, "LEFT")
	b.num = Ink:Text(b, F.numR, 9, C.soft, "CENTER")
	b.num:SetPoint("TOP", b.bar, "BOTTOM", 0, -2)
	-- 오를 때: 톡 튀기 + "+1" 떠오르기
	b.pop = b:CreateAnimationGroup()
	local s1 = b.pop:CreateAnimation("Scale")
	s1:SetScaleFrom(1, 1); s1:SetScaleTo(1.22, 1.22); s1:SetDuration(0.12); s1:SetOrder(1); s1:SetSmoothing("OUT")
	local s2 = b.pop:CreateAnimation("Scale")
	s2:SetScaleFrom(1.22, 1.22); s2:SetScaleTo(1, 1); s2:SetDuration(0.22); s2:SetOrder(2); s2:SetSmoothing("IN")
	b.plus = Ink:Text(b, F.latinB, 11, { 0.55, 0.9, 0.55 }, "CENTER", "OVERLAY")
	b.plus:SetPoint("BOTTOM", b.disc, "TOP", 0, 0)
	b.plus:SetAlpha(0)
	b.float = b.plus:CreateAnimationGroup()
	local fa = b.float:CreateAnimation("Alpha"); fa:SetFromAlpha(1); fa:SetToAlpha(0); fa:SetDuration(1.1); fa:SetSmoothing("IN")
	local ft = b.float:CreateAnimation("Translation"); ft:SetOffset(0, 14); ft:SetDuration(1.1); ft:SetSmoothing("OUT")
	b:SetScript("OnEnter", function(self) M:Tip(self) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

function M:Paint(b, e)
	b.entry = e
	local p = math.max(0, math.min(1, (e.rank or 0) / math.max(1, e.max or 1)))
	local maxed = (e.rank or 0) >= (e.max or 1)
	local col
	if e.kind == "rep" then
		col = STANDING_RGB[e.standing or 4] or GOLD
		b.icon:Hide()
		b.letter:SetText((e.name or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?")
		b.letter:SetTextColor(col[1], col[2], col[3])
		b.letter:Show()
		b.num:SetText(_G["FACTION_STANDING_LABEL" .. (e.standing or 4)] or "")
	else
		col = maxed and GOLD or (e.kind == "weapon" and { 0.62, 0.78, 1 } or { 0.55, 0.85, 0.55 })
		b.letter:Hide()
		b.icon:SetTexture(e.icon or 134400)
		b.icon:Show()
		b.num:SetText(tostring(e.rank or 0))
	end
	b.ring:SetVertexColor(col[1], col[2], col[3], maxed and 0.95 or 0.6)
	b.fill:SetWidth(math.max(0.01, (SIZE - 6) * p))
	b.fill:SetVertexColor(col[1], col[2], col[3], 0.95)
	b.fill:SetShown(p > 0)
	b.num:SetTextColor(maxed and GOLD[1] or 0.8, maxed and GOLD[2] or 0.8, maxed and GOLD[3] or 0.8)
end

function M:Tip(b)
	local e = b.entry
	if not e then return end
	GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
	GameTooltip:AddLine(e.name, 1, 1, 1)
	if e.kind == "rep" then
		local col = STANDING_RGB[e.standing or 4] or GOLD
		GameTooltip:AddDoubleLine(_G["FACTION_STANDING_LABEL" .. (e.standing or 4)] or "", e.rank .. " / " .. e.max, col[1], col[2], col[3], 1, 1, 1)
	else
		GameTooltip:AddDoubleLine(e.kind == "weapon" and "무기 숙련" or "숙련", e.rank .. " / " .. e.max, 0.7, 0.72, 0.75, 1, 1, 1)
		if (e.mod or 0) ~= 0 then GameTooltip:AddDoubleLine("장비 · 효과", (e.mod > 0 and "+" or "") .. e.mod, 0.7, 0.72, 0.75, 0.55, 0.9, 0.55) end
		if e.kind == "prof" and e.rank >= e.max then
			GameTooltip:AddLine("최대예요 · 상급자에게 다음 단계를 배우면 더 올라요", GOLD[1], GOLD[2], GOLD[3], true)
		elseif e.kind == "weapon" then
			GameTooltip:AddLine("이 무기로 싸우면 올라요 (레벨 × 5 까지)", 0.56, 0.58, 0.61, true)
		end
	end
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- 다시 그리기
-------------------------------------------------------------------------------
function M:Collect()
	local list = {}
	local skills = Skills()
	for _, s in ipairs(skills) do
		s.pick = s.key
		if s.kind == "prof" and Pick(s.key) ~= false then list[#list + 1] = s end
	end
	local autoW, n = Ink.db.trackerWeapons ~= false, 0
	for _, s in ipairs(skills) do
		if s.kind == "weapon" then
			local p = Pick(s.key)
			if p == true then
				list[#list + 1] = s
			elseif p == nil and autoW and s.rank > 1 and s.rank < s.max and n < 4 then   -- 1 = 한 번도 안 쓴 무기
				list[#list + 1] = s
				n = n + 1
			end
		end
	end
	for _, r in ipairs(Reps()) do list[#list + 1] = r end
	return list
end

-- 지금 현황 아이콘에 떠 있는 것 (설정 칩 색칠용 · 바뀌면 다시 셈)
function M:Shown()
	if not self.shown then
		local set = {}
		local ok, list = pcall(self.Collect, self)
		if ok then for _, e in ipairs(list) do set[e.pick or e.key] = true end end
		self.shown = set
	end
	return self.shown
end

local STANDING_SHORT = function(st) return _G["FACTION_STANDING_LABEL" .. (st or 4)] or "" end

-- 설정 칩 목록: sec = "prof" / "weapon" / "rep"
function M:PickItems(sec)
	local out = {}
	if sec == "rep" then
		for _, d in ipairs(FactionRows()) do
			if d.header and not d.hasRep then
				out[#out + 1] = { header = true, name = d.name }
			else
				local rank = (d.val or 0) - (d.min or 0)
				local span = math.max(1, (d.max or 1) - (d.min or 0))
				out[#out + 1] = { key = RepKey(d), kind = "rep", name = d.name, letter = (d.name or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?",
					rgb = STANDING_RGB[d.standing or 4] or GOLD, sub = STANDING_SHORT(d.standing), rank = rank, max = span, standing = d.standing }
			end
		end
		-- 빈 묶음 제목은 뺀다
		local clean = {}
		for i, it in ipairs(out) do
			local nextIt = out[i + 1]
			if not (it.header and (not nextIt or nextIt.header)) then clean[#clean + 1] = it end
		end
		return clean
	end
	for _, s in ipairs(Skills()) do
		if s.kind == sec then
			out[#out + 1] = { key = s.key, kind = s.kind, name = s.name, icon = s.icon or 134400, sub = s.rank .. "/" .. s.max,
				rank = s.rank, max = s.max, mod = s.mod, maxed = s.rank >= s.max }
		end
	end
	return out
end

-- 칩 하나의 상태: 떠 있나, 직접 고른 값 (true 고정 / false 뺌 / nil 자동)
function M:PickState(key)
	return self:Shown()[key] and true or false, Pick(key)
end

function M:TogglePick(key, kind)
	local t = Picks(true)
	if self:Shown()[key] then
		t[key] = false
	elseif kind == "prof" then
		t[key] = nil
	else
		local top = 0
		for _, v in pairs(t) do if type(v) == "number" and v > top then top = v end end
		t[key] = top + 1
	end
	self.shown = nil
	pcall(self.Update, self)
end

-- 기술 키 → 종류 (배운 기술 목록 · 없으면 이름표)
local function SkillKind(key, cache)
	if cache[key] == nil then
		BuildIcons()
		cache[key] = KIND[key:sub(3)] or false
		for _, s in ipairs(cache.list or {}) do if s.key == key then cache[key] = s.kind end end
	end
	return cache[key]
end

local function InSec(key, sec, cache)
	if sec == "rep" then return key:find("^f:") or key:find("^r:") end
	return key:find("^s:") and SkillKind(key, cache) == sec
end

function M:PickChanged(sec)
	local cache = { list = Skills() }
	for k, v in pairs(Picks()) do
		if v ~= nil and InSec(k, sec, cache) then return true end
	end
	return false
end

function M:ClearPicks(sec)
	local t = Picks()
	local cache = { list = Skills() }
	local drop = {}
	for k in pairs(t) do if InSec(k, sec, cache) then drop[#drop + 1] = k end end
	for _, k in ipairs(drop) do t[k] = nil end
	self.shown = nil
	pcall(self.Update, self)
end

local PER_ROW = 12   -- 한 줄에 이만큼 넘으면 아래 줄로

function M:Update()
	local list = self.Collect and self:Collect() or {}
	local set = {}
	for _, e in ipairs(list) do set[e.pick or e.key] = true end
	self.shown = set
	local f = self.frame
	if not f then return end
	self.last = self.last or {}
	for i, e in ipairs(list) do
		local b = f.chips[i] or NewChip(f)
		f.chips[i] = b
		b:ClearAllPoints()
		local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
		b:SetPoint("TOPLEFT", col * (SIZE + GAP), -row * (SIZE + 24))
		self:Paint(b, e)
		b:Show()
		local prev = self.last[e.key]
		if prev and e.rank > prev and e.kind ~= "rep" then
			b.plus:SetText("+" .. (e.rank - prev))
			b.pop:Stop(); b.pop:Play()
			b.float:Stop(); b.float:Play()
		end
		self.last[e.key] = e.rank
	end
	for i = #list + 1, #f.chips do f.chips[i]:Hide() end
	local cols = math.min(#list, PER_ROW)
	local rows = math.max(1, math.ceil(#list / PER_ROW))
	f:SetWidth(math.max(SIZE, cols * (SIZE + GAP) - GAP))
	f:SetHeight(SIZE + 14 + (rows - 1) * (SIZE + 24))
end

function M:Init()
	if Ink.db.tracker == false then return end
	local f = CreateFrame("Frame", "FOATracker", Ink.root)
	f:SetSize(SIZE, SIZE + 14)
	f:SetFrameStrata("LOW")
	f.chips = {}
	self.frame = f
	Ink:Movable("tracker", "현황 아이콘", f, "left", 60, 16, 300, SIZE + 14)
	self.recentRep = {}

	-- 오리지널식 기술 목록: 접힌 묶음이 있으면 목록에 안 나와서 한 번 펼쳐 둔다 (포에버는 번호로 찾아서 필요 없음)
	if not C_SkillInfo and ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end

	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "UPDATE_FACTION",
		"CHAT_MSG_COMBAT_FACTION_CHANGE", "LEARNED_SPELL_IN_TAB", "TRADE_SKILL_UPDATE" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local queued
	e:SetScript("OnEvent", function(_, ev, msg)
		if ev == "CHAT_MSG_COMBAT_FACTION_CHANGE" and type(msg) == "string" then
			-- "스톰윈드에 대한 평판이 25만큼 올랐습니다." 같은 글에서 진영 이름을 찾는다
			local n = (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetNumFactions()) or (GetNumFactions and GetNumFactions()) or 0
			for i = 1, n do
				local fname, fid
				if C_Reputation and C_Reputation.GetFactionDataByIndex then
					local d = C_Reputation.GetFactionDataByIndex(i)
					fname, fid = d and d.name, d and d.factionID
				elseif GetFactionInfo then
					local r = { GetFactionInfo(i) }
					fname, fid = r[1], r[14]
				end
				if fname and fid and msg:find(fname, 1, true) then
					for k, v in ipairs(M.recentRep) do if v == fid then table.remove(M.recentRep, k) break end end
					table.insert(M.recentRep, 1, fid)
					while #M.recentRep > 3 do table.remove(M.recentRep) end
					break
				end
			end
		end
		if queued then return end
		queued = true
		C_Timer.After(0.4, function()
			queued = nil
			local ok, err = pcall(M.Update, M)
			if not ok then Ink:LogError("Tracker: " .. tostring(err)) end
		end)
	end)
	C_Timer.After(2, function() pcall(M.Update, M) end)
end

M.FactionIDByName = FactionIDByName
