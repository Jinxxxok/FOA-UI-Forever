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
-- 대도시 주요 NPC (대표만 하나씩)
--  비행 · 전문기술 상급자: AllTheThings 포에버 자료(MIT) / 연금술: warcraft.wiki.gg / 직업 상급자: 워크래프트 태번 포에버 가이드
--  은행 · 경매장 · 여관 · 우편함 · 수리는 한 번 들르면 그 자리를 기억해서 채운다 (들른 자리가 위 자료보다 우선)
-------------------------------------------------------------------------------
local CAPITAL = { [1453] = 2, [1455] = 2, [1457] = 2, [1454] = 1, [1458] = 1, [1456] = 1 }
local PROF_KO = { p171 = "연금술", p164 = "대장기술", p165 = "가죽세공", p197 = "재봉술", p202 = "기계공학", p333 = "마법부여",
	p182 = "약초채집", p186 = "채광", p393 = "무두질", p185 = "요리", p129 = "응급치료", p356 = "낚시" }
local CITY = {
	[1453] = { flight = { 71, 72.5 }, p171 = { 55.6, 85.9 }, p164 = { 64, 37.2 }, p185 = { 78.2, 53 }, p333 = { 53, 73.8 }, p202 = { 62.2, 30.6 },
		p129 = { 52.8, 44.8 }, p356 = { 55, 69.6 }, p182 = { 44.8, 77 }, p165 = { 72.4, 62.2 }, p186 = { 59.2, 37.6 }, p393 = { 72.6, 62 }, p197 = { 53.2, 81.6 },
		c11 = { 34.3, 65.1 }, c3 = { 67.4, 36.3 }, c8 = { 48.3, 87.3 }, c2 = { 49.5, 49.7 }, c5 = { 50.8, 44.9 }, c4 = { 80.3, 68.7 }, c9 = { 39.4, 85.0 }, c1 = { 80.2, 61.6 } },
	[1454] = { flight = { 45.2, 63.8 }, p171 = { 55.7, 45.8 }, p164 = { 79.6, 23.6 }, p185 = { 57.4, 53.6 }, p333 = { 53.8, 38.6 }, p202 = { 75.8, 25.2 },
		p129 = { 34, 84.4 }, p356 = { 66.6, 41.6 }, p182 = { 55.6, 39.6 }, p165 = { 63.2, 44.4 }, p186 = { 73, 27 }, p393 = { 63.2, 45.2 }, p197 = { 63.6, 50 },
		c3 = { 66.2, 18.6 }, c8 = { 38.6, 86.0 }, c5 = { 35.6, 87.6 }, c4 = { 42.8, 51.6 }, c7 = { 38.8, 36.6 }, c9 = { 48.0, 46.8 }, c1 = { 79.6, 31.6 } },
	[1455] = { flight = { 55.6, 48 }, p164 = { 52.6, 40.8 }, p202 = { 68.8, 45.2 }, p171 = { 66.6, 55.2 },
		c3 = { 71.6, 88.8 }, c8 = { 27.0, 8.2 }, c2 = { 24.8, 6.2 }, c5 = { 25.4, 8.4 }, c4 = { 52.0, 13.6 }, c7 = { 47.3, 13.5 }, c9 = { 50.8, 6.4 }, c1 = { 66.8, 87.6 } },
	[1456] = { flight = { 46.8, 50 }, p165 = { 41.8, 42.6 }, p171 = { 46.8, 33.5 },
		c11 = { 77.6, 29.0 }, c3 = { 57.6, 88.6 }, c8 = { 22.6, 15.8 }, c5 = { 25.8, 22.0 }, c7 = { 22.8, 19.4 }, c1 = { 57.8, 85.4 } },
	-- 다르나서스: 직업 상급자 (와우헤드 불성 클래식 다르나서스 상급자 안내 · 같은 자리) / 전문기술 상급자 (장인의 정원 등)
	[1457] = { bank = { 40.0, 42.0 }, auction = { 55.0, 58.5 }, inn = { 62.5, 29.8 }, mail = { 44.9, 47.7 }, flight = { 36.6, 44.8 },
		p171 = { 54.9, 24.0 }, p165 = { 64.4, 21.5 }, p393 = { 64.1, 22.3 }, p333 = { 58.4, 13.1 }, p197 = { 63.8, 22.1 }, p182 = { 47.9, 68.0 },
		p129 = { 54.5, 23.4 }, p185 = { 49.0, 21.2 }, p356 = { 47.9, 56.7 }, p164 = { 57.0, 50.0 },
		c11 = { 34.8, 7.4 }, c3 = { 40.4, 8.6 }, c5 = { 39.5, 81.2 }, c4 = { 37.0, 21.9 }, c1 = { 58.7, 34.9 } },
	[1458] = { 74.0, 32.4, "오웬 사드", "사서 · 호드 — 마법 지구, 계산대 뒤", 1 },
}
local REWARDS = { { 10, "목걸이" }, { 20, "반지" }, { 25, "활 · 방패 · 보조장비" } }
local BOOK = { 0.79, 0.66, 1.00 }      -- 보라
local BOOK_DONE = { 0.44, 0.83, 0.60 } -- 초록


-------------------------------------------------------------------------------
-- 대도시 주요 NPC (대표만 하나씩)
--  비행 · 전문기술 상급자: AllTheThings 포에버 자료(MIT) / 연금술: warcraft.wiki.gg / 직업 상급자: 워크래프트 태번 포에버 가이드
--  은행 · 경매장 · 여관 · 우편함 · 수리는 한 번 들르면 그 자리를 기억해서 채운다 (들른 자리가 위 자료보다 우선)
-------------------------------------------------------------------------------
local CAPITAL = { [1453] = 2, [1455] = 2, [1457] = 2, [1454] = 1, [1458] = 1, [1456] = 1 }
local PROF_KO = { p171 = "연금술", p164 = "대장기술", p165 = "가죽세공", p197 = "재봉술", p202 = "기계공학", p333 = "마법부여",
	p182 = "약초채집", p186 = "채광", p393 = "무두질", p185 = "요리", p129 = "응급치료", p356 = "낚시" }
