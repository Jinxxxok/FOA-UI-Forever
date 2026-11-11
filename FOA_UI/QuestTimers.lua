-- FOA UI · 시간 제한 퀘스트
--  받으면 시간이 흐르기 시작하는 퀘스트(식은 음식 등)와, 얻은 아이템이 곧 사라지는 퀘스트를 툴팁에 강조해 보여 준다.
--  자료:
--   · 퀘스트 시간 제한: AzerothCore quest_template.TimeAllowed (AGPL · 값만 대조해 옮김 · 오리지널 퀘스트만)
--   · 아이템이 사라지는 퀘스트: QuestieDB 포에버 퀘스트 목표 글("5분 안에" · "식기 전에" 등)에서 찾음
--   · 게임에서 직접 배움: 퀘스트를 받으면 C_QuestLog.GetTimeAllowed 로 실제 제한 시간을 기억 (계정 공유 · 자료보다 먼저)
--  [퀘스트] = { 초, 종류 }  종류 1 = 받는 순간부터 퀘스트 시간 제한 · 2 = 얻은(받은) 아이템이 사라짐 · 초 0 = 길이는 모름

local _, ns = ...
local Ink = ns.Ink

ns.QUEST_TIMERS = {
	-- 퀘스트 시간 제한 (받는 순간부터)
	[28] = { 1800, 1 }, [29] = { 1800, 1 },   -- Trial of the Lake
	[212] = { 1800, 1 },   -- A Meal Served Cold (식은 음식 · 스톰윈드 앵거스 스턴)
	[257] = { 900, 1 }, [258] = { 720, 1 },   -- A Hunter's Boast / Challenge
	[647] = { 900, 1 },   -- MacKreel's Moonshine
	[654] = { 7200, 1 },   -- Tanaris Field Sampling
	[812] = { 2700, 1 },   -- Need for a Cure
	[853] = { 2700, 1 },   -- Apothecary Zamah
	[938] = { 540, 1 },   -- Mist
	[1119] = { 7200, 1 }, [1120] = { 7200, 1 }, [1121] = { 7200, 1 },   -- Zanzil's Mixture · Get the Gnomes / Goblins Drunk
	[1560] = { 1800, 1 },   -- Tooga's Quest (escort)
	[1699] = { 3600, 1 },   -- The Rethban Gauntlet
	[1719] = { 600, 1 },   -- The Affray (warrior)
	[1824] = { 1800, 1 },   -- Trial at the Field of Giants (warrior)
	[1955] = { 180, 1 },   -- The Exorcism (warlock)
	[1957] = { 600, 1 },   -- Mana Surges
	[2845] = { 900, 1 },   -- Wandering Shay (escort)
	[2863] = { 3600, 1 },   -- Alpha Strike
	[2969] = { 360, 1 },   -- Freedom for All Creatures (escort)
	[3522] = { 300, 1 },   -- Iverron's Antidote
	[3843] = { 3600, 1 },   -- The Newest Member of the Family
	[4491] = { 1500, 1 },   -- A Little Help From My Friends (escort)
	[4961] = { 180, 1 },   -- Cleansing of the Orb of Orahil (warlock)
	[5321] = { 1500, 1 },   -- The Sleeper Has Awakened (escort)
	[8193] = { 7200, 1 },   -- Master Angler
	[97257] = { 0, 1 },   -- Call of Fire (Forever · "before the timer runs out")
	[97891] = { 0, 1 },   -- Prompt Potion Runner (Forever · "within the time limit")
	-- 얻은 아이템이 사라짐 (그 전에 전달해야 함)
	[3364] = { 300, 2 },   -- Scalding Mornbrew Delivery ("before it gets cold in five minutes")
	[6022] = { 600, 2 },   -- To Kill With Purpose ("7 Living Rot in under 10 minutes")
	[95805] = { 600, 2 },   -- Forever · incense "burns to ash in ten minutes"
	[924] = { 0, 2 },   -- The Demon Seed ("before the stone expires")
	[1395] = { 0, 2 },   -- Supplies for Nethergarde ("before the powerstones expire")
	[2962] = { 0, 2 },   -- The Only Cure is More Green Glow ("fallout collapses quickly")
}

