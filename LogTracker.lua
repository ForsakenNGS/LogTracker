local _, L = ...;

LogTracker = CreateFrame("Frame", "LogTracker", UIParent);

function LogTracker:Init()
  self.debug = false;
  self.defaults = {
    chatExtension = true,
    tooltipExtension = true,
    lfgExtension = true,
    slashExtension = true,
    hide10Player = false,
    hide25Player = false
  };
  self.activityDetails = {
    -- Naxxramas 10-man
    [841] = {
      zone = 1015,
      size = 10,
      encounters = { 101107, 101108, 101109, 101110, 101111, 101112, 101113, 101114, 101115, 101116, 101117, 101118, 101119, 101120, 101121 }
    },
    -- The Obsidian Sanctum 10-man
    [1101] = {
      zone = 1015,
      size = 10,
      encounters = { 742 }
    },
    -- The Eye of Eternity 10-man
    [1102] = {
      zone = 1015,
      size = 10,
      encounters = { 734 }
    },
    -- Vault of Archavon 10-man
    [1095] = {
      zone = 1016,
      size = 10,
      encounters = { 772 }
    },
    -- Naxxramas 25-man
    [1098] = {
      zone = 1015,
      size = 25,
      encounters = { 101107, 101108, 101109, 101110, 101111, 101112, 101113, 101114, 101115, 101116, 101117, 101118, 101119, 101120, 101121 }
    },
    -- The Obsidian Sanctum 25-man
    [1097] = {
      zone = 1015,
      size = 25,
      encounters = { 742 }
    },
    -- The Eye of Eternity 25-man
    [1094] = {
      zone = 1015,
      size = 25,
      encounters = { 734 }
    },
    -- Vault of Archavon 25-man
    [1096] = {
      zone = 1016,
      size = 25,
      encounters = { 772 }
    },
  };
  self.db = CopyTable(self.defaults);
  self:LogDebug("Init");
  self:SetScript("OnEvent", self.OnEvent);
  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("CHAT_MSG_SYSTEM");
  self:RegisterEvent("MODIFIER_STATE_CHANGED");
  self:RegisterEvent("PLAYER_ENTERING_WORLD");
  --self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
  GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip, ...)
    LogTracker:OnTooltipSetUnit(tooltip, ...);
  end);
  GameTooltip:HookScript("OnShow", function(tooltip, ...)
    LogTracker:OnTooltipShow(tooltip, ...);
  end);
end

