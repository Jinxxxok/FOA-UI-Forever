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
-- 도서관 책 (위치: 와우헤드 포에버 도서관 가이드 좌표, 한글 이름: wowf.io)
--  { 지도, x, y, 한글 이름, 위치, 아이템ID, 반납 퀘스트ID, 진영(0 공통 1 호드 2 얼라), 메모 }
-------------------------------------------------------------------------------
local BOOKS = {
	{ 1429, 65.4, 70.1, "대마법사 테오크리투스의 연구 일지", "아조라의 탑", 203755, 79092, 2 },
	{ 1455, 75.4, 11.0, "대마법사 안토니다스: 자서전 원본", "탐험가의 전당", 203754, 79091, 2 },
	{ 1436, 45.4, 70.4, "마술과 비술", "문브룩", 209845, 78142, 0 },
	{ 1436, 52.7, 53.8, "놈리건의 루미: 작품 모음집", "감시의 언덕", 208860, 79093, 2 },
	{ 1432, 77.4, 14.0, "마술사 왕의 룬", "모그로쉬 소굴 · 오우거 동굴", 209850, 78148, 0 },
	{ 1431, 16.4, 28.4, "범죄에 맞서는 해부학", "어스름 강둑", 209849, 78147, 0 },
	{ 1437, 33.6, 47.9, "고아즈 두루마리", "웰가르의 발굴현장", 209848, 78146, 0 },
	{ 1421, 63.4, 63.1, "달라란 소식지 23호", "앰버밀", 209844, 78127, 0 },
	{ 1421, 43.4, 41.2, "아테릭: 비전의 신비에 관하여", "공동묘지", 210177, 79096, 1 },
	{ 1420, 59.4, 52.3, "연금술사의 형이상학적 지침서", "브릴", 208185, 79095, 1 },
	{ 1439, 59.6, 22.2, "나르탈라스 연감 74권", "마시스트라의 폐허", 209843, 78124, 0 },
	{ 1413, 56.3, 8.8, "신비한 체계 설명서", "진흙늪", 209847, 78145, 0 },
	{ 1413, 62.7, 36.3, "박스탄: 파괴 마법에 관하여", "톱니항", 208800, 79097, 0 },
	{ 1413, 46.0, 36.5, "꿈꾸는 자의 비밀", "푸른 오아시스", 209846, 78143, 0 },
	{ 1442, 74.4, 85.7, "대지의 격노", "그림토템 초소", 209851, 78149, 0 },
	{ 1454, 38.7, 78.4, "타조의 가르침", "정기의 골짜기", 207972, 79094, 1 },
	{ 1434, 41.4, 50.9, "바실리스크: 과연 석화를 두려워해야 하는가?", "수정 광산", 213165, 79535, 0 },
	{ 1441, 34.4, 40.1, "흙점술: 냉혹한 진실", "먹구름 봉우리", 215683, 79947, 0 },
	{ 1416, 48.4, 57.7, "방어 마법의 기초", "갤로우 삼거리", 215815, 79948, 0 },
	{ 1445, 57.2, 20.8, "옳옳옳옳!", "마녀 언덕", 215822, 79952, 0 },
	{ 1417, 73.6, 65.2, "거짓의 그물: 신화와 전설의 실체", "마른나무껍질 마을", 215816, 79949, 0 },
	{ 1443, 55.1, 26.2, "악마와 나", "천둥도끼 요새", 215817, 79950, 0 },
	{ 1418, 56.7, 39.9, "미라: 불쾌한 언데드 안내서", "지하 묘실", 215820, 79951, 0 },
	{ 1435, 61.0, 22.0, "루디트의 악마 소환수 관리법", "드레노어 성역", 215824, 79953, 0, "녹슨 우리 열쇠가 있으면 편해요" },
	{ 1435, 70.1, 51.8, "핏빛 마술", "눈물의 연못", 0, 0, 0 },
	{ 1446, 72.6, 47.8, "파도현자의 전설", "해적단 소굴", 0, 0, 0 },
	{ 1447, 20.8, 62.0, "일상 예의", "할다르 야영지", 0, 0, 0 },
	{ 1428, 29.1, 28.9, "바위의 설계", "검은바위 산", 220349, 0, 0, "검은바위 나락 강철 금고 안쪽" },
	{ 1425, 36.0, 72.8, "지독한 여정", "샤드라알로", 0, 0, 0 },
	{ 1427, 37.8, 49.3, "금속 정신", "용광로", 0, 0, 0 },
	{ 1419, 55.4, 32.2, "창조술사의 전서", nil, 0, 0, 0 },
	{ 1448, 65.2, 3.2, "북부 칼림도어 - 종합 안내서", "나무구렁 요새 안", 228134, 0, 0 },
	{ 1422, 69.4, 72.8, "강령술 기초서", "카엘 다로우 · 스칼로맨스 위층", 228141, 0, 0 },
	{ 1423, 81.7, 57.8, "빛의 연구", "희망의 빛 예배당", 228135, 0, 0 },
	{ 1452, 60.7, 37.7, "콰쾅!", "눈망루 마을 · 연금술 건물", 228136, 0, 0 },
	{ 1422, 38.3, 54.6, "언데드 감자", "펠스톤 농장", 228132, 0, 0, "위치 미확인 (와우헤드 좌표)" },
	{ 1423, 54.5, 50.8, "기사와 숙녀", nil, 228138, 0, 0, "위치 미확인 (와우헤드 좌표)" },
	{ 1423, 31.3, 21.0, "스컬지: 언데드의 위협인가 오해인가?", "스트라솔름 입구 앞", 228140, 0, 0, "위치 미확인 (와우헤드 좌표)" },
}
local LIBRARIANS = {
	[1453] = { 49.0, 86.4, "가리온 웬델", "사서 · 얼라이언스 — 마법사 탑, 책장 옆", 2 },
	[1458] = { 74.0, 32.4, "오웬 사드", "사서 · 호드 — 마법 지구, 계산대 뒤", 1 },
}
local REWARDS = { { 10, "목걸이" }, { 20, "반지" }, { 25, "활 · 방패 · 보조장비" } }
local BOOK = { 0.79, 0.66, 1.00 }      -- 보라
local BOOK_DONE = { 0.44, 0.83, 0.60 } -- 초록

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
		p:SetScale(pinScale)
		-- 크기를 바꾼 틀의 위치 값은 그 크기만큼 곱해져서, 미리 나눠 둬야 제자리에 찍힌다
		p:SetPoint("CENTER", cv, "TOPLEFT", x * W / pinScale, -y * H / pinScale)
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
	self:DrawBooks(mapID, cv, pinScale)
	self:PaintBooks(mapID)
