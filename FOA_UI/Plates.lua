-- InkUI · 네임플레이트
--  적: 이름 / 체력바 / 체력% / 내 디버프(위) / 시전바(아래, 차단 가능 여부 색 구분) / 대상 강조 / 어그로 표시 / 징표
--  아군: 이름만 깔끔하게
-- 블리자드 기본 네임플레이트는 투명하게 두고(클릭 판정은 그대로) 그 위에 Ink 프레임을 얹는다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Plates")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

local W, BAR_H = 132, 6
local SetRank -- 아래에서 정의 (정예/희귀 테두리)
local QUEST_COLOR = C.accent -- 퀘스트 대상 몹 색
local plates = {}   -- unit → ink 프레임
M.plates = plates

-------------------------------------------------------------------------------
-- 블리자드 플레이트 숨기기
-------------------------------------------------------------------------------
local hookedUF = setmetatable({}, { __mode = "k" })

-- 던전 · 파티에서는 블리자드 이름표 값이 비공개(secret)라서 바로 참/거짓을 따지면 오류가 난다.
--  plain() 으로 꺼내 보고 모르면 건드리지 않는다.
local function KillMouse(f)
	if not f or f:IsForbidden() then return end
	if f.EnableMouse then
		local okM, m = pcall(f.IsMouseEnabled, f)
		local okP, pr = pcall(f.IsProtected, f)
		if okM and okP and plain(m) == true and plain(pr) == false then pcall(f.EnableMouse, f, false) end
	end
	for _, c in ipairs({ f:GetChildren() }) do KillMouse(c) end
end

local function HideBlizzard(plate, unit)
	local uf = plate.UnitFrame
	if not uf or uf:IsForbidden() then return end
	uf:SetAlpha(0)
	if uf.castBar then uf.castBar:UnregisterAllEvents() end
	if uf.AurasFrame then pcall(KillMouse, uf.AurasFrame) end
	-- 징표: FOA 아이콘을 쓰고(이름 왼쪽), 값을 못 읽는 경우에만 블리자드 것을 대신 보인다 (UpdateInfo)
	if plate.ink then plate.ink.blizzRT = uf.RaidTargetFrame end
	if not hookedUF[uf] then
		hookedUF[uf] = true
		local busy
		hooksecurefunc(uf, "SetAlpha", function(self, a)
			if busy or not a or a == 0 then return end
			local u = self.unit or (self.GetUnit and self:GetUnit())
			if u and plates[u] then
				busy = true
				self:SetAlpha(0)
				busy = nil
			end
		end)
	end
end

local function RestoreBlizzard(plate)
	local uf = plate.UnitFrame
	if not uf or uf:IsForbidden() then return end
	uf:SetAlpha(1)
end

-------------------------------------------------------------------------------
-- Ink 플레이트 만들기
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 역할 NPC 아이콘 (경매인 · 은행원 · 여관주인 · 비행 조련사 · 상인 · 수리 …)
--  NPC 이름 아래 <직함> 줄을 읽어서 역할을 정한다 (한글 / 영어 클라이언트 모두)
--  위에서부터 먼저 맞는 것이 이긴다.
-------------------------------------------------------------------------------
local ROLES = {
	{ key = "inn", icon = "NpcInn", color = "F59E6B", words = { "여관주인", "Innkeeper" } },
	{ key = "mail", icon = "NpcMail", color = "7FB8FF", words = { "우편", "우체", "편지", "Mail", "Postmaster", "Postal", "Courier" } },
	{ key = "bank", icon = "NpcBank", color = "6FD39A", words = { "은행", "Banker", "Bank" } },
	{ key = "auction", icon = "NpcAuction", color = "F2C14E", words = { "경매", "Auctioneer" } },
	{ key = "stable", icon = "NpcStable", color = "A9D88B", words = { "야수 조련사", "Stable Master" } },
	{ key = "flight", icon = "NpcFlight", color = "86DDF2", words = { "비행", "그리폰", "그리핀", "와이번", "히포그리프", "비룡", "박쥐 조련사",
		"Flight Master", "Gryphon Master", "Wind Rider", "Hippogryph Master", "Bat Handler" } },
	{ key = "transmog", icon = "NpcTransmog", color = "F4A3C8", words = { "형상변환", "공허 보관", "Transmogrifier", "Void Storage" } },
	{ key = "upgrade", icon = "NpcUpgrade", color = "FF9547", words = { "강화", "업그레이드", "촉매", "재구성", "Upgrade", "Catalyst", "Reforge" } },
	{ key = "barber", icon = "NpcBarber", color = "E4E8F2", words = { "미용", "Barber" } },
	{ key = "quartermaster", icon = "NpcQuartermaster", color = "86E06C", words = { "병참", "보급관", "명예", "정복", "용맹", "평판",
		"Quartermaster", "Honor", "Conquest", "Valor", "Renown" } },
	{ key = "librarian", icon = "Journal", color = "C9A8FF", words = { "사서", "Librarian" } },
	{ key = "trainer", icon = "NpcTrainer", color = "B9A4FF", words = { "지도자", "교관", "전문기술자", "상급자", "숙련자", "Trainer" } },
	{ key = "repair", icon = "NpcRepair", color = "C9CED6", words = { "대장장이", "방어구", "갑옷", "무기", "수리", "정비",
		"Armorer", "Weaponsmith", "Blacksmith", "Repair" } },
	{ key = "vendor", icon = "NpcVendor", color = "FFF468", words = { "상인", "용품", "음식", "음료", "판매", "공급", "잡화", "상점",
		"무역", "행상", "여행 중인", "교환", "환전", "주화", "물물", "재료", "보석", "골동품", "수집", "기념품", "장신구", "의상", "탈것", "애완",
		"Vendor", "Merchant", "Supplies", "Goods", "Food", "Drink", "Trade", "Trader", "Peddler", "Traveling", "Exchange", "Curator", "Collector", "Outfitter" } },
}
for _, r in ipairs(ROLES) do r.rgb = Ink.hex(r.color); r.tex = Ink.icon(r.icon) end

local roleCache = {} -- 이름 → 역할 (같은 NPC를 다시 읽지 않게)

-- 툴팁 둘째 줄이 직함 (예전엔 "<은행원>", 지금은 괄호 없이 "은행원")
--  직함이 없는 NPC는 둘째 줄이 "90 레벨" 같은 레벨 줄이라 건너뛴다.
local function Subtitle(unit)
	if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
	local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
	if not ok or not data or not data.lines then return end
	local line = data.lines[2]
	local t = line and plain(line.leftText)
	if type(t) ~= "string" or t == "" then return end
	t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	t = t:match("^<(.+)>$") or t
	if t:find("레벨") or t:find("Level") or t:find("^%d") then return end
	return t
end

local function NpcRole(unit)
	if Ink.db.npcIcons == false then return end
	if plain(UnitIsPlayer(unit)) then return end
	local name = plain(UnitName(unit))
	if type(name) == "string" and roleCache[name] ~= nil then return roleCache[name] or nil end
	local sub = Subtitle(unit)
	local found = false
	-- "수습 · 숙련 · 전문 · 대가 · 장인 ○○" 같은 직함은 전문기술 상급자 (대장장이라도 수리 아님)
	if sub and (sub:find("^수습 ") or sub:find("^숙련 ") or sub:find("^전문 ") or sub:find("^대가 ") or sub:find("^장인 ")
		or sub:find("^Apprentice ") or sub:find("^Journeyman ") or sub:find("^Expert ") or sub:find("^Artisan ") or sub:find("^Master ")) then
		for _, r in ipairs(ROLES) do if r.key == "trainer" then found = r end end
	end
	if sub and not found then
		for _, r in ipairs(ROLES) do
			for _, w in ipairs(r.words) do
				if sub:find(w, 1, true) then found = r break end
			end
			if found then break end
		end
	end
	-- 직함을 못 읽었으면(아직 정보가 안 왔을 때 등) 저장하지 않고 다음에 다시 본다
	if type(name) == "string" and sub then roleCache[name] = found end
	return found or nil
end