local CITY = {
	[1453] = { flight = { 71, 72.5 }, p171 = { 55.6, 85.9 }, p164 = { 64, 37.2 }, p185 = { 78.2, 53 }, p333 = { 53, 73.8 }, p202 = { 62.2, 30.6 },
		p129 = { 52.8, 44.8 }, p356 = { 55, 69.6 }, p182 = { 44.8, 77 }, p165 = { 72.4, 62.2 }, p186 = { 59.2, 37.6 }, p393 = { 72.6, 62 }, p197 = { 53.2, 81.6 },
		c11 = { 34.3, 65.1 }, c3 = { 67.4, 36.3 }, c8 = { 48.3, 87.3 }, c2 = { 49.5, 49.7 }, c5 = { 50.8, 44.9 }, c4 = { 80.3, 68.7 }, c9 = { 39.4, 85.0 }, c1 = { 80.2, 61.6 } },
	[1454] = { flight = { 45.2, 63.8 }, p171 = { 55.7, 45.8 }, p164 = { 79.6, 23.6 }, p185 = { 57.4, 53.6 }, p333 = { 53.8, 38.6 }, p202 = { 75.8, 25.2 },
		p129 = { 34, 84.4 }, p356 = { 66.6, 41.6 }, p182 = { 55.6, 39.6 }, p165 = { 63.2, 44.4 }, p186 = { 73, 27 }, p393 = { 63.2, 45.2 }, p197 = { 63.6, 50 },
		c3 = { 66.2, 18.6 }, c8 = { 38.6, 86.0 }, c5 = { 35.6, 87.6 }, c4 = { 42.8, 51.6 }, c7 = { 38.8, 36.6 }, c9 = { 48.0, 46.8 }, c1 = { 79.6, 31.6 } },
	[1455] = { flight = { 55.6, 48 }, p164 = { 52.6, 40.8 }, p202 = { 68.8, 45.2 }, p171 = { 66.6, 55.2 },
		c3 = { 71.6, 88.8 }, c8 = { 27.0, 8.2 }, c2 = { 24.8, 6.2 }, c5 = { 25.4, 8.4 }, c4 = { 52.0, 13.6 }, c7 = { 47.3, 13.5 }, c9 = { 50.8, 6.4 }, c1 = { 66.8, 87.6 } },
	[1456] = { flight = { 46.8, 50 }, p165 = { 41.8, 42.6 }, p171 = { 46.8, 33.5 },
		c11 = { 77.6, 29.0 }, c3 = { 57.6, 88.6 }, c8 = { 22.6, 15.8 }, c5 = { 25.8, 22.0 }, c7 = { 22.8, 19.4 }, c1 = { 57.8, 85.4 } },
	[1457] = { bank = { 40.0, 42.0 }, auction = { 55.0, 58.5 }, inn = { 62.5, 29.8 }, mail = { 44.9, 47.7 }, flight = { 36.6, 44.8 },
		p164 = { 57.0, 50.0 }, p171 = { 55.0, 23.8 }, p165 = { 64.6, 21.6 },
		c11 = { 34.8, 8.6 }, c3 = { 42.2, 7.6 }, c5 = { 38.6, 82.0 }, c4 = { 38.8, 21.2 }, c1 = { 58.6, 35.6 } },
	[1458] = { flight = { 63.6, 48.6 }, p171 = { 47.7, 73.0 }, p197 = { 70.8, 29.2 },
		c8 = { 85.0, 10.2 }, c5 = { 49.6, 17.2 }, c4 = { 83.8, 71.6 }, c9 = { 86.0, 15.6 }, c1 = { 48.2, 15.6 } },
}
local CLASS_KO = { c1 = "전사", c2 = "성기사", c3 = "사냥꾼", c4 = "도적", c5 = "사제", c7 = "주술사", c8 = "마법사", c9 = "흑마법사", c11 = "드루이드" }

-- 훈련사 직함 → 대표 열쇠 (수습 · 숙련 · 전문 · 대가 대장장이 → p164 하나로)
local PROF_WORD = {
	{ "연금술", "p171" }, { "대장", "p164" }, { "가죽세공", "p165" }, { "재봉", "p197" }, { "기계공학", "p202" }, { "마법부여", "p333" },
	{ "약초", "p182" }, { "채광", "p186" }, { "광부", "p186" }, { "무두", "p393" }, { "요리", "p185" }, { "응급치료", "p129" }, { "낚시", "p356" },
	{ "Alchem", "p171" }, { "Blacksmith", "p164" }, { "Leatherwork", "p165" }, { "Tailor", "p197" }, { "Engineer", "p202" }, { "Enchant", "p333" },
	{ "Herbalis", "p182" }, { "Mining", "p186" }, { "Miner", "p186" }, { "Skinn", "p393" }, { "Cook", "p185" }, { "First Aid", "p129" }, { "Fish", "p356" },
}
local CLASS_WORD = {
	{ "흑마법사", "c9" }, { "마법사", "c8" }, { "전사", "c1" }, { "성기사", "c2" }, { "사냥꾼", "c3" }, { "도적", "c4" }, { "사제", "c5" },
	{ "주술사", "c7" }, { "드루이드", "c11" },
	{ "Warlock", "c9" }, { "Mage", "c8" }, { "Warrior", "c1" }, { "Paladin", "c2" }, { "Hunter", "c3" }, { "Rogue", "c4" }, { "Priest", "c5" },
	{ "Shaman", "c7" }, { "Druid", "c11" },
}
local function TrainerKey(sub)
	if type(sub) ~= "string" then return end
	for _, w in ipairs(CLASS_WORD) do if sub:find(w[1], 1, true) then return w[2] end end
	for _, w in ipairs(PROF_WORD) do if sub:find(w[1], 1, true) then return w[2] end end
end
M.TrainerKey = TrainerKey
local KEY_ROLE = { flight = "flight", bank = "bank", auction = "auction", inn = "inn", mail = "mail", repair = "repair" }
local KEY_LABEL = { flight = "비행", bank = "은행", auction = "경매장", inn = "여관", mail = "우편함", repair = "수리" }
local function KeyLabel(k) return KEY_LABEL[k] or PROF_KO[k] or (CLASS_KO[k] and (CLASS_KO[k] .. " 상급자")) or k end
local function KeyRole(k) return KEY_ROLE[k] or "trainer" end

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

-------------------------------------------------------------------------------
-- 대도시 · 비행 핀 모양
--  서비스(은행 · 경매장 · 여관 · 우편 · 비행 · 수리): 각자 색과 아이콘 + 이름 알약
--  전문기술 상급자: 그 전문기술의 게임 아이콘(동그랗게) + 보라 테두리
--  직업 상급자: 직업 문양 + 직업 색 테두리
--  가까이 겹치면 살짝 벌려서 놓는다
-------------------------------------------------------------------------------
local SVC = {
	bank = { "NpcBank", "E3C07A", "은행" }, auction = { "NpcAuction", "F2A84E", "경매장" }, inn = { "NpcInn", "F59E6B", "여관" },
	mail = { "NpcMail", "7FB8FF", "우편함" }, flight = { "NpcFlight", "86DDF2", "비행" }, repair = { "NpcRepair", "C9CED6", "수리" },
}
for _, v in pairs(SVC) do v.rgb = Ink.hex(v[2]) end
local PROF_ICON = { p171 = 136240, p164 = 136241, p202 = 136243, p333 = 136244, p356 = 136245, p182 = 136246,
	p165 = 136247, p186 = 136248, p197 = 136249, p393 = 134366, p185 = 133971, p129 = 135966 }
