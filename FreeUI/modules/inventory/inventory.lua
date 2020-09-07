local F, C, L = unpack(select(2, ...))
local INVENTORY = F:GetModule('INVENTORY')
local cargBags = F.cargBags


local format, pairs, wipe, ipairs, strmatch, unpack, ceil = string.format, pairs, table.wipe, ipairs, string.match, unpack, math.ceil
local EJ_LOOT_SLOT_FILTER_ARTIFACT_RELIC = EJ_LOOT_SLOT_FILTER_ARTIFACT_RELIC
local LE_ITEM_QUALITY_POOR, LE_ITEM_QUALITY_RARE, LE_ITEM_QUALITY_HEIRLOOM = LE_ITEM_QUALITY_POOR, LE_ITEM_QUALITY_RARE, LE_ITEM_QUALITY_HEIRLOOM
local LE_ITEM_CLASS_WEAPON, LE_ITEM_CLASS_ARMOR, LE_ITEM_CLASS_CONTAINER = LE_ITEM_CLASS_WEAPON, LE_ITEM_CLASS_ARMOR, LE_ITEM_CLASS_CONTAINER
local SortBankBags, SortReagentBankBags, SortBags = SortBankBags, SortReagentBankBags, SortBags
local GetContainerNumSlots, GetContainerItemInfo, PickupContainerItem = GetContainerNumSlots, GetContainerItemInfo, PickupContainerItem
local C_AzeriteEmpoweredItem_IsAzeriteEmpoweredItemByID, C_NewItems_IsNewItem, C_NewItems_RemoveNewItem, C_Timer_After = C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID, C_NewItems.IsNewItem, C_NewItems.RemoveNewItem, C_Timer.After
local IsControlKeyDown, IsAltKeyDown, DeleteCursorItem = IsControlKeyDown, IsAltKeyDown, DeleteCursorItem
local GetItemInfo, GetContainerItemID, SplitContainerItem = GetItemInfo, GetContainerItemID, SplitContainerItem
local IsCorruptedItem = IsCorruptedItem

local icons = {
	['restore']   = C.AssetsPath..'inventory\\restore',
	['toggle']    = C.AssetsPath..'inventory\\toggle',
	['sort']      = C.AssetsPath..'inventory\\sort',
	['reagen']    = C.AssetsPath..'inventory\\reagen',
	['deposit']   = C.AssetsPath..'inventory\\deposit',
	['delete']    = C.AssetsPath..'inventory\\delete',
	['favourite'] = C.AssetsPath..'inventory\\favourite',
	['split']     = C.AssetsPath..'inventory\\split',
	['repair']    = C.AssetsPath..'inventory\\repair',
	['sell']      = C.AssetsPath..'inventory\\sell',
	['search']    = C.AssetsPath..'inventory\\search',
	['junk']      = C.AssetsPath..'inventory\\junk',
}

local function getMoneyString(number, full)
	if not full then
		local money = format('%.0f', number/1e4)
		return GetMoneyString(money*1e4)
	else
		return GetMoneyString(number)
	end
end

local sortCache = {}

function INVENTORY:ReverseSort()
	for bag = 0, 4 do
		local numSlots = GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local texture, _, locked = GetContainerItemInfo(bag, slot)
			if (slot <= numSlots/2) and texture and not locked and not sortCache['b'..bag..'s'..slot] then
				PickupContainerItem(bag, slot)
				PickupContainerItem(bag, numSlots+1 - slot)
				sortCache['b'..bag..'s'..slot] = true
			end
		end
	end

	INVENTORY.Bags.isSorting = false
	INVENTORY:UpdateAllBags()
end

function INVENTORY:UpdateAnchors(parent, bags)
	local anchor = parent
	for _, bag in ipairs(bags) do
		if bag:GetHeight() > 45 then
			bag:Show()
		else
			bag:Hide()
		end
		if bag:IsShown() then
			bag:SetPoint('BOTTOMLEFT', anchor, 'TOPLEFT', 0, 5)
			anchor = bag
		end
	end
end

local function highlightFunction(button, match)
	button:SetAlpha(match and 1 or .3)
end

local profit, spent, oldMoney = 0, 0, 0

local function getClassIcon(class)
	local c1, c2, c3, c4 = unpack(CLASS_ICON_TCOORDS[class])
	c1, c2, c3, c4 = (c1+.03)*50, (c2-.03)*50, (c3+.03)*50, (c4-.03)*50
	local classStr = '|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:13:15:0:-1:50:50:'..c1..':'..c2..':'..c3..':'..c4..'|t '
	return classStr or ''
end