local function Build(plate)
	local f = CreateFrame("Frame", nil, plate)
	f:SetSize(W, 40)
	f:SetPoint("CENTER", plate, "CENTER", 0, 0)
	f:SetFrameStrata("LOW")

	-- 체력바: 어두운 받침 + 얇은 바
	f.back = CreateFrame("Frame", nil, f)
	f.back:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.back:SetSize(W + 4, BAR_H + 4)
	f.back.bg = Ink:Round(f.back, "BACKGROUND", true, false)
	f.back.bg:SetAllPoints()
	f.back.bg:SetVertexColor(0.02, 0.025, 0.035, 0.72)
	f.back.bd = Ink:Round(f.back, "BORDER", true, true)
	f.back.bd:SetAllPoints()
	f.back.bd:SetVertexColor(1, 1, 1, 0.08)
	f.glow = f.back:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.glow:SetTexture(Ink.tex.glow)
	f.glow:SetPoint("TOPLEFT", -14, 12)
	f.glow:SetPoint("BOTTOMRIGHT", 14, -12)
	f.glow:SetAlpha(0)

	f.hp = Ink:Bar(f.back, W, BAR_H, C.red, { 1, 1, 1, 0.06 })
	f.hp:SetPoint("CENTER")

	-- 대상 표시용 양쪽 꺾쇠
	f.markL = f.back:CreateTexture(nil, "OVERLAY")
	f.markL:SetSize(5, 5)
	f.markL:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	f.markL:SetRotation(math.rad(45))
	f.markL:SetPoint("RIGHT", f.back, "LEFT", -5, 0)
	f.markR = f.back:CreateTexture(nil, "OVERLAY")
	f.markR:SetSize(5, 5)
	f.markR:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	f.markR:SetRotation(math.rad(45))
	f.markR:SetPoint("LEFT", f.back, "RIGHT", 5, 0)

	-- 이름 / 체력% / 징표 / 정예 표시
	-- 레벨 (이름 왼쪽 · 레벨 차이 색: 회색 · 초록 · 노랑 · 주황 · 빨강)
	f.lvl = Ink:Text(f, F.latinB or F.semi, 11, C.text, "LEFT")
	f.lvl:SetPoint("BOTTOMLEFT", f.back, "TOPLEFT", 2, 3)
	f.name = Ink:Text(f, F.semi, 11, C.text, "LEFT")
	f.name:SetPoint("BOTTOMLEFT", f.back, "TOPLEFT", 2, 3)
	f.name:SetWidth(W - 34)
	f.pct = Ink:Text(f, F.numR, 11, C.soft, "RIGHT")
	f.pct:SetPoint("BOTTOMRIGHT", f.back, "TOPRIGHT", -2, 3)
	f.raid = f:CreateTexture(nil, "OVERLAY")
	f.raid:SetSize(15, 15)
	f.raid:SetPoint("RIGHT", f.back, "TOPLEFT", -12, 9)   -- 레벨 · 이름 줄 왼쪽 바깥
	f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	f.raid:Hide()
	f.elite = f:CreateTexture(nil, "OVERLAY")
	f.elite:SetSize(7, 7)
	f.elite:SetRotation(math.rad(45))
	f.elite:SetPoint("BOTTOMLEFT", f.back, "TOPLEFT", -7, 6)
	f.elite:Hide()

	-- 정예(금) / 희귀(은) 테두리: 은은하게 숨쉬는 빛 + 몇 초마다 지나가는 반짝임
	local rk = CreateFrame("Frame", nil, f.back)
	rk:SetPoint("TOPLEFT", -2, 2)
	rk:SetPoint("BOTTOMRIGHT", 2, -2)
	rk:SetFrameLevel(f.back:GetFrameLevel() + 4)
	rk.glow = rk:CreateTexture(nil, "BACKGROUND")
	rk.glow:SetTexture(Ink.tex.glow)
	rk.glow:SetBlendMode("ADD")
	rk.glow:SetPoint("TOPLEFT", -12, 10)
	rk.glow:SetPoint("BOTTOMRIGHT", 12, -10)
	rk.bd = Ink:Round(rk, "OVERLAY", true, true)
	rk.bd:SetAllPoints()
	local pulse = rk.glow:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local pa = pulse:CreateAnimation("Alpha")
	pa:SetFromAlpha(0.12)
	pa:SetToAlpha(0.5)
	pa:SetDuration(1.2)
	pa:SetSmoothing("IN_OUT")
	rk.pulse = pulse
	-- 반짝임: 테두리 안쪽을 왼쪽에서 오른쪽으로 훑고 지나간다 (테두리 밖으로는 안 나간다)
	rk.clip = CreateFrame("Frame", nil, rk)
	rk.clip:SetAllPoints()
	rk.clip:SetClipsChildren(true)
	rk.sheen = rk.clip:CreateTexture(nil, "OVERLAY")
	rk.sheen:SetTexture(Ink.tex.glow)
	rk.sheen:SetBlendMode("ADD")
	rk.sheen:SetSize(28, 22)
	rk.sheen:SetPoint("CENTER", rk.clip, "LEFT", -20, 0)
	local sw = rk.sheen:CreateAnimationGroup()
	sw:SetLooping("REPEAT")
	local mv = sw:CreateAnimation("Translation")
	mv:SetOffset(W + 44, 0)
	mv:SetDuration(0.9)
	mv:SetStartDelay(2.6)
	mv:SetSmoothing("IN_OUT")
	rk.sweep = sw
	rk:Hide()
	f.rank = rk

	-- 역할 NPC 배지 (이름 위)
	local rb = CreateFrame("Frame", nil, f)
	rb:SetSize(24, 24)
	rb:SetPoint("BOTTOM", f.name, "TOP", 0, 3)
	rb.disc = rb:CreateTexture(nil, "BACKGROUND")
	rb.disc:SetTexture(Ink.tex.disc)
	rb.disc:SetAllPoints()
	rb.disc:SetVertexColor(0.035, 0.04, 0.052, 0.92)
	rb.ring = rb:CreateTexture(nil, "BORDER")
	rb.ring:SetTexture(Ink.tex.ring)
	rb.ring:SetAllPoints()
	rb.icon = rb:CreateTexture(nil, "ARTWORK")
	rb.icon:SetSize(14, 14)
	rb.icon:SetPoint("CENTER")
	rb:Hide()
	f.role = rb
	-- NPC 직함 (<여관주인> 같은 줄): 이름 바로 아래 작게
	f.sub = Ink:Text(f, F.sans, 9, C.muted, "CENTER")
	f.sub:SetPoint("TOP", f.name, "BOTTOM", 0, -1)
	f.sub:SetWidth(W + 40)
	f.sub:Hide()

	-- 내 디버프 (이름 위)
	f.auras = ns.AuraBox(f, 20, 6, { growUp = true, noMouse = true,
		groups = { { key = "mine", filter = "HARMFUL|PLAYER" } } })
	f.auras:SetPoint("BOTTOMLEFT", f.name, "TOPLEFT", -2, 14)

	-- 시전바 (체력바 아래)
	local cb = CreateFrame("Frame", nil, f)
	cb:SetSize(W, 20)
	cb:SetPoint("TOPLEFT", f.back, "BOTTOMLEFT", 2, -3)
	cb.bar = Ink:Bar(cb, W, 4, C.orange, { 1, 1, 1, 0.08 })
	cb.bar:SetPoint("TOPLEFT")
	-- 차단 불가면 회색 덮개가 보인다 (secret 값도 안전하게)
	cb.lock = cb.bar:CreateTexture(nil, "OVERLAY")
	cb.lock:SetAllPoints(cb.bar:GetStatusBarTexture())
	cb.lock:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)
	cb.lock:SetAlpha(0)
	cb.icon = cb:CreateTexture(nil, "ARTWORK")
	cb.icon:SetSize(16, 16)
	cb.icon:SetPoint("TOPRIGHT", cb.bar, "TOPLEFT", -5, 2)
	cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cb.name = Ink:Text(cb, F.sans, 10, C.orange, "LEFT")
	cb.name:SetPoint("TOPLEFT", cb.bar, "BOTTOMLEFT", 0, -3)
	cb.name:SetWidth(W - 30)
	cb.lockName = Ink:Text(cb, F.sans, 10, C.muted, "LEFT")
	cb.lockName:SetPoint("TOPLEFT", cb.bar, "BOTTOMLEFT", 0, -3)
	cb.lockName:SetWidth(W - 30)
	cb.lockName:SetAlpha(0)
	cb.time = Ink:Text(cb, F.latin, 10, C.muted, "RIGHT")
	cb.time:SetPoint("TOPRIGHT", cb.bar, "BOTTOMRIGHT", 0, -3)
	cb:Hide()
	cb:SetScript("OnUpdate", function(self)
		if self.flash then
			if GetTime() > self.flash then self.flash = nil; self:Hide() end
			return
		end
		if self.dur then
			safe(function() self.time:SetFormattedText("%.1f", self.dur:GetRemainingDuration()) end)
		elseif self.endTime then
			local now = GetTime() * 1000
			self.bar:SetValue(now)
			self.time:SetFormattedText("%.1f", math.max(0, (self.endTime - now) / 1000))
		end
	end)
	f.cast = cb

	-- 퀘스트 대상 표시: 바 오른쪽 작은 아이콘(처치 = 칼 / 수집 = 꾸러미) + 바 아래 진행 수치
	f.qicon = f.back:CreateTexture(nil, "OVERLAY")
	f.qicon:SetSize(13, 13)
	f.qicon:SetPoint("LEFT", f.back, "RIGHT", 14, 0)
	f.qicon:Hide()
	f.qtext = Ink:Text(f, F.latinB, 10, C.accent, "RIGHT")
	f.qtext:SetPoint("TOPRIGHT", f.back, "BOTTOMRIGHT", -2, -3)
	f.qtext:SetShadowOffset(1, -1)
	f.qtext:SetShadowColor(0, 0, 0, 1)
	f.qtext:Hide()
	-- 시전바가 뜨면 진행 수치와 겹치니 잠시 숨긴다
	cb:HookScript("OnShow", function() f.qtext:SetAlpha(0) end)
	cb:HookScript("OnHide", function() f.qtext:SetAlpha(1) end)

	-- 효과: 체력 잔상 · 대상 괄호 · 어그로 맥박 · 차단 알림 · 퀘스트 톡 · 차단 흔들림
	if ns.FX then
		pcall(function()
			ns.FX.Trail(f.hp, 0.4)
			ns.FX.AttachPlate(f)
			cb.fxShakeP = ns.FX.Shake(cb, 4)
		end)
	end

	f:Hide()
	plate.ink = f
	C_Timer.After(0, function() Ink:CrispTree(f) end)
	return f
end

-------------------------------------------------------------------------------
-- 갱신
-------------------------------------------------------------------------------
local function ReactionColor(u)
	if plain(UnitIsPlayer(u)) then return ns.ClassColor(u) end
	if plain(UnitIsTapDenied(u)) then return 0.55, 0.57, 0.6 end
	local r = plain(UnitReaction(u, "player"))
	if r then
		if r <= 3 then return C.red[1], C.red[2], C.red[3] end
		if r == 4 then return C.orange[1], C.orange[2], C.orange[3] end
		return C.green[1], C.green[2], C.green[3]
	end
	return C.red[1], C.red[2], C.red[3]
end

function M:UpdateHealth(f)
	local u = f.unit
	safe(function()
		f.hp:SetMinMaxValues(0, UnitHealthMax(u))
		f.hp:SetValue(UnitHealth(u))
	end)
	f.pct:SetText(ns.HealthPercentText(u) .. "%")
	if ns.FX then ns.FX.TrailSet(f.hp, u) end
end

function M:UpdateLook(f)
	local u = f.unit
	-- 대상 여부: "대상의 이름표 = 이 이름표"로 비교 (UnitIsUnit 은 비공개 값일 수 있다)
	local tp = C_NamePlate.GetNamePlateForUnit("target")
	local isTarget = tp ~= nil and tp == f:GetParent()
	local a = C.accent
	-- 어그로: 내가 위협 1순위면 붉은 테두리
	local threat = plain(UnitThreatSituation("player", u))
	if ns.FX then
		ns.FX.PlateTarget(f, isTarget)
		ns.FX.PlateAggro(f, threat and threat >= 2 and not isTarget)
	end
	if isTarget then
		f.back.bd:SetVertexColor(a[1], a[2], a[3], 1)
		f.glow:SetVertexColor(a[1], a[2], a[3])
		f.glow:SetAlpha(0.45)
		f.name:SetTextColor(a[1], a[2], a[3])
		f.markL:Show(); f.markR:Show()
		f:SetScale(1.12)
		f:SetFrameLevel(20)
	else
		if threat and threat >= 2 then
			f.back.bd:SetVertexColor(C.red[1], C.red[2], C.red[3], 0.9)
		elseif f.questInfo then
			-- 퀘스트 대상: 체력바 색(적대 빨강 / 중립 주황)은 그대로 두고 테두리만 노랗게
			f.back.bd:SetVertexColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3], 1)
		else
			f.back.bd:SetVertexColor(1, 1, 1, 0.08)
		end
		-- 퀘스트 대상은 은은한 노란 빛
		if f.questInfo then
			f.glow:SetVertexColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3])
			f.glow:SetAlpha(0.3)
		else
			f.glow:SetAlpha(0)
		end
		f.name:SetTextColor(C.text[1], C.text[2], C.text[3])
		f.markL:Hide(); f.markR:Hide()
		f:SetScale(1)
		f:SetFrameLevel(5)
	end
	-- 대상이 있을 때 나머지는 살짝 흐리게
	f:SetAlpha((plain(UnitExists("target")) and not isTarget) and 0.6 or 1)
