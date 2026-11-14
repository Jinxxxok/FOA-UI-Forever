-- FOA UI · 자물쇠 따기 연습 사물함 (도적 · 포에버)
--  · 미니맵 · 세계 지도에 사물함이 생길 수 있는 자리 (자물쇠 표시 · 누르면 지도에 찍고 화면에 길 안내)
--  · 가까이 가서 상호작용 대상으로 잡히면 이름표에 자물쇠 배지 + 반짝임 (Plates.lua 가 BoxOf · Look 을 씀)
--  · 색 = 내 숙련도로 열면 오르는지 (주황 거의 매번 · 노랑 자주 · 초록 가끔 · 회색 안 오름 · 빨강 아직 못 엶)
--  자료: Lockboxes.lua (QuestieDB 자리 · 필요 숙련도는 대략 값)
--  사물함 자체에 3D 외곽선을 그리는 건 애드온이 할 수 없어서(게임이 막아 둠) 이름표 · 지도 표시로 대신한다

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Lockpick")
local plain = Ink.plain

local FOREVER = (function() local b = select(4, GetBuildInfo()) or 0 return b >= 16001 and b < 20000 end)()
local LOCK_SKILL = 633
local PICK_LOCK = 1804
local COL = {
	red = { 1.00, 0.42, 0.37 }, orange = { 1.00, 0.62, 0.30 }, yellow = { 1.00, 0.86, 0.36 },
	green = { 0.44, 0.83, 0.55 }, gray = { 0.56, 0.58, 0.61 },
}
local MINI_OUT = { 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 }   -- 미니맵 확대 단계별 지름(야드) · 바깥
local MINI_IN = { 300, 240, 180, 120, 80, 50 }

-------------------------------------------------------------------------------
-- 판정
-------------------------------------------------------------------------------
function M.MySkill()
	if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
		local ok, d = pcall(C_SkillInfo.GetSkillLineInfoByID, LOCK_SKILL)
		if ok and type(d) == "table" and (d.rank or 0) > 0 then return d.rank, d.maxRank end
	end
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local n, header, _, rank, _, _, max = GetSkillLineInfo(i)
			if not header and (n == "자물쇠 따기" or n == "Lockpicking") then return rank, max end
		end
	end
end

function M.Active()
	if not FOREVER or Ink.db.lockboxes == false or not ns.LOCKBOXES then return false end
	local _, cls = UnitClass("player")
	if cls ~= "ROGUE" then return false end
	if (M.MySkill() or 0) > 0 then return true end
	return IsPlayerSpell and IsPlayerSpell(PICK_LOCK) or false
end

local names
local function Names()
	if names then return names end
	names = {}
	for id, e in pairs(ns.LOCKBOXES or {}) do names[e[1]] = id; names[e[3]] = id end
	return names
end

-- 이름표 단위(물체)가 연습 사물함인지: 물체 번호(GUID) → 이름
function M.BoxOf(unit)
	if not ns.LOCKBOXES or not unit then return end
	local ok, g = pcall(UnitGUID, unit)
	g = ok and plain(g)
	if type(g) == "string" then
		local kind, _, _, _, _, id = strsplit("-", g)
		id = tonumber(id)
		if kind == "GameObject" and id and ns.LOCKBOXES[id] then return id, ns.LOCKBOXES[id] end
	end
	local okN, n = pcall(UnitName, unit)
	n = okN and plain(n)
	local id = type(n) == "string" and Names()[n]
	if id then return id, ns.LOCKBOXES[id] end
end

-- 내 숙련도로 열면 오르는지 (필요 숙련도 기준 +25 노랑 · +50 초록 · +100 회색 · 값이 대략이라 글자에 "대략")
function M.Look(req)
	local r = M.MySkill() or 0
	if r < req then return COL.red, "숙련도 " .. req .. " 필요" end
	if r < req + 25 then return COL.orange, "열면 숙련도 오름" end
	if r < req + 50 then return COL.yellow, "자주 오름" end
	if r < req + 100 then return COL.green, "가끔 오름" end
	return COL.gray, "안 오름"
