local F, C, L = unpack(select(2, ...))
local module = F:GetModule("misc")


function module:AddAlerts()
	self:InterruptAlert()
end


-- interrupt/stolen/dispel alert
function module:InterruptAlert()
	if not C.misc.interruptAlert then return end

	local interruptSound = "Interface\\AddOns\\FreeUI\\assets\\sound\\Shutupfool.ogg"
	local dispelSound = "Interface\\AddOns\\FreeUI\\assets\\sound\\buzz.ogg"

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:SetScript("OnEvent", function(self)
		local _, event, _, sourceGUID, _, _, _, _, destName, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
		local inInstance, instanceType = IsInInstance()
		if ((sourceGUID == UnitGUID("player")) or (sourceGUID == UnitGUID("pet"))) then
			if (event == "SPELL_INTERRUPT") then
				if C.misc.interruptSound then
					PlaySoundFile(interruptSound, "Master")
				end
				if inInstance and C.misc.interruptNotify and (instanceType ~= 'pvp' and instanceType ~= 'arena') then
					SendChatMessage(L["interrupted"]..destName.." "..GetSpellLink(spellID), say)
				end
			elseif (event == "SPELL_DISPEL") then
				if C.misc.dispelSound then
					PlaySoundFile(dispelSound, "Master")
				end
				if inInstance and C.misc.interruptNotify and (instanceType ~= 'pvp' and instanceType ~= 'arena') then
					SendChatMessage(L["dispeled"]..destName.." "..GetSpellLink(spellID), say)
				end
			elseif (event == "SPELL_STOLEN") then
				if C.misc.dispelSound then
					PlaySoundFile(dispelSound, "Master")
				end
				if inInstance and C.misc.interruptNotify and (instanceType ~= 'pvp' and instanceType ~= 'arena') then
					SendChatMessage(L["stolen"]..destName.." "..GetSpellLink(spellID), say)
				end
			end
		end
	end)
end