local CLASS_TOKEN = { c1 = "WARRIOR", c2 = "PALADIN", c3 = "HUNTER", c4 = "ROGUE", c5 = "PRIEST", c7 = "SHAMAN", c8 = "MAGE", c9 = "WARLOCK", c11 = "DRUID" }
local PROF_RING = { 0.79, 0.66, 1.00 }
local FLIGHT_OFF = { 0.55, 0.57, 0.60 }

function M:CityPin(i)
	self.cityPins = self.cityPins or {}
	local p = self.cityPins[i]
	if p then return p end
	p = CreateFrame("Button", nil, self.layer)
	p:SetSize(24, 24)
	p.art = CreateFrame("Frame", nil, p)
	p.art:SetPoint("CENTER")
	p.art:SetSize(24, 24)
	p.art:EnableMouse(false)
	local a = p.art
	a.glow = a:CreateTexture(nil, "BACKGROUND", nil, -1)
	a.glow:SetTexture(Ink.tex.glow)
	a.glow:SetPoint("TOPLEFT", -8, 8)
	a.glow:SetPoint("BOTTOMRIGHT", 8, -8)
	a.glow:SetBlendMode("ADD")
	a.disc = a:CreateTexture(nil, "BACKGROUND")
	a.disc:SetTexture(Ink.tex.disc)
	a.disc:SetAllPoints()
	a.disc:SetVertexColor(0.035, 0.04, 0.055, 0.95)
	a.icon = a:CreateTexture(nil, "ARTWORK")
	a.icon:SetPoint("CENTER")
	a.mask = a:CreateMaskTexture()
	a.mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	a.mask:SetPoint("TOPLEFT", a, "TOPLEFT", 2, -2)
	a.mask:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -2, 2)
	a.ring = a:CreateTexture(nil, "OVERLAY")
	a.ring:SetTexture(Ink.tex.ring)
	a.ring:SetAllPoints()
	-- 이름 알약 (서비스만)
	a.pill = CreateFrame("Frame", nil, a)
	a.pill:SetHeight(15)
	a.pill:SetPoint("TOP", a, "BOTTOM", 0, -2)
	a.pill.bg = Ink:Round(a.pill, "BACKGROUND", true, false)
	a.pill.bg:SetAllPoints()
	a.pill.bg:SetVertexColor(0.03, 0.035, 0.05, 0.86)
	a.pill.t = Ink:Text(a.pill, F.semi, 10, C.text, "CENTER")
	a.pill.t:SetPoint("CENTER", 0, 0)
	local ag = a:CreateAnimationGroup()
	local sc = ag:CreateAnimation("Scale")
	sc:SetDuration(0.12); sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.18, 1.18); sc:SetSmoothing("OUT")
	ag:SetScript("OnFinished", function() a:SetScale(1.18) end)
	p.grow = ag
	p:SetScript("OnEnter", function(self)
		self.grow:Play()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
		GameTooltip:AddLine(self.tipTitle or "", self.tipR or 1, self.tipG or 1, self.tipB or 1)
		if self.tipSub then GameTooltip:AddLine(self.tipSub, 0.85, 0.86, 0.88, true) end
		if self.tipNote then GameTooltip:AddLine(self.tipNote, 0.56, 0.58, 0.61, true) end
		GameTooltip:AddLine("우클릭: 길 안내", 0.56, 0.58, 0.61)
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.grow:Stop(); self.art:SetScale(1) end)
	p:RegisterForClicks("RightButtonUp")
	p:SetScript("OnClick", function(self)
		local mapID = WorldMapFrame:GetMapID()
		if mapID and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, self.wx, self.wy))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
		end
	end)
	self.cityPins[i] = p
	return p
end

-- kind: "svc" / "prof" / "cls" / "flight"
local function StylePin(p, kind, key, off)
	local a = p.art
	local size = (kind == "svc") and 26 or 22
	p:SetSize(size, size); a:SetSize(size, size)
	a.icon:RemoveMaskTexture(a.mask)
	a.icon:SetTexCoord(0, 1, 0, 1)
	a.icon:SetDesaturated(false)
	a.icon:SetAlpha(1)
	a.pill:Hide()
	local col
	if kind == "svc" or kind == "flight" then
		local v = SVC[key == "flight" and "flight" or key]
		col = (kind == "flight" and off) and FLIGHT_OFF or v.rgb
		a.icon:SetTexture(Ink.icon(v[1]))
		a.icon:SetSize(size * 0.56, size * 0.56)
		a.icon:SetVertexColor(col[1], col[2], col[3])
		a.icon:SetAlpha(off and 0.65 or 1)
		if kind == "svc" then
			a.pill.t:SetText(v[3])
			a.pill.t:SetTextColor(col[1], col[2], col[3])
			a.pill:SetWidth(a.pill.t:GetStringWidth() + 12)
			a.pill:Show()
		end
	elseif kind == "prof" then
		col = PROF_RING
		a.icon:SetTexture(PROF_ICON[key] or 134400)
		a.icon:SetSize(size - 4, size - 4)
		a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		a.icon:AddMaskTexture(a.mask)
		a.icon:SetVertexColor(1, 1, 1)
	else
		local tok = CLASS_TOKEN[key]
		local cc = tok and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tok]
		col = cc and { cc.r, cc.g, cc.b } or C.text
		a.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
		local tc = tok and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[tok]
		if tc then a.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
		a.icon:SetSize(size - 4, size - 4)
		a.icon:SetVertexColor(1, 1, 1)
	end
	a.ring:SetVertexColor(col[1], col[2], col[3], off and 0.5 or 1)
	a.glow:SetVertexColor(col[1], col[2], col[3], off and 0 or ((kind == "svc" or kind == "flight") and 0.26 or 0.14))
	p.tipR, p.tipG, p.tipB = col[1], col[2], col[3]
end