end

-------------------------------------------------------------------------------
-- 도서관 책: 모았는지 (가방 · 은행에 있음 / 반납 퀘스트 완료 / 직접 체크)
-------------------------------------------------------------------------------
local function BookKey(b) return b[6] ~= 0 and ("i" .. b[6]) or ("n" .. b[4]) end

local function BookState(b)
	local key = BookKey(b)
	local man = Ink.cdb and Ink.cdb.books and Ink.cdb.books[key]
	if man == false then return false end              -- 직접 체크를 풀었으면 그대로
	if b[7] ~= 0 and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(b[7]) then return true, "반납함" end
	if b[6] ~= 0 and C_Item.GetItemCount and (C_Item.GetItemCount(b[6], true) or 0) > 0 then return true, "가방 · 은행에 있음" end
	local seen = Ink.cdb and Ink.cdb.booksSeen and Ink.cdb.booksSeen[key]
	if seen then return true, seen end
	if man then return true, "직접 체크" end
	return false
end

local function MyFaction()
	local f = UnitFactionGroup("player")
	return f == "Horde" and 1 or (f == "Alliance" and 2 or 0)
end

function M:BookCount()
	local have, total = 0, 0
	local fac = MyFaction()
	for _, b in ipairs(BOOKS) do
		if b[8] == 0 or b[8] == fac then
			total = total + 1
			if BookState(b) then have = have + 1 end
		end
	end
	return have, total
end

