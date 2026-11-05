-- FOA UI · 세계 지도 표시
--  1) 비행 지점: 이 지도에 있는 비행 조련사를 전부 표시 (발견 = 하늘색, 미발견 = 회색)
--  2) 주요 NPC: 여관 · 은행 · 경매장 · 우편함 · 훈련사 · 상인 · 수리 · 비행 · 사서 …
--     NPC와 대화하거나 창을 열면 그 자리를 기억해 두고 지도에 이름표로 찍는다 (계정 공용, 갈수록 채워짐)
--  3) 도서관 책: 지금 보는 지역에 있는 책과 위치 이름을 지도 구석에 목록으로
--  블리자드 지도가 이미 비행 지점을 그리는 지도에서는 겹치지 않게 FOA 비행 표시를 쉰다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Map")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

-------------------------------------------------------------------------------
-- 도서관 책 (wowf.io 도서관 목록 · 지역과 위치 이름. 좌표는 공개된 게 없어서 위치 이름으로)
-------------------------------------------------------------------------------
local ZONE_KO = {
	["Elwynn Forest"] = "엘윈 숲", ["Ironforge"] = "아이언포지", ["Westfall"] = "서부 몰락지대",
	["Loch Modan"] = "모단 호수", ["Duskwood"] = "그늘숲", ["Wetlands"] = "저습지",
	["Silverpine Forest"] = "은빛소나무 숲", ["Tirisfal Glades"] = "티리스팔 숲", ["Darkshore"] = "어둠해안",
	["The Barrens"] = "불모의 땅", ["Stonetalon Mountains"] = "돌발톱 산맥", ["Orgrimmar"] = "오그리마",
	["Stranglethorn Vale"] = "가시덤불 골짜기", ["Thousand Needles"] = "버섯구름 봉우리", ["Alterac Mountains"] = "알터랙 산맥",
	["Dustwallow Marsh"] = "먼지진흙 습지대", ["Arathi Highlands"] = "아라시 고원", ["Desolace"] = "잊혀진 땅",
	["Badlands"] = "황야의 땅", ["Swamp of Sorrows"] = "슬픔의 늪", ["Tanaris"] = "타나리스",
	["Azshara"] = "아즈샤라", ["Burning Steppes"] = "불타는 평원", ["The Hinterlands"] = "동부 내륙지",
	["Searing Gorge"] = "이글거리는 협곡", ["Blasted Lands"] = "저주받은 땅", ["Felwood"] = "악령의 숲",
	["Western Plaguelands"] = "서부 역병지대", ["Eastern Plaguelands"] = "동부 역병지대", ["Winterspring"] = "여명의 설원",
	["Stormwind City"] = "스톰윈드", ["Undercity"] = "언더시티",
}
local BOOKS = {
	{ "Archmage Theocritus' Research Journal", "Elwynn Forest", "Tower of Azora" },
	{ "Archmage Antonidas: The Unabridged Autobiography", "Ironforge", nil },
	{ "Bewitchments and Glamours", "Westfall", "Moonbrook" },
	{ "Rumi of Gnomeregan: The Collected Works", "Westfall", "Sentinel Hill" },
	{ "Runes of the Sorcerer-Kings", "Loch Modan", "Mo'grosh Stronghold" },
	{ "Crimes Against Anatomy", "Duskwood", "The Darkened Bank" },
	{ "Goaz Scrolls", "Wetlands", "Whelgar's Excavation Site" },
	{ "The Dalaran Digest, Vol. 23", "Silverpine Forest", "Ambermill" },
	{ "Ataeric: On Arcane Curiosities", "Silverpine Forest", "The Sepulcher" },
	{ "The Apothecary's Metaphysical Primer", "Tirisfal Glades", "Brill" },
	{ "Nar'thalas Almanac, Vol. 74", "Darkshore", "Ruins of Mathystra" },
	{ "Arcanic Systems Manual", "The Barrens", "The Sludge Fen" },
	{ "Baxtan: On Destructive Magics", "The Barrens", "Ratchet" },
	{ "Secrets of the Dreamers", "The Barrens", "Lushwater Oasis" },
	{ "Fury of the Land", "Stonetalon Mountains", "Grimtotem Post" },
	{ "The Lessons of Ta'zo", "Orgrimmar", nil },
	{ "Basilisks: Should Petrification be Feared?", "Stranglethorn Vale", "Crystalvein Mine" },
	{ "Geomancy: The Stone-Cold Truth", "Thousand Needles", "Darkcloud Pinnacle" },
	{ "Defensive Magics 101", "Alterac Mountains", "Gallows' Corner" },
	{ "RwlRwlRwlRwl!", "Dustwallow Marsh", "Witch Hill" },
	{ "A Web of Lies: Debunking Myths and Legends", "Arathi Highlands", "Witherbark Village" },
	{ "Demons and You", "Desolace", "Thunder Axe Fortress" },
	{ "Mummies: A Guide to the Unsavory Undead", "Badlands", nil },
	{ "A Luddite's Guide to Caring for Your Demonic Pet", "Swamp of Sorrows", "Fallow Sanctuary" },
	{ "Sanguine Sorcery", "Swamp of Sorrows", "Pool of Tears" },
	{ "Legends of the Tidesages", "Tanaris", "Lost Rigger Cove" },
	{ "Everyday Etiquette", "Azshara", "Haldarr Encampment" },
	{ "Stonewrought Design", "Burning Steppes", "Blackrock Mountain" },
	{ "Venomous Journeys", "The Hinterlands", "Shadra'Alor" },
	{ "A Mind of Metal", "Searing Gorge", "The Cauldron" },
	{ "Conjurer's Codex", "Blasted Lands", nil },
	{ "Northern Kalimdor - A Comprehensive Guide", "Felwood", "Timbermaw Hold" },
	{ "Necromancy 101", "Western Plaguelands", "Caer Darrow" },
	{ "A Study of the Light", "Eastern Plaguelands", "Light's Hope Chapel" },
	{ "Ka-Boom!", "Winterspring", "Everlook" },
}
-- 위치 이름 한글 (확실한 것만. 나머지는 영어 그대로)
local SUB_KO = {
	["Moonbrook"] = "달빛시내 마을", ["Sentinel Hill"] = "감시의 언덕", ["Brill"] = "브릴", ["Ratchet"] = "톱니항",
	["Everlook"] = "눈망루 마을", ["Light's Hope Chapel"] = "희망의 빛 예배당", ["Caer Darrow"] = "카엘 다로우",
	["Blackrock Mountain"] = "검은바위 산", ["Timbermaw Hold"] = "나무구렁 요새", ["The Sepulcher"] = "공동묘지",
}
local LIBRARIANS = {
	["Stormwind City"] = { "사서 가리온 웬델 (얼라이언스)", "마법사 지구 · 책장 옆 — 책을 모아 가져가요" },
	["Undercity"] = { "사서 오웬 새드 (호드)", "마법 지구 · 계산대 뒤 — 책을 모아 가져가요" },
}
local REWARDS = "책 10권 목걸이 · 20권 반지 · 25권 활/방패/보조장비"

