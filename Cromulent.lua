--[[
--	Credit to ckknight for originally writing Cartographer_ZoneInfo
--]]
Cromulent = LibStub("AceAddon-3.0"):NewAddon("Cromulent", "AceHook-3.0")
local Cromulent, self = Cromulent, Cromulent
-- Perhaps add toggling of the different infos later.
--[[local defaults = {
	profile = {
		zonelevels = true,
		instances = true,
		fishing = true,
	},
}]]
local L = LibStub("AceLocale-3.0"):GetLocale("Cromulent")
local T = LibStub("LibTourist-3.0")
local table_concat = table.concat
local table_wipe = table.wipe
local GetCurrentMapContinent = GetCurrentMapContinent
local GetProfessionInfo = GetProfessionInfo
local GetMapContinents = GetMapContinents
local GetProfessions = GetProfessions
local COLOUR_RED = "ff0000"
local COLOUR_GREEN = "00ff00"
local COLOUR_YELLOW = "ffff00"

-- World map IDs. These are located in FrameXML/WorldMapFrame.lua
local WORLDMAP_AZEROTH_ID = WORLDMAP_AZEROTH_ID
local WORLDMAP_COSMIC_ID = WORLDMAP_COSMIC_ID
local WORLDMAP_DRAENOR_ID = WORLDMAP_DRAENOR_ID
local WORLDMAP_MAELSTROM_ID = WORLDMAP_MAELSTROM_ID
local WORLDMAP_OUTLAND_ID = WORLDMAP_OUTLAND_ID

-- IDs that don't have a constant in FrameXML/WorldMapFrame.lua
local WORLDMAP_BROKENISLES_ID = 8
local WORLDMAP_EASTERNKINGDOMS_ID = 2
local WORLDMAP_KALIMDOR_ID = 1

-- Store a table of continent names during OnEnable.
local continentNames = nil

function Cromulent:OnEnable()
	if not self.frame then
		self.frame = CreateFrame("Frame", nil, WorldMapFrame)

		self.frame.text = WorldMapFrameAreaFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		local text = self.frame.text
		local font, size = GameFontHighlightLarge:GetFont()
		text:SetFont(font, size, "OUTLINE")
		text:SetPoint("TOP", WorldMapFrameAreaDescription, "BOTTOM", 0, -32)
		text:SetWidth(1024)
	end

	if not continentNames then
		local continents = { GetMapContinents() }
		continentNames = {}

		for i = 1, #continents, 2 do
			name = continents[i + 1]
			continentNames[name] = true
		end
	end

	self.frame:Show()
	self:SecureHookScript(WorldMapButton, "OnUpdate", "WorldMapButton_OnUpdate")
end

function Cromulent:OnDisable()
	self.frame:Hide()
	WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)
end

local lastZone	-- So we don't keep processing zones in every Update
local t = {}	-- Text to display stored here

function Cromulent:WorldMapButton_OnUpdate()
	if not self.frame then
		return
	end

	if not WorldMapDetailFrame:IsShown() or not WorldMapFrameAreaLabel:IsShown() then
		self.frame.text:SetText("")
		lastZone = nil
		return
	end

	-- Under Attack is used during events like the Naxxramas opening event.
	local underAttack = false
	local zone = WorldMapFrameAreaLabel:GetText()
	if zone then
		zone = WorldMapFrameAreaLabel:GetText():gsub("|cff.+$", "")
		if WorldMapFrameAreaDescription:GetText() then
			underAttack = true
			zone = WorldMapFrameAreaDescription:GetText():gsub("|cff.+$", "")
		end
	end

	-- Set the text to white and hide the zone info if we're on the Azeroth
	-- continent map.
	local currentMapContinent = GetCurrentMapContinent()
	if currentMapContinent == WORLDMAP_AZEROTH_ID then
		if continentNames[zone] then
			WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)
			self.frame.text:SetText("")
			return
		end
	else
		-- Get a proper lookup name for the zone based on the
		-- continent.
		zone = T:GetUniqueEnglishZoneNameForLookup(zone, currentMapContinent)
	end

	-- If we didn't find a zone, or the zone isn't an instance or a real
	-- zone steal the zone name from the WorldMapFrame
	if not zone or not T:IsZoneOrInstance(zone) then
		zone = WorldMapFrame.areaName
	end

	WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)

	-- Now we can do some real work if the zone is a real zone and/or has
	-- instances
	if zone and (T:IsZoneOrInstance(zone) or T:DoesZoneHaveInstances(zone)) then
		-- For PvP servers, perhaps?  I haven't seen this do anything
		-- on my home (PvE) server when a city was attacked.
		if not underAttack then
			WorldMapFrameAreaLabel:SetTextColor(T:GetFactionColor(zone))
			WorldMapFrameAreaDescription:SetTextColor(1, 1, 1)
		else
			WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)
			WorldMapFrameAreaDescription:SetTextColor(T:GetFactionColor(zone))
		end

		--local low, high = T:GetLevel(zone)
		local minFish = T:GetFishingLevel(zone)
		local fishingSkillText

		-- Fishing levels!
		if minFish then
			-- Get fishing index
			-- prof1, prof2, archaeology, fishing, cooking, firstaid
			local _, _, _, fishingIdx, _, _ = GetProfessions()

			-- Find our current fishing rank
			if fishingIdx then
				local skillName, _, skillRank = GetProfessionInfo(fishingIdx)
				local numColour = COLOUR_RED
				if minFish < skillRank then
					numColour = COLOUR_GREEN
				end
				fishingSkillText = ("|cff%s%s|r |cff%s[%d]|r"):format(COLOUR_YELLOW, skillName, numColour, minFish)
			end
		end

		-- List the instances in the zone if it has any.
		if T:DoesZoneHaveInstances(zone) then
			if lastZone ~= zone then
				-- Set lastZone so we don't keep grabbing this info in every Update.
				lastZone = zone
				t[#t + 1] = ("|cffffff00%s:|r"):format(L["Instances"])

				-- Iterate over the instance list and insert them into t[]
				for instance in T:IterateZoneInstances(zone) do
					local complex = T:GetComplex(instance)
					local low, high = T:GetLevel(instance)
					local r1, g1, b1 = T:GetFactionColor(instance)
					local r2, g2, b2 = T:GetLevelColor(instance)
					local groupSize = T:GetInstanceGroupSize(instance)
					local name = instance

					if complex then
						name = complex .. " - " .. instance
					end

					if low == high then
						if groupSize > 0 then
							t[#t + 1] = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r " .. L["%d-man"]):format(r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, high, groupSize)
						else
							t[#t + 1] = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r"):format(r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, high)
						end
					else
						if groupSize > 0 then
							t[#t + 1] = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r " .. L["%d-man"]):format(r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, low, high, groupSize)
						else
							t[#t + 1] = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r"):format(r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, low, high)
						end
					end
				end

				-- Add the fishing info to t[] if it exists.
				if minFish and fishingSkillText then
					t[#t + 1] = fishingSkillText
				end

				-- OK, add all of the info from t[] into the zone info!
				self.frame.text:SetText(table_concat(t, "\n"))
				-- Reset t[], ready for the next run.
				table_wipe(t)
			end
		else
			-- If the zone has no instances
			-- Just set the fishing level text and be on our way.
			if minFish and fishingSkillText then
				self.frame.text:SetText(fishingSkillText)
			else
				self.frame.text:SetText("")
			end
			lastZone = nil
		end
	elseif not zone then
		-- If we couldn't identify a valid zone at all, just blank it out.
		lastZone = nil
		self.frame.text:SetText("")
	end
end
