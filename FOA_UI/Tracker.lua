-- FOA UI · 현황 아이콘 (전문기술 · 무기 숙련 · 평판을 창을 열지 않고 둥근 아이콘으로)
--  · 전문기술 / 보조 기술 (요리 · 응급치료 · 낚시) / 자물쇠 따기: 아이콘 + 숙련 + 아래 진행 막대
--  · 무기 숙련 · 방어: 아직 다 안 올린 것만
--  · 평판: 추적 중인 평판 + 이번 접속에서 오른 평판
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

-- 기술 목록 읽기 (캐릭터 창 "기술" 탭과 같은 자료)
local function Skills()
	local out = {}
	if not (GetNumSkillLines and GetSkillLineInfo) then return out end
	BuildIcons()
	local sec = "other"
	for i = 1, GetNumSkillLines() do
		local name, header, _, rank, _, mod, max = GetSkillLineInfo(i)
		if header then
			sec = Section(name)
		elseif name and (max or 0) > 1 then
			local kind = (sec ~= "other" and sec) or KIND[name]
			if kind then
				out[#out + 1] = { key = "s:" .. name, name = name, rank = rank or 0, max = max, mod = mod or 0, kind = kind, icon = ICONS[name] }
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

local function Reps()
	local out, seen = {}, {}
	local w = Watched()
	if w then out[#out + 1] = w; seen[w.name] = true end
	for _, id in ipairs(M.recentRep or {}) do
		local f = FactionByID(id)
		if f and not seen[f.name] and #out < 3 then out[#out + 1] = f; seen[f.name] = true end
	end
	for _, f in ipairs(out) do
		f.key = "r:" .. f.name
		f.kind = "rep"
		f.rank = (f.val or 0) - (f.min or 0)
		f.max = math.max(1, (f.max or 1) - (f.min or 0))
	end
	return out
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
		if s.kind == "prof" then list[#list + 1] = s end
	end
	if Ink.db.trackerWeapons ~= false then
		local n = 0
		for _, s in ipairs(skills) do
			if s.kind == "weapon" and s.rank < s.max and n < 4 then list[#list + 1] = s; n = n + 1 end
		end
	end
	if Ink.db.trackerReps ~= false then
		for _, r in ipairs(Reps()) do list[#list + 1] = r end
	end
	return list
end

function M:Update()
	local f = self.frame
	if not f then return end
	local list = self.Collect and self:Collect() or {}
	self.last = self.last or {}
	for i, e in ipairs(list) do
		local b = f.chips[i] or NewChip(f)
		f.chips[i] = b
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", (i - 1) * (SIZE + GAP), 0)
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
	f:SetWidth(math.max(SIZE, #list * (SIZE + GAP) - GAP))
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

	-- 접힌 기술 묶음이 있으면 목록에 안 나와서 한 번 펼쳐 둔다
	if ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end

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