-- 이름이 같은 책을 가방에서 찾기 (아이템 번호가 없는 책용) / 획득 메시지
function M:ScanBagsForBooks(where)
	if not (C_Container and C_Container.GetContainerNumSlots) then return end
	local names = {}
	for _, b in ipairs(BOOKS) do names[b[4]] = b end
	local bags = where == "bank" and { -1, 6, 7, 8, 9, 10, 11, 12 } or { 0, 1, 2, 3, 4, 5 }
	local changed
	for _, bag in ipairs(bags) do
		local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (ok and n or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local nm = info and info.hyperlink and info.hyperlink:match("%[(.-)%]")
			local b = nm and names[nm]
			if b and BookState(b) == false then
				Ink.cdb.booksSeen = Ink.cdb.booksSeen or {}
				Ink.cdb.booksSeen[BookKey(b)] = where == "bank" and "은행에 있음" or "주움"
				changed = true
			end
		end
	end
	if changed and WorldMapFrame and WorldMapFrame:IsShown() then self:Refresh() end
end

function M:ToggleBook(b)
	Ink.cdb.books = Ink.cdb.books or {}
	local key = BookKey(b)
	local on = BookState(b)
	if on then
		Ink.cdb.books[key] = false
		if Ink.cdb.booksSeen then Ink.cdb.booksSeen[key] = nil end
	else
		Ink.cdb.books[key] = true
	end
	PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
	self:Refresh()
end

-------------------------------------------------------------------------------
-- 책 핀: 어두운 원판 + 보라 고리 + 책 아이콘, 모은 책은 초록 고리 + 체크 배지
--  마우스를 올리면 그림만 살짝 커진다 (누르는 범위는 그대로라 깜빡이지 않음)
-------------------------------------------------------------------------------
local function HoverArt(p)
	local ag = p.art:CreateAnimationGroup()
	local sc = ag:CreateAnimation("Scale")
	sc:SetDuration(0.12); sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.16, 1.16); sc:SetSmoothing("OUT")
	ag:SetScript("OnFinished", function() p.art:SetScale(1.16) end)
	p.grow = ag
end

