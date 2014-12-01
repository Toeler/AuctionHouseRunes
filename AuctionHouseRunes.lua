-----------------------------------------------------------------------------------------------
-- Client Lua Script for AuctionHouseRunes
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- AuctionHouseRunes Module Definition
-----------------------------------------------------------------------------------------------
local NAME = "AuctionHouseRunes"

local AuctionHouseRunes = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon(NAME, false, {"MarketplaceAuction", "Gemini:Logging-1.2"}, "Gemini:Hook-1.0")

local Logger

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local ktVersion = {nMajor = 1, nMinor = 2, nPatch = 2}

local ktDefaultSettings = {
	tVersion = {
		nMajor = ktVersion.nMajor,
		nMinor = ktVersion.nMinor,
		nPatch = ktVersion.nPatch
	},
	bRuneIcons = true,
	nIconSize = 28,
	bRuneNames = true
}

local ktMinWidth = 40

local ktAuctionHouseAddons = {
	"MarketplaceAuction"
}

local ktEvalColors = {
	[Item.CodeEnumItemQuality.Inferior] 		= ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 			= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= ApolloColor.new("ItemQuality_Artifact")
}

local ktRuneNames = {
	[7]		= "Air",
	[8]		= "Water",
	[9]		= "Earth",
	[10]	= "Fire",
	[11]	= "Logic",
	[12]	= "Life",
	[13]	= "Fusion",
	[14]	= "Omni"
}
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function AuctionHouseRunes:OnInitialize()
	--self:InitializeLogger()
	
	self.settings = copyTable(ktDefaultSettings)
	
	self.xmlDoc = XmlDoc.CreateFromFile("AuctionHouseRunes.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function AuctionHouseRunes:OnDocLoaded()
	if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() then
		Apollo.AddAddonErrorText(self, "XmlDoc not loaded.")
	end
	
	Apollo.RegisterSlashCommand("auctionhouserunes", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("ahr", "OnSlashCommand", self)
	
	self.bAuctionHouseHooked = self:InstallAuctionHouseHook()
	
	if not self.bAuctionHouseHooked then
		Apollo.AddAddonErrorText(self, "Could not find MarketplaceAuction.")
	end
end

function AuctionHouseRunes:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	self.settings.tVersion = copyTable(ktVersion)
	return self.settings
end

function AuctionHouseRunes:OnRestore(eLevel, tData)
	if tData ~= nil then
		self.settings = mergeTables(self.settings, tData)
	end
end

function AuctionHouseRunes:OnSlashCommand(sCommand, sParam)
	local function print(sMessage)
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, sMessage, "")
	end
	
	local bValid = false
	if sParam then
		if string.sub(sParam, 1, string.len("icon")) == "icon" then
			local sRest = string.lower(string.sub(sParam, string.len("icon") + 2))
			if sRest == "on" or sRest == "show" then
				bValid = true
				self.settings.bRuneIcons = true
				print("[AuctionHouseRunes] Rune icons shown. Please close and reopen the auction house.")
			elseif sRest == "off" or sRest == "hide" then
				bValid = true
				self.settings.bRuneIcons = false
				print("[AuctionHouseRunes] Rune icons hidden. Please close and reopen the auction house.")
			end
		elseif string.sub(sParam, 1, string.len("name")) == "name" then
			local sRest = string.lower(string.sub(sParam, string.len("name") + 2))
			if sRest == "on" or sRest == "show" then
				bValid = true
				self.settings.bRuneNames = true
				print("[AuctionHouseRunes] Rune names shown. Please close and reopen the auction house.")
			elseif sRest == "off" or sRest == "hide" then
				bValid = true
				self.settings.bRuneNames = false
				print("[AuctionHouseRunes] Rune names hidden. Please close and reopen the auction house.")
			end
		elseif string.sub(sParam, 1, string.len("size")) == "size" then
			local sRest = string.lower(string.sub(sParam, string.len("name") + 2))
			if tonumber(sRest) then
				bValid = true
				self.settings.nIconSize = tonumber(sRest)
				print("[AuctionHouseRunes] Rune icon size set to " .. tostring(self.settings.nIconSize) .. ". Please close and reopen the auction house.")
			end
		end
	end
	
	if bValid == false then
		print("[AuctionHouseRunes] Usage:")
		print("/ahr icon show|hide - shows or hides the rune icons (Default show)")
		print("/ahr size XX - sets the rune icon size (Default 28)")
		print("/ahr name show|hide - shows or hides the rune names (Default show)")
	end
end

function AuctionHouseRunes:InitializeLogger()
	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	Logger = GeminiLogging:GetLogger({
		level = GeminiLogging.DEBUG,
		pattern = "%d [%c:%n] %l - %m",
		appender = "GeminiConsole"
	})
	Logger:debug("Logger Initialized")
end

-----------------------------------------------------------------------------------------------
-- Hook Functions
-----------------------------------------------------------------------------------------------
function AuctionHouseRunes:InstallAuctionHouseHook()
	local oAuctionHouse
	for i, addonName in ipairs(ktAuctionHouseAddons) do
		oAuctionHouse = Apollo.GetAddon(addonName)
		
		if oAuctionHouse ~= nil then
			break
		end
	end
	
	if oAuctionHouse == nil then
		return false
	end
	self.oAuctionHouse = oAuctionHouse
	
	self:PostHook(self.oAuctionHouse, "BuildListItem", "Hook_BuildListItem")
	self:PostHook(self.oAuctionHouse, "InitializeSell", "Hook_InitializeSell")
	self:PostHook(self.oAuctionHouse, "OnSellListItemCheck", "Hook_OnSellListItemCheck")
	self:PostHook(self.oAuctionHouse, "OnSellListItemUncheck", "Hook_OnSellListItemUncheck")
	
	return true
end

function AuctionHouseRunes:Hook_BuildListItem(luaCaller, aucCurr, wndParent, bBuyTab)
	local tItem = aucCurr:GetItem()
	local tSigils = tItem:GetRuneSlots()
	
	local wndItemContainers = wndParent:GetChildren()
	local wndItemContainer = wndItemContainers[#wndItemContainers]
	
	if tSigils ~= nil and tSigils.bIsDefined then
		local wndRuneContainer = Apollo.LoadForm(self.xmlDoc, "RuneContainer", wndItemContainer, self)
		local nRuneWidth = (self.settings.nIconSize >= 36) and self.settings.nIconSize or ktMinWidth
		local width, height = 0, 0
		
		for i, tSigil in ipairs(tSigils.arRuneSlots) do
			local wndRune = Apollo.LoadForm(self.xmlDoc, "Rune", wndRuneContainer, self)
			local wndIcon = wndRune:FindChild("Icon")
			local wndName = wndRune:FindChild("Name")
			wndIcon:SetSprite("Crafting_RunecraftingSprites:sprRunecrafting_" .. ktRuneNames[tSigil.eType])
			wndIcon:SetAnchorOffsets(-(self.settings.nIconSize / 2), 0, (self.settings.nIconSize / 2), self.settings.nIconSize)
			wndIcon:Show(self.settings.bRuneIcons)
			local tIconOffsets = {wndIcon:GetAnchorOffsets()}
			
			local nNameTop = (wndIcon:IsShown() and tIconOffsets[4] or 0)
			wndName:SetText(tSigil.strName)
			wndName:SetAnchorOffsets(-(nRuneWidth / 2), nNameTop, (nRuneWidth / 2), nNameTop + 12)
			wndName:Show(self.settings.bRuneNames)
			
			if height == 0 then
				height	= (wndIcon:IsShown() and wndIcon:GetHeight() or 0) + (wndName:IsShown() and wndName:GetHeight() or 0)
			end
			
			local tOffsets = {wndRune:GetAnchorOffsets()}
			wndRune:SetAnchorOffsets(tOffsets[1], tOffsets[2], nRuneWidth, tOffsets[2] + height)
		end
		
		wndRuneContainer:ArrangeChildrenHorz()
		
		local tOffsets = {wndRuneContainer:GetAnchorOffsets()}
		wndRuneContainer:SetAnchorOffsets(tOffsets[3] - (nRuneWidth * #wndRuneContainer:GetChildren()), tOffsets[4] - height, tOffsets[3], tOffsets[4])
	end
	
	local itemQualityColor = ktEvalColors[tItem:GetItemQuality()]
	local tItemIconPixie = {
		bLine = false,
		bRestart = true,
		cr = itemQualityColor,
		strSprite = "BK3:UI_BK3_ItemQualityWhite",
		loc = {
			fPoints = {0, 0, 1, 1},
			nOffsets = {0,0,0,0}
		}
	}	
	wndItemContainer:FindChild("ListIcon"):AddPixie(tItemIconPixie)
	
	wndItemContainer:FindChild("ListName"):SetTextColor(itemQualityColor)
	
	local tActivateSpell = tItem:GetActivateSpell()
	local tTradeskillRequirements = tActivateSpell and tActivateSpell:GetTradeskillRequirements()
	if tTradeskillRequirements and tTradeskillRequirements.bIsKnown then
		wndItemContainer:FindChild("ListName"):SetText(wndItemContainer:FindChild("ListName"):GetText() .. " (Known)")
		wndItemContainer:FindChild("ListName"):SetTextColor("UI_WindowTextRed")
	end
end

function AuctionHouseRunes:Hook_InitializeSell(luaCaller)
	local wndItemSellList = luaCaller.wndMain:FindChild("SellLeftSideItemList")
	if wndItemSellList ~= nil and #wndItemSellList:GetChildren() > 0 then
		for idx, wndSellItem in ipairs(wndItemSellList:GetChildren()) do
			if wndSellItem:FindChild("ListItemTitle"):GetTextColor() ~= "UI_BtnTextGrayListNormal" then
				local tItem = wndSellItem:GetData()
				local itemQualityColor = ktEvalColors[tItem:GetItemQuality()]
				wndSellItem:FindChild("ListItemTitle"):SetTextColor(itemQualityColor)
				
				local tItemIconPixie = {
					bLine = false,
					bRestart = true,
					cr = itemQualityColor,
					strSprite = "BK3:UI_BK3_ItemQualityWhite",
					loc = {
						fPoints = {0, 0, 1, 1},
						nOffsets = {0,0,0,0}
					}
				}
				wndSellItem:FindChild("ListItemIcon"):AddPixie(tItemIconPixie)
				
				-- Maybe add runes
				local tSigils = tItem:GetRuneSlots()
				if tSigils ~= nil and tSigils.bIsDefined then
					local tOffsets = {wndSellItem:GetAnchorOffsets()}
					wndSellItem:SetAnchorOffsets(tOffsets[1], tOffsets[2], tOffsets[3], tOffsets[4] + 18)
					
					local tTitleOffsets = {wndSellItem:FindChild("ListItemTitle"):GetAnchorOffsets()}
					local nTitleHeight = wndSellItem:FindChild("ListItemTitle"):GetHeight()
					wndSellItem:FindChild("ListItemTitle"):SetAnchorPoints(0, 0, 1, 0)
					wndSellItem:FindChild("ListItemTitle"):SetAnchorOffsets(tTitleOffsets[1], tTitleOffsets[2], tTitleOffsets[3], tTitleOffsets[2] + nTitleHeight)
					
					local tIconOffsets = {wndSellItem:FindChild("ListItemIcon"):GetAnchorOffsets()}
					wndSellItem:FindChild("ListItemIcon"):SetAnchorPoints(0, 0, 0, 0)
					wndSellItem:FindChild("ListItemIcon"):SetAnchorOffsets(tIconOffsets[1], tIconOffsets[2], tIconOffsets[3], tIconOffsets[2] + (tIconOffsets[3] - tIconOffsets[1]))
					
					local wndRuneContainer = Apollo.LoadForm(self.xmlDoc, "RuneContainer", wndSellItem, self)
					local nRuneWidth = 16
					local width, height = 0, 0
					
					for i, tSigil in ipairs(tSigils.arRuneSlots) do
						local wndRune = Apollo.LoadForm(self.xmlDoc, "Rune", wndRuneContainer, self)
						local wndIcon = wndRune:FindChild("Icon")
						wndRune:FindChild("Name"):Show(false) -- Not enough room for names
						wndIcon:SetSprite("Crafting_RunecraftingSprites:sprRunecrafting_" .. ktRuneNames[tSigil.eType])
						wndIcon:SetAnchorOffsets(-10, 0, 10, 20)
						wndIcon:Show(true)
						local tIconOffsets = {wndIcon:GetAnchorOffsets()}
						
						if height == 0 then
							height	= (wndIcon:IsShown() and wndIcon:GetHeight() or 0)
						end
						
						local tOffsets = {wndRune:GetAnchorOffsets()}
						wndRune:SetAnchorOffsets(tOffsets[1], tOffsets[2], nRuneWidth, tOffsets[2] + height)
					end
					
					wndRuneContainer:ArrangeChildrenHorz()
					
					local tOffsets = {wndRuneContainer:GetAnchorOffsets()}
					wndRuneContainer:SetAnchorPoints(0, 1, 0, 1)
					wndRuneContainer:SetAnchorOffsets(5, -2 - height, 5 + (nRuneWidth * #wndRuneContainer:GetChildren()), -2)
					--wndRuneContainer:SetAnchorOffsets(tOffsets[3] - (nRuneWidth * #wndRuneContainer:GetChildren()), tOffsets[4] - height, tOffsets[3], tOffsets[4])
				end
			end
		end
		wndItemSellList:ArrangeChildrenVert(0, function (a,b) return a:GetName() < b:GetName() end)
	end
end

function AuctionHouseRunes:Hook_OnSellListItemCheck(luaCaller, wndHandler, wndControl)
	local itemQualityColor = ktEvalColors[wndHandler:GetData():GetItemQuality()]
	wndHandler:FindChild("ListItemTitle"):SetTextColor(itemQualityColor)
	
	local tItemIconPixie = {
		bLine = false,
		bRestart = true,
		cr = itemQualityColor,
		strSprite = "BK3:UI_BK3_ItemQualityWhite",
		loc = {
			fPoints = {0, 0, 1, 1},
			nOffsets = {0,0,0,0}
		}
	}	
	
	local wndRightSide = luaCaller.wndMain:FindChild("SellRightSide")
	wndRightSide:FindChild("BigIcon"):AddPixie(tItemIconPixie)
	
	wndRightSide:FindChild("BigItemName"):SetTextColor(itemQualityColor)
	
	-- Add runes
end

function AuctionHouseRunes:Hook_OnSellListItemUncheck(luaCaller, wndHandler, wndControl)
	local tItem = wndHandler:GetData()
	if tItem ~= nil then
		local itemQualityColor = ktEvalColors[tItem:GetItemQuality()]
		local wndItemTitle = wndHandler:FindChild("ListItemTitle")
		if wndItemTitle ~= nil then
			wndItemTitle:SetTextColor(itemQualityColor)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------------------------------------------
function copyTable(orig)
	local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[copyTable(orig_key)] = copyTable(orig_value)
        end
        setmetatable(copy, copyTable(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function mergeTables(t1, t2)
    for k, v in pairs(t2) do
    	if type(v) == "table" then
			if t1[k] then
	    		if type(t1[k] or false) == "table" then
	    			mergeTables(t1[k] or {}, t2[k] or {})
	    		else
	    			t1[k] = v
	    		end
			else
				t1[k] = {}
    			mergeTables(t1[k] or {}, t2[k] or {})
			end
    	else
    		t1[k] = v
    	end
    end
    return t1
end
