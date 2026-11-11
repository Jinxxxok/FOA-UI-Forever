-- FOA UI · 현황 아이콘 (전문기술 · 무기 숙련 · 평판을 창을 열지 않고 둥근 아이콘으로)
--  · 전문기술 / 보조 기술 (요리 · 응급치료 · 낚시 · 독) / 자물쇠 따기: 아이콘 + 숙련 + 아래 진행 막대
--  · 모양: FOA 아이콘 칸 (둥근 모서리 · 얇은 테두리) · 전문 민트 / 무기 파랑 / 평판 단계 색 · 다 올리면 금색
--  · 묶음 사이엔 넓은 틈과 가는 세로 선
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

local ICON, GAP, GROUP_GAP, ROW_GAP = 28, 7, 19, 10   -- 아이콘 · 칸 사이 · 묶음 사이 · 줄 사이
local CHIP_H = ICON + 19                                 -- 아이콘 + 막대 + 숫자
local PER_ROW = 12                                       -- 한 줄 폭 (아이콘 수 기준)
local GOLD = { 0.890, 0.753, 0.478 }                     -- 다 올림 (FOA gold)
local KIND_RGB = {
	prof = { 0.435, 0.827, 0.604 },     -- 전문기술 · 보조 기술: 민트
	weapon = { 0.498, 0.659, 1.000 },   -- 무기 숙련 · 방어: 강철 파랑
}

