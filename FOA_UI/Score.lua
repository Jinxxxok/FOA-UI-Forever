-- FOA UI · 아이템 점수 · 착용 비교
--  아이템 점수 = Σ(능력치 × 가중치). 가중치는 직업 · 특성마다 PvE / PvP 따로 (아래 W 표, 모든 직업에 같은 규칙).
--  가방 · 상인 · 퀘스트 보상 · 전리품 툴팁에 "착용 대비 +n%" 를 붙이고, 가방 칸에는 더 좋은 장비에 화살표.
--  포에버(클래식 능력치)는 직업 · 특성 가중치 점수, 본섭은 주 능력치 + 2차 능력치(전문화 BIS 비중) 점수.
--  본섭 장신구는 사용 · 발동 효과가 핵심이라 점수 대신 BIS 여부와 아이템 레벨만 알려 준다.
--  못 쓰는 장비(빨간 줄: 직업 · 방어구 · 무기 숙련)는 비교하지 않고, 레벨만 모자라면 "n레벨부터" 로 알려 준다.

local ADDON, ns = ...
local Ink = ns.Ink
local C, F = Ink.c, Ink.font
local M = Ink:Module("Score")
ns.Score = M

local build = select(4, GetBuildInfo()) or 0
local FOREVER = build >= 16001 and build < 20000
M.forever = FOREVER
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local plain = Ink.plain or function(v) return v end
local RATING_IDX, RatingPct

-------------------------------------------------------------------------------
-- 가중치 (1 = 공격력 1 또는 주문력 1 정도의 값어치)
--  적중 / 치명타는 1% 당. 무기 초당 공격력(dps)은 무기 칸에만.
--  포에버는 클래식 능력치 체계라 클래식 EP(Equivalence Point) 관례를 따르고,
--  공략에 능력치 우선순위가 나오면 여기 숫자만 고치면 된다.
-------------------------------------------------------------------------------
local K = {
	str = "ITEM_MOD_STRENGTH_SHORT", agi = "ITEM_MOD_AGILITY_SHORT", sta = "ITEM_MOD_STAMINA_SHORT",
	int = "ITEM_MOD_INTELLECT_SHORT", spi = "ITEM_MOD_SPIRIT_SHORT",
	ap = "ITEM_MOD_ATTACK_POWER_SHORT", rap = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", fap = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
	sp = "ITEM_MOD_SPELL_POWER_SHORT", heal = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", sdmg = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
	mp5 = "ITEM_MOD_MANA_REGENERATION_SHORT", hp5 = "ITEM_MOD_HEALTH_REGENERATION_SHORT",
	hit = "ITEM_MOD_HIT_RATING_SHORT", crit = "ITEM_MOD_CRIT_RATING_SHORT",
	shit = "ITEM_MOD_HIT_SPELL_RATING_SHORT", scrit = "ITEM_MOD_CRIT_SPELL_RATING_SHORT",
	def = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", dodge = "ITEM_MOD_DODGE_RATING_SHORT", parry = "ITEM_MOD_PARRY_RATING_SHORT",
	block = "ITEM_MOD_BLOCK_RATING_SHORT", bv = "ITEM_MOD_BLOCK_VALUE_SHORT",
	armor = "RESISTANCE0_NAME", dps = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
	-- 포에버에 새로 생긴 능력치 (Method 공략 우선순위에 나옴)
	exp = "ITEM_MOD_EXPERTISE_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT", spen = "ITEM_MOD_SPELL_PENETRATION_SHORT",
}