function LogTracker:InitLogsFrame()
  local urlRegion = "";
  local urlRegionId = GetCurrentRegion();
  if (urlRegionId == 1) then
    urlRegion = "us";
  elseif (urlRegionId == 2) then
    urlRegion = "kr";
  elseif (urlRegionId == 3) then
    urlRegion = "eu";
  elseif (urlRegionId == 4) then
    urlRegion = "tw";
  elseif (urlRegionId == 5) then
    urlRegion = "ch";
  end
  local urlBase = "https://classic.warcraftlogs.com/character/"..urlRegion.."/"..strlower(GetRealmName()).."/";
  self.warcraftlogsFrame = CreateFrame("Frame", nil, UIParent, "DialogBorderTemplate");
  self.warcraftlogsFrame:ClearAllPoints();
  self.warcraftlogsFrame:SetPoint("TOPLEFT", 50, -50);
  self.warcraftlogsFrame:SetSize(160, 124);
  self.warcraftlogsFrame:Hide();
  self.warcraftlogsFrame.Title = self.warcraftlogsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
  self.warcraftlogsFrame.Title:ClearAllPoints();
  self.warcraftlogsFrame.Title:SetPoint("TOPLEFT", 18, -15);
  self.warcraftlogsFrame.Title:SetText("WarcraftLogs");
  self.warcraftlogsFrame.Title:SetTextColor(1, 1, 1);
  self.warcraftlogsFrame.CharacterLabel = self.warcraftlogsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
  self.warcraftlogsFrame.CharacterLabel:ClearAllPoints();
  self.warcraftlogsFrame.CharacterLabel:SetPoint("TOPLEFT", 18, -35);
  self.warcraftlogsFrame.CharacterLabel:SetText("Character");
  self.warcraftlogsFrame.CharacterLabel:SetJustifyH("LEFT");
  self.warcraftlogsFrame.CharacterDropdown = CreateFrame("Button", nil, self.warcraftlogsFrame, "UIDropDownMenuTemplate");
  self.warcraftlogsFrame.CharacterDropdown:ClearAllPoints();
  self.warcraftlogsFrame.CharacterDropdown:SetPoint("TOPLEFT", -4, -46);
  self.warcraftlogsFrame.CharacterDropdown:SetPoint("TOPRIGHT", -18, -46);
  self.warcraftlogsFrame.CharacterDropdown:SetScript("OnClick", function()
    ToggleDropDownMenu(1, nil, self.warcraftlogsFrame.CharacterDropdown, self.warcraftlogsFrame.CharacterDropdown, 0, 0);
  end);
  self.warcraftlogsFrame.CharacterDropdown.values = {};
  self.warcraftlogsFrame.CharacterName = self.warcraftlogsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
  self.warcraftlogsFrame.CharacterName:ClearAllPoints();
  self.warcraftlogsFrame.CharacterName:SetPoint("TOPLEFT", 18, -54);
  self.warcraftlogsFrame.CharacterName:SetText("TODO");
  self.warcraftlogsFrame.CharacterName:SetJustifyH("LEFT");
  self.warcraftlogsFrame.UrlLabel = self.warcraftlogsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
  self.warcraftlogsFrame.UrlLabel:ClearAllPoints();
  self.warcraftlogsFrame.UrlLabel:SetPoint("TOPLEFT", 18, -75);
  self.warcraftlogsFrame.UrlLabel:SetText("Profile URL");
  self.warcraftlogsFrame.UrlLabel:SetJustifyH("LEFT");
  self.warcraftlogsFrame.Url = CreateFrame("EditBox", nil, self.warcraftlogsFrame, "InputBoxTemplate");
  self.warcraftlogsFrame.Url:ClearAllPoints();
  self.warcraftlogsFrame.Url:SetAutoFocus(false);
  self.warcraftlogsFrame.Url:SetPoint("TOPLEFT", 20, -88);
  self.warcraftlogsFrame.Url:SetPoint("TOPRIGHT", -14, -88);
  self.warcraftlogsFrame.Url:SetHeight(20);
  self.warcraftlogsFrame.Url:SetText("TODO");
  local characterDropdownClick = function(dropdown)
    UIDropDownMenu_SetSelectedValue(dropdown.owner, dropdown.value);
    self.warcraftlogsFrame.Url:SetText(urlBase..strlower(dropdown.value));
  end
  local characterDropdownInit = function(dropdown)
		for i=1, #dropdown.values do
      local info = UIDropDownMenu_CreateInfo();
      info.text = dropdown.values[i].text;
      info.value = dropdown.values[i].value;
      info.owner = dropdown;
      info.checked = UIDropDownMenu_GetSelectedValue(dropdown) == info.value;
      info.func = characterDropdownClick;
      UIDropDownMenu_AddButton(info);
			if (info.checked) then
				UIDropDownMenu_SetSelectedValue(dropdown, info.value);
      end
    end
  end
  UIDropDownMenu_Initialize(self.warcraftlogsFrame.CharacterDropdown, characterDropdownInit);
  UIDropDownMenu_JustifyText(self.warcraftlogsFrame.CharacterDropdown, "LEFT");
  LFGBrowseFrame:HookScript("OnShow", function()
    self.warcraftlogsFrame:SetPoint("TOPLEFT", LFGBrowseFrame, "TOPRIGHT", -30, -10);
  end);
  LFGBrowseFrame:HookScript("OnHide", function()
    self.warcraftlogsFrame:Hide();
  end);
  hooksecurefunc("LFGBrowseSearchEntry_OnClick", function(lfg, button)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(lfg.resultID);
    local numMembers = searchResultInfo.numMembers;
    if (numMembers > 1) then
      -- Group
      local selectedValue = nil;
      wipe(self.warcraftlogsFrame.CharacterDropdown.values);
      for i=1, numMembers do
        local name, role, classFileName, className, level, isLeader = C_LFGList.GetSearchResultMemberInfo(lfg.resultID, i);
        if name then
          local classColor = RAID_CLASS_COLORS[classFileName];
          tinsert(self.warcraftlogsFrame.CharacterDropdown.values, {
            text = "|cff"..string.format("%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255)..name.."|r",
            value = name
          });
          if isLeader then
            selectedValue = name;
          end
        end
      end
      self.warcraftlogsFrame.CharacterName:Hide();
      self.warcraftlogsFrame.CharacterDropdown:Show();
      UIDropDownMenu_Initialize(self.warcraftlogsFrame.CharacterDropdown, characterDropdownInit);
      if selectedValue then
        UIDropDownMenu_SetSelectedValue(self.warcraftlogsFrame.CharacterDropdown, selectedValue);
        self.warcraftlogsFrame.Url:SetText(urlBase..strlower(selectedValue));
      end
      self.warcraftlogsFrame:Show();
    elseif (numMembers == 1) then
      -- Player
      local name, role, classFileName, className, level, areaName, soloRoleTank, soloRoleHealer, soloRoleDPS = C_LFGList.GetSearchResultLeaderInfo(lfg.resultID);
      local classColor = RAID_CLASS_COLORS[classFileName];
      self.warcraftlogsFrame.CharacterName:SetTextColor(classColor.r, classColor.g, classColor.b);
      self.warcraftlogsFrame.CharacterName:SetText(name);
      self.warcraftlogsFrame.CharacterName:Show();
      self.warcraftlogsFrame.Url:SetText(urlBase..strlower(name));
      self.warcraftlogsFrame.CharacterDropdown:Hide();
      self.warcraftlogsFrame:Show();
    else
      self.warcraftlogsFrame:Hide();
    end
  end);
end

function LogTracker:InitOptions()
  self.optionsPanel = CreateFrame("Frame");
  self.optionsPanel.name = "LogTracker";
  InterfaceOptions_AddCategory(self.optionsPanel);
  -- Chat integration
  self.optionCheckChat = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
	self.optionCheckChat:SetPoint("TOPLEFT", 20, -20);
	self.optionCheckChat.Text:SetText(L["OPTION_CHAT"]);
	self.optionCheckChat:SetScript("OnClick", function()
		self.db.chatExtension = self.optionCheckChat:GetChecked();
	end)
	self.optionCheckChat:SetChecked(self.db.chatExtension);
  -- Player tooltip integration
  self.optionCheckTooltip = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
	self.optionCheckTooltip:SetPoint("TOPLEFT", 20, -40);
	self.optionCheckTooltip.Text:SetText(L["OPTION_TOOLTIP"]);
	self.optionCheckTooltip:SetScript("OnClick", function()
		self.db.tooltipExtension = self.optionCheckTooltip:GetChecked();
	end)
	self.optionCheckTooltip:SetChecked(self.db.tooltipExtension);
  -- Player tooltip integration
  self.optionCheckLFG = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
	self.optionCheckLFG:SetPoint("TOPLEFT", 20, -60);
	self.optionCheckLFG.Text:SetText(L["OPTION_LFG"]);
	self.optionCheckLFG:SetScript("OnClick", function(_, value)
		self.db.lfgExtension = self.optionCheckLFG:GetChecked();
	end)
	self.optionCheckLFG:SetChecked(self.db.lfgExtension);
  -- Slash command
  self.optionCheckSlash = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
	self.optionCheckSlash:SetPoint("TOPLEFT", 20, -80);
	self.optionCheckSlash.Text:SetText(L["OPTION_SLASH_CMD"]);
	self.optionCheckSlash:SetScript("OnClick", function(_, value)
		self.db.slashExtension = self.optionCheckSlash:GetChecked();
	end)
	self.optionCheckSlash:SetChecked(self.db.slashExtension);
  -- Show 10 player logs
  self.optionHide10Player = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
	self.optionHide10Player:SetPoint("TOPLEFT", 20, -100);
	self.optionHide10Player.Text:SetText(L["OPTION_HIDE_10_PLAYER"]);
	self.optionHide10Player:SetScript("OnClick", function(_, value)
		self.db.hide10Player = self.optionHide10Player:GetChecked();
	end)
	self.optionHide10Player:SetChecked(self.db.hide10Player);
  -- Show 25 player logs
  self.optionHide25Player = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
	self.optionHide25Player:SetPoint("TOPLEFT", 20, -120);
	self.optionHide25Player.Text:SetText(L["OPTION_HIDE_25_PLAYER"]);
	self.optionHide25Player:SetScript("OnClick", function(_, value)
		self.db.hide25Player = self.optionHide25Player:GetChecked();
	end)
	self.optionHide25Player:SetChecked(self.db.hide25Player);
end

function LogTracker:LogOutput(...)
  print("|cffff0000LT|r", ...);
end

function LogTracker:LogDebug(...)
  if self.debug then
    print("|cffff0000LT|r", "|cffffff00Debug|r", ...);
  end
end

function LogTracker:AddPlayerInfoToTooltip(targetName)
  local playerData, playerName, playerRealm = self:GetPlayerData(targetName);
  if playerData then
    self:SetPlayerInfoTooltip(playerData, playerName, playerRealm);
  end
end

function LogTracker:OnSlashCommand(arguments)
  if not self.db.slashExtension then
    return;
  end
  --self:LogOutput("OnSlashCommand", arguments);
  local playerData, playerName, playerRealm = self:GetPlayerData(arguments);
  if playerData then
    self:SendSystemChatLine(L["CHAT_PLAYER_DETAILS"].." |Hplayer:"..playerName.."-"..playerRealm.."|h"..playerName.."|h");
    self:SendPlayerInfoToChat(playerData, playerName, playerRealm, true);
  else
    self:SendSystemChatLine(L["CHAT_PLAYER_NOT_FOUND"].." |Hplayer:"..playerName.."-"..playerRealm.."|h"..playerName.."|h");
  end
end

function LogTracker:OnEvent(event, ...)
  if (event == "ADDON_LOADED") then
    self:OnAddonLoaded(...);
  elseif (event == "CHAT_MSG_SYSTEM") then
    self:OnChatMsgSystem(...);
  elseif (event == "UPDATE_MOUSEOVER_UNIT") then
    self:OnMouseoverUnit(...);
  elseif (event == "MODIFIER_STATE_CHANGED") then
    self:OnModifierStateChanged(...);
  elseif (event == "PLAYER_ENTERING_WORLD") then
    -- Workaround for misaligned tooltip
    if TacoTipConfig and not TacoTipConfig.show_guild_name then
      print(self:GetColoredText("error", L["TACOTIP_GUILD_NAME_WARNING"]));
    end
    -- Hook into Group finder frame
    LogTracker:InitLogsFrame();
    -- Hook into Group finder tooltip
    if LFGBrowseSearchEntryTooltip then
      hooksecurefunc("LFGBrowseSearchEntryTooltip_UpdateAndShow", function(tooltip, ...)
        LogTracker:OnTooltipShow(tooltip, ...);
      end);
    end
  else
    self:LogDebug("OnEvent", event, ...);
  end
end

function LogTracker:OnAddonLoaded(addonName)
  if (addonName ~= "LogTracker") then
    return;
  end
  LogTrackerDB = LogTrackerDB or self.db;
  self.db = LogTrackerDB;
  -- Init options panel
  self:InitOptions();
  -- Register shlash command
  if self.db.slashExtension then
    SLASH_LOGTRACKER1, SLASH_LOGTRACKER2 = '/lt', '/logtracker';
    SlashCmdList.LOGTRACKER = function(...)
      LogTracker:OnSlashCommand(...);
    end
  end
end

function LogTracker:OnChatMsgSystem(text)
  if not self.db.chatExtension then
    return;
  end
  local _, _, name, linkText = string.find(text, "|Hplayer:([^:]*)|h%[([^%[%]]*)%]?|h");
  if name then
    local playerData, playerName, playerRealm = self:GetPlayerData(name);
    if playerData then
      self:SendPlayerInfoToChat(playerData, playerName, playerRealm);
    end
  end
end

function LogTracker:OnModifierStateChanged()
  if not self.db.tooltipExtension then
    return;
  end
  if (UnitExists("mouseover")) then
    GameTooltip:SetUnit("mouseover");
  end
end

function LogTracker:OnTooltipSetUnit(tooltip, ...)
  if not self.db.tooltipExtension then
    return;
  end
  local unitName, unitId = GameTooltip:GetUnit();
  if not UnitIsPlayer(unitId) then
    return;
  end
  local unitName, unitRealm = UnitName(unitId);
  local playerData, playerName, playerRealm = self:GetPlayerData(unitName, unitRealm);
  if playerData then
    self:SetPlayerInfoTooltip(playerData, playerName, playerRealm);
  end
end

function LogTracker:IsTooltipLFGPlayer(tooltip)
  if not self.db.lfgExtension then
    return false;
  end
  if LFGBrowseSearchEntryTooltip and (tooltip == LFGBrowseSearchEntryTooltip) then
    return true;
  else
    return false;
  end
end

function LogTracker:OnTooltipShow(tooltip, ...)
  if self:IsTooltipLFGPlayer(tooltip) then
    self:OnTooltipShow_LFGPlayer(tooltip, ...);
  end
end

function LogTracker:OnTooltipShow_LFGPlayer(tooltip, resultID)
  local logTargets = nil;
  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID);
  if #searchResultInfo.activityIDs > 0 then
    for i, activityID in ipairs(searchResultInfo.activityIDs) do
      local activityDetails = self.activityDetails[activityID];
      if activityDetails then
        local activityKey = activityDetails.zone.."-"..activityDetails.size;
        if not logTargets then
          logTargets = {};
        end
        if not logTargets[activityKey] then
          logTargets[activityKey] = {};
        end
        for e, encounterID in ipairs(activityDetails.encounters) do
          if not tContains(logTargets[activityKey], encounterID) then
            tinsert(logTargets[activityKey], encounterID);
          end
        end
      end
    end
  end
  -- Tooltip for lead / single player
  local tooltipName = tooltip:GetName();
  local playerLine = tooltip.Leader.Name:GetText();
  local playerNameTooltip = strsplit("-", playerLine);
  playerNameTooltip = strtrim(playerNameTooltip);
  local playerData, playerName, playerRealm = self:GetPlayerData(playerNameTooltip);
  if playerData then
    -- Add instance top rank for leader
    if not tooltip.Leader.Logs then
      tooltip.Leader.Logs = tooltip.Leader:CreateFontString(nil, "ARTWORK", "GameFontNormal");
      tooltip.Leader.Logs:SetPoint("TOPLEFT", tooltip.Leader.Role, "TOPRIGHT", 32, -2)
    end
    tooltip.Leader.Logs:SetText(self:GetPlayerOverallPerformance(playerData, logTargets));
    -- Add tooltip for leader
    GameTooltip:ClearLines();
    GameTooltip:SetOwner(LFGBrowseSearchEntryTooltip);
    GameTooltip:SetText(playerNameTooltip);
    self:SetPlayerInfoTooltip(playerData, playerName, playerRealm, true);
    -- TODO: Solve positioning cleaner
    C_Timer.After(0, function()
      GameTooltip:ClearAllPoints();
      GameTooltip:SetPoint("TOPLEFT", LFGBrowseSearchEntryTooltip, "BOTTOMLEFT");
    end);
  else
    GameTooltip:ClearLines();
    GameTooltip:Hide();
  end
  -- Tooltip for additional members
  for frame in tooltip.memberPool:EnumerateActive() do
    self:OnTooltipShow_LFGMember(frame, logTargets);
  end
  -- Increase width to prevent overlap
  tooltip:SetWidth( tooltip:GetWidth() + 32 );