-------------------------------------------------------------------------------
-- NPC 역할 → 지도 이름표 글자
-------------------------------------------------------------------------------
local ROLE_LABEL = {
	inn = "여관", mail = "우편함", bank = "은행", auction = "경매장", stable = "야수 관리인", flight = "비행",
	transmog = "형상변환", upgrade = "강화", barber = "미용실", quartermaster = "병참관", librarian = "사서",
	trainer = "훈련사", repair = "수리", vendor = "상인",
}
local ROLE_ICON = {
	inn = "NpcInn", mail = "NpcMail", bank = "NpcBank", auction = "NpcAuction", stable = "NpcStable", flight = "NpcFlight",
	transmog = "NpcTransmog", upgrade = "NpcUpgrade", barber = "NpcBarber", quartermaster = "NpcQuartermaster",
	librarian = "Journal", trainer = "NpcTrainer", repair = "NpcRepair", vendor = "NpcVendor",
}
local ROLE_COLOR = {}
do
	local P = ns.Plates or Ink.modules.Plates
	for _, r in ipairs((P and P.ROLES) or {}) do ROLE_COLOR[r.key] = r.rgb end
end
local function RoleColor(k)
	if not ROLE_COLOR[k] then
		local P = Ink.modules.Plates
		for _, r in ipairs((P and P.ROLES) or {}) do ROLE_COLOR[r.key] = r.rgb end
	end
	return ROLE_COLOR[k] or C.accent