-- 직업 · 특성별 가중치 (포에버 레벨 60 PvE)
--  출처: Icy Veins 포에버 능력치 우선순위 (2026-11 갱신) · Warcraft Tavern 포에버 직업 공략
--  우선순위(같은 아이템 예산일 때 어느 능력치가 나은가)를 클래식 환산(힘 → 공격력, 민첩 → 치명 등)으로 숫자로 옮겼다.
--  포에버는 적중 · 치명타가 물리 · 주문 공통이라 시전자도 hit / crit 를 shit / scrit 과 같은 값으로 친다.
--  상한: 근접 · 원거리 적중 8% · 주문 적중 17% · 숙련 6.5% → 이미 채웠으면 적중 가치를 낮춘다 (CapAdjust).
local function Caster(t) t.hit = t.hit or t.shit; t.crit = t.crit or t.scrit; return t end
local W = {
	-- 전사: 무기 공격력 > 적중(8%) > 숙련(6.5%) > 치명타 > 힘 · 힘 1 = 공격력 2, 민첩 20 = 치명 1%
	["WARRIOR:arms"] = { dps = 16, hit = 26, exp = 24, crit = 22, str = 2.0, agi = 1.15, ap = 1, haste = 13, sta = 0.2, armor = 0.01 },
	["WARRIOR:fury"] = { dps = 15, hit = 26, exp = 24, crit = 23, str = 2.0, agi = 1.2, ap = 1, haste = 14, sta = 0.2, armor = 0.01 },
	-- 방어 전사: (공격) 숙련 > 적중 > 민첩 > 힘 > 체력 · (방어) 체력 > 방어도 > 민첩 > 회피 · 무기 막기 > 방어 숙련
	["WARRIOR:prot"] = { sta = 1.6, armor = 0.12, agi = 1.5, dodge = 12, parry = 11, def = 1.0, block = 4, bv = 0.3,
		exp = 16, hit = 14, str = 1.0, ap = 0.4, crit = 8, dps = 5, haste = 4 },
	-- 도적(암살 · 전투): 숙련(6.5%) > 적중(8%) > 민첩 > 무기 공격력 > 치명타 · 민첩 1 = 공격력 1 + 치명
	["ROGUE:assassination"] = { exp = 30, hit = 28, agi = 2.2, dps = 13, crit = 22, str = 1.0, ap = 1, haste = 15, sta = 0.2, armor = 0.01 },
	["ROGUE:combat"] = { exp = 30, hit = 28, agi = 2.2, dps = 14, crit = 21, str = 1.0, ap = 1, haste = 15, sta = 0.2, armor = 0.01 },
	-- 잠행: 무기 공격력 > 숙련 > 적중 > 민첩
	["ROGUE:subtlety"] = { dps = 16, exp = 28, hit = 26, agi = 2.2, crit = 22, str = 1.0, ap = 1, haste = 13, sta = 0.2, armor = 0.01 },
	-- 사냥꾼: 무기 공격력 > 적중(8%) > 치명타 > 민첩 > 전투력 · 민첩 1 = 원거리 전투력 2
	["HUNTER:bm"] = { rdps = 15, hit = 26, crit = 24, agi = 2.4, rap = 1, ap = 0.8, int = 0.3, haste = 13, sta = 0.2, armor = 0.01, dps = 1 },
	["HUNTER:mm"] = { rdps = 16, hit = 26, crit = 25, agi = 2.4, rap = 1, ap = 0.8, int = 0.3, haste = 12, sta = 0.2, armor = 0.01, dps = 1 },
	-- 생존: 포에버에서 근접 특성 → 근접 무기가 중심
	["HUNTER:sv"] = { dps = 15, rdps = 5, hit = 26, crit = 24, agi = 2.3, ap = 1, rap = 0.4, int = 0.3, haste = 13, sta = 0.2, armor = 0.01, exp = 18 },
	-- 마법사: 적중(17%) > 주문력 > 치명타 > 지능 > 정신력 · 마나 회복
	["MAGE:arcane"] = Caster({ shit = 14, sp = 1, sdmg = 1, scrit = 11, int = 0.55, spi = 0.25, mp5 = 0.6, haste = 9, sta = 0.1, spen = 0.4 }),
	["MAGE:fire"] = Caster({ shit = 14, sp = 1, sdmg = 1, scrit = 12, int = 0.4, spi = 0.15, mp5 = 0.5, haste = 9, sta = 0.1, spen = 0.4 }),
	["MAGE:frost"] = Caster({ shit = 14, sp = 1, sdmg = 1, scrit = 9, int = 0.4, mp5 = 0.55, spi = 0.15, haste = 9, sta = 0.1, spen = 0.4 }),
	-- 흑마법사: 적중 > 주문력 > 치명타 > 가속 > 지능 (파괴는 가속 > 치명타)
	["WARLOCK:aff"] = Caster({ shit = 14, sp = 1, sdmg = 1, scrit = 8, haste = 7, int = 0.3, spi = 0.15, sta = 0.3, mp5 = 0.4, spen = 0.5 }),
	["WARLOCK:demo"] = Caster({ shit = 14, sp = 1, sdmg = 1, scrit = 8, haste = 7, int = 0.3, spi = 0.15, sta = 0.3, mp5 = 0.4, spen = 0.5 }),
	["WARLOCK:destro"] = Caster({ shit = 14, sp = 1, sdmg = 1, haste = 9, scrit = 8, int = 0.3, spi = 0.1, sta = 0.3, mp5 = 0.4, spen = 0.5 }),
	-- 사제(수양 · 신성): 치유량 > 마나 회복 > 정신력 > 지능 > 치명타
	["PRIEST:disc"] = Caster({ heal = 1, sp = 1, mp5 = 2.0, spi = 0.75, int = 0.6, scrit = 6, haste = 5, sta = 0.1 }),
	["PRIEST:holy"] = Caster({ heal = 1, sp = 1, mp5 = 2.0, spi = 0.8, int = 0.55, scrit = 6, haste = 5, sta = 0.1 }),
	-- 암흑: 적중(17%) > 주문력 > 치명타 > 주문 관통 > 정신력
	["PRIEST:shadow"] = Caster({ shit = 14, sp = 1, sdmg = 1, scrit = 8, spen = 0.7, spi = 0.25, int = 0.3, mp5 = 0.4, haste = 8, sta = 0.1 }),
	-- 드루이드 조화: 적중(17%) > 치명타 > 주문력 > 지능
	["DRUID:balance"] = Caster({ shit = 14, scrit = 11, sp = 1, sdmg = 1, int = 0.45, haste = 9, spi = 0.15, mp5 = 0.6, sta = 0.1, spen = 0.4 }),
	-- 야성(표범): 무기 공격력(포에버는 폼에도 무기 dps 가 더해짐) > 숙련 > 적중 > 민첩 > 힘
	["DRUID:feral"] = { dps = 14, exp = 25, hit = 24, agi = 2.25, str = 2.0, ap = 1, fap = 1, crit = 25, haste = 10, sta = 0.2, armor = 0.02 },
	-- 야성(곰): 방어도 > 방어 숙련(440) > 체력 > 민첩 > 회피 · 위협은 표범과 같은 순서
	["DRUID:guardian"] = { armor = 0.18, def = 1.3, sta = 1.4, agi = 1.6, dodge = 12, dps = 7, exp = 12, hit = 10, str = 0.8, ap = 0.4, fap = 0.4, crit = 6, haste = 3 },
	["DRUID:resto"] = Caster({ heal = 1, sp = 1, int = 0.75, spi = 0.7, mp5 = 1.5, scrit = 6, haste = 5, sta = 0.1 }),
	-- 성기사 신성: 치유량 > 지능 > 정신력 > 마나 회복 > 치명타
	["PALADIN:holy"] = Caster({ heal = 1, sp = 1, int = 0.8, spi = 0.65, mp5 = 1.4, scrit = 7, haste = 5, sta = 0.1 }),
	-- 보호: 체력 > 방어 숙련(440) > 주문력 > 지능 > 힘
	["PALADIN:prot"] = { sta = 1.6, def = 1.4, sp = 0.8, int = 0.5, str = 0.4, armor = 0.08, bv = 0.3, block = 3, dodge = 8, parry = 8,
		hit = 6, exp = 4, dps = 3, crit = 4, shit = 4 },
	-- 징벌(봉인 해제 빌드): 무기 공격력 > 적중(8%) > 숙련(6.5%) > 힘 > 주문력
	["PALADIN:ret"] = { dps = 16, hit = 26, exp = 22, str = 2.0, sp = 0.6, crit = 20, agi = 1.0, ap = 1, int = 0.3, haste = 12, sta = 0.2, armor = 0.01 },
	-- 징벌(신성 충격 빌드): 무기 공격력 > 적중 > 주문력 > 치명타 > 숙련
	["PALADIN:retshock"] = { dps = 12, hit = 24, sp = 1.3, sdmg = 1.3, crit = 18, exp = 14, str = 1.4, agi = 0.8, ap = 0.7, int = 0.4, haste = 10, sta = 0.2, armor = 0.01 },
	-- 주술사 정기: 주문력 > 적중(17%) > 치명타 > 지능 > 마나 회복
	["SHAMAN:ele"] = Caster({ sp = 1, sdmg = 1, shit = 12, scrit = 9, int = 0.4, mp5 = 0.8, haste = 9, spen = 0.5, spi = 0.1, sta = 0.1 }),
	-- 고양: 무기 공격력 > 적중 > 숙련 > 지능(전투력 75%) > 힘 > 주문력
	["SHAMAN:enh"] = { dps = 14, hit = 24, exp = 22, int = 2.1, str = 2.0, sp = 0.7, crit = 18, agi = 0.8, ap = 1, haste = 12, sta = 0.2, armor = 0.01 },
	-- 복원: 치유량 > 치명타 > 지능 > 정신력 > 마나 회복
	["SHAMAN:resto"] = Caster({ heal = 1, sp = 1, scrit = 10, int = 0.65, spi = 0.4, mp5 = 1.2, haste = 6, sta = 0.1 }),
}
M.W = W
M.K = K

-- 적중 상한 (%) · 근접 / 원거리 8, 주문 17
local SPELL_HIT = { MAGE = true, WARLOCK = true, ["PRIEST:shadow"] = true, ["DRUID:balance"] = true, ["SHAMAN:ele"] = true }

-- PvP: 체력을 크게, 적중 · 정신력 · 마나 회복은 덜 (탄력도가 없는 클래식 PvP 관례)
local function PvP(w)
	local p = {}
	for k, v in pairs(w) do p[k] = v end
	p.sta = math.max(1.0, (w.sta or 0) * 3)
	if p.hit then p.hit = p.hit * 0.5 end
	if p.shit then p.shit = p.shit * 0.6 end
	if p.exp then p.exp = p.exp * 0.6 end
	if p.spi then p.spi = p.spi * 0.4 end
	if p.mp5 then p.mp5 = p.mp5 * 0.6 end
	if p.crit then p.crit = p.crit * 1.1 end
	if p.armor then p.armor = math.max(p.armor, 0.03) end
	return p
end

-- 특성 탭 순서 (클래식 특성 트리 순서) · 본섭 특성 번호
local TABS = {
	WARRIOR = { "arms", "fury", "prot" }, ROGUE = { "assassination", "combat", "subtlety" },
	HUNTER = { "bm", "mm", "sv" }, MAGE = { "arcane", "fire", "frost" },
	WARLOCK = { "aff", "demo", "destro" }, PRIEST = { "disc", "holy", "shadow" },
	DRUID = { "balance", "feral", "resto" }, PALADIN = { "holy", "prot", "ret" },
	SHAMAN = { "ele", "enh", "resto" },
}
local SPEC_ID = {
	[71] = "arms", [72] = "fury", [73] = "prot", [259] = "assassination", [260] = "combat", [261] = "subtlety",
	[253] = "bm", [254] = "mm", [255] = "sv", [62] = "arcane", [63] = "fire", [64] = "frost",
	[265] = "aff", [266] = "demo", [267] = "destro", [256] = "disc", [257] = "holy", [258] = "shadow",
	[102] = "balance", [103] = "feral", [104] = "guardian", [105] = "resto", [65] = "holy", [66] = "prot", [70] = "ret",
	[262] = "ele", [263] = "enh", [264] = "resto",
}
-- 특성이 아직 없을 때 (레벨 10 전) 기본
M.TABS = TABS
local DEFAULT = { WARRIOR = "arms", ROGUE = "combat", HUNTER = "bm", MAGE = "frost", WARLOCK = "aff", PRIEST = "shadow", DRUID = "feral", PALADIN = "ret", SHAMAN = "enh" }
local SPEC_NAME = {
	arms = "무기", fury = "분노", prot = "방어", assassination = "암살", combat = "전투", subtlety = "잠행",
	bm = "야수", mm = "사격", sv = "생존", arcane = "비전", fire = "화염", frost = "냉기",
	aff = "고통", demo = "악마", destro = "파괴", disc = "수양", holy = "신성", shadow = "암흑",
	balance = "조화", feral = "야성", guardian = "수호", resto = "회복", ret = "징벌", ele = "정기", enh = "고양",
}

