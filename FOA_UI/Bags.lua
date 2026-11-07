-- InkUI · 가방
--  블리자드 가방 대신 하나로 합친 Ink 가방 창.
--  분류: 고정(귀환석 + 직접 고정한 아이템) / 아이템(장비) / 소모품 / 재료 / 잡동사니
--  위쪽 탭으로 분류만 골라 볼 수 있고, 제목 줄을 끌어서 위치를 옮길 수 있다 (저장됨).
--  칸은 블리자드 ContainerFrameItemButtonTemplate 을 그대로 써서 클릭·사용·끌어놓기·툴팁은 기본과 같다.
--  전투 중에는 칸을 새로 만들거나 다시 배치하지 않는다 (보안 버튼 오염 방지) → 전투가 끝나면 다시 정리.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Bags")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

local SLOT, GAP, COLS, PAD = 36, 5, 10, 16
local HEAD_H, FOOT_H, SEC_H = 84, 56, 26
local MAX_VIEW = 600
local WIDTH = PAD * 2 + COLS * SLOT + (COLS - 1) * GAP
local HEARTH = 6948

local CATS = {
	{ key = "pin",  name = "고정" },
	{ key = "gear", name = "아이템" },
	{ key = "cons", name = "소모품" },
	{ key = "mat",  name = "재료" },
	{ key = "misc", name = "잡동사니" },
}
local TABS = { { key = "all", name = "전체" } }
for _, c in ipairs(CATS) do TABS[#TABS + 1] = c end

local IC = Enum.ItemClass or {}
local REAGENT_BAG = Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
local NUM_BAGS = NUM_BAG_SLOTS or 4

local function BagList()
	local t = {}
	for b = 0, NUM_BAGS do t[#t + 1] = b end
	t[#t + 1] = REAGENT_BAG
	return t
end

-------------------------------------------------------------------------------
-- 고정 목록 (귀환석은 항상 맨 앞)
-------------------------------------------------------------------------------
local function Pins()
	Ink.db.bagPins = Ink.db.bagPins or {}
	return Ink.db.bagPins
end

local function PinOrder(itemID)
	if itemID == HEARTH then return 0 end
	return Pins()[itemID]
end

-------------------------------------------------------------------------------
-- 분류
-------------------------------------------------------------------------------
local function Category(itemID, quality, bag)
	if PinOrder(itemID) then return "pin" end
	if quality == 0 then return "misc" end
	local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
	if classID == IC.Weapon or classID == IC.Armor or classID == (IC.Profession or 19) then return "gear" end
	if classID == IC.Consumable then return "cons" end
	if bag == REAGENT_BAG or classID == IC.Tradegoods or classID == IC.Reagent or classID == IC.Gem
		or classID == IC.ItemEnhancement then
		return "mat"
	end
	return "misc"
end

-------------------------------------------------------------------------------
-- 퀘스트에 필요한 일반 아이템 (요리 재료 · 가죽 등)
--  퀘스트 목표 글("멧돼지 갈비: 3/8")에서 아이템 이름을 읽어, 가방의 같은 이름 아이템에 표시한다.
--  목표를 다 채웠어도 보고하기 전까지는 표시 (그 전에 팔면 다시 모아야 한다)
-------------------------------------------------------------------------------
local need = {}        -- 아이템 이름 → { { title, have, want }, ... }
local needDirty = true

local function ObjName(text)
	if type(text) ~= "string" or text == "" then return end
	local name = text:gsub("%d+%s*/%s*%d+", ""):gsub("[:：]", "")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name ~= "" then return name end
end

function M:RebuildNeed()
	needDirty = false
	wipe(need)
	if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives) then return end
	for i = 1, (C_QuestLog.GetNumQuestLogEntries() or 0) do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID then
			for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
				if plain(o.type) == "item" then
					local nm = ObjName(plain(o.text))
					if nm then
						local t = need[nm] or {}
						need[nm] = t
						t[#t + 1] = { title = plain(info.title) or "", have = tonumber(plain(o.numFulfilled)) or 0, want = tonumber(plain(o.numRequired)) or 0 }
					end
				end
			end
		end
	end
end

local function NeedOf(name)
	if needDirty then pcall(M.RebuildNeed, M) end
	name = plain(name)
	return type(name) == "string" and need[name] or nil
end
M.NeedOf = NeedOf

-------------------------------------------------------------------------------
-- 세부 분류 (소모품 / 재료 안에서 작은 제목으로 나눈다)
--  이름은 블리자드 하위 분류 이름(한국어)을 그대로 쓰고, 몇 가지는 묶는다.
-------------------------------------------------------------------------------
local CONS = { -- 소모품 하위 분류 번호 → 묶음
	[1] = { 1, "물약" },
	[2] = { 2, "영약 · 약병" }, [3] = { 2, "영약 · 약병" },
	[5] = { 3, "음식 · 음료" },
	[6] = { 4, "숫돌 · 오일" },
	[7] = { 5, "붕대" },
}

local function SubName(classID, subID)
	local name = GetItemSubClassInfo and classID and subID and GetItemSubClassInfo(classID, subID)
	if type(name) == "string" and name ~= "" then return name end
end

-- 돌려주는 값: 정렬 순서, 표시 이름
local function SubGroup(cat, classID, subID)
	if cat == "cons" then
		local c = CONS[subID]
		if c then return c[1], c[2] end
		if subID == 0 or subID == 8 or not subID then return 90, "기타" end
		return 50 + subID, SubName(classID, subID) or "기타"
	elseif cat == "mat" then
		if classID == IC.Gem then return 60, SubName(classID, subID) and "보석" or "보석" end
		if classID == IC.ItemEnhancement then return 61, "강화" end
		local name = SubName(classID, subID)
		if not name or subID == 11 or subID == 0 then return 90, "기타" end
		return 10 + (subID or 0), name
	end
end

local function SortItems(a, b)
	if a.subOrder ~= b.subOrder then return (a.subOrder or 0) < (b.subOrder or 0) end
	if a.subName ~= b.subName then return (a.subName or "") < (b.subName or "") end
	if a.cat == "pin" then
		local oa, ob = PinOrder(a.itemID) or 999, PinOrder(b.itemID) or 999
		if oa ~= ob then return oa < ob end
	end
	if a.quality ~= b.quality then return a.quality > b.quality end
	if a.classID ~= b.classID then return (a.classID or 99) < (b.classID or 99) end
	if a.subID ~= b.subID then return (a.subID or 99) < (b.subID or 99) end
	if a.itemID ~= b.itemID then return a.itemID < b.itemID end
	if a.count ~= b.count then return a.count > b.count end
	if a.bag ~= b.bag then return a.bag < b.bag end
	return a.slot < b.slot
end

-------------------------------------------------------------------------------
-- 칸 (블리자드 가방 칸 템플릿 + Ink 꾸밈)
--  칸마다 부모 프레임 하나: 부모 ID = 가방 번호, 버튼 ID = 칸 번호 (템플릿이 이걸 읽는다)
--  꾸밈 정보는 버튼에 직접 쓰지 않고 바깥 표에 둔다 (보안 실행 경로 오염 방지)
-------------------------------------------------------------------------------
local skin = setmetatable({}, { __mode = "k" })

local function SetTex(b, t)
	if b.SetItemButtonTexture then b:SetItemButtonTexture(t) else SetItemButtonTexture(b, t) end
end
local function SetCount(b, n)
	if b.SetItemButtonCount then b:SetItemButtonCount(n) else SetItemButtonCount(b, n) end
end

local function HideRegion(r)
	if r then r:SetAlpha(0) end
end

local function SkinButton(b)
	local s = {}
	skin[b] = s
	HideRegion(b:GetNormalTexture())
	HideRegion(b.IconBorder)
	HideRegion(b.IconOverlay)
	HideRegion(b.IconOverlay2)
	HideRegion(b.NewItemTexture)
	HideRegion(b.BattlepayItemTexture)
	HideRegion(b.IconQuestTexture)
	HideRegion(b.JunkIcon)
	HideRegion(b.UpgradeIcon)
	HideRegion(b.flash)
	HideRegion(b.searchOverlay)
	HideRegion(b.ItemContextOverlay)
	HideRegion(b.ExtendedSlot)
	local pushed = b:GetPushedTexture()
	if pushed then
		pushed:SetTexture(Ink.tex.round4)
		pushed:SetVertexColor(0, 0, 0, 0.35)
	end
	local hl = b:GetHighlightTexture()
	if hl then
		hl:SetTexture(Ink.tex.round4)
		if hl.SetTextureSliceMargins then hl:SetTextureSliceMargins(5, 5, 5, 5) end
		hl:SetVertexColor(1, 1, 1, 0.1)
		hl:SetBlendMode("ADD")
	end

	s.bg = Ink:Round(b, "BACKGROUND", true, false, -8)
	s.bg:SetAllPoints()
	s.bg:SetVertexColor(1, 1, 1, 0.04)

	local icon = b.icon or b.Icon
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		if b.CreateMaskTexture and icon.AddMaskTexture then
			local mask = b:CreateMaskTexture()
			mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(icon)
			icon:AddMaskTexture(mask)
		end
	end
	s.icon = icon

	local cd = b.Cooldown or (b.GetName and b:GetName() and _G[b:GetName() .. "Cooldown"])
	if not cd then
		cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	end
	cd:ClearAllPoints()
	cd:SetPoint("TOPLEFT", 1, -1)
	cd:SetPoint("BOTTOMRIGHT", -1, 1)
	Ink:SkinCooldown(cd, true)
	s.cd = cd

	local top = CreateFrame("Frame", nil, b)
	top:SetAllPoints()
	top:SetFrameLevel(cd:GetFrameLevel() + 2)
	top:EnableMouse(false)
	s.top = top
	s.border = Ink:Round(top, "OVERLAY", true, true)
	s.border:SetAllPoints()
	s.border:SetVertexColor(1, 1, 1, 0.12)

	local count = b.Count or (b.GetName and b:GetName() and _G[b:GetName() .. "Count"])
	if count then
		count:SetParent(top)
		count:SetFont(F.latinB, 10, "OUTLINE")
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", -2, 2)
		count:SetDrawLayer("OVERLAY", 7)
	end

	s.ilvl = Ink:Text(top, F.latinB, 9, C.soft, "LEFT")
	s.ilvl:SetFont(F.latinB, 9, "OUTLINE")
	s.ilvl:SetPoint("TOPLEFT", 3, -3)

	s.new = top:CreateTexture(nil, "OVERLAY", nil, 7)
	s.new:SetTexture(Ink.tex.round4)
	s.new:SetSize(6, 6)
	s.new:SetPoint("TOPRIGHT", -3, -3)
	s.new:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
	s.new:Hide()

	-- 지금 착용한 것보다 좋은 장비 (아이템 점수 비교)
	s.up = top:CreateTexture(nil, "OVERLAY", nil, 7)
	s.up:SetTexture(Ink.icon("Up"))
	s.up:SetSize(12, 12)
	s.up:SetPoint("BOTTOMLEFT", 2, 2)
	s.up:Hide()

	s.free = Ink:Text(top, F.latinB, 11, C.soft, "CENTER")
	s.free:SetPoint("CENTER")
	s.free:Hide()

	-- 퀘스트에 필요한 일반 아이템: 왼쪽 위 작은 느낌표
	s.qneed = top:CreateTexture(nil, "OVERLAY", nil, 7)
	s.qneed:SetTexture(Ink.icon("QuestBang"))
	s.qneed:SetSize(12, 12)
	s.qneed:SetPoint("TOPLEFT", 2, -2)
	s.qneed:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	s.qneed:Hide()
end

local holders = {}      -- 만들어 둔 칸 (부모 프레임)
local active = {}       -- 지금 배치된 칸

local function NewHolder(parent)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(SLOT, SLOT)
	local b = CreateFrame("ItemButton", nil, h, "ContainerFrameItemButtonTemplate")
	b:ClearAllPoints()
	b:SetAllPoints(h)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	SkinButton(b)
	-- 휠 클릭: 고정 / 고정 해제
	b:HookScript("OnMouseUp", function(self, button)
		if button == "MiddleButton" then M:TogglePin(self) end
	end)
	h.btn = b
	h:Hide()
	return h
end

-- 칸 모양 갱신 (전투 중에도 안전한 부분만)
local function Paint(h)
	local b = h.btn
	local s = skin[b]
	local bag, slot = h.bag, h.slot
	if not bag then return end
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info then
		SetTex(b, nil)
		SetCount(b, 0)
		SetItemButtonDesaturated(b, false)
		s.border:SetVertexColor(1, 1, 1, 0.08)
		s.ilvl:SetText("")
		s.new:Hide()
		s.up:Hide()
		if s.qneed then s.qneed:Hide() end
		s.cd:Clear()
		b:SetAlpha(1)
		return
	end
	SetTex(b, info.iconFileID)
	SetCount(b, info.stackCount)
	SetItemButtonDesaturated(b, info.isLocked)

	local q = info.quality or 1
	local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
	local qn = NeedOf(info.itemName or C_Item.GetItemInfo(info.itemID))
	if (quest and (quest.isQuestItem or quest.questID)) or qn then
		s.border:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	elseif q >= 2 then
		local r, g, bl = C_Item.GetItemQualityColor(q)
		s.border:SetVertexColor(r, g, bl, 0.9)
	elseif q == 0 then
		s.border:SetVertexColor(0.5, 0.5, 0.5, 0.18)
	else
		s.border:SetVertexColor(1, 1, 1, 0.12)
	end
	SetItemButtonDesaturated(b, info.isLocked or q == 0)

	-- 장비면 아이템 레벨
	local text = ""
	if h.cat == "gear" and q >= 2 and ItemLocation and C_Item.GetCurrentItemLevel then
		local ok, lvl = pcall(function()
			return C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot))
		end)
		if ok and plain(lvl) and lvl > 1 then text = tostring(lvl) end
	end
	s.ilvl:SetText(text)
	s.qneed:ClearAllPoints()
	s.qneed:SetPoint(text ~= "" and "LEFT" or "TOPLEFT", 2, text ~= "" and 0 or -2)
	s.qneed:SetShown(qn and true or false)
	if text ~= "" and q >= 2 then
		local r, g, bl = C_Item.GetItemQualityColor(q)
		s.ilvl:SetTextColor(r, g, bl)
	end

	local up = h.cat == "gear" and ns.Score and ns.Score:BagUpgrade(bag, slot)
	if up then
		-- 레벨이 모자라 아직 못 입으면 노랑, 바로 입을 수 있으면 초록
		if up.level then s.up:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1) else s.up:SetVertexColor(0.44, 0.83, 0.6, 1) end
		s.up:Show()
	else
		s.up:Hide()
	end

	local isNew = C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bag, slot)
	s.new:SetShown(isNew and true or false)

	local ok, start, dur, enable = pcall(C_Container.GetContainerItemCooldown, bag, slot)
	if ok and plain(start) and plain(dur) and dur > 0 and enable ~= 0 and enable ~= false then
		s.cd:SetCooldown(start, dur)
	else
		s.cd:Clear()
	end

	b:SetAlpha(info.isFiltered and 0.18 or 1)