function INVENTORY:CreateCurrencyFrame()
	local currencyFrame = CreateFrame('Button', nil, self)
	currencyFrame:SetPoint('TOPLEFT', 6, 0)
	currencyFrame:SetSize(140, 26)

	currencyFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
	currencyFrame:RegisterEvent('PLAYER_MONEY')
	currencyFrame:RegisterEvent('SEND_MAIL_MONEY_CHANGED')
	currencyFrame:RegisterEvent('SEND_MAIL_COD_CHANGED')
	currencyFrame:RegisterEvent('PLAYER_TRADE_MONEY')
	currencyFrame:RegisterEvent('TRADE_MONEY_CHANGED')
	currencyFrame:RegisterEvent('TOKEN_MARKET_PRICE_UPDATED')
	currencyFrame:SetScript('OnEvent', function(self, event)
		if event == 'PLAYER_ENTERING_WORLD' then
			oldMoney = GetMoney()
			C_WowTokenPublic.UpdateMarketPrice();
			self:UnregisterEvent(event)
		end
		if event == 'TOKEN_MARKET_PRICE_UPDATED' then
			C_WowTokenPublic.UpdateMarketPrice();
			return
		end
		local newMoney = GetMoney()
		local change = newMoney - oldMoney
		if oldMoney > newMoney then
			spent = spent - change
		else
			profit = profit + change
		end

		if not FreeADB['gold_count'][C.MyRealm] then FreeADB['gold_count'][C.MyRealm] = {} end
		FreeADB['gold_count'][C.MyRealm][C.MyName] = {GetMoney(), C.MyClass}

		oldMoney = newMoney
	end)

	local tag = self:SpawnPlugin('TagDisplay', '[money]  [currencies]', currencyFrame)
	F.SetFS(tag, C.Assets.Fonts.Number, 11, nil, '', nil, 'THICK', 'TOPLEFT', 0, -3)


	currencyFrame:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L['INVENTORY_GOLD_COUNT'], .9, .8, .6)
		GameTooltip:AddLine(' ')

		GameTooltip:AddLine(L['INVENTORY_SESSION'], .6,.8,1)
		GameTooltip:AddDoubleLine(L['INVENTORY_EARNED'], GetMoneyString(profit), 1,1,1, 1, 1, 1)
		GameTooltip:AddDoubleLine(L['INVENTORY_SPENT'], GetMoneyString(spent), 1,1,1, 1, 1, 1)
		if profit < spent then
			GameTooltip:AddDoubleLine(L['INVENTORY_DEFICIT'], GetMoneyString(spent-profit), 1,0,0, 1, 1, 1)
		elseif profit > spent then
			GameTooltip:AddDoubleLine(L['INVENTORY_PROFIT'], GetMoneyString(profit-spent), 0,1,0, 1, 1, 1)
		end
		GameTooltip:AddLine(' ')

		local totalGold = 0
		GameTooltip:AddLine(L['INVENTORY_CHARACTER'], .6,.8,1)
		local thisRealmList = FreeADB['gold_count'][C.MyRealm]
		for k, v in pairs(thisRealmList) do
			local gold, class = unpack(v)
			local r, g, b = F.ClassColor(class)
			GameTooltip:AddDoubleLine(getClassIcon(class)..k, GetMoneyString(gold), r,g,b, 1, 1, 1)
			totalGold = totalGold + gold
		end
		GameTooltip:AddLine(' ')
		GameTooltip:AddDoubleLine(L['INVENTORY_GOLD_TOTAL'], GetMoneyString(totalGold), .6,.8,1, 1, 1, 1)

		for i = 1, GetNumWatchedTokens() do
			local name, count, icon, currencyID = GetBackpackCurrencyInfo(i)
			if name and i == 1 then
				GameTooltip:AddLine(' ')
				GameTooltip:AddLine(CURRENCY, .6,.8,1)
			end
			if name and count then
				local _, _, _, _, _, total = GetCurrencyInfo(currencyID)
				local iconTexture = ' |T'..icon..':13:15:0:0:50:50:4:46:4:46|t'
				if total > 0 then
					GameTooltip:AddDoubleLine(name, count..'/'..total..iconTexture, 1,1,1, 1, 1, 1)
				else
					GameTooltip:AddDoubleLine(name, count..iconTexture, 1,1,1, 1, 1, 1)
				end
			end
		end

		GameTooltip:Show()
	end)

	currencyFrame:HookScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	currencyFrame:HookScript('OnMouseUp', function(self, btn)
		if InCombatLockdown() then UIErrorsFrame:AddMessage(C.InfoColor..ERR_NOT_IN_COMBAT) return end

		if btn == 'LeftButton' then
			securecall(ToggleCharacter, 'TokenFrame')

		elseif btn == 'RightButton' then
			if (not StoreFrame) then
				LoadAddOn('Blizzard_StoreUI')
			end
			securecall(ToggleStoreUI)
		elseif btn == 'MiddleButton' then
			StaticPopup_Show('FREEUI_RESET_GOLD')
		end
	end)
end

function INVENTORY:CreateBagBar(settings, columns)
	local bagBar = self:SpawnPlugin('BagBar', settings.Bags)
	local width, height = bagBar:LayoutButtons('grid', columns, 5, 5, -5)
	bagBar:SetSize(width + 10, height + 10)
	bagBar:SetPoint('TOPRIGHT', self, 'BOTTOMRIGHT', 0, -5)
	F.SetBD(bagBar)
	bagBar.highlightFunction = highlightFunction
	bagBar.isGlobal = true
	bagBar:Hide()

	self.BagBar = bagBar
end

function INVENTORY:CreateRestoreButton(f)
	local bu = F.CreateButton(self, 16, 16, true, icons.restore)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu:SetScript('OnClick', function()
		FreeDB['ui_anchor_temp'][f.main:GetName()] = nil
		FreeDB['ui_anchor_temp'][f.bank:GetName()] = nil
		FreeDB['ui_anchor_temp'][f.reagent:GetName()] = nil
		f.main:ClearAllPoints()
		f.main:SetPoint('BOTTOMRIGHT', -FreeADB['ui_gap'], FreeADB['ui_gap'])
		f.bank:ClearAllPoints()
		f.bank:SetPoint('BOTTOMRIGHT', f.main, 'BOTTOMLEFT', -10, 0)
		f.reagent:ClearAllPoints()
		f.reagent:SetPoint('BOTTOMLEFT', f.bank)
		PlaySound(SOUNDKIT.IG_MINIMAP_OPEN)
	end)
	bu.title = L['INVENTORY_ANCHOR_RESET']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	return bu
end

function INVENTORY:CreateReagentButton(f)
	local bu = F.CreateButton(self, 16, 16, true, icons.reagen)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu:RegisterForClicks('AnyUp')
	bu:SetScript('OnClick', function(_, btn)
		if not IsReagentBankUnlocked() then
			StaticPopup_Show('CONFIRM_BUY_REAGENTBANK_TAB')
		else
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			ReagentBankFrame:Show()
			BankFrame.selectedTab = 2
			f.reagent:Show()
			f.bank:Hide()
			if btn == 'RightButton' then DepositReagentBank() end
		end
	end)
	bu.title = REAGENT_BANK
	F.AddTooltip(bu, 'ANCHOR_TOP')

	return bu
end

