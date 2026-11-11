-- FOA UI · 설정 시트 (04 Dock)
--  아래에서 스프링으로 올라오는 독립 설정 창. 위쪽 게임 화면이 그대로 보여서 바꾸는 즉시 확인한다.
--  · 분류 독(아이콘 타일) + 스프링으로 미끄러지는 받침
--  · 본문은 3칸 묶음 (스위치 · 단계 · 고르기 · 슬라이더 · 버튼)
--  · 설정 줄에 마우스를 올리면 그 설정이 바꾸는 화면 요소를 짚어 준다
--  · 기본값과 다른 설정엔 노란 점, /reload 가 필요한 설정은 주황 표시 + 아래 "다시 불러오기"
--  · 검색 · ESC 로 닫기 · 위 손잡이를 끌어 높이 조절 · 눈 버튼을 누르고 있으면 시트가 비쳐 보임
--  · 전투가 시작되면 닫힌다 (전투 중에는 열 수 없음)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Sheet")
local F, C = Ink.font, Ink.c

local MEDIA = "Interface\\AddOns\\FOA_UI\\Media\\"
local DISC = MEDIA .. "Textures\\Disc"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local K = 0.02   -- Disc 이미지 가장자리 여백 (128 중 2.5) 을 잘라 모서리와 직선이 딱 맞게

local BG = { 0.059, 0.067, 0.082 }      -- 시트 바탕
local RAISE = { 0.118, 0.129, 0.161 }   -- 독 받침
local SEGON = { 0.165, 0.180, 0.216 }   -- 단계 버튼 고른 칸
local INK = { 0.067, 0.075, 0.094 }     -- 노란 바탕 위 글자 · 켜진 스위치 손잡이

local EXTRA = 64      -- 화면 아래로 숨겨 둔 여분 (스프링이 넘쳐도 바닥이 비지 않게)
local HEAD = 128      -- 손잡이 + 독 높이
local FOOT = 64       -- 아래 줄 높이
local PADX = 30       -- 좌우 여백
local TILE_W, TILE_H, TILE_GAP = 88, 76, 6

-------------------------------------------------------------------------------
-- 움직임: 설정 "효과 → 설정 창 움직임" (끄기 / 은은하게 / 풍부하게)
-------------------------------------------------------------------------------
local function MotionMode() return Ink.db and Ink.db.sheetMotion or "soft" end
local function Motion()
	local m = MotionMode()
	if m == "off" then return 0 end
	return m == "rich" and 1.3 or 1
end
local function Over() return MotionMode() == "rich" and 1.7 or 1.15 end

local E = {}
function E.out(p) return 1 - (1 - p) ^ 3 end
function E.out5(p) return 1 - (1 - p) ^ 5 end
function E.inn(p) return p * p * p end
function E.back(p, s)
	s = s or Over()
	local q = p - 1
	return 1 + (s + 1) * q * q * q + s * q * q
end
function E.knob(p) return E.back(p, MotionMode() == "rich" and 2.6 or 1.9) end
function E.pop(p)
	if p < 0.65 then return 1.55 * (p / 0.65) end
	return 1.55 - 0.55 * ((p - 0.65) / 0.35)
end
local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end
local function lerp(a, b, t) return a + (b - a) * t end

-- 아주 작은 트윈 엔진: (id, ch) 같은 것은 새로 시작하면 이전 것을 취소한다
local tweens = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
	local now = GetTime()
	local i = 1
	while i <= #tweens do
		local t = tweens[i]
		local p = (now - t.start) / t.dur
		if p >= 0 then
			if p > 1 then p = 1 end
			local ok = pcall(t.step, t.ease(p))
			if p >= 1 or not ok then
				table.remove(tweens, i)
				if t.done then pcall(t.done) end
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	if #tweens == 0 then driver:Hide() end
end)

local function Cancel(id, ch)
	for i = #tweens, 1, -1 do
		local t = tweens[i]
		if t.id == id and t.ch == ch then table.remove(tweens, i) end
	end
end