-- 이름 → 아이콘 (그 기술을 배우는 주문의 아이콘. 이름은 게임 언어 그대로라 한국어 · 영어 다 맞는다)
local PROF_SPELLS = { 2259, 2018, 7411, 4036, 2366, 2108, 2575, 8613, 3908, 2550, 3273, 7620, 1804, 2842 }
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
	[197] = 3908, [185] = 2550, [129] = 3273, [356] = 7620, [633] = 1804, [40] = 2842,
	[173] = 1180, [43] = 201, [55] = 202, [44] = 196, [172] = 197, [54] = 198, [160] = 199, [229] = 200, [136] = 227,
	[162] = 203, [473] = 15590, [45] = 264, [46] = 266, [226] = 5011, [176] = 2567, [228] = 5009, [95] = 204,
}
local PROF_ORDER = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 185, 129, 356, 633, 40 }
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
	[1] = { 1.000, 0.420, 0.369 }, [2] = { 1.000, 0.420, 0.369 }, [3] = { 1.000, 0.718, 0.353 }, [4] = { 0.910, 0.824, 0.478 },
	[5] = { 0.435, 0.827, 0.604 }, [6] = { 0.310, 0.765, 0.631 }, [7] = { 0.361, 0.784, 0.839 }, [8] = { 0.498, 0.659, 1.000 },
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
-- 아이콘 칩 (FOA 아이콘 칸: 둥근 모서리 + 얇은 테두리 · 아래 가는 진행 막대 + 숫자)
--  전문기술 = 민트 · 무기 = 파랑 · 평판 = 평판 단계 색 · 다 올리면 금색 테두리와 은은한 빛
-------------------------------------------------------------------------------
local function FirstChar(name)
	return (name or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
end

local function NewChip(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(ICON, CHIP_H)
	-- 아이콘 칸
	b.ic = CreateFrame("Frame", nil, b)
	b.ic:SetSize(ICON, ICON)
	b.ic:SetPoint("TOP")
	b.icon = b.ic:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.skin = Ink:IconSkin(b.ic, b.icon, true)
	b.skin.bg:SetVertexColor(0.035, 0.040, 0.052, 0.86)
	-- 글자 칸 (평판 · 아이콘 없는 기술): 단계 색을 옅게 깐 바탕 + 굵은 첫 글자
	b.wash = Ink:Round(b.ic, "BORDER", true)
	b.wash:SetPoint("TOPLEFT", 1, -1)
	b.wash:SetPoint("BOTTOMRIGHT", -1, 1)
	b.letter = Ink:Text(b.skin.top, F.bold, 13, C.text, "CENTER")
	b.letter:SetPoint("CENTER", b.ic, "CENTER", 0, 0)
	-- 위쪽 은은한 윤기 (아이콘이 납작해 보이지 않게)
	b.sheen = b.skin.top:CreateTexture(nil, "ARTWORK")
	b.sheen:SetPoint("TOPLEFT", b.ic, "TOPLEFT", 4, -2)
	b.sheen:SetPoint("TOPRIGHT", b.ic, "TOPRIGHT", -4, -2)
	b.sheen:SetHeight(ICON * 0.42)
	b.sheen:SetTexture(Ink.tex.white)
	if b.sheen.SetGradient and CreateColor then
		pcall(b.sheen.SetGradient, b.sheen, "VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.07))
	else
		b.sheen:SetVertexColor(1, 1, 1, 0.035)
	end
	-- 빛 (다 올림 · 오를 때 번쩍)
	b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -7)
	b.glow:SetTexture(Ink.tex.glow)
	b.glow:SetPoint("TOPLEFT", b.ic, "TOPLEFT", -11, 11)
	b.glow:SetPoint("BOTTOMRIGHT", b.ic, "BOTTOMRIGHT", 11, -11)
	b.glow:SetBlendMode("ADD")
	b.glow:SetAlpha(0)
	-- 진행 막대 (아이콘 폭 · 2점 · 둥근 끝 대신 1점 안쪽으로 들여 깔끔하게)
	b.track = b:CreateTexture(nil, "ARTWORK")
	b.track:SetTexture(Ink.tex.white)
	b.track:SetHeight(2)
	b.track:SetPoint("TOPLEFT", b.ic, "BOTTOMLEFT", 2, -4)
	b.track:SetPoint("TOPRIGHT", b.ic, "BOTTOMRIGHT", -2, -4)
	b.track:SetVertexColor(1, 1, 1, 0.09)
	b.fill = b:CreateTexture(nil, "OVERLAY")
	b.fill:SetTexture(Ink.tex.white)
	b.fill:SetHeight(2)
	b.fill:SetPoint("LEFT", b.track, "LEFT")
	b.tip = b:CreateTexture(nil, "OVERLAY", nil, 1)   -- 막대 끝 밝은 점
	b.tip:SetTexture(Ink.tex.white)
	b.tip:SetSize(2, 2)
	b.tip:SetPoint("RIGHT", b.fill, "RIGHT")
	b.num = Ink:Text(b, F.numR, 10, C.soft, "CENTER")
	b.num:SetPoint("TOP", b.track, "BOTTOM", 0, -3)
	-- 오를 때: 톡 튀기 + 빛 번쩍 + "+1" 떠오르기
	b.pop = b.ic:CreateAnimationGroup()
	local s1 = b.pop:CreateAnimation("Scale")
	s1:SetScaleFrom(1, 1); s1:SetScaleTo(1.16, 1.16); s1:SetDuration(0.12); s1:SetOrder(1); s1:SetSmoothing("OUT")
	local s2 = b.pop:CreateAnimation("Scale")
	s2:SetScaleFrom(1.16, 1.16); s2:SetScaleTo(1, 1); s2:SetDuration(0.26); s2:SetOrder(2); s2:SetSmoothing("IN")
	b.flash = b.glow:CreateAnimationGroup()
	local g1 = b.flash:CreateAnimation("Alpha"); g1:SetFromAlpha(0); g1:SetToAlpha(0.7); g1:SetDuration(0.14); g1:SetOrder(1)
	local g2 = b.flash:CreateAnimation("Alpha"); g2:SetFromAlpha(0.7); g2:SetToAlpha(0); g2:SetDuration(0.9); g2:SetOrder(2); g2:SetSmoothing("OUT")
	b.flash:SetScript("OnFinished", function() b.glow:SetAlpha(b.restGlow or 0) end)
	b.plus = Ink:Text(b, F.latinB, 11, KIND_RGB.prof, "CENTER", "OVERLAY")
	b.plus:SetPoint("BOTTOM", b.ic, "TOP", 0, 1)
	b.plus:SetAlpha(0)
	b.float = b.plus:CreateAnimationGroup()
	local fa = b.float:CreateAnimation("Alpha"); fa:SetFromAlpha(1); fa:SetToAlpha(0); fa:SetDuration(1.2); fa:SetSmoothing("IN")
	local ft = b.float:CreateAnimation("Translation"); ft:SetOffset(0, 14); ft:SetDuration(1.2); ft:SetSmoothing("OUT")
	b:SetScript("OnEnter", function(self)
		self.hot = true
		if self.entry then M:Paint(self, self.entry) end
		M:Tip(self)
	end)
	b:SetScript("OnLeave", function(self)
		self.hot = nil
		if self.entry then M:Paint(self, self.entry) end
		GameTooltip:Hide()
	end)
	return b
end

function M:Paint(b, e)
	b.entry = e
	local p = math.max(0, math.min(1, (e.rank or 0) / math.max(1, e.max or 1)))
	local maxed = (e.rank or 0) >= (e.max or 1)
	local col = e.kind == "rep" and (STANDING_RGB[e.standing or 4] or GOLD) or (KIND_RGB[e.kind] or KIND_RGB.prof)
	local useLetter = e.kind == "rep" or not e.icon
	if useLetter then
		b.icon:Hide()
		b.wash:SetVertexColor(col[1], col[2], col[3], 0.16)
		b.wash:Show()
		b.letter:SetText(FirstChar(e.name))
		b.letter:SetTextColor(col[1], col[2], col[3])
		b.letter:Show()
	else
		b.wash:Hide()
		b.letter:Hide()
		b.icon:SetTexture(e.icon)
		b.icon:Show()
	end
	-- 테두리: 평소 옅게 · 평판은 단계 색 · 다 올리면 금색 · 마우스 올리면 밝게
	local bd = b.skin.border
	if maxed and e.kind ~= "rep" then
		bd:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], b.hot and 1 or 0.78)
	elseif e.kind == "rep" then
		bd:SetVertexColor(col[1], col[2], col[3], b.hot and 0.9 or 0.45)
	else
		bd:SetVertexColor(1, 1, 1, b.hot and 0.42 or 0.13)
	end
	-- 막대 · 숫자
	local fc = (maxed and e.kind ~= "rep") and GOLD or col
	b.fill:SetVertexColor(fc[1], fc[2], fc[3], 0.95)
	b.fill:SetWidth(math.max(0.01, (ICON - 4) * p))
	b.fill:SetShown(p > 0)
	b.tip:SetVertexColor(math.min(1, fc[1] + 0.35), math.min(1, fc[2] + 0.35), math.min(1, fc[3] + 0.35), 1)
	b.tip:SetShown(p > 0.04 and p < 1)
	if e.kind == "rep" then
		b.num:SetText(math.floor(p * 100 + 0.5) .. "%")
		b.num:SetTextColor(col[1], col[2], col[3])
	else
		b.num:SetText(tostring(e.rank or 0))
		local nc = maxed and GOLD or (b.hot and C.text or C.soft)
		b.num:SetTextColor(nc[1], nc[2], nc[3])
	end
	-- 다 올린 것은 금빛이 은은하게 남는다
	b.restGlow = (maxed and e.kind ~= "rep") and 0.16 or 0
	b.glow:SetVertexColor(fc[1], fc[2], fc[3])
	if not (b.flash and b.flash:IsPlaying()) then b.glow:SetAlpha(b.restGlow) end
	b.plus:SetTextColor(col[1], col[2], col[3])
