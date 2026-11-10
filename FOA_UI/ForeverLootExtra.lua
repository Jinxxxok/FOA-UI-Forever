-- FOA UI · 던전 희귀몹 · 특수 몹 · 상자 전리품 (자동 생성 · tools/dungeons/gen_rares.py)
-- 자료: wowf.io 던전 안내 전리품 표 (보스 외 출처 · 장비만) · ForeverLoot 에 합친다 (같은 이름 보스면 아이템만 더함)
-- [던전] = { { 한글 이름, { 아이템 }, NPC 번호(0 = 모름), 1 희귀 / 2 특수 몹 · 상자, 영문 이름 }, ... }
local _, ns = ...
ns.FOREVER_LOOT_EXTRA = {
	brd = {
		{ "광신자 고로쉬", { 11726, 22257, 22266, 22271 }, 0, 2, "Gorosh the Dervish" },
		{ "그리즐", { 11702, 11703, 11722, 22270 }, 0, 2, "Grizzle" },
		{ "적출자", { 11679, 11685, 11686, 11730 }, 0, 2, "Eviscerator" },
		{ "파괴자 오크토르", { 11662, 11665, 11824, 11728 }, 0, 2, "Ok'thor the Breaker" },
		{ "아눕쉬아", { 11675, 11677, 11678, 11731 }, 0, 2, "Anub'shiah" },
		{ "왕거미 헤드룸", { 11633, 11634, 11635, 11729 }, 0, 2, "Hedrum the Creeper" },
		{ "베레크", { 11755, 22242 }, 0, 1, "Verek" },
		{ "무적의 판저", { 11787, 11786, 11785, 22245 }, 0, 1, "Panzor the Invincible" },
		{ "재앙의 피조물", { 22256, 22205, 22255, 22254 }, 0, 2, "Warbringer Construct" },
		{ "보초 둠그립", { 22256, 22205, 22255, 22254 }, 0, 2, "Watchman Doomgrip" },
		{ "파멸괴철로단 땜장이", { 22205 }, 0, 2, "Doomforge Craftsman" },
		{ "유물 금고", { 11945, 11946 }, 0, 2, "Relic Coffer" },
		{ "텔드렌", { 22305, 22330, 22318, 22317 }, 0, 2, "Theldren" },
		{ "비밀 금고", { 22205, 22254, 22255, 22256 }, 0, 2, "Secret Safe" },
	},
	deadmines = {
		{ "광부 존슨", { 5443, 5444 }, 0, 1, "Miner Johnson" },
		{ "스니드의 벌목기", { 1937, 2169, 285292 }, 0, 2, "Sneed's Shredder" },
	},
	dm_east = {
		{ "이살리엔", { 22304, 22472, 22401, 22345, 22315, 22314 }, 0, 2, "Isalien" },
	},
	dm_north = {
		{ "고르독 공물", { 18538, 18528, 18495, 18532, 18530, 18533, 18529, 18500, 18537, 18499, 18531, 18534, 18479, 18480, 18478, 18475, 18477, 18476, 18482, 18481 }, 0, 2, "Gordok Tribute" },
	},
	gnomeregan = {
		{ "첨단로봇", { 9444 }, 0, 1, "Techbot" },
		{ "검은무쇠단 사절", { 9455, 9456, 9457 }, 0, 1, "Dark Iron Ambassador" },
	},
	kraul = {
		{ "가시덩굴일족 가시근위병", { 6679 }, 0, 1, "Razorfen Spearhide" },
		{ "눈먼사냥꾼", { 6695, 6697, 6696 }, 0, 1, "Blind Hunter" },
		{ "대지의주술사 함가르", { 6688, 6689 }, 0, 1, "Earthcaller Halmgar" },
	},
	lbrs = {
		{ "뾰족바위일족 학살자", { 12608, 13286 }, 0, 1, "Spirestone Butcher" },
		{ "뾰족바위일족 전투대장", { 13284, 13285 }, 0, 1, "Spirestone Battle Lord" },
		{ "뾰족바위일족 마법사장", { 13283, 13282, 13261 }, 0, 1, "Spirestone Lord Magus" },
		{ "수정 맹독거미", { 13185, 13184, 13218 }, 0, 1, "Crystal Fang" },
		{ "반노크 그림액스", { 12634, 12637, 12621 }, 0, 1, "Bannok Grimaxe" },
		{ "고크 배시구드", { 13203, 13204, 13198 }, 0, 1, "Ghok Bashguud" },
		{ "불타는 지옥군단병", { 13181, 13182 }, 0, 2, "Burning Felguard" },
		{ "모르 그레이후프", { 22306, 22325, 22319, 22398, 22322 }, 0, 2, "Mor Grayhoof" },
	},
	lordaeron = {
		{ "Lordaeron Captain", { 6642, 6641 }, 0, 1, "Lordaeron Captain" },
	},
	maraudon = {
		{ "정원사 메슬로크", { 17767, 17741, 17742 }, 0, 1, "Meshlok the Harvester" },
	},
	scholo = {
		{ "죽음의 기사 다크리버", { 18760, 18761, 18758, 18759 }, 0, 2, "Death Knight Darkreaver" },
	},
	shadowfang = {
		{ "지옥마 / 암흑마", { 6341 }, 0, 2, "Fel Steed / Shadow Charger" },
		{ "죽음의 경비대장", { 6642, 6641 }, 0, 1, "Deathsworn Captain" },
		{ "아루갈의 보이드워커", { 5943 }, 0, 2, "Arugal's Voidwalker" },
	},
	sm_gy = {
		{ "잠들지 않는 아즈쉬르", { 7709, 7708, 7731 }, 6490, 1, "Azshir the Sleepless" },
		{ "타락한 용사", { 7691, 7690, 7689 }, 6488, 1, "Fallen Champion" },
		{ "무쇠해골", { 7688, 7687, 7686 }, 6489, 1, "Ironspine" },
	},
	stockade = {
		{ "브루갈 아이언너클", { 3228, 2941, 2942 }, 0, 1, "Bruegal Ironknuckle" },
	},
	strat_live = {
		{ "소도스와 자리엔의 가보", { 22327, 22301, 22328, 22329 }, 0, 2, "Sothos and Jarien's Heirlooms" },
	},
	sunken = {
		{ "비운의 오그옴", { 10804, 10805, 10803 }, 0, 2, "Ogom the Wretched" },
		{ "졸로", { 10783, 10784, 10787, 10788, 10785, 10786 }, 0, 2, "Zolo" },
		{ "게이셔", { 10783, 10784, 10785, 10786, 10787, 10788 }, 0, 2, "Gasher" },
		{ "후쿠", { 10783, 10784, 10785, 10786, 10787, 10788 }, 0, 2, "Hukku" },
		{ "학카르의 피조물", { 10801, 10802 }, 0, 2, "Spawn of Hakkar" },
		{ "로로", { 10783, 10784, 10785, 10786, 10787, 10788 }, 0, 2, "Loro" },
		{ "줄로", { 10783, 10784, 10785, 10786, 10787, 10788 }, 0, 2, "Zul'Lor" },
		{ "마이잔", { 10783, 10784, 10785, 10786, 10787, 10788 }, 0, 2, "Mijan" },
	},
	ubrs = {
		{ "화염고리 솔라카르", { 12589, 12603, 12606, 12609 }, 0, 2, "Solakar Flamewreath" },
		{ "제드 룬와처", { 12604, 12605, 12930 }, 0, 1, "Jed Runewatcher" },
		{ "고랄루크 앤빌크랙", { 18048, 13498, 18047, 13502 }, 0, 2, "Goraluk Anvilcrack" },
		{ "기스", { 12952, 12953, 12960, 22225 }, 0, 2, "Gyth" },
	},
	wailing = {
		{ "돌연변이 요정용", { 5243, 6632 }, 0, 1, "Deviate Faerie Dragon" },
	},
	zulfarrak = {
		{ "제릴리스", { 12470 }, 0, 1, "Zerillis" },
		{ "더스트레이스", { 12471 }, 0, 1, "Dustwraith" },
	},
}

-- 합치기: 같은 영문 이름의 보스가 있으면 빠진 아이템만 더하고, 없으면 희귀 · 선택 칸으로 붙인다
do
	local L = ns.FOREVER_LOOT
	for _, d in ipairs(L and L.list or {}) do
		local extra = ns.FOREVER_LOOT_EXTRA[d.key]
		if extra and d.bosses then
			for _, e in ipairs(extra) do
				local hit
				for _, b in ipairs(d.bosses) do
					if b[5] == e[5] or (e[3] ~= 0 and b[3] == e[3]) then hit = b break end
				end
				if hit then
					local have = {}
					for _, id in ipairs(hit[2]) do have[id] = true end
					for _, id in ipairs(e[2]) do if not have[id] then table.insert(hit[2], id) end end
				else
					table.insert(d.bosses, { e[1], e[2], e[3], e[4], e[5] })
				end
			end
		end
	end
end
