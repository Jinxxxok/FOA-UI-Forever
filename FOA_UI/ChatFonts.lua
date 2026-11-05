-- FOA UI · 채팅 글꼴 고르기
--  채팅창 오른쪽 위 톱니바퀴 → 글꼴 목록을 그 글꼴로 직접 써서 미리 보여 주고, 누르면 바로 바뀐다
--  · 한 글꼴에 굵기가 여러 개면 굵기마다 한 줄씩
--  · FOA 에 들어 있는 글꼴 + 게임 기본 글꼴 + 직접 넣은 글꼴(AddOns\FOA_Fonts 또는 FOA_UI\Media\Fonts)
--    (게임은 폴더 안 파일 목록을 읽을 수 없어서, 많이 쓰는 한글 글꼴 이름들을 하나씩 찾아본다)
--  · 글자 크기 · 테두리도 여기서

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("ChatFonts")
local F, C = Ink.font, Ink.c

local MEDIA = "Interface\\AddOns\\FOA_UI\\Media\\Fonts\\"
local USER_DIRS = { "Interface\\AddOns\\FOA_Fonts\\", MEDIA }
local W, H = 384, 540
local SAMPLE = "다람쥐 헌 쳇바퀴에 타고파  ·  Aa Bb 123"

-- FOA 에 들어 있는 글꼴 (전부 한글 포함)
local BUNDLED = {
	{ "프리텐다드", "Pretendard", { { "Regular", "보통" }, { "Medium", "중간" }, { "SemiBold", "약간 굵게" }, { "Bold", "굵게" } } },
	{ "IBM 플렉스 산스 KR", "PlexSansKR", { { "Regular", "보통" }, { "SemiBold", "약간 굵게" }, { "Bold", "굵게" } } },
	{ "인터 (한글 포함)", "Inter", { { "Medium", "중간" }, { "SemiBold", "약간 굵게" } } },
	{ "스페이스 그로테스크 (한글 포함)", "SpaceGrotesk", { { "Light", "얇게" }, { "Regular", "보통" } } },
}
-- 게임 안 글꼴
local GAME = {
	{ "Fonts\\2002.ttf", "기본" }, { "Fonts\\2002B.ttf", "굵게" }, { "Fonts\\K_Pagetext.ttf", "책 · 편지" }, { "Fonts\\K_Damage.ttf", "전투 숫자" },
}
-- 직접 넣은 글꼴 후보: { 묶음 이름, { { 파일 이름(확장자 없이), 굵기 이름 }, ... } }
local USER = {
	{ "무빅 · 세방고딕", { { "MUBIG", "보통" }, { "MUBIG-Bold", "굵게" }, { "SEBANG Gothic", "보통" }, { "SEBANG Gothic Bold", "굵게" },
		{ "SEBANGGothic", "보통" }, { "SEBANGGothicBold", "굵게" }, { "SebangGothicBold", "굵게" }, { "세방고딕", "보통" }, { "세방고딕 Bold", "굵게" } } },
	{ "나눔고딕", { { "NanumGothicLight", "얇게" }, { "NanumGothic", "보통" }, { "NanumGothicBold", "굵게" }, { "NanumGothicExtraBold", "아주 굵게" } } },
	{ "나눔바른고딕", { { "NanumBarunGothicUltraLight", "아주 얇게" }, { "NanumBarunGothicLight", "얇게" }, { "NanumBarunGothic", "보통" }, { "NanumBarunGothicBold", "굵게" } } },
	{ "나눔스퀘어", { { "NanumSquareL", "얇게" }, { "NanumSquareR", "보통" }, { "NanumSquareB", "굵게" }, { "NanumSquareEB", "아주 굵게" } } },
	{ "나눔스퀘어 라운드", { { "NanumSquareRoundL", "얇게" }, { "NanumSquareRoundR", "보통" }, { "NanumSquareRoundB", "굵게" }, { "NanumSquareRoundEB", "아주 굵게" } } },
	{ "나눔명조", { { "NanumMyeongjo", "보통" }, { "NanumMyeongjoBold", "굵게" }, { "NanumMyeongjoExtraBold", "아주 굵게" } } },
	{ "나눔손글씨", { { "NanumPen", "펜" }, { "NanumBrush", "붓" } } },
	{ "본고딕 (Noto Sans KR)", { { "NotoSansKR-Thin", "아주 얇게" }, { "NotoSansKR-Light", "얇게" }, { "NotoSansKR-Regular", "보통" }, { "NotoSansKR-Medium", "중간" },
		{ "NotoSansKR-SemiBold", "약간 굵게" }, { "NotoSansKR-Bold", "굵게" }, { "NotoSansKR-ExtraBold", "아주 굵게" }, { "NotoSansKR-Black", "가장 굵게" } } },
	{ "본명조 (Noto Serif KR)", { { "NotoSerifKR-Regular", "보통" }, { "NotoSerifKR-SemiBold", "약간 굵게" }, { "NotoSerifKR-Bold", "굵게" } } },
	{ "스포카 한 산스 Neo", { { "SpoqaHanSansNeo-Thin", "아주 얇게" }, { "SpoqaHanSansNeo-Light", "얇게" }, { "SpoqaHanSansNeo-Regular", "보통" },
		{ "SpoqaHanSansNeo-Medium", "중간" }, { "SpoqaHanSansNeo-Bold", "굵게" } } },
	{ "SUIT", { { "SUIT-Light", "얇게" }, { "SUIT-Regular", "보통" }, { "SUIT-Medium", "중간" }, { "SUIT-SemiBold", "약간 굵게" }, { "SUIT-Bold", "굵게" }, { "SUIT-ExtraBold", "아주 굵게" } } },
	{ "G마켓 산스", { { "GmarketSansTTFLight", "얇게" }, { "GmarketSansTTFMedium", "보통" }, { "GmarketSansTTFBold", "굵게" },
		{ "GmarketSansLight", "얇게" }, { "GmarketSansMedium", "보통" }, { "GmarketSansBold", "굵게" } } },
	{ "마루 부리", { { "MaruBuri-Light", "얇게" }, { "MaruBuri-Regular", "보통" }, { "MaruBuri-SemiBold", "약간 굵게" }, { "MaruBuri-Bold", "굵게" } } },
	{ "배민체", { { "BMDOHYEON_ttf", "도현" }, { "BMJUA_ttf", "주아" }, { "BMHANNAPro", "한나 Pro" }, { "BMHANNAAir_ttf", "한나 Air" }, { "BMEULJIRO", "을지로" } } },
	{ "맑은 고딕", { { "malgunsl", "얇게" }, { "malgun", "보통" }, { "malgunbd", "굵게" } } },
	{ "D2Coding", { { "D2Coding", "보통" }, { "D2CodingBold", "굵게" } } },
	{ "카페24", { { "Cafe24Ssurround", "써라운드" }, { "Cafe24SsurroundAir", "써라운드 에어" }, { "Cafe24Ohsquare", "아네모네" } } },
	{ "에스코어 드림", { { "S-CoreDream-3Light", "얇게" }, { "S-CoreDream-4Regular", "보통" }, { "S-CoreDream-5Medium", "중간" }, { "S-CoreDream-6Bold", "굵게" } } },
	{ "KoPub 돋움", { { "KoPubDotumLight", "얇게" }, { "KoPubDotumMedium", "보통" }, { "KoPubDotumBold", "굵게" } } },
	{ "이서윤체 · 기타", { { "LeeSeoyun", "보통" }, { "Jalnan", "잘난체" }, { "JalnanOTF", "잘난체" }, { "TmoneyRoundWindRegular", "티머니 둥근바람" }, { "TmoneyRoundWindExtraBold", "티머니 둥근바람 굵게" } } },
}

