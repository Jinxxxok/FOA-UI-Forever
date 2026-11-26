-- FOA UI · 외형 도감 (포에버)
--  본섭 '수집품 → 외형' 처럼 부위별로 장비 외형을 3D 모델 격자로 보고, 어디서 나오는지 · 내 캐릭터에 입혀 본 모습까지.
--  · 포에버 게임에도 외형 시스템(입혀 보기 모델 · 외형 번호 · 부위별 카메라)은 그대로 있고, 수집품 창이
--    "모은 외형만" 보이게 막혀 있을 뿐이다 → FOA 가 아는 장비(던전 드랍 · 퀘스트 · 제작 · 필드/상인 · PvP)를 직접 모아 보여 준다
--  · 같은 생김새(외형 번호)는 한 칸에 묶고, 칸에 마우스를 올리면 그 외형이 나오는 아이템 · 획득처를 모두 보여 준다
--  · 칸을 누르면 오른쪽 미리보기에서 지금 내 장비 위에 입혀 본다 (끌어서 돌리기 · 휠 확대 · 오른쪽 끌기 이동)
--  · 여는 곳: BIS 창 "외형 도감" · BIS · 던전 전리품 칸 Ctrl+클릭 · /foa 외형
--  게임 API: DressUpModel(TryOn · SetItemAppearance) · C_TransmogCollection.GetItemInfo / GetAppearanceCameraID · Model_ApplyUICamera

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Wardrobe")
local F, C = Ink.font, Ink.c
local build = select(4, GetBuildInfo()) or 0
local FOREVER = build >= 16001 and build < 20000
M.forever = FOREVER

local QCOL = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }

-- 부위 (보이지 않는 칸 = 목 · 반지 · 장신구 · 성물은 없음)
local SLOTS = {
	{ key = "head", ko = "머리", inv = { INVTYPE_HEAD = true }, ts = "HEADSLOT", armor = true },
	{ key = "shoulder", ko = "어깨", inv = { INVTYPE_SHOULDER = true }, ts = "SHOULDERSLOT", armor = true },
	{ key = "back", ko = "등", inv = { INVTYPE_CLOAK = true }, ts = "BACKSLOT", armor = true },
	{ key = "chest", ko = "가슴", inv = { INVTYPE_CHEST = true, INVTYPE_ROBE = true }, ts = "CHESTSLOT", armor = true },
	{ key = "wrist", ko = "손목", inv = { INVTYPE_WRIST = true }, ts = "WRISTSLOT", armor = true },
	{ key = "hands", ko = "손", inv = { INVTYPE_HAND = true }, ts = "HANDSSLOT", armor = true },
	{ key = "waist", ko = "허리", inv = { INVTYPE_WAIST = true }, ts = "WAISTSLOT", armor = true },
	{ key = "legs", ko = "다리", inv = { INVTYPE_LEGS = true }, ts = "LEGSSLOT", armor = true },
	{ key = "feet", ko = "발", inv = { INVTYPE_FEET = true }, ts = "FEETSLOT", armor = true },
	{ key = "1h", ko = "한손 무기", inv = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true } },
	{ key = "2h", ko = "양손 무기", inv = { INVTYPE_2HWEAPON = true } },
	{ key = "oh", ko = "보조 · 방패", inv = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true } },
	{ key = "ranged", ko = "원거리", inv = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true } },
}
M.SLOTS = SLOTS
local SLOT_OF = {}
for i, s in ipairs(SLOTS) do for loc in pairs(s.inv) do SLOT_OF[loc] = i end end

-- 본섭 외형 창과 같은 모델 준비 (블리자드 TransmogShared 표 · 부위마다 다른 칸을 숨김 장비로 가린다)
--  숨김 장비 번호(78416 …)는 아이템이 아니라 외형 번호 · 없으면 그냥 벗은 몸
local SETUP = {
	HEADSLOT = { skin = false, choices = false, obey = false, slots = { CHESTSLOT = true } },
	SHOULDERSLOT = { skin = true, choices = true, obey = true, slots = { HEADSLOT = true } },
	BACKSLOT = { skin = true, choices = true, obey = true, slots = { HEADSLOT = true } },
	CHESTSLOT = { skin = true, choices = true, obey = true, slots = { HEADSLOT = true } },
	WRISTSLOT = { skin = true, choices = true, obey = true, slots = { HEADSLOT = true } },
	HANDSSLOT = { skin = false, choices = true, obey = true, slots = { CHESTSLOT = true, LEGSSLOT = true, FEETSLOT = true, HEADSLOT = true } },
	WAISTSLOT = { skin = true, choices = true, obey = true, slots = { HEADSLOT = true } },
	LEGSSLOT = { skin = true, choices = true, obey = true, slots = { HEADSLOT = true } },
	FEETSLOT = { skin = false, choices = true, obey = true, slots = { CHESTSLOT = true, HANDSSLOT = true, LEGSSLOT = true, HEADSLOT = true } },
}
local SETUP_GEAR = { CHESTSLOT = 78420, LEGSSLOT = 78425, FEETSLOT = 78427, HANDSSLOT = 78426, HEADSLOT = 78416 }

-- 획득처 종류 (위 칩)
local KINDS = { { "all", "전체" }, { "dungeon", "던전" }, { "quest", "퀘스트" }, { "craft", "제작" }, { "world", "필드 · 상인" }, { "pvp", "PvP" } }
local PROF = { "대장기술", "가죽세공", "재봉술", "기계공학", "마법부여" }

local COLS, ROWS = 4, 2
local PAGE = COLS * ROWS
local CELL_W, CELL_H, MODEL_H = 138, 216, 168
local LEFT_W, PREV_W = 132, 262
local W = 16 + LEFT_W + 12 + COLS * (CELL_W + 6) - 6 + 14 + PREV_W + 16
local H = 610

local function D() return Ink.modules.Dungeon end
local function MyFac()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	return f == "Horde" and 1 or (f == "Alliance" and 2 or 0)
end

-------------------------------------------------------------------------------
-- 자료 모으기: [아이템] = { src = { { 종류, 글, 퀘스트 } … }, kinds = { 종류 = true } }
-------------------------------------------------------------------------------
local function Add(items, id, kind, text, qid)
	if type(id) ~= "number" then return end
	local e = items[id]
	if not e then e = { src = {}, kinds = {} }; items[id] = e end
	for _, s in ipairs(e.src) do if s[2] == text and s[3] == qid then return end end
	if #e.src < 6 then e.src[#e.src + 1] = { kind, text, qid } end
	e.kinds[kind] = true
end

local function KindOfText(t)
	if t:find("퀘스트") then return "quest" end
	if t:find("제조법") or t:find("제작") then return "craft" end
	if t:find("상인") or t:find("평판") or t:find("월드 드랍") or t:find("^드랍") then return "world" end
	return "dungeon"
end