end

function LogTracker:OnTooltipShow_LFGMember(frame, logTargets)
  if not frame.Logs then
    frame.Logs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    frame.Logs:SetPoint("TOPLEFT", frame.Role, "TOPRIGHT", 32, -2)
  end
  local memberName = frame.Name:GetText();
  local playerData, playerName, playerRealm = self:GetPlayerData(memberName);
  if playerData then
    frame.Logs:SetText(self:GetPlayerOverallPerformance(playerData, logTargets));
  else
    frame.Logs:SetText(self:GetColoredText("muted", "--"));
  end
end

function LogTracker:GetIconSized(iconTemplate, width, height)
  local iconString = gsub(gsub(iconTemplate, "%%w", width), "%%h", height);
  return "|T"..iconString.."|t";
end

-- /script print(LogTracker:GetClassIcon("Priest"))
-- /script print("\124TInterface/AddOns/LogTracker/Icons/classes:36:36:0:0:256:512:180:216:36:72\124t")
-- /script print("\124TInterface/InventoryItems/WoWUnknownItem01\124t")
function LogTracker:GetClassIcon(classNameOrId, width, height)
  if not width then
    width = 14;
  end
  if not height then
    height = 14;
  end
  local addonLoaded = LoadAddOn("LogTracker_BaseData");
  if not addonLoaded or not LogTracker_BaseData or not LogTracker_BaseData.classes or not LogTracker_BaseData.classes[classNameOrId] then
    return self:GetIconSized("Interface/InventoryItems/WoWUnknownItem01:%w:%h", width, height);
  end
  local classData = LogTracker_BaseData.classes[classNameOrId];
  return self:GetIconSized(classData.icon, width, height);