-- 쓸 수 있는 글꼴 목록 (처음 열 때 한 번 찾는다) { { family, { {path, label}, ... } }, ... }
function M:Catalog()
	if self.catalog then return self.catalog end
	local list = {}
	-- 게임 기본
	local g = {}
	for _, e in ipairs(GAME) do if Ink:FontExists(e[1]) then g[#g + 1] = { e[1], e[2] } end end
	if #g > 0 then list[#list + 1] = { "게임 기본 글꼴", g, "game" } end
	-- 직접 넣은 글꼴 (맨 위에)
	local seen, mine = {}, {}
	for _, fam in ipairs(USER) do
		local found = {}
		for _, w in ipairs(fam[2]) do
			for _, dir in ipairs(USER_DIRS) do
				for _, ext in ipairs({ ".ttf", ".otf", ".TTF", ".OTF" }) do
					local p = dir .. w[1] .. ext
					if not seen[p:lower()] and Ink:FontExists(p) then
						seen[p:lower()] = true
						found[#found + 1] = { p, w[2] .. (dir == USER_DIRS[1] and "" or "  ·  FOA 글꼴 폴더") }
						break
					end
				end
			end
		end
		if #found > 0 then mine[#mine + 1] = { fam[1], found, "user" } end
	end
	-- 무빅을 다른 이름으로 찾아 둔 경우
	if Ink.mubigFile and not seen[Ink.mubigFile:lower()] then
		table.insert(mine, 1, { "무빅 · 세방고딕", { { Ink.mubigFile, "보통" } }, "user" })
	end
	for i = #mine, 1, -1 do table.insert(list, 1, mine[i]) end
	-- FOA 글꼴
	for _, fam in ipairs(BUNDLED) do
		local ws = {}
		for _, w in ipairs(fam[3]) do
			local p = MEDIA .. fam[2] .. "-" .. w[1] .. ".ttf"
			if Ink:FontExists(p) then ws[#ws + 1] = { p, w[2] .. "  ·  " .. w[1] } end
		end
		if #ws > 0 then list[#list + 1] = { fam[1], ws, "foa" } end
	end
	if Ink:FontExists(MEDIA .. "YSpotlight.ttf") then list[#list + 1] = { "Y 스포트라이트", { { MEDIA .. "YSpotlight.ttf", "보통" } }, "foa" } end
	self.catalog = list
	return list
end

-------------------------------------------------------------------------------
-- 지금 채팅 글꼴 · 크기
-------------------------------------------------------------------------------
local function Bz() return Ink.modules.Blizzard end
local function Current()
	local bz = Bz()
	if bz and bz.ChatFont then return bz:ChatFont() end
	return F.sans, ""
end
local function CurSize()
	local cf = _G.ChatFrame1
	local size
	if cf and cf.GetFont then size = select(2, cf:GetFont()) end
	return math.floor((size or 13) + 0.5)
end

function M:Pick(path)
	Ink.db.chatFontPath = path
	local bz = Bz()
	if bz then bz.chatPickOK = nil; if bz.ApplyChatFont then bz:ApplyChatFont() end end
	self:Paint()
	local cfg = Ink.modules.Config
	if cfg and cfg.SyncFontButton then pcall(cfg.SyncFontButton, cfg) end
end

function M:SetSize(size)
	size = math.max(9, math.min(24, size))
	for _, n in ipairs(CHAT_FRAMES or {}) do
		local cf = _G[n]
		if cf then
			if FCF_SetChatWindowFontSize then pcall(FCF_SetChatWindowFontSize, nil, cf, size)
			else local p, _, fl = cf:GetFont(); cf:SetFont(p, size, fl) end
		end
	end
	local bz = Bz()
	if bz and bz.ApplyChatFont then bz:ApplyChatFont() end
	self:Paint()
end

-------------------------------------------------------------------------------
-- 창
-------------------------------------------------------------------------------
local function SmallBtn(parent, w, h, label)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(1, 1, 1, 0.05)
	b.bd = Ink:Round(b, "BORDER", true, true)
	b.bd:SetAllPoints()
	b.bd:SetVertexColor(1, 1, 1, 0.1)
	b.t = Ink:Text(b, F.semi, 11, C.text, "CENTER")
	b.t:SetPoint("CENTER")
	b.t:SetText(label or "")
	b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.1) end)
	b:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0.05) end)
	return b