function M:Collect()
	if self.items then return self.items end
	local items, my = {}, MyFac()
	local Dg = D()
	-- 던전 보스 · 일반 몹 (ForeverSources 가 던전 목록에 "일반 몹" 칸으로 넣어 둔 것 포함)
	for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
		if not d.soon then
			for _, b in ipairs(d.bosses or {}) do
				local bn = (Dg and Dg.BossName and Dg.BossName({ npc = b[3], name = b[1] })) or b[1] or ""
				for _, id in ipairs(b[2] or {}) do Add(items, id, "dungeon", (d.ko or d.en or "") .. " · " .. bn) end
			end
		end
	end
	-- 월드 드랍 · 필드 몹 · 희귀몹 · 상인 · 평판 · 언더마인 (내 진영 것만)
	local S = ns.FOREVER_SOURCES
	if S and ns.ItemSourceText then
		for id, e in pairs(S) do
			if not ns.ItemSourceForMe or ns.ItemSourceForMe(id) then
				local t = ns.ItemSourceText(id)
				if t then
					local kind = "world"
					for _, s in ipairs(e.src or {}) do if s[1] == "t" or s[1] == "x" then kind = "dungeon" end end
					Add(items, id, kind, t)
				end
			end
		end
	end
	-- 퀘스트 보상 { 아이템, 퀘스트, 레벨, 진영(1호드 2얼라), … }
	for _, q in ipairs(ns.FOREVER_QREWARDS or {}) do
		local fac = q[4] or 0
		if fac == 0 or my == 0 or fac == my then Add(items, q[1], "quest", nil, q[2]) end
	end
	-- 제작 { 아이템, 전문기술, 주문, 숙련 }
	for _, c in ipairs(ns.FOREVER_CRAFTS or {}) do
		Add(items, c[1], "craft", (PROF[c[2]] or "제작") .. " 제작" .. (c[4] and c[4] > 0 and (" · 숙련 " .. c[4]) or ""))
	end
	-- PvP (명예 · 계급)
	local P = ns.FOREVER_PVP
	if P then
		local mine = my == 1 and P.H or P.A
		for rank, list in pairs(mine or {}) do
			for _, id in ipairs(list) do Add(items, id, "pvp", "PvP 계급 " .. rank .. " 장비 (명예 상인)") end
		end
		for _, id in ipairs(P.N or {}) do Add(items, id, "pvp", "PvP 명예 장비 (명예 상인)") end
	end
	-- BIS 공략 획득처 (T0.5 강화 퀘스트 등 위 자료에 없는 것)
	local B = ns.BIS_FOREVER
	local KS = Dg and Dg.KoSource
	for _, kind in ipairs({ "specs", "pvp" }) do
		for _, sp in pairs(B and B[kind] or {}) do
			for id, t in pairs(sp.src or {}) do
				if not items[id] and type(t) == "string" then
					local txt = KS and KS(t) or t
					Add(items, id, KindOfText(txt), txt)
				end
			end
		end
	end
	self.items = items
	return items
end

-- 게임 수집품에 모은 외형인가 (외형 하나라도 · 그 아이템 · 그 출처)
function M.Collected(g)
	local T = C_TransmogCollection
	if not T then return false end
	if g.src and T.GetAppearanceInfoBySource then
		local ok, info = pcall(T.GetAppearanceInfoBySource, g.src)
		if ok and type(info) == "table" and (info.appearanceIsCollected or info.sourceIsCollected) then return true end
	end
	for _, id in ipairs(g.ids or {}) do
		if T.PlayerHasTransmog then
			local ok, v = pcall(T.PlayerHasTransmog, id)
			if ok and v == true then return true end
		end
	end
	if g.src and T.PlayerHasTransmogItemModifiedAppearance then
		local ok, v = pcall(T.PlayerHasTransmogItemModifiedAppearance, g.src)
		if ok and v == true then return true end
	end
	return false
end

-- 외형 번호 · 외형 출처 번호 (게임에 외형 자료가 없으면 nil → 아이템 번호로 입혀 본다)
local appMemo = {}
local function Appearance(id)
	local m = appMemo[id]
	if m then return m[1], m[2] end
	local app, src
	if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
		local ok, a, s = pcall(C_TransmogCollection.GetItemInfo, id)
		if ok then app, src = a, s end
	end
	if type(app) ~= "number" or app == 0 then app = nil end
	if type(src) ~= "number" or src == 0 then src = nil end
	if app then appMemo[id] = { app, src } end
	return app, src
end
M.Appearance = Appearance

local function Quality(id)
	local Dg = D()
	return (Dg and Dg.QualityOf and Dg.QualityOf(id)) or (C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)) or 1
end

-- 이름: 한 번 받은 이름은 기억해 둔다
--  게임이 들고 있는 아이템 정보는 개수 한도가 있어서 수백 개를 훑으면 먼저 받은 이름이 밀려난다
--  → 기억 없이 그리면 "아이템 #번호"와 이름이 번갈아 깜빡였다
local nameMemo = {}
local function ItemName(id)
	local n = nameMemo[id]
	if n then return n end
	n = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not n and C_Item.GetItemInfo then n = C_Item.GetItemInfo(id) end
	if type(n) == "string" and n ~= "" then nameMemo[id] = n return n end
	local nm = ns.BIS_FOREVER and ns.BIS_FOREVER.nm
	return nm and nm[id]
end
local function Cached(id)
	return not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(id) or nameMemo[id] ~= nil
end
local function Request(id)
	if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
end

local function QuestTitle(qid)
	local t = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
	if not t and C_QuestLog and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, qid) end
	return t or ("#" .. qid)
end

local function SrcText(s)
	if s[3] then return "퀘스트 · " .. QuestTitle(s[3]) end
	return s[2] or ""
end
M.SrcText = SrcText

-- BIS 창이 지금 고른 특성으로 매긴 순위 (있으면 칸에 BIS · 대체 표시)
local function RankOf(id)
	local Dg = D()
	local r = Dg and Dg.ranks and Dg.ranks[id]
	return r and r.rank
end

-------------------------------------------------------------------------------
-- 즐겨찾기 (계정 공통 · InkUIDB.wardFav = { [아이템] = true })
--  아이템 번호로 기억한다: 외형 번호는 게임이 늦게 알려 주기도 해서 번호로 묶으면 잃어버릴 수 있다
--  같은 외형의 아이템 중 하나라도 들어 있으면 그 외형이 즐겨찾기
-------------------------------------------------------------------------------
local function FavDB()
	local t = Ink.db.wardFav
	if type(t) ~= "table" then t = {}; Ink.db.wardFav = t end
	return t
end
function M.IsFav(g)
	if not g then return false end
	local fav = FavDB()
	for _, id in ipairs(g.ids or { g.first }) do if fav[id] then return true end end
	return false
end
function M.FavCount()
	local n = 0
	for _ in pairs(FavDB()) do n = n + 1 end
	return n
end
-- 켜기 = 대표 아이템 하나 · 끄기 = 그 외형의 아이템 모두
--  즐겨찾기 탭에서 끄면 칸은 그대로 두고 별만 빈다 (잘못 눌렀으면 다시 누르면 되게 · 다른 탭에 다녀오면 빠진다)
function M:ToggleFav(g)
	if not (g and g.first) then return end
	local fav = FavDB()
	if M.IsFav(g) then
		for _, id in ipairs(g.ids or { g.first }) do fav[id] = nil end
	else
		fav[g.first] = true
	end
	self:PaintFav()