function INVENTORY:CreateBankButton(f)
	local bu = F.CreateButton(self, 16, 16, true, icons.reagen)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu:SetScript('OnClick', function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		ReagentBankFrame:Hide()
		BankFrame.selectedTab = 1
		f.reagent:Hide()
		f.bank:Show()
	end)
	bu.title = BANK
	F.AddTooltip(bu, 'ANCHOR_TOP')

	return bu
end

function INVENTORY:CreateDepositButton()
	local bu = F.CreateButton(self, 16, 16, true, icons.reagen)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu:SetScript('OnClick', DepositReagentBank)
	bu.title = REAGENTBANK_DEPOSIT
	F.AddTooltip(bu, 'ANCHOR_TOP')

	return bu
end

function INVENTORY:CreateBagToggle()
	local bu = F.CreateButton(self, 16, 16, true, icons.toggle)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu:SetScript('OnClick', function()
		ToggleFrame(self.BagBar)
		if self.BagBar:IsShown() then
			bu.Icon:SetVertexColor(C.r, C.g, C.b, 1)
			PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
		else
			bu.Icon:SetVertexColor(.5, .5, .5, 1)
			PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
		end
	end)

	bu.title = L['INVENTORY_BAGS']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	return bu
end

function INVENTORY:CreateSortButton(name)
	local bu = F.CreateButton(self, 16, 16, true, icons.sort)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu:SetScript('OnClick', function()
		if name == 'Bank' then
			SortBankBags()
		elseif name == 'Reagent' then
			SortReagentBankBags()
		else
			if FreeDB['inventory']['reverse_sort'] then
				if InCombatLockdown() then
					UIErrorsFrame:AddMessage(C.InfoColor..ERR_NOT_IN_COMBAT)
				else
					SortBags()
					wipe(sortCache)
					INVENTORY.Bags.isSorting = true
					C_Timer_After(.5, INVENTORY.ReverseSort)
				end
			else
				SortBags()
			end
		end
	end)
	bu.title = L['INVENTORY_SORT']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	return bu
end

function INVENTORY:CreateRepairButton()
	local enabledText = C.BlueColor..L['INVENTORY_AUTO_REPAIR_ENABLED']
	local bu = F.CreateButton(self, 16, 16, true, icons.repair)

	if FreeDB['inventory']['auto_repair'] then
		bu.Icon:SetVertexColor(C.r, C.g, C.b, 1)
	else
		bu.Icon:SetVertexColor(.5, .5, .5, 1)
	end

	bu.title = L['INVENTORY_AUTO_REPAIR']..': '..(FreeDB['inventory']['auto_repair'] and C.GreenColor..VIDEO_OPTIONS_ENABLED or C.RedColor..VIDEO_OPTIONS_DISABLED)
	F.AddTooltip(bu, 'ANCHOR_TOP')

	bu:SetScript('OnClick', function(self)
		FreeDB['inventory']['auto_repair'] = not FreeDB['inventory']['auto_repair']

		if FreeDB['inventory']['auto_repair'] then
			self.Icon:SetVertexColor(C.r, C.g, C.b, 1)
			self.text = enabledText
		else
			self.Icon:SetVertexColor(.5, .5, .5, 1)
			self.text = nil
		end

		bu.title = L['INVENTORY_AUTO_REPAIR']..': '..(FreeDB['inventory']['auto_repair'] and C.GreenColor..VIDEO_OPTIONS_ENABLED or C.RedColor..VIDEO_OPTIONS_DISABLED)
		self:GetScript('OnEnter')(self)
	end)

	return bu
end

function INVENTORY:CreateSellButton()
	local enabledText = C.BlueColor..L['INVENTORY_SELL_JUNK_ENABLED']
	local bu = F.CreateButton(self, 16, 16, true, icons.sell)

	if FreeDB['inventory']['auto_sell_junk'] then
		bu.Icon:SetVertexColor(C.r, C.g, C.b, 1)
	else
		bu.Icon:SetVertexColor(.5, .5, .5, 1)
	end

	bu.title = L['INVENTORY_SELL_JUNK']..': '..(FreeDB['inventory']['auto_sell_junk'] and C.GreenColor..VIDEO_OPTIONS_ENABLED or C.RedColor..VIDEO_OPTIONS_DISABLED)
	F.AddTooltip(bu, 'ANCHOR_TOP')

	bu:SetScript('OnClick', function(self)
		FreeDB['inventory']['auto_sell_junk'] = not FreeDB['inventory']['auto_sell_junk']

		if FreeDB['inventory']['auto_sell_junk'] then
			self.Icon:SetVertexColor(C.r, C.g, C.b, 1)
			self.text = enabledText
		else
			self.Icon:SetVertexColor(.5, .5, .5, 1)
			self.text = nil
		end

		bu.title = L['INVENTORY_SELL_JUNK']..': '..(FreeDB['inventory']['auto_sell_junk'] and C.GreenColor..VIDEO_OPTIONS_ENABLED or C.RedColor..VIDEO_OPTIONS_DISABLED)
		self:GetScript('OnEnter')(self)
	end)

	return bu
end

function INVENTORY:CreateSearchButton()
	local bu = F.CreateButton(self, 16, 16, true, icons.search)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)

	bu.title = L['INVENTORY_SEARCH']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	local searchBar = self:SpawnPlugin('SearchBar', bu)
	searchBar.highlightFunction = highlightFunction
	searchBar.isGlobal = true
	searchBar:SetPoint('RIGHT', bu, 'RIGHT', -6, 0)
	searchBar:SetSize(80, 26)
	searchBar:DisableDrawLayer('BACKGROUND')
	F.AddTooltip(searchBar, 'ANCHOR_TOP', L['INVENTORY_SEARCH_ENABLED'], 'info')

	local bg = F.CreateBDFrame(searchBar, 0)
	bg:SetPoint('TOPLEFT', -5, -5)
	bg:SetPoint('BOTTOMRIGHT', 5, 5)
	F.CreateGradient(bg)

	searchBar:SetScript('OnShow', function(self)
		bu:SetSize(80, 26)
	end)

	searchBar:SetScript('OnHide', function(self)
		bu:SetSize(16, 16)
	end)

	return bu