end

local KIND_LABEL = { prof = "숙련", weapon = "무기 숙련" }

function M:Tip(b)
	local e = b.entry
	if not e then return end
	GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
	GameTooltip:AddLine(e.name, 1, 1, 1)
	local g = { 0.56, 0.58, 0.61 }
	if e.kind == "rep" then
		local col = STANDING_RGB[e.standing or 4] or GOLD
		GameTooltip:AddDoubleLine(_G["FACTION_STANDING_LABEL" .. (e.standing or 4)] or "", e.rank .. " / " .. e.max, col[1], col[2], col[3], 1, 1, 1)
		if e.rank < e.max then GameTooltip:AddLine("다음 단계까지 " .. (e.max - e.rank), g[1], g[2], g[3]) end
	else
		local col = KIND_RGB[e.kind] or KIND_RGB.prof
		GameTooltip:AddDoubleLine(KIND_LABEL[e.kind] or "숙련", e.rank .. " / " .. e.max, col[1], col[2], col[3], 1, 1, 1)
		if (e.mod or 0) ~= 0 then GameTooltip:AddDoubleLine("장비 · 효과", (e.mod > 0 and "+" or "") .. e.mod, g[1], g[2], g[3], 0.55, 0.9, 0.55) end
		if e.rank >= e.max then
			GameTooltip:AddLine(e.kind == "weapon" and "지금 레벨에선 최대예요 · 레벨이 오르면 다시 올라요"
				or "최대예요 · 상급자에게 다음 단계를 배우면 더 올라요", GOLD[1], GOLD[2], GOLD[3], true)
		elseif e.kind == "weapon" then
			GameTooltip:AddLine("이 무기로 싸우면 올라요 (레벨 × 5 까지) · 남은 " .. (e.max - e.rank), g[1], g[2], g[3], true)
		else
			GameTooltip:AddLine("최대까지 " .. (e.max - e.rank), g[1], g[2], g[3])
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
				out[#out + 1] = { key = RepKey(d), kind = "rep", name = d.name, letter = FirstChar(d.name),
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
			out[#out + 1] = { key = s.key, kind = s.kind, name = s.name, icon = s.icon, letter = FirstChar(s.name), rgb = KIND_RGB[s.kind], sub = s.rank .. "/" .. s.max,
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

-- 묶음(전문기술 · 무기 · 평판) 사이엔 넓은 틈 + 가는 세로 선 · 폭이 넘치면 아래 줄로
function M:Update()
	local list = self.Collect and self:Collect() or {}
	local set = {}
	for _, e in ipairs(list) do set[e.pick or e.key] = true end
	self.shown = set
	local f = self.frame
	if not f then return end
	self.last = self.last or {}
	f.divs = f.divs or {}
	local maxW = PER_ROW * (ICON + GAP) - GAP
	local x, row, right, nd, prevKind = 0, 0, 0, 0, nil
	for i, e in ipairs(list) do
		local b = f.chips[i] or NewChip(f)
		f.chips[i] = b
		if prevKind and e.kind ~= prevKind then
			if x - GAP + GROUP_GAP + ICON > maxW then
				x, row = 0, row + 1
			else
				nd = nd + 1
				local d = f.divs[nd]
				if not d then
					d = f:CreateTexture(nil, "ARTWORK")
					d:SetTexture(Ink.tex.white)
					d:SetSize(1, ICON - 10)
					f.divs[nd] = d
				end
				d:SetVertexColor(1, 1, 1, 0.12)
				d:ClearAllPoints()
				d:SetPoint("TOP", f, "TOPLEFT", x - GAP + GROUP_GAP / 2, -(row * (CHIP_H + ROW_GAP) + 5))
				d:Show()
				x = x - GAP + GROUP_GAP
			end
		elseif x > 0 and x + ICON > maxW then
			x, row = 0, row + 1
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", x, -row * (CHIP_H + ROW_GAP))
		self:Paint(b, e)
		b:Show()
		right = math.max(right, x + ICON)
		x = x + ICON + GAP
		prevKind = e.kind
		local prev = self.last[e.key]
		if prev and e.rank > prev and e.kind ~= "rep" then
			b.plus:SetText("+" .. (e.rank - prev))
			b.pop:Stop(); b.pop:Play()
			b.flash:Stop(); b.flash:Play()
			b.float:Stop(); b.float:Play()
		end
		self.last[e.key] = e.rank
	end
	for i = #list + 1, #f.chips do f.chips[i]:Hide() end
	for i = nd + 1, #f.divs do f.divs[i]:Hide() end
	f:SetWidth(math.max(ICON, right))
	f:SetHeight((row + 1) * CHIP_H + row * ROW_GAP)
end

function M:Init()
	if Ink.db.tracker == false then return end
	local f = CreateFrame("Frame", "FOATracker", Ink.root)
	f:SetSize(ICON, CHIP_H)
	f:SetFrameStrata("LOW")
	f.chips = {}
	self.frame = f
	Ink:Movable("tracker", "현황 아이콘", f, "left", 60, 16, 300, CHIP_H)
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
