-- FOA UI · 지도 밝히기 (포에버)
--  안 가 본 곳도 지역 지도 그림을 그대로 보여 주되 살짝 어둡게. 가 본 곳은 게임이 원래대로 밝게 그린다.
--  자료: 게임 파일의 지도 덮개 표 (MapRevealData.lua)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("MapReveal")

local FOREVER = (function() local b = select(4, GetBuildInfo()) or 0 return b >= 16001 and b < 20000 end)()
local DIM = { 0.6, 0.6, 0.66 }   -- 안 가 본 곳 색 (살짝 어둡고 차갑게)

local function Canvas()
	local wm = WorldMapFrame
	return wm and wm.ScrollContainer and wm.ScrollContainer.Child
end

function M:Tex(i)
	local t = self.texs[i]
	if not t then
		t = self.frame:CreateTexture(nil, "ARTWORK", nil, -1)
		self.texs[i] = t
	end
	return t
end

function M:Refresh()
	local wm, cv = WorldMapFrame, Canvas()
	if not (self.frame and wm and cv and wm:IsShown()) then return end
	local n = 0
	local mapID = wm:GetMapID()
	local data
	if Ink.db.mapReveal ~= false and mapID and ns.MAP_REVEAL and C_Map.GetMapArtID then
		local ok, art = pcall(C_Map.GetMapArtID, mapID)
		data = ok and art and ns.MAP_REVEAL[art]
	end
	if data then
		local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
		local L = layers and layers[1]
		local tileW, tileH = (L and L.tileWidth) or 256, (L and L.tileHeight) or 256
		local k = (L and L.layerWidth and L.layerWidth > 0) and (cv:GetWidth() / L.layerWidth) or 1
		-- 가 본 곳 (게임이 이미 밝게 그리는 덮개)
		local explored = {}
		if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
			local ok, list = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
			for _, e in ipairs(ok and list or {}) do
				explored[e.textureWidth .. ":" .. e.textureHeight .. ":" .. e.offsetX .. ":" .. e.offsetY] = true
			end
		end
		-- 게임 덮개와 같은 높이에 (기본 지도 위 · 다른 표시 아래)
		local lvl = cv:GetFrameLevel() + 1
		if wm.GetPinFrameLevelsManager then
			local ok, v = pcall(function() return wm:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_EXPLORATION") end)
			if ok and v then lvl = v end
		end
		self.frame:SetFrameLevel(lvl)
		for i = 1, #data, 5 do
			local w, h, x, y, ids = data[i], data[i + 1], data[i + 2], data[i + 3], data[i + 4]
			if not explored[w .. ":" .. h .. ":" .. x .. ":" .. y] then
				local fids = {}
				for id in ids:gmatch("%d+") do fids[#fids + 1] = tonumber(id) end
				local cols, rows = math.ceil(w / tileW), math.ceil(h / tileH)
				for r = 1, rows do
					local ph = (r < rows) and tileH or (h - tileH * (rows - 1))
					local fh = 16
					while fh < ph do fh = fh * 2 end
					for c = 1, cols do
						local fid = fids[(r - 1) * cols + c]
						if fid then
							local pw = (c < cols) and tileW or (w - tileW * (cols - 1))
							local fw = 16
							while fw < pw do fw = fw * 2 end
							n = n + 1
							local t = self:Tex(n)
							t:SetTexture(fid, nil, nil, "TRILINEAR")
							t:SetTexCoord(0, pw / fw, 0, ph / fh)
							t:SetSize(pw * k, ph * k)
							t:ClearAllPoints()
							t:SetPoint("TOPLEFT", cv, "TOPLEFT", (x + tileW * (c - 1)) * k, -(y + tileH * (r - 1)) * k)
							t:SetVertexColor(DIM[1], DIM[2], DIM[3], 1)
							if t.SetDesaturation then t:SetDesaturation(0.25) end
							t:Show()
						end
					end
				end
			end
		end
	end
	for i = n + 1, #self.texs do self.texs[i]:Hide() end
end

function M:Hook()
	local wm, cv = WorldMapFrame, Canvas()
	if not (wm and cv) or self.hooked then return end
	self.hooked = true
	self.frame = CreateFrame("Frame", nil, cv)
	self.frame:SetAllPoints(cv)
	self.texs = {}
	wm:HookScript("OnShow", function() C_Timer.After(0, function() pcall(M.Refresh, M) end) end)
	if wm.OnMapChanged then hooksecurefunc(wm, "OnMapChanged", function() pcall(M.Refresh, M) end) end
end

function M:Init()
	if not FOREVER or not ns.MAP_REVEAL then return end
	pcall(self.Hook, self)
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "ADDON_LOADED", "MAP_EXPLORATION_UPDATED", "UI_INFO_MESSAGE" }) do pcall(e.RegisterEvent, e, ev) end
	e:SetScript("OnEvent", function(_, event)
		if event == "ADDON_LOADED" then pcall(M.Hook, M) return end
		if WorldMapFrame and WorldMapFrame:IsShown() then C_Timer.After(0.2, function() pcall(M.Refresh, M) end) end
	end)
end