M.SPEC_NAME = SPEC_NAME

-------------------------------------------------------------------------------
-- 포에버 특성 트리: 클래식식 GetTalentTabInfo 가 없어서, 찍은 특성 칸의 아이콘으로 어느 트리에 몇 점인지 센다.
--  트리별 특성 아이콘 이름: wowf.io 특성 계산기 (2026-11-10 확인) · 두 트리에 같은 아이콘이 있으면 세지 않는다.
-------------------------------------------------------------------------------
local TREE_ICONS = {
	WARRIOR = {
		"ability_rogue_ambush,ability_parry,ability_gouge,ability_warrior_charge,spell_nature_enchantarmor,inv_sword_05,spell_holy_blessingofstamina,ability_backstab,inv_spear_01,inv_axe_09,ability_searingarrow,inv_sword_01,ability_rogue_slicedice,garrison_weaponupgrade,ability_warrior_decisivestrike,ability_shockwave,ability_warrior_savageblow",
		"spell_nature_purge,ability_rogue_eviscerate,ability_warrior_secondwind,spell_nature_stoneclawtotem,ability_warrior_incite,spell_shadow_deathscream,spell_shadow_summonimp,spell_shadow_unholyfrenzy,ability_dualwield,ability_warrior_bloodfrenzy,inv_sword_48,spell_nature_ancestralguardian,spell_shadow_deathpact,racial_troll_berserk,ability_rogue_sprint,ability_whirlwind,ability_ghoulfrenzy,spell_nature_bloodlust",
		"ability_racial_bloodrage,inv_shield_06,spell_magic_magearmor,spell_nature_mirrorimage,ability_warrior_revenge,ability_thunderclap,spell_holy_ashestoashes,ability_warrior_shieldguard,ability_warrior_disarm,ability_warrior_innerrage,ability_warrior_sunder,ability_warrior_shieldcharge,ability_warrior_shieldbash,ability_warrior_shieldwall,ability_thunderbolt,ability_warrior_focusedrage,inv_shield_04,inv_shield_05",
	},
	PALADIN = {
		"spell_arcane_blink,ability_golemthunderclap,spell_holy_holybolt,spell_holy_divineillumination,ability_thunderbolt,spell_holy_purifyingpower,spell_holy_heal,spell_holy_greaterheal,spell_holy_devineaegis,spell_holy_mindsooth,ability_paladin_infusionoflight,spell_holy_greaterblessingoflight,spell_holy_innerfire,spell_holy_searinglight,ability_paladin_sacredcleansing,spell_holy_power,ability_paladin_judgementofthepure",
		"spell_nature_sleep,ability_defend,ability_rogue_ambush,spell_holy_sealofprotection,spell_holy_divineintervention,ability_paladin_shieldofthetemplar,spell_holy_sealofmight,inv_shield_06,spell_holy_devotion,ability_paladin_judgementred,spell_holy_sealoffury,spell_magic_lesserinvisibilty,spell_holy_stoicism,spell_holy_blessingofprotection,spell_holy_blessingofstrength,spell_holy_improvedresistanceauras,spell_holy_greaterblessingofsanctuary",
		"ability_parry,spell_frost_windwalkon,spell_holy_righteousfury,spell_holy_retributionaura,ability_paladin_judgementblue,spell_holy_vindication,spell_holy_unyieldingfaith,ability_warrior_innerrage,spell_holy_persuitofjustice,spell_holy_eyeforaneye,inv_sword_08,inv_hammer_04,spell_holy_turnundead,spell_holy_prayerofhealing,ability_racial_avatar,ability_paladin_enlightenedjudgements,spell_holy_blessedresillience",
	},
	HUNTER = {
		"spell_nature_ravenform,spell_nature_reincarnation,inv_weapon_crossbow_10,ability_hunter_aspectofthemonkey,ability_hunter_beastsoothe,ability_mount_jungletiger,ability_druid_dash,ability_bullrush,ability_hunter_mendpet,inv_misc_monsterclaw_04,ability_hunter_animalhandler,ability_druid_demoralizingroar,ability_devour,spell_nature_abolishmagic,inv_misc_monsterclaw_03,ability_druid_ferociousbite",
		"ability_townwatch,spell_frost_stun,ability_searingarrow,ability_hunter_quickshot,spell_frost_wizardmark,ability_hunter_zenarchery,ability_hunter_rapidkilling,ability_impalingbolt,ability_mount_whitedirewolf,ability_trueshot,ability_piercedamage,ability_hunter_rapidregeneration,ability_upgrademoonglaive,ability_golemstormbolt,inv_weapon_rifle_06,hunter_pvp_snipershot",
		"inv_misc_head_dragon_black,ability_parry,spell_nature_stranglevines,ability_racial_bloodrage,spell_shadow_twilight,ability_rogue_trip,spell_nature_timestop,ability_kick,ability_whirlwind,ability_ensnare,ability_dualwield,ability_warrior_challange,ability_hunter_resourcefulness,ability_hunter_swiftstrike,ability_hunter_mastertactitian,ability_hunter_pet_tallstrider,spell_nature_invisibilty,ability_gouge",
	},
	ROGUE = {
		"ability_gouge,ability_fiegndead,ability_racial_bloodrage,ability_druid_disembowel,ability_warrior_riposte,ability_rogue_slicedice,spell_nature_earthbindtotem,ability_rogue_rupture,ability_criticalstrike,ability_rogue_feigndeath,spell_ice_lament,ability_poisons,ability_warrior_decisivestrike,inv_sword_31,ability_rogue_kidneyshot,spell_shadow_chilltouch,ability_rogue_deadlybrew",
		"ability_rogue_eviscerate,spell_shadow_ritualofsacrifice,spell_nature_invisibilty,ability_backstab,ability_parry,ability_marksmanship,ability_rogue_sprint,spell_shadow_shadowward,ability_warrior_challange,ability_rogue_fleetfooted,ability_kick,inv_sword_35,spell_holy_blessingofstrength,ability_racial_avatar,ability_dualwield,ability_warrior_punishingblow,inv_sword_27,ability_rogue_restlessblades,spell_shadow_shadowworddominate",
		"spell_nature_mirrorimage,spell_shadow_charm,ability_warrior_warcry,spell_shadow_summonsuccubus,ability_stealth,ability_rogue_ambush,ability_sap,spell_shadow_fumble,spell_shadow_possession,inv_sword_17,spell_magic_lesserinvisibilty,spell_shadow_curse,ability_rogue_blackjack,ability_ambush,spell_shadow_antishadow,spell_shadow_lifedrain,inv_sword_32,ability_creature_cursed_02",
	},
	PRIEST = {
		"spell_holy_searinglight,inv_wand_01,spell_holy_sealofvengeance,spell_nature_manaregentotem,spell_holy_divineillumination,spell_nature_enchantarmor,spell_nature_tranquility,ability_hibernation,spell_frost_windwalkon,spell_holy_powerwordshield,spell_nature_sleep,spell_holy_innerfire,spell_shadow_manaburn,spell_holy_pureofheart,spell_holy_penance,spell_holy_holyprotection,spell_holy_devineaegis,spell_holy_powerinfusion",
		"spell_holy_healingfocus,spell_holy_renew,spell_holy_sealofsalvation,spell_holy_spellwarding,spell_holy_sealofwrath,spell_holy_holynova,spell_holy_blessedrecovery,spell_holy_layonhands,spell_holy_purify,spell_holy_heal02,spell_holy_searinglightpriest,spell_holy_blindingheal,inv_scroll_07,inv_enchant_essenceeternallarge,spell_holy_spiritualguidence,spell_nature_moonglow,spell_holy_prayerofmendingtga",
		"spell_shadow_burningspirit,spell_shadow_gathershadows,spell_shadow_requiem,spell_shadow_unholyfrenzy,spell_shadow_shadowwordpain,spell_shadow_chilltouch,spell_shadow_psychicscream,spell_shadow_siphonmana,spell_shadow_soulleech_2,spell_warlock_demonsoul,spell_shadow_unsummonbuilding,spell_shadow_blackplague,spell_shadow_impphaseshift,spell_shadow_devouringplague,spell_shadow_demonicfortitude,spell_shadow_twilight,spell_shadow_shadowform",
	},
	SHAMAN = {
		"spell_nature_wispsplode,spell_nature_earthshock,spell_fire_elementaldevastation,spell_frost_frostward,spell_lightning_lightningbolt01,spell_fire_immolation,spell_shadow_manaburn,spell_nature_spiritarmor,spell_fire_sealoffire,spell_nature_eyeofthestorm,spell_nature_stranglevines,spell_nature_stormreach,spell_nature_callstorm,spell_nature_lightningoverload,spell_fire_volcano,spell_nature_unrelentingstorm",
		"spell_nature_stoneclawtotem,ability_thunderbolt,spell_shadow_grimward,spell_nature_stoneskintotem,spell_nature_mentalquickness,spell_nature_lightningshield,spell_fire_flametounge,spell_nature_elementalabsorption,spell_nature_mirrorimage,spell_holy_devotion,ability_ghoulfrenzy,ability_shaman_stormstrike,spell_nature_spiritwolf,ability_parry,spell_nature_sleep,spell_shaman_improvedstormstrike,spell_shaman_maelstromweapon,spell_nature_bloodlust",
		"spell_nature_magicimmunity,spell_frost_manarecharge,spell_nature_sleep,spell_nature_healingtouch,spell_nature_moonglow,spell_nature_reincarnation,spell_nature_undyingstrength,spell_nature_healingwavelesser,ability_shaman_watershield,spell_nature_tranquility,spell_nature_manaregentotem,spell_frost_summonwaterelemental,spell_nature_healingway,spell_nature_ravenform,spell_frost_wizardmark,spell_nature_riptide",
	},
	MAGE = {
		"inv_wand_01,spell_nature_starfall,spell_arcane_arcaneresilience,spell_holy_dispelmagic,spell_nature_astralrecalgroup,spell_shadow_manaburn,ability_mage_missilebarrage,inv_ability_mage_radiantspark,spell_nature_wispsplode,spell_arcane_blast,spell_shadow_detectlesserinvisibility,spell_frost_iceshock,spell_shadow_siphonmana,ability_mage_netherwindpresence,spell_nature_enchantarmor,spell_shadow_charm,spell_shadow_teleport,spell_nature_lightning",
		"spell_fire_flameshock,spell_fire_flamebolt,spell_fire_incinerate,spell_fire_flare,spell_fire_meteorstorm,spell_fire_fire,spell_fire_selfdestruct,spell_fire_fireball02,spell_fire_lavaspawn,spell_fire_soulburn,spell_fire_firearmor,spell_fire_firebolt,spell_fire_masterofelements,spell_nature_wispheal,spell_holy_excorcism_02,spell_fire_immolation,spell_fire_sealoffire",
		"spell_frost_frostward,spell_frost_frostbolt02,spell_ice_magicdamage,spell_frost_iceshard,spell_frost_frostarmor,spell_frost_freezingbreath,spell_frost_wisp,spell_frost_stun,spell_frost_icestorm,spell_frost_frostblast,spell_shadow_darkritual,spell_frost_frost,spell_frost_frostshock,spell_frost_glacier,spell_frost_wizardmark,ability_mage_wintersgrasp,spell_frost_chillingblast,spell_ice_lament",
	},
	WARLOCK = {
		"spell_shadow_burningspirit,spell_shadow_unsummonbuilding,spell_shadow_abominationexplosion,spell_shadow_callofbone,inv_elemental_primal_shadow,spell_shadow_haunting,spell_shadow_curseofsargeras,spell_shadow_fingerofdeath,spell_shadow_contagion,spell_shadow_unstableaffliction_2,spell_shadow_focusedpower,spell_shadow_twilight,spell_shadow_grimward,spell_shadow_requiem,spell_shadow_lifedrain02,spell_shadow_shadetruesight,ability_deathknight_hemorrhagicfever",
		"spell_shadow_lifedrain,spell_shadow_summonimp,spell_shadow_metamorphosis,spell_shadow_shadowworddominate,spell_shadow_ragingscream,spell_shadow_summonvoidwalker,spell_shadow_demonictactics,spell_shadow_felmending,ability_warlock_randomizesuccubusincubus,spell_shadow_psychicscream,spell_shadow_impphaseshift,spell_fire_fireball02,spell_nature_removecurse,ability_demonhunter_chaoticimprint_fire,spell_shadow_summonfelhunter,spell_shadow_gathershadows,spell_shadow_improvedvampiricembrace,spell_shadow_shadowpact,inv_ability_soulharvesterwarlock_demonicsoul",
		"spell_shadow_corpseexplode,spell_shadow_shadowbolt,spell_shadow_deathpact,ability_mage_moltenarmor,spell_fire_windsofwoe,spell_fire_fire,spell_shadow_shadowwordpain,spell_shadow_scourgebuild,spell_fire_lavaspawn,spell_fire_soulburn,spell_fire_fireball,spell_fire_volcano,ability_warlock_baneofhavoc,spell_fire_meteorstorm,spell_fire_playingwithfire,spell_fire_burnout",
	},
	DRUID = {
		"spell_nature_abolishmagic,spell_arcane_arcane03,spell_nature_sentinal,spell_nature_starfall,inv_staff_01,spell_nature_naturetouchgrow,spell_nature_stranglevines,spell_nature_natureresistancetotem,spell_nature_insectswarm,spell_nature_purge,spell_arcane_starfire,inv_misc_herb_15,spell_nature_naturesblessing,ability_druid_eclipse,spell_nature_moonglow,spell_nature_forceofnature",
		"ability_hunter_pet_hyena,spell_holy_blessingofstamina,spell_nature_spiritwolf,ability_ambush,ability_druid_bash,inv_misc_pelt_bear_03,spell_shadow_vampiricaura,ability_druid_ravage,ability_hunter_pet_bear,inv_misc_monsterclaw_04,ability_hunter_pet_cat,ability_druid_lacerate,spell_druid_savagery,ability_ghoulfrenzy,spell_nature_unyeildingstamina,ability_druid_predatoryinstincts,ability_druid_primalagression,ability_bullrush,ability_racial_cannibalize,spell_druid_displacement",
		"spell_nature_healingwavegreater,spell_holy_blessingofagility,spell_nature_healingtouch,spell_frost_windwalkon,spell_nature_wispsplode,ability_eyeoftheowl,spell_nature_protectionformnature,inv_misc_herb_felblossom,spell_holy_elunesgrace,spell_nature_rejuvenation,inv_relics_idolofrejuvenation,spell_nature_ravenform,spell_nature_giftofthewaterspirit,spell_nature_tranquility,spell_nature_resistnature,ability_druid_flourish",
	},
}
-- 이 아이콘이 내 직업 특성 칸 아이콘인가 (배울 기술에서 특성으로 얻는 기술 거르기)
function M.IsTalentIcon(class, icon)
	local src = TREE_ICONS[class]
	if not src or type(icon) ~= "string" then return false end
	icon = icon:lower()
	for _, list in ipairs(src) do
		for name in list:gmatch("[^,]+") do if name == icon then return true end end
	end
	return false