function M:BookPin(i)
	self.bookPins = self.bookPins or {}
	local p = self.bookPins[i]
	if p then return p end
	p = CreateFrame("Button", nil, self.layer)
	p:SetSize(26, 26)
	p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	p.art = CreateFrame("Frame", nil, p)
	p.art:SetPoint("CENTER")
	p.art:SetSize(26, 26)
	p.art:EnableMouse(false)
	local a = p.art
	a.glow = a:CreateTexture(nil, "BACKGROUND", nil, -1)
	a.glow:SetTexture(Ink.tex.glow)
	a.glow:SetPoint("TOPLEFT", -10, 10)
	a.glow:SetPoint("BOTTOMRIGHT", 10, -10)
	a.glow:SetBlendMode("ADD")
	a.disc = a:CreateTexture(nil, "BACKGROUND")
	a.disc:SetTexture(Ink.tex.disc)
	a.disc:SetAllPoints()
	a.disc:SetVertexColor(0.035, 0.035, 0.055, 0.94)
	a.shine = a:CreateTexture(nil, "BORDER")
	a.shine:SetTexture(Ink.tex.disc)
	a.shine:SetPoint("TOPLEFT", 3, -2)
	a.shine:SetPoint("BOTTOMRIGHT", -3, 11)
	a.shine:SetVertexColor(1, 1, 1, 0.06)
	a.ring = a:CreateTexture(nil, "ARTWORK")
	a.ring:SetTexture(Ink.tex.ring)
	a.ring:SetAllPoints()
	a.icon = a:CreateTexture(nil, "OVERLAY")
	a.icon:SetTexture(Ink.icon("Journal"))
	a.icon:SetSize(14, 14)
	a.icon:SetPoint("CENTER")
	a.check = CreateFrame("Frame", nil, a)
	a.check:SetSize(13, 13)
	a.check:SetPoint("CENTER", a, "BOTTOMRIGHT", -3, 3)
	a.check.bg = a.check:CreateTexture(nil, "ARTWORK")
	a.check.bg:SetTexture(Ink.tex.disc)
	a.check.bg:SetAllPoints()
	a.check.bg:SetVertexColor(BOOK_DONE[1], BOOK_DONE[2], BOOK_DONE[3])
	a.check.i = a.check:CreateTexture(nil, "OVERLAY")
	a.check.i:SetTexture(Ink.icon("Check"))
	a.check.i:SetSize(9, 9)
	a.check.i:SetPoint("CENTER")
	a.check.i:SetVertexColor(0.04, 0.06, 0.05)
	HoverArt(p)
	p:SetScript("OnEnter", function(self)
		self.grow:Play()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
		if self.lib then
			GameTooltip:AddLine(self.lib[3], BOOK[1], BOOK[2], BOOK[3])
			GameTooltip:AddLine(self.lib[4], 0.85, 0.86, 0.88)
			local have, total = M:BookCount()
			GameTooltip:AddLine(string.format("모은 책 %d / %d", have, total), 1, 1, 1)
			for _, r in ipairs(REWARDS) do
				local c = have >= r[1] and "|cff6FD39A" or "|cff8E939B"
				GameTooltip:AddLine(string.format("%s%d권 · %s|r", c, r[1], r[2]))
			end
		else
			local b = self.book
			local done, how = BookState(b)
			GameTooltip:AddLine(b[4], done and BOOK_DONE[1] or BOOK[1], done and BOOK_DONE[2] or BOOK[2], done and BOOK_DONE[3] or BOOK[3])
			if b[5] then GameTooltip:AddLine(b[5], 0.85, 0.86, 0.88) end
			GameTooltip:AddLine(string.format("%.1f, %.1f", b[2], b[3]), 0.56, 0.58, 0.61)
			if b[9] then GameTooltip:AddLine(b[9], 1, 0.72, 0.35, true) end
			if b[8] == 1 then GameTooltip:AddLine("언더시티 사서(오웬 사드)에게만 반납", 0.75, 0.77, 0.8)
			elseif b[8] == 2 then GameTooltip:AddLine("스톰윈드 사서(가리온 웬델)에게만 반납", 0.75, 0.77, 0.8) end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(done and ("|cff6FD39A모음|r · " .. (how or "")) or "|cffC9A8FF아직 안 모음|r", 1, 1, 1)
			GameTooltip:AddLine("클릭: 모음 체크 · 우클릭: 길 안내", 0.56, 0.58, 0.61)
		end
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.grow:Stop(); self.art:SetScale(1) end)
	p:SetScript("OnClick", function(self, btn)
		if btn == "RightButton" or self.lib then
			local mapID = WorldMapFrame:GetMapID()
			if mapID and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
				C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, self.wx, self.wy))
				if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
			end
			return
		end
		M:ToggleBook(self.book)
		if GameTooltip:GetOwner() == self then self:GetScript("OnEnter")(self) end
	end)
	self.bookPins[i] = p
	return p
end

function M:PaintBookPin(p, done, lib)
	local col = lib and C.accent or (done and BOOK_DONE or BOOK)
	local a = p.art
	a.ring:SetVertexColor(col[1], col[2], col[3], 1)
	a.icon:SetVertexColor(col[1], col[2], col[3], done and 0.75 or 1)
	a.glow:SetVertexColor(col[1], col[2], col[3], done and 0.12 or 0.3)
	a.check:SetShown(done and not lib)
	p:SetSize(lib and 30 or 26, lib and 30 or 26)
	a:SetSize(lib and 30 or 26, lib and 30 or 26)
end

-- 다른 지도(대륙 · 세계 · 도시를 품은 지역) 위치로 바꾸기
local rectCache = {}
local function ToMap(fromID, x, y, toID)
	if fromID == toID then return x, y end
	local key = fromID .. ">" .. toID
	local r = rectCache[key]
	if r == nil then
		local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, fromID, toID)
		r = (ok and minX and maxX and maxX > minX and maxY > minY) and { minX, maxX, minY, maxY } or false
		rectCache[key] = r
	end
	if not r then return end
	local nx, ny = r[1] + x * (r[2] - r[1]), r[3] + y * (r[4] - r[3])
	if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end
	return nx, ny
end
M.ToMap = ToMap

