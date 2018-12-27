local F, C, L = unpack(select(2, ...))
local module = F:GetModule("misc")

local format, pairs = string.format, pairs
local min, mod, floor = math.min, mod, math.floor
local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL
local MAX_REPUTATION_REACTION = MAX_REPUTATION_REACTION
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local NUM_FACTIONS_DISPLAYED = NUM_FACTIONS_DISPLAYED
local REPUTATION_PROGRESS_FORMAT = REPUTATION_PROGRESS_FORMAT


local function UpdateBar(bar)
	local rest = bar.restBar
	if rest then rest:Hide() end

	if UnitLevel("player") < MAX_PLAYER_LEVEL then
		local xp, mxp, rxp = UnitXP("player"), UnitXPMax("player"), GetXPExhaustion()
		bar:SetStatusBarColor(79/250, 167/250, 74/250)
		bar:SetMinMaxValues(0, mxp)
		bar:SetValue(xp)
		bar:Show()
		if rxp then
			rest:SetMinMaxValues(0, mxp)
			rest:SetValue(min(xp + rxp, mxp))
			rest:Show()
		end
		if IsXPUserDisabled() then bar:SetStatusBarColor(.7, 0, 0) end
	elseif C_AzeriteItem.HasActiveAzeriteItem() then
		local azeriteItemLocation = C_AzeriteItem.FindActiveAzeriteItem()
		local xp, totalLevelXP = C_AzeriteItem.GetAzeriteItemXPInfo(azeriteItemLocation)
		bar:SetStatusBarColor(.9, .8, .6)
		bar:SetMinMaxValues(0, totalLevelXP)
		bar:SetValue(xp)
		bar:Show()
	else
		bar:Hide()
	end

end

local function UpdateTooltip(bar)
	GameTooltip:SetOwner(Minimap, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -5, -33)
	
	if UnitLevel("player") < MAX_PLAYER_LEVEL then
		GameTooltip:AddLine(LEVEL.." "..UnitLevel("player"), C.r, C.g, C.b)

		local xp, mxp, rxp = UnitXP("player"), UnitXPMax("player"), GetXPExhaustion()
		GameTooltip:AddDoubleLine(XP..":", xp.."/"..mxp.." ("..floor(xp/mxp*100).."%)", 1, 1, 1, 1,1,1)
		if rxp then
			GameTooltip:AddDoubleLine(TUTORIAL_TITLE26..":", "+"..rxp.." ("..floor(rxp/mxp*100).."%)", 1, 1, 1, 1,1,1)
		end
		if IsXPUserDisabled() then GameTooltip:AddLine("|cffff0000"..XP..LOCKED) end
		GameTooltip:AddLine(" ")
	end

	if C_AzeriteItem.HasActiveAzeriteItem() then
		local azeriteItemLocation = C_AzeriteItem.FindActiveAzeriteItem()
		local azeriteItem = Item:CreateFromItemLocation(azeriteItemLocation)
		local azeriteItemName = azeriteItem:GetItemName()
		local xp, totalLevelXP = C_AzeriteItem.GetAzeriteItemXPInfo(C_AzeriteItem.FindActiveAzeriteItem())
		local currentLevel = C_AzeriteItem.GetPowerLevel(azeriteItemLocation)
		GameTooltip:AddLine(azeriteItemName.." ("..format(SPELLBOOK_AVAILABLE_AT, currentLevel)..")", 247/255, 225/255, 171/255)
		GameTooltip:AddDoubleLine(ARTIFACT_POWER, F.Numb(xp).."/"..F.Numb(totalLevelXP).." ("..floor(xp/totalLevelXP*100).."%)", 1, 1, 1, 1,1,1)
		GameTooltip:AddLine(" ")
	end

	if GetWatchedFactionInfo() then
		local name, standing, barMin, barMax, value, factionID = GetWatchedFactionInfo()
		local friendID, _, _, _, _, _, friendTextLevel, _, nextFriendThreshold = GetFriendshipReputation(factionID)
		local currentRank, maxRank = GetFriendshipReputationRanks(friendID)
		local standingtext
		if friendID then
			if maxRank > 0 then
				name = name.." ("..currentRank.." / "..maxRank..")"
			end
			if not nextFriendThreshold then
				value = barMax - 1
			end
			standingtext = friendTextLevel
		else
			if standing == MAX_REPUTATION_REACTION then
				barMax = barMin + 1e3
				value = barMax - 1
			end
			standingtext = GetText("FACTION_STANDING_LABEL"..standing, UnitSex("player"))
		end
		GameTooltip:AddLine(name, 62/250, 175/250, 227/250)
		GameTooltip:AddDoubleLine(standingtext, value - barMin.."/"..barMax - barMin.." ("..floor((value - barMin)/(barMax - barMin)*100).."%)", 1,1,1, 1,1,1)
		
		if C_Reputation.IsFactionParagon(factionID) then
			local currentValue, threshold = C_Reputation.GetFactionParagonInfo(factionID)
			local paraCount = floor(currentValue/threshold)
			currentValue = mod(currentValue, threshold)
			GameTooltip:AddDoubleLine(L["ParagonRep"]..paraCount, currentValue.."/"..threshold.." ("..floor(currentValue/threshold*100).."%)", 131/250, 239/250, 131/250, 1,1,1)
			GameTooltip:AddLine(" ")
		else
			GameTooltip:AddLine(" ")
		end
	end

	--if IsWatchingHonorAsXP() then
	if UnitLevel("player") == MAX_PLAYER_LEVEL then
		local current, barMax, level = UnitHonor("player"), UnitHonorMax("player"), UnitHonorLevel("player")
		GameTooltip:AddLine(HONOR, 177/250, 19/250, 0)
		GameTooltip:AddDoubleLine(LEVEL.." "..level, current.."/"..barMax, 1, 1, 1, 1,1,1)
	end

	GameTooltip:Show()