end

-------------------------------------------------------------------------------
-- 창
-------------------------------------------------------------------------------
local function Chip(parent, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b.text = Ink:Text(b, F.semi, 12, C.muted, "CENTER")
	b.text:SetPoint("CENTER", 0, 1)
	b.text:SetText(text)
	b:SetSize(b.text:GetStringWidth() + 14, 24)
	b.line = b:CreateTexture(nil, "OVERLAY")
	b.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	b.line:SetHeight(2)
	b.line:SetPoint("BOTTOMLEFT", 7, -2)
	b.line:SetPoint("BOTTOMRIGHT", -7, -2)
	b.line:Hide()
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self) if not self.on then self.text:SetTextColor(C.text[1], C.text[2], C.text[3]) end end)
	b:SetScript("OnLeave", function(self) if not self.on then self.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end end)
	function b:SetOn(on)
		self.on = on
		self.line:SetShown(on)
		local c = on and C.text or C.muted
		self.text:SetTextColor(c[1], c[2], c[3])
	end
	return b
end

local function IconButton(parent, label, tip, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(24, 24)
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(1, 1, 1, 0.05)
	b.text = Ink:Text(b, F.semi, 13, C.soft, "CENTER")
	b.text:SetPoint("CENTER", 0, 1)
	b.text:SetText(label)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.12)
		if tip then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText(tip)
			GameTooltip:Show()
		end
	end)
	b.base = { 1, 1, 1, 0.05 }
	b:SetScript("OnLeave", function(self)
		self.bg:SetVertexColor(unpack(self.base))
		GameTooltip:Hide()
	end)
	return b