end

-------------------------------------------------------------------------------
-- 지도 위치 · 길 안내
-------------------------------------------------------------------------------
local function Spots(mapID)
	local out = {}
	for id, e in pairs(ns.LOCKBOXES or {}) do
		local l = e[4][mapID]
		if l then
			for i = 1, #l, 2 do out[#out + 1] = { id = id, box = e, x = l[i] / 100, y = l[i + 1] / 100 } end
		end
	end
	return out
end
local spotCache = {}
local function MapSpots(mapID)
	if not mapID then return {} end
	local s = spotCache[mapID]
	if not s then s = Spots(mapID); spotCache[mapID] = s end
	return s
end

local function Waypoint(self)
	if not (self.mapID and self.wx) then return end
	if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(self.mapID) and UiMapPoint then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(self.mapID, self.wx, self.wy))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
		print("|cffFFF468FOA|r 지도에 " .. (self.box and self.box[1] or "사물함") .. " 자리를 찍었어요")
	end
end

local function Tip(self)
	local e = self.box
	if not e then return end
	local col, txt = M.Look(e[2])
	local r = M.MySkill()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	Ink.TipLine(GameTooltip, e[1], col[1], col[2], col[3])
	GameTooltip:AddLine("자물쇠 따기 숙련도 대략 " .. e[2] .. "부터" .. (r and (" · 내 숙련도 " .. r) or ""), 0.75, 0.77, 0.8)
	GameTooltip:AddLine(txt, col[1], col[2], col[3])
	GameTooltip:AddLine("사물함이 생길 수 있는 자리예요 · 한 번에 몇 개만 생기고 열면 다른 자리에 다시 생겨요", 0.6, 0.62, 0.66, true)
	GameTooltip:AddLine("누르면 지도에 찍고 화면에 길 안내", 0.6, 0.62, 0.66)
	GameTooltip:Show()
end

local function NewPin(parent, size)
	local p = CreateFrame("Button", nil, parent)
	p:SetSize(size, size)
	p:RegisterForClicks("LeftButtonUp")
	p.disc = p:CreateTexture(nil, "BACKGROUND")
	p.disc:SetTexture(Ink.tex.disc)
	p.disc:SetAllPoints()
	p.disc:SetVertexColor(0.035, 0.04, 0.055, 0.92)
	p.ring = p:CreateTexture(nil, "BORDER")
	p.ring:SetTexture(Ink.tex.ring)
	p.ring:SetAllPoints()
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetTexture(Ink.icon("Lock"))
	p.icon:SetPoint("CENTER")
	p.icon:SetSize(size * 0.6, size * 0.6)
	p:SetScript("OnEnter", Tip)
	p:SetScript("OnLeave", GameTooltip_Hide)
	p:SetScript("OnClick", Waypoint)
	return p
end

local function Paint(p, box)
	local col = M.Look(box[2])
	p.box = box
	p.icon:SetVertexColor(col[1], col[2], col[3])
	p.ring:SetVertexColor(col[1], col[2], col[3], 1)
end