end

-- 정예·희귀 테두리 켜기/끄기 (color = 테두리·빛, shine = 지나가는 반짝임 색)
local GOLD = { 1, 0.80, 0.30 }
local SILVER = { 0.84, 0.88, 0.95 }
SetRank = function(f, color, shine)
	local rk = f.rank
	if not color then
		if rk:IsShown() then rk.pulse:Stop(); rk.sweep:Stop(); rk:Hide() end
		return
	end
	rk.bd:SetVertexColor(color[1], color[2], color[3], 0.95)
	rk.glow:SetVertexColor(color[1], color[2], color[3])
	rk.sheen:SetVertexColor(shine[1], shine[2], shine[3], 0.9)
	if not rk:IsShown() then
		rk:Show()
		rk.pulse:Play()
		rk.sweep:Play()
	end
end

-------------------------------------------------------------------------------
-- 퀘스트 대상 찾기: 몹 툴팁의 퀘스트 목표 줄("- 6/8 오우거 처치")을 읽는다
-------------------------------------------------------------------------------
local LINE_OBJ = Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8
local KILL_WORDS = { "처치", "죽이", "물리치", "쓰러뜨", "사냥", "제거", "격파", "파괴", "부수", "slain", "kill", "defeat", "destroy" }

local function IsKill(t)
	local low = t:lower()
	for _, w in ipairs(KILL_WORDS) do if low:find(w, 1, true) then return true end end
	return false
end

local QuestObjectives
-- 목표 글자 비교용: 색 코드 · 숫자 · 기호 · 빈칸을 뺀다 ("- 허벅지 고기: 0/4" → "허벅지고기")
local function Norm(t)
	return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%d%s%p]", ""))
end
-- 목표 글자에서 대상 이름만: 진행 수치 · 기호 · "처치" 같은 낱말을 뺀다 ("새끼 그물독거미 처치: 0/8" → "새끼 그물독거미")
local function Phrase(t)
	t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%d+%s*/%s*%d+", ""):gsub("%d+%%", ""):gsub("：", " "):gsub("[:%-%(%)%[%]]", " ")
	local words = {}
	for w in t:gmatch("%S+") do if not IsKill(w) then words[#words + 1] = w end end
	return table.concat(words, " ")
end
M.Phrase = Phrase

-- 툴팁 목표 줄이 지금 퀘스트 로그의 안 끝난 목표인지 (이미 끝냈거나 넘긴 퀘스트가 툴팁에 남아 있을 때 거른다)
local function InLog(t)
	if not (QuestObjectives and C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetNumQuestLogEntries) then return true end
	local list = QuestObjectives()
	local n = Norm(t)
	if n == "" then return false end
	for _, o in ipairs(list) do
		local on = o.norm
		if not on then on = Norm(o.text); o.norm = on end
		if on ~= "" and (on == n or on:find(n, 1, true) or n:find(on, 1, true)) then return true end
	end
	return false
end

-- 툴팁의 퀘스트 목표 줄에서 아직 안 끝난 진행 수치를 찾는다
local function ScanQuestLines(unit)
	if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
	local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
	if not ok or not data or not data.lines then return end
	for i = 2, #data.lines do
		local line = data.lines[i]
		local t = line and plain(line.leftText)
		local lt = line and plain(line.type)
		if type(t) == "string" and (lt == LINE_OBJ or (lt == nil and t:find("^%s*%-"))) and not plain(line.completed) then
			t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			local cur, max = t:match("(%d+)%s*/%s*(%d+)")
			local pct = t:match("(%d+)%%")
			local done = (cur and tonumber(cur) >= tonumber(max)) or (pct and tonumber(pct) >= 100)
			if (cur or pct) and not done and InLog(t) then
				return {
					kind = (pct or IsKill(t)) and "kill" or "loot",
					text = cur and (cur .. "/" .. max) or (pct .. "%"),
				}
			end
		end
	end
end

-- 몹 번호 (GUID "Creature-0-…-몹번호-…")
local function NpcIDOf(unit)
	local ok, g = pcall(UnitGUID, unit)
	g = ok and plain(g)
	if type(g) ~= "string" then return end
	local kind, _, _, _, _, id = strsplit("-", g)
	if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- 퀘스트 아이템 이름 (비교용으로 다듬은 것) · 아직 못 불러왔으면 요청만 하고 다음 번에
local dropName = {}
local function DropItemNorm(id)
	local n = dropName[id]
	if n then return n end
	local name = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (C_Item.GetItemInfo and C_Item.GetItemInfo(id))
	name = plain(name)
	if type(name) == "string" and name ~= "" then
		n = Norm(name); dropName[id] = n
		return n
	end
	if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
	-- 이름이 오면 한 번 다시 그리기 (1초 뒤 · 여러 아이템이어도 한 번)
	if not M.dropRetry then
		M.dropRetry = true
		C_Timer.After(1, function()
			M.dropRetry = nil
			for _, pf in pairs(plates) do
				if pf.unit and not pf.friendly and not pf.object then pcall(M.ApplyQuest, M, pf) end
			end
		end)
	end
end

-- 이 몹이 떨구는 퀘스트 아이템이 지금 안 끝난 줍기 목표인지 (자료: QuestDrops.lua · AllTheThings)
--  "밀림 치료제 1/7" ← 쿠르젠 약사 처럼 몹 이름과 아이템 이름이 전혀 달라도 찾는다
local function DropQuestInfo(unit)
	local drops = ns.QUEST_DROP_NPC
	local items = drops and drops[NpcIDOf(unit) or 0]
	if not (items and QuestObjectives) then return end
	for _, it in ipairs(items) do
		local n = DropItemNorm(it)
		if n and n ~= "" then
			for _, o in ipairs(QuestObjectives()) do
				if o.type ~= "monster" then
					local on = o.norm
					if not on then on = Norm(o.text); o.norm = on end
					if on ~= "" and on:find(n, 1, true) then
						local have, need = o.numFulfilled, o.numRequired
						return { kind = "loot", text = (need and need > 0 and have) and (have .. "/" .. need) or "" }
					end
				end
			end
		end
	end
end

local function QuestInfo(unit)
	if Ink.db.questPlates == false then return end
	-- 1) 툴팁의 퀘스트 목표 줄 (가장 정확)
	--   포에버(클래식)는 "고기 · 가죽 줍기" 같은 전리품 퀘스트 몹을 퀘스트 관련 몹으로 알려 주지 않아서,
	--   예전처럼 그 대답(false)만 보고 건너뛰면 요리 퀘스트 몹에 표시가 안 떴다 → 툴팁은 늘 읽는다
	local info = ScanQuestLines(unit)
	if info then return info end
	-- 2) 퀘스트 아이템을 떨구는 몹 (몹 번호 → 아이템 자료)
	info = DropQuestInfo(unit)
	if info then return info end
	-- 3) 퀘스트 목표 글자에 몹 이름이 들어 있으면 (예: "식인독수리 고기" ← 식인독수리) 줍기 퀘스트
	local okN, name = pcall(UnitName, unit)
	name = okN and plain(name)
	if type(name) == "string" and #name >= 4 and QuestObjectives then
		-- 이름 전체, 아니면 마지막 낱말(몹 종류: "새끼 뿔엄니멧돼지" → "뿔엄니멧돼지")로 찾는다
		-- 직업 · 역할 낱말(광부 · 일꾼 · 경비병 …)은 다른 무리 몹과 겹쳐서 쓰지 않는다
		local JOB = { ["광부"] = true, ["일꾼"] = true, ["노동자"] = true, ["경비병"] = true, ["정찰병"] = true, ["전사"] = true,
			["주술사"] = true, ["마법사"] = true, ["사냥꾼"] = true, ["약탈자"] = true, ["도둑"] = true, ["산적"] = true, ["강도"] = true,
			["노상강도"] = true, ["경비대"] = true, ["수호병"] = true, ["파수병"] = true, ["병사"] = true, ["대장"] = true, ["두목"] = true }
		local last = name:match("(%S+)$")
		if last and (#last < 6 or JOB[last]) then last = nil end
		local nName = Norm(name)
		for _, o in ipairs(QuestObjectives()) do
			local t = plain(o.text)
			local hit
			if type(t) == "string" then
				local ph = Phrase(t)
				if o.type == "monster" then
					-- 처치 목표는 몹 이름이 통째로 같아야: "새끼 그물독거미 처치"에 그냥 "그물독거미"가 잡히면 안 된다
					hit = ph == name or (nName ~= "" and Norm(ph) == nName)
				else
					-- 줍기 목표는 그 몹 이름으로 시작할 때만 ("식인독수리 고기" ← 식인독수리 / "새끼 거미 다리" ← 거미 X)
					hit = ph:sub(1, #name) == name or (last and last ~= name and ph:sub(1, #last) == last)
				end
			end
			if hit then
				local have, need = o.numFulfilled, o.numRequired
				return { kind = (o.type == "monster") and "kill" or "loot", text = (need and need > 0 and have) and (have .. "/" .. need) or "" }
			end
		end
	end
end

M.QuestInfo = QuestInfo

-------------------------------------------------------------------------------
-- 퀘스트 오브젝트 (바닥에서 줍기 · 부수기 · 열기 같은 상호작용 물체)
--  물체에는 원래 이름표가 없어서, 블리자드 "상호작용 대상(소프트 타겟)" 기능을 켜면
--  내 앞의 가장 가까운 상호작용 물체 하나에 이름표가 생긴다. 그 물체가 퀘스트 대상이면
--  노란 배지 + 진행 수치를 띄운다. (한 번에 하나, 내가 바라보는 쪽의 가까운 물체)
-------------------------------------------------------------------------------
local objCacheStamp = 0
local objCache -- 아직 안 끝난 퀘스트 목표 목록 (퀘스트 로그가 바뀌면 다시 만든다)

QuestObjectives = function()
	if objCache then return objCache end
	objCache = {}
	if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestObjectives) then return objCache end
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		local qid = info and not info.isHeader and info.questID
		-- 다 끝낸(보고만 남은) 퀘스트는 빼기: 포에버는 끝낸 퀘스트 목표가 "안 끝남"으로 남을 때가 있다
		local over = qid and ((C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(qid)) or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(qid)))
		if qid and not over then
			for _, o in ipairs(C_QuestLog.GetQuestObjectives(qid) or {}) do
				if o and not o.finished and type(o.text) == "string" and o.text ~= "" then
					table.insert(objCache, o)
				end
			end
		end
	end
	return objCache