end

-------------------------------------------------------------------------------
-- 가방 칸 (가방 창 위에 붙는 작은 줄): 가방 1~4 + 재료 가방
--  가방을 끌어다 놓거나, 가방을 집은 채로 칸을 누르면 끼운다. 칸의 가방을 끌어내면 뺀다.
-------------------------------------------------------------------------------
local BAG_SLOT = 34
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"

local function BagInv(bag)
	return C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bag)
end

local function NewBagSlot(parent, bag)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(BAG_SLOT, BAG_SLOT)
	b.bag = bag
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.skin = Ink:IconSkin(b, b.icon, true)
	b.skin.bg:SetVertexColor(1, 1, 1, 0.05)
	b.count = Ink:Text(b.skin.top, F.latinB, 10, C.text, "RIGHT")
	b.count:SetPoint("BOTTOMRIGHT", -3, 3)
	b.count:SetShadowOffset(1, -1)
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetTexture(Ink.tex.round4)
	b.hl:SetAllPoints()
	b.hl:SetVertexColor(1, 1, 1, 0.12)
	b.hl:SetBlendMode("ADD")
	local function put(self)
		local inv = BagInv(self.bag)
		if not inv then return end
		if CursorHasItem() then PutItemInBag(inv) else PickupBagFromSlot(inv) end
	end
	b:SetScript("OnClick", put)
	b:SetScript("OnReceiveDrag", put)
	b:SetScript("OnDragStart", function(self)
		local inv = BagInv(self.bag)
		if inv then PickupBagFromSlot(inv) end
	end)
	b:SetScript("OnEnter", function(self)
		local inv = BagInv(self.bag)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if inv and GetInventoryItemTexture("player", inv) then
			GameTooltip:SetInventoryItem("player", inv)
		else
			GameTooltip:SetText(self.bag == REAGENT_BAG and "재료 가방 칸" or "빈 가방 칸")
			GameTooltip:AddLine("가방을 끌어다 놓으면 끼워집니다.", 0.7, 0.7, 0.7)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

function M:BuildBagBar()
	local f = self.frame
	local list = {}
	for i = 1, NUM_BAGS do list[#list + 1] = i end
	if REAGENT_BAG and BagInv(REAGENT_BAG) then list[#list + 1] = REAGENT_BAG end
	local bar = CreateFrame("Frame", nil, f)
	bar:SetSize(PAD * 2 + #list * BAG_SLOT + (#list - 1) * 6 + 8, BAG_SLOT + 20)
	bar:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 6)
	bar:EnableMouse(true)
	bar.bg = Ink:Round(bar, "BACKGROUND", false, false)
	bar.bg:SetAllPoints()
	bar.bg:SetVertexColor(0.035, 0.04, 0.052, 0.95)
	bar.bd = Ink:Round(bar, "BORDER", false, true)
	bar.bd:SetAllPoints()
	bar.bd:SetVertexColor(1, 1, 1, 0.08)
	bar.slots = {}
	local x = PAD
	for i, bag in ipairs(list) do
		if bag == REAGENT_BAG then x = x + 8 end -- 재료 가방은 살짝 띄운다
		local b = NewBagSlot(bar, bag)
		b:SetPoint("LEFT", bar, "LEFT", x, 0)
		x = x + BAG_SLOT + 6
		bar.slots[i] = b
	end
	bar:Hide()
	f.bagBar = bar
end

function M:UpdateBagBar()
	local bar = self.frame and self.frame.bagBar
	if not bar or not bar:IsShown() then return end
	for _, b in ipairs(bar.slots) do
		local inv = BagInv(b.bag)
		local tex = inv and GetInventoryItemTexture("player", inv)
		b.icon:SetTexture(tex or EMPTY_BAG)
		b.icon:SetDesaturated(not tex)
		b.icon:SetAlpha(tex and 1 or 0.35)
		local n = tex and C_Container.GetContainerNumSlots(b.bag) or 0
		b.count:SetText(n > 0 and n or "")
	end
end

function M:ToggleBagBar(show)
	local bar = self.frame and self.frame.bagBar
	if not bar then return end
	if show == nil then show = not bar:IsShown() end
	bar:SetShown(show)
	Ink.db.bagBarOpen = show
	local btn = self.frame.bagBtn
	btn.base = show and { C.accent[1], C.accent[2], C.accent[3], 0.22 } or { 1, 1, 1, 0.05 }
	btn.bg:SetVertexColor(unpack(btn.base))
	btn.text:SetTextColor(show and C.accent[1] or C.soft[1], show and C.accent[2] or C.soft[2], show and C.accent[3] or C.soft[3])
	self:UpdateBagBar()
end

function M:Build()
	local f = CreateFrame("Frame", "InkUIBags", Ink.root)
	f:SetSize(WIDTH, 300)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	self.frame = f
	table.insert(UISpecialFrames, "InkUIBags")

	f.bg = Ink:Round(f, "BACKGROUND", false, false)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.95)
	f.bd = Ink:Round(f, "BORDER", false, true)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.08)
	f.glow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.glow:SetTexture(Ink.tex.glow)
	f.glow:SetPoint("TOPLEFT", -24, 24)
	f.glow:SetPoint("BOTTOMRIGHT", 24, -24)
	f.glow:SetVertexColor(0, 0, 0, 0.6)
	-- 위쪽 포인트 선
	f.accent = f:CreateTexture(nil, "ARTWORK")
	f.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
	f.accent:SetSize(28, 2)
	f.accent:SetPoint("TOPLEFT", PAD, -1)

	-- 제목 줄 (끌어서 이동, Shift+우클릭으로 기본 위치)
	local drag = CreateFrame("Frame", nil, f)
	drag:SetPoint("TOPLEFT")
	drag:SetPoint("TOPRIGHT")
	drag:SetHeight(42)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function() f:StartMoving() end)
	drag:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		M:SavePos()
	end)
	drag:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and IsShiftKeyDown() then
			Ink.cdb.bagPos = nil
			M:ApplyPos()
		end
	end)

	f.title = Ink:Text(f, F.bold, 15, C.text, "LEFT")
	f.title:SetPoint("TOPLEFT", PAD, -16)
	f.title:SetText("가방")
	f.slots = Ink:Text(f, F.latin, 11, C.dim, "LEFT")
	f.slots:SetPoint("BOTTOMLEFT", f.title, "BOTTOMRIGHT", 8, 1)

	f.close = IconButton(f, "×", nil, function() f:Hide() end)
	f.close:SetPoint("TOPRIGHT", -PAD + 4, -12)
	f.sort = IconButton(f, "정리", "같은 아이템 묶기 + 가방 자동 정렬", function() M:Sort() end)
	f.sort.text:SetFont(F.semi, 11, "")
	f.sort:SetWidth(56)
	f.sort:HookScript("OnMouseDown", function(self)
		self.text:SetPoint("CENTER", 0, 0)
		self.bg:SetVertexColor(1, 1, 1, 0.2)
	end)
	f.sort:HookScript("OnMouseUp", function(self)
		self.text:SetPoint("CENTER", 0, 1)
	end)
	f.sort:SetPoint("RIGHT", f.close, "LEFT", -6, 0)

	-- 검색
	local sb = CreateFrame("EditBox", nil, f)
	sb:SetSize(124, 24)
	sb:SetPoint("RIGHT", f.sort, "LEFT", -8, 0)
	sb:SetAutoFocus(false)
	sb:SetFont(F.sans, 12, "")
	sb:SetTextColor(C.text[1], C.text[2], C.text[3])
	sb:SetTextInsets(10, 8, 0, 0)
	sb.bg = Ink:Round(sb, "BACKGROUND", true, false)
	sb.bg:SetAllPoints()
	sb.bg:SetVertexColor(1, 1, 1, 0.05)
	sb.bd = Ink:Round(sb, "BORDER", true, true)
	sb.bd:SetAllPoints()
	sb.bd:SetVertexColor(1, 1, 1, 0.08)
	sb.hint = Ink:Text(sb, F.sans, 12, C.dim, "LEFT")
	sb.hint:SetPoint("LEFT", 10, 0)
	sb.hint:SetText("아이템 검색")
	sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	sb:SetScript("OnEditFocusGained", function(self) self.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.6) end)
	sb:SetScript("OnEditFocusLost", function(self) self.bd:SetVertexColor(1, 1, 1, 0.08) end)
	sb:SetScript("OnTextChanged", function(self)
		local t = self:GetText() or ""
		self.hint:SetShown(t == "")
		if C_Container.SetItemSearch then C_Container.SetItemSearch(t) end
	end)
	f.search = sb

	-- 가방 칸 열기/닫기 (가방 바꿔 끼우기)
	f.bagBtn = IconButton(f, "가방 칸", "가방 칸 보기 / 숨기기\n가방을 끌어다 놓아 바꿔 끼웁니다", function() M:ToggleBagBar() end)
	f.bagBtn.text:SetFont(F.semi, 11, "")
	f.bagBtn:SetWidth(52)
	f.bagBtn:SetPoint("RIGHT", sb, "LEFT", -6, 0)

	-- 제목 줄(끌기 영역)이 버튼을 덮지 않도록 버튼들을 위로 올린다
	drag:SetFrameLevel(f:GetFrameLevel() + 1)
	for _, w in ipairs({ f.close, f.sort, sb, f.bagBtn }) do w:SetFrameLevel(f:GetFrameLevel() + 6) end
	self:BuildBagBar()

	-- 분류 탭
	f.tabs = {}
	local prev
	for _, t in ipairs(TABS) do
		local chip = Chip(f, t.name, function() M:SetTab(t.key) end)
		if prev then chip:SetPoint("LEFT", prev, "RIGHT", 2, 0) else chip:SetPoint("TOPLEFT", PAD - 7, -48) end
		chip.key = t.key
		f.tabs[#f.tabs + 1] = chip
		prev = chip
	end
	f.div1 = f:CreateTexture(nil, "ARTWORK")
	f.div1:SetColorTexture(1, 1, 1, 0.06)
	f.div1:SetHeight(1)
	f.div1:SetPoint("TOPLEFT", PAD, -HEAD_H + 8)
	f.div1:SetPoint("TOPRIGHT", -PAD, -HEAD_H + 8)

	-- 내용 (길어지면 휠로 스크롤)
	local sc = CreateFrame("ScrollFrame", nil, f)
	sc:SetPoint("TOPLEFT", PAD, -HEAD_H)
	sc:SetPoint("BOTTOMRIGHT", -PAD, FOOT_H)
	sc:EnableMouseWheel(true)
	sc:SetScript("OnMouseWheel", function(self, d)
		local maxS = math.max(0, (self.contentH or 0) - self:GetHeight())
		self:SetVerticalScroll(math.min(maxS, math.max(0, self:GetVerticalScroll() - d * 48)))
	end)
	local content = CreateFrame("Frame", nil, sc)
	content:SetSize(WIDTH - PAD * 2, 10)
	sc:SetScrollChild(content)
	f.scroll, f.content = sc, content

	f.sections = {}
	f.subs = {}

	-- 아래 줄: 빈 칸(여기로 끌어 놓기) / 남은 칸 / 골드
	f.div2 = f:CreateTexture(nil, "ARTWORK")
	f.div2:SetColorTexture(1, 1, 1, 0.06)
	f.div2:SetHeight(1)
	f.div2:SetPoint("BOTTOMLEFT", PAD, FOOT_H - 2)
	f.div2:SetPoint("BOTTOMRIGHT", -PAD, FOOT_H - 2)
	f.freeHolder = NewHolder(f)
	f.freeHolder:SetPoint("BOTTOMLEFT", PAD, 10)
	f.freeLabel = Ink:Text(f, F.semi, 11, C.soft, "LEFT")
	f.freeLabel:SetPoint("TOPLEFT", f.freeHolder, "TOPRIGHT", 10, -3)
	f.freeLabel:SetText("빈 칸")
	f.freeCount = Ink:Text(f, F.latin, 11, C.muted, "LEFT")
	f.freeCount:SetPoint("TOPLEFT", f.freeLabel, "BOTTOMLEFT", 0, -3)
	f.hint = Ink:Text(f, F.sans, 10, C.dim, "CENTER")
	f.hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 22)
	f.hint:SetText("휠 클릭으로 고정 / 해제")
	f.gold = Ink:Text(f, F.latin, 12, C.text, "RIGHT")
	f.gold:SetPoint("BOTTOMRIGHT", -PAD, 22)

	f:SetScript("OnShow", function()
		M:Refresh()
		if Ink.db.bagBarOpen then M:ToggleBagBar(true) end
		if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
	end)
	f:SetScript("OnHide", function()
		if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end
		f.search:ClearFocus()
		-- 블리자드 쪽 "열림" 상태도 같이 닫아서 다음 B 키가 한 번에 열리게
		if M:BlizzardOpen() then CloseAllBags() end
		if C_NewItems and C_NewItems.ClearAll then pcall(C_NewItems.ClearAll) end
	end)

	self:ApplyPos()
	self:SetTab(Ink.db.bagTab or "all")