local function Tween(id, ch, dur, ease, step, done, delay)
	Cancel(id, ch)
	local k = Motion()
	dur = (dur or 0.3) * k
	if dur <= 0.001 then
		step(1)
		if done then done() end
		return
	end
	tweens[#tweens + 1] = { id = id, ch = ch, start = GetTime() + (delay or 0) * k, dur = dur, ease = ease or E.out, step = step, done = done }
	driver:Show()
end
M.Tween, M.E = Tween, E

-------------------------------------------------------------------------------
-- 모양 도구: 반지름 자유 둥근 사각형 / 알약 / 그라데이션
-------------------------------------------------------------------------------
-- inset: 바깥에서 그만큼 안쪽으로 (같은 프레임에 테두리 + 안쪽 바탕을 겹쳐 그릴 때)
local function RoundRect(parent, layer, sub, r, topOnly, inset)
	local o = { t = {} }
	local i = inset or 0
	local function tex(file)
		local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
		t:SetTexture(file)
		o.t[#o.t + 1] = t
		return t
	end
	local function corner(point, x, y, l, rr, tt, b)
		local t = tex(DISC)
		t:SetTexCoord(l, rr, tt, b)
		t:SetSize(r, r)
		t:SetPoint(point, x, y)
	end
	corner("TOPLEFT", i, -i, K, 0.5, K, 0.5)
	corner("TOPRIGHT", -i, -i, 0.5, 1 - K, K, 0.5)
	local mid = tex(WHITE)
	mid:SetPoint("TOPLEFT", r + i, -i)
	mid:SetPoint("BOTTOMRIGHT", -(r + i), topOnly and 0 or i)
	local lt = tex(WHITE)
	lt:SetPoint("TOPLEFT", i, -(r + i))
	local rt = tex(WHITE)
	rt:SetPoint("TOPRIGHT", -i, -(r + i))
	if topOnly then
		lt:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", r + i, 0)
		rt:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", -(r + i), 0)
	else
		corner("BOTTOMLEFT", i, i, K, 0.5, 0.5, 1 - K)
		corner("BOTTOMRIGHT", -i, i, 0.5, 1 - K, 0.5, 1 - K)
		lt:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", r + i, r + i)
		rt:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", -(r + i), r + i)
	end
	function o:Color(cr, cg, cb, ca)
		for _, t in ipairs(self.t) do t:SetVertexColor(cr, cg, cb, ca or 1) end
	end
	function o:SetShown(on)
		for _, t in ipairs(self.t) do t:SetShown(on) end
	end
	return o
end

-- 알약 (높이 h 고정, 양끝 반원)
local function Pill(parent, layer, sub, h)
	local o = { t = {} }
	local r = h / 2
	local L = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	L:SetTexture(DISC); L:SetTexCoord(K, 0.5, K, 1 - K); L:SetSize(r, h); L:SetPoint("LEFT")
	local R = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	R:SetTexture(DISC); R:SetTexCoord(0.5, 1 - K, K, 1 - K); R:SetSize(r, h); R:SetPoint("RIGHT")
	local Mi = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	Mi:SetTexture(WHITE); Mi:SetPoint("TOPLEFT", r, 0); Mi:SetPoint("BOTTOMRIGHT", -r, 0)
	o.t = { L, R, Mi }
	function o:Color(cr, cg, cb, ca)
		for _, t in ipairs(self.t) do t:SetVertexColor(cr, cg, cb, ca or 1) end
	end
	return o
end

local function Grad(t, orient, c, a1, a2)
	t:SetTexture(WHITE)
	if CreateColor and t.SetGradient then
		local ok = pcall(t.SetGradient, t, orient, CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
		if ok then return end
	end
	t:SetVertexColor(c[1], c[2], c[3], (a1 + a2) / 2)
end

local function Icon(parent, name, size, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(Ink.icon(name))
	t:SetSize(size, size)
	return t
end

local function Sound(kind)
	if not (PlaySound and SOUNDKIT) then return end
	local id = kind == "open" and SOUNDKIT.IG_MAINMENU_OPEN or kind == "close" and SOUNDKIT.IG_MAINMENU_CLOSE
		or SOUNDKIT.U_CHAT_SCROLL_BUTTON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
	if id then pcall(PlaySound, id) end
end

-- 시트 버튼: ghost(바탕 없음) / outline(노란 테두리) / primary(노란 바탕) / text(노란 글자)
local function Btn(parent, text, style, icon, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(36)
	b.style = style or "ghost"
	if b.style == "outline" then
		b.edge = RoundRect(b, "BACKGROUND", 0, 10)
		b.fill = RoundRect(b, "BACKGROUND", 1, 9, false, 1)
	else
		b.fill = RoundRect(b, "BACKGROUND", 0, 10)
	end
	if icon then
		b.icon = Icon(b, icon, 16)
		b.icon:SetPoint("LEFT", 14, 0)
	end
	b.text = Ink:Text(b, F.semi, 13, C.text, "LEFT")
	b.text:SetPoint("LEFT", icon and 38 or 16, 0)
	b.text:SetText(text)
	function b:Fit()
		local w = math.ceil(self.text:GetStringWidth() or 0)
		self:SetWidth(math.max(self.minW or 0, w + (self.icon and 38 or 16) + 16))
	end
	function b:Paint()
		local a = C.accent
		local hot, on = self.hot, self.on
		if self.style == "primary" then
			self.fill:Color(a[1], a[2], a[3], hot and 1 or 0.92)
			self.text:SetTextColor(INK[1], INK[2], INK[3])
			if self.icon then self.icon:SetVertexColor(INK[1], INK[2], INK[3]) end
		elseif self.style == "outline" then
			self.edge:Color(a[1], a[2], a[3], hot and 0.8 or 0.45)
			self.fill:Color(BG[1] + (hot and 0.03 or 0), BG[2] + (hot and 0.03 or 0), BG[3] + (hot and 0.02 or 0), 1)
			self.text:SetTextColor(a[1], a[2], a[3])
			if self.icon then self.icon:SetVertexColor(a[1], a[2], a[3]) end
		elseif self.style == "text" then
			self.fill:Color(a[1], a[2], a[3], hot and 0.1 or 0)
			self.text:SetTextColor(a[1], a[2], a[3])
			if self.icon then self.icon:SetVertexColor(a[1], a[2], a[3]) end
		else
			if on then
				self.fill:Color(a[1], a[2], a[3], hot and 0.2 or 0.14)
				self.text:SetTextColor(a[1], a[2], a[3])
				if self.icon then self.icon:SetVertexColor(a[1], a[2], a[3]) end
			else
				self.fill:Color(1, 1, 1, hot and 0.07 or 0)
				local c = hot and C.text or C.soft
				self.text:SetTextColor(c[1], c[2], c[3])
				if self.icon then self.icon:SetVertexColor(c[1], c[2], c[3]) end
			end
		end
	end
	function b:SetOn(on) self.on = on; self:Paint() end
	b:SetScript("OnEnter", function(self) self.hot = true; self:Paint() end)
	b:SetScript("OnLeave", function(self) self.hot = nil; self:Paint() end)
	if onClick then b:SetScript("OnClick", onClick) end
	b:Fit()
	b:Paint()
	return b
end

-------------------------------------------------------------------------------
-- 설정 목록 (분류 → 묶음 → 줄)
--  kind: switch / seg(단계) / cycle(‹ 값 ›) / slider / action(버튼)
--  reload = /reload 해야 적용 · hud = 짚어 줄 화면 요소(편집 모드 키) · dep = 이 설정이 켜져야 쓸 수 있음
-------------------------------------------------------------------------------
local function mod(name) return Ink.modules[name] end
local function call(name, fn, ...)
	local m = mod(name)
	if m and m[fn] then return pcall(m[fn], m, ...) end
end

local CATS = {
	{ id = "general", label = "일반", icon = "Sliders" },
	{ id = "frames", label = "프레임", icon = "Character" },
	{ id = "bars", label = "행동단축바", icon = "Keyboard" },
	{ id = "plates", label = "이름표", icon = "Tag" },
	{ id = "map", label = "지도 · 퀘스트", icon = "Map" },
	{ id = "dungeon", label = "던전 · BIS", icon = "Journal" },
	{ id = "grow", label = "성장", icon = "Spells" },
	{ id = "bags", label = "가방 · 상인", icon = "Bag" },
	{ id = "combat", label = "전투", icon = "Swords" },
	{ id = "fx", label = "효과", icon = "Sparkles" },
}
M.CATS = CATS

-- 현황 아이콘 고르기 줄 (칩 목록 · 캐릭터별로 저장)
local function TR(fn, ...)
	local t = Ink.modules.Tracker
	if not (t and t[fn]) then return end
	local ok, a, b = pcall(t[fn], t, ...)
	if ok then return a, b end
end

local function Picks(id, sec, label, desc, empty)
	return { kind = "picks", id = id, label = label, desc = desc, empty = empty, dep = "tracker", hud = "tracker",
		items = function() return TR("PickItems", sec) or {} end,
		state = function(it) return TR("PickState", it.key) end,
		toggle = function(it) TR("TogglePick", it.key, it.kind) end,
		changed = function() return TR("PickChanged", sec) end,
		set = function() TR("ClearPicks", sec) end }
end

local function SW(key, label, desc, o)
	o = o or {}
	o.kind, o.key, o.label, o.desc = "switch", key, label, desc
	return o
end

function M:BuildRegistry()
	local Q = mod("Quest")
	local fontOpts = {}
	for _, k in ipairs(Ink.FONT_SETS or { "foa" }) do fontOpts[#fontOpts + 1] = { k, (Ink.FONT_NAME or {})[k] or k } end
	local soundOpts = {}
	if Q and Q.SOUNDS then
		for _, k in ipairs(Q.SOUNDS) do soundOpts[#soundOpts + 1] = { k, Q.SOUND_NAME[k] or k } end
	end
	local function chatFont() call("Blizzard", "ApplyChatFont") end
	local function quests() call("Quest", "Update") end
	local function questMap()
		local qm = mod("QuestMap")
		if qm and qm.Queue then pcall(qm.Queue, qm) elseif qm and qm.Refresh then pcall(qm.Refresh, qm) end
	end
	local function worldMap()
		if WorldMapFrame and WorldMapFrame:IsShown() then call("Map", "Refresh") end
	end

	local G = {
		general = {
			{ t = "화면", rows = {
				{ kind = "cycle", id = "aspect", label = "화면 비율", desc = "비율마다 배치를 따로 저장해요",
					opts = { { "auto", "자동" }, { "16:10", "16:10" }, { "16:9", "16:9" }, { "21:9", "21:9" }, { "32:9", "32:9" } },
					def = "auto", get = function() return Ink.cdb.aspect or "auto" end,
					set = function(v) Ink:SetAspect(v) end },
				SW("pixelPerfect", "UI 픽셀 맞춤", "선 · 테두리가 번지지 않게 UI 크기를 맞춰요", { def = false,
					set = function(v) call("Config", "SetPixelPerfect", v) end }),
				{ kind = "seg", id = "gfx", label = "그래픽 프리셋", desc = "처음 바꿀 때 원래 값을 기억해 둬요",
					opts = { { "none", "원래" }, { "perf", "성능" }, { "balanced", "균형" }, { "quality", "화질" } },
					def = "none", get = function() return Ink.db.gfxPreset or "none" end,
					set = function(v) call("Config", "ApplyGraphics", v == "none" and "restore" or v) end },
			} },
			{ t = "글자", rows = {
				{ kind = "seg", key = "fontSet", label = "글꼴", desc = "작은 글자가 뭉개지면 선명한 글꼴", opts = fontOpts, def = "foa", reload = true },
				{ kind = "seg", key = "renderMode", label = "화면 선명도", desc = "자동이면 모니터 세로 픽셀로 골라요",
					opts = { { "auto", "자동" }, { "1x", "1080p" }, { "q", "QHD" }, { "2x", "4K" } }, def = "auto", reload = true },
				{ kind = "cycle", id = "chatFont", label = "채팅 글꼴", desc = "채팅창 톱니바퀴로 미리 보며 고를 수도 있어요",
					opts = { { "set", "FOA 따라감" }, { "game", "게임 기본" }, { "pretendard", "선명한 글꼴" }, { "mubig", "무빅" } },
					def = "set", other = "직접 고른 글꼴",
					get = function() return Ink.db.chatFontPath and "pick" or (Ink.db.chatFont or "set") end,
					set = function(v) Ink.db.chatFont = v; Ink.db.chatFontPath = nil end, apply = chatFont },
				SW("chatOutline", "채팅 글자 테두리", "밝은 배경에서도 또렷하게", { def = false, apply = chatFont }),
				SW("chatArrows", "채팅 화살표로 지난 글", "입력창에서 위 · 아래 화살표로 보냈던 글 다시 부르기", { def = true,
					apply = function() call("Blizzard", "SetupChatHistory") end }),
			} },
			{ t = "화면 구성", rows = {
				SW("launcher", "진영 메뉴", "왼쪽 위 진영 문양 메뉴", { reload = true, hud = "launcher" }),
				SW("clock", "화면 위 시계", "누르면 서버 시간", { reload = true, hud = "clock" }),
				SW("combatHide", "전투 중 시계 · 메뉴 숨기기", "전투가 시작되면 위 시계와 문양을 숨겨요", { hud = "clock" }),
				SW("hideTutorials", "튜토리얼 끄기", "노란 안내 상자 · 화살표 · 말풍선", { reload = true }),
				SW("windows", "기본 창 · 글꼴 (실험)", "블리자드 창 껍데기와 글꼴 바꾸기", { reload = true, def = false }),
			} },
			{ t = "현황 아이콘", rows = {
				SW("tracker", "현황 아이콘", "전문기술 · 무기 숙련 · 평판을 둥근 아이콘으로 · 오르면 톡 튀어요", { reload = true, hud = "tracker" }),
				SW("trackerWeapons", "무기 숙련 자동", "써 본 무기 중 아직 다 안 올린 것 4개까지 알아서", { dep = "tracker", hud = "tracker", apply = function() call("Tracker", "Update") end }),
				SW("trackerReps", "평판 자동", "추적 중인 평판 + 이번 접속에서 오른 평판", { dep = "tracker", hud = "tracker", apply = function() call("Tracker", "Update") end }),
			} },
			{ t = "현황 아이콘 고르기", rows = {
				Picks("trackerPickProf", "prof", "전문기술", "누르면 켜고 끄기", "배운 전문기술이 없어요"),
				Picks("trackerPickWeapon", "weapon", "무기 숙련 · 방어", "누르면 고정 · 한 번 더 누르면 빼기", "무기 숙련이 없어요"),
				Picks("trackerPickRep", "rep", "평판", "고른 평판은 늘 보여요 · 노란 점 = 고정", "아직 만난 진영이 없어요"),
			} },
			{ t = "미니맵", rows = {
				SW("mmArcane", "아케인 미니맵", "금세공 모서리 · 위 나침반 띠 · 아래 지역 이름과 레벨", { reload = true, hud = "minimap" }),
				SW("mmSigil", "뒤에서 도는 마법진", "미니맵 뒤로 은은하게 비쳐요", { dep = "mmArcane", hud = "minimap",
					apply = function() call("Blizzard", "ApplyArcaneOptions") end }),
				SW("mmRibbon", "나침반 띠", "보는 방향에 맞춰 흘러요 · 길 안내 중인 곳은 금색 마름모", { dep = "mmArcane", hud = "minimap",
					apply = function() call("Blizzard", "ApplyArcaneOptions") end }),
				SW("mmSoftEdge", "가장자리 번짐", "지도 끝이 게임 화면에 녹아들게", { dep = "mmArcane", hud = "minimap",
					apply = function() call("Blizzard", "ApplyArcaneOptions") end }),
			} },
		},
		frames = {
			{ t = "플레이어 · 대상", rows = {
				SW("unitPortrait", "초상화", "플레이어는 왼쪽 · 대상은 오른쪽에 둥근 얼굴 · 직업색 고리", { def = false, hud = { "player", "target" },
					apply = function() call("Units", "UpdateAll") end }),
			} },
			{ t = "파티 · 레이드", rows = {
				SW("party", "파티 프레임", "FOA 파티 프레임", { reload = true, hud = "party" }),
				SW("raid", "레이드 프레임", "FOA 레이드 프레임", { reload = true, hud = "raid" }),
			} },
			{ t = "정보 막대", rows = {
				SW("xp", "경험치 바", "얇은 FOA 경험치 바", { reload = true, hud = "xp" }),
				SW("range", "사거리 표시", "빨강 밖 · 노랑 끝 · 초록 안 · 주황 근접", { reload = true, hud = "range" }),
			} },
			{ t = "창", rows = {
				SW("charSheet", "캐릭터 창", "FOA 스타일 · BIS 탭", { reload = true }),
				{ kind = "seg", key = "charSlotText", label = "장비 칸 옆 글자", desc = "마법부여 · 보석 효과를 짧게 (민+2 체+8) 또는 아이템 이름", dep = "charSheet",
					opts = { { "ench", "마부 · 보석" }, { "name", "아이템 이름" } }, def = "ench",
					apply = function() call("Character", "PaintAll") end },
			} },
		},
		bars = {
			{ t = "행동단축바", rows = {
				SW("actionBars", "FOA 행동단축바", "버튼 수 · 줄 · 크기 · 간격은 편집 모드에서", { reload = true, hud = { "bar1", "bar2" } }),
				SW("barLock", "잠금", "Shift 를 누른 채 끌어야 기술이 빠져요", { hud = { "bar1", "bar2" },
					apply = function() call("ActionBars", "ApplyLock") end }),
				SW("autoPush", "새 주문 자동 배치", "새로 배운 주문을 빈 칸에", { hud = "bar1",
					apply = function() call("Blizzard", "ApplyAutoPush") end }),
			} },
			{ t = "바로 가기", rows = {
				{ kind = "action", id = "act:kb", label = "단축키 지정", desc = "칸에 마우스를 올리고 키를 누르면 끝", btn = "단축키 모드",
					fn = function() M:Close(); Ink:OpenQuickKeybind() end },
				{ kind = "action", id = "act:edit", label = "바 모양 바꾸기", desc = "버튼 수 · 줄 · 크기 · 간격 · 빈칸", btn = "편집 모드",
					fn = function() M:ToEdit() end },
			} },
		},
		plates = {
			{ t = "이름표", rows = {
				SW("plates", "FOA 이름표", "레벨 색 · 퀘스트 진행 · 정예 테두리", { reload = true }),
			} },
			{ t = "표시", rows = {
				SW("npcIcons", "NPC 역할 아이콘", "상인 · 수리 · 여관 등 머리 위에"),
				SW("questObjects", "퀘스트 물체 배지", "줍기 · 부수기 물체 위에 노란 배지"),
				SW("questSparkle", "퀘스트 물체 반짝임", "배지 주위로 별이 반짝이고 빛이 퍼져요 · 몬스터 전리품처럼", { dep = "questObjects" }),
			} },
		},
		map = {
			{ t = "세계 지도", rows = {
				SW("mapLayer", "지도 표시", "비행 지점 · 주요 NPC · 배편 · 도서관 책", { reload = true }),
				SW("mapReveal", "지도 밝히기", "안 가 본 곳도 살짝 어둡게 보여 줘요", { apply = worldMap }),
				SW("mapEntrances", "던전 입구", "누르면 전리품 · 진행 경로", { apply = worldMap }),
				SW("mapFieldTrainers", "마을의 내 상급자", "필드 마을엔 내 직업 · 배운 전문기술 상급자만 · 지나가면 자리를 배워요", { apply = worldMap }),
				SW("mapZoneLevel", "지역 적정 레벨", "지도 왼쪽 위 · 대륙 지도에선 마우스를 올린 지역 · 내 레벨에 맞춰 색", { def = true, apply = worldMap }),
				SW("mapScaleUp", "창 지도 크게", "창으로 띄운 세계 지도 크기", { def = false,
					apply = function() call("Map", "ApplyScale") end }),
				{ kind = "slider", key = "mapScalePct", label = "지도 크기", min = 100, max = 150, step = 5, fmt = "%d%%", def = 130,
					dep = "mapScaleUp", apply = function() call("Map", "ApplyScale") end },
			} },
			{ t = "지도의 퀘스트", rows = {
				SW("questMap", "받을 수 있는 퀘스트", "지도에 느낌표 · 누르면 길 안내", { reload = true }),
				SW("questMapLow", "낮은 퀘스트도", "회색 퀘스트까지 보여 줘요", { def = false, dep = "questMap", apply = questMap }),
				SW("questTurnIn", "보고할 곳 물음표", "다 끝낸 퀘스트 보고 위치", { apply = questMap }),
				SW("questMinimap", "미니맵에 퀘스트", "범위 밖은 가까운 3개만 테두리에", { reload = true, hud = "minimap" }),
			} },
			{ t = "퀘스트 목록", rows = {
				{ kind = "slider", key = "questMax", label = "한 번에 보이는 수", min = 3, max = 10, step = 1, fmt = "%d개", def = 6,
					hud = "quest", apply = quests },
				SW("questClass", "직업 퀘스트", "받을 수 있는 직업 퀘스트를 맨 위에", { hud = "quest", apply = quests }),
				SW("questToast", "완료 알림", "목표를 다 채우면 위에 카드"),
				{ kind = "cycle", key = "questSound", label = "완료 소리", desc = "바꾸면 미리 들려줘요", opts = soundOpts, def = "random",
					apply = function() call("Quest", "PlayDoneSound") end },
			} },
		},
		dungeon = {
			{ t = "던전", rows = {
				SW("dungeon", "던전 전리품 · BIS", "지도 옆 보스별 전리품 · 캐릭터 창 BIS 탭", { reload = true }),
				SW("dungeonBoard", "던전 안 큰 던전 화면", "지도 대신 진행 경로 · 전리품"),
			} },
			{ t = "BIS 후보", rows = {
				SW("bisCrafts", "제작템", "경매장 가격 · 제조법 상인까지"),
				SW("bisQuests", "퀘스트 보상", "내 진영 · 직업 · 아직 안 깬 것만"),
				SW("bisWorld", "월드 · 필드 · 상인 · 평판", "월드 드랍 · 필드 몹 · 필드 희귀몹 · 던전 일반 몹 · 상인 · 평판 보상"),
			} },
			{ t = "아이템 비교", rows = {
				{ kind = "seg", id = "compare", label = "비교 기준", desc = "가방 · 보상 화살표 · 툴팁에 착용 대비 %",
					opts = { { "pve", "PvE" }, { "pvp", "PvP" }, { "off", "끄기" } }, def = "pve",
					get = function() return Ink.db.itemCompare == false and "off" or (Ink.cdb.scoreMode or "pve") end,
					set = function(v)
						Ink.db.itemCompare = v ~= "off"
						if v ~= "off" then Ink.cdb.scoreMode = v end
						if ns.Score and ns.Score.Invalidate then pcall(ns.Score.Invalidate, ns.Score) end
					end },
			} },
			{ t = "장비 도우미", rows = {
				SW("gearPopup", "칸 업그레이드 창", "캐릭터 창 장비 칸을 오른쪽 클릭 · 지금 레벨 후보 순위 · 내 특성 추천 마법부여"),
				SW("gearSlotRank", "툴팁에 칸 순위", "그 칸에서 몇 점짜리인지 · 지금 레벨 최고템 = 100"),
				SW("gearToast", "최고 장비 획득 알림", "칸 1순위 템이나 착용보다 15% 넘게 좋은 템을 얻으면 화면 위에 알림 · 누르면 캐릭터 창"),
			} },
		},
		grow = {
			{ t = "포에버 안내", rows = {
				SW("talentGuide", "특성 가이드", "다음에 찍을 특성 강조 · 포인트 알림"),
				SW("training", "배울 기술", "마법책 옆에 지금 · 다음 레벨 기술"),
			} },
			{ t = "전문기술", rows = {
				SW("profGuide", "전문기술 안내", "구간별 만들 것 · 재료 · 배울 제조법"),
			} },
		},
		bags = {
			{ t = "가방", rows = {
				SW("bags", "FOA 가방", "분류별로 정리되는 가방", { reload = true, hud = "bags" }),
				SW("itemCountTip", "툴팁에 보유 개수", "가방 · 은행 · 다른 캐릭터가 몇 개 갖고 있는지 · 은행은 마지막으로 열었을 때 기준"),
			} },
			{ t = "상인", rows = {
				SW("sellJunk", "잡동사니 자동 판매", "상인 창을 열면 회색 아이템"),
				SW("autoRepair", "자동 수리", "상인 창을 열면 장비 수리"),
				SW("guildRepair", "길드 자금으로 수리", "가능하면 길드 자금 먼저", { dep = "autoRepair" }),
			} },
			{ t = "편의", rows = {
				SW("oneTouchFish", "원터치 낚시", "낚싯대를 들었을 때 오른쪽 두 번 클릭으로 던지고 · 찌가 뜨면 같은 동작으로 낚아채기 · 단축키도 가능",
					{ apply = function() call("Fishing", "Refresh") end }),
				SW("speedyLoot", "빠른 자동 줍기", "자동 줍기일 때 전리품 창을 기다리지 않고 한 번에 · 가방이 차면 원래 창이 떠요"),
			} },
			{ t = "경매장", rows = {
				SW("ahTooltip", "툴팁에 경매장 가격", "가격 스캔으로 받은 최저 단가"),
				SW("ahAuto", "자동 가격 스캔", "경매장에 들어가면 15분마다"),
			} },
		},
		combat = {
			{ t = "미터기", rows = {
				SW("meter", "피해량 미터기", "피해량 · 치유량", { reload = true, hud = "meter" }),
				SW("threat", "위협 수준", "미터기 옆 어그로 막대", { reload = true, hud = "threat", dep = "meter" }),
				{ kind = "seg", key = "meterReset", label = "인스턴스 들어갈 때", desc = "미터기 기록 지우기", dep = "meter",
					opts = { { "ask", "묻기" }, { "auto", "자동 지우기" }, { "off", "그대로" } }, def = "ask" },
			} },
			{ t = "알림", rows = {
				SW("bossMod", "보스 알림", "패턴 타이머 · 경고", { reload = true, hud = { "bossWarn", "bossBars" } }),
				SW("bossSound", "보스 시전 소리", "블리자드 보스 정보가 없는 던전에서 보스가 기술을 쓸 때 경고음", { dep = "bossMod" }),
			} },
		},
		fx = {
			{ t = "설정 창", rows = {
				{ kind = "seg", key = "sheetMotion", label = "움직임", desc = "열고 닫기 · 분류 바꾸기 애니메이션",
					opts = { { "off", "끄기" }, { "soft", "은은하게" }, { "rich", "풍부하게" } }, def = "soft" },
			} },
		},
	}

	-- 효과: FX 목록을 성격별 묶음으로
	if ns.FX and ns.FX.LIST then
		local SET = {
			cdReady = "bar", procBracket = "bar", press = "bar", rangeDesat = "bar",
			dispelPulse = "group", deathFade = "group", readyCheck = "group",
			levelUp = "alert", questPop = "alert", questDone = "alert", lootToast = "alert", mailRipple = "alert",
			bossDrop = "alert", meterSlide = "alert", meterGlow = "alert",
		}
		local groups = { combat = { t = "전투", rows = {} }, bar = { t = "행동단축바", rows = {} },
			group = { t = "파티", rows = {} }, alert = { t = "알림", rows = {} } }
		for _, d in ipairs(ns.FX.LIST) do
			local k = d[1]
			local g = groups[SET[k] or "combat"]
			g.rows[#g.rows + 1] = { kind = "switch", id = "fx:" .. k, label = d[2], desc = d[3], reload = d[4] and true or nil, def = true,
				get = function() return ns.FX.on(k) end, set = function(v) ns.FX.set(k, v) end }
		end
		for _, k in ipairs({ "combat", "bar", "group", "alert" }) do
			if #groups[k].rows > 0 then table.insert(G.fx, groups[k]) end
		end
	end

	self.groups = G
	self.entries, self.byId = {}, {}
	for _, c in ipairs(CATS) do
		for _, g in ipairs(G[c.id] or {}) do
			for _, e in ipairs(g.rows) do
				e.id = e.id or e.key
				e.cat = c.id
				if e.def == nil and e.key and e.kind == "switch" then
					local d = Ink.defaults and Ink.defaults[e.key]
					if d == nil then d = true end
					e.def = d
				end
				self.entries[#self.entries + 1] = e
				self.byId[e.id] = e
			end
		end
	end
end

local function Get(e)
	if e.get then return e.get() end
	local v = Ink.db[e.key]
	if v == nil then v = e.def end
	if e.kind == "switch" then return v and true or false end
	return v
end

local function Set(e, v)
	if e.set then e.set(v) else Ink.db[e.key] = v end
	if e.apply then pcall(e.apply, v) end
end

local function Changed(e)
	if e.kind == "action" then return false end
	if e.kind == "picks" then return e.changed and e.changed() and true or false end
	return Get(e) ~= e.def
end

local function DepOK(e)
	if not e.dep then return true end
	local d = M.byId and M.byId[e.dep]
	if d then return Get(d) and true or false end
	return Ink.db[e.dep] ~= false
end

local function OptIndex(e, v)
	for i, o in ipairs(e.opts or {}) do if o[1] == v then return i end end
end

local function OptLabel(e, v)
	local i = OptIndex(e, v)
	return i and e.opts[i][2] or (e.other or tostring(v))
end

-------------------------------------------------------------------------------
-- 설정 줄
-------------------------------------------------------------------------------
local Row = {}
Row.__index = Row

local SW_W, SW_H, KNOB = 46, 26, 20

local function RowEnter(r)
	if r.hover then return end
	r.hover = true
	Tween(r, "hl", 0.16, E.out, function(p) r.hl:Color(1, 1, 1, 0.04 * p) end)
	if r.e.kind == "switch" then r:PaintSwitch(r.swP or 0) end
	if r.e.kind == "slider" then r:PaintSlider() end
	M:SpotFor(r.e)
end

local function RowLeave(r)
	if r:IsMouseOver() then return end
	r.hover = nil
	r.pressed = nil
	local from = 0.04
	Tween(r, "hl", 0.22, E.out, function(p) r.hl:Color(1, 1, 1, from * (1 - p)) end)
	if r.e.kind == "switch" then r:PaintSwitch(r.swP or 0) end
	M:SpotLeave()
end

-- 줄 안의 작은 버튼(단계 · 화살표 · 바로 가기)이 마우스를 받아도 줄 강조는 유지
local function Child(r, w)
	w:HookScript("OnEnter", function() RowEnter(r) end)
	w:HookScript("OnLeave", function() RowLeave(r) end)
end

-- 고르기 칩 (현황 아이콘 고르기): 아이콘/글자 + 이름 + 작은 값 · 켜지면 노랗게
local PICK_H = 30
local function NewPickChip(r, parent)
	local c = CreateFrame("Button", nil, parent)
	c:SetHeight(PICK_H)
	c:RegisterForClicks("LeftButtonUp")
	c.bg = Pill(c, "BACKGROUND", 2, PICK_H)
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetSize(18, 18)
	c.icon:SetPoint("LEFT", 7, 0)
	c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if c.CreateMaskTexture and c.icon.AddMaskTexture and Ink.tex and Ink.tex.mask then
		c.mask = c:CreateMaskTexture()
		c.mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		c.mask:SetAllPoints(c.icon)
		c.icon:AddMaskTexture(c.mask)
	end
	c.disc = c:CreateTexture(nil, "ARTWORK")
	c.disc:SetTexture(DISC)
	c.disc:SetTexCoord(K, 1 - K, K, 1 - K)
	c.disc:SetSize(18, 18)
	c.disc:SetPoint("LEFT", 7, 0)
	c.letter = Ink:Text(c, F.bold, 10, C.text, "CENTER")
	c.letter:SetPoint("CENTER", c.disc, "CENTER", 0, 0)
	c.text = Ink:Text(c, F.semi, 13, C.soft, "LEFT")
	c.text:SetPoint("LEFT", 32, 0)
	c.text:SetWordWrap(false)
	c.sub = Ink:Text(c, F.numR, 11, C.muted, "LEFT")
	c.pin = c:CreateTexture(nil, "OVERLAY")
	c.pin:SetTexture(DISC)
	c.pin:SetSize(5, 5)
	c.pin:SetPoint("TOPRIGHT", -7, -6)
	c.pin:Hide()

	function c:Set(it, maxW)
		self.it = it
		local isRep = it.kind == "rep" or not it.icon   -- 평판 · 아이콘 없는 기술은 첫 글자
		self.icon:SetShown(not isRep)
		self.disc:SetShown(isRep)
		self.letter:SetShown(isRep)
		if isRep then
			local q = it.rgb or C.accent
			self.disc:SetVertexColor(q[1], q[2], q[3], 0.22)
			self.letter:SetText(it.letter or "?")
			self.letter:SetTextColor(q[1], q[2], q[3])
		else
			self.icon:SetTexture(it.icon or 134400)
		end
		self.text:SetWidth(0)
		self.text:SetText(it.name or "?")
		self.sub:SetText(it.sub or "")
		local nw = math.ceil(self.text:GetStringWidth() or 0)
		local sw = (it.sub and it.sub ~= "") and math.ceil(self.sub:GetStringWidth() or 0) or 0
		local fixed = 32 + (sw > 0 and (7 + sw) or 0) + 14
		if maxW and nw + fixed > maxW then nw = math.max(30, maxW - fixed) end
		self.text:SetWidth(nw)
		self.sub:ClearAllPoints()
		self.sub:SetPoint("LEFT", self.text, "RIGHT", 7, 0)
		self.sub:SetShown(sw > 0)
		self:SetWidth(nw + fixed)
	end

	function c:Paint(animate)
		local it = self.it
		if not it then return end
		local e = r.e
		local on, pick = false, nil
		if e.state then on, pick = e.state(it) end
		local ok = DepOK(e)
		local a, hot = C.accent, self.hot and ok
		local to = on and 1 or 0
		local from = self.p or to
		local function paint(p)
			self.p = p
			self.bg:Color(lerp(1, a[1], p), lerp(1, a[2], p), lerp(1, a[3], p), lerp(hot and 0.09 or 0.05, hot and 0.24 or 0.17, p))
			local tc = on and a or (hot and C.text or C.soft)
			self.text:SetTextColor(tc[1], tc[2], tc[3])
			self.sub:SetTextColor(on and a[1] * 0.8 or C.muted[1], on and a[2] * 0.8 or C.muted[2], on and a[3] * 0.8 or C.muted[3])
			self.icon:SetDesaturated(p < 0.5)
			self.icon:SetAlpha(lerp(0.45, 1, p))
			self.disc:SetAlpha(lerp(0.5, 1, p))
			self.letter:SetAlpha(lerp(0.55, 1, p))
		end
		if animate and from ~= to then
			Tween(self, "on", 0.24, E.out, function(p) paint(lerp(from, to, p)) end, function() paint(to) end)
		else
			Cancel(self, "on")
			paint(to)
		end
		-- 직접 고정한 칩엔 작은 노란 점
		self.pin:SetVertexColor(a[1], a[2], a[3])
		self.pin:SetShown(pick == true and it.kind ~= "prof")
	end

	c:SetScript("OnEnter", function(self)
		self.hot = true
		self:Paint()
		RowEnter(r)
		local it, e = self.it, r.e
		if not it then return end
		local on, pick = false, nil
		if e.state then on, pick = e.state(it) end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(it.name or "?", 1, 1, 1)
		if it.kind == "rep" then
			local q = it.rgb or C.accent
			GameTooltip:AddDoubleLine(it.sub or "", (it.rank or 0) .. " / " .. (it.max or 0), q[1], q[2], q[3], 1, 1, 1)
		else
			GameTooltip:AddDoubleLine(it.kind == "weapon" and "무기 숙련" or "숙련", (it.rank or 0) .. " / " .. (it.max or 0), 0.7, 0.72, 0.75, 1, 1, 1)
		end
		local g = { 0.56, 0.58, 0.61 }
		local line
		if not DepOK(e) then
			line, g = "현황 아이콘을 켜야 쓸 수 있어요", C.orange
		elseif on and pick == true then
			line = "고정했어요 · 누르면 빼요"
		elseif on then
			line = it.kind == "prof" and "보여 주는 중 · 누르면 빼요"
				or (it.kind == "weapon" and "자동으로 보여 주는 중 (아직 덜 올림) · 누르면 빼요"
				or "자동으로 보여 주는 중 (추적 · 방금 오름) · 누르면 빼요")
		elseif pick == false then
			line = "뺐어요 · 누르면 다시 보여요"
		elseif it.kind == "weapon" then
			line = it.maxed and "다 올려서 자동에선 숨겨요 · 누르면 고정해요"
				or ((it.rank or 0) <= 1 and "아직 안 써 본 무기라 자동에선 숨겨요 · 누르면 고정해요" or "자동 칸(4개)이 찼어요 · 누르면 고정해요")
		else
			line = "누르면 고정해요"
		end
		GameTooltip:AddLine(line, g[1], g[2], g[3], true)
		GameTooltip:Show()
	end)
	c:SetScript("OnLeave", function(self)
		self.hot = nil
		self:Paint()
		GameTooltip:Hide()
		RowLeave(r)
	end)
	c:SetScript("OnClick", function(self)
		local e = r.e
		if not DepOK(e) or not self.it or not e.toggle then return end
		e.toggle(self.it)
		Sound()
		M:Changed(e)
		if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
	end)
	return c
end

-- 프레임 메타테이블은 건드리지 않고 Row 함수들을 프레임 테이블에 직접 붙인다
local function NewRow(parent, e)
	local r = CreateFrame("Button", nil, parent)
	for k, f in pairs(Row) do if type(f) == "function" then r[k] = f end end
	r.e = e
	r:RegisterForClicks("LeftButtonUp")
	r.hl = RoundRect(r, "BACKGROUND", 1, 12)
	r.hl:Color(1, 1, 1, 0)
	r.line = r:CreateTexture(nil, "BORDER")
	r.line:SetTexture(WHITE)
	r.line:SetVertexColor(1, 1, 1, 0.045)
	r.line:SetHeight(1)
	r.line:SetPoint("BOTTOMLEFT", 12, 0)
	r.line:SetPoint("BOTTOMRIGHT", -12, 0)
	-- 내용 (의존 설정이 꺼지면 이것만 흐리게)
	r.c = CreateFrame("Frame", nil, r)
	r.c:SetAllPoints()
	r.label = Ink:Text(r.c, F.semi, 15, C.text, "LEFT")
	r.label:SetText(e.label)
	r.dot = r.c:CreateTexture(nil, "OVERLAY")
	r.dot:SetTexture(DISC)
	r.dot:SetSize(6, 6)
	r.dot:Hide()
	r.tag = Ink:Text(r.c, F.latin, 11, C.orange, "LEFT")
	r.tag:SetText("/reload")
	r.tag:Hide()
	if e.desc then
		r.desc = Ink:Text(r.c, F.sans, 13, C.muted, "LEFT")
		r.desc:SetText(e.desc)
	end

	if e.kind == "switch" then
		local sw = CreateFrame("Frame", nil, r.c)
		sw:SetSize(SW_W, SW_H)
		sw.track = Pill(sw, "ARTWORK", 0, SW_H)
		sw.knob = sw:CreateTexture(nil, "ARTWORK", nil, 3)
		sw.knob:SetTexture(DISC)
		sw.knob:SetTexCoord(K, 1 - K, K, 1 - K)
		sw.knob:SetSize(KNOB, KNOB)
		r.sw = sw
		r.ctrl = sw
		r:SetScript("OnMouseDown", function(self) if DepOK(self.e) then self.pressed = true; self:PaintSwitch(self.swP or 0) end end)
		r:SetScript("OnMouseUp", function(self) self.pressed = nil; self:PaintSwitch(self.swP or 0) end)
		r:SetScript("OnClick", function(self)
			if not DepOK(self.e) then return end
			local v = not Get(self.e)
			Set(self.e, v)
			Sound()
			M:Changed(self.e)
		end)
	elseif e.kind == "seg" then
		local s = CreateFrame("Frame", nil, r.c)
		s:SetHeight(36)
		s.bg = RoundRect(s, "BACKGROUND", 2, 10)
		s.bg:Color(1, 1, 1, 0.05)
		s.pill = CreateFrame("Frame", nil, s)
		s.pill:SetHeight(30)
		s.pill.bg = RoundRect(s.pill, "BACKGROUND", 3, 8)
		s.pill.bg:Color(SEGON[1], SEGON[2], SEGON[3], 1)
		s.pill.bar = s.pill:CreateTexture(nil, "ARTWORK")
		s.pill.bar:SetTexture(WHITE)
		s.pill.bar:SetHeight(2)
		s.pill.bar:SetPoint("BOTTOMLEFT", 8, 0)
		s.pill.bar:SetPoint("BOTTOMRIGHT", -8, 0)
		s.btns = {}
		local x = 3
		for i, o in ipairs(e.opts) do
			local b = CreateFrame("Button", nil, s)
			b:SetHeight(30)
			b:SetFrameLevel(s.pill:GetFrameLevel() + 2)
			b.text = Ink:Text(b, F.semi, 13, C.soft, "CENTER")
			b.text:SetPoint("CENTER")
			b.text:SetText(o[2])
			local w = math.max(48, math.ceil(b.text:GetStringWidth() or 0) + 26)
			b:SetWidth(w)
			b:SetPoint("LEFT", s, "LEFT", x, 0)
			b.x, b.w = x, w
			x = x + w + 2
			b:SetScript("OnClick", function()
				if not DepOK(e) or Get(e) == o[1] then return end
				Set(e, o[1])
				Sound()
				M:Changed(e)
			end)
			Child(r, b)
			s.btns[i] = b
		end
		s:SetWidth(x + 1)
		r.seg = s
		r.ctrl = s
	elseif e.kind == "cycle" then
		local cy = CreateFrame("Frame", nil, r.c)
		cy:SetHeight(34)
		cy.bg = RoundRect(cy, "BACKGROUND", 2, 10)
		cy.bg:Color(1, 1, 1, 0.05)
		local wmax = 70
		local probe = Ink:Text(cy, F.semi, 13, C.text, "CENTER")
		for _, o in ipairs(e.opts) do
			probe:SetText(o[2])
			wmax = math.max(wmax, math.ceil(probe:GetStringWidth() or 0))
		end
		if e.other then probe:SetText(e.other); wmax = math.max(wmax, math.ceil(probe:GetStringWidth() or 0)) end
		probe:Hide()
		local function arrow(txt, dir)
			local b = CreateFrame("Button", nil, cy)
			b:SetSize(30, 34)
			b.t = Ink:Text(b, F.latinB, 17, C.muted, "CENTER")
			b.t:SetPoint("CENTER", 0, 1)
			b.t:SetText(txt)
			b:SetScript("OnEnter", function(self) self.t:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end)
			b:SetScript("OnLeave", function(self) self.t:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
			b:SetScript("OnClick", function() r:Cycle(dir) end)
			Child(r, b)
			return b
		end
		cy.l = arrow("‹", -1)
		cy.l:SetPoint("LEFT", 0, 0)
		cy.r = arrow("›", 1)
		cy.r:SetPoint("RIGHT", 0, 0)
		cy.val = Ink:Text(cy, F.semi, 13, C.text, "CENTER")
		cy.val:SetWidth(wmax + 8)
		cy:SetWidth(wmax + 8 + 60)
		cy.val:SetPoint("CENTER")
		r.cy = cy
		r.ctrl = cy
		r:SetScript("OnClick", function(self) self:Cycle(1) end)
	elseif e.kind == "slider" then
		r.val = Ink:Text(r.c, F.latin, 14, C.accent, "RIGHT")
		local sl = CreateFrame("Frame", nil, r.c)
		sl:SetHeight(22)
		sl:EnableMouse(true)
		sl.track = CreateFrame("Frame", nil, sl)
		sl.track:SetHeight(4)
		sl.track:SetPoint("LEFT")
		sl.track:SetPoint("RIGHT")
		sl.track.p = Pill(sl.track, "ARTWORK", 0, 4)
		sl.track.p:Color(1, 1, 1, 0.12)
		sl.fill = CreateFrame("Frame", nil, sl)
		sl.fill:SetHeight(4)
		sl.fill:SetPoint("LEFT")
		sl.fill.p = Pill(sl.fill, "ARTWORK", 1, 4)
		sl.halo = sl:CreateTexture(nil, "ARTWORK", nil, 2)
		sl.halo:SetTexture(DISC)
		sl.halo:SetSize(34, 34)
		sl.halo:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0)
		sl.thumb = sl:CreateTexture(nil, "ARTWORK", nil, 3)
		sl.thumb:SetTexture(DISC)
		sl.thumb:SetTexCoord(K, 1 - K, K, 1 - K)
		sl.thumb:SetSize(18, 18)
		sl.thumb:SetVertexColor(C.text[1], C.text[2], C.text[3])
		local function fromCursor()
			local l, w = sl:GetLeft(), sl:GetWidth()
			if not l or not w or w <= 0 then return end
			local x = GetCursorPosition() / sl:GetEffectiveScale()
			local f = clamp01((x - l) / w)
			local v = e.min + math.floor(f * (e.max - e.min) / e.step + 0.5) * e.step
			if v ~= Get(e) then
				Set(e, v)
				M:Changed(e, true)
			end
		end
		sl:SetScript("OnMouseDown", function()
			if not DepOK(e) then return end
			sl.drag = true
			fromCursor()
			sl:SetScript("OnUpdate", fromCursor)
			r:PaintSlider()
		end)
		sl:SetScript("OnMouseUp", function()
			sl.drag = nil
			sl:SetScript("OnUpdate", nil)
			r:PaintSlider()
		end)
		Child(r, sl)
		-- 휠은 막대 위에서만 (본문을 휠로 내리다가 값이 바뀌지 않게)
		sl:EnableMouseWheel(true)
		sl:SetScript("OnMouseWheel", function(_, d)
			if not DepOK(e) then return end
			local v = math.max(e.min, math.min(e.max, (Get(e) or e.min) + (d > 0 and e.step or -e.step)))
			if v ~= Get(e) then Set(e, v); M:Changed(e, true) end
		end)
		r.sl = sl
	elseif e.kind == "action" then
		local b = Btn(r.c, e.btn, "outline", nil, function() if e.fn then e.fn() end end)
		b:SetHeight(34)
		Child(r, b)
		r.act = b
		r.ctrl = b
	elseif e.kind == "picks" then
		r.pk = CreateFrame("Frame", nil, r.c)
		r.pk.chips, r.pk.heads = {}, {}
		r.pk.empty = Ink:Text(r.pk, F.sans, 13, C.muted, "LEFT")
		r.pk.empty:SetPoint("TOPLEFT", 2, -4)
		local b = Btn(r.c, "자동으로", "text", nil, function()
			if not DepOK(e) then return end
			Set(e, nil)
			Sound()
			M:Changed(e)
		end)
		b:SetHeight(28)
		Child(r, b)
		r.act = b
		r.ctrl = b
	end

	r:SetScript("OnEnter", RowEnter)
	r:SetScript("OnLeave", RowLeave)
	r:EnableMouseWheel(false)   -- 휠은 본문 스크롤로
	return r
end
M.NewRow = NewRow

-- 줄 배치: 폭 gw(내용 폭)에 맞춰 높이를 정하고 돌려준다
function Row:Layout(gw)
	local e = self.e
	local lineH = self.desc and 66 or 52
	local cw = gw
	local ctrlW = self.ctrl and self.ctrl:GetWidth() or 0
	if e.kind == "slider" then ctrlW = 60 end
	-- 단계가 길어서 한 줄에 안 들어가면 아래로 내린다
	local labelW = math.ceil(self.label:GetStringWidth() or 0)
	self.stack = (e.kind == "seg") and (math.max(80, math.min(labelW, 200)) + 24 + ctrlW > cw)
	local textW = self.stack and cw or math.max(60, cw - ctrlW - 20)
	local h = lineH
	local top = self.desc and 15 or 17
	self.label:ClearAllPoints()
	self.label:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -top)
	-- 오른쪽에 노란 점 · /reload 표시 자리를 남긴다
	self.label:SetWidth(math.max(40, textW - 70))
	if self.desc then
		self.desc:ClearAllPoints()
		self.desc:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -(top + 24))
		self.desc:SetWidth(textW)
	end
	local cy = -lineH / 2
	if e.kind == "switch" or e.kind == "cycle" or e.kind == "action" or (e.kind == "seg" and not self.stack) then
		self.ctrl:ClearAllPoints()
		self.ctrl:SetPoint("RIGHT", self, "TOPRIGHT", -12, cy)
	elseif e.kind == "seg" then
		self.ctrl:ClearAllPoints()
		self.ctrl:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -(lineH - 4))
		h = lineH + 36 + 10
	elseif e.kind == "picks" then
		self.ctrl:ClearAllPoints()
		self.ctrl:SetPoint("RIGHT", self, "TOPRIGHT", -12, cy)
		local ph = self:LayoutPicks(cw)
		self.pk:ClearAllPoints()
		self.pk:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -(lineH - 2))
		self.pk:SetSize(cw, ph)
		h = lineH + ph + 14
	elseif e.kind == "slider" then
		self.val:ClearAllPoints()
		self.val:SetPoint("RIGHT", self, "TOPRIGHT", -12, cy)
		self.sl:ClearAllPoints()
		self.sl:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -(lineH - 8))
		self.sl:SetPoint("TOPRIGHT", self, "TOPRIGHT", -12, -(lineH - 8))
		h = lineH + 26
	end
	self.h = h
	return h
end

-- 칩을 폭 cw 안에서 줄바꿈하며 놓고 높이를 돌려준다 (열 때마다 지금 캐릭터 자료로 다시)
function Row:LayoutPicks(cw)
	local e, pk = self.e, self.pk
	local ok, items = pcall(e.items or function() return {} end)
	if not ok or type(items) ~= "table" then items = {} end
	for _, c in ipairs(pk.chips) do c:Hide(); c.it = nil end
	for _, t in ipairs(pk.heads) do t:Hide() end
	local GX, GY = 6, 6
	local x, y, ci, hi, open = 0, 0, 0, 0, false
	for _, it in ipairs(items) do
		if it.header then
			if open then y = y + PICK_H + GY; x = 0; open = false end
			hi = hi + 1
			local t = pk.heads[hi]
			if not t then
				t = Ink:Text(pk, F.semi, 12, C.muted, "LEFT")
				pk.heads[hi] = t
			end
			if hi > 1 or ci > 0 then y = y + 6 end
			t:SetText(it.name or "")
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", pk, "TOPLEFT", 4, -y)
			t:Show()
			y = y + 22
		else
			ci = ci + 1
			local c = pk.chips[ci]
			if not c then
				c = NewPickChip(self, pk)
				pk.chips[ci] = c
			end
			c:Set(it, cw)
			local w = c:GetWidth()
			if open and x + w > cw then x = 0; y = y + PICK_H + GY end
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", pk, "TOPLEFT", x, -y)
			c:Show()
			x = x + w + GX
			open = true
		end
	end
	if open then y = y + PICK_H end
	pk.empty:SetShown(ci == 0)
	if ci == 0 then
		pk.empty:SetText(e.empty or "아직 없어요")
		y = math.max(y, 24)
	end
	self:PaintPicks(false)
	return y
end

function Row:PaintPicks(animate)
	for _, c in ipairs(self.pk.chips) do
		if c:IsShown() and c.it then c:Paint(animate) end
	end
	if self.act then self.act:SetShown(Changed(self.e)) end
end

function Row:PaintSwitch(p)
	local sw = self.sw
	local a = C.accent
	local q = clamp01(p)
	local kw = KNOB + (self.pressed and 5 or 0)
	sw.knob:SetSize(kw, KNOB)
	local travel = SW_W - 6 - kw
	sw.knob:ClearAllPoints()
	sw.knob:SetPoint("LEFT", sw, "LEFT", 3 + travel * p, 0)
	sw.track:Color(lerp(1, a[1], q), lerp(1, a[2], q), lerp(1, a[3], q), lerp(0.12 + (self.hover and 0.04 or 0), 1, q))
	local m = C.muted
	sw.knob:SetVertexColor(lerp(m[1], INK[1], q), lerp(m[2], INK[2], q), lerp(m[3], INK[3], q))
end

function Row:PaintSeg(animate)
	local s = self.seg
	local v = Get(self.e)
	local i = OptIndex(self.e, v) or 1
	local b = s.btns[i]
	for j, bb in ipairs(s.btns) do
		local c = (j == i) and C.text or C.soft
		bb.text:SetTextColor(c[1], c[2], c[3])
	end
	s.pill.bar:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	local fx, fw = s.pillX or b.x, s.pillW or b.w
	local tx, tw = b.x, b.w
	local function place(px, pw)
		s.pillX, s.pillW = px, pw
		s.pill:ClearAllPoints()
		s.pill:SetPoint("LEFT", s, "LEFT", px, 0)
		s.pill:SetWidth(pw)
	end
	if animate then
		Tween(s, "pill", 0.34, function(p) return E.back(p, 1.25) end, function(p) place(lerp(fx, tx, p), lerp(fw, tw, clamp01(p))) end)
	else
		Cancel(s, "pill")
		place(tx, tw)
	end
end

function Row:Cycle(dir)
	local e = self.e
	if not DepOK(e) or not e.opts or #e.opts == 0 then return end
	local i = OptIndex(e, Get(e)) or 0
	i = ((i - 1 + dir) % #e.opts) + 1
	if i < 1 then i = #e.opts end
	Set(e, e.opts[i][1])
	Sound()
	self.cyDir = dir
	M:Changed(e)
end

function Row:PaintCycle(animate)
	local cy = self.cy
	cy.val:SetText(OptLabel(self.e, Get(self.e)))
	if animate then
		local d = (self.cyDir or 1) * 8
		Tween(cy, "val", 0.26, E.out, function(p)
			cy.val:SetAlpha(p)
			cy.val:ClearAllPoints()
			cy.val:SetPoint("CENTER", cy, "CENTER", d * (1 - p), 0)
		end)
	end
end

function Row:PaintSlider()
	local e, sl = self.e, self.sl
	local v = Get(e) or e.min
	self.val:SetText(string.format(e.fmt or "%d", v))
	local w = sl:GetWidth()
	if not w or w <= 0 then return end
	local f = clamp01((v - e.min) / (e.max - e.min))
	local a = C.accent
	sl.fill:SetWidth(math.max(4, w * f))
	sl.fill.p:Color(a[1], a[2], a[3], 1)
	sl.thumb:ClearAllPoints()
	sl.thumb:SetPoint("CENTER", sl, "LEFT", w * f, 0)
	sl.halo:ClearAllPoints()
	sl.halo:SetPoint("CENTER", sl.thumb)
	sl.halo:SetVertexColor(a[1], a[2], a[3], sl.drag and 0.28 or (self.hover and 0.14 or 0))
	sl.thumb:SetSize(sl.drag and 20 or 18, sl.drag and 20 or 18)
end

-- 값 · 점 · 주황 표시 다시 그리기 (animate = 방금 바뀜)
function Row:Refresh(animate)
	local e = self.e
	local ok = DepOK(e)
	self.c:SetAlpha(ok and 1 or 0.38)
	if e.kind == "switch" then
		local to = Get(e) and 1 or 0
		local from = self.swP or to
		if animate and from ~= to then
			Tween(self, "sw", 0.4, E.knob, function(p) self.swP = lerp(from, to, p); self:PaintSwitch(self.swP) end,
				function() self.swP = to; self:PaintSwitch(to) end)
		else
			Cancel(self, "sw")
			self.swP = to
			self:PaintSwitch(to)
		end
	elseif e.kind == "seg" then
		self:PaintSeg(animate)
	elseif e.kind == "cycle" then
		self:PaintCycle(animate)
	elseif e.kind == "slider" then
		self:PaintSlider()
	elseif e.kind == "picks" then
		self:PaintPicks(animate)
	end
	-- 기본값과 다르면 노란 점 (나타날 때 톡)
	local ch = Changed(e)
	local a = C.accent
	self.dot:SetVertexColor(a[1], a[2], a[3])
	local lw = math.min(math.ceil(self.label:GetStringWidth() or 0), math.floor(self.label:GetWidth() or 999))
	self.dot:ClearAllPoints()
	self.dot:SetPoint("LEFT", self.label, "LEFT", lw + 8, 0)
	if ch and not self.dot:IsShown() then
		self.dot:Show()
		if animate then
			Tween(self.dot, "pop", 0.36, E.pop, function(p) local s = math.max(0.1, 6 * p); self.dot:SetSize(s, s) end,
				function() self.dot:SetSize(6, 6) end)
		else
			self.dot:SetSize(6, 6)
		end
	elseif not ch then
		Cancel(self.dot, "pop")
		self.dot:Hide()
	end
	-- /reload 해야 적용되는 설정을 이번 접속에서 바꿨으면 주황 표시
	local pend = M:Pending(e)
	self.tag:ClearAllPoints()
	self.tag:SetPoint("LEFT", self.label, "LEFT", lw + (ch and 20 or 8), 0)
	self.tag:SetShown(pend)
	if pend then self.tag:SetTextColor(C.orange[1], C.orange[2], C.orange[3]) end
end

-------------------------------------------------------------------------------
-- 바뀐 설정 세기 · /reload 대기
-------------------------------------------------------------------------------
function M:Pending(e)
	if not e.reload then return false end
	local v = self.login and self.login[e.id]
	if v == nil then return false end
	return Get(e) ~= v
end

function M:Counts()
	local changed, pending, per = 0, 0, {}
	for _, e in ipairs(self.entries or {}) do
		if Changed(e) then
			changed = changed + 1
			per[e.cat] = (per[e.cat] or 0) + 1
		end
		if self:Pending(e) then pending = pending + 1 end
	end
	return changed, pending, per
end

-- 값이 바뀐 뒤: 그 줄 + 의존하는 줄 + 아래 줄 + 독 점
function M:Changed(e, quiet)
	for _, r in ipairs(self:RowsFor(e.id)) do r:Refresh(not quiet or e.kind ~= "slider") end
	for _, d in ipairs(self.entries) do
		if d.dep == e.id or d.dep == e.key then
			for _, r in ipairs(self:RowsFor(d.id)) do r:Refresh(false) end
		end
	end
	-- 현황 아이콘 설정이 바뀌면 고르기 칩 색도 다시 (자동으로 뜨는 것이 달라짐)
	if e.id and tostring(e.id):find("^tracker") then
		for _, d in ipairs(self.entries) do
			if d.kind == "picks" and d ~= e then
				for _, r in ipairs(self:RowsFor(d.id)) do r:Refresh(true) end
			end
		end
	end
	self:PaintFooter()
	self:PaintTiles()
	if e.kind == "slider" then
		for _, r in ipairs(self:RowsFor(e.id)) do r:PaintSlider() end
	end
end

function M:RowsFor(id)
	local out = {}
	for _, pg in pairs(self.pages or {}) do
		local r = pg.byId and pg.byId[id]
		if r then out[#out + 1] = r end
	end
	return out
end

-------------------------------------------------------------------------------
-- 시트 만들기
-------------------------------------------------------------------------------
local function Dim()
	local rw = Ink.root:GetWidth() or 1920
	local W = math.floor(math.max(1080, math.min(1560, rw - 160)))
	local H = math.floor(math.max(420, math.min(820, Ink.db.sheetH or 580)))
	return W, H
end

function M:Build()
	local f = CreateFrame("Frame", "FOASettingsSheet", Ink.root)
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(60)
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	self.f = f
	self.pages = {}

	-- 바탕 · 위로 드리운 그림자 · 위 가장자리 선
	f.shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.shadow:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 10, -24)
	f.shadow:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -10, -24)
	f.shadow:SetHeight(150)
	Grad(f.shadow, "VERTICAL", { 0, 0, 0 }, 0.5, 0)
	f.bg = RoundRect(f, "BACKGROUND", 0, 28, true)
	f.bg:Color(BG[1], BG[2], BG[3], 0.975)
	f.edge = f:CreateTexture(nil, "BORDER")
	f.edge:SetTexture(WHITE)
	f.edge:SetVertexColor(1, 1, 1, 0.09)
	f.edge:SetHeight(1)
	f.edge:SetPoint("TOPLEFT", 26, 0)
	f.edge:SetPoint("TOPRIGHT", -26, 0)
	-- 열 때 위 가장자리를 노란 빛이 한 번 훑고 지나감
	f.clip = CreateFrame("Frame", nil, f)
	f.clip:SetPoint("TOPLEFT", 22, 0)
	f.clip:SetPoint("TOPRIGHT", -22, 0)
	f.clip:SetHeight(2)
	if f.clip.SetClipsChildren then f.clip:SetClipsChildren(true) end
	-- 빛 줄은 자식 프레임에 그려야 확실히 잘린다 (둥근 모서리 밖으로 삐져나오지 않게)
	f.clip.inner = CreateFrame("Frame", nil, f.clip)
	f.clip.inner:SetAllPoints()
	f.sheenL = f.clip.inner:CreateTexture(nil, "OVERLAY")
	f.sheenL:SetHeight(1)
	Grad(f.sheenL, "HORIZONTAL", C.accent, 0, 0.95)
	f.sheenR = f.clip.inner:CreateTexture(nil, "OVERLAY")
	f.sheenR:SetHeight(1)
	Grad(f.sheenR, "HORIZONTAL", C.accent, 0.95, 0)
	f.sheenL:SetAlpha(0); f.sheenR:SetAlpha(0)

	-- 손잡이: 끌어서 높이 조절
	local grab = CreateFrame("Button", nil, f)
	grab:SetSize(140, 26)
	grab:SetPoint("TOP", 0, -1)
	grab.pill = CreateFrame("Frame", nil, grab)
	grab.pill:SetSize(52, 5)
	grab.pill:SetPoint("TOP", 0, -11)
	grab.pill.p = Pill(grab.pill, "ARTWORK", 0, 5)
	grab.pill.p:Color(1, 1, 1, 0.18)
	grab:SetScript("OnEnter", function(self)
		self.pill.p:Color(C.accent[1], C.accent[2], C.accent[3], 0.7)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("끌어서 높이 조절", 1, 1, 1)
		GameTooltip:Show()
	end)
	grab:SetScript("OnLeave", function(self)
		if not self.drag then self.pill.p:Color(1, 1, 1, 0.18) end
		GameTooltip_Hide()
	end)
	grab:SetScript("OnMouseDown", function(self)
		local _, cy = GetCursorPosition()
		self.drag = { cy = cy / f:GetEffectiveScale(), h = select(2, Dim()) }
		self:SetScript("OnUpdate", function()
			local _, y = GetCursorPosition()
			local nh = self.drag.h + (y / f:GetEffectiveScale() - self.drag.cy)
			nh = math.floor(math.max(420, math.min(math.min(820, (Ink.root:GetHeight() or 1080) - 140), nh)) + 0.5)
			if nh ~= Ink.db.sheetH then
				Ink.db.sheetH = nh
				M:FitSheet(true)
			end
		end)
	end)
	grab:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
		self.drag = nil
		if not self:IsMouseOver() then self.pill.p:Color(1, 1, 1, 0.18) end
		M:FitSheet()
	end)
	f.grab = grab

	-- 왼쪽: 로고 + 버전
	local brand, ui = Ink:Brand(f, 18)
	brand:SetPoint("TOPLEFT", f, "TOPLEFT", PADX + 2, -58)
	f.brand = brand
	f.ver = Ink:Text(f, F.latin, 12, C.dim, "LEFT")
	f.ver:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 1, -8)
	f.ver:SetText("설정  ·  v" .. tostring(Ink.version or ""))

	self:BuildDock()
	self:BuildRight()

	-- 본문 위 선 · 칸 구분선
	f.div = f:CreateTexture(nil, "BORDER")
	f.div:SetTexture(WHITE)
	f.div:SetVertexColor(1, 1, 1, 0.06)
	f.div:SetHeight(1)
	f.div:SetPoint("TOPLEFT", PADX, -HEAD)
	f.div:SetPoint("TOPRIGHT", -PADX, -HEAD)
	f.cols = {}
	for k = 1, 2 do
		local t = f:CreateTexture(nil, "BORDER")
		t:SetTexture(WHITE)
		t:SetVertexColor(1, 1, 1, 0.05)
		t:SetWidth(1)
		f.cols[k] = t
	end

	-- 본문 (스크롤)
	local sf = CreateFrame("ScrollFrame", nil, f)
	sf:SetPoint("TOPLEFT", PADX - 14, -(HEAD + 1))
	sf:SetPoint("BOTTOMRIGHT", -(PADX - 14), EXTRA + FOOT)
	local body = CreateFrame("Frame", nil, sf)
	body:SetSize(100, 100)
	sf:SetScrollChild(body)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(_, d) M:ScrollBy(-d * 90) end)
	self.sf, self.body = sf, body
	f.track = f:CreateTexture(nil, "ARTWORK")
	f.track:SetTexture(WHITE)
	f.track:SetVertexColor(1, 1, 1, 0.05)
	f.track:SetWidth(3)
	f.track:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -(HEAD + 16))
	f.track:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, EXTRA + FOOT + 16)
	f.thumb = f:CreateTexture(nil, "OVERLAY")
	f.thumb:SetTexture(WHITE)
	f.thumb:SetWidth(3)
	f.empty = Ink:Text(body, F.sans, 15, C.muted, "CENTER")
	f.empty:SetPoint("TOP", body, "TOP", 0, -70)
	f.empty:Hide()

	self:BuildFooter()
	self:BuildSpot()

	-- ESC 로 닫기 (다른 키는 게임으로 그대로)
	f:EnableKeyboard(true)
	f:SetPropagateKeyboardInput(true)
	f:SetScript("OnKeyDown", function(self, key)
		local esc = key == "ESCAPE"
		if not InCombatLockdown() then self:SetPropagateKeyboardInput(not esc) end
		if esc then M:Close() end
	end)
	f:SetScript("OnHide", function() M:SpotFor(nil, true) end)