end

-------------------------------------------------------------------------------
-- 목록: 고른 부위 · 획득처 · 내 직업 · 검색어로 거른 뒤 같은 외형끼리 묶는다
-------------------------------------------------------------------------------
function M:List()
	local items = self:Collect()
	local favMode = self.fav
	local slot = SLOTS[self.slot or 1]
	local kind, mine, q = self.kind or "all", self.mine ~= false, self.query
	local Dg = D()
	local fmc = Dg and Dg.ForMyClass
	local groups, byKey, nItems = {}, {}, 0
	-- 즐겨찾기 탭: 부위 · 획득처 · 내 직업 상관없이 즐겨찾기한 아이템 + 그와 같은 외형
	local fav, favApp = nil, {}
	if favMode then
		fav = FavDB()
		for id in pairs(fav) do
			local a = Appearance(id)
			if a then favApp[a] = true end
		end
	end
	local anyApp = next(favApp) ~= nil
	local function Consider(id, e)
		local _, _, _, loc, icon = C_Item.GetItemInfoInstant(id)
		local si = loc and SLOT_OF[loc]
		if not si or (Dg and Dg.itemFail and Dg.itemFail[id]) then return end
		if favMode then
			if not fav[id] then
				local a = anyApp and Appearance(id)
				if not (a and favApp[a]) then return end
			end
		elseif not (slot.inv[loc] and (kind == "all" or e.kinds[kind]) and (not mine or not fmc or fmc({ id = id }))) then
			return
		end
		if q and q ~= "" then
			local n = ItemName(id)
			if not n and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
			if not (n and n:lower():find(q, 1, true)) then return end
		end
		nItems = nItems + 1
		local app, src = Appearance(id)
		local key = app and ("a" .. app) or ("i" .. id)
		local g = byKey[key]
		if not g then
			g = { app = app, src = src, ids = {}, icon = icon, slot = si }
			byKey[key] = g
			groups[#groups + 1] = g
		end
		g.ids[#g.ids + 1] = id
	end
	for id, e in pairs(items) do Consider(id, e) end
	-- 도감 자료에 없는 아이템(내 직업이 아닌 BIS 칸에서 Ctrl+클릭으로 열어 본 것 등)도 즐겨찾기엔 보인다
	if favMode then for id in pairs(fav) do if not items[id] then Consider(id, nil) end end end
	for _, g in ipairs(groups) do
		-- 한 외형 안에서는 BIS → 등급 높은 것 → 번호 순 (대표 아이템 = 맨 앞)
		table.sort(g.ids, function(a, b)
			local ra, rb = RankOf(a) or 99, RankOf(b) or 99
			if ra ~= rb then return ra < rb end
			local qa, qb = Quality(a), Quality(b)
			if qa ~= qb then return qa > qb end
			return a > b
		end)
		g.first = g.ids[1]
		g.rank = RankOf(g.first)
		g.q = Quality(g.first)
	end
	-- 가진 외형: 착용 · 가방 · 은행(FOA 가 기억한 것) 또는 게임 수집품에 모은 외형
	local own = {}
	if Dg and Dg.OwnedItems then local ok, o = pcall(Dg.OwnedItems, Dg); if ok and type(o) == "table" then own = o end end
	local nHave = 0
	for _, g in ipairs(groups) do
		g.have = nil
		for _, id in ipairs(g.ids) do
			local o = own[id]
			if o then g.have, g.haveID = o.kind, id break end
		end
		if not g.have and M.Collected(g) then g.have = "col" end
		if g.have then nHave = nHave + 1 end
	end
	self.nHave = nHave
	-- 외형끼리: (즐겨찾기 탭은 부위 순서 먼저) 지금 특성 BIS · 대체 → 등급 → 번호(새 장비가 앞)
	table.sort(groups, function(a, b)
		if favMode and a.slot ~= b.slot then return a.slot < b.slot end
		local ra, rb = a.rank or 99, b.rank or 99
		if ra ~= rb then return ra < rb end
		if a.q ~= b.q then return a.q > b.q end
		return a.first > b.first
	end)
	self.groups, self.nItems = groups, nItems
	return groups
end

-------------------------------------------------------------------------------
-- 모델
-------------------------------------------------------------------------------
local function ApplyCam(m)
	if m.cameraID and m.cameraID > 0 and Model_ApplyUICamera then pcall(Model_ApplyUICamera, m, m.cameraID) end
end

local function FlatLight(m)
	if not (m.SetLight and CreateVector3D and CreateColor) then return end
	pcall(m.SetLight, m, true, {
		omnidirectional = false, point = CreateVector3D(-1, 1, -1),
		ambientIntensity = 1.05, ambientColor = CreateColor(1, 1, 1),
		diffuseIntensity = 0, diffuseColor = CreateColor(1, 1, 1),
	})
end

local function NewModel(parent, cell)
	local ok, m = pcall(CreateFrame, "DressUpModel", nil, parent)
	if not ok or not m then return nil end
	if cell then
		-- 본섭 외형 창과 같은 조명(앞뒤 고르게) · 자동으로 내 장비 입히기 끔
		--  기본 조명은 어깨처럼 옆 · 뒤에서 보는 카메라에서 몸이 까맣게 보였다
		pcall(m.SetAutoDress, m, false)
		FlatLight(m)
		m:SetScript("OnModelLoaded", ApplyCam)
	end
	return m
end

-- 격자 칸: 본섭 외형 창과 같은 방식 (방어구 = 벗은 몸에 그 칸만 · 무기 = 무기만)
--  돌려주는 값: 아이템 정보가 아직 안 와서 제대로 못 입혔으면 true (정보가 오면 다시 그린다)
local function ShowInCell(m, g, slot)
	if not m then return end
	m.cameraID = nil
	if not g.app then g.app, g.src = Appearance(g.first) end
	local pending = not Cached(g.first)
	if slot.armor then
		local set = SETUP[slot.ts]
		if m.slotKey ~= slot.key then
			if set then
				pcall(m.SetUseTransmogSkin, m, set.skin)
				pcall(m.SetUseTransmogChoices, m, set.choices)
				pcall(m.SetObeyHideInTransmogFlag, m, set.obey)
			end
			pcall(m.SetUnit, m, "player", false)
			m.slotKey = slot.key
		end
		pcall(m.Undress, m)
		for s, on in pairs(set and set.slots or {}) do
			if on and SETUP_GEAR[s] then pcall(m.TryOn, m, SETUP_GEAR[s]) end
		end
		local ok, r = pcall(m.TryOn, m, g.src or ("item:" .. g.first))
		if (not ok or r == 3) and g.src then ok, r = pcall(m.TryOn, m, "item:" .. g.first) end
		if r == 3 then pending = true end   -- Enum.ItemTryOnReason.DataPending
	else
		m.slotKey = slot.key
		local ok = g.app and pcall(m.SetItemAppearance, m, g.app)
		if not ok then pcall(m.SetItem, m, g.first) else pending = false end
	end
	if g.app and C_TransmogCollection and C_TransmogCollection.GetAppearanceCameraID then
		local ok, cam = pcall(C_TransmogCollection.GetAppearanceCameraID, g.app)
		if ok and type(cam) == "number" then m.cameraID = cam end
	end
	ApplyCam(m)
	if pending then Request(g.first) end
	return pending
end

-------------------------------------------------------------------------------
-- 창
-------------------------------------------------------------------------------
local function Panel(f)
	f.bg = Ink:Round(f, "BACKGROUND", false, false, -8)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.97)
	f.bd = Ink:Round(f, "BORDER", false, true, -8)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.08)
	f.accent = f:CreateTexture(nil, "ARTWORK")
	f.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	f.accent:SetSize(26, 2)
	f.accent:SetPoint("TOPLEFT", 16, -1)
