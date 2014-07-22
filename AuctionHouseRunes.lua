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
local ktVersion = {nMajor = 1, nMinor = 0, nPatch = 0}

local ktDefaultSettings = {
	tVersion = {
		nMajor = ktVersion.nMajor,
		nMinor = ktVersion.nMinor,
		nPatch = ktVersion.nPatch
	},
	bRuneIcons = true,
	bRuneNames = true
}

local ktAuctionHouseAddons = {
	"MarketplaceAuction"
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
	local bValid = false
	if sParam then
		if string.sub(sParam, 1, string.len("icon")) == "icon" then
			local sRest = string.lower(string.sub(sParam, string.len("icon") + 2))
			if sRest == "on" or sRest == "show" then
				bValid = true
				self.settings.bRuneIcons = true
				Print("[AuctionHouseRunes] Rune icons shown. Please close and reopen the auction house.")
			elseif sRest == "off" or sRest == "hide" then
				bValid = true
				self.settings.bRuneIcons = false
				Print("[AuctionHouseRunes] Rune icons hidden. Please close and reopen the auction house.")
			end
		elseif string.sub(sParam, 1, string.len("name")) == "name" then
			local sRest = string.lower(string.sub(sParam, string.len("name") + 2))
			if sRest == "on" or sRest == "show" then
				bValid = true
				self.settings.bRuneNames = true
				Print("[AuctionHouseRunes] Rune names shown. Please close and reopen the auction house.")
			elseif sRest == "off" or sRest == "hide" then
				bValid = true
				self.settings.bRuneNames = false
				Print("[AuctionHouseRunes] Rune names hidden. Please close and reopen the auction house.")
			end
		end
	end
	
	if bValid == false then
		Print("[AuctionHouseRunes] Usage:")
		Print("/ahr icon show|hide - shows or hides the rune icons")
		Print("/ahr name show|hide - shows or hides the rune names")
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
	
	return true
end

function AuctionHouseRunes:Hook_BuildListItem(luaCaller, aucCurr, wndParent, bBuyTab)
	if bBuyTab == true then
		local tItem = aucCurr:GetItem()
		local tSigils = tItem:GetSigils()
		
		if tSigils ~= nil and tSigils.bIsDefined then
			local wndItemContainers = wndParent:GetChildren()
			local wndItemContainer = wndItemContainers[#wndItemContainers]
			local wndRuneContainer = Apollo.LoadForm(self.xmlDoc, "RuneContainer", wndItemContainer, self)
			local width, height = 0, 0
			
			for i, tSigil in ipairs(tSigils.arSigils) do
				local wndRune = Apollo.LoadForm(self.xmlDoc, "Rune", wndRuneContainer, self)
				wndRune:FindChild("Icon"):SetSprite("Crafting_RunecraftingSprites:sprRunecrafting_" .. tSigil.strName) -- TODO: Works with i18n?
				wndRune:FindChild("Icon"):Show(self.settings.bRuneIcons)
				wndRune:FindChild("Name"):SetText(tSigil.strName)
				wndRune:FindChild("Name"):Show(self.settings.bRuneNames)
				
				width = width + wndRune:GetWidth()
				
				if height == 0 then
					height	= (self.settings.bRuneIcons and wndRune:FindChild("Icon"):GetHeight() or 0) + (self.settings.bRuneNames and wndRune:FindChild("Name"):GetHeight() or 0) + 2
				end
				
				if self.settings.bRuneIcons == false and self.settings.bRuneNames == true then
					local tOffsets = {wndRune:GetAnchorOffsets()}
					wndRune:SetAnchorOffsets(tOffsets[1], tOffsets[2], tOffsets[3], tOffsets[2] + height)
				end
			end
			
			wndRuneContainer:ArrangeChildrenHorz()
			
			local tOffsets = {wndRuneContainer:GetAnchorOffsets()}
			wndRuneContainer:SetAnchorOffsets(tOffsets[3] - width, tOffsets[4] - height, tOffsets[3], tOffsets[4])
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