end

-------------------------------------------------------------------------------
-- 위치
-------------------------------------------------------------------------------
function M:SavePos()
	local f, root = self.frame, Ink.root
	local l, t = f:GetLeft(), f:GetTop()
	if not (l and t) then return end
	Ink.cdb.bagPos = { l - root:GetLeft(), t - root:GetTop() }
	Ink.db.bagPos = { Ink.cdb.bagPos[1], Ink.cdb.bagPos[2] }
	self:ApplyPos()
end

function M:ApplyPos()
	local f = self.frame
	f:ClearAllPoints()
	local p = Ink.cdb and Ink.cdb.bagPos
	if p then
		f:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", p[1], p[2])
	else
		f:SetPoint("BOTTOMRIGHT", Ink.root, "BOTTOMRIGHT", -24, 64)
	end
end

-------------------------------------------------------------------------------
-- 배치
-------------------------------------------------------------------------------
function M:SetTab(key)
	Ink.db.bagTab = key
	self.tab = key
	for _, chip in ipairs(self.frame.tabs) do chip:SetOn(chip.key == key) end
	self.frame.scroll:SetVerticalScroll(0)
	if self.frame:IsShown() then self:Layout() end
end

local function Section(f, i)
	local s = f.sections[i]
	if s then return s end
	s = CreateFrame("Frame", nil, f.content)
	s:SetSize(WIDTH - PAD * 2, SEC_H)
	s.name = Ink:Text(s, F.semi, 12, C.soft, "LEFT")
	s.name:SetPoint("LEFT", 0, 0)
	s.count = Ink:Text(s, F.latin, 10, C.dim, "LEFT")
	s.count:SetPoint("LEFT", s.name, "RIGHT", 6, -1)
	s.line = s:CreateTexture(nil, "ARTWORK")
	s.line:SetColorTexture(1, 1, 1, 0.05)
	s.line:SetHeight(1)
	s.line:SetPoint("LEFT", s.count, "RIGHT", 10, 1)
	s.line:SetPoint("RIGHT", 0, 0)
	f.sections[i] = s
	return s