end

local function TextButton(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h or 22)
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(1, 1, 1, 0.05)
	b.label = Ink:Text(b, F.semi, 11, C.soft, "CENTER")
	b.label:SetPoint("CENTER", 0, 0)
	b.label:SetText(text)
	b:SetScript("OnClick", onClick)
	-- 화살표: 글자(‹ ›) 대신 그림 · 글꼴에 따라 □ 로 깨지지 않게 (SettingsSheet 와 같은 방식)
	if text == "<" or text == ">" then
		b.label:SetText("")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetTexture(Ink.icon("Chevron"))
		b.icon:SetSize(14, 14)
		b.icon:SetPoint("CENTER", 0, 0)
		b.icon:SetRotation(text == "<" and -math.pi / 2 or math.pi / 2)
		b.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3])
	end
	b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.1) end)
	b:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, self.on and 0.12 or 0.05) end)
	function b:SetOn(on)
		self.on = on
		self.bg:SetVertexColor(on and C.accent[1] or 1, on and C.accent[2] or 1, on and C.accent[3] or 1, on and 0.16 or 0.05)
		local c = on and C.accent or C.soft
		self.label:SetTextColor(c[1], c[2], c[3])
	end
	return b
end

-- 즐겨찾기 별 단추: 빈 별(흐리게) = 아님 · 금색 별 = 즐겨찾기 · 격자 칸 모델보다 위에
function M.SetStar(b)
	if b.on then
		b.icon:SetTexture(Ink.icon("Star"))
		b.icon:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	else
		b.icon:SetTexture(Ink.icon("StarLine"))
		local p = b:GetParent()
		b.icon:SetVertexColor(1, 1, 1, b.hot and 1 or ((p and p.hover) and 0.75 or (b.dim or 0.3)))
	end
end

local function StarButton(parent, size, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b:SetFrameLevel((parent:GetFrameLevel() or 1) + 8)
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetSize(size - 7, size - 7)
	b.icon:SetPoint("CENTER", 0, 0)
	b:SetScript("OnEnter", function(self)
		self.hot = true
		M.SetStar(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.on and "즐겨찾기에서 빼기" or "즐겨찾기에 넣기", 1, 1, 1)
		if self.hint then GameTooltip:AddLine(self.hint, 0.55, 0.58, 0.62) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self) self.hot = nil; M.SetStar(self); GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self, ...)
		onClick(self, ...)
		if self.hot then self:GetScript("OnEnter")(self) end
	end)
	return b
end

function M:PaintStar(c)
	local b = c.star
	if not b then return end
	b:SetShown(c.g ~= nil)
	if c.g then b.on = M.IsFav(c.g); M.SetStar(b) end
end

local function PaintSelStar(f, g)
	local b = f.selStar
	if not b then return end
	b:SetShown(g ~= nil)
	if g then b.on = M.IsFav(g); M.SetStar(b) end
end

function M:PaintFav()
	local f = self.frame
	if not f then return end
	for _, c in ipairs(f.cells) do self:PaintStar(c) end
	PaintSelStar(f, self.sel)
	local n = M.FavCount()
	f.favBtn.n:SetText(n > 0 and tostring(n) or "")
end

function M:SavePos()
	local f = self.frame
	if not (f and f:GetLeft()) then return end
	local s = f:GetEffectiveScale()
	Ink.db.wardPos = { math.floor(f:GetLeft() * s + 0.5), math.floor(f:GetTop() * s + 0.5) }
end

function M:PlaceFrame()
	local f, p = self.frame, Ink.db.wardPos
	f:ClearAllPoints()
	if p then
		local s = f:GetEffectiveScale()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1] / s, p[2] / s)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
end