-------------------------------------------------------------------------------
-- 미니맵: 범위 안 자리는 모두, 범위 안에 하나도 없으면 가장 가까운 하나를 테두리에 (방향)
-------------------------------------------------------------------------------
function M:MiniUpdate()
	local mm = Minimap
	self.mpins = self.mpins or {}
	local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local pts = M.Active() and MapSpots(mapID) or {}
	local pos = (#pts > 0 and mm and mm:IsVisible()) and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
	local px, py
	if pos then px, py = pos:GetXY() end
	px, py = plain(px), plain(py)
	local ww, wh
	if px and C_Map.GetMapWorldSize then ww, wh = C_Map.GetMapWorldSize(mapID) end
	if not (px and py and ww and ww > 0) then
		for _, p in ipairs(self.mpins) do p:Hide() end
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
	local n, best, bestD = 0, nil, nil
	for _, q in ipairs(pts) do
		local dx, dy = (q.x - px) * ww, (q.y - py) * wh
		if rot then dx, dy = dx * cs - dy * sn, dx * sn + dy * cs end
		local d = math.sqrt(dx * dx + dy * dy)
		if d <= rad * 0.94 then
			n = n + 1
			local p = self.mpins[n] or NewPin(mm, 13)
			self.mpins[n] = p
			p:SetFrameLevel(mm:GetFrameLevel() + 11)
			p:ClearAllPoints()
			p:SetPoint("CENTER", mm, "CENTER", dx * k, -dy * k)
			p.mapID, p.wx, p.wy = mapID, q.x, q.y
			Paint(p, q.box)
			p:SetAlpha(1)
			p:Show()
		elseif not bestD or d < bestD then
			best, bestD = { q = q, dx = dx, dy = dy }, d
		end
	end
	if n == 0 and best then
		n = 1
		local p = self.mpins[1] or NewPin(mm, 13)
		self.mpins[1] = p
		local x, y = best.dx * k, -best.dy * k
		local lim = half - 8
		if round then
			local d = math.sqrt(x * x + y * y)
			x, y = x / d * lim, y / d * lim
		else
			local m = math.max(math.abs(x), math.abs(y))
			x, y = x / m * lim, y / m * lim
		end
		p:SetFrameLevel(mm:GetFrameLevel() + 11)
		p:ClearAllPoints()
		p:SetPoint("CENTER", mm, "CENTER", x, y)
		p.mapID, p.wx, p.wy = mapID, best.q.x, best.q.y
		Paint(p, best.q.box)
		p:SetAlpha(0.7)
		p:Show()
	end
	for i = n + 1, #self.mpins do self.mpins[i]:Hide() end
end

-------------------------------------------------------------------------------
-- 세계 지도: 지역 지도에서만 작은 자물쇠 (Map 모듈이 다시 그릴 때 같이)
-------------------------------------------------------------------------------
function M:DrawWorld()
	local Map = Ink.modules.Map
	local wm = WorldMapFrame
	local cv = wm and wm.ScrollContainer and wm.ScrollContainer.Child
	self.wpins = self.wpins or {}
	local mapID = wm and wm:IsShown() and wm:GetMapID()
	local mi = mapID and C_Map.GetMapInfo(mapID)
	local pts = (Map and Map.layer and cv and mi and mi.mapType == 3 and M.Active()) and MapSpots(mapID) or {}
	local n = 0
	if #pts > 0 then
		local W, H = cv:GetWidth(), cv:GetHeight()
		local scale = (wm.GetCanvasScale and wm:GetCanvasScale()) or 1
		local sc = math.max(0.45, math.min(1.4, 1 / scale)) * 0.8
		for _, q in ipairs(pts) do
			n = n + 1
			local p = self.wpins[n] or NewPin(Map.layer, 18)
			self.wpins[n] = p
			p:SetScale(sc)
			p:ClearAllPoints()
			p:SetPoint("CENTER", cv, "TOPLEFT", q.x * W / sc, -q.y * H / sc)
			p:SetFrameLevel(Map.layer:GetFrameLevel() + 15)
			p.mapID, p.wx, p.wy = mapID, q.x, q.y
			Paint(p, q.box)
			p:Show()
		end
	end
	for i = n + 1, #self.wpins do self.wpins[i]:Hide() end
end

function M:Init()
	if not FOREVER or not ns.LOCKBOXES then return end
	local _, cls = UnitClass("player")
	if cls ~= "ROGUE" then return end
	local Map = Ink.modules.Map
	if Map and Map.Refresh then hooksecurefunc(Map, "Refresh", function() pcall(M.DrawWorld, M) end) end
	if Minimap then
		local f = CreateFrame("Frame")
		local acc = 0
		f:SetScript("OnUpdate", function(_, el)
			acc = acc + el
			if acc < 0.2 then return end
			acc = 0
			pcall(M.MiniUpdate, M)
		end)
		if Ink.ProfFrame then Ink.ProfFrame(f, "자물쇠 사물함 미니맵") end
		self.ticker = f
	end
end