-- 넓은 지도용 작은 비행 지점: 가 본 곳 = 하늘색 점 + 얇은 고리, 안 가 본 곳 = 속이 빈 회색 고리
local function MiniFlight(p, off)
	local a = p.art
	local size = 12
	p:SetSize(size + 4, size + 4); a:SetSize(size, size)
	a.pill:Hide()
	a.glow:SetVertexColor(FLIGHT_ON[1], FLIGHT_ON[2], FLIGHT_ON[3], off and 0 or 0.18)
	a.disc:SetVertexColor(0.03, 0.035, 0.05, off and 0.55 or 0.92)
	a.icon:SetTexture(Ink.tex.disc)
	a.icon:SetSize(off and 3 or 5, off and 3 or 5)
	a.icon:SetTexCoord(0, 1, 0, 1)
	a.icon:SetVertexColor(off and 0.6 or FLIGHT_ON[1], off and 0.62 or FLIGHT_ON[2], off and 0.66 or FLIGHT_ON[3])
	a.icon:SetAlpha(off and 0.7 or 1)
	a.ring:SetVertexColor(off and 0.6 or FLIGHT_ON[1], off and 0.62 or FLIGHT_ON[2], off and 0.66 or FLIGHT_ON[3], off and 0.55 or 1)
end

-- 비행 지점을 알고 있는지 (비행 조련사 지도를 열 때 기억)
local function FlightKnown(id)
	return Ink.cdb and Ink.cdb.flightKnown and Ink.cdb.flightKnown[id]
end

function M:RememberFlights()
	if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then return end
	local mapID = GetTaxiMapID and GetTaxiMapID()
	local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID or 0)
	if not ok or type(nodes) ~= "table" then return end
	Ink.cdb.flightKnown = Ink.cdb.flightKnown or {}
	local S = Enum.FlightPathState
	for _, nd in ipairs(nodes) do
		if nd.nodeID and (not S or nd.state == S.Current or nd.state == S.Reachable) then
			Ink.cdb.flightKnown[nd.nodeID] = true
		end
	end
end

function M:Refresh()
	local wm = WorldMapFrame
	local cv = Canvas()
	if not (wm and cv and wm:IsShown() and self.layer) then return end
	local mapID = wm:GetMapID()
	local W, H = cv:GetWidth(), cv:GetHeight()
	local scale = (wm.GetCanvasScale and wm:GetCanvasScale()) or 1
	local pinScale = math.max(0.45, math.min(1.4, 1 / scale))
	local n = 0
	local placed = {}
	local cat = Ink.db.mapCat or {}
	-- 겹치면 둘레로 살짝 벌린다 (지도 칸 단위)
	local function spread(x, y, r)
		local px, py = x * W, y * H
		local function hit(qx, qy)
			for _, o in ipairs(placed) do
				local dx, dy = qx - o[1], qy - o[2]
				if dx * dx + dy * dy < (r + o[3]) * (r + o[3]) * 0.8 then return true end
			end
		end
		if hit(px, py) then
			for ring = 1, 3 do
				local found
				for k = 0, 5 do
					local ang = (k / 6 + ring * 0.08) * math.pi * 2
					local qx, qy = px + math.cos(ang) * r * 1.9 * ring, py + math.sin(ang) * r * 1.9 * ring
					if not hit(qx, qy) then px, py, found = qx, qy, true break end
				end
				if found then break end
			end
		end
		placed[#placed + 1] = { px, py, r }
		return px, py
	end
	-- 대륙 · 세계 지도: 비행 지점은 작고 깔끔한 점으로 (책 표시와 겹쳐도 덜 어지럽게)
	local mInfo = mapID and C_Map.GetMapInfo(mapID)
	local wide = mInfo and mInfo.mapType and mInfo.mapType <= 2
	local function put(x, y, kind, key, title, sub, note, off)
		n = n + 1
		local p = self:CityPin(n)
		StylePin(p, kind, key, off)
		if kind == "flight" and wide then MiniFlight(p, off) end
		local r = ((kind == "flight" and wide) and 6 or (kind == "svc" and 15 or 12)) * pinScale
		local px, py = spread(x, y, r)
		p:ClearAllPoints()
		p:SetScale(pinScale)
		-- 크기를 바꾼 틀의 위치 값은 그 크기만큼 곱해져서, 미리 나눠 둬야 제자리에 찍힌다
		p:SetPoint("CENTER", cv, "TOPLEFT", px / pinScale, -py / pinScale)
		p:SetFrameLevel(self.layer:GetFrameLevel() + (kind == "svc" and 30 or 10))
		p.wx, p.wy = x, y
		p.tipTitle, p.tipSub, p.tipNote = title, sub, note
		p:Show()
	end

	-- 1) 대도시: 서비스 먼저 (위에 그려지고 자리를 먼저 차지)
	if Ink.db.mapNpcs ~= false and mapID and CAPITAL[mapID] then
		local pick = {}
		for k, xy in pairs(CITY[mapID] or {}) do pick[k] = { x = xy[1] / 100, y = xy[2] / 100, seed = true } end
		for name, sp in pairs((Ink.db.npcSpots and Ink.db.npcSpots[mapID]) or {}) do
			local k
			local ranked = type(sp.sub) == "string" and (sp.sub:find("^수습 ") or sp.sub:find("^숙련 ") or sp.sub:find("^전문 ")
				or sp.sub:find("^대가 ") or sp.sub:find("^장인 ") or sp.sub:find("상급자") or sp.sub:find("지도자"))
			if sp.role == "trainer" or (ranked and TrainerKey(sp.sub)) then k = TrainerKey(sp.sub)
			elseif KEY_ROLE[sp.role] then k = sp.role end
			if k then
				local cur = pick[k]
				if not cur or cur.seed or (sp.t or 0) >= (cur.t or 0) then
					pick[k] = { x = sp.x, y = sp.y, name = (name:sub(1, 4) ~= "poi:") and name or nil, sub = sp.sub, t = sp.t }
				end
			end
		end
		local order = {}
		for k, sp in pairs(pick) do order[#order + 1] = { k = k, sp = sp } end
		local rank = function(k) return SVC[k] and 1 or (CLASS_TOKEN[k] and 2 or 3) end
		table.sort(order, function(a2, b2) return rank(a2.k) < rank(b2.k) end)
		for _, o in ipairs(order) do
			local k, sp = o.k, o.sp
			local kind = SVC[k] and "svc" or (CLASS_TOKEN[k] and "cls" or "prof")
			local show = (kind == "svc" and cat.svc ~= false) or (kind == "cls" and cat.cls ~= false) or (kind == "prof" and cat.prof ~= false)
			if show then
				local label = KeyLabel(k)
				local note = sp.seed and "기본 위치 · 한 번 들르면 정확한 자리로 바뀌어요" or nil
				put(sp.x, sp.y, kind, k, sp.name or label, sp.name and label or (sp.sub and ("<" .. sp.sub .. ">")), note)
			end
		end
	end

	-- 2) 비행 지점: 게임이 알려 주면 그걸로, 아니면 포에버 비행 자료 + 내가 아는 지점 기록
	if Ink.db.mapFlight ~= false and mapID and cat.flight ~= false then
		local fac = UnitFactionGroup("player")
		local facN = fac == "Horde" and 1 or (fac == "Alliance" and 2 or 0)
		local shown = 0
		if C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
			local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
			for _, nd in ipairs(ok and nodes or {}) do
				local pos = nd.position
				local x, y = pos and pos.GetXY and pos:GetXY()
				local mine = true
				if Enum.FlightPathFaction then
					if nd.faction == Enum.FlightPathFaction.Horde then mine = facN == 1
					elseif nd.faction == Enum.FlightPathFaction.Alliance then mine = facN == 2 end
				end
				if x and y and mine and not nd.isMapLayerTransition then
					local off = nd.isUndiscovered and not FlightKnown(nd.nodeID)
					put(x, y, "flight", "flight", nd.name or "비행 지점", off and "아직 안 가 본 비행 지점" or "가 본 비행 지점", nil, off)
					shown = shown + 1
				end
			end
		end
		if shown == 0 then
			for id, f in pairs(ns.FLIGHT_DB or {}) do
				if f[4] == 0 or f[4] == facN then
					local x, y = ToMap(f[1], f[2] / 100, f[3] / 100, mapID)
					if x then
						local off = not FlightKnown(id)
						put(x, y, "flight", "flight", "비행 조련사", off and "아직 안 가 본 비행 지점 (비행 조련사 지도를 한 번 열면 갱신)" or "가 본 비행 지점", nil, off)
					end
				end
			end
		end
	end
	for i = n + 1, #(self.cityPins or {}) do self.cityPins[i]:Hide() end
	n = 0
	self:PaintCityLegend(mapID)

	for i = n + 1, #(self.pins or {}) do self.pins[i]:Hide() end
	self:DrawBooks(mapID, cv, pinScale)
	self:PaintBooks(mapID)
	pcall(self.DrawEntrances, self, mapID, cv, pinScale)
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