function M:Build()
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "FOAWardrobe", UIParent)
	f:SetSize(W, H)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:Hide()
	Panel(f)
	self.frame = f
	if UISpecialFrames then table.insert(UISpecialFrames, "FOAWardrobe") end
	-- 제목 줄 (끌어서 옮기기)
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", -40, 0)
	bar:SetHeight(40)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		local Mv = Ink.modules.Mover
		if Mv and Mv.DragStart then Mv.DragStart(f, function() M:SavePos() end) else f:StartMoving() end
	end)
	bar:SetScript("OnDragStop", function()
		local Mv = Ink.modules.Mover
		if Mv and Mv.DragStop and Mv.Dragging and Mv.Dragging(f) then Mv.DragStop() else f:StopMovingOrSizing(); M:SavePos() end
	end)
	f.title = Ink:Text(f, F.bold, 15, C.text, "LEFT")
	f.title:SetPoint("TOPLEFT", 16, -14)
	f.title:SetText("외형 도감")
	f.sub = Ink:Text(f, F.sans, 10, C.muted, "LEFT")
	f.sub:SetPoint("LEFT", f.title, "RIGHT", 10, -1)
	f.sub:SetText("포에버에서 얻을 수 있는 장비 외형 · 어디서 나오는지 · 입어 보기")
	f.close = CreateFrame("Button", nil, f)
	f.close:SetSize(24, 24)
	f.close:SetPoint("TOPRIGHT", -10, -10)
	f.close.x = Ink:Text(f.close, F.semi, 14, C.muted, "CENTER")
	f.close.x:SetPoint("CENTER", 0, 1)
	f.close.x:SetText("×")
	f.close:SetScript("OnClick", function() f:Hide() end)
	f.close:SetScript("OnEnter", function(self) self.x:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
	f.close:SetScript("OnLeave", function(self) self.x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)

	-- 왼쪽 맨 위: 즐겨찾기 탭 (부위 상관없이 모아 보기)
	local fb = CreateFrame("Button", nil, f)
	fb:SetSize(LEFT_W, 26)
	fb:SetPoint("TOPLEFT", 12, -50)
	fb.hl = Ink:Round(fb, "BACKGROUND", true, false)
	fb.hl:SetAllPoints()
	fb.hl:SetVertexColor(1, 1, 1, 0)
	fb.icon = fb:CreateTexture(nil, "ARTWORK")
	fb.icon:SetTexture(Ink.icon("Star"))
	fb.icon:SetSize(13, 13)
	fb.icon:SetPoint("LEFT", 10, 0)
	fb.icon:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
	fb.label = Ink:Text(fb, F.semi, 12, C.text, "LEFT")
	fb.label:SetPoint("LEFT", 29, 0)
	fb.label:SetText("즐겨찾기")
	fb.n = Ink:Text(fb, F.num, 11, C.muted, "RIGHT")
	fb.n:SetPoint("RIGHT", -10, 0)
	fb:SetScript("OnClick", function() M.fav = true; M.page = 1; M:Refresh() end)
	fb:SetScript("OnEnter", function(self) if not M.fav then self.hl:SetVertexColor(1, 1, 1, 0.05) end end)
	fb:SetScript("OnLeave", function(self) if not M.fav then self.hl:SetVertexColor(1, 1, 1, 0) end end)
	f.favBtn = fb
	f.favSep = f:CreateTexture(nil, "ARTWORK")
	f.favSep:SetColorTexture(1, 1, 1, 0.06)
	f.favSep:SetHeight(1)
	f.favSep:SetPoint("TOPLEFT", 20, -83)
	f.favSep:SetPoint("TOPRIGHT", f, "TOPLEFT", 4 + LEFT_W, -83)

	-- 왼쪽: 부위
	local function SlotOn(i) return not M.fav and (M.slot or 1) == i end
	f.slots = {}
	for i, s in ipairs(SLOTS) do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(LEFT_W, 26)
		b:SetPoint("TOPLEFT", 12, -92 - (i - 1) * 28 - (i > 9 and 10 or 0))
		b.hl = Ink:Round(b, "BACKGROUND", true, false)
		b.hl:SetAllPoints()
		b.hl:SetVertexColor(1, 1, 1, 0)
		b.label = Ink:Text(b, F.semi, 12, C.text, "LEFT")
		b.label:SetPoint("LEFT", 10, 0)
		b.label:SetText(s.ko)
		b:SetScript("OnClick", function() M.slot = i; M.fav = false; M.page = 1; M:Refresh() end)
		b:SetScript("OnEnter", function(self) if not SlotOn(i) then self.hl:SetVertexColor(1, 1, 1, 0.05) end end)
		b:SetScript("OnLeave", function(self) if not SlotOn(i) then self.hl:SetVertexColor(1, 1, 1, 0) end end)
		f.slots[i] = b
	end
	f.sep = f:CreateTexture(nil, "ARTWORK")
	f.sep:SetColorTexture(1, 1, 1, 0.06)
	f.sep:SetWidth(1)
	f.sep:SetPoint("TOPLEFT", 12 + LEFT_W + 6, -48)
	f.sep:SetPoint("BOTTOMLEFT", 12 + LEFT_W + 6, 14)

	-- 위: 획득처 칩 · 내 직업 · 검색
	local gx = 16 + LEFT_W + 12
	f.kinds = {}
	local x = gx
	for i, k in ipairs(KINDS) do
		local w = (#k[2] > 6) and 74 or 48
		local b = TextButton(f, k[2], w, 22, function() M.kind = k[1]; M.page = 1; M:Refresh() end)
		b:SetPoint("TOPLEFT", x, -48)
		b.kind = k[1]
		x = x + w + 4
		f.kinds[i] = b
	end
	f.mine = TextButton(f, "내 직업", 58, 22, function() M.mine = not (M.mine ~= false); M.page = 1; M:Refresh() end)
	f.mine:SetPoint("TOPLEFT", x + 8, -48)
	-- 즐겨찾기 탭에선 획득처 칩 · 내 직업 대신 안내 한 줄 (부위 · 획득처 상관없이 모두)
	f.favNote = Ink:Text(f, F.sans, 11, C.soft, "LEFT")
	f.favNote:SetPoint("LEFT", f, "TOPLEFT", gx + 2, -59)
	f.favNote:SetText("부위 · 획득처 상관없이 즐겨찾기한 외형을 모아 봐요")
	f.favNote:Hide()
	f.search = CreateFrame("EditBox", nil, f)
	f.search:SetSize(120, 22)
	f.search:SetPoint("TOPLEFT", f.mine, "TOPRIGHT", 8, 0)
	f.search:SetAutoFocus(false)
	f.search:SetFont(F.sans, 11, "")
	f.search:SetTextColor(C.text[1], C.text[2], C.text[3])
	f.search:SetTextInsets(8, 8, 0, 0)
	f.search.bg = Ink:Round(f.search, "BACKGROUND", true, false)
	f.search.bg:SetAllPoints()
	f.search.bg:SetVertexColor(1, 1, 1, 0.05)
	f.search.ph = Ink:Text(f.search, F.sans, 10, C.dim, "LEFT")
	f.search.ph:SetPoint("LEFT", 8, 0)
	f.search.ph:SetText("이름 검색")
	f.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	f.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.search:SetScript("OnTextChanged", function(self)
		local t = self:GetText() or ""
		self.ph:SetShown(t == "")
		M.query = t:lower()
		M.page = 1
		if M.searchPend then return end
		M.searchPend = true
		C_Timer.After(0.25, function() M.searchPend = nil; M:Refresh() end)
	end)

	-- 격자
	f.cells = {}
	for i = 1, PAGE do
		local c = CreateFrame("Button", nil, f)
		c:SetSize(CELL_W, CELL_H)
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		c:SetPoint("TOPLEFT", gx + col * (CELL_W + 6), -80 - row * (CELL_H + 8))
		c.bg = Ink:Round(c, "BACKGROUND", true, false)
		c.bg:SetAllPoints()
		c.bg:SetVertexColor(1, 1, 1, 0.03)
		c.bd = Ink:Round(c, "BORDER", true, true)
		c.bd:SetAllPoints()
		c.bd:SetVertexColor(1, 1, 1, 0.06)
		c.model = NewModel(c, true)
		if c.model then
			c.model:SetPoint("TOPLEFT", 4, -4)
			c.model:SetSize(CELL_W - 8, MODEL_H)
			c.model:EnableMouse(false)
		end
		c.name = Ink:Text(c, F.semi, 11, C.text, "LEFT")
		c.name:SetPoint("TOPLEFT", 8, -(MODEL_H + 8))
		c.name:SetWidth(CELL_W - 16)
		c.src = Ink:Text(c, F.sans, 9, C.muted, "LEFT")
		c.src:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
		c.src:SetWidth(CELL_W - 16)
		c.badge = Ink:Text(c, F.semi, 10, C.accent, "LEFT")
		c.badge:SetPoint("TOPLEFT", 8, -7)
		-- 오른쪽 위: [+n] [가진 외형 ✓] [즐겨찾기 별]
		c.have = c:CreateTexture(nil, "OVERLAY")
		c.have:SetTexture(Ink.icon("Check"))
		c.have:SetSize(16, 16)
		c.have:SetPoint("TOPRIGHT", -27, -6)
		c.have:SetVertexColor(C.green[1], C.green[2], C.green[3])
		c.have:Hide()
		c.more = Ink:Text(c, F.semi, 9, C.soft, "RIGHT")
		c.more:SetPoint("TOPRIGHT", -29, -7)
		c.star = StarButton(c, 22, function(self) M:ToggleFav(c.g) end)
		c.star:SetPoint("TOPRIGHT", -3, -3)
		c.star.hint = "칸을 오른쪽 클릭해도 돼요"
		c:SetScript("OnEnter", function(self) self.hover = true; M:CellTip(self); M:PaintStar(self) end)
		c:SetScript("OnLeave", function(self)
			self.hover = nil
			self.bd:SetVertexColor(1, 1, 1, M.selKey == self.key and 0.5 or 0.06)
			GameTooltip:Hide()
			M:PaintStar(self)
		end)
		c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		c:SetScript("OnClick", function(self, btn)
			if not self.g then return end
			-- 오른쪽 클릭 = 즐겨찾기 넣기 · 빼기
			if btn == "RightButton" then M:ToggleFav(self.g) return end
			local link = select(2, C_Item.GetItemInfo(self.g.first))
			if link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(link) return end
			M:Select(self.g)
		end)
		c:EnableMouseWheel(true)
		c:SetScript("OnMouseWheel", function(_, d) M:Turn(-d) end)
		f.cells[i] = c
	end
	f.empty = Ink:Text(f, F.sans, 11, C.muted, "CENTER")
	f.empty:SetPoint("TOP", f, "TOPLEFT", gx + (COLS * (CELL_W + 6)) / 2, -220)
	f.empty:SetWidth(COLS * (CELL_W + 6) - 20)
	f.empty:SetWordWrap(true)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, d) M:Turn(-d) end)
	-- 쪽 넘기기
	f.prev = TextButton(f, "<", 28, 22, function() M:Turn(-1) end)
	f.next = TextButton(f, ">", 28, 22, function() M:Turn(1) end)
	f.pageText = Ink:Text(f, F.num, 12, C.soft, "CENTER")
	local midX = gx + (COLS * (CELL_W + 6) - 6) / 2
	f.pageText:SetPoint("BOTTOM", f, "BOTTOMLEFT", midX, 22)
	f.prev:SetPoint("RIGHT", f.pageText, "LEFT", -12, 0)
	f.next:SetPoint("LEFT", f.pageText, "RIGHT", 12, 0)
	f.count = Ink:Text(f, F.sans, 10, C.dim, "LEFT")
	f.count:SetPoint("BOTTOMLEFT", gx, 26)

	-- 오른쪽: 미리보기 (지금 내 장비 위에 입혀 보기)
	local px = W - 16 - PREV_W
	f.psep = f:CreateTexture(nil, "ARTWORK")
	f.psep:SetColorTexture(1, 1, 1, 0.06)
	f.psep:SetWidth(1)
	f.psep:SetPoint("TOPLEFT", px - 8, -48)
	f.psep:SetPoint("BOTTOMLEFT", px - 8, 14)
	local pv = CreateFrame("Frame", nil, f)
	pv:SetPoint("TOPLEFT", px, -48)
	pv:SetSize(PREV_W, 336)
	pv.bg = Ink:Round(pv, "BACKGROUND", true, false)
	pv.bg:SetAllPoints()
	pv.bg:SetVertexColor(1, 1, 1, 0.03)
	pv.model = NewModel(pv)
	if pv.model then
		local m = pv.model
		m:SetAllPoints()
		m:EnableMouse(true)
		m:EnableMouseWheel(true)
		m.zoom, m.px, m.py = 0, 0, 0
		m:SetScript("OnMouseDown", function(self, btn)
			self.dragBtn = btn
			self.lastX, self.lastY = GetCursorPosition()
		end)
		m:SetScript("OnMouseUp", function(self) self.dragBtn = nil end)
		m:SetScript("OnHide", function(self) self.dragBtn = nil end)
		m:SetScript("OnUpdate", function(self)
			if not self.dragBtn then return end
			local cx, cy = GetCursorPosition()
			local dx, dy = cx - (self.lastX or cx), cy - (self.lastY or cy)
			self.lastX, self.lastY = cx, cy
			if self.dragBtn == "LeftButton" then
				self.facing = (self.facing or 0) + dx * 0.012
				pcall(self.SetFacing, self, self.facing)
			else
				local s = self:GetEffectiveScale() * 120
				self.py, self.pz = (self.py or 0) + dx / s, (self.pz or 0) + dy / s
				pcall(self.SetPosition, self, 0, self.py, self.pz)
			end
		end)
		m:SetScript("OnMouseWheel", function(self, d)
			self.zoom = math.max(0, math.min(0.75, (self.zoom or 0) + d * 0.08))
			pcall(self.SetPortraitZoom, self, self.zoom)
		end)
		m:SetScript("OnModelLoaded", function(self)
			pcall(self.SetFacing, self, self.facing or 0)
			-- 모델을 다 불러온 뒤에 내 장비를 다시 (불러오기 전에 입힌 건 사라질 수 있다)
			if self.needDress then self.needDress = nil; M:DressMine() end
		end)
	end
	pv.hint = Ink:Text(pv, F.sans, 9, C.dim, "CENTER")
	pv.hint:SetPoint("BOTTOM", 0, 6)
	pv.hint:SetText("끌기 돌리기 · 휠 확대 · 오른쪽 끌기 이동")
	f.pv = pv
	-- 미리보기 단추
	local bw = math.floor((PREV_W - 8) / 3)
	f.bDress = TextButton(f, "내 장비", bw, 22, function() M:ResetPreview(true) end)
	f.bDress:SetPoint("TOPLEFT", pv, "BOTTOMLEFT", 0, -6)
	f.bUndress = TextButton(f, "벗기", bw, 22, function() M:Undress() end)
	f.bUndress:SetPoint("LEFT", f.bDress, "RIGHT", 4, 0)
	f.bBis = TextButton(f, "BIS 입기", bw, 22, function() M:WearBis() end)
	f.bBis:SetPoint("LEFT", f.bUndress, "RIGHT", 4, 0)
	-- 고른 외형 정보
	f.selName = Ink:Text(f, F.bold, 13, C.text, "LEFT")
	f.selName:SetPoint("TOPLEFT", f.bDress, "BOTTOMLEFT", 0, -12)
	f.selName:SetWidth(PREV_W - 28)
	f.selStar = StarButton(f, 24, function() M:ToggleFav(M.sel) end)
	f.selStar.dim = 0.55
	f.selStar:SetPoint("TOPRIGHT", f.bBis, "BOTTOMRIGHT", 3, -6)
	f.selStar:Hide()
	f.selInfo = Ink:Text(f, F.sans, 10, C.soft, "LEFT")
	f.selInfo:SetPoint("TOPLEFT", f.selName, "BOTTOMLEFT", 0, -6)
	f.selInfo:SetWidth(PREV_W)
	f.selInfo:SetWordWrap(true)
	f.selInfo:SetJustifyV("TOP")
	f.selInfo:SetHeight(150)

	f:SetScript("OnShow", function() M:PlaceFrame(); M:Refresh(); M:ResetPreview(false) end)
	f:SetScript("OnHide", function() GameTooltip:Hide() end)
	-- 아이템 이름 · 퀘스트 이름이 도착하면 보이는 칸 글자만 다시
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	ev:RegisterEvent("ITEM_DATA_LOAD_RESULT")
	ev:RegisterEvent("QUEST_DATA_LOAD_RESULT")
	local arrived = {}
	ev:SetScript("OnEvent", function(_, event, id)
		if not f:IsShown() then return end
		if event ~= "QUEST_DATA_LOAD_RESULT" and id then arrived[id] = true end
		if M.textPend then return end
		M.textPend = true
		C_Timer.After(0.3, function()
			M.textPend = nil
			if not f:IsShown() then wipe(arrived) return end
			local slot = SLOTS[M.slot or 1]
			for _, c in ipairs(f.cells) do
				if c.pend and arrived[c.pend] and c.g then c.pend = ShowInCell(c.model, c.g, c.slotDef or slot) and c.g.first or nil end
			end
			if M.prevPend and arrived[M.prevPend] then local pid = M.prevPend; M.prevPend = nil; M:TryOn(pid) end
			wipe(arrived)
			M:PaintText()
		end)
	end)
	return f