end

function M:Build()
	local p = CreateFrame("Frame", "FOAChatFontPicker", UIParent)
	p:SetSize(W, H)
	p:SetFrameStrata("DIALOG")
	p:SetClampedToScreen(true)
	p:EnableMouse(true)
	p:Hide()
	p.bg = Ink:Round(p, "BACKGROUND", false, false)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(0.035, 0.04, 0.052, 0.98)
	p.bd = Ink:Round(p, "BORDER", false, true)
	p.bd:SetAllPoints()
	p.bd:SetVertexColor(1, 1, 1, 0.1)
	local acc = p:CreateTexture(nil, "ARTWORK")
	acc:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	acc:SetSize(24, 2)
	acc:SetPoint("TOPLEFT", 16, -1)
	p.title = Ink:Text(p, F.bold, 14, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", 16, -16)
	p.title:SetText("채팅 글꼴")
	p.close = CreateFrame("Button", nil, p)
	p.close:SetSize(24, 24)
	p.close:SetPoint("TOPRIGHT", -10, -10)
	p.close.i = p.close:CreateTexture(nil, "OVERLAY")
	p.close.i:SetTexture(Ink.icon("Cross"))
	p.close.i:SetSize(12, 12)
	p.close.i:SetPoint("CENTER")
	p.close.i:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
	p.close:SetScript("OnClick", function() p:Hide() end)
	p.close:SetScript("OnEnter", function(self) self.i:SetVertexColor(1, 1, 1) end)
	p.close:SetScript("OnLeave", function(self) self.i:SetVertexColor(C.muted[1], C.muted[2], C.muted[3]) end)
	-- 크게 미리 보기 (채팅처럼)
	local pv = CreateFrame("Frame", nil, p)
	pv:SetPoint("TOPLEFT", 12, -44)
	pv:SetPoint("TOPRIGHT", -12, -44)
	pv:SetHeight(78)
	pv.bg = Ink:Round(pv, "BACKGROUND", true, false)
	pv.bg:SetAllPoints()
	pv.bg:SetVertexColor(0, 0, 0, 0.35)
	pv.bd = Ink:Round(pv, "BORDER", true, true)
	pv.bd:SetAllPoints()
	pv.bd:SetVertexColor(1, 1, 1, 0.06)
	pv.l1 = pv:CreateFontString(nil, "OVERLAY")
	pv.l1:SetPoint("TOPLEFT", 12, -12)
	pv.l1:SetPoint("RIGHT", -12, 0)
	pv.l1:SetJustifyH("LEFT")
	pv.l1:SetWordWrap(false)
	pv.l2 = pv:CreateFontString(nil, "OVERLAY")
	pv.l2:SetPoint("TOPLEFT", pv.l1, "BOTTOMLEFT", 0, -6)
	pv.l2:SetPoint("RIGHT", -12, 0)
	pv.l2:SetJustifyH("LEFT")
	pv.l2:SetWordWrap(false)
	pv.l3 = pv:CreateFontString(nil, "OVERLAY")
	pv.l3:SetPoint("TOPLEFT", pv.l2, "BOTTOMLEFT", 0, -6)
	pv.l3:SetPoint("RIGHT", -12, 0)
	pv.l3:SetJustifyH("LEFT")
	pv.l3:SetWordWrap(false)
	for _, l in ipairs({ pv.l1, pv.l2, pv.l3 }) do l:SetShadowColor(0, 0, 0, 0.8); l:SetShadowOffset(1, -1) end
	p.pv = pv
	-- 크기 · 테두리
	local row = CreateFrame("Frame", nil, p)
	row:SetPoint("TOPLEFT", pv, "BOTTOMLEFT", 0, -10)
	row:SetPoint("TOPRIGHT", pv, "BOTTOMRIGHT", 0, -10)
	row:SetHeight(24)
	row.k = Ink:Text(row, F.sans, 11, C.muted, "LEFT")
	row.k:SetPoint("LEFT", 2, 0)
	row.k:SetText("글자 크기")
	row.minus = SmallBtn(row, 24, 24, "−")
	row.minus:SetPoint("LEFT", row.k, "RIGHT", 10, 0)
	row.size = Ink:Text(row, F.numR or F.semi, 12, C.text, "CENTER")
	row.size:SetPoint("LEFT", row.minus, "RIGHT", 4, 0)
	row.size:SetWidth(30)
	row.plus = SmallBtn(row, 24, 24, "+")
	row.plus:SetPoint("LEFT", row.size, "RIGHT", 4, 0)
	row.minus:SetScript("OnClick", function() M:SetSize(CurSize() - 1) end)
	row.plus:SetScript("OnClick", function() M:SetSize(CurSize() + 1) end)
	row.line = SmallBtn(row, 86, 24, "글자 테두리")
	row.line:SetPoint("RIGHT", -96, 0)
	row.line:SetScript("OnClick", function()
		Ink.db.chatOutline = not Ink.db.chatOutline or nil
		local bz = Bz()
		if bz and bz.ApplyChatFont then bz:ApplyChatFont() end
		M:Paint()
	end)
	row.reset = SmallBtn(row, 88, 24, "FOA 기본으로")
	row.reset:SetPoint("RIGHT", 0, 0)
	row.reset:SetScript("OnClick", function()
		Ink.db.chatFontPath, Ink.db.chatFont = nil, nil
		local bz = Bz()
		if bz and bz.ApplyChatFont then bz:ApplyChatFont() end
		M:Paint()
	end)
	p.row = row
	-- 목록
	local sf = CreateFrame("ScrollFrame", nil, p)
	sf:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -10)
	sf:SetPoint("BOTTOMRIGHT", -12, 34)
	local body = CreateFrame("Frame", nil, sf)
	body:SetSize(W - 24, 10)
	sf:SetScrollChild(body)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, d)
		local r = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(math.max(0, math.min(r, self:GetVerticalScroll() - d * 48)))
	end)
	p.sf, p.body, p.rows, p.heads = sf, body, {}, {}
	p.foot = Ink:Text(p, F.sans, 9, C.dim, "LEFT")
	p.foot:SetPoint("BOTTOMLEFT", 16, 12)
	p.foot:SetPoint("BOTTOMRIGHT", -16, 12)
	p.foot:SetWordWrap(true)
	p.foot:SetText("직접 넣은 글꼴: AddOns\\FOA_Fonts 폴더에 넣고 게임을 다시 켜면 여기에 나와요 (많이 쓰는 한글 글꼴 이름만 찾아요)")
	-- 끌어서 옮기기
	p:SetMovable(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", p.StartMoving)
	p:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetLeft(), self:GetTop()
		Ink.db.panelPos = Ink.db.panelPos or {}
		Ink.db.panelPos.chatFont = { x, y }
	end)
	tinsert(UISpecialFrames, "FOAChatFontPicker")
	self.panel = p
	return p