function M:DrawBooks(mapID, cv, pinScale)
	local n = 0
	local W, H = cv:GetWidth(), cv:GetHeight()
	local fac = MyFaction()
	local function put(x, y, small)
		n = n + 1
		local p = self:BookPin(n)
		local sc = pinScale * (small and 0.62 or 1)
		p:ClearAllPoints()
		p:SetScale(sc)
		p:SetPoint("CENTER", cv, "TOPLEFT", x * W / sc, -y * H / sc)
		p:SetFrameLevel(self.layer:GetFrameLevel() + 20)
		p.wx, p.wy = x, y
		p:Show()
		return p
	end
	if Ink.db.mapBooks ~= false and mapID then
		for _, b in ipairs(BOOKS) do
			if b[8] == 0 or b[8] == fac then
				local x, y = ToMap(b[1], b[2] / 100, b[3] / 100, mapID)
				if x then
					local p = put(x, y, b[1] ~= mapID)
					p.book, p.lib = b, nil
					self:PaintBookPin(p, BookState(b) and true or false, false)
				end
			end
		end
		for libMap, lib in pairs(LIBRARIANS) do
			if lib[5] == fac or fac == 0 then
				local x, y = ToMap(libMap, lib[1] / 100, lib[2] / 100, mapID)
				if x then
					local p = put(x, y, libMap ~= mapID)
					p.book, p.lib = nil, lib
					self:PaintBookPin(p, false, true)
				end
			end
		end
	end
	for i = n + 1, #(self.bookPins or {}) do self.bookPins[i]:Hide() end
end