end

local function SubLabel(f, i)
	local l = f.subs[i]
	if l then return l end
	l = CreateFrame("Frame", nil, f.content)
	l:SetSize(200, 14)
	l.dot = l:CreateTexture(nil, "ARTWORK")
	l.dot:SetColorTexture(1, 1, 1, 0.25)
	l.dot:SetSize(3, 3)
	l.dot:SetPoint("LEFT", 0, 0)
	l.text = Ink:Text(l, F.sans, 10, C.muted, "LEFT")
	l.text:SetPoint("LEFT", l.dot, "RIGHT", 6, 0)
	l.count = Ink:Text(l, F.latin, 9, C.dim, "LEFT")
	l.count:SetPoint("LEFT", l.text, "RIGHT", 5, 0)
	f.subs[i] = l
	return l
end

local function Gather()
	local byCat = {}
	for _, c in ipairs(CATS) do byCat[c.key] = {} end
	local firstFree, free, total = nil, 0, 0
	for _, bag in ipairs(BagList()) do
		local n = C_Container.GetContainerNumSlots(bag) or 0
		local bagFree = 0
		for slot = 1, n do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(info.itemID)
				local it = {
					bag = bag, slot = slot, itemID = info.itemID, quality = info.quality or 1,
					count = info.stackCount or 1, classID = classID, subID = subID,
				}
				it.cat = Category(info.itemID, it.quality, bag)
				it.subOrder, it.subName = SubGroup(it.cat, classID, subID)
				table.insert(byCat[it.cat], it)
			elseif bag ~= REAGENT_BAG then
				bagFree = bagFree + 1
				if not firstFree then firstFree = { bag = bag, slot = slot } end
			end
		end
		if bag ~= REAGENT_BAG then
			free = free + bagFree
			total = total + n
		end
	end
	for _, list in pairs(byCat) do table.sort(list, SortItems) end
	return byCat, firstFree, free, total