end

local function Head(body)
	local h = CreateFrame("Frame", nil, body)
	h:SetSize(W - 24, 26)
	h.t = Ink:Text(h, F.semi, 11, C.soft, "LEFT")
	h.t:SetPoint("BOTTOMLEFT", 4, 6)
	h.tag = Ink:Text(h, F.sans, 9, C.dim, "LEFT")
	h.tag:SetPoint("LEFT", h.t, "RIGHT", 8, 0)
	h.line = h:CreateTexture(nil, "ARTWORK")
	h.line:SetColorTexture(1, 1, 1, 0.07)
	h.line:SetHeight(1)
	h.line:SetPoint("BOTTOMLEFT", 2, 0)
	h.line:SetPoint("BOTTOMRIGHT", -2, 0)
	return h
end

local function Row(body)
	local r = CreateFrame("Button", nil, body)
	r:SetSize(W - 24, 46)
	r.hl = Ink:Round(r, "BACKGROUND", true, false)
	r.hl:SetAllPoints()
	r.hl:SetVertexColor(1, 1, 1, 0)
	r.bd = Ink:Round(r, "BORDER", true, true)
	r.bd:SetAllPoints()
	r.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0)
	r.bar = r:CreateTexture(nil, "ARTWORK")
	r.bar:SetSize(2, 26)
	r.bar:SetPoint("LEFT", 2, 0)
	r.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	r.w = Ink:Text(r, F.sans, 9, C.muted, "LEFT")
	r.w:SetPoint("TOPLEFT", 12, -7)
	r.check = r:CreateTexture(nil, "OVERLAY")
	r.check:SetTexture(Ink.icon("Check"))
	r.check:SetSize(14, 14)
	r.check:SetPoint("RIGHT", -12, 0)
	r.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	r.sample = r:CreateFontString(nil, "OVERLAY")
	r.sample:SetPoint("BOTTOMLEFT", 12, 7)
	r.sample:SetPoint("RIGHT", -32, 0)
	r.sample:SetJustifyH("LEFT")
	r.sample:SetWordWrap(false)
	r.sample:SetShadowColor(0, 0, 0, 0.8)
	r.sample:SetShadowOffset(1, -1)
	r:SetScript("OnEnter", function(self) if not self.sel then self.hl:SetVertexColor(1, 1, 1, 0.05) end end)
	r:SetScript("OnLeave", function(self) self.hl:SetVertexColor(1, 1, 1, self.sel and 0.04 or 0) end)
	r:SetScript("OnClick", function(self) M:Pick(self.path) end)
	return r