end

function INVENTORY:GetContainerEmptySlot(bagID)
	for slotID = 1, GetContainerNumSlots(bagID) do
		if not GetContainerItemID(bagID, slotID) then
			return slotID
		end
	end
end

function INVENTORY:GetEmptySlot(name)
	if name == 'Main' then
		for bagID = 0, 4 do
			local slotID = INVENTORY:GetContainerEmptySlot(bagID)
			if slotID then
				return bagID, slotID
			end
		end
	elseif name == 'Bank' then
		local slotID = INVENTORY:GetContainerEmptySlot(-1)
		if slotID then
			return -1, slotID
		end
		for bagID = 5, 11 do
			local slotID = INVENTORY:GetContainerEmptySlot(bagID)
			if slotID then
				return bagID, slotID
			end
		end
	elseif name == 'Reagent' then
		local slotID = INVENTORY:GetContainerEmptySlot(-3)
		if slotID then
			return -3, slotID
		end
	end
end

function INVENTORY:FreeSlotOnDrop()
	local bagID, slotID = INVENTORY:GetEmptySlot(self.__name)
	if slotID then
		PickupContainerItem(bagID, slotID)
	end
end

local freeSlotContainer = {
	['Main'] = true,
	['Bank'] = true,
	['Reagent'] = true,
}

function INVENTORY:CreateFreeSlots()
	local name = self.name
	if not freeSlotContainer[name] then return end

	local slot = CreateFrame('Button', name..'FreeSlot', self)
	slot:SetSize(self.iconSize, self.iconSize)
	slot:SetHighlightTexture(C.Assets.bd_tex)
	slot:GetHighlightTexture():SetVertexColor(1, 1, 1, .25)
	slot:GetHighlightTexture():SetInside()
	F.CreateBD(slot, .25)
	slot:SetBackdropColor(.3, .3, .3, .25)

	slot:SetScript('OnMouseUp', INVENTORY.FreeSlotOnDrop)
	slot:SetScript('OnReceiveDrag', INVENTORY.FreeSlotOnDrop)
	F.AddTooltip(slot, 'ANCHOR_RIGHT', L['INVENTORY_FREE_SLOTS'])
	slot.__name = name

	local tag = self:SpawnPlugin('TagDisplay', '[space]', slot)
	F.SetFS(tag, C.Assets.Fonts.Number, 11, nil, '', 'CLASS', 'THICK', 'BOTTOMRIGHT', -2, 2)
	tag.__name = name

	self.freeSlot = slot
end

local toggleButtons = {}
function INVENTORY:SelectToggleButton(id)
	for index, button in pairs(toggleButtons) do
		if index ~= id then
			button.__turnOff()
		end
	end
end

local splitEnable
local function saveSplitCount(self)
	local count = self:GetText() or ''
	FreeDB['inventory']['split_count'] = tonumber(count) or 1
end

function INVENTORY:CreateSplitButton()
	local enabledText = C.BlueColor..L['INVENTORY_SPLIT_MODE_ENABLED']

	local splitFrame = CreateFrame('Frame', nil, self)
	splitFrame:SetSize(100, 50)
	splitFrame:SetPoint('TOPRIGHT', self, 'TOPLEFT', -5, 0)
	F.CreateFS(splitFrame, C.Assets.Fonts.Normal, 12, nil, L['INVENTORY_SPLIT_COUNT'], 'YELLOW', 'THICK', 'TOP', 1, -5)
	F.SetBD(splitFrame)
	splitFrame:Hide()
	local editbox = F.CreateEditBox(splitFrame, 90, 20)
	editbox:SetPoint('BOTTOMLEFT', 5, 5)
	editbox:SetJustifyH('CENTER')
	editbox:SetScript('OnTextChanged', saveSplitCount)

	local bu = F.CreateButton(self, 16, 16, true, icons.split)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu.__turnOff = function()
		bu.Icon:SetVertexColor(.5, .5, .5, 1)
		bu.text = nil
		splitFrame:Hide()
		splitEnable = nil
	end
	bu:SetScript('OnClick', function(self)
		INVENTORY:SelectToggleButton(1)
		splitEnable = not splitEnable
		if splitEnable then
			bu.Icon:SetVertexColor(C.r, C.g, C.b, 1)
			self.text = enabledText
			splitFrame:Show()
			editbox:SetText(FreeDB['inventory']['split_count'])
		else
			self.__turnOff()
		end
		self:GetScript('OnEnter')(self)
	end)
	bu:SetScript('OnHide', bu.__turnOff)
	bu.title = L['INVENTORY_QUICK_SPLIT']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	toggleButtons[1] = bu

	return bu
end

local function splitOnClick(self)
	if not splitEnable then return end

	PickupContainerItem(self.bagID, self.slotID)

	local texture, itemCount, locked = GetContainerItemInfo(self.bagID, self.slotID)
	if texture and not locked and itemCount and itemCount > FreeDB['inventory']['split_count'] then
		SplitContainerItem(self.bagID, self.slotID, FreeDB['inventory']['split_count'])

		local bagID, slotID = INVENTORY:GetEmptySlot('Main')
		if slotID then
			PickupContainerItem(bagID, slotID)
		end
	end
end

local favouriteEnable
function INVENTORY:CreateFavouriteButton()
	local enabledText = C.BlueColor..L['INVENTORY_PICK_FAVOURITE_ENABLED']

	local bu = F.CreateButton(self, 16, 16, true, icons.favourite)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu.__turnOff = function()
		bu.Icon:SetVertexColor(.5, .5, .5, 1)
		bu.text = nil
		favouriteEnable = nil
	end
	bu:SetScript('OnClick', function(self)
		INVENTORY:SelectToggleButton(2)
		favouriteEnable = not favouriteEnable
		if favouriteEnable then
			self.Icon:SetVertexColor(C.r, C.g, C.b, 1)
			self.text = enabledText
		else
			self.__turnOff()
		end
		self:GetScript('OnEnter')(self)
	end)

	bu:SetScript('OnHide', bu.__turnOff)
	bu.title = L['INVENTORY_PICK_FAVOURITE']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	toggleButtons[2] = bu

	return bu