end
-- 곰 탱커 특성 (두꺼운 가죽 · 야성의 본능 · 자연의 반응 · 야성의 충격): 합쳐서 3점 이상이면 수호(곰)
local BEAR_TALENTS = { "inv_misc_pelt_bear_03", "ability_ambush", "ability_bullrush", "ability_druid_bash" }
-- 신성 충격 (성기사 신성 트리)
local HOLY_SHOCK = "spell_holy_searinglight"

local iconProbe
local function IconFileID(name)
	local path = "Interface\\Icons\\" .. name
	if GetFileIDFromPath then
		local ok, id = pcall(GetFileIDFromPath, path)
		if ok and type(id) == "number" and id > 0 then return id end
	end
	iconProbe = iconProbe or CreateFrame("Frame"):CreateTexture()
	if iconProbe.GetTextureFileID then
		iconProbe:SetTexture(path)
		local id = iconProbe:GetTextureFileID()
		if type(id) == "number" and id > 0 then return id end
	end
end
M.IconFileID = IconFileID

local treeMap = {}
local function TreeMap(class)
	if treeMap[class] then return treeMap[class] end
	local src = TREE_ICONS[class]
	if not src then return end
	local map, n = {}, 0
	for t, list in ipairs(src) do
		for name in list:gmatch("[^,]+") do
			local id = IconFileID(name)
			for _, k in ipairs({ id or false, name }) do
				if k then
					if map[k] and map[k] ~= t then map[k] = false else map[k] = t end
				end
			end
			if id then n = n + 1 end
		end
	end
	if n > 0 then treeMap[class] = map end
	return map