function M:DrawBooks(mapID, cv, pinScale)
	local n = 0
	local W, H = cv:GetWidth(), cv:GetHeight()
	local fac = MyFaction()
	local function put(x, y, small)
		n = n + 1
		local p = self:BookPin(n)
		local mi = mapID and C_Map.GetMapInfo(mapID)
		local wide = mi and mi.mapType and mi.mapType <= 2
		local sc = pinScale * (small and (wide and 0.5 or 0.62) or 1)
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
-- 던전 입구: 지역 지도에만 (대륙 · 세계 지도에는 안 찍는다)
--  금테 아치 + 보랏빛 차원문 그림, 옆에 이름 · 권장 레벨 알약 (내 레벨 기준 색)
--  누르면 지도 옆 전리품 칸이 그 던전으로, 오른쪽 클릭은 이 지도에만 길 표시
-------------------------------------------------------------------------------
local PORTAL_TEX = "Interface\\AddOns\\FOA_UI\\Media\\Textures\\Portal"
-- 자료에 없는 입구 (지역 지도 좌표)
local EXTRA_ENTR = {
	thanes = { { 1455, 43.6, 51.7 } },
	dm_east = { { 1444, 59.2, 44.8 } }, dm_west = { { 1444, 59.2, 44.8 } }, dm_north = { { 1444, 59.2, 44.8 } },
	strat_live = { { 1423, 27.0, 11.5 } }, strat_ud = { { 1423, 43.0, 18.0 } },
	brd = { { 1427, 34.8, 85.3 }, { 1428, 29.4, 37.6 } },
	lbrs = { { 1427, 34.8, 85.3 }, { 1428, 29.4, 37.6 } },
	ubrs = { { 1427, 34.8, 85.3 }, { 1428, 29.4, 37.6 } },
}
local SKIP_ATT_ENTR = { brd = true }  -- 검은바위 산 안쪽 지도 좌표 대신 산 입구로

local function EntrLevelColor(lo, hi)
	local lv = UnitLevel("player") or 1
	if lv < lo - 2 then return C.red end
	if lv < lo then return C.orange end
	if lv <= hi then return { 0.44, 0.83, 0.6 } end
	return C.muted
end