end

-------------------------------------------------------------------------------
-- 지도 위 핀
-------------------------------------------------------------------------------
local function Canvas()
	local wm = WorldMapFrame
	return wm and wm.ScrollContainer and wm.ScrollContainer.Child
end

function M:NewPin()
	local cv = Canvas()
	local p = CreateFrame("Frame", nil, self.layer)
	p:SetSize(22, 22)
	p.disc = p:CreateTexture(nil, "BACKGROUND")
	p.disc:SetTexture(Ink.tex.disc)
	p.disc:SetAllPoints()
	p.disc:SetVertexColor(0.035, 0.04, 0.052, 0.92)
	p.ring = p:CreateTexture(nil, "BORDER")
	p.ring:SetTexture(Ink.tex.ring)
	p.ring:SetAllPoints()
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetSize(13, 13)
	p.icon:SetPoint("CENTER")
	p.label = Ink:Text(p, F.semi, 11, C.text, "CENTER")
	p.label:SetPoint("TOP", p, "BOTTOM", 0, -1)
	p.label:SetShadowColor(0, 0, 0, 1)
	p:EnableMouse(true)
	p:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.tipTitle or "", 1, 1, 1)
		if self.tipSub then GameTooltip:AddLine(self.tipSub, 0.75, 0.77, 0.8, true) end
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", GameTooltip_Hide)
	return p
end

function M:Pin(i)
	self.pins = self.pins or {}
	local p = self.pins[i]
	if not p then p = self:NewPin(); self.pins[i] = p end
	return p
end

-------------------------------------------------------------------------------
-- 그리기
-------------------------------------------------------------------------------
local FLIGHT_ON = { 0.53, 0.87, 0.95 }
local FLIGHT_OFF = { 0.55, 0.57, 0.60 }

function M:Refresh()
	local wm = WorldMapFrame
	local cv = Canvas()
	if not (wm and cv and wm:IsShown() and self.layer) then return end
	local mapID = wm:GetMapID()
	local W, H = cv:GetWidth(), cv:GetHeight()
	local scale = (wm.GetCanvasScale and wm:GetCanvasScale()) or 1
	local pinScale = math.max(0.45, math.min(1.4, 1 / scale))
	local n = 0
	local function place(x, y, iconName, color, label, title, sub, dim)
		n = n + 1
		local p = self:Pin(n)
		p:ClearAllPoints()
		p:SetPoint("CENTER", cv, "TOPLEFT", x * W, -y * H)
		p:SetScale(pinScale)
		p.icon:SetTexture(Ink.icon(iconName))
		p.icon:SetVertexColor(color[1], color[2], color[3])
		p.ring:SetVertexColor(color[1], color[2], color[3], dim and 0.45 or 0.95)
		p.icon:SetAlpha(dim and 0.6 or 1)
		p.label:SetText(label or "")
		p.label:SetTextColor(color[1], color[2], color[3], dim and 0.7 or 1)
		p.tipTitle, p.tipSub = title, sub
		p:Show()
	end

	-- 1) 비행 지점 (블리자드가 이미 그리는 지도면 쉰다)
	if Ink.db.mapFlight ~= false and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and mapID then
		local blizzard = C_TaxiMap.ShouldMapShowTaxiNodes and C_TaxiMap.ShouldMapShowTaxiNodes(mapID)
		if not blizzard then
			local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
			local faction = UnitFactionGroup("player")
			for _, nd in ipairs(ok and nodes or {}) do
				local pos = nd.position
				local x, y = pos and pos.GetXY and pos:GetXY()
				local fac = nd.faction
				local mine = true
				if Enum.FlightPathFaction then
					if fac == Enum.FlightPathFaction.Horde then mine = faction == "Horde"
					elseif fac == Enum.FlightPathFaction.Alliance then mine = faction == "Alliance" end
				end
				if x and y and mine and not nd.isMapLayerTransition then
					local off = nd.isUndiscovered
					place(x, y, "NpcFlight", off and FLIGHT_OFF or FLIGHT_ON, nil,
						nd.name or "비행 지점", off and "아직 발견 못 한 비행 지점" or "발견한 비행 지점")
				end
			end
		end
	end

	-- 2) 기억해 둔 주요 NPC
	local spots = Ink.db.npcSpots and mapID and Ink.db.npcSpots[mapID]
	if Ink.db.mapNpcs ~= false and spots then
		for name, s in pairs(spots) do
			local col = RoleColor(s.role)
			local label = s.role == "trainer" and s.sub or ROLE_LABEL[s.role]
			place(s.x, s.y, ROLE_ICON[s.role] or "NpcVendor", col, label, name, s.sub and ("<" .. s.sub .. ">") or nil)
		end
	end

	for i = n + 1, #(self.pins or {}) do self.pins[i]:Hide() end
	self:PaintBooks(mapID)