end

-------------------------------------------------------------------------------
-- 분류 독
-------------------------------------------------------------------------------
function M:BuildDock()
	local f = self.f
	local n = #CATS
	local nav = CreateFrame("Frame", nil, f)
	nav:SetSize(n * TILE_W + (n - 1) * TILE_GAP, TILE_H)
	nav:SetPoint("TOP", f, "TOP", 0, -34)
	f.nav = nav
	-- 받침: 고른 타일 밑을 스프링으로 미끄러진다
	local ind = CreateFrame("Frame", nil, nav)
	ind:SetSize(TILE_W, TILE_H)
	ind.glow = ind:CreateTexture(nil, "BACKGROUND", nil, -2)
	ind.glow:SetTexture(MEDIA .. "Textures\\Glow")
	ind.glow:SetPoint("TOPLEFT", -18, 6)
	ind.glow:SetPoint("BOTTOMRIGHT", 18, -22)
	ind.glow:SetVertexColor(0, 0, 0, 0.55)
	ind.bg = RoundRect(ind, "BACKGROUND", 0, 16)
	ind.bg:Color(RAISE[1], RAISE[2], RAISE[3], 1)
	ind.bar = ind:CreateTexture(nil, "ARTWORK")
	ind.bar:SetTexture(WHITE)
	ind.bar:SetHeight(2)
	ind.bar:SetPoint("BOTTOMLEFT", 18, 0)
	ind.bar:SetPoint("BOTTOMRIGHT", -18, 0)
	f.ind = ind
	f.tiles = {}
	for i, c in ipairs(CATS) do
		local t = CreateFrame("Button", nil, nav)
		t:SetSize(TILE_W, TILE_H)
		t:SetPoint("TOPLEFT", (i - 1) * (TILE_W + TILE_GAP), 0)
		t:SetFrameLevel(ind:GetFrameLevel() + 2)
		t.cat = c
		t.hov = RoundRect(t, "BACKGROUND", 1, 16)
		t.hov:Color(1, 1, 1, 0)
		t.icon = Icon(t, c.icon, 24)
		t.label = Ink:Text(t, F.semi, 13, C.muted, "CENTER")
		t.label:SetText(c.label)
		t.label:SetWidth(TILE_W - 4)
		t.badge = t:CreateTexture(nil, "OVERLAY")
		t.badge:SetTexture(DISC)
		t.badge:SetSize(6, 6)
		t.badge:Hide()
		t.lift = 0
		function t:Place()
			self.icon:ClearAllPoints()
			self.icon:SetPoint("TOP", self, "TOP", 0, -15 + self.lift)
			self.label:ClearAllPoints()
			self.label:SetPoint("TOP", self, "TOP", 0, -48)
			self.badge:ClearAllPoints()
			self.badge:SetPoint("CENTER", self.icon, "TOPRIGHT", 3, -1)
		end
		t:Place()
		t:SetScript("OnEnter", function(self)
			if M.cat ~= c.id or M.query then
				Tween(self, "hov", 0.16, E.out, function(p) self.hov:Color(1, 1, 1, 0.045 * p) end)
			end
			M:LiftTile(self, true)
		end)
		t:SetScript("OnLeave", function(self)
			Tween(self, "hov", 0.2, E.out, function(p) self.hov:Color(1, 1, 1, 0.045 * (1 - p)) end)
			M:LiftTile(self, false)
		end)
		t:SetScript("OnClick", function()
			Sound()
			M:Pick(c.id)
		end)
		f.tiles[i] = t
	end