-- 같은 자리 입구는 하나로 묶는다 (붉은십자군 날개 · 혈투의 전장 · 검은바위 산)
local function EntranceGroups()
	local groups, byPos = {}, {}
	for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
		if not d.soon then
			local pts = {}
			if d.entr and not SKIP_ATT_ENTR[d.key] then pts[#pts + 1] = d.entr end
			for _, e in ipairs(EXTRA_ENTR[d.key] or {}) do pts[#pts + 1] = e end
			for _, e in ipairs(pts) do
				local k = e[1] .. ":" .. math.floor(e[2] * 2 + 0.5) .. ":" .. math.floor(e[3] * 2 + 0.5)
				local g = byPos[k]
				if not g then
					g = { map = e[1], x = e[2] / 100, y = e[3] / 100, list = {} }
					byPos[k] = g
					groups[#groups + 1] = g
				end
				g.list[#g.list + 1] = d
			end
		end
	end
	return groups
end

local function GroupTitle(g)
	local first = g.list[1]
	if #g.list == 1 then return first.ko end
	local same = first.groupKo
	for _, d in ipairs(g.list) do if d.groupKo ~= same then same = nil break end end
	if same then return same end
	return "검은바위 산"
end

function M:EntrancePin(i)
	self.entrPins = self.entrPins or {}
	local p = self.entrPins[i]
	if p then return p end
	p = CreateFrame("Button", nil, self.layer)
	p:SetSize(18, 18)
	p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	p.art = CreateFrame("Frame", nil, p)
	p.art:SetPoint("CENTER")
	p.art:SetSize(21, 21)
	p.halo = p.art:CreateTexture(nil, "BACKGROUND")
	p.halo:SetTexture(Ink.tex.glow)
	p.halo:SetSize(36, 36)
	p.halo:SetPoint("CENTER", 0, -1)
	p.halo:SetBlendMode("ADD")
	p.halo:SetVertexColor(0.62, 0.52, 1, 0.22)
	p.icon = p.art:CreateTexture(nil, "ARTWORK")
	p.icon:SetTexture(PORTAL_TEX)
	p.icon:SetAllPoints()
	-- 이름 알약
	p.pill = CreateFrame("Frame", nil, p)
	p.pill:SetHeight(15)
	p.pill:SetPoint("LEFT", p, "RIGHT", 1, -1)
	p.pill.bg = Ink:Round(p.pill, "BACKGROUND", true, false)
	p.pill.bg:SetAllPoints()
	p.pill.bg:SetVertexColor(0.035, 0.04, 0.052, 0.88)
	p.pill.bd = Ink:Round(p.pill, "BORDER", true, true)
	p.pill.bd:SetAllPoints()
	p.pill.bd:SetVertexColor(0.89, 0.75, 0.48, 0.45)
	p.pill.name = Ink:Text(p.pill, F.semi, 9, C.text, "LEFT")
	p.pill.name:SetPoint("LEFT", 6, 0)
	p.pill.lvl = Ink:Text(p.pill, F.numR or F.semi, 9, C.soft, "LEFT")
	p.pill.lvl:SetPoint("LEFT", p.pill.name, "RIGHT", 5, 0)
	-- 입구 버튼으로 찾아왔을 때 몇 초 동안 물결
	p.ping = p:CreateTexture(nil, "BACKGROUND")
	p.ping:SetTexture(Ink.tex.ring)
	p.ping:SetSize(21, 21)
	p.ping:SetPoint("CENTER")
	p.ping:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0)
	local ag = p.ping:CreateAnimationGroup()
	ag:SetLooping("REPEAT")
	local s1 = ag:CreateAnimation("Scale"); s1:SetScaleFrom(0.6, 0.6); s1:SetScaleTo(2.4, 2.4); s1:SetDuration(1.2); s1:SetSmoothing("OUT")
	local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(1); a1:SetToAlpha(0); a1:SetDuration(1.2)
	p.pingAG = ag
	HoverArt(p)
	p:SetScript("OnEnter", function(self)
		self.grow:Play()
		self.halo:SetVertexColor(0.62, 0.52, 1, 0.45)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(GroupTitle(self.g) .. "  입구", 1, 1, 1)
		for _, d in ipairs(self.g.list) do
			local c = EntrLevelColor(d.lo, d.hi)
			local nb = 0
			for _, b in ipairs(d.bosses) do if b[4] ~= 1 then nb = nb + 1 end end
			GameTooltip:AddDoubleLine((d.wing and #self.g.list > 1 and d.groupKo == GroupTitle(self.g)) and d.wing or d.ko,
				"Lv " .. d.lo .. "–" .. d.hi .. "  ·  보스 " .. nb, 0.86, 0.87, 0.9, c[1], c[2], c[3])
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("클릭: 전리품 · 진행 경로 보기", 0.6, 0.62, 0.66)
		GameTooltip:AddLine("오른쪽 클릭: 이 지역 지도에 길 표시", 0.6, 0.62, 0.66)
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function(self)
		self.grow:Stop(); self.art:SetScale(1)
		self.halo:SetVertexColor(0.62, 0.52, 1, 0.22)
		GameTooltip:Hide()
	end)
	p:SetScript("OnClick", function(self, btn)
		if btn == "RightButton" then
			local mapID = WorldMapFrame:GetMapID()
			if mapID and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
				C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, self.wx, self.wy))
			end
			return
		end
		local D = Ink.modules.Dungeon
		local pick = self.g.list[1]
		local lv = UnitLevel("player") or 1
		for _, d in ipairs(self.g.list) do if lv >= d.lo - 1 and lv <= d.hi then pick = d break end end
		if D and D.SelectForever then
			if not (D.sidebar and D.sidebar:IsShown()) and D.ShowFor then D:ShowFor(pick.key, WorldMapFrame) end
			D:SelectForever(pick.key)
		end
	end)
	self.entrPins[i] = p
	return p
end

function M:DrawEntrances(mapID, cv, pinScale)
	local n = 0
	local info = mapID and C_Map.GetMapInfo(mapID)
	local mt = info and info.mapType
	-- 지역(3) · 작은 지역(5) · 따로 떨어진 지도(6)에만. 세계(1) · 대륙(2) · 던전(4)은 빼기
	local zoneLike = mt == 3 or mt == 5 or mt == 6
	if Ink.db.mapEntrances ~= false and zoneLike then
		self.entrGroups = self.entrGroups or EntranceGroups()
		local W, H = cv:GetWidth(), cv:GetHeight()
		for _, g in ipairs(self.entrGroups) do
			local x, y = ToMap(g.map, g.x, g.y, mapID)
			if x then
				n = n + 1
				local p = self:EntrancePin(n)
				p.g = g
				local sc = pinScale
				p:ClearAllPoints()
				p:SetScale(sc)
				p:SetPoint("CENTER", cv, "TOPLEFT", x * W / sc, -y * H / sc)
				p:SetFrameLevel(self.layer:GetFrameLevel() + 25)
				p.wx, p.wy = x, y
				local lo, hi = 99, 0
				for _, d in ipairs(g.list) do lo = math.min(lo, d.lo); hi = math.max(hi, d.hi) end
				p.pill.name:SetText(GroupTitle(g))
				local c = EntrLevelColor(lo, hi)
				p.pill.lvl:SetText(lo == hi and tostring(lo) or (lo .. "–" .. hi))
				p.pill.lvl:SetTextColor(c[1], c[2], c[3])
				p.pill:SetWidth(math.ceil(p.pill.name:GetStringWidth() + p.pill.lvl:GetStringWidth()) + 17)
				local flash = false
				for _, d in ipairs(g.list) do if d.key == self.flashKey then flash = true end end
				if flash then p.pingAG:Play() else p.pingAG:Stop() end
				p:Show()
			end
		end
	end
	for i = n + 1, #(self.entrPins or {}) do self.entrPins[i]:Hide() end
	self:HideBlizzardEntrances()
end

-- 같은 던전의 블리자드 동그란 입구 표시는 숨긴다 (우리 표시와 겹치지 않게 · 대륙 지도 포함)
function M:HideBlizzardEntrances()
	local wm = WorldMapFrame
	if Ink.db.mapEntrances == false or not (wm and wm.EnumeratePinsByTemplate) then return end
	if not self.entrNames then
		self.entrNames = {}
		for _, d in ipairs(ns.FOREVER_LOOT and ns.FOREVER_LOOT.list or {}) do
			for _, s in ipairs({ d.ko, d.en, d.groupKo }) do if s then self.entrNames[s] = true end end
		end
		self.entrNames["검은바위 산"], self.entrNames["Blackrock Mountain"] = true, true
		self.entrNames["붉은십자군 수도원"], self.entrNames["Scarlet Monastery"] = true, true
		self.entrNames["혈투의 전장"], self.entrNames["Dire Maul"] = true, true
		self.entrNames["스트라솔름"], self.entrNames["Stratholme"] = true, true
	end
	for _, tpl in ipairs({ "DungeonEntrancePinTemplate", "EncounterJournalPinTemplate" }) do
		local ok, iter = pcall(wm.EnumeratePinsByTemplate, wm, tpl)
		if ok and iter then
			for pin in iter do
				local nm = pin.name or (pin.poiInfo and pin.poiInfo.name)
				if nm and self.entrNames[nm] then pin:SetAlpha(0); if pin.EnableMouse then pin:EnableMouse(false) end end
			end
		end
	end
end

-- 던전 입구 자리 (지역 지도, 0~100 좌표): 전리품 칸의 "입구" 버튼용
function M:EntrancePoint(key)
	self.entrGroups = self.entrGroups or EntranceGroups()
	for _, g in ipairs(self.entrGroups) do
		for _, d in ipairs(g.list) do
			if d.key == key then return { g.map, g.x * 100, g.y * 100 } end
		end
	end
end

-- 전리품 칸의 "입구" 버튼: 그 지역 지도를 열고 입구 표시에 물결 (몇 초)
function M:FocusEntrance(key, mapID)
	self.flashKey = key
	if not (WorldMapFrame and WorldMapFrame:IsShown()) then
		if OpenWorldMap then pcall(OpenWorldMap, mapID) elseif ToggleWorldMap then ToggleWorldMap() end
	end
	if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
	self:Refresh()
	C_Timer.After(6, function()
		if M.flashKey == key then M.flashKey = nil; if WorldMapFrame and WorldMapFrame:IsShown() then M:Refresh() end end
	end)
end

-------------------------------------------------------------------------------
-- 도서관 책 상자 (지도 왼쪽 아래): 모은 수 + 다음 보상 + 이 지역 책 목록
-------------------------------------------------------------------------------
function M:PaintBooks(mapID)
	local box = self.books
	if not box then return end
	if Ink.db.mapBooks == false or not mapID then box:Hide() self:LayoutUnder() return end
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
	if #lines == 0 and not lib then box:Hide() self:LayoutUnder() return end
	-- 지도를 크게(최대화) 띄우면 아래 칸이 화면 밖이라 지도 안 왼쪽 아래로
	local wm = WorldMapFrame
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", 0, -6)
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
	self:LayoutUnder()
end

-- 지도 아래 칸 자리 잡기 (겹치지 않게)
--  창 지도: 첫 줄 = 대도시 범례(왼쪽) · 받을 수 있는 퀘스트(오른쪽), 그 아래 도서관 책 상자
--  큰 지도: 지도 안 아래쪽 = 책 상자(왼쪽) · 범례(가운데) · 퀘스트(오른쪽)
function M:LayoutUnder()
	local wm = WorldMapFrame
	if not wm then return end
	local big = wm.IsMaximized and wm:IsMaximized()
	local box, bar = self.books, self.cityBar
	local Q = Ink.modules.QuestMap
	local leg = Q and Q.legend
	local row = (bar and bar:IsShown()) or (leg and leg:IsShown())
	if bar then
		bar:ClearAllPoints()
		if big then bar:SetPoint("BOTTOM", wm.ScrollContainer, "BOTTOM", 0, 10)
		else bar:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", 0, -6) end
	end
	if box then
		box:ClearAllPoints()
		if big then
			box:SetPoint("BOTTOMLEFT", wm.ScrollContainer, "BOTTOMLEFT", 10, 10)
		else
			box:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", 0, -6)
		end
	end
	-- 창 지도: 지도 아래 한 줄 = 책 상자(왼쪽) · 범례(책 상자 바로 오른쪽, 책이 없으면 가운데) · 퀘스트(오른쪽 끝).
	--  지도 폭이 모자랄 때만 범례를 위 줄에 두고 책 상자를 한 줄 아래로
	if not big and bar and bar:IsShown() then
		local W = wm:GetWidth() or 0
		local bw = bar:GetWidth() or 0
		local left = (box and box:IsShown()) and ((box:GetWidth() or 212) + 6) or 0
		local right = W - ((leg and leg:IsShown()) and ((leg:GetWidth() or 0) + 8) or 0)
		local cx = (W - bw) / 2
		bar:ClearAllPoints()
		if left == 0 and cx + bw <= right then
			bar:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", cx, -6)
		elseif left + bw <= right then
			bar:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", left, -6)
		else
			bar:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", 0, -6)
			if box and box:IsShown() then
				box:ClearAllPoints()
				box:SetPoint("TOPLEFT", wm, "BOTTOMLEFT", 0, -38)
			end
		end
	end
end

function M:BuildBooks()
	local wm = WorldMapFrame
	-- 지도를 가리지 않게 지도 창 바로 아래에 붙인다
	local box = CreateFrame("Frame", nil, wm)
	box:SetWidth(212)
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
	box.bar = Ink:Bar(box, 184, 3, BOOK, C.track)
	box.bar:SetPoint("TOPLEFT", 14, -34)
	box.next = Ink:Text(box, F.sans, 10, C.muted, "LEFT")
	box.next:SetPoint("TOPLEFT", box.bar, "BOTTOMLEFT", 0, -6)
	box.text = Ink:Text(box, F.sans, 11, C.soft, "LEFT")
	box.text:SetPoint("TOPLEFT", 14, -62)
	box.text:SetWidth(184)
	box.text:SetWordWrap(true)
	box.text:SetSpacing(2)
	box:Hide()
	self.books = box
end

-------------------------------------------------------------------------------
-- 대도시 범례 (지도 아래 가운데): 서비스 · 직업 상급자 · 전문기술 · 비행 켜고 끄기
-------------------------------------------------------------------------------
local CHIPS = {
	{ "svc", "서비스", "NpcBank", "E3C07A" }, { "cls", "직업 상급자", "NpcTrainer", "F3F2EE" },
	{ "prof", "전문기술", "Professions", "C9A8FF" }, { "flight", "비행", "NpcFlight", "86DDF2" },
}
function M:BuildCityLegend()
	local wm = WorldMapFrame
	local bar = CreateFrame("Frame", nil, wm)
	bar:SetHeight(24)
	bar:SetPoint("TOP", wm, "BOTTOM", 0, -6)
	bar:SetFrameStrata("HIGH")
	bar.chips = {}
	local prev
	for i, c in ipairs(CHIPS) do
		local b = CreateFrame("Button", nil, bar)
		b:SetHeight(24)
		b.bg = Ink:Round(b, "BACKGROUND", true, false)
		b.bg:SetAllPoints()
		b.bd = Ink:Round(b, "BORDER", true, true)
		b.bd:SetAllPoints()
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetTexture(Ink.icon(c[3]))
		b.icon:SetSize(12, 12)
		b.icon:SetPoint("LEFT", 8, 0)
		b.t = Ink:Text(b, F.semi, 11, C.text, "LEFT")
		b.t:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
		b.t:SetText(c[2])
		b:SetWidth(b.t:GetStringWidth() + 26)
		b.key, b.rgb = c[1], Ink.hex(c[4])
		b:SetPoint("LEFT", prev or bar, prev and "RIGHT" or "LEFT", prev and 4 or 0, 0)
		b:SetScript("OnClick", function(self)
			Ink.db.mapCat = Ink.db.mapCat or {}
			Ink.db.mapCat[self.key] = (Ink.db.mapCat[self.key] == false) and true or false
			M:Refresh()
		end)
		bar.chips[i] = b
		prev = b
	end
	local w = 0
	for _, b in ipairs(bar.chips) do w = w + b:GetWidth() + 4 end
	bar:SetWidth(w - 4)
	bar:Hide()
	self.cityBar = bar
end

function M:PaintCityLegend(mapID)
	local bar = self.cityBar
	if not bar then return end
	if not (mapID and CAPITAL[mapID]) or Ink.db.mapNpcs == false then bar:Hide() self:LayoutUnder() return end
	local cat = Ink.db.mapCat or {}
	for _, b in ipairs(bar.chips) do
		local on = cat[b.key] ~= false
		local c = b.rgb
		b.bg:SetVertexColor(0.04, 0.045, 0.06, 0.9)
		b.bd:SetVertexColor(c[1], c[2], c[3], on and 0.6 or 0.15)
		b.icon:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.35)
		b.t:SetTextColor(on and C.text[1] or C.dim[1], on and C.text[2] or C.dim[2], on and C.text[3] or C.dim[3])
	end
	bar:Show()
	self:LayoutUnder()
end

-- 경비병에게 길을 물으면 지도에 찍히는 표시(은행 · 경매장 · 여관 · 훈련사 …)를 그 자리로 기억
function M:RememberGossipPoi()
	if not (C_GossipInfo and C_GossipInfo.GetPoiForUiMapID) then return end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not (mapID and CAPITAL[mapID]) then return end
	local poiID = C_GossipInfo.GetPoiForUiMapID(mapID)
	local info = poiID and C_GossipInfo.GetPoiInfo(mapID, poiID)
	if not (info and info.position and info.name) then return end
	local x, y = info.position:GetXY()
	local nm = info.name
	local role
	if nm:find("은행") or nm:find("Bank") then role = "bank"
	elseif nm:find("경매") or nm:find("Auction") then role = "auction"
	elseif nm:find("여관") or nm:find("Inn") then role = "inn"
	elseif nm:find("우편") or nm:find("Mail") then role = "mail"
	elseif nm:find("비행") or nm:find("그리") or nm:find("Flight") or nm:find("Gryphon") or nm:find("Wind Rider") then role = "flight"
	elseif TrainerKey(nm) then role = "trainer" end
	if not role then return end
	Ink.db.npcSpots = Ink.db.npcSpots or {}
	local t = Ink.db.npcSpots[mapID] or {}
	Ink.db.npcSpots[mapID] = t
	t["poi:" .. (role == "trainer" and TrainerKey(nm) or role)] = { x = x, y = y, role = role, sub = nm, t = time() }
	if WorldMapFrame and WorldMapFrame:IsShown() then self:Refresh() end
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
	-- 훈련사로 보이는 직함(수습 · 숙련 · 전문 대장장이 등)은 수리가 아니라 훈련사
	if sub and TrainerKey(sub) and (role == "repair" or role == "vendor") and event ~= "MERCHANT_SHOW" then role = "trainer" end
	if event == "TRAINER_SHOW" then role = "trainer" end
	t[name] = { x = math.floor(x * 1000 + 0.5) / 1000, y = math.floor(y * 1000 + 0.5) / 1000, role = role, sub = sub, t = time() }
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
		-- 지도 크기(배율)를 바꿔도 같은 자리에 오게 화면 기준 좌표로 저장
		local sc = wm:GetScale() or 1
		if l and t then Ink.db.mapPos = { l * sc, t * sc, ui = true } end
	end)
	h:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("끌어서 지도 옮기기", 1, 1, 1)
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", GameTooltip_Hide)
	self.moveHandle = h
	local function restore()
		M:ApplyScale()
		local pos = Ink.db.mapPos
		if not pos or InCombatLockdown() or (wm.IsMaximized and wm:IsMaximized()) then return end
		local sc = pos.ui and (wm:GetScale() or 1) or 1
		wm:ClearAllPoints()
		wm:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1] / sc, pos[2] / sc)
	end
	self.restorePos = restore
	wm:HookScript("OnShow", function() C_Timer.After(0, restore) end)
	for _, fn in ipairs({ "Maximize", "Minimize" }) do
		if wm[fn] then hooksecurefunc(wm, fn, function() C_Timer.After(0, function() restore(); M:LayoutUnder() end) end) end
	end