end

-- 찍은 특성 칸 아이콘 → 단계 합
local function TraitRanks()
	local T = ns.Talents
	if not (T and T.TraitsMode and T.TraitsMode() and T.TraitNodes) then return end
	local ranks, any = {}, false
	for _, n in ipairs(T.TraitNodes()) do
		if n.icon and (n.rank or 0) > 0 then
			ranks[n.icon] = (ranks[n.icon] or 0) + n.rank
			any = true
		end
	end
	return any and ranks or nil
end

local function RankOf(ranks, name)
	local id = IconFileID(name)
	return (id and ranks[id]) or ranks[name] or 0
end

-- 포에버: { 트리별 점수 }, 가장 많은 트리 key, 곰 여부, 신성 충격 여부
local function ForeverTree(class)
	local ranks = TraitRanks()
	if not ranks then return end
	local map = TreeMap(class)
	if not map then return end
	local pts = { 0, 0, 0 }
	for icon, r in pairs(ranks) do
		local t = map[icon]
		if t then pts[t] = pts[t] + r end
	end
	local best, bestN = nil, 0
	for t = 1, 3 do if pts[t] > bestN then best, bestN = t, pts[t] end end
	if not best then return end
	local key = TABS[class][best]
	if class == "DRUID" and key == "feral" then
		local bear = 0
		for _, nm in ipairs(BEAR_TALENTS) do bear = bear + RankOf(ranks, nm) end
		if bear >= 3 then key = "guardian" end
	end
	local shock = class == "PALADIN" and RankOf(ranks, HOLY_SHOCK) > 0
	return key, pts, shock
end
M.ForeverTree = ForeverTree

local specCache = { at = -100 }
function M:Spec()
	local _, class = UnitClass("player")
	local key = Ink.cdb and Ink.cdb.scoreSpec
	if key and W[class .. ":" .. key] then return class, key end
	local now = GetTime()
	if specCache.class == class and now - specCache.at < 10 then return class, specCache.spec end
	local spec, shock
	if FOREVER then
		local ok, k, pts, sh = pcall(ForeverTree, class)
		if ok and k then spec, shock = k, sh; specCache.pts = pts end
	end
	if not spec and GetTalentTabInfo and TABS[class] then
		local best, bestN = nil, 0
		for t = 1, 3 do
			local a, b, c, d, e = GetTalentTabInfo(t)
			-- 클라이언트마다 반환 순서가 달라서, 숫자 중 포인트로 보이는 값을 쓴다
			local n = (type(c) == "number" and c) or (type(e) == "number" and e) or 0
			if n > bestN then best, bestN = TABS[class][t], n end
		end
		spec = best
	end
	if not spec and FOREVER and ns.Talents and ns.Talents.GuessSpec then
		local ok, g = pcall(ns.Talents.GuessSpec, ns.Talents)
		if ok and g and W[class .. ":" .. g] then spec = g end
	end
	if not spec and GetSpecialization and GetSpecializationInfo then
		local i = GetSpecialization()
		local id = i and GetSpecializationInfo(i)
		if id and SPEC_ID[id] then spec = SPEC_ID[id] end
	end
	spec = spec or DEFAULT[class]
	specCache.class, specCache.spec, specCache.shock, specCache.at = class, spec, shock, now
	return class, spec
end

function M:ResetSpec() specCache.at = -100 end

function M:Mode()
	return (Ink.cdb and Ink.cdb.scoreMode) or "pve"
end

-- 지금 적중 % (장비 등급 + 근접은 특성 · 효과 보정). 주문 적중은 장비분만 (클라이언트마다 보정 함수 단위가 달라서)
local function CurHit(spell)
	local v = 0
	if GetCombatRatingBonus then
		local best = 0
		for _, cr in ipairs(spell and { CR_HIT_SPELL or 8, CR_HIT_MELEE or 6 } or { CR_HIT_MELEE or 6 }) do
			local ok, p = pcall(GetCombatRatingBonus, cr)
			p = ok and plain(p)
			if type(p) == "number" and p > best then best = p end
		end
		v = v + best
	end
	if not spell and GetHitModifier then
		local ok, p = pcall(GetHitModifier)
		p = ok and plain(p)
		if type(p) == "number" and p > 0 and p < 15 then v = v + p end
	end
	return v
end

-- 적중 상한을 이미 넘겼으면 적중 가치를 크게 낮춘다 (조금은 남겨서 같은 조건이면 적중 있는 쪽)
local capCache = {}
local function CapAdjust(w, class, spec)
	local spell = SPELL_HIT[class] or SPELL_HIT[class .. ":" .. spec]
	local cap = spell and 17 or 8
	local over = CurHit(spell) >= cap
	if not over then return w, "" end
	capCache[w] = capCache[w] or (function()
		local p = {}
		for k, v in pairs(w) do p[k] = v end
		if p.hit then p.hit = p.hit * 0.15 end
		if p.shit then p.shit = p.shit * 0.15 end
		return p
	end)()
	return capCache[w], "cap"
end

local weightSig = ""
function M:Weights()
	local class, spec = self:Spec()
	local wkey = (class or "") .. ":" .. (spec or "")
	if class == "PALADIN" and spec == "ret" and specCache.shock and not (Ink.cdb and Ink.cdb.scoreSpec) then wkey = "PALADIN:retshock" end
	local w = W[wkey]
	if not w then return end
	local sig
	w, sig = CapAdjust(w, class, spec)
	if self:Mode() == "pvp" then
		self.pvpCache = self.pvpCache or {}
		self.pvpCache[w] = self.pvpCache[w] or PvP(w)
		w = self.pvpCache[w]
	end
	weightSig = wkey .. sig
	return w, class, spec
end

-- 고른 특성의 가중치 (지금 내 특성이면 Weights 와 같음)
function M:WeightsFor(spec)
	local class, cur = self:Spec()
	if not spec or spec == cur then
		local w = self:Weights()
		return w, weightSig
	end
	local w = W[(class or "") .. ":" .. spec]
	if not w then return end
	local sig
	w, sig = CapAdjust(w, class, spec)
	if self:Mode() == "pvp" then
		self.pvpCache = self.pvpCache or {}
		self.pvpCache[w] = self.pvpCache[w] or PvP(w)
		w = self.pvpCache[w]
	end
	return w, (class or "") .. ":" .. spec .. sig
end

function M:ProfileName()
	local _, class, spec = self:Weights()
	local name = SPEC_NAME[spec or ""] or ""
	if class == "PALADIN" and spec == "ret" and specCache.shock then name = name .. "(신성 충격)" end
	if class == "DRUID" and spec == "guardian" then name = "야성(곰)" end
	return name .. " " .. (UnitClass("player") or "") .. " · " .. (self:Mode() == "pvp" and "PvP" or "PvE")
end

-------------------------------------------------------------------------------
-- 툴팁 읽기: 못 쓰는 장비 / 요구 레벨 / 장착 효과(적중 · 치명 · 공격력 · 주문력 …)
-------------------------------------------------------------------------------
local LEVEL_PAT
local function LevelPattern()
	if LEVEL_PAT == nil then
		LEVEL_PAT = ITEM_MIN_LEVEL and ("^" .. ITEM_MIN_LEVEL:gsub("%%d", "(%%d+)") .. "$") or false
	end
	return LEVEL_PAT
end

-- 직업별로 무기 전문가에게 배워서 쓸 수 있는 무기 (아이템 무기 종류 번호) · 워크래프트 태번 포에버 표
--  0 한손 도끼 · 1 양손 도끼 · 2 활 · 3 총 · 4 한손 둔기 · 5 양손 둔기 · 6 장창 · 7 한손 도검 · 8 양손 도검
--  10 지팡이 · 13 장착 무기 · 15 단검 · 16 투척 무기 · 18 석궁 · 19 마법봉
local function Set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WEAPON_OK = {
	WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
	PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
	HUNTER = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
	ROGUE = Set(0, 2, 3, 4, 7, 13, 15, 16, 18),
	PRIEST = Set(4, 10, 15, 19),
	SHAMAN = Set(0, 1, 4, 5, 10, 13, 15),
	MAGE = Set(7, 10, 15, 19),
	WARLOCK = Set(7, 10, 15, 19),
	DRUID = Set(4, 5, 6, 10, 13, 15),
}
ns.WEAPON_OK = WEAPON_OK
-- 이 무기 종류를 내 직업이 배워서 쓸 수 있나 (nil = 무기가 아님)
local function CanLearnWeapon(link)
	local _, _, _, _, _, classID, subID = GetItemInfoInstant(link)
	if classID ~= 2 then return nil end
	local _, cls = UnitClass("player")
	return (WEAPON_OK[cls] or {})[subID] and true or false, subID