end

function module:SetupScript(bar)
	bar.eventList = {
		"PLAYER_XP_UPDATE",
		"PLAYER_LEVEL_UP",
		"UPDATE_EXHAUSTION",
		"PLAYER_ENTERING_WORLD",
		"UPDATE_FACTION",
		"ARTIFACT_XP_UPDATE",
		"UNIT_INVENTORY_CHANGED",
		"ENABLE_XP_GAIN",
		"DISABLE_XP_GAIN",
		"AZERITE_ITEM_EXPERIENCE_CHANGED",
		"HONOR_XP_UPDATE",
	}
	for _, event in pairs(bar.eventList) do
		bar:RegisterEvent(event)
	end
	bar:SetScript("OnEvent", UpdateBar)
	bar:SetScript("OnEnter", UpdateTooltip)
	bar:SetScript("OnLeave", GameTooltip_Hide)
end

function module:ProgressBar()
	local bar = CreateFrame("StatusBar", nil, Minimap)
	bar:SetPoint("TOP", Minimap, "BOTTOM", 0, 31)
	bar:SetSize(256, 2)
	bar:SetHitRectInsets(0, 0, 0, -10)
	F.CreateSB(bar)
	F.CreateBDFrame(bar)

	local rest = CreateFrame("StatusBar", nil, bar)
	rest:SetAllPoints()
	rest:SetStatusBarTexture(C.media.sbTex)
	rest:SetStatusBarColor(105/250, 194/250, 221/250, .9)
	rest:SetFrameLevel(bar:GetFrameLevel() - 1)
	bar.restBar = rest

	self:SetupScript(bar)

	hooksecurefunc("ReputationFrame_Update", module.HookParagonRep)
end

function module:HookParagonRep()
	local numFactions = GetNumFactions()
	local factionOffset = FauxScrollFrame_GetOffset(ReputationListScrollFrame)
	for i = 1, NUM_FACTIONS_DISPLAYED, 1 do
		local factionIndex = factionOffset + i
		local factionRow = _G["ReputationBar"..i]
		local factionBar = _G["ReputationBar"..i.."ReputationBar"]
		local factionStanding = _G["ReputationBar"..i.."ReputationBarFactionStanding"]

		if factionIndex <= numFactions then
			local factionID = select(14, GetFactionInfo(factionIndex))
			if factionID and C_Reputation.IsFactionParagon(factionID) then
				local currentValue, threshold = C_Reputation.GetFactionParagonInfo(factionID)
				local barValue = mod(currentValue, threshold)
				local factionStandingtext = C.InfoColor..L["Paragon"]..floor(currentValue/threshold)

				factionBar:SetMinMaxValues(0, threshold)
				factionBar:SetValue(barValue)
				factionStanding:SetText(factionStandingtext)
				factionRow.standingText = factionStandingtext
				factionRow.rolloverText = C.InfoColor..format(REPUTATION_PROGRESS_FORMAT, barValue, threshold)
			end
		end
	end
end