end

function LogTracker:GetSpecIcon(classNameOrId, specNameOrId, width, height)
  if not width then
    width = 14;
  end
  if not height then
    height = 14;
  end
  local addonLoaded = LoadAddOn("LogTracker_BaseData");
  if not addonLoaded or not LogTracker_BaseData or not LogTracker_BaseData.classes or not LogTracker_BaseData.classes[classNameOrId]
      or not LogTracker_BaseData.classes[classNameOrId].specs or not LogTracker_BaseData.classes[classNameOrId].specs[specNameOrId] then
    return self:GetIconSized("Interface/InventoryItems/WoWUnknownItem01:%w:%h", width, height);
  end
  local classData = LogTracker_BaseData.classes[classNameOrId];
  local specData = classData.specs[specNameOrId];
  return self:GetIconSized(specData.icon, width, height);
end

function LogTracker:GetColoredText(type, text)
  if (type == "zone") then
    return "|cffdd60ff"..text.."|r";
  elseif (type == "spec") then
    return "|cffffffff"..text.."|r";
  elseif (type == "muted") then
    return "|cff808080"..text.."|r";
  elseif (type == "error") then
    return "|cffff0000"..text.."|r";
  else
    return text;
  end
end

function LogTracker:GetColoredProgress(done, overall)
  if (done == 0) then
    return "|cffd00000"..done.."/"..overall.."|r";
  elseif (done < overall) then
    return "|cffd0d000"..done.."/"..overall.."|r";
  else
    return "|cff00d000"..done.."/"..overall.."|r";
  end