end

function M:LiftTile(t, hover)
	local on = self.cat == t.cat.id and not self.query
	local to = (on and 4 or 0) + (hover and not on and 3 or 0)
	local from = t.lift
	Tween(t, "lift", 0.3, function(p) return E.back(p, 2) end, function(p) t.lift = lerp(from, to, p); t:Place() end)
end

function M:PaintTiles(animate)
	local f = self.f
	if not f then return end
	local _, _, per = self:Counts()
	local idx = 1
	for i, t in ipairs(f.tiles) do
		local on = self.cat == t.cat.id and not self.query
		if self.cat == t.cat.id then idx = i end
		local c = on and C.text or C.muted
		t.label:SetTextColor(c[1], c[2], c[3])
		t.label:SetFont(on and F.semi or F.sans, Ink:BoostSize(13), "")
		local ic = on and C.accent or C.soft
		t.icon:SetVertexColor(ic[1], ic[2], ic[3], on and 1 or 0.85)
		t.badge:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
		t.badge:SetShown((per[t.cat.id] or 0) > 0 and not on)
		self:LiftTile(t, t:IsMouseOver())
	end
	-- 받침 위치
	local ind = f.ind
	ind.bar:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	local tx = (idx - 1) * (TILE_W + TILE_GAP)
	local fx = self.indX or tx
	local function place(x)
		self.indX = x
		ind:ClearAllPoints()
		ind:SetPoint("TOPLEFT", f.nav, "TOPLEFT", x, 0)
	end
	if animate and fx ~= tx then
		Tween(ind, "x", 0.55, E.back, function(p) place(lerp(fx, tx, p)) end)
	elseif not animate then
		Cancel(ind, "x")
		place(tx)
	end
	local wantA = self.query and 0 or 1
	local a0 = ind:GetAlpha()
	if math.abs(a0 - wantA) > 0.01 then
		Tween(ind, "a", 0.2, E.out, function(p) ind:SetAlpha(lerp(a0, wantA, p)) end)
	end