end

-------------------------------------------------------------------------------
-- 그리기
-------------------------------------------------------------------------------
function M:Turn(d)
	local n = math.max(1, math.ceil(#(self.groups or {}) / PAGE))
	local p = math.max(1, math.min(n, (self.page or 1) + d))
	if p ~= self.page then self.page = p; self:Paint() end
end

function M:Refresh()
	if not (self.frame and self.frame:IsShown()) then return end
	self:List()
	self:Paint()
end

-- 칸 글자 (이름 · 획득처) · 이름이 아직 안 왔으면 받아 오기
function M:PaintText()
	local f = self.frame
	for _, c in ipairs(f.cells) do
		local g = c.g
		if g then
			local id = g.first
			local n = ItemName(id)
			if not n then Request(id) end
			local q = n and (QCOL[Quality(id) or 1] or QCOL[1]) or C.dim
			c.name:SetText(n or "불러오는 중…")
			c.name:SetTextColor(q[1], q[2], q[3])
			local e = self.items[id]
			-- 즐겨찾기 탭은 부위가 섞여 있어서 획득처 앞에 부위 이름
			local pre = (self.fav and c.slotDef) and ("|cffC9CDD4" .. c.slotDef.ko .. "|r · ") or ""
			c.src:SetText(pre .. (e and e.src[1] and SrcText(e.src[1]) or ""))
		end
	end
	if self.sel then self:PaintSel() end
end

function M:Paint()
	local f = self.frame
	if not f then return end
	local slot = SLOTS[self.slot or 1]
	local favMode = self.fav and true or false
	local function Hl(b, on)
		b.hl:SetVertexColor(on and C.accent[1] or 1, on and C.accent[2] or 1, on and C.accent[3] or 1, on and 0.14 or 0)
		local c = on and C.accent or C.text
		b.label:SetTextColor(c[1], c[2], c[3])
	end
	Hl(f.favBtn, favMode)
	for i, b in ipairs(f.slots) do Hl(b, not favMode and i == (self.slot or 1)) end
	for _, b in ipairs(f.kinds) do b:SetOn(b.kind == (self.kind or "all")); b:SetShown(not favMode) end
	f.mine:SetOn(self.mine ~= false)
	f.mine:SetShown(not favMode)
	f.favNote:SetShown(favMode)
	local groups = self.groups or {}
	local n = math.max(1, math.ceil(#groups / PAGE))
	self.page = math.max(1, math.min(n, self.page or 1))
	local off = (self.page - 1) * PAGE
	for i, c in ipairs(f.cells) do
		local g = groups[off + i]
		c.g = g
		if g then
			c.key = g.app and ("a" .. g.app) or ("i" .. g.first)
			c:Show()
			-- 즐겨찾기 탭: 칸마다 그 외형의 부위로 (카메라 · 숨김 장비가 부위마다 다르다)
			local gs = (favMode and SLOTS[g.slot]) or slot
			c.slotDef = gs
			if c.shownKey ~= c.key or c.shownSlot ~= gs.key then
				c.pend = ShowInCell(c.model, g, gs) and g.first or nil
				c.shownKey, c.shownSlot = c.key, gs.key
			end
			c.badge:SetText(g.rank == 0 and "BIS" or (g.rank and ("대체 " .. g.rank)) or "")
			c.more:SetText(#g.ids > 1 and ("+" .. (#g.ids - 1)) or "")
			c.have:SetShown(g.have and true or false)
			c.more:ClearAllPoints()
			c.more:SetPoint("TOPRIGHT", g.have and -45 or -29, -7)
			if c.model then c.model:SetAlpha(1) end
			c.bd:SetVertexColor(1, 1, 1, self.selKey == c.key and 0.5 or 0.06)
		else
			c:Hide()
			c.shownKey = nil
		end
	end
	self:PaintText()
	f.pageText:SetText(self.page .. " / " .. n)
	f.prev:SetShown(n > 1)
	f.next:SetShown(n > 1)
	f.count:SetText(string.format("%s · 외형 %d개 (아이템 %d개) · 가진 외형 %d개", favMode and "즐겨찾기" or slot.ko, #groups, self.nItems or 0, self.nHave or 0))
	f.empty:SetShown(#groups == 0)
	if favMode then
		f.empty:SetText((M.FavCount() > 0 and self.query and self.query ~= "") and "검색어에 맞는 즐겨찾기가 없어요"
			or "아직 즐겨찾기한 외형이 없어요\n칸 오른쪽 위의 별을 누르거나, 칸을 오른쪽 클릭하면 여기에 모여요")
	else
		f.empty:SetText((self.mine ~= false) and "조건에 맞는 장비가 없어요\n'내 직업'을 끄면 다른 직업 장비도 보여요" or "조건에 맞는 장비가 없어요")
	end
	self:PaintFav()
end

local HAVE_TXT = { equipped = "착용 중", bag = "가방에 있음", bank = "은행에 있음", col = "수집품에 모은 외형" }
-- 칸 툴팁: 아이템 툴팁 + 이 외형이 나오는 아이템 · 획득처
function M:CellTip(c)
	local g = c.g
	if not g then return end
	c.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
	GameTooltip:SetOwner(c, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -6, -40)
	GameTooltip:SetItemByID(g.first)
	GameTooltip:AddLine(" ")
	if g.have then GameTooltip:AddLine("가지고 있는 외형 · " .. (HAVE_TXT[g.have] or ""), 0.44, 0.83, 0.6) end
	GameTooltip:AddLine("|cffFFF468FOA|r 획득처", 1, 1, 1)
	local shown = 0
	for _, id in ipairs(g.ids) do
		local e = self.items[id]
		if e and shown < 8 then
			local nm = ItemName(id) or ("#" .. id)
			local q = QCOL[Quality(id) or 1] or QCOL[1]
			if #g.ids > 1 then GameTooltip:AddLine(nm, q[1], q[2], q[3]) end
			for k = 1, math.min(2, #e.src) do
				GameTooltip:AddLine("   " .. SrcText(e.src[k]), 0.75, 0.77, 0.8, true)
			end
			shown = shown + 1
		end
	end
	if #g.ids > shown then GameTooltip:AddLine(string.format("   … 같은 외형 %d개 더", #g.ids - shown), 0.55, 0.58, 0.62) end
	if M.IsFav(g) then GameTooltip:AddLine("즐겨찾기한 외형", C.gold[1], C.gold[2], C.gold[3]) end
	GameTooltip:AddLine("누르면 오른쪽에서 입어 보기 · 오른쪽 클릭 즐겨찾기 · Shift+클릭 채팅 링크", 0.55, 0.58, 0.62, true)
	GameTooltip:Show()
end

-- 미리보기
--  내 장비: 게임의 Dress() 만으로는 맨몸에 무기 · 허리띠만 보이는 일이 있어서(포에버) 보이는 칸을 하나씩 입힌다
local SHOWN_INV = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 15, 19, 16, 17, 18 }
function M:DressMine()
	local m = self.frame and self.frame.pv.model
	if not m then return end
	pcall(m.Undress, m)
	for _, inv in ipairs(SHOWN_INV) do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
		if link then
			if inv == 17 then pcall(m.TryOn, m, link, "SECONDARYHANDSLOT") else pcall(m.TryOn, m, link) end
		end
	end
	if self.sel then self:TryOn(self.sel.first) end
end

function M:ResetPreview(clearSel)
	local m = self.frame and self.frame.pv.model
	if not m then return end
	m.needDress = true
	pcall(m.SetUnit, m, "player")
	pcall(m.SetSheathed, m, false)
	self:DressMine()
	m.facing, m.zoom, m.py, m.pz = 0, 0, 0, 0
	pcall(m.SetFacing, m, 0)
	pcall(m.SetPortraitZoom, m, 0)
	pcall(m.SetPosition, m, 0, 0, 0)
	if clearSel then self.sel, self.selKey = nil, nil; self:PaintSel(); self:Paint(); self:DressMine() end
end

function M:Undress()
	local m = self.frame and self.frame.pv.model
	if not m then return end
	pcall(m.Undress, m)
	if self.sel then self:TryOn(self.sel.first) end
end

function M:TryOn(id)
	local m = self.frame and self.frame.pv.model
	if not m then return end
	local _, src = Appearance(id)
	local ok, r = pcall(m.TryOn, m, src or ("item:" .. id))
	if not ok or r == 3 then ok, r = pcall(m.TryOn, m, "item:" .. id) end
	if r == 3 or not Cached(id) then self.prevPend = id; Request(id) end
end

function M:Select(g)
	self.sel = g
	self.selKey = g and (g.app and ("a" .. g.app) or ("i" .. g.first)) or nil
	if g then self:TryOn(g.first) end
	self:PaintSel()
	if self.frame then
		for _, c in ipairs(self.frame.cells) do c.bd:SetVertexColor(1, 1, 1, (c.g and self.selKey == c.key) and 0.5 or 0.06) end
	end
end

function M:PaintSel()
	local f = self.frame
	local g = self.sel
	PaintSelStar(f, g)
	if not g then
		f.selName:SetText("")
		f.selInfo:SetText("격자에서 외형을 누르면 지금 내 장비 위에 입혀 봐요\nBIS 입기 = 지금 특성 BIS 를 한꺼번에")
		return
	end
	local id = g.first
	local q = QCOL[Quality(id) or 1] or QCOL[1]
	f.selName:SetText(ItemName(id) or "불러오는 중…")
	f.selName:SetTextColor(q[1], q[2], q[3])
	local lines = {}
	if g.have then lines[#lines + 1] = "|cff6FD39A가지고 있는 외형 · " .. (HAVE_TXT[g.have] or "") .. "|r" end
	if g.rank then lines[#lines + 1] = "|cffFFF468" .. (g.rank == 0 and "지금 특성 BIS" or ("지금 특성 대체 " .. g.rank .. "위")) .. "|r" end
	for _, iid in ipairs(g.ids) do
		local e = self.items[iid]
		if e and #lines < 10 then
			local pre = (#g.ids > 1) and ((ItemName(iid) or ("#" .. iid)) .. " · ") or ""
			lines[#lines + 1] = pre .. SrcText(e.src[1] or {})
		end
	end
	f.selInfo:SetText(table.concat(lines, "\n"))
end

-- 지금 특성 BIS 를 한꺼번에 (BIS 창이 매긴 순위 · 보이지 않는 칸은 빼고)
function M:WearBis()
	local Dg = D()
	if Dg and Dg.BuildRanks then pcall(Dg.BuildRanks, Dg) end
	local m = self.frame and self.frame.pv.model
	if not (m and Dg and Dg.ranks) then return end
	pcall(m.Undress, m)
	local n = 0
	for id, r in pairs(Dg.ranks) do
		if r.rank == 0 then
			local _, _, _, loc = C_Item.GetItemInfoInstant(id)
			if loc and SLOT_OF[loc] then self:TryOn(id); n = n + 1 end
		end
	end
	self.sel, self.selKey = nil, nil
	self:Paint()
	local f = self.frame
	f.selName:SetText("지금 특성 BIS 세트")
	f.selName:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	f.selInfo:SetText(n > 0 and (n .. "부위를 입혔어요 (목 · 반지 · 장신구는 보이지 않는 칸)") or "BIS 창에서 특성을 고르면 그 BIS 를 입혀요")
end

-------------------------------------------------------------------------------
-- 바깥에서 여는 곳
-------------------------------------------------------------------------------
function M:Toggle()
	local f = self:Build()
	if f:IsShown() then f:Hide() else f:Show() end
end

function M:Open()
	local f = self:Build()
	if not f:IsShown() then f:Show() end
	return f
end

-- 아이템 하나를 바로: 그 부위 · 그 외형이 있는 쪽으로 가서 입혀 본다 (BIS · 던전 전리품 칸 Ctrl+클릭)
function M:OpenItem(id)
	if not id then return end
	local _, _, _, loc = C_Item.GetItemInfoInstant(id)
	local si = loc and SLOT_OF[loc]
	self.slot = si or self.slot or 1
	self.kind, self.query, self.fav = "all", nil, false
	local f = self:Build()
	if f.search then f.search:SetText("") end
	self.page = 1
	if not f:IsShown() then f:Show() else self:Refresh() end
	local want = Appearance(id)
	for i, g in ipairs(self.groups or {}) do
		local hit = (want and g.app == want)
		if not hit then for _, x in ipairs(g.ids) do if x == id then hit = true end end end
		if hit then
			self.page = math.floor((i - 1) / PAGE) + 1
			self:Paint()
			self:Select(g)
			return
		end
	end
	-- 도감 목록에 없는 아이템(내 직업 아님 등)도 미리보기에는 입혀 본다
	self:Select({ first = id, ids = { id }, app = want })
end

-- 외형이 보이는 칸의 아이템인가 (목 · 반지 · 장신구 · 성물은 아님)
function M.CanShow(id)
	if not id then return false end
	local _, _, _, loc = C_Item.GetItemInfoInstant(id)
	return loc and SLOT_OF[loc] ~= nil or false
end

function M:Init()
	if not FOREVER then return end
	SLASH_FOAWARDROBE1 = "/외형도감"
	SLASH_FOAWARDROBE2 = "/foaw"
	SlashCmdList.FOAWARDROBE = function() M:Toggle() end
end
