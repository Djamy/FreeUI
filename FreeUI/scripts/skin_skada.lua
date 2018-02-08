local F, C, L = unpack(select(2, ...))

local function InitStyleSKADA()
	--print("Skada", F, C)
	-- Short Numbers
	local SkadaFormatValueText = _G.Skada.FormatValueText

	local function FormatValues(value, enabled, ...)
		if value == nil then
			return
		elseif ( _G.type(value) == "number" or ( _G.type(value) == "string" and value:match("^[-+]?[%d.,]+$") )) and _G.tonumber(value) > 1000 then
			value = _G.Skada:FormatNumber(_G.tonumber(value))
		end
		return value, enabled, FormatValues(...)
	end

	function _G.Skada.FormatValueText(Skada, ...)
		return SkadaFormatValueText(Skada, FormatValues(...))
	end

	-- Background + Textures
	local skadaBar = _G.Skada.displays["bar"]
	skadaBar._ApplySettings = skadaBar.ApplySettings
	skadaBar.ApplySettings = function(bar, win)
		skadaBar._ApplySettings(bar, win)

		local skada = win.bargroup

		if win.db.enabletitle and not skada.button.skinned then
			skada.button.skinned = true
			F.CreateBDFrame(skada.button)
		end

		skada:SetTexture(C.media.texture)
		skada:SetSpacing(0)
		skada:SetFrameLevel(5)

		skada:SetBackdrop(nil)
		if not skada.backdrop then
			skada.backdrop = F.CreateBDFrame(skada, .2)
		end
	end

	for _, window in _G.ipairs(_G.Skada:GetWindows()) do
		window:UpdateDisplay()
	end
end

if IsAddOnLoaded("Skada") then
	InitStyleWA()
else
	local load = CreateFrame("Frame")
	load:RegisterEvent("ADDON_LOADED")
	load:SetScript("OnEvent", function(self, _, addon)
		if addon ~= "Skada" then return end
		self:UnregisterEvent("ADDON_LOADED")

		InitStyleSKADA()

		load = nil
	end)
end