-------------------------------------------------------------------------------
-- 도서관 책 상자 (지도 왼쪽 아래): 모은 수 + 다음 보상 + 이 지역 책 목록
-------------------------------------------------------------------------------
function M:PaintBooks(mapID)
	local box = self.books
	if not box then return end
	if Ink.db.mapBooks == false or not mapID then box:Hide() return end
	local fac = MyFaction()
	local lines = {}
	for _, b in ipairs(BOOKS) do
		if b[1] == mapID and (b[8] == 0 or b[8] == fac) then
			local done = BookState(b)
			lines[#lines + 1] = (done and "|cff8E939B" or "|cffF3F2EE") .. b[4] .. "|r" .. (done and "  |cff6FD39A모음|r" or "")
			lines[#lines + 1] = "   |cff8E939B" .. (b[5] or "") .. (b[5] and "  ·  " or "") .. string.format("%.1f, %.1f", b[2], b[3]) .. "|r"
		end
	end
	local lib = LIBRARIANS[mapID]
	if #lines == 0 and not lib then box:Hide() return end
	-- 지도를 크게(최대화) 띄우면 아래 칸이 화면 밖이라 지도 안 왼쪽 아래로
	local wm = WorldMapFrame
	box:ClearAllPoints()
	if wm.IsMaximized and wm:IsMaximized() then
		box:SetPoint("BOTTOMLEFT", wm.ScrollContainer, "BOTTOMLEFT", 10, 10)
	else
		box:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", 0, -6)
	end
	local have, total = self:BookCount()
	local nextR
	for _, r in ipairs(REWARDS) do if have < r[1] then nextR = r break end end
	box.count:SetText(string.format("%d / %d", have, total))
	box.bar:SetMinMaxValues(0, math.max(1, total))
	box.bar:SetValue(have)
	box.next:SetText(nextR and string.format("다음 보상 %d권 · %s", nextR[1], nextR[2]) or "보상을 모두 받을 수 있어요")
	box.text:SetText(table.concat(lines, "\n"))
	box.text:SetShown(#lines > 0)
	box:SetHeight(64 + (#lines > 0 and (box.text:GetStringHeight() + 8) or 0))
	box:Show()
end

function M:BuildBooks()
	local wm = WorldMapFrame
	-- 지도를 가리지 않게 지도 창 바로 아래에 붙인다
	local box = CreateFrame("Frame", nil, wm)
	box:SetWidth(290)
	box:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", 0, -6)
	box:SetFrameStrata("HIGH")
	box.bg = Ink:Round(box, "BACKGROUND", false, false)
	box.bg:SetAllPoints()
	box.bg:SetVertexColor(0.035, 0.035, 0.05, 0.9)
	box.bd = Ink:Round(box, "BORDER", false, true)
	box.bd:SetAllPoints()
	box.bd:SetVertexColor(BOOK[1], BOOK[2], BOOK[3], 0.4)
	box.accent = box:CreateTexture(nil, "ARTWORK")
	box.accent:SetColorTexture(BOOK[1], BOOK[2], BOOK[3], 0.95)
	box.accent:SetSize(22, 2)
	box.accent:SetPoint("TOPLEFT", 14, -1)
	box.icon = box:CreateTexture(nil, "ARTWORK")
	box.icon:SetTexture(Ink.icon("Journal"))
	box.icon:SetSize(14, 14)
	box.icon:SetPoint("TOPLEFT", 14, -12)
	box.icon:SetVertexColor(BOOK[1], BOOK[2], BOOK[3])
	box.title = Ink:Text(box, F.bold, 12, C.text, "LEFT")
	box.title:SetPoint("LEFT", box.icon, "RIGHT", 6, 0)
	box.title:SetText("도서관 책")
	box.count = Ink:Text(box, F.latinB, 12, BOOK, "RIGHT")
	box.count:SetPoint("TOPRIGHT", -14, -12)
	box.bar = Ink:Bar(box, 262, 3, BOOK, C.track)
	box.bar:SetPoint("TOPLEFT", 14, -34)
	box.next = Ink:Text(box, F.sans, 10, C.muted, "LEFT")
	box.next:SetPoint("TOPLEFT", box.bar, "BOTTOMLEFT", 0, -6)
	box.text = Ink:Text(box, F.sans, 11, C.soft, "LEFT")
	box.text:SetPoint("TOPLEFT", 14, -62)
	box.text:SetWidth(262)
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
-- 지도 창 옮기기: 위쪽 제목 줄을 끌면 옮겨지고, 다음에 열 때도 그 자리 (최대화 상태는 제외)
function M:MakeMovable()
	local wm = WorldMapFrame
	if self.moveHandle or not wm then return end
	wm:SetMovable(true)
	wm:SetClampedToScreen(true)
	local h = CreateFrame("Frame", nil, wm)
	h:SetPoint("TOPLEFT", wm, "TOPLEFT", 60, 0)
	h:SetPoint("TOPRIGHT", wm, "TOPRIGHT", -60, 0)
	h:SetHeight(22)
	h:SetFrameLevel(wm:GetFrameLevel() + 600)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", function()
		if InCombatLockdown() or (wm.IsMaximized and wm:IsMaximized()) then return end
		wm:StartMoving()
	end)
	h:SetScript("OnDragStop", function()
		wm:StopMovingOrSizing()
		local l, t = wm:GetLeft(), wm:GetTop()
		if l and t then Ink.db.mapPos = { l, t } end
	end)
	h:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("끌어서 지도 옮기기", 1, 1, 1)
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", GameTooltip_Hide)
	self.moveHandle = h
	local function restore()
		local pos = Ink.db.mapPos
		if not pos or InCombatLockdown() or (wm.IsMaximized and wm:IsMaximized()) then return end
		wm:ClearAllPoints()
		wm:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
	end
	wm:HookScript("OnShow", function() C_Timer.After(0, restore) end)
end

function M:Hook()
	local wm = WorldMapFrame
	if not wm or self.hooked or not Canvas() then return end
	self.hooked = true
	pcall(self.MakeMovable, self)
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
	for _, ev in ipairs({ "GOSSIP_SHOW", "ADDON_LOADED", "TAXI_NODE_STATUS_CHANGED", "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN" }) do pcall(e.RegisterEvent, e, ev) end
	C_Timer.After(5, function() pcall(M.ScanBagsForBooks, M, "bags") end)
	e:SetScript("OnEvent", function(_, event)
		if event == "ADDON_LOADED" then
			if not M.hooked then M:Hook() end
			return
		end
		if event == "BAG_UPDATE_DELAYED" or event == "QUEST_TURNED_IN" then
			if event == "BAG_UPDATE_DELAYED" then pcall(M.ScanBagsForBooks, M, "bags") end
			if WorldMapFrame and WorldMapFrame:IsShown() then M:Refresh() end
			return
		end
		if event == "BANKFRAME_OPENED" then
			C_Timer.After(0.5, function() pcall(M.ScanBagsForBooks, M, "bank") end)
		end
		if event == "TAXI_NODE_STATUS_CHANGED" then
			if WorldMapFrame and WorldMapFrame:IsShown() then M:Refresh() end
			return
		end
		-- 창이 열린 직후 NPC 정보가 확실할 때 기록
		C_Timer.After(0.2, function() pcall(M.Remember, M, event) end)
	end)
end