end

-- 창 지도 크기: 설정에서 켜면 1.3배 (기본은 원래 크기 · 최대화했을 때는 그대로)
M.MAP_SCALE = 1.3
function M:ApplyScale()
	local wm = WorldMapFrame
	if not wm or InCombatLockdown() then return end
	local want = 1
	if Ink.db.mapScaleUp and not (wm.IsMaximized and wm:IsMaximized()) then want = M.MAP_SCALE end
	if math.abs((wm:GetScale() or 1) - want) > 0.001 then wm:SetScale(want) end
end

function M:Hook()
	local wm = WorldMapFrame
	if not wm or self.hooked or not Canvas() then return end
	self.hooked = true
	pcall(self.MakeMovable, self)
	pcall(self.BuildCityLegend, self)
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
	for _, ev in ipairs({ "GOSSIP_SHOW", "ADDON_LOADED", "TAXI_NODE_STATUS_CHANGED", "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "DYNAMIC_GOSSIP_POI_UPDATED" }) do pcall(e.RegisterEvent, e, ev) end
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
		if event == "DYNAMIC_GOSSIP_POI_UPDATED" then
			C_Timer.After(0.1, function() pcall(M.RememberGossipPoi, M) end)
			return
		end
		if event == "TAXIMAP_OPENED" then pcall(M.RememberFlights, M) end
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