end

local function favouriteOnClick(self)
	if not favouriteEnable then return end

	local texture, _, _, quality, _, _, _, _, _, itemID = GetContainerItemInfo(self.bagID, self.slotID)
	if texture and quality > LE_ITEM_QUALITY_POOR then
		if FreeDB['inventory']['favourite_items'][itemID] then
			FreeDB['inventory']['favourite_items'][itemID] = nil
		else
			FreeDB['inventory']['favourite_items'][itemID] = true
		end
		ClearCursor()
		INVENTORY:UpdateAllBags()
	end
end

local customJunkEnable
function INVENTORY:CreateCustomJunkButton()
	local enabledText = C.InfoColor..L['INVENTORY_MARK_JUNK_ENABLED']

	local bu = F.CreateButton(self, 16, 16, true, icons.junk)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu.__turnOff = function()
		bu.Icon:SetVertexColor(.5, .5, .5, 1)
		bu.text = nil
		customJunkEnable = nil
	end
	bu:SetScript('OnClick', function(self)
		INVENTORY:SelectToggleButton(3)
		customJunkEnable = not customJunkEnable
		if customJunkEnable then
			self.Icon:SetVertexColor(C.r, C.g, C.b, 1)
			self.text = enabledText
		else
			bu.__turnOff()
		end
		self:GetScript('OnEnter')(self)
		INVENTORY:UpdateAllBags()
	end)

	bu:SetScript('OnHide', bu.__turnOff)
	bu.title = L['INVENTORY_MARK_JUNK']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	toggleButtons[3] = bu

	return bu
end

local function customJunkOnClick(self)
	if not customJunkEnable then return end

	local texture, _, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(self.bagID, self.slotID)
	local price = select(11, GetItemInfo(itemID))
	if texture and price > 0 then
		if FreeADB['custom_junk_list'][itemID] then
			FreeADB['custom_junk_list'][itemID] = nil
		else
			FreeADB['custom_junk_list'][itemID] = true
		end
		ClearCursor()
		INVENTORY:UpdateAllBags()
	end
end

local deleteEnable
function INVENTORY:CreateDeleteButton()
	local enabledText = C.BlueColor..L['INVENTORY_QUICK_DELETE_ENABLED']

	local bu = F.CreateButton(self, 16, 16, true, icons.delete)
	bu.Icon:SetVertexColor(.5, .5, .5, 1)
	bu.__turnOff = function()
		bu.Icon:SetVertexColor(.5, .5, .5, 1)
		bu.text = nil
		deleteEnable = nil
	end
	bu:SetScript('OnClick', function(self)
		INVENTORY:SelectToggleButton(4)
		deleteEnable = not deleteEnable
		if deleteEnable then
			self.Icon:SetVertexColor(C.r, C.g, C.b, 1)
			self.text = enabledText
		else
			bu.__turnOff()
		end

		self:GetScript('OnEnter')(self)
	end)

	bu:SetScript('OnHide', bu.__turnOff)
	bu.title = L['INVENTORY_QUICK_DELETE']
	F.AddTooltip(bu, 'ANCHOR_TOP')

	toggleButtons[4] = bu

	return bu
end

local function deleteButtonOnClick(self)
	if not deleteEnable then return end

	local texture, _, _, quality = GetContainerItemInfo(self.bagID, self.slotID)
	if IsControlKeyDown() and IsAltKeyDown() and texture and (quality < LE_ITEM_QUALITY_RARE or quality == LE_ITEM_QUALITY_HEIRLOOM) then
		PickupContainerItem(self.bagID, self.slotID)
		DeleteCursorItem()
	end
end

function INVENTORY:ButtonOnClick(btn)
	if btn ~= 'LeftButton' then return end
	splitOnClick(self)
	favouriteOnClick(self)
	customJunkOnClick(self)
	deleteButtonOnClick(self)
end

function INVENTORY:UpdateAllBags()
	if self.Bags and self.Bags:IsShown() then
		self.Bags:BAG_UPDATE()
	end
end

function INVENTORY:OpenBags()
	OpenAllBags(true)
end

function INVENTORY:CloseBags()
	CloseAllBags()
end