end

function LogTracker:GetColoredPercent(value)
  value = floor(value);
  if (value >= 99) then
    return "|cffe268a8"..value.."|r";
  elseif (value >= 95) then
    return "|cffffa000"..value.."|r";
  elseif (value >= 75) then
    return "|cffdd60ff"..value.."|r";
  elseif (value >= 50) then
    return "|cff6060ff"..value.."|r";
  elseif (value >= 25) then
    return "|cff00d000"..value.."|r";
  else
    return "|cff808080"..value.."|r";
  end
end

function LogTracker:GetRegion(realmName)
  local addonLoaded = LoadAddOn("LogTracker_BaseData");
  if not addonLoaded or not LogTracker_BaseData or not LogTracker_BaseData.regionByServerName then
    return nil;
  end
  return LogTracker_BaseData.regionByServerName[realmName];
end

function LogTracker:GetPlayerLink(playerName)
  return self:GetColoredText("player", "|Hplayer:"..playerName.."|h["..playerName.."]|h");
end

function LogTracker:GetPlayerData(playerFull, realmNameExplicit)
  if not playerFull then
    return nil;
  end
  local playerName, realmName = strsplit("-", playerFull);
  if not realmName then
    if not realmNameExplicit or (realmNameExplicit == "") then
      realmName = GetRealmName();
    else
      realmName = realmNameExplicit
    end
  end
  playerFull = playerName.."-"..realmName;
  local region = self:GetRegion(realmName);
  if not region then
    return nil;
  end
  local addonLoaded = LoadAddOn("LogTracker_CharacterData_"..region);
  if not addonLoaded or not _G["LogTracker_CharacterData_"..region][realmName] then
    return nil;
  end
  local characterDataRaw = _G["LogTracker_CharacterData_"..region][realmName][playerName];
  local characterData = nil;
  -- Unpack character data into a more accessible format
  if characterDataRaw then
    local characterPerformance = {};
    for zoneIdSize, zonePerformance in pairs(characterDataRaw[5]) do
      local zoneId, zoneSize = strsplit("-", zoneIdSize);
      zoneId = tonumber(zoneId);
      zoneSize = tonumber(zoneSize);
      -- Zone name
      local zoneName = "Unknown ("..zoneSize..")";
      if LogTracker_BaseData.zoneNames and LogTracker_BaseData.zoneNames[zoneId] then
        zoneName = LogTracker_BaseData.zoneNames[zoneId]['name'].." ("..zoneSize..")";
      end
      -- Allstars rankings
      local zoneAllstars = {};
      for _, zoneAllstarsRaw in ipairs(zonePerformance[3]) do
        tinsert(zoneAllstars, {
          ['spec'] = tonumber(zoneAllstarsRaw[1]),
          ['percentRank'] = zoneAllstarsRaw[2]
        });
      end
      -- Encounters
      local zoneEncounters = {};
      if zonePerformance[4] ~= "" then
        local zoneEncountersStr = { strsplit("|", zonePerformance[4]) };
        for zoneEncounterIndex, zoneEncountersRaw in ipairs(zoneEncountersStr) do
          if (zoneEncountersRaw ~= "") then
            zoneEncountersRaw = { strsplit(",", zoneEncountersRaw) };
          else
            zoneEncountersRaw = { 0, 0, 0 };
          end
          tinsert(zoneEncounters, {
            ['spec'] = tonumber(zoneEncountersRaw[1]),
            ['encounter'] = LogTracker_BaseData.zoneEncounters[zoneId][zoneEncounterIndex],
            ['percentRank'] = zoneEncountersRaw[2],
            ['percentMedian'] = zoneEncountersRaw[3]
          });
        end
      end
      -- Zone details
      characterPerformance[zoneIdSize] = {
        ['zoneName'] = zoneName,
        ['zoneEncounters'] = zonePerformance[1],
        ['encountersKilled'] = zonePerformance[2],
        ['allstars'] = zoneAllstars,
        ['encounters'] = zoneEncounters
      }
    end
    -- Character details
    characterData = {
      ['level'] = characterDataRaw[1],
      ['faction'] = characterDataRaw[2],
      ['class'] = tonumber(characterDataRaw[3]),
      ['last_update'] = characterDataRaw[4],
      ['performance'] = characterPerformance,
    };
  end
  return characterData, playerName, realmName;