end

-------------------------------------------------------------------------------
-- 오른쪽: 검색 + 닫기
-------------------------------------------------------------------------------
function M:BuildRight()
	local f = self.f
	local close = CreateFrame("Button", nil, f)
	close:SetSize(40, 40)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADX + 2, -52)
	close.bg = close:CreateTexture(nil, "BACKGROUND")
	close.bg:SetTexture(DISC)
	close.bg:SetAllPoints()
	close.bg:SetVertexColor(1, 1, 1, 0.04)
	close.ring = close:CreateTexture(nil, "BORDER")
	close.ring:SetTexture(MEDIA .. "Textures\\Ring")
	close.ring:SetAllPoints()
	close.ring:SetVertexColor(1, 1, 1, 0.12)
	close.x = Icon(close, "Cross", 14)
	close.x:SetPoint("CENTER")
	close.x:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
	close:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.09)
		self.x:SetVertexColor(C.text[1], C.text[2], C.text[3])
	end)
	close:SetScript("OnLeave", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.04)
		self.x:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
	end)
	close:SetScript("OnClick", function() M:Close() end)
	f.close = close

	local sb = CreateFrame("Frame", nil, f)
	sb:SetSize(40, 40)
	sb:SetPoint("RIGHT", close, "LEFT", -10, 0)
	sb.bg = RoundRect(sb, "BACKGROUND", 0, 20)
	sb.bg:Color(1, 1, 1, 0)
	sb.btn = CreateFrame("Button", nil, sb)
	sb.btn:SetSize(40, 40)
	sb.btn:SetPoint("LEFT")
	sb.icon = Icon(sb.btn, "Search", 16)
	sb.icon:SetPoint("CENTER")
	sb.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3])
	sb.btn:SetScript("OnEnter", function() sb.icon:SetVertexColor(C.text[1], C.text[2], C.text[3]) end)
	sb.btn:SetScript("OnLeave", function() sb.icon:SetVertexColor(C.soft[1], C.soft[2], C.soft[3]) end)
	sb.btn:SetScript("OnClick", function()
		if sb.open then
			if (sb.edit:GetText() or "") == "" then M:SearchOpen(false) else sb.edit:SetFocus() end
		else
			M:SearchOpen(true)
		end
	end)
	local edit = CreateFrame("EditBox", nil, sb)
	edit:SetAutoFocus(false)
	edit:SetFont(F.sans, Ink:BoostSize(14), "")
	edit:SetTextColor(C.text[1], C.text[2], C.text[3])
	edit:SetPoint("LEFT", 40, 0)
	edit:SetPoint("RIGHT", -16, 0)
	edit:SetHeight(30)
	edit:SetMaxLetters(40)
	edit:Hide()
	edit.ph = Ink:Text(edit, F.sans, 14, C.dim, "LEFT")
	edit.ph:SetPoint("LEFT", 1, 0)
	edit.ph:SetText("설정 찾기 · 예: 잠금, 지도")
	edit:SetScript("OnTextChanged", function(self)
		local t = self:GetText() or ""
		self.ph:SetShown(t == "")
		M:Search(t)
	end)
	edit:SetScript("OnEscapePressed", function(self)
		if (self:GetText() or "") ~= "" then self:SetText("") else M:SearchOpen(false) end
	end)
	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusLost", function(self)
		if (self:GetText() or "") == "" then M:SearchOpen(false) end
	end)
	sb.edit = edit
	f.search = sb