-- 몇 초 → "30분" · "1시간 30분" · "45초"
function Ink.FormatSecs(s)
	s = math.floor((s or 0) + 0.5)
	if s < 60 then return s .. "초" end
	local m = math.floor(s / 60 + 0.5)
	if m < 60 then return m .. "분" end
	local h, r = math.floor(m / 60), m % 60
	return r > 0 and string.format("%d시간 %d분", h, r) or (h .. "시간")
end

-- 시간 제한 정보: 초, 종류 (없으면 nil) · 게임에서 배운 값이 자료보다 먼저
function Ink.QuestTimer(id)
	if type(id) ~= "number" then return end
	local learned = Ink.db and Ink.db.questTimers and Ink.db.questTimers[id]
	if learned and learned > 0 then return learned, 1 end
	local t = ns.QUEST_TIMERS[id]
	if t then return t[1], t[2] end
end

local ORANGE = { 1.00, 0.72, 0.35 }
local function Clock()
	return string.format("|T%s:12:12:0:-1:64:64:0:64:0:64:255:184:90|t", Ink.icon("Wait"))
end

-- 오른쪽 짧은 표시 ("제한 30분")
function Ink.TimerTag(id)
	local s, kind = Ink.QuestTimer(id)
	if not s then return end
	return "|cffFFB85A" .. (s > 0 and ("제한 " .. Ink.FormatSecs(s)) or "시간 제한") .. "|r"
end

-- 툴팁 한 줄 (강조): 시계 + 무엇이 언제 끝나는지
function Ink.TimerTipLine(tt, id, indent)
	local s, kind = Ink.QuestTimer(id)
	if not s then return end
	local txt
	if kind == 2 then
		txt = s > 0 and ("얻은 아이템이 " .. Ink.FormatSecs(s) .. " 뒤 사라져요 · 서둘러 전달") or "얻은 아이템이 곧 사라져요 · 서둘러 전달"
	else
		txt = s > 0 and ("제한 시간 " .. Ink.FormatSecs(s) .. " · 받는 순간부터 줄어요") or "시간 제한 퀘스트 · 받는 순간부터 줄어요"
	end
	Ink.TipLine(tt, (indent or "") .. Clock() .. " " .. txt, ORANGE[1], ORANGE[2], ORANGE[3])
	return true
end

-- 게임에서 배우기: 퀘스트를 받으면 실제 제한 시간을 기억 (다른 캐릭터 · 지도 툴팁에도)
local function Learn(id)
	if not (Ink.db and C_QuestLog and C_QuestLog.GetTimeAllowed) then return end
	local ok, total = pcall(C_QuestLog.GetTimeAllowed, id)
	total = ok and Ink.plain(total)
	if type(total) == "number" and total > 0 then
		Ink.db.questTimers = Ink.db.questTimers or {}
		Ink.db.questTimers[id] = math.floor(total + 0.5)
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "QUEST_ACCEPTED" then
		local id = Ink.plain(a2 or a1)   -- 클래식식 (번호, 퀘스트) · 최신식 (퀘스트)
		if type(id) == "number" then C_Timer.After(0.5, function() pcall(Learn, id) end) end
	else
		-- 이미 받아 둔 시간 제한 퀘스트
		C_Timer.After(3, function()
			if not (C_QuestLog and C_QuestLog.GetQuestTimers) then return end
			local ok, list = pcall(C_QuestLog.GetQuestTimers)
			for _, t in ipairs(ok and list or {}) do
				local id = type(t) == "table" and Ink.plain(t.questID)
				if type(id) == "number" then pcall(Learn, id) end
			end
		end)
	end
end)