end

function LogTracker:GetPlayerOverallPerformance(playerData, logTargets)
  local logScoreValue = 0;
  local logScoreCount = 0;
  for zoneId, zoneData in pairs(playerData['performance']) do
    for _, encounterData in ipairs(zoneData['encounters']) do
      local targetEncounters = nil;
      if logTargets and logTargets[zoneId] then
        targetEncounters = logTargets[zoneId];
      end
      if not logTargets or (targetEncounters and tContains(targetEncounters, encounterData['encounter']['id'])) then
        -- logTargets is either nil (include every encounter) or it contains the given encounter
        logScoreValue = logScoreValue + encounterData['percentRank'];
        logScoreCount = logScoreCount + 1;
      end
    end
  end
  if (logScoreCount > 0) then
    return self:GetColoredPercent(logScoreValue / logScoreCount);
  else
    return self:GetColoredText("muted", "--");
  end
end

function LogTracker:GetPlayerZonePerformance(zone, playerClass)
  local zoneName = zone.zoneName;
  local zoneProgress = self:GetColoredProgress(tonumber(zone.encountersKilled), tonumber(zone.zoneEncounters));
  local zoneRatingsStr = "";
  local zoneRatings = {};
  for _, allstarsRating in ipairs(zone.allstars) do
    tinsert(zoneRatings, self:GetSpecIcon(playerClass, allstarsRating.spec).." "..self:GetColoredPercent(allstarsRating.percentRank));
  end
  if #(zoneRatings) > 0 then
    zoneRatingsStr = strjoin(" ", unpack(zoneRatings));
  end
  return self:GetColoredText("zone", zoneName), self:GetColoredText("progress", zoneProgress), zoneRatingsStr;