end

local function IsObject(unit)
	if UnitIsGameObject then
		local ok, v = pcall(UnitIsGameObject, unit)
		if ok and plain(v) ~= nil then return plain(v) and true or false end
	end
	local ok, g = pcall(UnitGUID, unit)
	g = ok and plain(g)
	return type(g) == "string" and g:find("^GameObject") ~= nil
end
M.IsObject = IsObject
M.NpcRole, M.Subtitle, M.ROLES = NpcRole, Subtitle, ROLES

local function ObjectQuestInfo(unit)
	if Ink.db.questObjects == false then return end
	-- 1) 물체 툴팁의 퀘스트 목표 줄
	local info = ScanQuestLines(unit)
	if info then return info end
	-- 2) 물체 이름이 들어간 퀘스트 목표
	local okN, name = pcall(UnitName, unit)
	name = okN and plain(name)
	if type(name) == "string" and name ~= "" then
		for _, o in ipairs(QuestObjectives()) do
			if o.text:find(name, 1, true) then
				local need, have = tonumber(o.numRequired), tonumber(o.numFulfilled)
				return {
					kind = IsKill(o.text) and "kill" or "loot",
					text = (need and need > 1 and have) and (have .. "/" .. need) or "",
				}
			end
		end
	end
	-- 3) 블리자드가 퀘스트 관련이라고만 알려 주는 경우
	if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
		local ok, rel = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
		if ok and plain(rel) == true then return { kind = "loot", text = "" } end
	end
	-- 4) 물체 툴팁에 진행 중인 퀘스트 이름이 적혀 있으면 (클래식은 수치 없이 퀘스트 이름만 나올 때가 있다)
	if C_TooltipInfo and C_TooltipInfo.GetUnit then
		local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
		if ok and data and data.lines then
			local titles = M:ActiveQuestTitles()
			for i = 2, #data.lines do
				local t = plain(data.lines[i] and data.lines[i].leftText)
				if type(t) == "string" then
					t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
					if titles[t] then return { kind = "loot", text = titles[t] } end
				end
			end
		end
	end
	-- 5) 물체 이름과 퀘스트 목표 글자가 낱말을 함께 쓰면 (예: 물체 "안센 농장 우물" · 목표 "안센 농장 물 표본")
	if type(name) == "string" and name ~= "" then
		local GENERIC = { ["상자"] = true, ["더미"] = true, ["꾸러미"] = true, ["보따리"] = true, ["궤짝"] = true, ["통"] = true, ["주머니"] = true }
		local words = {}
		for w in name:gmatch("%S+") do if #w >= 4 and not GENERIC[w] then words[#words + 1] = w end end
		for _, o in ipairs(QuestObjectives()) do
			local hit = 0
			for _, w in ipairs(words) do if o.text:find(w, 1, true) then hit = hit + 1 end end
			if hit >= math.min(2, #words) and hit > 0 then
				local need, have = tonumber(o.numRequired), tonumber(o.numFulfilled)
				return { kind = "loot", text = (need and need > 1 and have) and (have .. "/" .. need) or "" }
			end
		end
	end
end

-- 진행 중(아직 안 끝난) 퀘스트 이름 → 진행 수치 글자
function M:ActiveQuestTitles()
	if self.titleCache and self.titleCacheAt == objCacheStamp then return self.titleCache end
	local t = {}
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
		for i = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(i)
			if info and not info.isHeader and info.questID and info.title then
				local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
				if not done then t[info.title] = "" end
			end
		end
	end
	self.titleCache, self.titleCacheAt = t, objCacheStamp
	return t
end

-- 물체 진단 기록 (/foa obj · 저장 파일 objDiag): 이름 · 툴팁 줄 · 판정 결과
function M:ObjDiag(unit, where, info)
	local okN, name = pcall(UnitName, unit)
	name = okN and plain(name) or "?"
	local okG, g = pcall(UnitGUID, unit)
	g = okG and plain(g) or "?"
	local lines = {}
	if C_TooltipInfo and C_TooltipInfo.GetUnit then
		local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
		for i, l in ipairs(ok and data and data.lines or {}) do
			local t = plain(l.leftText)
			lines[#lines + 1] = tostring(plain(l.type)) .. ":" .. (type(t) == "string" and t or "?")
			if i >= 6 then break end
		end
	end
	local okR, rel = false, nil
	if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then okR, rel = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit) end
	local rec = string.format("%s %s [%s] %s rel=%s 툴팁=%s → %s", date("%H:%M:%S"), where, name, tostring(g):sub(1, 24),
		tostring(okR and plain(rel)), table.concat(lines, " | "), info and ("퀘스트 " .. (info.text or "")) or "아님")
	Ink.db.objDiag = Ink.db.objDiag or {}
	local d = Ink.db.objDiag
	if d[#d] ~= rec then d[#d + 1] = rec end
	while #d > 15 do table.remove(d, 1) end
	return rec
end

-------------------------------------------------------------------------------
-- 퀘스트 물체 반짝임: 몬스터 전리품 반짝임처럼 배지 주위에서 별이 반짝이고
--  배지 뒤로 은은한 빛 + 퍼지는 고리 (멀리서도 눈에 띄게). 설정: 퀘스트 물체 반짝임
-------------------------------------------------------------------------------
local SPARK_TEX = "Interface\\AddOns\\FOA_UI\\Media\\Textures\\Sparkle"
-- { x, y, 크기, 쉬는 시간 } — 쉬는 시간이 달라서 별마다 반짝이는 때가 어긋난다
local SPARK_POS = {
	{ -21, 9, 15, 0.1 }, { 19, 15, 12, 0.55 }, { -13, -13, 11, 0.95 },
	{ 23, -7, 14, 0.3 }, { 3, 25, 10, 0.75 }, { -28, -1, 9, 1.2 },
}

local function SparkAnim(region, loop, kind, dur, order, delay, smooth)
	local ag = region.ag
	if not ag then
		ag = region:CreateAnimationGroup()
		if loop then ag:SetLooping(loop) end
		region.ag = ag
	end
	local a = ag:CreateAnimation(kind)
	a:SetDuration(dur)
	if order then a:SetOrder(order) end
	if delay then a:SetStartDelay(delay) end
	if smooth then a:SetSmoothing(smooth) end
	return a
end

local function SparkFrames(f)
	if f.spark then return f.spark end
	local col = QUEST_COLOR
	-- 배지 뒤 (빛 · 고리)
	local back = CreateFrame("Frame", nil, f)
	back:SetSize(24, 24)
	back:SetPoint("CENTER", f.role, "CENTER")
	back:SetFrameLevel(f:GetFrameLevel())
	back.glow = back:CreateTexture(nil, "BACKGROUND")
	back.glow:SetTexture(Ink.tex.glow)
	back.glow:SetPoint("CENTER")
	back.glow:SetSize(70, 70)
	back.glow:SetBlendMode("ADD")
	back.glow:SetVertexColor(col[1], col[2], col[3], 1)
	local g = SparkAnim(back.glow, "BOUNCE", "Alpha", 0.9, nil, nil, "IN_OUT")
	g:SetFromAlpha(0.3)
	g:SetToAlpha(0.85)
	back.ring = back:CreateTexture(nil, "ARTWORK")
	back.ring:SetTexture(Ink.tex.ring)
	back.ring:SetAllPoints()
	back.ring:SetBlendMode("ADD")
	back.ring:SetVertexColor(col[1], col[2], col[3], 1)
	back.ring:SetAlpha(0)
	local rs = SparkAnim(back.ring, "REPEAT", "Scale", 1.4, 1, 0.5, "OUT")
	rs:SetScaleFrom(1, 1)
	rs:SetScaleTo(2.8, 2.8)
	local ra = SparkAnim(back.ring, "REPEAT", "Alpha", 1.4, 1, 0.5, "OUT")
	ra:SetFromAlpha(0.85)
	ra:SetToAlpha(0)
	-- 배지 앞 (반짝이는 별)
	local front = CreateFrame("Frame", nil, f)
	front:SetSize(24, 24)
	front:SetPoint("CENTER", f.role, "CENTER")
	front:SetFrameLevel(f.role:GetFrameLevel() + 3)
	front.stars = {}
	for i, p in ipairs(SPARK_POS) do
		local t = front:CreateTexture(nil, "OVERLAY")
		t:SetTexture(SPARK_TEX)
		t:SetSize(p[3], p[3])
		t:SetPoint("CENTER", p[1], p[2])
		t:SetBlendMode("ADD")
		t:SetVertexColor(1, 0.95, 0.72, 1)
		t:SetAlpha(0)
		local a1 = SparkAnim(t, "REPEAT", "Alpha", 0.26, 1, p[4] + 0.25)
		a1:SetFromAlpha(0)
		a1:SetToAlpha(1)
		local s1 = SparkAnim(t, "REPEAT", "Scale", 0.26, 1, p[4] + 0.25, "OUT")
		s1:SetScaleFrom(0.25, 0.25)
		s1:SetScaleTo(1, 1)
		local a2 = SparkAnim(t, "REPEAT", "Alpha", 0.45, 2, nil, "IN")
		a2:SetFromAlpha(1)
		a2:SetToAlpha(0)
		local s2 = SparkAnim(t, "REPEAT", "Scale", 0.45, 2, nil, "IN")
		s2:SetScaleFrom(1, 1)
		s2:SetScaleTo(0.3, 0.3)
		local r2 = SparkAnim(t, "REPEAT", "Rotation", 0.45, 2)
		r2:SetDegrees(-45)
		front.stars[i] = t
	end
	f.spark = { back = back, front = front }
	return f.spark
end

function M.Sparkle(f, on)
	if on and Ink.db.questSparkle ~= false then
		local s = SparkFrames(f)
		if not s.on then
			s.on = true
			s.back:Show(); s.front:Show()
			s.back.glow.ag:Play(); s.back.ring.ag:Play()
			for _, t in ipairs(s.front.stars) do t.ag:Play() end
		end
	elseif f.spark and f.spark.on then
		local s = f.spark
		s.on = nil
		s.back.glow.ag:Stop(); s.back.ring.ag:Stop()
		for _, t in ipairs(s.front.stars) do t.ag:Stop(); t:SetAlpha(0) end
		s.back:Hide(); s.front:Hide()
	end
end

-- 물체 이름표: 퀘스트 물체만 보인다 (배지 + 이름 + 진행 수치), 나머지 물체는 숨김
function M:DrawObject(f, unit)
	self:SetFriendly(f, true)
	f.object = true
	local okN, name = pcall(UnitName, unit)
	f.name:SetText(okN and plain(name) or "")
	f:SetScale(1)
	f:SetAlpha(1)
	if not f.otext then
		f.otext = Ink:Text(f, F.latinB, 11, QUEST_COLOR, "CENTER")
		f.otext:SetPoint("TOP", f.name, "BOTTOM", 0, -2)
		f.otext:SetShadowColor(0, 0, 0, 1)
	end
	local info = ObjectQuestInfo(unit)
	f.objInfo = info
	pcall(M.ObjDiag, M, unit, "plate", info)
	if info then
		local q = QUEST_COLOR
		f.role.icon:SetTexture(Ink.icon(info.kind == "kill" and "QuestKill" or "QuestLoot"))
		f.role.icon:SetVertexColor(q[1], q[2], q[3])
		f.role.ring:SetVertexColor(q[1], q[2], q[3], 0.95)
		f.role:Show()
		f.name:SetTextColor(q[1], q[2], q[3])
		f.name:SetAlpha(1)
		f.otext:SetText(info.text)
		f.otext:SetShown(info.text ~= "")
		M.Sparkle(f, true)
	else
		f.role:Hide()
		f.name:SetAlpha(0)
		f.otext:Hide()
		M.Sparkle(f, false)
	end
end

function M:ApplyQuest(f)
	local info = (not f.friendly and f.unit) and QuestInfo(f.unit) or nil
	if ns.FX and f.questUnit == f.unit then ns.FX.PlateQuest(f, f.questInfo, info) end
	f.questUnit = f.unit
	f.questInfo = info
	if info then
		f.qicon:SetTexture(Ink.icon(info.kind == "kill" and "QuestKill" or "QuestLoot"))
		f.qicon:SetVertexColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3])
		f.qicon:Show()
		f.qtext:SetText(info.text)
		f.qtext:Show()
	else
		f.qicon:Hide()
		f.qtext:Hide()
	end