end

function M:SearchOpen(on)
	local sb = self.f.search
	if sb.open == on then return end
	sb.open = on
	local w0 = sb:GetWidth()
	local w1 = on and (self.searchW or 240) or 40
	if on then
		sb.edit:Show()
		sb.edit:SetFocus()
	else
		sb.edit:SetText("")
		sb.edit:ClearFocus()
	end
	Tween(sb, "w", on and 0.45 or 0.3, on and E.back or E.out, function(p)
		sb:SetWidth(math.max(40, lerp(w0, w1, p)))
		sb.bg:Color(1, 1, 1, 0.06 * clamp01(on and p or (1 - p)))
	end, function() if not on then sb.edit:Hide() end end)
end

-------------------------------------------------------------------------------
-- 아래 줄: 상태 · 기본값으로 · 다시 불러오기 | 미리보기 · 단축키 · 예시 · 편집 모드
-------------------------------------------------------------------------------
function M:BuildFooter()
	local f = self.f
	local ft = CreateFrame("Frame", nil, f)
	ft:SetPoint("BOTTOMLEFT", 0, EXTRA)
	ft:SetPoint("BOTTOMRIGHT", 0, EXTRA)
	ft:SetHeight(FOOT)
	ft:SetFrameLevel(f:GetFrameLevel() + 20)
	ft.line = ft:CreateTexture(nil, "BORDER")
	ft.line:SetTexture(WHITE)
	ft.line:SetVertexColor(1, 1, 1, 0.06)
	ft.line:SetHeight(1)
	ft.line:SetPoint("TOPLEFT", PADX, 0)
	ft.line:SetPoint("TOPRIGHT", -PADX, 0)
	ft.dot = ft:CreateTexture(nil, "ARTWORK")
	ft.dot:SetTexture(DISC)
	ft.dot:SetSize(8, 8)
	ft.dot:SetPoint("LEFT", PADX + 2, 0)
	ft.text = Ink:Text(ft, F.sans, 13, C.muted, "LEFT")
	ft.text:SetPoint("LEFT", ft.dot, "RIGHT", 10, 0)
	ft.reset = Btn(ft, "기본값으로", "text", "Undo", function(self)
		if self.armed then
			self.armed = nil
			M:ResetAll()
		else
			self.armed = true
			self.text:SetText("한 번 더 누르면 모두 기본값")
			self:Fit()
			C_Timer.After(3, function()
				if self.armed then self.armed = nil; self.text:SetText("기본값으로"); self:Fit() end
			end)
		end
	end)
	ft.reload = Btn(ft, "다시 불러오기", "primary", nil, function() ReloadUI() end)

	ft.edit = Btn(ft, "편집 모드", "outline", "Move", function() M:ToEdit() end)
	ft.edit:SetPoint("RIGHT", ft, "RIGHT", -PADX, 0)
	ft.test = Btn(ft, "예시 보기", "ghost", "Layers", function()
		local cfg = mod("Config")
		if cfg and cfg.SetTest then cfg:SetTest(not cfg.testing) end
		M:PaintFooter()
	end)
	ft.test:SetPoint("RIGHT", ft.edit, "LEFT", -6, 0)
	ft.kb = Btn(ft, "단축키", "ghost", "Keyboard", function() M:Close(); Ink:OpenQuickKeybind() end)
	ft.kb:SetPoint("RIGHT", ft.test, "LEFT", -2, 0)
	-- 미리보기: 누르고 있는 동안 시트가 비쳐서 뒤 화면이 보인다
	ft.peek = Btn(ft, "미리보기", "ghost", "Eye")
	ft.peek:SetPoint("RIGHT", ft.kb, "LEFT", -2, 0)
	ft.peek:SetScript("OnMouseDown", function() M:Peek(true) end)
	ft.peek:SetScript("OnMouseUp", function() M:Peek(false) end)
	ft.peek:HookScript("OnLeave", function() M:Peek(false) end)
	ft.peek:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("누르고 있으면 시트가 비쳐요", 1, 1, 1)
		GameTooltip:Show()
	end)
	ft.peek:HookScript("OnLeave", GameTooltip_Hide)
	f.foot = ft