end

function M:Layout()
	local f = self.frame
	if not f then return end
	if InCombatLockdown() then
		self.dirty = true
		self:Paint()
		return
	end
	self.dirty = nil
	local byCat, firstFree, free, total = Gather()

	-- 칸 모으기 (부족하면 만든다 - 전투 밖에서만)
	for _, h in ipairs(active) do h:Hide(); h.bag = nil end
	wipe(active)
	local y, used, secUsed, subUsed = 0, 0, 0, 0
	local stride = SLOT + GAP
	for _, cat in ipairs(CATS) do
		local list = byCat[cat.key]
		if (self.tab == "all" or self.tab == cat.key) and #list > 0 then
			secUsed = secUsed + 1
			local s = Section(f, secUsed)
			s:ClearAllPoints()
			s:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
			s.name:SetText(cat.name)
			local nc = (cat.key == "pin") and C.accent or C.soft
			s.name:SetTextColor(nc[1], nc[2], nc[3])
			s.count:SetText(#list)
			s:Show()
			y = y - SEC_H
			-- 세부 분류가 2개 이상일 때만 작은 제목을 붙인다
			local subs, lastSub = 0, nil
			for _, it in ipairs(list) do
				if it.subName ~= lastSub then subs = subs + 1; lastSub = it.subName end
			end
			local showSubs = subs > 1
			local i, cur = 0, nil
			for _, it in ipairs(list) do
				if showSubs and it.subName ~= cur then
					cur = it.subName
					if i > 0 then y = y - math.ceil(i / COLS) * stride - 4 end
					i = 0
					subUsed = subUsed + 1
					local lb = SubLabel(f, subUsed)
					lb:ClearAllPoints()
					lb:SetPoint("TOPLEFT", f.content, "TOPLEFT", 1, y)
					local n = 0
					for _, o in ipairs(list) do if o.subName == cur then n = n + 1 end end
					lb.text:SetText(cur)
					lb.count:SetText(n)
					lb:Show()
					y = y - 18
				end
				i = i + 1
				used = used + 1
				local h = holders[used]
				if not h then
					h = NewHolder(f.content)
					holders[used] = h
				end
				local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", f.content, "TOPLEFT", col * stride, y - row * stride)
				h.bag, h.slot, h.cat = it.bag, it.slot, cat.key
				h:SetID(it.bag)
				h.btn:SetID(it.slot)
				h:Show()
				h.btn:Show() -- 템플릿 버튼은 숨겨진 채로 만들어진다
				active[#active + 1] = h
			end
			y = y - math.ceil(i / COLS) * stride - 8
		end
	end
	for i = secUsed + 1, #f.sections do f.sections[i]:Hide() end
	for i = subUsed + 1, #f.subs do f.subs[i]:Hide() end

	-- 빈 칸 버튼: 첫 번째 빈 자리 (여기로 끌어다 놓으면 들어간다)
	local fh = f.freeHolder
	if firstFree then
		fh.bag, fh.slot, fh.cat = firstFree.bag, firstFree.slot, nil
		fh:SetID(firstFree.bag)
		fh.btn:SetID(firstFree.slot)
		fh.btn:EnableMouse(true)
	else
		fh.bag = nil
		fh.btn:EnableMouse(false)
	end
	fh:Show()
	fh.btn:Show()
	self.free, self.total = free, total

	local contentH = math.max(-y, 40)
	if secUsed == 0 then contentH = 40 end
	f.content:SetHeight(contentH)
	f.scroll.contentH = contentH
	local view = math.min(contentH, MAX_VIEW)
	f:SetHeight(HEAD_H + view + FOOT_H)
	local maxS = math.max(0, contentH - view)
	if f.scroll:GetVerticalScroll() > maxS then f.scroll:SetVerticalScroll(maxS) end

	if not f.empty then
		f.empty = Ink:Text(f.content, F.sans, 12, C.dim, "CENTER")
		f.empty:SetPoint("TOP", f.content, "TOP", 0, -12)
		f.empty:SetText("이 분류에는 아이템이 없어요")
	end
	f.empty:SetShown(secUsed == 0)

	self:Paint()
end

-- 배치는 그대로 두고 모양만 새로 (전투 중에도 가능)
function M:Paint()
	local f = self.frame
	if not f or not f:IsShown() then return end
	for _, h in ipairs(active) do Paint(h) end
	local fh = f.freeHolder
	local s = skin[fh.btn]
	if fh.bag then Paint(fh) else
		SetTex(fh.btn, nil)
		SetCount(fh.btn, 0)
	end
	-- 빈 칸 버튼 안에 남은 칸 수
	local free, total = 0, 0
	for b = 0, NUM_BAGS do
		free = free + (C_Container.GetContainerNumFreeSlots(b) or 0)
		total = total + (C_Container.GetContainerNumSlots(b) or 0)
	end
	s.free:SetText(free)
	s.free:SetShown(not (fh.bag and C_Container.GetContainerItemInfo(fh.bag, fh.slot)))
	s.free:SetTextColor((free == 0 and C.red or C.soft)[1], (free == 0 and C.red or C.soft)[2], (free == 0 and C.red or C.soft)[3])
	f.freeCount:SetText(string.format("%d / %d", free, total))
	f.slots:SetText(string.format("%d / %d", total - free, total))
	f.gold:SetText(GetMoneyString and GetMoneyString(GetMoney(), true) or tostring(GetMoney()))
end

function M:Refresh()
	if not self.frame or not self.frame:IsShown() then return end
	self:Layout()
end

-- 지연 갱신 (가방 이벤트는 한 번에 여러 개 온다)
function M:Schedule()
	if self.pending then return end
	self.pending = true
	C_Timer.After(0.05, function()
		self.pending = nil
		self:Refresh()
	end)
end

-------------------------------------------------------------------------------
-- 정리 버튼: 누르면 "정리 중" → 가방 변화가 끝나면 "완료" 를 잠깐 보여준다
-------------------------------------------------------------------------------
function M:SortState(state)
	local b = self.frame.sort
	self.sortState = state
	if b.timer then b.timer:Cancel(); b.timer = nil end
	if state == "busy" then
		b.text:SetText("정리 중")
		b.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		b.base = { C.accent[1], C.accent[2], C.accent[3], 0.18 }
		b.bg:SetVertexColor(unpack(b.base))
		-- 아무 변화가 없어도 3초 뒤엔 완료로
		b.timer = C_Timer.NewTimer(3, function() M:SortState("done") end)
	elseif state == "done" then
		b.text:SetText("완료")
		b.text:SetTextColor(C.green[1], C.green[2], C.green[3])
		b.base = { C.green[1], C.green[2], C.green[3], 0.16 }
		b.bg:SetVertexColor(unpack(b.base))
		local c = self.frame.content
		c:SetAlpha(0.35)
		local t0 = GetTime()
		Ink:Loop("bagFade", function()
			local a = math.min(1, 0.35 + (GetTime() - t0) * 2.6)
			c:SetAlpha(a)
			if a >= 1 then Ink:Loop("bagFade", nil) end
		end)
		b.timer = C_Timer.NewTimer(1.4, function() M:SortState(nil) end)
	elseif state == "combat" then
		b.text:SetText("전투 중")
		b.text:SetTextColor(C.red[1], C.red[2], C.red[3])
		b.base = { C.red[1], C.red[2], C.red[3], 0.16 }
		b.bg:SetVertexColor(unpack(b.base))
		b.timer = C_Timer.NewTimer(1.4, function() M:SortState(nil) end)
	else
		b.text:SetText("정리")
		b.text:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
		b.base = { 1, 1, 1, 0.05 }
		b.bg:SetVertexColor(unpack(b.base))
	end
end

function M:Sort()
	if InCombatLockdown() then self:SortState("combat") return end
	if self.sortState == "busy" then return end
	self:SortState("busy")
	if C_Container.SortBags then C_Container.SortBags() end
end

-------------------------------------------------------------------------------
-- 고정
-------------------------------------------------------------------------------
function M:TogglePin(btn)
	local bag, slot = btn:GetParent():GetID(), btn:GetID()
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info or not info.itemID then return end
	local id = info.itemID
	if id == HEARTH then return end
	local pins = Pins()
	if pins[id] then
		pins[id] = nil
	else
		local mx = 0
		for _, o in pairs(pins) do if o > mx then mx = o end end
		pins[id] = mx + 1
	end
	self:Refresh()
end

-------------------------------------------------------------------------------
-- 블리자드 가방과 열고 닫기 맞추기
--  B 키 / 가방 버튼 / 상점·우편함 자동 열기 등은 블리자드 가방 함수를 거친다.
--  블리자드 가방 창은 숨김 부모로 옮겨 안 보이게 하고, "열림" 상태만 따라간다.
-------------------------------------------------------------------------------
function M:BlizzardOpen()
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return true end
	for i = 1, 13 do
		local fr = _G["ContainerFrame" .. i]
		if fr and fr:IsShown() then return true end
	end
	return false
end

-- user = B 키 / 가방 버튼처럼 사람이 직접 연 / 닫은 것 (Toggle·Open)
-- 그 밖의 "모든 가방 닫기"(초보자 튜토리얼이 장비 착용 직후 부르는 것 등)는
-- 장비를 입거나 아이템을 옮긴 직후 1초 동안은 무시한다.
function M:Sync(user)
	if user then self.syncUser = true end
	if self.syncing then return end
	self.syncing = true
	C_Timer.After(0, function()
		self.syncing = nil
		local byUser = self.syncUser
		self.syncUser = nil
		local want = self:BlizzardOpen()
		local shown = self.frame:IsShown()
		if want == shown then return end
		if not want and shown and not byUser and GetTime() < (self.equipGuard or 0) then
			-- 가방은 그대로 두고, 블리자드 쪽 "열림" 상태도 되돌려 다음 B 키가 맞게 동작하게
			self.restoring = true
			pcall(OpenAllBags)
			self.restoring = nil
			return
		end
		self.frame:SetShown(want)
	end)
end

-- 아이템 툴팁: 퀘스트에 필요한 아이템이면 어느 퀘스트에 몇 개 필요한지 (팔기 전에 보이게)
function M:HookNeedTooltip()
	if self.needTip or not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType) then return end
	self.needTip = true
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		pcall(function()
			if not tt.AddLine then return end
			local id = data and plain(data.id)
			local name = type(id) == "number" and C_Item.GetItemInfo(id)
			local list = name and NeedOf(name)
			if not list then return end
			tt:AddLine(" ")
			tt:AddLine("퀘스트에 필요해요 · 보고하기 전까지 팔지 마세요", C.gold[1], C.gold[2], C.gold[3])
			for i, e in ipairs(list) do
				if i > 4 then break end
				local full = e.want > 0 and e.have >= e.want
				tt:AddDoubleLine("  " .. e.title, e.want > 0 and (e.have .. " / " .. e.want) or "",
					0.85, 0.86, 0.88, full and 0.44 or 1, full and 0.83 or 0.96, full and 0.55 or 0.41)
			end
		end)
	end)