end

-- 레벨 차이 색 (퀘스트 난이도 색과 같은 기준, FOA 색으로)
local LVL_COL = {
	skull = { 1.00, 0.36, 0.30 }, red = { 1.00, 0.42, 0.37 }, orange = { 1.00, 0.62, 0.30 },
	yellow = { 1.00, 0.86, 0.36 }, green = { 0.44, 0.83, 0.55 }, gray = { 0.56, 0.58, 0.61 },
}
local function LevelLook(u)
	local lv = plain(UnitLevel(u))
	if type(lv) ~= "number" then return end
	if lv <= 0 then return "??", LVL_COL.skull end
	local me = UnitLevel("player") or 1
	local d = lv - me
	local key
	if d >= 5 then key = "red"
	elseif d >= 3 then key = "orange"
	elseif d >= -2 then key = "yellow"
	else
		local green = (GetQuestGreenRange and GetQuestGreenRange()) or ((me <= 5) and 5 or (me <= 39 and (math.floor(me / 10) + 5) or (math.floor(me / 5) + 1)))
		key = (-d <= green) and "green" or "gray"
	end
	local cls = plain(UnitClassification(u))
	local plus = (cls == "elite" or cls == "rareelite" or cls == "worldboss") and "+" or ""
	return lv .. plus, LVL_COL[key]
end

function M:UpdateInfo(f)
	local u = f.unit
	f.name:SetText((UnitName(u)))
	if f.lvl then
		local txt, col
		if not f.friendly then txt, col = LevelLook(u) end
		if txt then
			f.lvl:SetText(txt)
			f.lvl:SetTextColor(col[1], col[2], col[3])
			f.lvl:Show()
			f.name:ClearAllPoints()
			f.name:SetPoint("BOTTOMLEFT", f.lvl, "BOTTOMRIGHT", 4, 0)
			f.name:SetWidth(W - 40 - (f.lvl:GetStringWidth() or 14))
		else
			f.lvl:Hide()
		end
	end
	local r, g, b = ReactionColor(u)
	f.hp:SetStatusBarColor(r, g, b)
	local cls = plain(UnitClassification(u))
	if f.friendly then cls = nil end
	if cls == "elite" or cls == "worldboss" or cls == "rareelite" then
		f.elite:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
		f.elite:Show()
		SetRank(f, GOLD, cls == "rareelite" and SILVER or GOLD)
	elseif cls == "rare" then
		f.elite:SetColorTexture(SILVER[1], SILVER[2], SILVER[3], 1)
		f.elite:Show()
		SetRank(f, SILVER, SILVER)
	else
		f.elite:Hide()
		SetRank(f, nil)
	end
	-- 징표 번호가 비밀 값(파티 · 던전)이어도 그림 칸 지정(SetSpriteSheetCell)에는 그대로 넘길 수 있다
	local okI, idx = pcall(GetRaidTargetIndex, u)
	local shown = false
	if okI and idx ~= nil then
		shown = pcall(SetRaidTargetIconTexture, f.raid, idx)
		if not shown and f.blizzRT and f.blizzRT.SetIgnoreParentAlpha then
			-- 그래도 안 되면 블리자드 징표를 보이게 (자리는 블리자드 기본)
			pcall(f.blizzRT.SetIgnoreParentAlpha, f.blizzRT, true)
		end
	end
	f.raid:SetShown(shown)
	self:ApplyQuest(f)
end

function M:UpdateAuras(f)
	-- 내가 건 디버프 전부 (독처럼 "플레이트 표시" 표시가 없는 것도 포함)
	f.auras:SetUnit((f.unit and not f.friendly) and f.unit or "none")
end

