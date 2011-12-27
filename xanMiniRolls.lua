--This is my take on a Loot Parser
--Special thanks to Tekkub for GreedBeacon

local f = CreateFrame("frame","xanMiniRolls",UIParent)
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

--lets edit the constants and replace wildcards to make it easier to use with string.match ;0)
--Note we have to get ride of the hyphens cause it screws up the matches ;0)

--LOOT_ROLL_ROLLED_DE = "Disenchant Roll - %d for %s by %s";
--LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s";
--LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s";

local playerRolls = {
	[(LOOT_ROLL_ROLLED_DE):gsub("%%d", "(%%d+)"):gsub("%%s", "(.+)"):gsub(".(- )"," ", 1)] = "Disenchant",  --1 at the end is only replace first occurance :P
	[(LOOT_ROLL_ROLLED_GREED):gsub("%%d", "(%%d+)"):gsub("%%s", "(.+)"):gsub(".(- )"," ", 1)] = "Greed",
	[(LOOT_ROLL_ROLLED_NEED):gsub("%%d", "(%%d+)"):gsub("%%s", "(.+)"):gsub(".(- )"," ", 1)] = "Need"
}

--LOOT_ROLL_DISENCHANT = "%s has selected Disenchant for: %s";
--LOOT_ROLL_DISENCHANT_SELF = "You have selected Disenchant for: %s";
--LOOT_ROLL_GREED = "%s has selected Greed for: %s";
--LOOT_ROLL_GREED_SELF = "You have selected Greed for: %s";
--LOOT_ROLL_NEED = "%s has selected Need for: %s";
--LOOT_ROLL_NEED_SELF = "You have selected Need for: %s";

local playerSelections = {
	[(LOOT_ROLL_DISENCHANT):gsub("%%s", "(.+)")] = "Disenchant",
	[(LOOT_ROLL_DISENCHANT_SELF):gsub("%%s", "(.+)")] = "Disenchant",
	[(LOOT_ROLL_GREED):gsub("%%s", "(.+)")] = "Greed",
	[(LOOT_ROLL_GREED_SELF):gsub("%%s", "(.+)")] = "Greed",
	[(LOOT_ROLL_NEED):gsub("%%s", "(.+)")] = "Need",
	[(LOOT_ROLL_NEED_SELF):gsub("%%s", "(.+)")] = "Need"
}

-- LOOT_ROLL_WON = "%s won: %s";
-- LOOT_ROLL_YOU_WON = "You won: %s";

local playerWon = {
	[(LOOT_ROLL_WON):gsub("%%s", "(.+)")] = "Need",
	[(LOOT_ROLL_YOU_WON):gsub("%%s", "(.+)")] = "Need"
}

--LOOT_ROLL_PASSED = "%s passed on: %s";
--LOOT_ROLL_PASSED_AUTO = "%s automatically passed on: %s because he cannot loot that item.";
--LOOT_ROLL_PASSED_AUTO_FEMALE = "%s automatically passed on: %s because she cannot loot that item.";
--LOOT_ROLL_PASSED_SELF = "You passed on: %s";
--LOOT_ROLL_PASSED_SELF_AUTO = "You automatically passed on: %s because you cannot loot that item.";