end

function LogTracker:GetPlayerEncounterPerformance(encounter, playerClass, reversed)
  local encounterName = encounter.encounter.name;
  if (encounter.spec == 0) then
    return self:GetColoredText("encounter", encounterName), "---";
  end
  local encounterRating = self:GetSpecIcon(playerClass, encounter.spec).." "..self:GetColoredPercent(encounter.percentRank);
  if (reversed) then
    encounterRating = self:GetColoredPercent(encounter.percentRank).." "..self:GetSpecIcon(playerClass, encounter.spec);
  end
  return self:GetColoredText("encounter", encounterName), encounterRating;
end

function LogTracker:SendSystemChatLine(text)
  local chatInfo = ChatTypeInfo["SYSTEM"];
  local i;
  for i=1, 16 do
    local chatFrame = _G["ChatFrame"..i];
    if (chatFrame) then
      chatFrame:AddMessage(text, chatInfo.r, chatInfo.g, chatInfo.b, chatInfo.id);
    end
  end
end

function LogTracker:SendPlayerInfoToChat(playerData, playerName, playerRealm, showEncounters)
  for zoneId, zone in pairs(playerData.performance) do
    local zoneName, zoneProgress, zoneSpecs = self:GetPlayerZonePerformance(zone, playerData.class);
    self:SendSystemChatLine( self:GetPlayerLink(playerName).." "..strjoin(" ", self:GetPlayerZonePerformance(zone, playerData.class)) );
    if showEncounters then
      for _, encounter in ipairs(zone.encounters) do
        local encounterName, encounterRating = self:GetPlayerEncounterPerformance(encounter, playerData.class);
        self:SendSystemChatLine("  "..encounterName..": "..encounterRating);
      end
    end
  end
  self:SendSystemChatLine(L["DATE_UPDATE"]..": "..date(L["DATE_FORMAT"], playerData.last_update));