end

function M:PaintFooter()
	local f = self.f
	if not f then return end
	local ft = f.foot
	local changed, pending = self:Counts()
	local c
	if pending > 0 then
		c = C.orange
		ft.text:SetText(string.format("다시 불러와야 적용되는 설정 %d개", pending))
		ft.text:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
	elseif changed > 0 then
		c = C.accent
		ft.text:SetText(string.format("기본값과 다른 설정 %d개  ·  나머지는 바로 적용돼요", changed))
		ft.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	else
		c = C.dim
		ft.text:SetText("모두 기본값  ·  바꾸면 바로 적용돼요")
		ft.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	end
	ft.dot:SetVertexColor(c[1], c[2], c[3])
	local prev = ft.text
	ft.reload:ClearAllPoints()
	if pending > 0 then
		ft.reload:SetPoint("LEFT", prev, "RIGHT", 14, 0)
		ft.reload:Show()
		prev = ft.reload
	else
		ft.reload:Hide()
	end
	ft.reset:ClearAllPoints()
	ft.reset:SetPoint("LEFT", prev, "RIGHT", pending > 0 and 6 or 10, 0)
	ft.reset:SetShown(changed > 0)
	local cfg = mod("Config")
	ft.test:SetOn(cfg and cfg.testing and true or false)
end

function M:ResetAll()
	for _, e in ipairs(self.entries) do
		if Changed(e) and e.kind ~= "action" then pcall(Set, e, e.def) end
	end
	self:RefreshRows()
	self:PaintFooter()
	self:PaintTiles()
end

-------------------------------------------------------------------------------
-- 짚어 주기: 설정 줄에 올리면 그 설정이 바꾸는 화면 요소 둘레에 노란 모서리
-------------------------------------------------------------------------------
function M:BuildSpot()
	local s = CreateFrame("Frame", nil, Ink.root)
	s:SetFrameStrata("DIALOG")
	s:SetFrameLevel(30)
	s:Hide()
	s.fill = s:CreateTexture(nil, "BACKGROUND")
	s.fill:SetTexture(WHITE)
	s.fill:SetAllPoints()
	s.corners = {}
	for i = 1, 8 do
		local t = s:CreateTexture(nil, "OVERLAY")
		t:SetTexture(WHITE)
		s.corners[i] = t
	end
	s.chip = CreateFrame("Frame", nil, s)
	s.chip:SetHeight(28)
	s.chip.bg = RoundRect(s.chip, "BACKGROUND", 0, 9)
	s.chip.bg:Color(BG[1], BG[2], BG[3], 0.96)
	s.chip.dot = s.chip:CreateTexture(nil, "ARTWORK")
	s.chip.dot:SetTexture(WHITE)
	s.chip.dot:SetSize(6, 6)
	s.chip.dot:SetPoint("LEFT", 11, 0)
	if s.chip.dot.SetRotation then s.chip.dot:SetRotation(math.rad(45)) end
	s.chip.text = Ink:Text(s.chip, F.semi, 13, C.accent, "LEFT")
	s.chip.text:SetPoint("LEFT", 24, 0)
	-- 시트에 가려진 요소: 시트 위 가장자리에 말풍선
	local u = CreateFrame("Frame", nil, Ink.root)
	u:SetFrameStrata("DIALOG")
	u:SetFrameLevel(90)
	u:SetHeight(30)
	u:Hide()
	u.bg = RoundRect(u, "BACKGROUND", 0, 10)
	u.bg:Color(BG[1], BG[2], BG[3], 0.97)
	u.caret = u:CreateTexture(nil, "BACKGROUND", nil, 1)
	u.caret:SetTexture(WHITE)
	u.caret:SetSize(10, 10)
	u.caret:SetPoint("CENTER", u, "BOTTOM", 0, 0)
	if u.caret.SetRotation then u.caret:SetRotation(math.rad(45)) end
	u.text = Ink:Text(u, F.semi, 13, C.text, "LEFT")
	u.text:SetPoint("LEFT", 14, 1)
	self.spot, self.under = s, u
end

local function SpotKey(e)
	local hud = e and e.hud
	if not hud then return end
	local list = type(hud) == "table" and hud or { hud }
	local cfg = mod("Config")
	for _, k in ipairs(list) do
		local m = Ink.movers[k]
		if m and m.frame and m.frame:IsVisible() and cfg and cfg.MoverBox then
			local x, y, w, h = cfg.MoverBox(k)
			if x then return k, m, x, y, w, h end
		end
	end
end

function M:PlaceSpot(x, y, w, h, gap)
	local s = self.spot
	s:ClearAllPoints()
	s:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", x - gap, -(y - gap))
	s:SetSize(w + gap * 2, h + gap * 2)
	local a = C.accent
	local L, T = 16, 2
	local c = s.corners
	local pts = {
		{ "TOPLEFT", 0, 0, L, T }, { "TOPLEFT", 0, 0, T, L },
		{ "TOPRIGHT", 0, 0, L, T }, { "TOPRIGHT", 0, 0, T, L },
		{ "BOTTOMLEFT", 0, 0, L, T }, { "BOTTOMLEFT", 0, 0, T, L },
		{ "BOTTOMRIGHT", 0, 0, L, T }, { "BOTTOMRIGHT", 0, 0, T, L },
	}
	for i, p in ipairs(pts) do
		c[i]:ClearAllPoints()
		c[i]:SetPoint(p[1], s, p[1], p[2], p[3])
		c[i]:SetSize(p[4], p[5])
		c[i]:SetVertexColor(a[1], a[2], a[3], 1)
	end
	s.fill:SetVertexColor(a[1], a[2], a[3], 0.05)
end

function M:SpotFor(e, instant)
	if not self.spot then return end
	self.spotWant = e
	if self.spotTimer then self.spotTimer:Cancel(); self.spotTimer = nil end
	local s, u = self.spot, self.under
	local key, m, x, y, w, h = SpotKey(e)
	if not key or not self.f or not self.f:IsShown() then
		if instant or not s:IsShown() then
			Cancel(s, "a"); s:Hide(); u:Hide(); self.spotRect = nil
		else
			local a0 = s:GetAlpha()
			Tween(s, "a", 0.15, E.out, function(p) s:SetAlpha(a0 * (1 - p)); u:SetAlpha(a0 * (1 - p)) end,
				function() s:Hide(); u:Hide(); self.spotRect = nil end)
		end
		return
	end
	self.lastSpot = e
	-- 시트 위 가장자리 (루트 좌표, 위에서부터)
	local rh = Ink.root:GetHeight() or 1080
	local _, H = Dim()
	local sheetTop = rh - H + (self.offY and -self.offY or 0)
	local covered = y > sheetTop - 6 and not self.peeking
	-- 사각형: 이미 보이면 새 자리로 미끄러진다
	local from = self.spotRect
	local to = { x, y, w, h }
	if from and s:IsShown() then
		Tween(s, "r", 0.3, E.out, function(p)
			self:PlaceSpot(lerp(from[1], to[1], p), lerp(from[2], to[2], p), lerp(from[3], to[3], p), lerp(from[4], to[4], p), 8)
			self.spotRect = { lerp(from[1], to[1], p), lerp(from[2], to[2], p), lerp(from[3], to[3], p), lerp(from[4], to[4], p) }
		end)
	else
		s:SetAlpha(0)
		Tween(s, "r", 0.32, function(p) return E.back(p, 1.6) end, function(p)
			self:PlaceSpot(x, y, w, h, lerp(20, 8, p))
		end)
		self.spotRect = to
	end
	s:SetFrameLevel(self.peeking and (self.f:GetFrameLevel() + 30) or 30)
	s:Show()
	local a0 = s:GetAlpha()
	Tween(s, "a", 0.2, E.out, function(p) s:SetAlpha(lerp(a0, 1, p)) end)
	s.chip.text:SetText("이 설정이 바꾸는 곳  ·  " .. (m.label or key))
	s.chip:SetWidth(math.ceil(s.chip.text:GetStringWidth() or 100) + 38)
	s.chip:ClearAllPoints()
	if y > 60 then
		s.chip:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 8)
	else
		s.chip:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -8)
	end
	s.chip.dot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	-- 가려졌으면 시트 위 가장자리에 말풍선
	if covered then
		local rw = Ink.root:GetWidth() or 1920
		local W = Dim()
		local cx = math.max(rw / 2 - W / 2 + 120, math.min(rw / 2 + W / 2 - 120, x + w / 2))
		u.text:SetText((m.label or key) .. " 은 시트 아래에 있어요  ·  |cff8E939B미리보기를 누르고 있으면 보여요|r")
		u:SetWidth(math.ceil(u.text:GetStringWidth() or 200) + 28)
		u:ClearAllPoints()
		u:SetPoint("BOTTOM", Ink.root, "BOTTOMLEFT", cx, (rh - sheetTop) + 14)
		u.caret:SetVertexColor(BG[1], BG[2], BG[3], 0.97)
		if not u:IsShown() then
			u:SetAlpha(0)
			u:Show()
		end
		local ua = u:GetAlpha()
		Tween(u, "a", 0.2, E.out, function(p) u:SetAlpha(lerp(ua, 1, p)) end)
	else
		u:Hide()
	end
end

function M:SpotLeave()
	if self.peeking then return end
	if self.spotTimer then self.spotTimer:Cancel() end
	-- 줄 사이를 옮겨 갈 때 깜빡이지 않게 잠깐 기다렸다가
	self.spotTimer = C_Timer.NewTimer and C_Timer.NewTimer(0.12, function()
		self.spotTimer = nil
		local over
		for _, pg in pairs(self.pages or {}) do
			if pg:IsShown() then
				for _, r in ipairs(pg.rows or {}) do if r.hover then over = r end end
			end
		end
		if not over then self:SpotFor(nil) end
	end)
	if not self.spotTimer then self:SpotFor(nil) end
end

function M:Peek(on)
	local f = self.f
	if not f or (on and (self.peeking or not f:IsShown())) or (not on and not self.peeking) then return end
	self.peeking = on or nil
	local a0 = f:GetAlpha()
	Tween(f, "peek", on and 0.2 or 0.25, E.out, function(p) f:SetAlpha(lerp(a0, on and 0.07 or 1, p)) end)
	if on then
		self:SpotFor(self.lastSpot)
	else
		local over = self.lastSpot
		self:SpotFor(nil)
		if over then
			for _, r in ipairs(self:RowsFor(over.id)) do if r.hover then self:SpotFor(over) end end
		end
	end
end