end

-------------------------------------------------------------------------------
-- 도서관 책 목록 (지도 왼쪽 아래)
-------------------------------------------------------------------------------
local function ZoneKey(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	local name = info and info.name
	if not name then return end
	for en, ko in pairs(ZONE_KO) do
		if name == en or name == ko then return en end
	end
end

function M:PaintBooks(mapID)
	local box = self.books
	if not box then return end
	local zone = Ink.db.mapBooks ~= false and ZoneKey(mapID)
	if not zone then box:Hide() return end
	local lines = {}
	local lib = LIBRARIANS[zone]
	if lib then
		lines[#lines + 1] = "|cffC9A8FF" .. lib[1] .. "|r"
		lines[#lines + 1] = "|cffB4B8BF" .. lib[2] .. "|r"
		lines[#lines + 1] = "|cff8E939B" .. REWARDS .. "|r"
	end
	for _, b in ipairs(BOOKS) do
		if b[2] == zone then
			local where = b[3] and ((SUB_KO[b[3]] and (SUB_KO[b[3]] .. " · ") or "") .. b[3]) or "도시 안"
			lines[#lines + 1] = "|cffF3F2EE" .. b[1] .. "|r"
			lines[#lines + 1] = "   |cffB4B8BF" .. where .. "|r"
		end
	end
	if #lines == 0 then box:Hide() return end
	box.text:SetText(table.concat(lines, "\n"))
	box:SetHeight(box.text:GetStringHeight() + 40)
	box:Show()
end

function M:BuildBooks()
	local wm = WorldMapFrame
	local box = CreateFrame("Frame", nil, wm.ScrollContainer)
	box:SetWidth(300)
	box:SetPoint("BOTTOMLEFT", wm.ScrollContainer, "BOTTOMLEFT", 10, 10)
	box:SetFrameStrata("HIGH")
	box.bg = Ink:Round(box, "BACKGROUND", false, false)
	box.bg:SetAllPoints()
	box.bg:SetVertexColor(0.04, 0.045, 0.06, 0.88)
	box.bd = Ink:Round(box, "BORDER", false, true)
	box.bd:SetAllPoints()
	box.bd:SetVertexColor(0.79, 0.66, 1, 0.45)
	box.icon = box:CreateTexture(nil, "ARTWORK")
	box.icon:SetTexture(Ink.icon("Journal"))
	box.icon:SetSize(14, 14)
	box.icon:SetPoint("TOPLEFT", 12, -10)
	box.icon:SetVertexColor(0.79, 0.66, 1)
	box.title = Ink:Text(box, F.bold, 12, C.text, "LEFT")
	box.title:SetPoint("LEFT", box.icon, "RIGHT", 6, 0)
	box.title:SetText("도서관 책")
	box.text = Ink:Text(box, F.sans, 11, C.soft, "LEFT")
	box.text:SetPoint("TOPLEFT", 12, -30)
	box.text:SetWidth(276)
	box.text:SetWordWrap(true)
	box.text:SetSpacing(2)
	box:Hide()
	self.books = box
end

-------------------------------------------------------------------------------
-- NPC 자리 기억: 대화 · 상점 · 은행 · 훈련사 · 비행 · 우편함 창이 열릴 때 내 위치를 그 NPC 자리로
-------------------------------------------------------------------------------
local EVENT_ROLE = {
	TAXIMAP_OPENED = "flight", BANKFRAME_OPENED = "bank", AUCTION_HOUSE_SHOW = "auction",
	MAIL_SHOW = "mail", TRAINER_SHOW = "trainer", MERCHANT_SHOW = "vendor", GOSSIP_SHOW = nil,
}

function M:Remember(event)
	if IsInInstance() then return end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return end
	local x, y = pos:GetXY()
	if not (x and y) or (x == 0 and y == 0) then return end
	local P = Ink.modules.Plates
	local role, sub, name
	if event == "MAIL_SHOW" and not UnitExists("npc") then
		role, name = "mail", "우편함"
	else
		if not UnitExists("npc") then return end
		name = plain(UnitName("npc"))
		sub = P and P.Subtitle and P.Subtitle("npc")
		local r = P and P.NpcRole and P.NpcRole("npc")
		role = r and r.key or EVENT_ROLE[event]
		if event == "MERCHANT_SHOW" and CanMerchantRepair and CanMerchantRepair() and (not r or r.key == "vendor") then role = "repair" end
	end
	if not (role and type(name) == "string") then return end
	Ink.db.npcSpots = Ink.db.npcSpots or {}
	local t = Ink.db.npcSpots[mapID] or {}
	Ink.db.npcSpots[mapID] = t
	t[name] = { x = math.floor(x * 1000 + 0.5) / 1000, y = math.floor(y * 1000 + 0.5) / 1000, role = role, sub = sub }
	if WorldMapFrame and WorldMapFrame:IsShown() then self:Refresh() end
end

-------------------------------------------------------------------------------
function M:Hook()
	local wm = WorldMapFrame
	if not wm or self.hooked or not Canvas() then return end
	self.hooked = true
	self.layer = CreateFrame("Frame", nil, Canvas())
	self.layer:SetAllPoints()
	self.layer:SetFrameLevel(Canvas():GetFrameLevel() + 2500)
	self:BuildBooks()
	wm:HookScript("OnShow", function() C_Timer.After(0, function() M:Refresh() end) end)
	if wm.OnMapChanged then hooksecurefunc(wm, "OnMapChanged", function() M:Refresh() end) end
	if wm.OnCanvasScaleChanged then hooksecurefunc(wm, "OnCanvasScaleChanged", function() M:Refresh() end) end
end

function M:Init()
	if Ink.db.mapLayer == false then return end
	self:Hook()
	local e = CreateFrame("Frame")
	for ev in pairs(EVENT_ROLE) do pcall(e.RegisterEvent, e, ev) end
	for _, ev in ipairs({ "GOSSIP_SHOW", "ADDON_LOADED", "TAXI_NODE_STATUS_CHANGED" }) do pcall(e.RegisterEvent, e, ev) end
	e:SetScript("OnEvent", function(_, event)
		if event == "ADDON_LOADED" then
			if not M.hooked then M:Hook() end
			return
		end
		if event == "TAXI_NODE_STATUS_CHANGED" then
			if WorldMapFrame and WorldMapFrame:IsShown() then M:Refresh() end
			return
		end
		-- 창이 열린 직후 NPC 정보가 확실할 때 기록
		C_Timer.After(0.2, function() pcall(M.Remember, M, event) end)
	end)
end