end
M.CanLearnWeapon = CanLearnWeapon

local function IsRed(c)
	return c and c.r and c.r > 0.95 and c.g < 0.2 and c.b < 0.2
end

-- 장착 효과 문장에서 숫자 뽑기 (한글 / 영어)
local EFFECTS = {
	{ "주문.-적중", "spell.-hit", "shit", true },
	{ "주문.-치명", "spell.-critical", "scrit", true },
	{ "적중", "chance to hit", "hit", true },
	{ "치명타", "critical strike", "crit", true },
	{ "원거리 전투력", "ranged attack power", "rap" },
	{ "공격 전투력", "attack power", "ap" },
	{ "피해와 치유", "damage and healing", "sp" },
	{ "치유량", "healing done", "heal" },
	{ "5초마다.-마나", "mana per 5", "mp5" },
	{ "방어 숙련", "defense", "def" },
	{ "회피", "dodge", "dodge", true },
	{ "무기 막기", "parry", "parry", true },
}
-- 내 능력치를 올리는 효과만 (예: "자신에게 걸리는 침묵 효과의 적중률이 4% 감소" 는 적중이 아니라 방어 효과)
local function Positive(text, low)
	if text:find("감소") or text:find("걸리는") or text:find("받는") or low:find("decreas") or low:find("reduc")
		or low:find("against you") or low:find("you are hit") then return false end
	return text:find("증가") or text:find("향상") or low:find("increas") or low:find("improv")
end
local function ParseEffect(text, out)
	local low = text:lower()
	for _, e in ipairs(EFFECTS) do
		if (text:find(e[1]) or low:find(e[2])) and (not e[4] or Positive(text, low)) then
			-- "0.3%" 같은 소수도 그대로 (예전엔 "3%"로 읽어서 10배가 됐다)
			local n = tonumber(text:match("(%d+%.?%d*)%%")) or tonumber(text:match("(%d+%.?%d*)"))
			if n and (not e[4] or text:find("%%")) then
				out[e[3]] = (out[e[3]] or 0) + n
				return
			end
		end
	end
end

-- 툴팁 줄: 못 쓰면 "no", 레벨이 모자라면 요구 레벨, 장착 효과 능력치
local tipCache = {}
local function ReadTooltip(link)
	local c = tipCache[link]
	if c then return c end
	local r = { effects = {}, pcts = {} }
	if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return r end
	local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
	if not ok or not data or not data.lines then return r end
	-- 아이템 정보가 아직 안 왔으면 (줄이 거의 없음) 기억하지 않는다
	local complete = #data.lines >= 2 and GetItemInfo(link) ~= nil
	local lp = LevelPattern()
	local onEquip = ITEM_SPELL_TRIGGER_ONEQUIP
	-- 아직 안 배운 무기 종류는 빨간 줄로 나오지만, 무기 전문가에게 배우면 쓸 수 있는 종류면 못 쓰는 걸로 치지 않는다
	local learnable, subID = CanLearnWeapon(link)
	local subName = subID and GetItemSubClassInfo and GetItemSubClassInfo(2, subID)
	local function SkillLine(t)
		return learnable and type(t) == "string" and subName and (t == subName or t:find(subName, 1, true))
	end
	for i, line in ipairs(data.lines) do
		local t = plain(line.leftText)
		if i > 1 and type(t) == "string" then
			local rt = plain(line.rightText)
			if IsRed(line.leftColor) then
				local lv = lp and tonumber(t:match(lp))
				if lv then r.level = lv
				elseif SkillLine(t) then r.skill = true
				elseif not (DURABILITY_TEMPLATE and t:find(DURABILITY_TEMPLATE:gsub("%%d", "%%d+"):gsub("%%s", ".-"))) then
					r.no = true
				end
			end
			if type(rt) == "string" and IsRed(line.rightColor) then
				if SkillLine(rt) then r.skill = true else r.no = true end
			end
			if onEquip and t:find(onEquip, 1, true) then ParseEffect(t, r.effects)
			elseif t:find("%%") then
				-- 포에버 능력치 줄의 % ("적중률 0.3%") → 등급을 % 로 바꿀 때 그대로 쓴다
				local n = tonumber(t:match("(%d+%.?%d*)%%"))
				if n then
					local key = (t:find("주문.-적중") or t:lower():find("spell.-hit")) and "shit"
						or (t:find("주문.-치명") or t:lower():find("spell.-crit")) and "scrit"
						or (t:find("적중") or t:lower():find("hit")) and "hit"
						or (t:find("치명") or t:lower():find("crit")) and "crit"
						or (t:find("가속") or t:lower():find("haste")) and "haste"
					if key and not r.pcts[key] then r.pcts[key] = n end
				end
			end
		end
	end
	if complete then tipCache[link] = r else M.missed = true end
	return r
end

-- 내 캐릭터가 쓸 수 있는 장비인가 (빨간 줄 없음 · 레벨만 모자란 건 쓸 수 있다고 본다)
function M:Usable(link)
	return not ReadTooltip(link).no
end

-- 무기 전문가에게 무기 기술을 배워야 쓸 수 있는 장비인가
function M:NeedsSkill(link)
	return ReadTooltip(link).skill == true
end

-------------------------------------------------------------------------------
-- 점수
-------------------------------------------------------------------------------
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local OFFHAND_FACTOR = 0.5

local scoreCache = {}
-- 등급 → % (내 레벨 기준)
RATING_IDX = {
	hit = CR_HIT_MELEE or 6, crit = CR_CRIT_MELEE or 9, shit = CR_HIT_SPELL or 8,
	scrit = CR_CRIT_SPELL or 11, haste = CR_HASTE_MELEE or 18,
}
RatingPct = function(cr, v)
	if v ~= math.floor(v) then return v end
	if GetCombatRatingBonusForCombatRatingValue then
		local ok, p = pcall(GetCombatRatingBonusForCombatRatingValue, cr, v)
		p = ok and plain(p)
		if type(p) == "number" and p >= 0 and p < v + 1 then return p end
	end
	return v > 5 and v / 14 or v
end

-- spec: 다른 특성 기준으로 점수 (BIS · 던전 전리품에서 특성 아이콘을 눌렀을 때). 없으면 지금 내 특성
function M:Score(link, asOffhand, spec)
	if not link then return 0 end
	local w, sig
	if spec then w, sig = self:WeightsFor(spec) else w = self:Weights(); sig = weightSig end
	if not w then return end
	local key = link .. (asOffhand and "#oh" or "") .. self:Mode() .. sig
	if scoreCache[key] then return scoreCache[key] end
	local stats = GetItemStats(link)
	if not stats then M.missed = true return end
	local loc = select(4, GetItemInfoInstant(link))
	local total = 0
	for short, full in pairs(K) do
		local v = stats[full]
		if v and v ~= 0 then
			if short == "dps" then
				if RANGED[loc] then total = total + v * (w.rdps or 0)
				else total = total + v * (w.dps or 0) * (asOffhand and OFFHAND_FACTOR or 1) end
			elseif short == "armor" then
				-- 방어도는 가중치가 없는 특성도 아주 조금 쳐준다 (나머지가 같을 때 방어도 높은 쪽)
				total = total + v * (w.armor or 0.004)
			else
				-- 적중 · 치명타 · 가속은 1% 단위로 바꿔서 계산
				--  포에버는 등급 수치(정수)로 온다 → 게임이 내 레벨 기준으로 % 로 바꿔 준다 (툴팁의 "적중률 0.3%")
				--  소수면 이미 % · 바꿔 주는 함수가 없으면 예전처럼 대략 1% = 14
				local cr = RATING_IDX[short]
				if cr then
					local tp = ReadTooltip(link).pcts[short]
					v = tp or RatingPct(cr, v)
				end
				total = total + v * (w[short] or 0)
			end
		end
	end
	-- 툴팁에만 있는 장착 효과 (GetItemStats 가 못 읽는 것)
	local tip = ReadTooltip(link)
	for short, v in pairs(tip.effects) do
		if not stats[K[short] or ""] then total = total + v * (w[short] or 0) end
	end
	scoreCache[key] = total
	return total