local playerPassed = GetLocale() == "deDE" and {
	[(LOOT_ROLL_PASSED):gsub("%%s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_AUTO):gsub("%%1$s", "(.+)"):gsub("%%2$s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_AUTO_FEMALE):gsub("%%1$s", "(.+)"):gsub("%%2$s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_SELF):gsub("%%s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_SELF_AUTO):gsub("%%s", "(.+)")] = "Pass"
}
or {
	[(LOOT_ROLL_PASSED):gsub("%%s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_AUTO):gsub("%%s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_AUTO_FEMALE):gsub("%%s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_SELF):gsub("%%s", "(.+)")] = "Pass",
	[(LOOT_ROLL_PASSED_SELF_AUTO):gsub("%%s", "(.+)")] = "Pass"
}

local rollList = {}

local selectionColors = {
	["Greed"] = "|cff3bed2e",
	["Disenchant"] = "|cff8080ff",
    ["Need"] = "|cffc84b4b"
}

----------------------
--      Enable      --
----------------------

function f:PLAYER_LOGIN()

	local ver = GetAddOnMetadata("xanMiniRolls","Version") or '1.0'
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF99CC33%s|r [v|cFFDF2B2B%s|r] Loaded", "xanMiniRolls", ver or "1.0"))
	
	if tonumber(GetCVar("showLootSpam")) < 1 then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33xanMiniRolls|r Warning you must turn on 'Detailed Loot Information' under Interface options for this addon to function properly!")
	end

	f:RegisterEvent("CHAT_MSG_LOOT")
	f:UnregisterEvent("PLAYER_LOGIN")
	f.PLAYER_LOGIN = nil
end

local function sendLootMsg(msg)
	--this function will only send the loot messages to those chatwindows that have the LOOT type enabled
	for i=1, NUM_CHAT_WINDOWS do
		local cName = ("ChatFrame%d"):format(i)
		--check messagetypes
		for k, v in pairs(_G[cName].messageTypeList) do
			if v == "LOOT" then
				_G[cName]:AddMessage(msg)
			end
		end
	end
end

local function checkRollList(link, playerName, hasRolled, loadWinner)
	
	--only keep 30 entries
	if table.getn(rollList) > 30 then table.remove(rollList, 1) end

	--this simple function will keep track of our rolls in a table, using the player name, itemlink, and wether or not there is a winner
	--in order to keep things clean, were going to check for items that either have a winner or not as well if a player has already done a roll
	for k, v in ipairs(rollList) do
		--check for a winner, then a matching itemLink, then wether a player has inputed already
		if not v.winner and v.itemLink == link and (not v[playerName] or hasRolled) then
			return v
		elseif not v.winner and loadWinner and v.itemLink == link and v[playerName] then
			--this is only used for the won scenario, only retrieve one that doesn't have a winner and that hasn't already had the roll completed
			return v, k
		end
	end
	
	--couldn't find a winner so return nil, to ignore
	if loadWinner then return nil end
	
	--we didn't find anything so create a new entry
	local tmpRoll = {itemLink = link}
	table.insert(rollList, tmpRoll)
	return tmpRoll
end

------------------------------
--      Event Handlers      --
------------------------------

function f:CHAT_MSG_LOOT(event, msg, sender, lang, channelString, target, flags, arg0, channelNumber, channelName, arg1, counter)

	--if detailed loot information is off then don't even bother
	if tonumber(GetCVar("showLootSpam")) < 1 then return end
	
	--check to see if a roll was done (with value)
	for str, rType in pairs(playerRolls) do
		local val, link, player = msg:gsub(".(- )"," ", 1):match(str) --remove first hyphen
		if player and val and link then
			local tmpRoll = checkRollList(link, player, true)
			tmpRoll[player] = {rollValue = val, rollType = rType}
			return
		end
	end
	
	--check to see if a selection was done
	for str, rType in pairs(playerSelections) do
		local player, link = msg:match(str)
		if player then
			--fix for 'You' issues
			if not link then
				link = player
				player = UnitName("player")
			end
			player = player == YOU and UnitName("player") or player

			local tmpRoll = checkRollList(link, player)
			tmpRoll[player] = {rollValue = 0, rollType = rType}
			return
		end
	end
	
	--check for a winner
	for str, rType in pairs(playerWon) do
		local player, link = msg:match(str)
		if player then
			--fix for 'You' issues
			if not link then
				link = player
				player = UnitName("player")
			end
			player = player == YOU and UnitName("player") or player
			
			local tmpRoll, index = checkRollList(link, player, false, true)
			if tmpRoll and index then
				tmpRoll.winner = player
				local msg = string.format("%s|Hxanminirolls:%d|h[%s]|h|r %s won %s ", selectionColors[tmpRoll[player].rollType], index, tmpRoll[player].rollType, player, link)
				sendLootMsg(msg)
			end
			return
		end
	end
	
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", function(self, event, msg)

	--if detailed loot information is off then don't even bother
	if tonumber(GetCVar("showLootSpam")) < 1 then return false end
	
	--here we will allow need rolls to pass through the filter, that way we can see if we need to press NEED on an item to prevent ninjas and such
	--or if your not sure if you need to press NEED, sometimes I see it's better to just see it then hide it, for specific situations
	--especially if I feel I should only press NEED only if someone else presses NEED on an item that I want

	--don't filter out need selections
	if msg:match((LOOT_ROLL_NEED):gsub("%%s", "(.+)")) or msg:match((LOOT_ROLL_NEED_SELF):gsub("%%s", "(.+)")) then
		return false
	end

	--check rolls
	for str, rType in pairs(playerRolls) do
		local val, link, player = msg:gsub(".(- )"," ", 1):match(str) --remove first hyphen
		if player and val and link then
			return true
		end
	end

	--check selections
	for str, rType in pairs(playerSelections) do
		local player, link = msg:match(str)
		if player then
			return true
		end
	end
	
	--check winners
	for str, rType in pairs(playerWon) do
		local player, link = msg:match(str)
		if player then
			return true
		end
	end
	
	--check pass
	for str, rType in pairs(playerPassed) do
		local player = msg:match(str)
		if player then
			return true
		end
	end	

end)

local orig2 = SetItemRef
function SetItemRef(link, text, button)
	local id = link:match("xanminirolls:(%d+)")
	if id and tonumber(id) and rollList[tonumber(id)] then
	
		ShowUIPanel(ItemRefTooltip)
		if not ItemRefTooltip:IsShown() then ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE") end
		
		local tmpRoll = rollList[tonumber(id)]
		local rollType = tmpRoll[tmpRoll.winner].rollType
		ItemRefTooltip:ClearLines()
		ItemRefTooltip:AddLine(selectionColors[rollType]..rollType.."|r - "..tmpRoll.itemLink)
		ItemRefTooltip:AddDoubleLine("Winner:", "|cFF99CC33"..tmpRoll.winner.."|r")
		for k, v in pairs(tmpRoll) do
			if k ~= "itemLink" and k ~= "winner" then
				local msg = string.format("|cffffffff%s|r  (%s%s|r)", k, selectionColors[v.rollType], v.rollType)
				ItemRefTooltip:AddDoubleLine(msg, v.rollValue)
			end
		end
		ItemRefTooltip:Show()
	else
		return orig2(link, text, button)
	end
end

if IsLoggedIn() then f:PLAYER_LOGIN() else f:RegisterEvent("PLAYER_LOGIN") end