end

function M:Paint()
	local p = self.panel
	if not (p and p:IsShown()) then return end
	local cur, flags = Current()
	local size = CurSize()
	-- 미리 보기
	local pv = p.pv
	local ok = pcall(pv.l1.SetFont, pv.l1, cur, size + 1, flags)
	pcall(pv.l2.SetFont, pv.l2, cur, size + 1, flags)
	pcall(pv.l3.SetFont, pv.l3, cur, size + 1, flags)
	pv.l1:SetText("|cffAAD372[파티]|r |cffFFF468일단|r: 영주의 전당 가실 분? 탱 구해요!")
	pv.l2:SetText("|cffFF7EFF[귓속말]|r 아이언포지 경매장 앞에서 봬요 :)")
	pv.l3:SetText("|cff40C0FF[길드]|r 오늘 9시 화산 심장부 출발합니다 · 1234567890")
	p.row.size:SetText(size)
	local a = C.accent
	local on = Ink.db.chatOutline
	p.row.line.t:SetTextColor(on and a[1] or C.text[1], on and a[2] or C.text[2], on and a[3] or C.text[3])
	p.row.line.bd:SetVertexColor(on and a[1] or 1, on and a[2] or 1, on and a[3] or 1, on and 0.6 or 0.1)
	-- 목록
	for _, r in ipairs(p.rows) do r:Hide() end
	for _, h in ipairs(p.heads) do h:Hide() end
	local y, nr, nh = 0, 0, 0
	local sampleSize = math.max(13, math.min(16, size + 1))
	for _, fam in ipairs(self:Catalog()) do
		nh = nh + 1
		local h = p.heads[nh] or Head(p.body)
		p.heads[nh] = h
		h.t:SetText(fam[1])
		h.tag:SetText(fam[3] == "user" and "직접 넣은 글꼴" or (fam[3] == "game" and "게임" or "FOA"))
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", 0, -y)
		h:Show()
		y = y + 30
		for _, w in ipairs(fam[2]) do
			nr = nr + 1
			local r = p.rows[nr] or Row(p.body)
			p.rows[nr] = r
			r.path = w[1]
			r.sel = (cur or ""):lower() == w[1]:lower()
			r.w:SetText(w[2])
			pcall(r.sample.SetFont, r.sample, w[1], sampleSize, "")
			r.sample:SetText(SAMPLE)
			r.sample:SetTextColor(r.sel and a[1] or C.text[1], r.sel and a[2] or C.text[2], r.sel and a[3] or C.text[3])
			r.bar:SetShown(r.sel)
			r.check:SetShown(r.sel)
			r.hl:SetVertexColor(1, 1, 1, r.sel and 0.04 or 0)
			r.bd:SetVertexColor(a[1], a[2], a[3], r.sel and 0.35 or 0)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -y)
			r:Show()
			y = y + 48
		end
		y = y + 4
	end
	p.body:SetHeight(math.max(10, y))