-------------------------------------------------------------------------------
-- 본문: 분류 페이지 (3칸 · 짧은 칸부터 채움)
-------------------------------------------------------------------------------
function M:MakePage(groups, key)
	local pg = CreateFrame("Frame", nil, self.body)
	pg:SetPoint("TOPLEFT")
	pg.groups, pg.rows, pg.byId = {}, {}, {}
	for _, g in ipairs(groups) do
		local gf = { title = Ink:Text(pg, F.bold, 15, C.text, "LEFT"), rows = {} }
		gf.title:SetText(g.t)
		for _, e in ipairs(g.rows) do
			local r = NewRow(pg, e)
			gf.rows[#gf.rows + 1] = r
			pg.rows[#pg.rows + 1] = r
			pg.byId[e.id] = r
		end
		pg.groups[#pg.groups + 1] = gf
	end
	pg.key = key
	pg:Hide()
	return pg
end

function M:Page(id)
	local pg = self.pages[id]
	if not pg then
		pg = self:MakePage(self.groups[id] or {}, id)
		self.pages[id] = pg
	end
	return pg
end

function M:LayoutPage(pg)
	local W = Dim()
	local inner = W - PADX * 2
	local colW = inner / 3
	local heights = { 0, 0, 0 }
	local used = 0
	for i, g in ipairs(pg.groups) do
		local c = i
		if i > 3 then
			c = 1
			for k = 2, 3 do if heights[k] < heights[c] then c = k end end
		end
		used = math.max(used, c)
		local padL = c == 1 and 0 or 26
		local padR = c == 3 and 0 or 26
		local x = 14 + (c - 1) * colW + padL
		local gw = colW - padL - padR
		local y = heights[c] + (heights[c] == 0 and 22 or 28)
		g.title:ClearAllPoints()
		g.title:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -y)
		g.tx, g.ty = x, y
		y = y + 30
		for j, r in ipairs(g.rows) do
			local h = r:Layout(gw)
			r.px, r.py = x - 12, y
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", pg, "TOPLEFT", r.px, -r.py)
			r:SetSize(gw + 24, h)
			r.line:SetShown(j < #g.rows)
			y = y + h
		end
		heights[c] = y + 4
	end
	pg.used = used
	pg.h = math.max(heights[1], heights[2], heights[3]) + 24
	pg:SetSize(inner + 28, pg.h)
	return pg
end

function M:ShowPage(pg, animate)
	for _, p in pairs(self.pages) do if p ~= pg then p:Hide() end end
	self:LayoutPage(pg)
	self.body:SetSize(pg:GetWidth(), pg.h)
	pg:Show()
	self.curPage = pg
	self.f.empty:Hide()
	self:PlaceCols(pg.used or 3)
	self:RefreshRows(pg)
	self:ScrollTo(0, true)
	-- 줄이 차례로 떠오른다
	if animate and Motion() > 0 then
		local n = 0
		for _, g in ipairs(pg.groups) do
			n = n + 1
			local t, d = g.title, math.min(n, 16) * 0.03
			t:SetAlpha(0)
			Tween(t, "in", 0.4, E.out5, function(p) t:SetAlpha(p) end, nil, d)
			for _, r in ipairs(g.rows) do
				n = n + 1
				local dl = math.min(n, 16) * 0.03
				r:SetAlpha(0)
				Tween(r, "in", 0.48, E.out5, function(p)
					r:SetAlpha(p)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", pg, "TOPLEFT", r.px, -(r.py + 10 * (1 - p)))
				end, nil, dl)
			end
		end
	else
		for _, g in ipairs(pg.groups) do
			Cancel(g.title, "in"); g.title:SetAlpha(1)
			for _, r in ipairs(g.rows) do Cancel(r, "in"); r:SetAlpha(1) end
		end
	end
end

function M:PlaceCols(used)
	local f = self.f
	local W = Dim()
	local colW = (W - PADX * 2) / 3
	for k, t in ipairs(f.cols) do
		local x = PADX + colW * k
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(HEAD + 1))
		t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, EXTRA + FOOT)
		t:SetShown(k < used)
	end
end

function M:RefreshRows(pg)
	for _, p in pairs(self.pages or {}) do
		if not pg or p == pg then
			for _, r in ipairs(p.rows) do r:Refresh(false) end
		end
	end
end

function M:Pick(id, instant)
	if self.query then
		self.query = nil
		local sb = self.f.search
		if sb.open then self:SearchOpen(false) end
	end
	local same = self.cat == id and self.curPage == self.pages[id] and self.curPage and self.curPage:IsShown()
	self.cat = id
	Ink.db.sheetCat = id
	self:PaintTiles(not instant)
	if same then return end
	self:ShowPage(self:Page(id), not instant)
end

-------------------------------------------------------------------------------
-- 검색: 이름 · 설명 · 분류에서 찾아 분류별로 묶어 보여 준다
-------------------------------------------------------------------------------
function M:Search(text)
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		if self.query then
			self.query = nil
			self:PaintTiles(true)
			self:ShowPage(self:Page(self.cat or "general"), true)
		end
		return
	end
	self.query = text
	local q = text:lower()
	local groups, catLabel = {}, {}
	for _, c in ipairs(CATS) do catLabel[c.id] = c.label end
	local byCat, order = {}, {}
	for _, e in ipairs(self.entries) do
		local hay = (e.label .. " " .. (e.desc or "") .. " " .. (catLabel[e.cat] or "") .. " " .. (e.key or "")):lower()
		if hay:find(q, 1, true) then
			if not byCat[e.cat] then byCat[e.cat] = { t = catLabel[e.cat], rows = {} }; order[#order + 1] = e.cat end
			table.insert(byCat[e.cat].rows, e)
		end
	end
	for _, c in ipairs(CATS) do if byCat[c.id] then groups[#groups + 1] = byCat[c.id] end end
	-- 검색 페이지 하나를 계속 쓴다 (줄 · 제목은 모아 두고 다시 씀)
	local pg = self.searchPage
	if not pg then
		pg = CreateFrame("Frame", nil, self.body)
		pg:SetPoint("TOPLEFT")
		pg.titles, pg.pool, pg.key = {}, {}, "?search"
		self.searchPage = pg
		self.pages["?search"] = pg
	end
	for _, t in ipairs(pg.titles) do t:Hide() end
	for _, r in pairs(pg.pool) do r:Hide() end
	pg.groups, pg.rows, pg.byId = {}, {}, {}
	for gi, g in ipairs(groups) do
		local t = pg.titles[gi]
		if not t then
			t = Ink:Text(pg, F.bold, 15, C.text, "LEFT")
			pg.titles[gi] = t
		end
		t:SetText(g.t)
		t:Show()
		local gf = { title = t, rows = {} }
		for _, e in ipairs(g.rows) do
			local r = pg.pool[e.id]
			if not r then
				r = NewRow(pg, e)
				pg.pool[e.id] = r
			end
			r:Show()
			gf.rows[#gf.rows + 1] = r
			pg.rows[#pg.rows + 1] = r
			pg.byId[e.id] = r
		end
		pg.groups[gi] = gf
	end
	self:PaintTiles(true)
	self:ShowPage(pg, true)
	if #groups == 0 then
		self.f.empty:SetText("‘" .. text .. "’ 에 맞는 설정이 없어요")
		self.f.empty:Show()
		self.body:SetHeight(200)
	end
end

-------------------------------------------------------------------------------
-- 스크롤 (부드럽게)
-------------------------------------------------------------------------------
function M:ScrollRange()
	local sf = self.sf
	local h = self.body:GetHeight() or 0
	return math.max(0, h - (sf:GetHeight() or 0))
end

function M:ScrollTo(v, instant)
	local sf = self.sf
	local range = self:ScrollRange()
	v = math.max(0, math.min(range, v))
	self.scrollTarget = v
	local from = sf:GetVerticalScroll() or 0
	local function apply(y)
		sf:SetVerticalScroll(y)
		self:PaintThumb()
	end
	if instant then
		Cancel(sf, "scroll")
		apply(v)
	else
		Tween(sf, "scroll", 0.3, E.out, function(p) apply(lerp(from, v, p)) end)
	end
end

function M:ScrollBy(d)
	self:ScrollTo((self.scrollTarget or self.sf:GetVerticalScroll() or 0) + d)
end

function M:PaintThumb()
	local f = self.f
	local range = self:ScrollRange()
	local th = f.track:GetHeight() or 0
	if range <= 1 or th <= 0 then f.track:Hide(); f.thumb:Hide(); return end
	f.track:Show(); f.thumb:Show()
	local view = self.sf:GetHeight()
	local h = math.max(28, th * view / (view + range))
	f.thumb:SetHeight(h)
	f.thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
	f.thumb:ClearAllPoints()
	f.thumb:SetPoint("TOP", f.track, "TOP", 0, -(th - h) * ((self.sf:GetVerticalScroll() or 0) / range))
end

-------------------------------------------------------------------------------
-- 크기 · 위치
-------------------------------------------------------------------------------
function M:SetOffset(y)
	self.offY = y
	local f = self.f
	f:ClearAllPoints()
	f:SetPoint("BOTTOM", Ink.root, "BOTTOM", 0, y - EXTRA)
end

function M:FitSheet(live)
	local f = self.f
	local W, H = Dim()
	f:SetSize(W, H + EXTRA)
	if self.state ~= "closing" then self:SetOffset(self.offY or 0) end
	-- 검색 칸 폭: 독과 닫기 버튼 사이에 들어가게
	local navW = #CATS * TILE_W + (#CATS - 1) * TILE_GAP
	local space = (W - navW) / 2 - PADX - 40 - 10 - 16
	self.searchW = math.max(120, math.min(270, space))
	if f.search.open then f.search:SetWidth(self.searchW) end
	-- 독이 너무 넓으면 타일을 줄인다
	local scale = math.min(1, (W - 2 * (PADX + 150)) / navW)
	f.nav:SetScale(math.max(0.72, scale))
	if self.curPage then
		self:LayoutPage(self.curPage)
		self.body:SetSize(self.curPage:GetWidth(), self.curPage.h)
		self:PlaceCols(self.curPage.used or 3)
		if not live then self:RefreshRows(self.curPage) end
	end
	self:PaintThumb()
end

-------------------------------------------------------------------------------
-- 열기 · 닫기
-------------------------------------------------------------------------------
function M:Sheen()
	local f = self.f
	if Motion() == 0 then return end
	local W = Dim()
	local sw = W * 0.3
	f.sheenL:SetWidth(sw / 2)
	f.sheenR:SetWidth(sw / 2)
	Tween(f, "sheen", 1.4, E.out, function(p)
		local x = lerp(-sw, W + sw * 0.3, p)
		local a = p < 0.2 and p / 0.2 or (1 - (p - 0.2) / 0.8)
		f.sheenL:ClearAllPoints()
		f.sheenL:SetPoint("TOPLEFT", f.clip, "TOPLEFT", x, 0)
		f.sheenR:ClearAllPoints()
		f.sheenR:SetPoint("LEFT", f.sheenL, "RIGHT", 0, 0)
		f.sheenL:SetAlpha(a); f.sheenR:SetAlpha(a)
	end, function() f.sheenL:SetAlpha(0); f.sheenR:SetAlpha(0) end, 0.25)
end

function M:Open(cat)
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투가 끝난 뒤에 설정 창을 열 수 있어요.")
		return
	end
	if not self.entries then self:BuildRegistry() end
	if not self.f then self:Build() end
	local cfg = mod("Config")
	if cfg and cfg.editing then cfg:SetEdit(false) end
	local f = self.f
	local wasOpen = self.state == "open"
	self.state = "open"
	f:SetAlpha(1)
	self.peeking = nil
	f:SetPropagateKeyboardInput(true)
	local _, H = Dim()
	if not wasOpen then
		if not f:IsShown() then self.offY = -(H + 60) end
		self:FitSheet()
		f:Show()
	end
	self:Pick(cat or self.cat or Ink.db.sheetCat or "general", wasOpen)
	if wasOpen and not cat then return end
	self:PaintFooter()
	if not wasOpen then
		Sound("open")
		local from = self.offY or -(H + 60)
		Tween(self, "slide", 0.7, E.back, function(p) self:SetOffset(lerp(from, 0, p)) end, function() self:SetOffset(0) end)
		self:Sheen()
		-- 독 타일이 차례로 떠오른다
		for i, t in ipairs(f.tiles) do
			t:SetAlpha(0)
			Tween(t, "in", 0.4, E.out, function(p) t:SetAlpha(p) end, nil, 0.12 + i * 0.025)
		end
	end
end

function M:Close()
	local f = self.f
	if not f or self.state ~= "open" then return end
	self.state = "closing"
	if f.search.open then self:SearchOpen(false) end
	self:SpotFor(nil, true)
	self:Peek(false)
	f:SetAlpha(1)
	Sound("close")
	local _, H = Dim()
	local from, to = self.offY or 0, -(H + 60)
	Tween(self, "slide", 0.42, E.inn, function(p) self:SetOffset(lerp(from, to, p)) end, function()
		f:Hide()
		self.state = nil
		self:SetOffset(to)
	end)
end

function M:Toggle(cat)
	if self.state == "open" and not cat then self:Close() else self:Open(cat) end
end

function M:IsOpen() return self.state == "open" end

-- 편집 모드로: 시트를 내리고 편집 모드를 켠다 (편집 모드에서 완료를 누르면 시트가 다시 올라온다)
function M:ToEdit()
	local cfg = mod("Config")
	if not cfg or InCombatLockdown() then return end
	self.reopen = true
	self:Close()
	C_Timer.After(Motion() > 0 and 0.18 or 0, function() cfg:SetEdit(true) end)
end

function M:EditDone()
	if self.reopen then
		self.reopen = nil
		C_Timer.After(0.05, function() M:Open() end)
	end
end

-------------------------------------------------------------------------------
function M:Init()
	self:BuildRegistry()
	-- 이번 접속의 값 (/reload 가 필요한 설정은 이 값과 다르면 "다시 불러오기" 표시)
	self.login = {}
	for _, e in ipairs(self.entries) do
		if e.reload then
			local ok, v = pcall(Get, e)
			if ok then self.login[e.id] = v end
		end
	end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
	ev:RegisterEvent("UI_SCALE_CHANGED")
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			if M.state == "open" then M:Close() end
		elseif M.f and M.f:IsShown() then
			C_Timer.After(0.1, function() M:FitSheet() end)
		end
	end)
end