function INVENTORY:OnLogin()
	if not FreeDB['inventory']['enable_inventory'] then return end

	INVENTORY:AutoSellJunk()
	INVENTORY:AutoRepair()

	local bagsScale = FreeDB['inventory']['scale']
	local bagsWidth = FreeDB['inventory']['bag_columns']
	local bankWidth = FreeDB['inventory']['bank_columns']
	local iconSize = FreeDB['inventory']['slot_size']
	local itemSetFilter = FreeDB['inventory']['item_filter_gear_set']
	local showNewItem = FreeDB['inventory']['new_item_flash']

	local Backpack = cargBags:NewImplementation('FreeUI_Backpack')
	Backpack:RegisterBlizzard()
	Backpack:SetScale(bagsScale)
	Backpack:HookScript('OnShow', function() PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end)
	Backpack:HookScript('OnHide', function() PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end)

	INVENTORY.Bags = Backpack
	INVENTORY.BagsType = {}
	INVENTORY.BagsType[0] = 0	-- backpack
	INVENTORY.BagsType[-1] = 0	-- bank
	INVENTORY.BagsType[-3] = 0	-- reagent

	local f = {}
	local filters = self:GetFilters()

	function Backpack:OnInit()
		local MyContainer = self:GetContainerClass()

		f.main = MyContainer:New('Main', {Columns = bagsWidth, Bags = 'bags'})
		f.main:SetFilter(filters.onlyBags, true)
		f.main:SetPoint('BOTTOMRIGHT', -FreeADB['ui_gap'], FreeADB['ui_gap'])

		f.junk = MyContainer:New('Junk', {Columns = bagsWidth, Parent = f.main})
		f.junk:SetFilter(filters.bagsJunk, true)

		f.azeriteItem = MyContainer:New('AzeriteItem', {Columns = bagsWidth, Parent = f.main})
		f.azeriteItem:SetFilter(filters.bagAzeriteItem, true)

		f.equipment = MyContainer:New('Equipment', {Columns = bagsWidth, Parent = f.main})
		f.equipment:SetFilter(filters.bagEquipment, true)

		f.consumable = MyContainer:New('Consumable', {Columns = bagsWidth, Parent = f.main})
		f.consumable:SetFilter(filters.bagConsumable, true)

		f.bagCompanion = MyContainer:New('BagCompanion', {Columns = bagsWidth, Parent = f.main})
		f.bagCompanion:SetFilter(filters.bagMountPet, true)

		f.bagGoods = MyContainer:New('BagGoods', {Columns = bagsWidth, Parent = f.main})
		f.bagGoods:SetFilter(filters.bagGoods, true)

		f.questitem = MyContainer:New('QuestItem', {Columns = bagsWidth, Parent = f.main})
		f.questitem:SetFilter(filters.bagQuestItem, true)

		f.bagFavourite = MyContainer:New('BagFavourite', {Columns = bagsWidth, Parent = f.main})
		f.bagFavourite:SetFilter(filters.bagFavourite, true)

		f.bank = MyContainer:New('Bank', {Columns = bankWidth, Bags = 'bank'})
		f.bank:SetFilter(filters.onlyBank, true)
		f.bank:SetPoint('BOTTOMRIGHT', f.main, 'BOTTOMLEFT', -10, 0)
		f.bank:Hide()

		f.bankAzeriteItem = MyContainer:New('BankAzeriteItem', {Columns = bankWidth, Parent = f.bank})
		f.bankAzeriteItem:SetFilter(filters.bankAzeriteItem, true)

		f.bankLegendary = MyContainer:New('BankLegendary', {Columns = bankWidth, Parent = f.bank})
		f.bankLegendary:SetFilter(filters.bankLegendary, true)

		f.bankEquipment = MyContainer:New('BankEquipment', {Columns = bankWidth, Parent = f.bank})
		f.bankEquipment:SetFilter(filters.bankEquipment, true)

		f.bankConsumable = MyContainer:New('BankConsumable', {Columns = bankWidth, Parent = f.bank})
		f.bankConsumable:SetFilter(filters.bankConsumable, true)

		f.bankCompanion = MyContainer:New('BankCompanion', {Columns = bankWidth, Parent = f.bank})
		f.bankCompanion:SetFilter(filters.bankMountPet, true)

		f.bankGoods = MyContainer:New('BankGoods', {Columns = bankWidth, Parent = f.main})
		f.bankGoods:SetFilter(filters.bankGoods, true)

		f.bankFavourite = MyContainer:New('BankFavourite', {Columns = bankWidth, Parent = f.bank})
		f.bankFavourite:SetFilter(filters.bankFavourite, true)

		f.reagent = MyContainer:New('Reagent', {Columns = bankWidth})
		f.reagent:SetFilter(filters.onlyReagent, true)
		f.reagent:SetPoint('BOTTOMLEFT', f.bank)
		f.reagent:Hide()

		INVENTORY.BagGroup = {f.azeriteItem, f.equipment, f.bagCompanion, f.bagGoods, f.consumable, f.bagFavourite, f.junk, f.questitem}
		INVENTORY.BankGroup = {f.bankAzeriteItem, f.bankEquipment, f.bankLegendary, f.bankCompanion, f.bankGoods, f.bankConsumable, f.bankFavourite}
	end

	local initBagType
	function Backpack:OnBankOpened()
		BankFrame:Show()
		self:GetContainer('Bank'):Show()

		if not initBagType then
			INVENTORY:UpdateAllBags() -- Initialize bagType
			initBagType = true
		end
	end

	function Backpack:OnBankClosed()
		BankFrame.selectedTab = 1
		BankFrame:Hide()
		self:GetContainer('Bank'):Hide()
		self:GetContainer('Reagent'):Hide()
		ReagentBankFrame:Hide()
	end

	local MyButton = Backpack:GetItemButtonClass()
	MyButton:Scaffold('Default')

	function MyButton:OnCreate()
		self:SetNormalTexture(nil)
		self:SetPushedTexture(nil)
		self:SetHighlightTexture(C.Assets.bd_tex)
		self:GetHighlightTexture():SetVertexColor(1, 1, 1, .25)
		self:GetHighlightTexture():SetInside()
		self:SetSize(iconSize, iconSize)

		self.Icon:SetInside()
		self.Icon:SetTexCoord(unpack(C.TexCoord))
		F.SetFS(self.Count, C.Assets.Fonts.Number, 11, 'OUTLINE', '', nil, false, 'BOTTOMRIGHT', -2, 2)
		self.Cooldown:SetInside()
		self.IconOverlay:SetInside()

		F.CreateBD(self, .25)
		self:SetBackdropColor(.3, .3, .3, .25)

		local parentFrame = CreateFrame('Frame', nil, self)
		parentFrame:SetAllPoints()
		parentFrame:SetFrameLevel(5)

		self.Favourite = parentFrame:CreateTexture(nil, 'ARTWORK')
		self.Favourite:SetAtlas('collections-icon-favorites')
		self.Favourite:SetSize(30, 30)
		self.Favourite:SetPoint('TOPLEFT', -12, 9)

		self.Quest = F.CreateFS(self, C.Assets.Fonts.Number, 11, nil, '!', nil, 'THICK', 'TOPLEFT', 2, -2)
		self.iLvl = F.CreateFS(self, C.Assets.Fonts.Number, 11, nil, '', nil, 'THICK', 'BOTTOMRIGHT', -2, 2)

		local flash = self:CreateTexture(nil, 'ARTWORK')
		flash:SetTexture('Interface\\Cooldown\\star4')
		flash:SetPoint('TOPLEFT', -20, 20)
		flash:SetPoint('BOTTOMRIGHT', 20, -20)
		flash:SetBlendMode('ADD')
		flash:SetAlpha(0)
		local anim = flash:CreateAnimationGroup()
		anim:SetLooping('REPEAT')
		anim.rota = anim:CreateAnimation('Rotation')
		anim.rota:SetDuration(1)
		anim.rota:SetDegrees(-90)
		anim.fader = anim:CreateAnimation('Alpha')
		anim.fader:SetFromAlpha(0)
		anim.fader:SetToAlpha(.5)
		anim.fader:SetDuration(.5)
		anim.fader:SetSmoothing('OUT')
		anim.fader2 = anim:CreateAnimation('Alpha')
		anim.fader2:SetStartDelay(.5)
		anim.fader2:SetFromAlpha(.5)
		anim.fader2:SetToAlpha(0)
		anim.fader2:SetDuration(1.2)
		anim.fader2:SetSmoothing('OUT')
		self:HookScript('OnHide', function() if anim:IsPlaying() then anim:Stop() end end)
		self.anim = anim

		self.ShowNewItems = showNewItem

		self:HookScript('OnClick', INVENTORY.ButtonOnClick)
	end

	function MyButton:ItemOnEnter()
		if self.ShowNewItems then
			if self.anim:IsPlaying() then self.anim:Stop() end
		end
	end

	local bagTypeColor = {
		[0] = {.3, .3, .3, .25},	-- 容器
		[1] = false,				-- 弹药袋
		[2] = {0, .5, 0, .25},		-- 草药袋
		[3] = {.8, 0, .8, .25},		-- 附魔袋
		[4] = {1, .8, 0, .25},		-- 工程袋
		[5] = {0, .8, .8, .25},		-- 宝石袋
		[6] = {.5, .4, 0, .25},		-- 矿石袋
		[7] = {.8, .5, .5, .25},	-- 制皮包
		[8] = {.8, .8, .8, .25},	-- 铭文包
		[9] = {.4, .6, 1, .25},		-- 工具箱
		[10] = {.8, 0, 0, .25},		-- 烹饪包
	}

	local function isItemNeedsLevel(item)
		return item.link and item.level and item.rarity > 1 and (item.subType == EJ_LOOT_SLOT_FILTER_ARTIFACT_RELIC or item.classID == LE_ITEM_CLASS_WEAPON or item.classID == LE_ITEM_CLASS_ARMOR)
	end

	local function GetIconOverlayAtlas(item)
		if not item.link then return end
		if C_AzeriteEmpoweredItem_IsAzeriteEmpoweredItemByID(item.link) then
			return 'AzeriteIconFrame'
		elseif IsCorruptedItem(item.link) then
			return 'Nzoth-inventory-icon'
		end
	end

	function MyButton:OnUpdate(item)
		if MerchantFrame:IsShown() then
			if item.isInSet then
				self:SetAlpha(.5)
			else
				self:SetAlpha(1)
			end
		end

		if self.JunkIcon then
			if (MerchantFrame:IsShown() or customJunkEnable) and (item.rarity == LE_ITEM_QUALITY_POOR or FreeADB['custom_junk_list'][item.id]) and item.sellPrice > 0 then
				self.JunkIcon:Show()
			else
				self.JunkIcon:Hide()
			end
		end

		local atlas = GetIconOverlayAtlas(item)
		if atlas then
			self.IconOverlay:SetAtlas(atlas)
			self.IconOverlay:Show()
		else
			self.IconOverlay:Hide()
		end

		if FreeDB['inventory']['favourite_items'][item.id] then
			self.Favourite:Show()
		else
			self.Favourite:Hide()
		end

		if self.ShowNewItems then
			if C_NewItems_IsNewItem(item.bagID, item.slotID) then
				self.anim:Play()
			else
				if self.anim:IsPlaying() then self.anim:Stop() end
			end
		end

		if FreeDB['inventory']['item_level'] and isItemNeedsLevel(item) then
			local level = F.GetItemLevel(item.link, item.bagID, item.slotID) or item.level
			if level < FreeDB['inventory']['item_level_to_show'] then level = '' end
			local color = C.QualityColors[item.rarity]
			self.iLvl:SetText(level)
			self.iLvl:SetTextColor(color.r, color.g, color.b)
		else
			self.iLvl:SetText('')
		end

		if FreeDB['inventory']['special_color'] then
			local bagType = INVENTORY.BagsType[item.bagID]
			local color = bagTypeColor[bagType] or bagTypeColor[0]
			self:SetBackdropColor(unpack(color))
		else
			self:SetBackdropColor(.3, .3, .3, .25)
		end
	end

	function MyButton:OnUpdateQuest(item)
		if item.questID and not item.questActive then
			self.Quest:Show()
		else
			self.Quest:Hide()
		end

		if item.questID or item.isQuestItem then
			self:SetBackdropBorderColor(.8, .8, 0, 1)
		elseif item.rarity and item.rarity > -1 then
			local color = C.QualityColors[item.rarity]
			self:SetBackdropBorderColor(color.r, color.g, color.b, 1)
		else
			self:SetBackdropBorderColor(0, 0, 0, .2)
		end
	end

	local MyContainer = Backpack:GetContainerClass()
	function MyContainer:OnContentsChanged()
		self:SortButtons('bagSlot')

		local columns = self.Settings.Columns
		local offset = FreeDB['inventory']['offset']
		local spacing = FreeDB['inventory']['spacing']
		local xOffset = 5
		local yOffset = -offset + xOffset
		local _, height = self:LayoutButtons('grid', columns, spacing, xOffset, yOffset)
		local width = columns * (iconSize+spacing)-spacing
		if self.freeSlot then
			if FreeDB['inventory']['combine_free_slots'] then
				local numSlots = #self.buttons + 1
				local row = ceil(numSlots / columns)
				local col = numSlots % columns
				if col == 0 then col = columns end
				local xPos = (col-1) * (iconSize + spacing)
				local yPos = -1 * (row-1) * (iconSize + spacing)

				self.freeSlot:ClearAllPoints()
				self.freeSlot:SetPoint('TOPLEFT', self, 'TOPLEFT', xPos+xOffset, yPos+yOffset)
				self.freeSlot:Show()

				if height < 0 then
					height = iconSize
				elseif col == 1 then
					height = height + iconSize + spacing
				end
			else
				self.freeSlot:Hide()
			end
		end
		self:SetSize(width + xOffset*2, height + offset)

		INVENTORY:UpdateAnchors(f.main, INVENTORY.BagGroup)
		INVENTORY:UpdateAnchors(f.bank, INVENTORY.BankGroup)
	end

	function MyContainer:OnCreate(name, settings)
		self.Settings = settings
		self:SetParent(settings.Parent or Backpack)
		self:SetFrameStrata('HIGH')
		self:SetClampedToScreen(true)
		F.SetBD(self)
		F.CreateMF(self, settings.Parent, true)

		local label
		if strmatch(name, 'AzeriteItem$') then
			label = L['INVENTORY_AZERITEARMOR']
		elseif strmatch(name, 'Equipment$') then
			if itemSetFilter then
				label = L['INVENTORY_EQUIPEMENTSET']
			else
				label = BAG_FILTER_EQUIPMENT
			end
		elseif name == 'BankLegendary' then
			label = LOOT_JOURNAL_LEGENDARIES
		elseif strmatch(name, 'Consumable$') then
			label = BAG_FILTER_CONSUMABLES
		elseif strmatch(name, 'QuestItem$') then
			label = AUCTION_CATEGORY_QUEST_ITEMS
		elseif name == 'Junk' then
			label = BAG_FILTER_JUNK
		elseif strmatch(name, 'Companion') then
			label = MOUNTS_AND_PETS
		elseif strmatch(name, 'Favourite') then
			label = PREFERENCES
		elseif strmatch(name, 'Goods') then
			label = AUCTION_CATEGORY_TRADE_GOODS
		end
		if label then
			self.cat = F.CreateFS(self, C.Assets.Fonts.Normal, 12, nil, label, nil, 'THICK', 'TOPLEFT', 5, -4)
			return
		end

		INVENTORY.CreateCurrencyFrame(self)

		local buttons = {}
		buttons[1] = INVENTORY.CreateRestoreButton(self, f)
		if name == 'Main' then
			INVENTORY.CreateBagBar(self, settings, 4)
			buttons[2] = INVENTORY.CreateBagToggle(self)
			buttons[4] = INVENTORY.CreateRepairButton(self)
			buttons[5] = INVENTORY.CreateSellButton(self)
			buttons[6] = INVENTORY.CreateSplitButton(self)
			buttons[7] = INVENTORY.CreateFavouriteButton(self)
			buttons[8] = INVENTORY.CreateCustomJunkButton(self)
			buttons[9] = INVENTORY.CreateDeleteButton(self)
			buttons[10] = INVENTORY.CreateSearchButton(self)

		elseif name == 'Bank' then
			INVENTORY.CreateBagBar(self, settings, 7)
			buttons[2] = INVENTORY.CreateReagentButton(self, f)
			buttons[3] = INVENTORY.CreateBagToggle(self)
		elseif name == 'Reagent' then
			buttons[2] = INVENTORY.CreateBankButton(self, f)
			buttons[3] = INVENTORY.CreateDepositButton(self)
		end
		buttons[3] = INVENTORY.CreateSortButton(self, name)

		for i = 1, #buttons do
			local bu = buttons[i]
			if not bu then break end
			if i == 1 then
				bu:SetPoint('TOPRIGHT', -5, -2)
			else
				bu:SetPoint('RIGHT', buttons[i-1], 'LEFT', -3, 0)
			end
		end

		self:HookScript('OnShow', F.RestoreMF)

		self.iconSize = iconSize
		INVENTORY.CreateFreeSlots(self)
	end

	local BagButton = Backpack:GetClass('BagButton', true, 'BagButton')
	function BagButton:OnCreate()
		self:SetNormalTexture(nil)
		self:SetPushedTexture(nil)
		self:SetHighlightTexture(C.Assets.bd_tex)
		self:GetHighlightTexture():SetVertexColor(1, 1, 1, .25)

		self:SetSize(iconSize, iconSize)
		F.CreateBD(self, .25)
		self.Icon:SetAllPoints()
		self.Icon:SetTexCoord(unpack(C.TexCoord))
	end

	function BagButton:OnUpdate()
		local id = GetInventoryItemID('player', (self.GetInventorySlot and self:GetInventorySlot()) or self.invID)
		if not id then return end
		local _, _, quality, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(id)
		if not quality or quality == 1 then quality = 0 end

		local color = C.QualityColors[quality]
		if not self.hidden and not self.notBought then
			self:SetBackdropBorderColor(color.r, color.g, color.b)
		else
			self:SetBackdropBorderColor(0, 0, 0)
		end

		if classID == LE_ITEM_CLASS_CONTAINER then
			INVENTORY.BagsType[self.bagID] = subClassID or 0
		else
			INVENTORY.BagsType[self.bagID] = 0
		end
	end

	-- Sort order
	SetSortBagsRightToLeft(not FreeDB['inventory']['reverse_sort'])
	SetInsertItemsLeftToRight(false)

	-- Init
	ToggleAllBags()
	ToggleAllBags()
	INVENTORY.initComplete = true

	F:RegisterEvent('TRADE_SHOW', INVENTORY.OpenBags)
	F:RegisterEvent('TRADE_CLOSED', INVENTORY.CloseBags)
	F:RegisterEvent('AUCTION_HOUSE_SHOW', INVENTORY.OpenBags)
	F:RegisterEvent('AUCTION_HOUSE_CLOSED', INVENTORY.CloseBags)

	-- Fixes
	BankFrame.GetRight = function() return f.bank:GetRight() end
	BankFrameItemButton_Update = F.Dummy
end