end

function M:Init()
	self:HookNeedTooltip()
	if Ink.db.bags == false then return end
	self:Build()

	if ContainerFrameCombinedBags then Ink:Disable(ContainerFrameCombinedBags, true) end
	for i = 1, 13 do
		if _G["ContainerFrame" .. i] then Ink:Disable(_G["ContainerFrame" .. i], true) end
	end
	for _, fn in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag", "OpenAllBags", "OpenBackpack", "OpenBag" }) do
		if _G[fn] then hooksecurefunc(fn, function() if not M.restoring then M:Sync(true) end end) end
	end
	for _, fn in ipairs({ "CloseAllBags", "CloseBackpack", "CloseBag" }) do
		if _G[fn] then hooksecurefunc(fn, function() M:Sync() end) end
	end

	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "BAG_CONTAINER_UPDATE", "BAG_UPDATE_DELAYED", "BAG_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
		"INVENTORY_SEARCH_UPDATE", "BAG_NEW_ITEMS_UPDATED", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED",
		"QUEST_ACCEPTED", "UNIT_QUEST_LOG_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "QUEST_LOG_UPDATE", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	e:SetScript("OnEvent", function(_, event)
		-- 퀘스트가 바뀌면 "퀘스트에 필요한 아이템" 목록을 다시 읽는다
		if event == "QUEST_ACCEPTED" or event == "UNIT_QUEST_LOG_CHANGED" or event == "QUEST_LOG_UPDATE" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
			needDirty = true
			if event == "QUEST_LOG_UPDATE" then
				if M.frame:IsShown() then M:Paint() end
				return
			end
		end
		-- 장비 착용 / 아이템 이동 직후엔 자동 "가방 닫기"를 잠깐 막는다
		if event == "ITEM_LOCK_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
			M.equipGuard = GetTime() + 1
			if event == "PLAYER_EQUIPMENT_CHANGED" then return end
		end
		if not M.frame:IsShown() then
			if event == "PLAYER_REGEN_ENABLED" then M.dirty = nil end
			return
		end
		if event == "BAG_CONTAINER_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
			M:UpdateBagBar()
			if event == "BAG_CONTAINER_UPDATE" then M:Schedule() return end
		end
		if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
			M:Schedule()
			-- 정리 중이면 가방 변화가 잠잠해진 뒤 완료 표시
			if M.sortState == "busy" and event == "BAG_UPDATE_DELAYED" then
				local b = M.frame.sort
				if b.timer then b.timer:Cancel() end
				b.timer = C_Timer.NewTimer(0.6, function() M:SortState("done") end)
			end
		elseif event == "PLAYER_REGEN_ENABLED" then
			if M.dirty then M:Layout() end
		else
			M:Paint()
		end
	end)

	-- 미리 칸을 만들어 둔다 (전투 중엔 만들 수 없어서)
	C_Timer.After(2, function()
		if InCombatLockdown() then return end
		local n = 0
		for _, bag in ipairs(BagList()) do n = n + (C_Container.GetContainerNumSlots(bag) or 0) end
		for i = #holders + 1, n do holders[i] = NewHolder(M.frame.content) end
	end)
end
