local _, L = ...;
local addonPrefix = "LTSY";
local startupDelay = 60;               -- 1 minute
local syncThrottle = 2;                -- 2 seconds
local syncInterval = 5;                -- 5 seconds
local syncHistoryUpdates = 300;        -- 5 minutes
local syncHistoryCount = 50;           -- Keep up to 50 players in the "recently updated" list for sync between logins
local syncPeerGreeting = 60;           -- 1 minute
local syncPeerTimeout = 300;           -- 5 minutes
local syncPeerUpdates = 1800;          -- 30 minutes
local syncBatchPlayers = 20;           -- Sync up to 20 players per batch
local syncRequestLimit = 30;           -- Keep up to 30 players in a request list (to retrieve missing data from other clients)
local syncRequestDelay = 60;           -- 1 minute
local playerUpdateInterval = 3600;     -- 1 hours
local playerAgeLimit = 86400 * 21;     -- 3 weeks

LogTracker = CreateFrame("Frame", "LogTracker", UIParent);

function LogTracker:Init()
  self.defaults = {
    debug = false,
    chatExtension = true,
    tooltipExtension = true,
    lfgExtension = true,
    slashExtension = true,
    hide10Player = false,
    hide25Player = false
  };
  self.syncStatus = {
    guild = 0,
    party = 0,
    raid = 0,
    whisper = 0,
    timer = GetTime(),
    peers = {},
    peersUpdate = GetTime(),
    peersChannel = {
      guild = GetTime(),
      party = GetTime(),
      raid = GetTime(),
      yell = GetTime()
    },
    players = {},
    requests = {},
    requestsLock = {},
    requestsTimer = GetTime(),
    historyUpdate = GetTime(),
    messages = {},
    messageLength = 0,
    throttleTimer = GetTime() + startupDelay,
  };
  self.achievementTime = nil;
  self.achievementGuid = nil;
  self.achievementUnit = nil;
  self.achievementDetails = {
    name = nil, level = nil, faction = nil
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
    -- Ulduar 10-man
    [1106] = {
      zone = 1017,
      size = 10,
      encounters = { 744, 745, 746, 747, 748, 749, 750, 751, 752, 753, 754, 755, 756, 757 },
      achivements = {
        [744] = { -- 744 2856 Flame Leviathan
          killCount = 2856, hardmodes = {
          { id = 2913, difficulty = 1, label = "1T" },
          { id = 2914, difficulty = 2, label = "2T" },
          { id = 2915, difficulty = 3, label = "3T" },
          { id = 3056, difficulty = 4, label = "4T" }
        }
        },
        [745] = { -- 745 2858 Ignis the Furnace Master
          killCount = 2858, hardmodes = {}
        },
        [746] = { -- 746 2857 Razorscale
          killCount = 2857, hardmodes = {}
        },
        [747] = { -- 747 2859 XT-002 Deconstructor
          killCount = 2859, hardmodes = {
          { id = 3058, difficulty = 4, label = "Hard" }
        }
        },
        [748] = { -- 748 2860 The Assembly of Iron
          killCount = 2860, hardmodes = {
          { id = 2940, difficulty = 0, label = "Easy" },
          { id = 2939, difficulty = 2, label = "Med" },
          { id = 2941, difficulty = 4, label = "Hard" }
        }
        },
        [749] = { -- 749 2861 Kologarn
          killCount = 2861, hardmodes = {}
        },
        [750] = { -- 750 2868 Auriaya
          killCount = 2868, hardmodes = {}
        },
        [751] = { -- 751 2862 Hodir
          killCount = 2862, hardmodes = {
          { id = 3182, difficulty = 4, label = "Hard" }
        }
        },
        [752] = { -- 752 2863 Thorim
          killCount = 2863, hardmodes = {
          { id = 3176, difficulty = 4, label = "Hard" }
        }
        },
        [753] = { -- 753 2864 Freya
          killCount = 2864, hardmodes = {
          { id = 3177, difficulty = 2, label = "1E" },
          { id = 3178, difficulty = 3, label = "2E" },
          { id = 3179, difficulty = 4, label = "3E" }
        }
        },
        [754] = { -- 754 2865 Mimiron
          killCount = 2865, hardmodes = {
          { id = 3180, difficulty = 4, label = "Hard" }
        }
        },
        [755] = { -- 755 2866 General Vezax
          killCount = 2866, hardmodes = {
          { id = 3181, difficulty = 4, label = "Hard" }
        }
        },
        [756] = { -- 756 2869 Yogg-Saron
          killCount = 2869, hardmodes = {
          { id = 3157, difficulty = 1, label = "3L" },
          { id = 3141, difficulty = 2, label = "2L" },
          { id = 3158, difficulty = 3, label = "1L" },
          { id = 3159, difficulty = 4, label = "0L" }
        }
        },
        [757] = { -- 757 2867 Algalon the Observer
          killCount = 2867, hardmodes = {}
        }
      }
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
    -- Ulduar 25-man
    [1107] = {
      zone = 1017,
      size = 25,
      encounters = { 744, 745, 746, 747, 748, 749, 750, 751, 752, 753, 754, 755, 756, 757 },
      achivements = {
        [744] = { -- 744 2872 Flame Leviathan
          killCount = 2872, hardmodes = {
          { id = 2918, difficulty = 1, label = "1T" },
          { id = 2916, difficulty = 2, label = "2T" },
          { id = 2917, difficulty = 3, label = "3T" },
          { id = 3057, difficulty = 4, label = "4T" }
        }
        },
        [745] = { -- 745 2874 Ignis the Furnace Master
          killCount = 2874, hardmodes = {}
        },
        [746] = { -- 746 2873 Razorscale
          killCount = 2873, hardmodes = {}
        },
        [747] = { -- 747 2884 XT-002 Deconstructor
          killCount = 2884, hardmodes = {
          { id = 3059, difficulty = 4, label = "Hard" }
        }
        },
        [748] = { -- 748 2885 The Assembly of Iron
          killCount = 2885, hardmodes = {
          { id = 2943, difficulty = 0, label = "Easy" },
          { id = 2942, difficulty = 2, label = "Med" },
          { id = 2944, difficulty = 4, label = "Hard" }
        }
        },
        [749] = { -- 749 2875 Kologarn
          killCount = 2875, hardmodes = {}
        },
        [750] = { -- 750 2882 Auriaya
          killCount = 2882, hardmodes = {}
        },
        [751] = { -- 751 3256 Hodir
          killCount = 3256, hardmodes = {
          { id = 3184, difficulty = 4, label = "Hard" }
        }
        },
        [752] = { -- 752 3257 Thorim
          killCount = 3257, hardmodes = {
          { id = 3183, difficulty = 4, label = "Hard" }
        }
        },
        [753] = { -- 753 3258 Freya
          killCount = 3258, hardmodes = {
          { id = 3185, difficulty = 2, label = "1E" },
          { id = 3186, difficulty = 3, label = "2E" },
          { id = 3187, difficulty = 4, label = "3E" }
        }
        },
        [754] = { -- 754 2879 Mimiron
          killCount = 2879, hardmodes = {
          { id = 3189, difficulty = 4, label = "Hard" }
        }
        },
        [755] = { -- 755 2880 General Vezax
          killCount = 2880, hardmodes = {
          { id = 3188, difficulty = 4, label = "Hard" }
        }
        },
        [756] = { -- 756 2883 Yogg-Saron
          killCount = 2883, hardmodes = {
          { id = 3161, difficulty = 1, label = "3L" },
          { id = 3162, difficulty = 2, label = "2L" },
          { id = 3163, difficulty = 3, label = "1L" },
          { id = 3164, difficulty = 4, label = "0L" }
        }
        },
        [757] = { -- 757 2881 Algalon the Observer
          killCount = 2881, hardmodes = {}
        }
      }
    },
  };
  self.db = CopyTable(self.defaults);
  self:SetScript("OnEvent", self.OnEvent);
  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("CHAT_MSG_ADDON");
  self:RegisterEvent("CHAT_MSG_SYSTEM");
  self:RegisterEvent("MODIFIER_STATE_CHANGED");
  self:RegisterEvent("PLAYER_ENTERING_WORLD");
  self:RegisterEvent("PLAYER_TARGET_CHANGED");
  self:RegisterEvent("INSPECT_ACHIEVEMENT_READY");
  self:RegisterEvent("NAME_PLATE_UNIT_ADDED");
  self:RegisterEvent("GUILD_ROSTER_UPDATE");
  self:RegisterEvent("GROUP_ROSTER_UPDATE");
  self:RegisterEvent("RAID_ROSTER_UPDATE");
  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
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
  local urlBase = "https://classic.warcraftlogs.com/character/" .. urlRegion .. "/" .. strlower(GetRealmName()) .. "/";
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
    self.warcraftlogsFrame.Url:SetText(urlBase .. strlower(dropdown.value));
  end
  local characterDropdownInit = function(dropdown)
    for i = 1, #dropdown.values do
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
      for i = 1, numMembers do
        local name, role, classFileName, className, level, isLeader = C_LFGList.GetSearchResultMemberInfo(lfg.resultID, i);
        if name then
          local classColor = RAID_CLASS_COLORS[classFileName];
          tinsert(self.warcraftlogsFrame.CharacterDropdown.values, {
            text = "|cff" .. string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) .. name .. "|r",
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
        self.warcraftlogsFrame.Url:SetText(urlBase .. strlower(selectedValue));
      end
      self.warcraftlogsFrame:Show();
    elseif (numMembers == 1) then
      -- Player
      local name, role, classFileName, className, level, areaName, soloRoleTank, soloRoleHealer, soloRoleDPS = C_LFGList
      .GetSearchResultLeaderInfo(lfg.resultID);
      local classColor = RAID_CLASS_COLORS[classFileName];
      self.warcraftlogsFrame.CharacterName:SetTextColor(classColor.r, classColor.g, classColor.b);
      self.warcraftlogsFrame.CharacterName:SetText(name);
      self.warcraftlogsFrame.CharacterName:Show();
      self.warcraftlogsFrame.Url:SetText(urlBase .. strlower(name));
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
  -- Show 25 player logs
  self.optionShowDebug = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
  self.optionShowDebug:SetPoint("TOPLEFT", 20, -140);
  self.optionShowDebug.Text:SetText(L["OPTION_SHOW_DEBUG"]);
  self.optionShowDebug:SetScript("OnClick", function(_, value)
    self.db.debug = self.optionShowDebug:GetChecked();
  end)
  self.optionShowDebug:SetChecked(self.db.debug);
end

function LogTracker:LogOutput(...)
  print("|cffff0000LT|r", ...);
end

function LogTracker:LogDebug(...)
  if self.db and self.db.debug then
    print("|cffff0000LT|r", "|cffffff00Debug|r", ...);
  end
end

function LogTracker:SendAddonMessage(action, data, type, target, prio)
  local message = action;
  if data ~= nil then
    message = message .. "|" .. data;
  end
  --self:LogDebug("SendAddonMessage", action, type, target, data);
  ChatThrottleLib:SendAddonMessage(prio or "NORMAL", addonPrefix, message, type, target);
end

function LogTracker:QueueAddonMessage(action, data)
  local message = action;
  if data ~= nil then
    message = message .. "|" .. data;
  end
  local messageLength = strlen(addonPrefix) + strlen(message) + 1;
  --self:LogDebug("QueueAddonMessage", messageLength, action, type, target, data);
  if messageLength > 254 then
    self:LogDebug("QueueAddonMessage", "Message too long! (" .. messageLength .. "/254)", action);
  else
    tinsert(self.syncStatus.messages, message);
  end
end

function LogTracker:QueuePlayerData(name)
  local realmName = GetRealmName();
  local playerData = self.db.playerData[realmName][name];
  if playerData then
    local message = name ..
    "#" .. playerData.level .. "#" .. playerData.faction .. "#" .. playerData.class .. "#" .. playerData.lastUpdate;
    self:QueueAddonMessage("pl", message);
    for zoneId, encounterData in pairs(playerData.encounters) do
      self:QueueAddonMessage("plE", name .. "#" .. zoneId .. "#" .. encounterData);
    end
    return true;
  end
  return false;
end

function LogTracker:FlushAddonMessages(type, target, prio)
  local statsMessages = 0;
  local statsBytes = 0;
  local data = "";
  local size = strlen(addonPrefix) + 1;
  for _, message in ipairs(self.syncStatus.messages) do
    if (size + strlen(message) + 1 > 254) then
      ChatThrottleLib:SendAddonMessage(prio or "NORMAL", addonPrefix, data, type, target);
      statsBytes = statsBytes + size;
      statsMessages = statsMessages + 1;
      data = message;
      size = strlen(addonPrefix) + strlen(message) + 1;
    else
      if data == "" then
        data = message;
      else
        data = data .. "|" .. message;
      end
      size = size + strlen(message) + 1;
    end
  end
  if data ~= "" then
    ChatThrottleLib:SendAddonMessage(prio or "NORMAL", addonPrefix, data, type, target);
    statsBytes = statsBytes + size;
    statsMessages = statsMessages + 1;
  end
  wipe(self.syncStatus.messages);
  --self:LogDebug("FlushAddonMessages", "Sent " .. statsBytes .. "bytes in " .. statsMessages .. " messages");
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
    self:SendSystemChatLine(L["CHAT_PLAYER_DETAILS"] .. " |Hplayer:" .. playerName .. "-" .. playerRealm .. "|h" .. playerName .. "|h");
    self:SendPlayerInfoToChat(playerData, playerName, playerRealm, true);
  else
    self:SendSystemChatLine(L["CHAT_PLAYER_NOT_FOUND"] .. " |Hplayer:" .. playerName .. "-" .. playerRealm .. "|h" .. playerName .. "|h");
  end
end

function LogTracker:OnEvent(event, ...)
  if (event == "ADDON_LOADED") then
    self:OnAddonLoaded(...);
  elseif (event == "CHAT_MSG_ADDON") then
    self:OnChatMsgAddon(...);
  elseif (event == "CHAT_MSG_SYSTEM") then
    self:OnChatMsgSystem(...);
  elseif (event == "INSPECT_ACHIEVEMENT_READY") then
    self:OnInspectAchievements(...);
  elseif (event == "PLAYER_TARGET_CHANGED") then
    self:OnTargetChanged(...);
  elseif (event == "UPDATE_MOUSEOVER_UNIT") then
    self:OnMouseoverUnit(...);
  elseif (event == "NAME_PLATE_UNIT_ADDED") then
    self:OnNameplateUnitAdded(...);
  elseif (event == "MODIFIER_STATE_CHANGED") then
    self:OnModifierStateChanged(...);
  elseif (event == "GUILD_ROSTER_UPDATE") then
    self:OnGuildRosterUpdate(...);
  elseif (event == "GROUP_ROSTER_UPDATE") then
    self:OnGroupRosterUpdate(...);
  elseif (event == "RAID_ROSTER_UPDATE") then
    self:OnRaidRosterUpdate(...);
  elseif (event == "PLAYER_ENTERING_WORLD") then
    -- Cleanup player data
    self:CleanupPlayerData();
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
    -- Greet peers
    if IsInGuild() then
      self:SendAddonMessage("hi", nil, "GUILD");
    end
    if IsInRaid() then
      self:SendAddonMessage("hi", nil, "RAID");
    elseif IsInGroup() then
      self:SendAddonMessage("hi", nil, "PARTY");
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
  self.db.playerData = self.db.playerData or {};
  if self.db.syncHistory then
    self.syncStatus.players = { unpack(self.db.syncHistory) };
  else
    self.db.syncHistory = {};
  end
  self:LogDebug("Init");
  -- Init options panel
  self:InitOptions();
  -- Register slash command
  if self.db.slashExtension then
    SLASH_LOGTRACKER1, SLASH_LOGTRACKER2 = '/lt', '/logtracker';
    SlashCmdList.LOGTRACKER = function(...)
      LogTracker:OnSlashCommand(...);
    end
  end
  -- Register addon prefix
  C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix);
end

function LogTracker:OnChatMsgAddon(prefix, message, source, sender)
  if prefix ~= addonPrefix then
    return;
  end
  local realmName = GetRealmName();
  local syncName = strsplit("-", sender);
  self.db.playerData[realmName] = self.db.playerData[realmName] or {};
  local peer = self:GetSyncPeer(syncName);
  if peer == nil then
    return;
  end
  local parts = { strsplit("|", message) };
  while #(parts) > 0 do
    local action = tremove(parts, 1);
    --self:LogDebug("Sync Received", syncName, action);
    if action == "hi" or action == "hello" then
      -- New peer
    elseif action == "pl" then
      -- Player base data
      local data = tremove(parts, 1);
      if data then
        local name, level, faction, class, lastUpdate = strsplit("#", data);
        lastUpdate = tonumber(lastUpdate);
        local playerData = self.db.playerData[realmName][name];
        peer.receivedOverall = peer.receivedOverall + 1;
        if not playerData then
          playerData = { encounters = {}, lastUpdate = lastUpdate - 1 };
        end
        if (playerData.lastUpdate < lastUpdate) then
          playerDetails.level = level;
          playerDetails.faction = faction;
          playerDetails.class = class;
          playerDetails.lastUpdate = lastUpdate;
          self.db.playerData[realmName][name] = playerData;
          peer.receivedUpdates = peer.receivedUpdates + 1;
        end
      end
    elseif action == "plE" then
      -- Player encounter data
      local data = tremove(parts, 1);
      if data then
        local name, zoneId, encouterData = strsplit("#", data);
        local playerData = self.db.playerData[realmName][name];
        if playerData then
          playerData.encounters[zoneId] = encouterData;
        end
      end
    elseif action == "rq" then
      -- Request for player data
      local data = tremove(parts, 1);
      local names = { strsplit("#", data) };
      local amount = 0;
      for _, name in ipairs(names) do
        if not self.syncStatus.requestsLock[name] and self:QueuePlayerData(name) then
          self.syncStatus.requestsLock[name] = true;
          amount = amount + 1;
        end
      end
      if amount > 0 then
        local target = nil;
        if source == "WHISPER" then
          target = sender;
        end
        self:FlushAddonMessages(source, target);
        self:LogDebug("Sync Request", syncName, "Sent " .. amount .. " players");
      else
        self:LogDebug("Sync Request", syncName, "None available! (" .. #(names) .. " requested)");
      end
    end
    peer.chatReported = false;
    peer.lastUpdate = GetTime();
    peer.isOnline = true;
    if source == "GUILD" then
      peer.isGuild = true;
    elseif source == "PARTY" then
      peer.isParty = true;
    elseif source == "RAID" then
      peer.isRaid = true;
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

function LogTracker:OnInspectAchievements(playerGuid)
  -- INSPECT_ACHIEVEMENT_READY
  if (self.achievementGuid == nil) or (playerGuid ~= self.achievementGuid) then
    return
  end
  local realmName = GetRealmName();
  self.db.playerData[realmName] = self.db.playerData[realmName] or {};
  local playerName = self.achievementDetails.name;
  local playerDetails = self.db.playerData[realmName][playerName] or { encounters = {} };
  playerDetails.class = self.achievementDetails.class;
  playerDetails.level = self.achievementDetails.level;
  playerDetails.faction = self.achievementDetails.faction;
  playerDetails.lastUpdate = time();
  for activityID, activityDetail in pairs(self.activityDetails) do
    if activityDetail.achivements then
      local activityKey = activityDetail.zone .. "-" .. activityDetail.size;
      local activityEncounters = {};
      for _, encounterID in ipairs(activityDetail.encounters) do
        local encounterDetails = activityDetail.achivements[encounterID];
        local name = encounterID;
        local kills = 0;
        local hardmode = "0,Easy";
        if encounterDetails.killCount then
          local _, killName = GetAchievementInfo(encounterDetails.killCount);
          name = killName;
          kills = GetComparisonStatistic(encounterDetails.killCount);
          if kills == "--" then
            kills = 0;
          else
            kills = tonumber(kills);
          end
        end
        if encounterDetails.hardmodes then
          for _, hardmodeDetail in pairs(encounterDetails.hardmodes) do
            if GetAchievementComparisonInfo(hardmodeDetail.id) then
              hardmode = hardmodeDetail.difficulty .. "," .. hardmodeDetail.label;
            end
          end
        end
        if (kills > 0) then
          tinsert(activityEncounters, kills .. "," .. hardmode);
        else
          tinsert(activityEncounters, "");
        end
      end
      playerDetails.encounters[activityKey] = strjoin("/", unpack(activityEncounters));
    end
  end
  self.db.playerData[realmName][playerName] = playerDetails;
  if not tContains(self.syncStatus.players, playerName) then
    tinsert(self.syncStatus.players, playerName);
  end
  -- Remove from request list if present
  self:SyncRequestRemove(playerName);
  --self:LogDebug("Updated achievements for ", playerName);
  self:SyncCheck();
  -- Clear unit / guid for inspect
  self.achievementTime = nil;
  self.achievementGuid = nil;
  self.achievementUnit = nil;
  self.achievementDetails.name = nil;
  self.achievementDetails.level = nil;
  self.achievementDetails.faction = nil;
end

function LogTracker:OnTargetChanged()
  self:CompareAchievements("target");
end

function LogTracker:OnMouseoverUnit()
  self:CompareAchievements("mouseover");
end

function LogTracker:OnNameplateUnitAdded(unitId)
  self:CompareAchievements(unitId);
end

function LogTracker:OnGuildRosterUpdate()
  self:SyncUpdateGuild();
  self:SyncCheck();
end

function LogTracker:OnGroupRosterUpdate()
  self:SyncUpdateParty();
  self:SyncCheck();
end

function LogTracker:OnRaidRosterUpdate()
  self:SyncUpdateRaid();
  self:SyncCheck();
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
        local activityKey = activityDetails.zone .. "-" .. activityDetails.size;
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
  tooltip:SetWidth(tooltip:GetWidth() + 32);
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

function LogTracker:GetActivityByZoneId(zoneId, zoneSize)
  for activityID, activityDetail in pairs(self.activityDetails) do
    if (activityDetail.zone == zoneId) and (activityDetail.size == zoneSize) then
      return activityDetail, activityID;
    end
  end
  return nil;
end

function LogTracker:GetIconSized(iconTemplate, width, height)
  local iconString = gsub(gsub(iconTemplate, "%%w", width), "%%h", height);
  return "|T" .. iconString .. "|t";
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
    return "|cffdd60ff" .. text .. "|r";
  elseif (type == "spec") or (type == "kills") then
    return "|cffffffff" .. text .. "|r";
  elseif (type == "muted") then
    return "|cff808080" .. text .. "|r";
  elseif (type == "error") then
    return "|cffff0000" .. text .. "|r";
  elseif (type == "hardmode0") then
    return "|cff00ff00" .. text .. "|r";
  elseif (type == "hardmode1") then
    return "|cff80ff00" .. text .. "|r";
  elseif (type == "hardmode2") then
    return "|cffffff00" .. text .. "|r";
  elseif (type == "hardmode3") then
    return "|cff80ff00" .. text .. "|r";
  elseif (type == "hardmode4") then
    return "|cffff0000" .. text .. "|r";
  else
    return text;
  end
end

function LogTracker:GetColoredProgress(done, overall)
  if (done == 0) then
    return "|cffd00000" .. done .. "/" .. overall .. "|r";
  elseif (done < overall) then
    return "|cffd0d000" .. done .. "/" .. overall .. "|r";
  else
    return "|cff00d000" .. done .. "/" .. overall .. "|r";
  end
end

function LogTracker:GetColoredPercent(value)
  value = floor(value);
  if (value >= 99) then
    return "|cffe268a8" .. value .. "|r";
  elseif (value >= 95) then
    return "|cffffa000" .. value .. "|r";
  elseif (value >= 75) then
    return "|cffdd60ff" .. value .. "|r";
  elseif (value >= 50) then
    return "|cff6060ff" .. value .. "|r";
  elseif (value >= 25) then
    return "|cff00d000" .. value .. "|r";
  else
    return "|cff808080" .. value .. "|r";
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
  return self:GetColoredText("player", "|Hplayer:" .. playerName .. "|h[" .. playerName .. "]|h");
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
  playerFull = playerName .. "-" .. realmName;
  local region = self:GetRegion(realmName);
  if not region then
    return nil;
  end
  local characterData = nil;
  -- Unpack character data into a more accessible format
  self.db.playerData[realmName] = self.db.playerData[realmName] or {};
  local playerDataRaw = self.db.playerData[realmName][playerName];
  if playerDataRaw then
    local characterPerformance = {};
    for zoneIdSize, zonePerformance in pairs(playerDataRaw.encounters) do
      local zoneId, zoneSize = strsplit("-", zoneIdSize);
      zoneId = tonumber(zoneId);
      zoneSize = tonumber(zoneSize);
      -- Activity defails
      local activityDetail, activityID = self:GetActivityByZoneId(zoneId, zoneSize);
      -- Zone name
      local zoneName = "Unknown (" .. zoneSize .. ")";
      if LogTracker_BaseData.zoneNames and LogTracker_BaseData.zoneNames[zoneId] then
        zoneName = LogTracker_BaseData.zoneNames[zoneId]['name'] .. " (" .. zoneSize .. ")";
      end
      -- Encounters
      local zoneEncounters = {};
      local zoneEncountersRaw = { strsplit("/", zonePerformance) };
      local zoneEncountersKilled = 0;
      local zoneEncountersHardmodes = 0;
      for zoneEncounterIndex, zoneEncounterRaw in ipairs(zoneEncountersRaw) do
        local zoneEncounterKills, zoneEncounterHmDiff, zoneEncounterHmLabel = strsplit(",", zoneEncounterRaw);
        local hardmodes = 0;
        if activityDetail and activityDetail.encounters[zoneEncounterIndex] then
          local zoneEncounterId = tonumber(activityDetail.encounters[zoneEncounterIndex]);
          hardmodes = #(activityDetail.achivements[zoneEncounterId].hardmodes);
        end
        if zoneEncounterRaw == "" then
          zoneEncounterKills = 0;
          zoneEncounterHmDiff = 0;
          zoneEncounterHmLabel = "Easy";
        else
          zoneEncounterKills = tonumber(zoneEncounterKills);
        end
        if zoneEncounterKills > 0 then
          zoneEncountersKilled = zoneEncountersKilled + 1;
          zoneEncounterHmDiff = tonumber(zoneEncounterHmDiff);
          if zoneEncounterHmDiff > 1 then
            zoneEncountersHardmodes = zoneEncountersHardmodes + 1;
          elseif hardmodes == 0 then
            zoneEncounterHmDiff = 2;
            zoneEncounterHmLabel = "Down";
          end
        end
        tinsert(zoneEncounters, {
          ['encounter'] = LogTracker_BaseData.zoneEncounters[zoneId][zoneEncounterIndex],
          ['kills'] = zoneEncounterKills,
          ['hardmode'] = self:GetColoredText("hardmode" .. zoneEncounterHmDiff, zoneEncounterHmLabel)
        });
      end
      -- Zone details
      characterPerformance[zoneIdSize] = {
        ['zoneName'] = zoneName,
        ['zoneEncounters'] = #(LogTracker_BaseData.zoneEncounters[zoneId]),
        ['hardmodes'] = zoneEncountersHardmodes,
        ['encountersKilled'] = zoneEncountersKilled,
        ['encounters'] = zoneEncounters
      };
    end
    -- Character details
    characterData = {
      ['level'] = playerDataRaw.level,
      ['faction'] = playerDataRaw.faction,
      ['class'] = tonumber(playerDataRaw.class),
      ['last_update'] = playerDataRaw.lastUpdate,
      ['performance'] = characterPerformance,
    };
  else
    self:SyncRequest(playerName);
  end
  -- Unpack character data into a more accessible format
  --[[
  local addonLoaded = LoadAddOn("LogTracker_CharacterData_" .. region);
  if not addonLoaded or not _G["LogTracker_CharacterData_" .. region][realmName] then
    return nil;
  end
  local characterDataRaw = _G["LogTracker_CharacterData_"..region][realmName][playerName];
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
  --]]
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
  if zone.allstars then
    for _, allstarsRating in ipairs(zone.allstars) do
      tinsert(zoneRatings,
      self:GetSpecIcon(playerClass, allstarsRating.spec) .. " " .. self:GetColoredPercent(allstarsRating.percentRank));
    end
  end
  if #(zoneRatings) > 0 then
    zoneRatingsStr = strjoin(" ", unpack(zoneRatings));
  end
  if zone.hardmodes and zone.hardmodes > 0 then
    zoneRatingsStr = zoneRatingsStr .. self:GetColoredText("hardmode4", zone.hardmodes .. "HM");
  end
  return self:GetColoredText("zone", zoneName), self:GetColoredText("progress", zoneProgress), zoneRatingsStr;
end

function LogTracker:GetPlayerEncounterPerformance(encounter, playerClass, reversed)
  local encounterName = encounter.encounter.name;
  if not encounter.spec and encounter.kills then
    if (encounter.kills > 0) then
      return self:GetColoredText("encounter", encounterName),
      encounter.hardmode .. " " .. self:GetColoredText("kills", encounter.kills .. "x");
    else
      return self:GetColoredText("encounter", encounterName), self:GetColoredText("muted", "not down");
    end
  end
  if (encounter.spec == 0) then
    return self:GetColoredText("encounter", encounterName), "---";
  end
  local encounterRating = self:GetSpecIcon(playerClass, encounter.spec) ..
  " " .. self:GetColoredPercent(encounter.percentRank);
  if (reversed) then
    encounterRating = self:GetColoredPercent(encounter.percentRank) .. " " ..
    self:GetSpecIcon(playerClass, encounter.spec);
  end
  return self:GetColoredText("encounter", encounterName), encounterRating;
end

function LogTracker:GetSyncPeer(name, noUpdate, noCreate)
  local playerName = UnitName("player");
  if name == playerName then
    return nil;
  end
  if noCreate and not self.syncStatus.peers[name] then
    return nil;
  end
  self.syncStatus.peers[name] = self.syncStatus.peers[name] or {
    chatReported = false,
    lastReport = GetTime(),
    lastSeen = 0,
    syncOffset = 0,
    isOnline = false,
    isGuild = false,
    isParty = false,
    isRaid = false,
    isWhisper = false,
    receivedOverall = 0,
    receivedUpdates = 0,
    sentOverall = 0
  };
  if not noUpdate then
    self.syncStatus.peers[name].isOnline = true;
    self.syncStatus.peers[name].chatReported = false;
    self.syncStatus.peers[name].lastSeen = GetTime();
  end
  if not self.syncStatus.peers[name].lastUpdate then
    self.syncStatus.peers[name].lastUpdate = GetTime();
  end
  return self.syncStatus.peers[name];
end

function LogTracker:CleanupPlayerData()
  local playerData = self.db.playerData;
  local kept = 0;
  local removed = 0;
  self.db.playerData = {};
  for realmName, playerList in pairs(playerData) do
    self.db.playerData[realmName] = {};
    for name, playerDetails in pairs(playerList) do
      local playerAge = time() - playerDetails.lastUpdate;
      if playerAge < playerAgeLimit then
        self.db.playerData[realmName][name] = playerDetails;
        kept = kept + 1;
      else
        removed = removed + 1;
      end
    end
  end
  self:LogDebug("Player data cleanup done!", "Removed " .. removed .. " / " .. (kept + removed) .. " players.");
  return removed, kept;
end

function LogTracker:CompareAchievements(unitId)
  if not UnitIsPlayer(unitId) or not CheckInteractDistance(unitId, 1) then
    return;
  end
  if self.achievementTime ~= nil then
    local timeGone = GetTime() - self.achievementTime;
    if (timeGone < 10) then
      return;
    end
  end
  local realmName = GetRealmName();
  local playerName = UnitName(unitId);
  self.db.playerData[realmName] = self.db.playerData[realmName] or {};
  local playerDetails = self.db.playerData[realmName][playerName];
  local playerAge = playerUpdateInterval + 1;
  if playerDetails then
    playerAge = time() - playerDetails.lastUpdate;
  end
  if playerAge > playerUpdateInterval then
    local _, _, classId = UnitClass(unitId);
    self.achievementTime = GetTime();
    self.achievementUnit = unitId;
    self.achievementGuid = UnitGUID(unitId);
    self.achievementDetails.name = playerName;
    self.achievementDetails.class = classId;
    self.achievementDetails.level = UnitLevel(unitId);
    self.achievementDetails.faction = UnitFactionGroup(unitId);
    ClearAchievementComparisonUnit();
    SetAchievementComparisonUnit(unitId);
  end
end

function LogTracker:SyncCheck()
  local now = GetTime();
  if self.syncStatus.throttleTimer > now then
    return;
  end
  self.syncStatus.throttleTimer = now + syncThrottle;
  local chatBandwidth = ChatThrottleLib:UpdateAvail();
  if chatBandwidth < 3000 then
    self:LogDebug("SyncPeers", "Chat bandwidth limited, skipping sync for now.", chatBandwidth);
    return;
  end
  self:SyncSendHello("YELL");
  if self.syncStatus.peersUpdate < now then
    -- Update sync list (Every 30 minutes one full update)
    self.syncStatus.peersUpdate = now + syncPeerUpdates;
    local guild, party, raid, whisper = self:SyncUpdateFull();
    self:LogDebug("SyncPeers", "Updated available peers", "Guild: " .. guild, "Party: " .. party, "Raid: " .. raid, "Whisper: " .. whisper);
    return;
  end
  if self.syncStatus.historyUpdate < now then
    -- Update sync history
    self.syncStatus.historyUpdate = now + syncHistoryUpdates;
    wipe(self.db.syncHistory);
    local last = #(self.syncStatus.players);
    local first = max(0, last - syncHistoryCount) + 1;
    for i = first, last do
      tinsert(self.db.syncHistory, self.syncStatus.players[i]);
    end
    return;
  end
  if (self.syncStatus.requestsTimer < now) and #(self.syncStatus.requests) > 0 then
    -- Request missing data from other peers
    local namesLimit = 251 - strlen(addonPrefix);
    local namesList = "";
    local i = 1;
    local last = #(self.syncStatus.requests);
    while (i <= last) and (strlen(self.syncStatus.requests[i]) < namesLimit) do
      if namesList ~= "" then
        namesList = namesList .. "#";
      end
      namesList = namesList .. self.syncStatus.requests[i];
      namesLimit = 251 - strlen(addonPrefix) - strlen(namesList);
      i = i + 1;
    end
    --self:LogDebug("Request", namesList);
    local guild, party, raid, whisper = self:SyncUpdateFull();
    if (guild + party + raid + whisper) > 0 then
      self:LogDebug("Requesting Sync for ", i, " players");
    end
    if guild > 0 then
      self:SendAddonMessage("rq", namesList, "GUILD");
    end
    if party > 0 then
      self:SendAddonMessage("rq", namesList, "PARTY");
    end
    if raid > 0 then
      self:SendAddonMessage("rq", namesList, "RAID");
    end
    if whisper > 0 then
      for name, peer in pairs(self.syncStatus.peers) do
        if peer.isWhisper then
          self:SendAddonMessage("rq", namesList, "WHISPER", name);
        end
      end
    end
    -- Clear request list and timer
    local ratio = 1 - i / syncRequestLimit;
    self.syncStatus.requestsTimer = GetTime() + syncRequestDelay * ratio;
    wipe(self.syncStatus.requests);
  end
  if self.syncStatus.timer < now then
    -- Check for pending sync data (Every 5 seconds if due and chat bandwidth available)
    self.syncStatus.timer = now + syncInterval;
    local playerCount = #(self.syncStatus.players);
    if playerCount > 0 then
      -- Check guild
      local guildPeers, guildOffset = self:SyncUpdateGuild();
      if guildPeers > 0 and guildOffset < playerCount then
        local offset, sent = self:SyncSend("GUILD", nil, guildOffset, syncBatchPlayers);
        self.syncStatus.guild = offset;
        self:LogDebug("Sync", guildPeers, "Guild", offset, "/", playerCount, " (" .. sent .. ")");
        return;
      end
      -- Check party
      local partyPeers, partyOffset = self:SyncUpdateParty();
      if partyPeers > 0 and partyOffset < playerCount then
        local offset, sent = self:SyncSend("PARTY", nil, partyOffset, syncBatchPlayers);
        self.syncStatus.party = offset;
        self:LogDebug("Sync", partyPeers, "Party", offset, "/", playerCount, " (" .. sent .. ")");
        return;
      end
      -- Check raid
      local raidPeers, raidOffset = self:SyncUpdateRaid();
      if raidPeers > 0 and raidOffset < playerCount then
        local offset, sent = self:SyncSend("RAID", nil, raidOffset, syncBatchPlayers);
        self.syncStatus.party = offset;
        self:LogDebug("Sync", raidPeers, "Raid", offset, "/", playerCount, " (" .. sent .. ")");
        return;
      end
      -- Check whisper
      local whisperPeers, whisperOffset = self:SyncUpdateWhisper();
      if whisperPeers > 0 and whisperOffset < playerCount then
        for name, peer in pairs(self.syncStatus.peers) do
          if peer.isWhisper and peer.syncOffset < playerCount then
            local offset, sent = self:SyncSend("RAID", nil, peer.syncOffset, syncBatchPlayers);
            peer.syncOffset = offset;
            self:LogDebug("Sync", peer.name, "Whisper", offset, "/", playerCount, " (" .. sent .. ")");
            return;
          end
        end
      end
    end
  end
  self:SyncReportPeers();
end

function LogTracker:SyncUpdateFull()
  local guild = self:SyncUpdateGuild();
  local party = self:SyncUpdateParty();
  local raid = self:SyncUpdateRaid();
  local whisper = self:SyncUpdateWhisper();
  return guild, party, raid, whisper;
end

function LogTracker:SyncUpdateGuild()
  if not IsInGuild() then
    return 0, 0;
  end
  -- Send greeting if not throttled
  self:SyncSendHello("GUILD");
  -- Clear existing guild flags
  for name, peer in pairs(self.syncStatus.peers) do
    peer.isGuild = false;
  end
  -- Set guild flags for currently online members
  local peers = 0;
  local numTotalMembers, numOnlineMaxLevelMembers, numOnlineMembers = GetNumGuildMembers();
  self.syncStatus.guild = #(self.syncStatus.players);
  for i = 1, numTotalMembers do
    local nameFull, _, _, level, class, _, _, _, online = GetGuildRosterInfo(i);
    if nameFull then
      local name, realm = strsplit("-", nameFull);
      local peer = self:GetSyncPeer(name, true, true);
      if peer then
        peer.isOnline = online;
        if peer.isOnline then
          peer.isGuild = true;
          peer.lastSeen = GetTime();
          self.syncStatus.guild = min(self.syncStatus.guild, peer.syncOffset);
          peers = peers + 1;
        end
      end
    end
  end
  if peers == 0 then
    self.syncStatus.guild = 0;
  end
  return peers, self.syncStatus.guild;
end

function LogTracker:SyncUpdateParty()
  if not IsInGroup() or IsInRaid() then
    return 0, 0;
  end
  -- Send greeting if not throttled
  self:SyncSendHello("PARTY");
  -- Clear existing party flags
  for name, peer in pairs(self.syncStatus.peers) do
    peer.isParty = false;
  end
  -- Set party flags for currently online members
  local peers = 0;
  local members = GetNumGroupMembers();
  self.syncStatus.party = #(self.syncStatus.players);
  for i = 1, members do
    local unitId = "party" .. i;
    local name = UnitName(unitId);
    if name then
      local peer = self:GetSyncPeer(name, true, true);
      if peer then
        peer.isOnline = UnitIsConnected(unitId);
        if peer.isOnline then
          peer.isParty = true;
          peer.lastSeen = GetTime();
          self.syncStatus.party = min(self.syncStatus.party, peer.syncOffset);
          peers = peers + 1;
        end
      end
      self:CompareAchievements(unitId);
    end
  end
  if peers == 0 then
    self.syncStatus.party = 0;
  end
  return peers, self.syncStatus.party;
end

function LogTracker:SyncUpdateRaid()
  if not IsInRaid() then
    return 0, 0;
  end
  -- Send greeting if not throttled
  self:SyncSendHello("RAID");
  -- Clear existing raid flags
  for name, peer in pairs(self.syncStatus.peers) do
    peer.isRaid = false;
  end
  -- Set raid flags for currently online members
  local peers = 0;
  local members = GetNumGroupMembers();
  self.syncStatus.raid = #(self.syncStatus.players);
  for i = 1, members do
    local unitId = "raid" .. i;
    local name = UnitName(unitId);
    if name then
      local peer = self:GetSyncPeer(name, true, true);
      if peer then
        peer.isOnline = UnitIsConnected(unitId);
        if peer.isOnline then
          peer.isRaid = true;
          peer.lastSeen = GetTime();
          self.syncStatus.raid = min(self.syncStatus.raid, peer.syncOffset);
          peers = peers + 1;
        end
      end
      self:CompareAchievements(unitId);
    end
  end
  if peers == 0 then
    self.syncStatus.raid = 0;
  end
  return peers, self.syncStatus.raid;
end

function LogTracker:SyncUpdateWhisper()
  local peers = 0;
  for name, peer in pairs(self.syncStatus.peers) do
    -- Update online status
    if peer.isOnline then
      local peerAge = GetTime() - peer.lastSeen;
      if peerAge > syncPeerTimeout then
        peer.isOnline = false;
      end
    end
    -- Check if peer should sync via whisper
    if peer.isOnline and not peer.isGuild and not peer.isParty and not peer.isRaid and peer.syncOffset < playerCount then
      peer.isWhisper = true;
      self.syncStatus.whisper = min(self.syncStatus.whisper, peer.syncOffset);
      peers = peers + 1;
    else
      peer.isWhisper = false;
    end
  end
  if peers == 0 then
    self.syncStatus.whisper = 0;
  end
  return peers, self.syncStatus.whisper;
end

function LogTracker:SyncRequest(name)
  -- Check if user is already in the request list
  local requestIndex = nil;
  for i, requestName in ipairs(self.syncStatus.requests) do
    if requestName == name then
      requestIndex = i;
      break;
    end
  end
  -- Remove existing entry if present (will be prepended)
  if requestIndex ~= nil then
    tremove(self.syncStatus.requests, requestIndex);
  end
  -- Shorten list to respect limit
  while #(self.syncStatus.requests) >= syncRequestLimit do
    tremove(self.syncStatus.requests, syncRequestLimit);
  end
  -- Prepend requested player
  tinsert(self.syncStatus.requests, 1, name);
end

function LogTracker:SyncRequestRemove(name)
  -- Check if user is already in the request list
  local requestIndex = nil;
  for i, requestName in ipairs(self.syncStatus.requests) do
    if requestName == name then
      requestIndex = i;
      break;
    end
  end
  -- Remove existing entry if present (will be prepended)
  if requestIndex ~= nil then
    tremove(self.syncStatus.requests, requestIndex);
    return true;
  end
  return false;
end

function LogTracker:SyncSend(type, target, offset, limit)
  local playerCount = #(self.syncStatus.players);
  if playerCount == 0 then
    return;
  end
  -- Apply defaults
  offset = (offset or 0) + 1;
  limit = limit or 20;
  local last = min(playerCount, limit + offset);
  local amount = 0;
  -- Send messages
  local realmName = GetRealmName();
  self.db.playerData[realmName] = self.db.playerData[realmName] or {};
  for i = offset, last do
    local playerName = self.syncStatus.players[i];
    if self:QueuePlayerData(playerName) then
      amount = amount + 1;
    end
  end
  -- Flush messages
  self:FlushAddonMessages(type, target);
  -- Update peers
  self:SyncUpdatePeers(type, target, amount, last);
  -- Return new offset
  return last, amount;
end

function LogTracker:SyncSendHello(channel, target)
  local now = GetTime();
  if (channel == "GUILD") and (self.syncStatus.peersChannel.guild < now) then
    self.syncStatus.peersChannel.guild = now + syncPeerGreeting;
    self:SendAddonMessage("hi", nil, channel, target);
  elseif (channel == "PARTY") and (self.syncStatus.peersChannel.party < now) then
    self.syncStatus.peersChannel.party = now + syncPeerGreeting;
    self:SendAddonMessage("hi", nil, channel, target);
  elseif (channel == "RAID") and (self.syncStatus.peersChannel.raid < now) then
    self.syncStatus.peersChannel.raid = now + syncPeerGreeting;
    self:SendAddonMessage("hi", nil, channel, target);
  elseif (channel == "YELL") and (self.syncStatus.peersChannel.yell < now) then
    self.syncStatus.peersChannel.yell = now + syncPeerGreeting;
    self:SendAddonMessage("hi", nil, channel, target);
  end
end

function LogTracker:SyncUpdatePeers(type, target, sentCount, offset)
  for name, peerStatus in pairs(self.syncStatus.peers) do
    if (type == "GUILD" and peerStatus.isGuild) or (type == "PARTY" and peerStatus.isParty)
        or (type == "RAID" and peerStatus.isRaid) or (type == "WHISPER" and name == target)
    then
      peerStatus.sentOverall = peerStatus.sentOverall + sentCount;
      peerStatus.syncOffset = max(peerStatus.syncOffset, offset);
      peerStatus.chatReported = false;
      peerStatus.lastUpdate = GetTime();
    end
  end
end

function LogTracker:SyncReportPeers()
  local now = GetTime();
  for name, peerStatus in pairs(self.syncStatus.peers) do
    if not peerStatus.chatReported then
      local age = now - peerStatus.lastReport;
      if age > 30 then
        self:LogDebug(
          "Sync stats for peer " .. name .. ":",
          "Received: " .. peerStatus.receivedOverall,
          "Updated: " .. peerStatus.receivedUpdates,
          "Sent: " .. peerStatus.sentOverall
        );
        peerStatus.chatReported = true;
        peerStatus.lastReport = now;
      end
    end
  end
end

function LogTracker:SendSystemChatLine(text)
  local chatInfo = ChatTypeInfo["SYSTEM"];
  local i;
  for i = 1, 16 do
    local chatFrame = _G["ChatFrame" .. i];
    if (chatFrame) then
      chatFrame:AddMessage(text, chatInfo.r, chatInfo.g, chatInfo.b, chatInfo.id);
    end
  end
end

function LogTracker:SendPlayerInfoToChat(playerData, playerName, playerRealm, showEncounters)
  for zoneId, zone in pairs(playerData.performance) do
    local zoneName, zoneProgress, zoneSpecs = self:GetPlayerZonePerformance(zone, playerData.class);
    self:SendSystemChatLine(self:GetPlayerLink(playerName) .. " " .. strjoin(" ", self:GetPlayerZonePerformance(zone, playerData.class)));
    if showEncounters then
      for _, encounter in ipairs(zone.encounters) do
        local encounterName, encounterRating = self:GetPlayerEncounterPerformance(encounter, playerData.class);
        self:SendSystemChatLine("  " .. encounterName .. ": " .. encounterRating);
      end
    end
  end
  self:SendSystemChatLine(L["DATE_UPDATE"] .. ": " .. date(L["DATE_FORMAT"], playerData.last_update));
end

function LogTracker:SetPlayerInfoTooltip(playerData, playerName, playerRealm, disableShiftNotice)
  for zoneIdSize, zone in pairs(playerData.performance) do
    local zoneId, zoneSize = strsplit("-", zoneIdSize);
    if (zoneSize == "10" and not self.db.hide10Player) or (zoneSize == "25" and not self.db.hide25Player) then
      local zoneName, zoneProgress, zoneSpecs = self:GetPlayerZonePerformance(zone, playerData.class);
      GameTooltip:AddDoubleLine(
        zoneName .. " " .. zoneProgress, zoneSpecs,
        1, 1, 1, 1, 1, 1
      );
      if IsShiftKeyDown() then
        for _, encounter in ipairs(zone.encounters) do
          local encounterName, encounterRating = self:GetPlayerEncounterPerformance(encounter, playerData.class, true);
          GameTooltip:AddDoubleLine(
            "  " .. encounterName, encounterRating,
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