end

local function Equipped(slot) return GetInventoryItemLink("player", slot) end

-- 본섭: 주 능력치 + 2차 능력치(특화 · 가속 · 치명 · 유연)를 전문화마다 다른 비중으로
--  비중은 그 전문화 BIS 장비(BISData)에 붙은 2차 능력치 합에서 뽑는다 → BIS 가 좋아하는 능력치가 높게.
--  내 전문화 주 능력치가 아닌 장비는 비교하지 않는다. 장신구는 사용 · 발동 효과가 핵심이라 따로 본다.
local PRIMARY = { [1] = "ITEM_MOD_STRENGTH_SHORT", [2] = "ITEM_MOD_AGILITY_SHORT", [4] = "ITEM_MOD_INTELLECT_SHORT" }
local SECONDARY = { "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_VERSATILITY" }
local SEC_NAME = { ITEM_MOD_MASTERY_RATING_SHORT = "특화", ITEM_MOD_HASTE_RATING_SHORT = "가속", ITEM_MOD_CRIT_RATING_SHORT = "치명", ITEM_MOD_VERSATILITY = "유연" }

local function RetailSpec()
	if not (GetSpecialization and GetSpecializationInfo) then return end
	local i = GetSpecialization()
	if not i then return end
	local id, name, _, _, _, primary = GetSpecializationInfo(i)
	local _, class = UnitClass("player")
	return id, name, primary, class
end

local retailW = {}
function M:RetailWeights()
	local id, _, _, class = RetailSpec()
	if not id then return end
	local key = class .. ":" .. id
	if retailW[key] then return retailW[key] end
	local spec = ns.BIS and ns.BIS.specs and ns.BIS.specs[key]
	local sum, total, missing = {}, 0, false
	if spec and spec.g then
		for _, itemID in pairs(spec.g) do
			local st = GetItemStats("item:" .. itemID)
			if st then
				for _, k in ipairs(SECONDARY) do
					local v = st[k] or 0
					sum[k] = (sum[k] or 0) + v
					total = total + v
				end
			else
				missing = true
				if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
			end
		end
	end
	local w = { order = {} }
	local top = 0
	for _, k in ipairs(SECONDARY) do top = math.max(top, sum[k] or 0) end
	for _, k in ipairs(SECONDARY) do
		-- 가장 좋아하는 2차 = 0.6, 나머지는 비율대로 (최소 0.2). BIS 정보가 없으면 모두 0.4
		w[k] = (top > 0) and math.max(0.2, 0.6 * (sum[k] or 0) / top) or 0.4
		w.order[#w.order + 1] = k
	end
	table.sort(w.order, function(x, y) return w[x] > w[y] end)
	w.bis = spec and spec.g
	if total > 0 and not missing then retailW[key] = w end
	return w
end

local function RetailScore(link)
	local stats = GetItemStats(link)
	if not stats then M.missed = true return end
	local _, _, my = RetailSpec()
	local hasPrimary, mine = false, 0
	for id, k in pairs(PRIMARY) do
		if stats[k] then
			hasPrimary = true
			if id == my then mine = stats[k] end
		end
	end
	if hasPrimary and my and mine == 0 then return false end
	local w = M:RetailWeights() or {}
	local sc = mine
	for _, k in ipairs(SECONDARY) do sc = sc + (stats[k] or 0) * (w[k] or 0.4) end
	sc = sc + (stats.ITEM_MOD_STAMINA_SHORT or 0) * 0.02
	return sc
end

function M:RetailOrder()
	local w = self:RetailWeights()
	if not w then return "" end
	local t = {}
	for _, k in ipairs(w.order) do t[#t + 1] = SEC_NAME[k] end
	return table.concat(t, " > ")
end

-- 본섭 장신구: 사용 · 발동 효과가 핵심이라 점수 대신 BIS 여부 + 아이템 레벨만
local function RetailTrinket(link)
	local itemID = GetItemInfoInstant(link)
	local w = M:RetailWeights()
	local isBis = false
	if w and w.bis then
		for slot, id in pairs(w.bis) do
			if (slot == 13 or slot == 14) and id == itemID then isBis = true end
		end
	end
	local function lvl(l) return l and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(l) or 0 end
	local a, b = Equipped(13), Equipped(14)
	local sameID
	for _, e in ipairs({ a, b }) do
		if e and GetItemInfoInstant(e) == itemID then sameID = e end
	end
	local base = sameID and lvl(sameID) or math.min(lvl(a), lvl(b))
	return { trinket = true, bis = isBis, ilvl = lvl(link) - base, same = sameID ~= nil, empty = not a or not b,
		pct = (isBis and not sameID) and 1 or ((sameID and lvl(link) > lvl(sameID)) and 1 or 0) }
end

-------------------------------------------------------------------------------
-- 착용 중인 것과 비교
-------------------------------------------------------------------------------
local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}


-- 착용 장비 한 칸 평균 점수 (셔츠 · 겉옷 빼고) · 잠깐 기억
local baseCache, baseAt = 0, -10
function M:SlotBaseline()
	local now = GetTime()
	if now - baseAt < 3 then return baseCache end
	local sum, n = 0, 0
	for slot = 1, 18 do
		if slot ~= 4 then
			local l = Equipped(slot)
			local v = l and FOREVER and self:Score(l, slot == 17)
			if type(v) == "number" and v > 0 then sum, n = sum + v, n + 1 end
		end
	end
	baseCache, baseAt = (n > 0) and (sum / n) or 0, now
	return baseCache
end

-- 결과: { pct, new, old, level, empty } 또는 nil (비교할 수 없음)
function M:Compare(link)
	if not link or Ink.db.itemCompare == false or self:Mode() == "off" then return end
	local loc = select(4, GetItemInfoInstant(link))
	local slots = loc and SLOTS[loc]
	if not slots then return end
	local tip = ReadTooltip(link)
	if tip.no then return end
	if not FOREVER and loc == "INVTYPE_TRINKET" then
		local r = RetailTrinket(link)
		local lvl = tip.level
		if lvl and lvl <= (UnitLevel("player") or 0) then lvl = nil end
		r.level = lvl
		return r
	end
	local score = FOREVER and function(l, oh) return self:Score(l, oh) end or function(l) return RetailScore(l) end
	local new
	local old
	local emptySlot = false -- 그 칸에 착용한 게 정말 없을 때만 "빈 칸"
	if loc == "INVTYPE_2HWEAPON" then
		new = score(link)
		local mh, oh = Equipped(16), Equipped(17)
		emptySlot = not mh and not oh
		local a = mh and score(mh) or 0
		local b = oh and score(oh, true) or 0
		if a == nil or b == nil then return end
		old = (a or 0) + (FOREVER and (b or 0) or 0)
	elseif loc == "INVTYPE_WEAPON" then
		local mh, oh = Equipped(16), Equipped(17)
		local mhLoc = mh and select(4, GetItemInfoInstant(mh))
		if mhLoc == "INVTYPE_2HWEAPON" then
			-- 양손 → 한손: 한손 + 지금 보조장비 없음
			new, old = score(link), score(mh)
		else
			local ohIsWeapon = oh and select(4, GetItemInfoInstant(oh)) == "INVTYPE_WEAPON"
			local dual = CanDualWield and CanDualWield()
			local sm = mh and score(mh) or 0
			if dual and ohIsWeapon then
				local so = score(oh, true) or 0
				-- 약한 쪽과 비교
				if FOREVER and so < sm * OFFHAND_FACTOR then new, old = score(link, true), so else new, old = score(link), sm end
			elseif dual and not oh then
				new, old = score(link, true), 0
				emptySlot = true
				if not mh then new, old = score(link), 0 end
			else
				new, old = score(link), sm
				emptySlot = not mh
			end
		end
	elseif loc == "INVTYPE_FINGER" or loc == "INVTYPE_TRINKET" then
		new = score(link)
		local a, b = Equipped(slots[1]), Equipped(slots[2])
		if not a or not b then old = 0; emptySlot = true
		else
			local sa, sb = score(a), score(b)
			if sa == nil or sb == nil then return end
			old = math.min(sa or 0, sb or 0)
		end
	elseif loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
		local mh = Equipped(16)
		if mh and select(4, GetItemInfoInstant(mh)) == "INVTYPE_2HWEAPON" then return end
		new = score(link, loc == "INVTYPE_WEAPONOFFHAND")
		local oh = Equipped(17)
		old = oh and score(oh, loc == "INVTYPE_WEAPONOFFHAND") or 0
		emptySlot = not oh
	else
		new = score(link)
		local cur = Equipped(slots[1])
		old = cur and score(cur) or 0
		emptySlot = not cur
	end
	if new == false or old == false then return end
	if new == nil or old == nil then return end
	local empty = emptySlot
	local pct
	if empty then pct = 100
	elseif old <= 0 then pct = (new > 0) and 100 or 0 -- 둘 다 점수 0 (예: 방어도만 다른 천 장갑) → 비슷
	else
		-- 원거리 칸처럼 원래 점수가 아주 작은 칸은 조금만 좋아도 수천 % 가 나와서,
		--  착용 장비 한 칸 평균 점수보다 작으면 그 평균을 기준으로 잰다
		pct = (new - old) / math.max(math.abs(old), self:SlotBaseline(), 1) * 100
	end
	local lvl = tip.level
	if lvl and lvl <= (UnitLevel("player") or 0) then lvl = nil end
	return { pct = pct, new = new, old = old, level = lvl, empty = empty }
end

-- 가방 칸: 더 좋은 장비인가 (화살표 표시용)
function M:BagUpgrade(bag, slot)
	local link = C_Container.GetContainerItemLink(bag, slot)
	if not link then return end
	local ok, r = pcall(self.Compare, self, link)
	if not ok or not r then return end
	if r.trinket then
		if r.pct > 0 then return r end
	elseif r.empty or r.pct > 0.5 then
		return r
	end
end

function M:Invalidate()
	wipe(scoreCache)
	specCache.at = -100
	self.version = (self.version or 0) + 1
	local bags = Ink.modules.Bags
	if bags and bags.Schedule then pcall(bags.Schedule, bags) end
	pcall(self.UpdateQuestRewards, self)
end

-------------------------------------------------------------------------------
-- 툴팁 줄
-------------------------------------------------------------------------------
local function Line(tt, r)
	local txt
	if r.trinket then
		-- 본섭 장신구
		if r.bis then txt = "|cffFFF468BIS 장신구|r"
		else txt = "|cff9EA3AB장신구 · 사용/발동 효과로 판단|r" end
		if r.same and r.ilvl > 0 then txt = txt .. string.format("  |cff6FD39A같은 장신구 아이템 레벨 +%d|r", r.ilvl)
		elseif r.ilvl ~= 0 and not r.empty then txt = txt .. string.format("  |cff9EA3AB아이템 레벨 %+d|r", r.ilvl) end
		if r.level then txt = txt .. string.format("  |cffFFF468%d레벨부터|r", r.level) end
		tt:AddLine(txt)
		return
	end
	if r.empty then
		txt = "|cff6FD39A▲ 빈 칸에 착용 가능|r"
	else
		local p = math.floor(r.pct + (r.pct >= 0 and 0.5 or -0.5))
		if p > 0 then txt = string.format("|cff6FD39A▲ 착용 대비 +%d%%|r", p)
		elseif p < 0 then txt = string.format("|cffD9776B▼ 착용 대비 %d%%|r", p)
		else txt = "|cff9EA3AB= 착용한 것과 비슷|r" end
	end
	if r.level then txt = txt .. string.format("  |cffFFF468%d레벨부터|r", r.level) end
	local right = FOREVER and M:ProfileName() or M:RetailOrder()
	-- 아이템 점수 (FOA 가중치 합) · 착용 중인 것의 점수와 같이
	local sc = ""
	if r.new and r.new > 0 then
		sc = string.format("|cffE3C07A점수 %d|r", math.floor(r.new + 0.5))
		if r.old and r.old > 0 and not r.empty then sc = sc .. string.format(" |cff5E636B(지금 %d)|r", math.floor(r.old + 0.5)) end
		sc = sc .. "  "
	end
	-- 한 줄로 붙여서 (오른쪽 정렬이면 툴팁이 넓을 때 가운데가 크게 빈다)
	tt:AddLine(txt .. "   " .. sc .. string.format("|cff5E636B%s|r", right or ""))
end

function M:HookTooltip()
	if not (TooltipDataProcessor and Enum.TooltipDataType) then return end
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		pcall(M.OnTooltip, M, tt)
	end)