end

function LogTracker:SetPlayerInfoTooltip(playerData, playerName, playerRealm, disableShiftNotice)
  for zoneIdSize, zone in pairs(playerData.performance) do
    local zoneId, zoneSize = strsplit("-", zoneIdSize);
    if (zoneSize == "10" and not self.db.hide10Player) or (zoneSize == "25" and not self.db.hide25Player) then
      local zoneName, zoneProgress, zoneSpecs = self:GetPlayerZonePerformance(zone, playerData.class);
      GameTooltip:AddDoubleLine(
        zoneName.." "..zoneProgress, zoneSpecs,
        1, 1, 1, 1, 1, 1
      );
      if IsShiftKeyDown() then
        for _, encounter in ipairs(zone.encounters) do
          local encounterName, encounterRating = self:GetPlayerEncounterPerformance(encounter, playerData.class, true);
          GameTooltip:AddDoubleLine(
            "  "..encounterName, encounterRating,
            1, 1, 1, 1, 1, 1
          );
        end
      end
    end
  end
  if IsShiftKeyDown() then
    GameTooltip:AddDoubleLine(
      L["DATE_UPDATE"], date(L["DATE_FORMAT"], playerData.last_update),
      0.5, 0.5, 0.5, 0.5, 0.5, 0.5
    );
  end
  if not IsShiftKeyDown() and not disableShiftNotice then
    GameTooltip:AddLine(
      self:GetColoredText("muted", L["SHIFT_FOR_DETAILS"]),
      1, 1, 1
    );
  end
  GameTooltip:Show();
end

-- Kickstart the addon
LogTracker:Init();