function M:UpdateCast(f, event)
	local cb, u = f.cast, f.unit
	if event == "UNIT_SPELLCAST_INTERRUPTED" then
		cb.dur, cb.endTime = nil, nil
		cb.bar:SetMinMaxValues(0, 1)
		cb.bar:SetValue(1)
		cb.bar:SetStatusBarColor(C.red[1], C.red[2], C.red[3])
		cb.lock:SetAlpha(0)
		cb.name:SetText("차단됨")
		cb.name:SetTextColor(C.red[1], C.red[2], C.red[3])
		cb.lockName:SetAlpha(0)
		cb.time:SetText("")
		cb.flash = GetTime() + 0.6
		cb:Show()
		if cb.fxShakeP and ns.FX.on("castFinish") then cb.fxShakeP() end
		return
	end
	local name, text, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(u)
	local dur, dir
	local E = Enum.StatusBarTimerDirection
	if name then
		dur = UnitCastingDuration and UnitCastingDuration(u)
		dir = E and E.ElapsedTime
	else
		name, text, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(u)
		if name then
			dur = UnitChannelDuration and UnitChannelDuration(u)
			dir = E and E.RemainingTime
		end
	end
	if not name then
		if not cb.flash then cb:Hide() end
		return
	end
	cb.flash = nil
	cb.bar:SetStatusBarColor(C.orange[1], C.orange[2], C.orange[3])
	cb.name:SetTextColor(C.orange[1], C.orange[2], C.orange[3])
	cb.name:SetText(text or name)
	cb.lockName:SetText(text or name)
	cb.icon:SetTexture(texture)
	cb.dur, cb.endTime = nil, nil
	if dur and cb.bar.SetTimerDuration then
		local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
		if not pcall(cb.bar.SetTimerDuration, cb.bar, dur, interp, dir) then pcall(cb.bar.SetTimerDuration, cb.bar, dur) end
		cb.dur = dur
	else
		local s, e = plain(startTime), plain(endTime)
		if s and e then
			cb.bar:SetMinMaxValues(s, e)
			cb.endTime = e
		end
	end
	if ns.FX and (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") then
		ns.FX.PlatePing(f, notInterruptible)
	end
	-- 차단 불가: 회색 바 + 회색 이름 (값이 비공개여도 SetAlphaFromBoolean 으로 처리)
	if cb.lock.SetAlphaFromBoolean then
		safe(cb.lock.SetAlphaFromBoolean, cb.lock, notInterruptible, 1, 0)
		safe(cb.lockName.SetAlphaFromBoolean, cb.lockName, notInterruptible, 1, 0)
		safe(cb.name.SetAlphaFromBoolean, cb.name, notInterruptible, 0, 1)
	else
		local ni = plain(notInterruptible)
		cb.lock:SetAlpha(ni and 1 or 0)
		cb.lockName:SetAlpha(ni and 1 or 0)
		cb.name:SetAlpha(ni and 0 or 1)
	end
	cb:Show()
end

function M:UpdateAll(f)
	self:UpdateInfo(f)
	self:UpdateHealth(f)
	self:UpdateLook(f)
	self:UpdateAuras(f)
	self:UpdateCast(f)
end

local function Plain(fn, ...)
	local ok, v = pcall(fn, ...)
	if ok then return plain(v) end
end

-- 거리 확인은 전투 중이나 인스턴스 안에서 "공격할 수 없는 대상"에게 쓰면
-- 보호된 동작으로 막힌다(ADDON_ACTION_BLOCKED). 그때는 부르지 않고 마지막으로 잰 값을 쓴다.
local function RangeAllowed()
	if InCombatLockdown() then return false end
	local inInstance, kind = IsInInstance()
	return not (inInstance and kind ~= "none")
end

function M:NearFriendly(u, f)
	if Plain(UnitIsUnit, u, "target") or Plain(UnitIsUnit, u, "mouseover") then return true end
	-- 플레이어 이름은 항상 보인다 (거리 숨김은 멀리 있는 NPC 이름용)
	if Plain(UnitIsPlayer, u) then return true end
	if not RangeAllowed() then return f and f.near or false end
	-- 4 = 따라가기 거리(약 28미터)
	local near = Plain(CheckInteractDistance, u, 4) and true or false
	if f then f.near = near end
	return near
end

-- 아군 이름 색: 플레이어 = 직업색, NPC = 초록. 던전 안처럼 값이 비공개면 직업 → 흰색 순으로
local function FriendlyColor(u)
	local isP = plain(UnitIsPlayer(u))
	if isP == false then
		local r = plain(UnitReaction(u, "player"))
		if r and r <= 4 then return ReactionColor(u) end
		return C.green[1], C.green[2], C.green[3]
	end
	local ok, _, cls = pcall(UnitClass, u)
	cls = ok and plain(cls)
	if cls and ns.ClassColorOf then return ns.ClassColorOf(cls) end
	if isP then return ns.ClassColor(u) end
	return C.text[1], C.text[2], C.text[3]
end

local function InInstance()
	local inInst, kind = IsInInstance()
	return inInst and kind ~= "none"
end

-- 아군: 이름만
function M:SetFriendly(f, friendly)
	f.friendly = friendly
	f.back:SetShown(not friendly)
	f.pct:SetShown(not friendly)
	f.auras:SetShown(not friendly)
	if friendly then f.auras:SetUnit("none") end
	if friendly then
		f.cast:Hide()
		if f.lvl then f.lvl:Hide() end
		f.name:ClearAllPoints()
		f.name:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.name:SetJustifyH("CENTER")
		f.name:SetWidth(W + 40)
		f.name:SetTextColor(FriendlyColor(f.unit))
		f.near = nil
		-- 역할 NPC는 멀리서도 아이콘과 이름이 보이게
		local role = f.unit and NpcRole(f.unit)
		f.roleInfo = role
		if role then
			f.role.icon:SetTexture(role.tex)
			f.role.icon:SetVertexColor(role.rgb[1], role.rgb[2], role.rgb[3])
			f.role.ring:SetVertexColor(role.rgb[1], role.rgb[2], role.rgb[3], 0.7)
			f.role:Show()
		else
			f.role:Hide()
		end
		-- 던전 · 레이드 안에선 거리를 잴 수 없어서(보호된 동작) 파티원 이름은 항상 보이게
		f.nameAlpha = (role or InInstance() or self:NearFriendly(f.unit, f)) and 0.9 or 0
		f.name:SetAlpha(f.nameAlpha)
		local sub = f.unit and not plain(UnitIsPlayer(f.unit)) and not IsObject(f.unit) and Subtitle(f.unit)
		if sub then
			f.sub:SetText("<" .. sub .. ">")
			if role then f.sub:SetTextColor(role.rgb[1], role.rgb[2], role.rgb[3]) else f.sub:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end
			f.sub:SetAlpha(f.nameAlpha)
			f.sub:Show()
		else
			f.sub:Hide()
		end
		f.markL:Hide(); f.markR:Hide(); f.elite:Hide()
		-- 아군(파티원 등) 징표는 이름 바로 위에 크게
		f.raid:ClearAllPoints()
		f.raid:SetPoint("BOTTOM", f.name, "TOP", 0, 3)
		f.raid:SetSize(22, 22)
		SetRank(f, nil)
		f.questInfo = nil
		f.qicon:Hide(); f.qtext:Hide()
	else
		f.roleInfo = nil
		f.role:Hide()
		f.name:ClearAllPoints()
		f.name:SetJustifyH("LEFT")
		local ltxt, lcol
		if f.lvl and f.unit and not f.isPreview then ltxt, lcol = LevelLook(f.unit) end
		if ltxt then
			f.lvl:SetText(ltxt)
			f.lvl:SetTextColor(lcol[1], lcol[2], lcol[3])
			f.lvl:Show()
			f.name:SetPoint("BOTTOMLEFT", f.lvl, "BOTTOMRIGHT", 4, 0)
			f.name:SetWidth(W - 40 - (f.lvl:GetStringWidth() or 14))
		else
			if f.lvl then f.lvl:Hide() end
			f.name:SetPoint("BOTTOMLEFT", f.back, "TOPLEFT", 2, 3)
			f.name:SetWidth(W - 34)
		end
		f.name:SetAlpha(1)
		f.nameAlpha = nil
		f.sub:Hide()
		f.raid:ClearAllPoints()
		f.raid:SetPoint("RIGHT", f.back, "TOPLEFT", -12, 9)   -- 레벨 · 이름 줄 왼쪽 바깥
		f.raid:SetSize(15, 15)
	end
end

-------------------------------------------------------------------------------
-- 이벤트
-------------------------------------------------------------------------------
-- 진단용: 플레이어 이름표가 어떻게 들어오는지 마지막 30개를 저장 (/reload 후 SavedVariables 에서 확인)
local function Diag(unit, plate)
	if not plain(UnitIsPlayer(unit)) then return end
	Ink.db.plateDiag = Ink.db.plateDiag or {}
	local d = Ink.db.plateDiag
	local ok, nm = pcall(UnitName, unit)
	table.insert(d, string.format("%s %s plate=%s forbidden=%s attack=%s reaction=%s",
		date("%H:%M:%S"), tostring(ok and plain(nm) or "?"), tostring(plate ~= nil),
		tostring(plate and plate:IsForbidden()), tostring(plain(UnitCanAttack("player", unit))),
		tostring(plain(UnitReaction(unit, "player")))))
	while #d > 30 do table.remove(d, 1) end
end

-- 아군인가? (공격 불가 = 아군)
--  멀리서 막 나타난 대상은 정보가 덜 와서 "공격 가능"이 빈 값일 때가 있다.
--  그때는 반응(적대/중립/우호)으로 보고, 그것도 없으면 적으로 본다 → 체력바가 항상 보이게.
local function IsFriendly(unit)
	local ok, can = pcall(UnitCanAttack, "player", unit)
	if ok then can = plain(can) else can = nil end
	if can == true then return false end
	if can == false then
		-- 공격 불가인데 적대 반응이면(일시적 정보 부족) 적으로
		local okR, r = pcall(UnitReaction, unit, "player")
		r = okR and plain(r)
		if r and r <= 3 then return false end
		return true
	end
	local okR, r = pcall(UnitReaction, unit, "player")
	r = okR and plain(r)
	if r then return r >= 5 end
	return false
end
M.IsFriendly = IsFriendly

-- 오류 기록 (같은 내용은 30초에 한 번만)
local lastErr = {}
local function PlateError(where, err)
	local key = where .. tostring(err)
	local now = GetTime()
	if lastErr[key] and now - lastErr[key] < 30 then return end
	lastErr[key] = now
	Ink:LogError("Plates." .. where .. ": " .. tostring(err))
end

function M:Draw(f, unit)
	if IsObject(unit) then return self:DrawObject(f, unit) end
	if f.object then
		f.object, f.objInfo = nil, nil
		if f.otext then f.otext:Hide() end
		M.Sparkle(f, false)
	end
	local friendly = IsFriendly(unit)
	self:SetFriendly(f, friendly)
	self:UpdateInfo(f)
	if friendly then
		f:SetScale(1)
		f:SetAlpha(1)
		f.name:SetTextColor(FriendlyColor(unit))
	else
		self:UpdateAll(f)
	end
end

function M:OnAdded(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate or plate:IsForbidden() then return end
	local okB, f = pcall(function() return plate.ink or Build(plate) end)
	if not okB or not f then
		PlateError("Build", f)
		RestoreBlizzard(plate)
		return
	end
	f.unit = unit
	f.failAt = nil
	f.questUnit, f.questInfo, f.fxWasTarget = nil, nil, nil
	plates[unit] = f
	f:Show()
	local ok, err = pcall(self.Draw, self, f, unit)
	if not ok then
		-- FOA 이름표를 못 그리면 블리자드 기본 이름표라도 보이게
		PlateError("Draw", err)
		plates[unit] = nil
		f.unit = nil
		f.failAt = GetTime()
		f:Hide()
		RestoreBlizzard(plate)
		return
	end
	HideBlizzard(plate, unit)
	if ns.FX and not f.friendly then ns.FX.TrailSnap(f.hp, unit) end
	-- 첫 프레임에 공격 가능 여부가 틀리게 나올 수 있어 한 번 더 확인
	C_Timer.After(0.1, function()
		if plates[unit] ~= f or f.object then return end
		local fr = IsFriendly(unit)
		if fr ~= f.friendly then
			local okD, errD = pcall(M.Draw, M, f, unit)
			if not okD then PlateError("Recheck", errD) end
		end
	end)
end

-- 이벤트를 놓쳤거나 그리기에 실패한 이름표를 다시 잡는다 (0.2초마다)
function M:Heal()
	local now = GetTime()
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		if not plate:IsForbidden() then
			local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
			if u then
				local f = plates[u]
				local broken = not f or f ~= plate.ink or not f:IsShown() or f.unit ~= u
				local cooling = plate.ink and plate.ink.failAt and now - plate.ink.failAt < 3
				if broken and not cooling then self:OnAdded(u) end
			end
		end
	end
end

function M:OnRemoved(unit)
	local f = plates[unit]
	plates[unit] = nil
	-- 같은 플레이트가 이미 다른 대상에게 넘어갔으면 건드리지 않는다
	if f and f.unit ~= unit then f = nil end
	if f then
		f:Hide()
		f.cast:Hide()
		f.cast.flash = nil
		f.unit = nil
		SetRank(f, nil)
		f.roleInfo = nil
		f.role:Hide()
		f.auras:SetUnit("none")
		f.object, f.objInfo = nil, nil
		if f.otext then f.otext:Hide() end
		M.Sparkle(f, false)
	end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if plate then RestoreBlizzard(plate) end
end

-------------------------------------------------------------------------------
-- 기본 이름표(머리 위 3D 이름) 끄기
--  블리자드 이름표는 화면 해상도와 상관없이 크게 그려져서(특히 맥) 거슬린다.
--  이름은 Ink 아군 네임플레이트가 대신 보여주도록 아군 플레이트를 켜고, 기본 이름표만 끈다.
--  원래 값은 저장해 두었다가 Ink 네임플레이트를 끄면 되돌린다.
-------------------------------------------------------------------------------
local NAME_CVARS = {
	UnitNameNPC = "0",
	UnitNameFriendlySpecialNPCName = "0",
	UnitNameHostleNPC = "0",
	UnitNameInteractiveNPC = "0",
	UnitNameNonCombatCreatureName = "0",
	UnitNameFriendlyPlayerName = "0",
	-- 적 진영 플레이어(성역 도시의 호드/얼라 등) 머리 위 3D 이름도 끈다
	UnitNameEnemyPlayerName = "0",
	UnitNameEnemyPetName = "0",
	UnitNameEnemyGuardianName = "0",
	UnitNameEnemyTotemName = "0",
	UnitNameEnemyMinionName = "0",
	UnitNameFriendlyPetName = "0",
	UnitNameFriendlyGuardianName = "0",
	UnitNameFriendlyTotemName = "0",
	UnitNameFriendlyMinionName = "0",
	nameplateShowFriends = "1",
	nameplateShowFriendlyPlayers = "1", -- 성역의 적 진영 플레이어도 여기에 들어간다
	nameplateShowFriendlyNPCs = "1",
	-- 던전 안처럼 FOA가 못 꾸미는 아군 플레이어 이름표는 체력바 없이 이름만 (12.x 새 설정)
	nameplateShowOnlyNameForFriendlyPlayerUnits = "1",
	nameplateUseClassColorForFriendlyPlayerUnitNames = "1",
}

local function GetCV(k)
	return (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(k)) or (GetCVar and GetCVar(k))
end
local function SetCV(k, v)
	if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, k, v) end
	return pcall(SetCVar, k, v)
end

function M:ApplyNameCVars()
	if InCombatLockdown() then
		self.cvarPending = true
		return
	end
	self.cvarPending = nil
	Ink.db.cvarBackup = Ink.db.cvarBackup or {}
	for k, v in pairs(NAME_CVARS) do
		local cur = GetCV(k)
		if cur ~= nil then
			if Ink.db.cvarBackup[k] == nil then Ink.db.cvarBackup[k] = cur end
			if cur ~= v then SetCV(k, v) end
		end
	end
end

function M:RestoreNameCVars()
	local b = Ink.db.cvarBackup
	if not b or InCombatLockdown() then return end
	for k, v in pairs(b) do SetCV(k, v) end
	Ink.db.cvarBackup = nil
end

-- 아군 NPC 이름표: 바깥에선 켜고(역할 아이콘 · 이름), 던전 / 레이드 안에선 끈다
--  (인스턴스 안 아군 이름표는 블리자드가 애드온 손을 막아 둬서 체력바째로 크게 나온다)
local INSTANCE_NAMES = { "UnitNameNPC", "UnitNameFriendlySpecialNPCName", "UnitNameInteractiveNPC" }
function M:UpdateFriendlyNPCs()
	if InCombatLockdown() then
		self.npcPending = true
		return
	end
	self.npcPending = nil
	local inst = InInstance()
	local function want(k, v) if GetCV(k) ~= nil and GetCV(k) ~= v then SetCV(k, v) end end
	want("nameplateShowFriendlyNPCs", inst and "0" or "1")
	for _, k in ipairs(INSTANCE_NAMES) do want(k, inst and "1" or "0") end
	-- 아군 플레이어 이름표는 어디서든 켜고, 이름만 · 직업색
	want("nameplateShowFriends", "1")
	want("nameplateShowFriendlyPlayers", "1")
	want("nameplateShowOnlyNameForFriendlyPlayerUnits", "1")
	want("nameplateUseClassColorForFriendlyPlayerUnitNames", "1")
end

-- 퀘스트 오브젝트 표시용: 내 앞의 상호작용 물체에 이름표가 생기게 한다 (끄면 원래 값으로)
local SOFT_CVARS = {
	SoftTargetInteract = "3",          -- 상호작용 대상 잡기: 항상
	SoftTargetNameplateInteract = "1", -- 그 대상에 이름표
	SoftTargetIconInteract = "1",      -- 줍기 · 상호작용 물체 위에 게임 아이콘
	SoftTargetIconGameObject = "1",    -- 바닥 물체(퀘스트 물건 등)에도
	SoftTargetInteractRange = "45",    -- 잡는 거리 (기본 10미터라 바로 앞까지 가야 떴다 · 30도 가까워서 45)
	SoftTargetInteractArc = "2",       -- 앞쪽만이 아니라 옆에 있는 물체도
}

function M:ApplyObjectCVars()
	if InCombatLockdown() then
		self.softPending = true
		return
	end
	self.softPending = nil
	if Ink.db.questObjects == false or Ink.db.plates == false then
		local b = Ink.db.softBackup
		if b then
			for k, v in pairs(b) do SetCV(k, v) end
			Ink.db.softBackup = nil
		end
		return
	end
	Ink.db.softBackup = Ink.db.softBackup or {}
	for k, v in pairs(SOFT_CVARS) do
		local cur = GetCV(k)
		if cur ~= nil then
			if Ink.db.softBackup[k] == nil then Ink.db.softBackup[k] = cur end
			if cur ~= v then SetCV(k, v) end
		end
	end
end

function M:CombatEnd()
	if self.softPending then self:ApplyObjectCVars() end
	if self.cvarPending then self:ApplyNameCVars() end
	if self.npcPending then self:UpdateFriendlyNPCs() end
end

function M:Init()
	Ink.db.plateCVars, Ink.db.plateDiag = nil, nil
	if Ink.db.plates == false then
		self:RestoreNameCVars()
		pcall(self.ApplyObjectCVars, self)
		return
	end
	self:ApplyNameCVars()
	self:UpdateFriendlyNPCs()
	pcall(self.ApplyObjectCVars, self)
	local e = CreateFrame("Frame")
	for _, ev in ipairs({
		"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE",
		"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
		"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_AURA",
		"UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_CLASSIFICATION_CHANGED",
		"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
		"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
		"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
		"UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
	}) do
		e:RegisterEvent(ev)
	end
	pcall(e.RegisterEvent, e, "PLAYER_SOFT_INTERACT_CHANGED")
	local function OnEvent(_, event, unit)
		if event == "PLAYER_SOFT_INTERACT_CHANGED" then
			-- 바라보는 물체가 바뀔 때마다 진단 기록 (이름표가 안 생기는 경우도 알 수 있게)
			if UnitExists("softinteract") then pcall(M.ObjDiag, M, "softinteract", "soft", nil) end
			return
		end
		if event == "NAME_PLATE_UNIT_ADDED" then
			M:OnAdded(unit)
			return
		elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
			M:UpdateFriendlyNPCs()
			return
		elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
			-- 퀘스트 진행이 바뀌면 (한 번에 여러 번 와서) 잠깐 모아서 다시 그린다
			if not M.questPending then
				M.questPending = true
				-- 전투 중엔 퀘스트 로그 갱신이 잦아서 1초에 한 번만 (이름표마다 툴팁을 읽는 일이라 무겁다)
				C_Timer.After(InCombatLockdown() and 1 or 0.3, function()
					M.questPending = nil
					objCache = nil
					objCacheStamp = objCacheStamp + 1
					for _, pf in pairs(plates) do
						if pf.object and pf.unit then
							pcall(M.DrawObject, M, pf, pf.unit)
						elseif not pf.friendly and pf.unit then
							pcall(M.UpdateInfo, M, pf)
							pcall(M.UpdateLook, M, pf)
						end
					end
				end)
			end
			return
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			M:OnRemoved(unit)
			return
		elseif event == "PLAYER_TARGET_CHANGED" then
			for _, f in pairs(plates) do if not f.friendly then M:UpdateLook(f) end end
			return
		elseif event == "RAID_TARGET_UPDATE" then
			for _, f in pairs(plates) do if not f.object then M:UpdateInfo(f) end end
			return
		end
		local f = unit and plates[unit]
		if not f or f.object then return end
		if f.friendly then
			if event == "UNIT_NAME_UPDATE" or event == "UNIT_FACTION" then
				local fr = IsFriendly(unit)
				M:SetFriendly(f, fr)
				M:UpdateInfo(f)
				if not fr then M:UpdateAll(f) end
			end
			return
		end
		if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
			M:UpdateHealth(f)
		elseif event == "UNIT_AURA" then
			if not f.auras:IsLive() then M:UpdateAuras(f) end
		elseif event:find("^UNIT_THREAT") then
			M:UpdateLook(f)
		elseif event:find("^UNIT_SPELLCAST") then
			M:UpdateCast(f, event)
		else
			M:UpdateInfo(f)
			if event == "UNIT_FACTION" then
				local fr = IsFriendly(unit)
				if fr ~= f.friendly then M:SetFriendly(f, fr) end
			end
		end
	end
	e:SetScript("OnEvent", function(self, event, unit)
		local ok, err = pcall(OnEvent, self, event, unit)
		if not ok then PlateError(event, err) end
	end)
	-- 아군 이름은 가까울 때(약 28미터)나 대상/마우스오버일 때만 보인다.
	-- 네임플레이트는 거리와 상관없이 같은 크기로 그려져서, 멀리 있는 NPC 이름이 크게 겹쳐 보이기 때문.
	local t = 0
	e:SetScript("OnUpdate", function(_, el)
		t = t + el
		if t < 0.2 then return end
		t = 0
		local okH, errH = pcall(M.Heal, M)
		if not okH then PlateError("Heal", errH) end
		for u, f in pairs(plates) do
			-- 적/아군이 바뀌었으면(정보가 늦게 왔거나 반응이 바뀜) 바로 모양을 바꾼다
			local fr = IsFriendly(u)
			if fr ~= f.friendly then
				local ok, err = pcall(M.Draw, M, f, u)
				if not ok then PlateError("Redraw", err) end
				f:Show()
			end
			if f.friendly then
				local a = (f.roleInfo or M:NearFriendly(u, f)) and 0.9 or 0
				if f.nameAlpha ~= a then
					f.nameAlpha = a
					f.name:SetAlpha(a)
					f.sub:SetAlpha(a)
				end
			end
		end
	end)
	Ink.ProfFrame(e, "이름표")

	-- 이미 떠 있는 플레이트 처리 (/reload 직후)
	C_Timer.After(0.5, function()
		for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
			local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
			if u and not plates[u] then M:OnAdded(u) end
		end
	end)
end

-------------------------------------------------------------------------------
-- 테스트 모드: 앞에 몹이 없어도 이름표를 볼 수 있게 화면 가운데에 가짜 이름표를 띄운다
--  대상(정예 · 시전) / 퀘스트 몹 / 희귀 / 어그로 / 상인(역할 아이콘) / 퀘스트 물체
-------------------------------------------------------------------------------
local FAKE = {
	{ key = "target", name = "수정 골렘 파수꾼", hp = 72, rank = "elite", x = 960, y = 430, cast = "대지 분쇄" },
	{ key = "quest", name = "굶주린 오우거", hp = 100, neutral = true, x = 690, y = 430, quest = { "kill", 3, 8 } },
	{ key = "rare", name = "은빛 날개 와이번", hp = 45, rank = "rare", x = 1230, y = 430 },
	{ key = "aggro", name = "분노한 흙덩이", hp = 58, x = 820, y = 540, aggro = true },
	{ key = "vendor", name = "상인 토르발", friendly = true, role = "vendor", x = 1100, y = 540 },
	{ key = "object", name = "보급품 상자", object = true, x = 1360, y = 540, quest = { "loot", 2, 6 } },
}

function M:BuildPreview()
	if self.pv then return end
	local pv = CreateFrame("Frame", nil, Ink.root)
	pv:SetAllPoints()
	pv:SetFrameStrata("LOW")
	pv:Hide()
	pv.list = {}
	for _, d in ipairs(FAKE) do
		local holder = CreateFrame("Frame", nil, pv)
		holder:SetSize(W, 40)
		holder:SetPoint("CENTER", Ink.root, "TOPLEFT", 0, 0)
		local f = Build(holder)
		f:SetParent(holder)
		f.fake = d
		holder.f = f
		holder.d = d
		pv.list[#pv.list + 1] = holder
	end
	self.pv = pv
end

-- 가짜 이름표 하나 그리기 (유닛 없이 값만)
function M:PaintFake(holder, isTarget)
	local f, d = holder.f, holder.d
	holder:ClearAllPoints()
	holder:SetPoint("CENTER", Ink.root, "TOP", d.x - 960, -d.y)
	f:Show()
	if d.friendly or d.object then
		f.friendly = true
		f.back:Hide(); f.pct:Hide(); f.auras:Hide(); f.cast:Hide()
		f.name:ClearAllPoints()
		f.name:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.name:SetJustifyH("CENTER")
		f.name:SetWidth(W + 40)
		f.name:SetText(d.name)
		f.name:SetAlpha(1)
		f.markL:Hide(); f.markR:Hide(); f.elite:Hide(); f.qicon:Hide(); f.qtext:Hide()
		SetRank(f, nil)
		local col, icon
		if d.role then
			for _, r in ipairs(ROLES) do if r.key == d.role then col, icon = r.rgb, r.tex end end
			col = col or C.green
			icon = icon or Ink.icon("NpcVendor")
			f.name:SetTextColor(C.green[1], C.green[2], C.green[3])
		else
			col = QUEST_COLOR
			icon = Ink.icon(d.quest and d.quest[1] == "kill" and "QuestKill" or "QuestLoot")
			f.name:SetTextColor(col[1], col[2], col[3])
			if not f.otext then
				f.otext = Ink:Text(f, F.latinB, 11, QUEST_COLOR, "CENTER")
				f.otext:SetPoint("TOP", f.name, "BOTTOM", 0, -2)
				f.otext:SetShadowColor(0, 0, 0, 1)
			end
			f.otext:SetText(d.quest[2] .. "/" .. d.quest[3])
			f.otext:Show()
		end
		f.role.icon:SetTexture(icon)
		f.role.icon:SetVertexColor(col[1], col[2], col[3])
		f.role.ring:SetVertexColor(col[1], col[2], col[3], d.object and 0.95 or 0.7)
		f.role:Show()
		f:SetScale(1)
		return
	end
	self:SetFriendly(f, false)
	f.name:SetText(d.name)
	-- 예시 레벨: 몹마다 다른 난이도 색으로
	if f.lvl then
		local my = UnitLevel("player") or 15
		local off = ({ 0, 3, -4, 5, -12, 1, 2 })[(#(d.name or "") % 7) + 1]
		local key = off >= 5 and "red" or (off >= 3 and "orange" or (off >= -2 and "yellow" or (off >= -8 and "green" or "gray")))
		local c = LVL_COL[key]
		f.lvl:SetText(tostring(math.max(1, my + off)))
		f.lvl:SetTextColor(c[1], c[2], c[3])
		f.lvl:Show()
		f.name:ClearAllPoints()
		f.name:SetPoint("BOTTOMLEFT", f.lvl, "BOTTOMRIGHT", 4, 0)
	end
	local col = d.neutral and C.orange or C.red
	f.hp:SetStatusBarColor(col[1], col[2], col[3])
	if not holder.hpSet then
		holder.hpSet = true
		f.hp:SetMinMaxValues(0, 100)
		f.hp:SetValue(d.hp)
		if f.hp.inkTrail then f.hp.inkTrail:SetMinMaxValues(0, 100); f.hp.inkTrail:SetValue(d.hp) end
	end
	f.pct:SetText((holder.curHP or d.hp) .. "%")
	if d.rank == "elite" then
		f.elite:SetColorTexture(1, 0.8, 0.3, 1); f.elite:Show()
		SetRank(f, { 1, 0.80, 0.30 }, { 1, 0.80, 0.30 })
	elseif d.rank == "rare" then
		f.elite:SetColorTexture(0.84, 0.88, 0.95, 1); f.elite:Show()
		SetRank(f, { 0.84, 0.88, 0.95 }, { 0.84, 0.88, 0.95 })
	else
		f.elite:Hide(); SetRank(f, nil)
	end
	if d.quest then
		f.questInfo = { kind = d.quest[1], text = (holder.qcur or d.quest[2]) .. "/" .. d.quest[3] }
		f.qicon:SetTexture(Ink.icon(d.quest[1] == "kill" and "QuestKill" or "QuestLoot"))
		f.qicon:SetVertexColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3])
		f.qicon:Show()
		f.qtext:SetText(f.questInfo.text)
		f.qtext:Show()
	else
		f.questInfo = nil
		f.qicon:Hide(); f.qtext:Hide()
	end
	local a = C.accent
	if ns.FX then
		ns.FX.PlateTarget(f, isTarget)
		ns.FX.PlateAggro(f, d.aggro and ns.FX.demoOn("aggroPulse"))
	end
	if isTarget then
		f.back.bd:SetVertexColor(a[1], a[2], a[3], 1)
		f.glow:SetVertexColor(a[1], a[2], a[3]); f.glow:SetAlpha(0.45)
		f.name:SetTextColor(a[1], a[2], a[3])
		f.markL:Show(); f.markR:Show()
		f:SetScale(1.12)
	else
		if d.aggro then
			f.back.bd:SetVertexColor(C.red[1], C.red[2], C.red[3], 0.9)
		elseif d.quest then
			f.back.bd:SetVertexColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3], 1)
		else
			f.back.bd:SetVertexColor(1, 1, 1, 0.08)
		end
		if d.quest then f.glow:SetVertexColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3]); f.glow:SetAlpha(0.3) else f.glow:SetAlpha(0) end
		f.name:SetTextColor(C.text[1], C.text[2], C.text[3])
		f.markL:Hide(); f.markR:Hide()
		f:SetScale(1)
	end