end

function M:OnTooltip(tt)
	do
		if Ink.db.itemCompare == false or not tt.AddLine or not tt.GetItem then return end
		-- 비교용 보조 툴팁(착용 중 표시)에는 안 붙인다
		local name = tt.GetName and tt:GetName() or ""
		if name:find("Shopping") or name:find("Compare") then return end
		local ok, _, link = pcall(tt.GetItem, tt)
		link = ok and plain(link)
		if not link then return end
		for s = 1, 19 do if Equipped(s) == link then return end end
		local r = M:Compare(link)
		if r then Line(tt, r) end
		-- 아직 안 배운 무기 종류: 무기 전문가에게 배우면 쓸 수 있다
		if ReadTooltip(link).skill then
			tt:AddLine("|cffE3C07A무기 전문가에게 배우면 쓸 수 있어요|r |cff8E939B· P(주문책) 옆 목록에서 위치|r")
		end
	end
end

-------------------------------------------------------------------------------
-- 퀘스트 보상: 더 좋은 장비에 화살표
-------------------------------------------------------------------------------
function M:UpdateQuestRewards()
	if Ink.db.itemCompare == false then return end
	local frame = QuestInfoRewardsFrame
	if not frame or not frame:IsVisible() then return end
	local buttons = frame.RewardButtons or {}
	for i = 1, 10 do
		local b = buttons[i] or _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
		if b and b:IsShown() then
			local link
			local kind = b.type or "choice"
			if QuestInfoFrame and QuestInfoFrame.questLog and GetQuestLogItemLink then
				link = GetQuestLogItemLink(kind, b:GetID())
			elseif GetQuestItemLink then
				link = GetQuestItemLink(kind, b:GetID())
			end
			local r = link and self:Compare(link)
			if not b.foaUp then
				b.foaUp = b:CreateTexture(nil, "OVERLAY", nil, 7)
				b.foaUp:SetTexture(Ink.icon("Up"))
				b.foaUp:SetSize(14, 14)
				local icon = b.Icon or b.icon or _G[(b:GetName() or "") .. "IconTexture"]
				b.foaUp:SetPoint("TOPLEFT", icon or b, "TOPLEFT", -2, 2)
			end
			local show = r and ((r.trinket and r.pct > 0) or (not r.trinket and (r.empty or r.pct > 0.5)))
			b.foaUp:SetShown(show and true or false)
			if show then
				if r.level then b.foaUp:SetVertexColor(C.accent[1], C.accent[2], C.accent[3]) else b.foaUp:SetVertexColor(0.44, 0.83, 0.6) end
			end
		elseif b and b.foaUp then
			b.foaUp:Hide()
		end
	end
end

-------------------------------------------------------------------------------
function M:Init()
	self:HookTooltip()
	if QuestInfo_Display then
		hooksecurefunc("QuestInfo_Display", function() C_Timer.After(0, function() pcall(M.UpdateQuestRewards, M) end) end)
	end
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
		"ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "SKILL_LINES_CHANGED", "GET_ITEM_INFO_RECEIVED",
		"TRAIT_CONFIG_UPDATED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event)
		if event == "GET_ITEM_INFO_RECEIVED" then
			-- 아이템 정보가 늦게 와서 점수를 못 낸 칸이 있으면 잠깐 뒤에 다시
			if M.retryQueued or not M.missed then return end
			M.missed = nil
			M.retryQueued = true
			C_Timer.After(0.5, function() M.retryQueued = nil; M:Invalidate() end)
			return
		end
		if event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED" then wipe(tipCache) end
		M:Invalidate()
	end)
end