end

function M:Toggle(anchor)
	local p = self.panel or self:Build()
	if p:IsShown() then p:Hide() return end
	p:ClearAllPoints()
	local pos = Ink.db.panelPos and Ink.db.panelPos.chatFont
	if pos then
		p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
	elseif anchor then
		p:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 8, 0)
	else
		p:SetPoint("CENTER")
	end
	p:Show()
	self:Paint()
end

-------------------------------------------------------------------------------
-- 채팅창 오른쪽 위 톱니바퀴 (평소엔 흐리게, 채팅창에 마우스를 올리면 또렷하게)
-------------------------------------------------------------------------------
function M:BuildGear()
	local cf = _G.ChatFrame1
	if not cf or self.gear then return end
	local g = CreateFrame("Button", "FOAChatFontGear", UIParent)
	g:SetSize(20, 20)
	g:SetFrameStrata("MEDIUM")
	g:SetFrameLevel((cf:GetFrameLevel() or 1) + 20)
	-- FOA 채팅 배경(위로 30, 오른쪽으로 10 넓다) 안쪽 오른쪽 위 모서리, 탭 줄 높이
	g:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 6, 26)
	g.bg = g:CreateTexture(nil, "BACKGROUND")
	g.bg:SetTexture(Ink.tex.disc)
	g.bg:SetAllPoints()
	g.bg:SetVertexColor(1, 1, 1, 0)
	g.i = g:CreateTexture(nil, "ARTWORK")
	g.i:SetTexture(Ink.icon("Gear"))
	g.i:SetSize(13, 13)
	g.i:SetPoint("CENTER")
	g.i:SetVertexColor(C.soft[1], C.soft[2], C.soft[3])
	g:SetAlpha(0.45)
	local spin = g.i:CreateAnimationGroup()
	local r = spin:CreateAnimation("Rotation")
	r:SetDegrees(-60); r:SetDuration(0.35); r:SetSmoothing("OUT")
	g:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		self.bg:SetVertexColor(1, 1, 1, 0.08)
		self.i:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
		spin:Play()
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
		GameTooltip:AddLine("채팅 글꼴", 1, 1, 1)
		GameTooltip:AddLine("글꼴 · 굵기 · 크기 · 테두리를 미리 보고 고르기", 0.7, 0.72, 0.75)
		GameTooltip:Show()
	end)
	g:SetScript("OnLeave", function(self)
		self:SetAlpha(0.45)
		self.bg:SetVertexColor(1, 1, 1, 0)
		self.i:SetVertexColor(C.soft[1], C.soft[2], C.soft[3])
		GameTooltip:Hide()
	end)
	g:SetScript("OnClick", function(self) M:Toggle(self) end)
	self.gear = g
end

function M:Init()
	if Ink.db.chatFontGear == false then return end
	local e = CreateFrame("Frame")
	e:RegisterEvent("PLAYER_LOGIN")
	e:SetScript("OnEvent", function() C_Timer.After(1, function() pcall(M.BuildGear, M) end) end)
	if IsLoggedIn and IsLoggedIn() then C_Timer.After(1, function() pcall(M.BuildGear, M) end) end
end