end

function M:SetTest(on)
	self.testing = on
	if not on then
		Ink:Loop("platesTest", nil)
		if self.pv then self.pv:Hide() end
		return
	end
	self:BuildPreview()
	local pv = self.pv
	pv:Show()
	local list = pv.list
	local byKey = {}
	for _, h in ipairs(list) do byKey[h.d.key] = h end
	local target = "target"
	for _, h in ipairs(list) do self:PaintFake(h, h.d.key == target) end
	local t0 = GetTime()
	local lastSwap, lastHit, lastQuest, lastCast = 0, 0, 0, -99
	local castN = 0
	Ink:Loop("platesTest", function()
		local now = GetTime()
		local fx = ns.FX
		-- 대상 바꾸기 (괄호 조임)
		if fx and fx.demoOn("targetBracket") and now - lastSwap > 3 then
			lastSwap = now
			target = (target == "target") and "rare" or "target"
			for _, h in ipairs(list) do self:PaintFake(h, h.d.key == target) end
		end
		-- 어그로
		local ag = byKey.aggro
		if ag and fx then fx.PlateAggro(ag.f, fx.demoOn("aggroPulse")) end
		-- 잔상
		if fx and fx.demoOn("trail") and now - lastHit > 2.2 then
			lastHit = now
			for _, k in ipairs({ "target", "rare", "aggro" }) do
				local h = byKey[k]
				local v = math.random(15, 90)
				h.curHP = v
				fx.TrailFake(h.f.hp, v)
				h.f.pct:SetText(v .. "%")
			end
		end
		-- 퀘스트 수치 톡
		if fx and fx.demoOn("questPop") and now - lastQuest > 2.6 then
			lastQuest = now
			local h = byKey.quest
			h.qcur = ((h.qcur or h.d.quest[2]) % (h.d.quest[3] - 1)) + 1
			local prev = h.f.questInfo
			self:PaintFake(h, target == "quest")
			fx.PlateQuest(h.f, prev, h.f.questInfo)
		end
		-- 시전 (대상 몹): 2.4초 시전, 홀수 번째는 차단 불가(회색) / 끝나면 결과
		local tg = byKey.target
		local cb = tg.f.cast
		local e = now - lastCast
		if e > 3.4 then
			lastCast = now
			castN = castN + 1
			e = 0
			cb.flash = nil
			local locked = castN % 3 == 0
			cb.bar:SetStatusBarColor(C.orange[1], C.orange[2], C.orange[3])
			cb.name:SetTextColor(C.orange[1], C.orange[2], C.orange[3])
			cb.name:SetText(tg.d.cast)
			cb.lockName:SetText(tg.d.cast)
			cb.lock:SetAlpha(locked and 1 or 0)
			cb.lockName:SetAlpha(locked and 1 or 0)
			cb.name:SetAlpha(locked and 0 or 1)
			cb.icon:SetTexture(136025)
			cb.bar:SetMinMaxValues(0, 2.4)
			cb.dur, cb.endTime = nil, nil
			cb:Show()
			if fx and fx.demoOn("interruptPing") then fx.PlatePing(tg.f, locked) end
		end
		if e <= 2.4 then
			cb.bar:SetValue(e)
			cb.time:SetFormattedText("%.1f", 2.4 - e)
		elseif not cb.flash and cb:IsShown() then
			if fx and fx.demoOn("castFinish") and castN % 2 == 0 then
				cb.bar:SetStatusBarColor(C.red[1], C.red[2], C.red[3])
				cb.lock:SetAlpha(0); cb.lockName:SetAlpha(0); cb.name:SetAlpha(1)
				cb.name:SetText("차단됨")
				cb.name:SetTextColor(C.red[1], C.red[2], C.red[3])
				cb.time:SetText("")
				cb.flash = GetTime() + 0.6
				if cb.fxShakeP then cb.fxShakeP() end
			else
				cb:Hide()
			end
		end
	end)
end
