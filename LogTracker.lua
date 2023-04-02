local _, L = ...;
local addonPrefix = "LTSY";
local addonPrefixCompressed = "LTSC";
local dbVersion = 1;
local syncVersion = 3;
local startupDelay = 10;               -- 10 seconds
local syncThrottle = 2;                -- 2 seconds
local syncInterval = 5;                -- 5 seconds
local syncHistoryUpdates = 300;        -- 5 minutes
local syncHistoryCount = 50;           -- Keep up to 50 players in the "recently updated" list for sync between logins
local syncHistoryLimit = 1500;         -- Do not sync more than 1000 players to new peers
local syncPeerGreeting = 120;          -- 2 minutes (interval to greet potential peers on guild/raid/group/yell)
local syncPeerTimeout = 300;           -- 5 minutes (time without contact at which to assume a peer has gone offline)
local syncPeerUpdates = 1800;          -- 30 minutes (interval to check available peers)
local syncPeerOnlineCheck = 1800;      -- 30 minutes (check if peers are online if there is nothing to do)
local syncBatchPlayers = 20;           -- Sync up to 20 players per batch
local syncRequestLimit = 50;           -- Keep up to 50 players in a request list (to retrieve missing data from other clients)
local syncRequestDelay = 10;           -- 10 seconds
local playerUpdateInterval = 3600;     -- 1 hours
local playerLogsInterval = 86400;      -- 1 day
local playerAgeLimit = 86400 * 21;     -- 3 weeks
local peerAgeLimit = 86400 * 7;        -- 1 week
local appQueueUpdateInterval = 10;     -- 10 seconds

-- Libraries
local Comm = LibStub:GetLibrary("AceComm-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate");
local LibSerialize = LibStub:GetLibrary("LibSerialize");

LogTracker = CreateFrame("Frame", "LogTracker", UIParent);

function LogTracker:Init()
  self.defaults = {
    debug = false,
    chatExtension = true,
    tooltipExtension = true,
    lfgExtension = true,
    slashExtension = true,
    hide10Player = false,
    hide25Player = false,
    syncSend = true,
    syncReceive = true,
    appImportCount = 0,
    appPriorityOnly = false
  };
  self.syncStatus = {
    guild = 0,
    guildVersion = syncVersion,
    party = 0,
    partyVersion = syncVersion,
    raid = 0,
    raidVersion = syncVersion,
    whisper = 0,
    offsetStart = 0,
    timer = GetTime(),
    peers = {},
    peersUpdate = GetTime(),
    peersChannel = {
      guild = GetTime() + random(1, 10),
      party = GetTime() + random(1, 10),
      raid = GetTime() + random(1, 10),
      yell = GetTime() + random(1, 10),
      whisper = {}
    },
    players = {},
    requests = {},
    requestsLogs = {},
    requestsLock = {},
    requestsLockLogs = {},
    requestsTimer = GetTime(),
    historyUpdate = GetTime(),
    messages = {},
    messageLength = 0,
    throttleTimer = GetTime() + startupDelay,
  };
  self.appSyncStatusTime = time();
  self.versionNoticeSent = false;
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
  self:RegisterEvent("CHAT_MSG_CHANNEL");
  self:RegisterEvent("MODIFIER_STATE_CHANGED");
  self:RegisterEvent("PLAYER_ENTERING_WORLD");
  self:RegisterEvent("PLAYER_TARGET_CHANGED");
  self:RegisterEvent("INSPECT_ACHIEVEMENT_READY");
  self:RegisterEvent("NAME_PLATE_UNIT_ADDED");
  self:RegisterEvent("GUILD_ROSTER_UPDATE");
  self:RegisterEvent("GROUP_ROSTER_UPDATE");
  self:RegisterEvent("RAID_ROSTER_UPDATE");
  self:RegisterEvent("FRIENDLIST_UPDATE");
  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
  self:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED");
  Comm:RegisterComm(addonPrefixCompressed, function(...)
    LogTracker:OnCommMessage(...);
  end);
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
  -- Show due app updates
  if self.db.appImportCount > 0 then
    if not self.appSyncStatus then
      self.appSyncStatus = LFGBrowseFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmallLeft");
      self.appSyncStatus:SetPoint("TOPLEFT", LFGBrowseFrame, "TOPLEFT", 74, -50);
      self.appSyncStatus:SetText("");
      self.appSyncStatus:Show();
    end
    if not self.appSyncHelp then
      self.appSyncHelp = LFGBrowseFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmallLeft");
      self.appSyncHelp:SetPoint("TOPLEFT", LFGBrowseFrame, "TOPLEFT", 54, -72);
      self.appSyncHelp:SetText("|cffa0a0a0Do a /reload to start updating / import results|r");
      self.appSyncHelp:Show();
    end
    self:UpdateAppQueue();
  end
  -- Show logs within the group finder
  hooksecurefunc("LFGBrowseSearchEntry_Update", function(frame)
    if not frame.Logs then
      frame.Logs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
      frame.Logs:SetPoint("TOPLEFT", frame, "TOPRIGHT", -28, -13)
    end
    local searchResultInfo = C_LFGList.GetSearchResultInfo(frame.resultID);
    local isSolo = searchResultInfo.numMembers == 1;
    if isSolo then
      local logTargets = self:GetGroupFinderLogTargets(searchResultInfo);
      local playerData, playerName, playerRealm = self:GetPlayerData(searchResultInfo.leaderName, nil, nil, nil, true);
      if playerData then
        frame.Logs:SetText(self:GetPlayerOverallPerformance(playerData, logTargets));
      else
        frame.Logs:SetText(self:GetColoredText("muted", "--"));
      end
      frame.Logs:Show();
    else
      frame.Logs:Hide();
    end
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
  -- Send player data to other clients
  self.optionSyncSend = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
  self.optionSyncSend:SetPoint("TOPLEFT", 20, -140);
  self.optionSyncSend.Text:SetText(L["OPTION_SYNC_SEND"]);
  self.optionSyncSend:SetScript("OnClick", function(_, value)
    self.db.syncSend = self.optionSyncSend:GetChecked();
  end)
  self.optionSyncSend:SetChecked(self.db.syncSend);
  -- Receive player data from other clients
  self.optionSyncReceive = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
  self.optionSyncReceive:SetPoint("TOPLEFT", 20, -160);
  self.optionSyncReceive.Text:SetText(L["OPTION_SYNC_RECEIVE"]);
  self.optionSyncReceive:SetScript("OnClick", function(_, value)
    self.db.syncReceive = self.optionSyncReceive:GetChecked();
  end)
  self.optionSyncReceive:SetChecked(self.db.syncReceive);
  -- Only update prioritized players
  self.optionAppPriorityOnly = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
  self.optionAppPriorityOnly:SetPoint("TOPLEFT", 20, -180);
  self.optionAppPriorityOnly.Text:SetText(L["OPTION_APP_PRIORITY_ONLY"]);
  self.optionAppPriorityOnly:SetScript("OnClick", function(_, value)
    self.db.appPriorityOnly = self.optionAppPriorityOnly:GetChecked();
  end)
  self.optionAppPriorityOnly:SetChecked(self.db.appPriorityOnly or false);
  
  -- Debug output
  self.optionShowDebug = CreateFrame("CheckButton", nil, self.optionsPanel, "InterfaceOptionsCheckButtonTemplate");
  self.optionShowDebug:SetPoint("TOPLEFT", 20, -200);
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

function LogTracker:StringifyData(data, glueOuter, glueInner)
  glueOuter = glueOuter or "|";
  glueInner = glueInner or ",";
  local dataStr = {};
  for _, values in ipairs(data) do
    tinsert(dataStr, strjoin(glueInner, unpack(values)));
  end
  return strjoin(glueOuter, unpack(dataStr));
end

function LogTracker:UnstringifyData(dataStr, glueOuter, glueInner)
  glueOuter = glueOuter or "|";
  glueInner = glueInner or ",";
  local data = {};
  local dataRaw = { strsplit(glueOuter, dataStr) };
  for _, valuesStr in ipairs(dataRaw) do
    tinsert(data, { strsplit(glueInner, valuesStr) });
  end
  return data;
end

function LogTracker:SendAddonMessage(action, data, type, target, prio)
  if type == "WHISPER" then
    local peer = self:GetSyncPeer(target, true, true);
    if peer and not peer.isOnline then
      return;
    end
  end
  local message = action;
  if data ~= nil then
    message = message .. "|" .. data;
  end
  --self:LogDebug("SendAddonMessage", action, type, target);
  ChatThrottleLib:SendAddonMessage(prio or "NORMAL", addonPrefix, message, type, target);
end

function LogTracker:SendCommMessage(action, data, type, target, prio)
  local message = action.."#"..LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(data)));
  --self:LogDebug("SendCommMessage", action, type, target);
  Comm:SendCommMessage(addonPrefixCompressed, message, type, target, prio or "NORMAL");
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

function LogTracker:InsertPlayerData(data, name, requireLogs)
  local realmName = GetRealmName();
  local playerData = self.db.playerData[realmName][name];
  if playerData and (playerData.class > 0) and (playerData.lastUpdateLogs or not requireLogs) then
    tinsert(data, {
      name =  name, level = playerData.level, faction = playerData.faction, class = playerData.class,
      lastUpdate = playerData.lastUpdate, lastUpdateLogs = playerData.lastUpdateLogs or playerData.lastUpdate,
      encounters = playerData.encounters, logs = playerData.logs
    });
    return true;
  end
  return false;
end

function LogTracker:QueuePlayerData(name, requireLogs)
  local realmName = GetRealmName();
  local playerData = self.db.playerData[realmName][name];
  if playerData and (playerData.class > 0) and (playerData.lastUpdateLogs or not requireLogs) then
    local message = name .. "#" .. playerData.level .. "#" .. playerData.faction .. "#" .. playerData.class .. "#" .. playerData.lastUpdate .. "#" .. syncVersion;
    self:QueueAddonMessage("pl", message);
    if playerData.logs then
      for zoneId, logData in pairs(playerData.logs) do
        local allstarsData = self:StringifyData(self:UnstringifyData(logData[3]), "/");
        local encounterData = self:StringifyData(self:UnstringifyData(logData[4]), "/");
        -- playerName#zoneId#ecounters#encountersKilled#allstarsData#encounterData
        self:QueueAddonMessage("plL", name .. "#" .. zoneId .. "#" .. logData[1] .. "#" .. logData[2] .. "#" .. allstarsData .. "#" .. encounterData);
      end
    else
      for zoneId, encounterData in pairs(playerData.encounters) do
        self:QueueAddonMessage("plE", name .. "#" .. zoneId .. "#" .. encounterData);
      end
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
  local playerData, playerName, playerRealm = self:GetPlayerData(targetName, nil, nil, nil, true);
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
  elseif (event == "CHAT_MSG_CHANNEL") then
    self:OnChatMsgChannel(...);
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
  elseif (event == "FRIENDLIST_UPDATE") then
    self:OnFriendlistUpdate(...);
  elseif (event == "LFG_LIST_SEARCH_RESULT_UPDATED") then
    self:OnLfgListSearchResultUpdated(...);
  elseif (event == "PLAYER_ENTERING_WORLD") then
    self:OnPlayerEnteringWorld(...);
  else
    self:LogDebug("OnEvent", event, ...);
  end
end

function LogTracker:OnPlayerEnteringWorld()
  -- Workaround for misaligned tooltip
  if TacoTipConfig and not TacoTipConfig.show_guild_name then
    print(self:GetColoredText("error", L["TACOTIP_GUILD_NAME_WARNING"]));
  end
  -- Update self
  self:CompareAchievements("player", 30);
  -- Greet peers
  if IsInGuild() then
    self:SendAddonMessage("hi", nil, "GUILD");
  end
  if IsInRaid() then
    self:SendAddonMessage("hi", nil, "RAID");
  elseif IsInGroup() then
    self:SendAddonMessage("hi", nil, "PARTY");
  end
  -- Hook into Group finder frame
  LogTracker:InitLogsFrame();
  -- Hook into Group finder tooltip
  if LFGBrowseSearchEntryTooltip then
    hooksecurefunc("LFGBrowseSearchEntryTooltip_UpdateAndShow", function(tooltip, ...)
      LogTracker:OnTooltipShow(tooltip, ...);
    end);
  end
  -- WCL Notice
  self:LogOutput("Log ratings (if shown) are owned by and obtained from warcraftlogs.com. Please consider supporting them!");
end

function LogTracker:OnAddonLoaded(addonName)
  if (addonName ~= "LogTracker") then
    return;
  end
  LogTrackerDB = LogTrackerDB or self.db;
  self.db = LogTrackerDB;
  self.db.version = self.db.version or 0;
  if self.db.version < dbVersion then
    self.db.playerData = {};
    self.db.syncHistory = {};
    self.db.version = dbVersion;
  else
    self.db.playerData = self.db.playerData or {};
  end
  if self.db.syncSend == nil then
    self.db.syncSend = self.defaults.syncSend;
  end
  if self.db.syncReceive == nil then
    self.db.syncReceive = self.defaults.syncReceive;
  end
  if self.db.syncHistory then
    self.syncStatus.players = { unpack(self.db.syncHistory) };
  else
    self.db.syncHistory = {};
  end
  if not self.db.syncPeers then
    self.db.syncPeers = {};
  end
  if self.db.appImportCount == nil then
    self.db.appImportCount = 0;
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
  -- Filter system messages
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(...)
    return LogTracker:OnChatMsgSystemFilter(...);
  end);
  -- Cleanup player data
  self:CleanupPlayerData();
  self:CleanupPeerData();
  -- Import app data
  self:ImportAppData();
end

function LogTracker:OnCommMessage(prefix, message, distribution, sender)
  if not self.db.syncSend and not self.db.syncReceive then
    return;
  end
  self:SyncCheck();
  if prefix ~= addonPrefixCompressed then
    return;
  end
  local split_pos = strfind(message, "#");
  if not split_pos then
    self:LogDebug("OnCommMessage", "Invalid message received.");
    return;
  end
  local message_type = strsub(message, 1, split_pos-1);
  local message_data_raw = strsub(message, split_pos+1);
  local message_data = LibDeflate:DecodeForPrint(message_data_raw);
  if not message_data then
    self:LogDebug("OnCommMessage", "Error decoding message data.");
    return;
  end
  message_data = LibDeflate:DecompressDeflate(message_data);
  if not message_data then
    self:LogDebug("OnCommMessage", "Error decompressing message data.");
    return;
  end
  local success, message_data_obj = LibSerialize:Deserialize(message_data);
  if not success then
    self:LogDebug("OnCommMessage", "Error deserializing message data.");
    return;
  end
  self:OnCommMessageDecoded(message_type, message_data_obj, distribution, sender);
end

function LogTracker:OnCommMessageDecoded(message_type, message_data, distribution, sender)
  local realmName = GetRealmName();
  local syncName = strsplit("-", sender);
  local peer = self:GetSyncPeer(syncName, false, false, 2);
  if peer == nil then
    return;
  end
  if message_type == "hi" then
    if message_data.versionAddon then
      local myAddonMajor, myAddonMinor, myAddonPatch = strsplit(".", GetAddOnMetadata("LogTracker", "version"));
      local peerAddonMajor, peerAddonMinor, peerAddonPatch = strsplit(".", message_data.versionAddon);
      local myAddonNumeric = tonumber(myAddonMajor) * 10000 + tonumber(myAddonMinor) * 100 + tonumber(myAddonPatch);
      local peerAddonNumeric = tonumber(peerAddonMajor) * 10000 + tonumber(peerAddonMinor) * 100 + tonumber(peerAddonPatch);
      if (myAddonNumeric < peerAddonNumeric) and not self.versionNoticeSent then
        self.versionNoticeSent = true;
        self:LogOutput("There is a new version of LogTracker available! (" .. message_data.versionAddon .. ")");
      end
    end
    peer.version = message_data.version or peer.version;
    if message_data.peers then
      for _, name in ipairs(message_data.peers) do
        self:OnPlayerOnline(name);
        -- Add/update peer history
        if not self.db.syncPeers[realmName] then
          self.db.syncPeers[realmName] = {};
        end
        if not self.db.syncPeers[realmName][name] then
          self.db.syncPeers[realmName][name] = { lastUpdate = time() };
        end
      end
    end
    if peer.version > syncVersion and not self.versionNoticeSent then
      self.versionNoticeSent = true;
      self:LogOutput("There is a new version of LogTracker available! Data updates may be limited until you update.");
    end
  elseif message_type == "pl" then
    if not self.db.syncReceive then
      return;
    end
    peer.version = message_data.version or peer.version;
    for i, playerDataRcv in ipairs(message_data.players) do
      local playerData = self.db.playerData[realmName][playerDataRcv.name];
      local updated = false;
      peer.receivedOverall = peer.receivedOverall + 1;
      if not playerData then
        playerData = { encounters = {}, lastUpdate = 0 };
      end
      if (playerDataRcv.lastUpdate < time()) then
        if (playerData.lastUpdate < playerDataRcv.lastUpdate) then
          playerData.syncFrom = syncName;
          playerData.level = playerDataRcv.level;
          playerData.class = playerDataRcv.class;
          playerData.faction = playerDataRcv.faction;
          playerData.lastUpdate = playerDataRcv.lastUpdate;
          playerData.encounters = playerDataRcv.encounters;
          updated = true;
        end
        if not playerData.lastUpdateLogs or (playerData.lastUpdateLogs < playerDataRcv.lastUpdateLogs) then
          playerData.syncFromLogs = syncName;
          playerData.lastUpdateLogs = playerDataRcv.lastUpdateLogs;
          playerData.logs = playerDataRcv.logs;
          updated = true;
        end
      end
      if updated then
        peer.receivedUpdates = peer.receivedUpdates + 1;
        self.db.playerData[realmName][playerDataRcv.name] = playerData;
        -- Update tooltip if target is active
        local unitName, unitId = GameTooltip:GetUnit();
        if unitId and unitName and (unitName == playerDataRcv.name) then
          self:LogDebug("Received data for active tooltip, updating... (Sync from "..syncName..")");
          GameTooltip:SetUnit(unitId);
        end
      end
    end
  elseif message_type == "rq" then
    if not self.db.syncSend then
      return;
    end
    peer.version = message_data.version or peer.version;
    -- Request for player data
    local amount = self:SyncSendByNames(message_data.names, distribution, sender);
    self:LogDebug("Sync v2 Request (base)", syncName, "Sent " .. amount .. " / " .. #message_data.names .. " players");
    --self:LogDebug("Sync Request (base)", unpack(message_data.names));
  elseif message_type == "rqL" then
    if not self.db.syncSend then
      return;
    end
    peer.version = message_data.version or peer.version;
    -- Request for player logs
    local amount = self:SyncSendByNames(message_data.names, distribution, sender, true);
    self:LogDebug("Sync v2 Request (logs)", syncName, "Sent " .. amount .. " / " .. #message_data.names .. " players");
    --self:LogDebug("Sync Request (logs)", unpack(message_data.names));
  elseif message_type == "rqC" then
    if not self.db.syncSend then
      return;
    end
    peer.version = message_data.version or peer.version;
    local amountSent = 0;
    local amountRequested = 0;
    if #message_data.names_base > 0 then
      amountSent = amountSent + self:SyncSendByNames(message_data.names_base, distribution, sender);
      amountRequested = amountRequested + #message_data.names_base;
    end
    if #message_data.names_logs > 0 then
      amountSent = amountSent + self:SyncSendByNames(message_data.names_logs, distribution, sender, true);
      amountRequested = amountRequested + #message_data.names_logs;
    end
    self:LogDebug("Sync v3 Request", syncName, "Sent " .. amountSent .. " / " .. amountRequested .. " players");
  end
  peer.chatReported = false;
  peer.lastUpdate = GetTime();
  peer.isOnline = true;
  if distribution == "GUILD" then
    peer.isGuild = true;
  elseif distribution == "PARTY" then
    peer.isParty = true;
  elseif distribution == "RAID" then
    peer.isRaid = true;
  end
end

function LogTracker:OnChatMsgAddon(prefix, message, source, sender)
  if not self.db.syncSend and not self.db.syncReceive then
    return;
  end
  self:SyncCheck();
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
      if not self.db.syncReceive then
        return;
      end
      -- Player base data
      local data = tremove(parts, 1);
      if data then
        local name, level, faction, class, lastUpdate, peerSyncVersion = strsplit("#", data);
        lastUpdate = tonumber(lastUpdate);
        local playerData = self.db.playerData[realmName][name];
        peer.receivedOverall = peer.receivedOverall + 1;
        peer.version = peerSyncVersion or peer.version;
        if not playerData then
          playerData = { encounters = {}, lastUpdate = lastUpdate - 1 };
        end
        if (playerData.lastUpdate < lastUpdate) then
          playerData.level = level;
          playerData.faction = faction;
          playerData.lastUpdate = lastUpdate;
          playerData.syncFrom = syncName;
          if not playerData.class or (peerSyncVersion and tonumber(peerSyncVersion) >= 1) then
            playerData.class = class;
          end
          self.db.playerData[realmName][name] = playerData;
          peer.receivedUpdates = peer.receivedUpdates + 1;
        elseif not playerData.lastUpdateLogs or (playerData.lastUpdateLogs < lastUpdate) then
          playerData.lastUpdate = lastUpdate;
          playerData.syncFrom = syncName;
          self.db.playerData[realmName][name] = playerData;
          peer.receivedUpdates = peer.receivedUpdates + 1;
        end
      end
    elseif action == "plE" then
      if not self.db.syncSend then
        return;
      end
      -- Player encounter data
      local data = tremove(parts, 1);
      if data then
        local name, zoneId, encouterData = strsplit("#", data);
        local playerData = self.db.playerData[realmName][name];
        if playerData and playerData.syncFrom and playerData.syncFrom == syncName then
          if not playerData.encounters then
            playerData.encounters = {};
          end
          playerData.encounters[zoneId] = encouterData;
          -- Update tooltip if target is active
          local unitName, unitId = GameTooltip:GetUnit();
          if unitId and unitName and (unitName == name) then
            self:LogDebug("Received encounter data for active tooltip, updating... (Sync from "..syncName..")");
            GameTooltip:SetUnit(unitId);
          end
        end
      end
    elseif action == "plL" then
      if not self.db.syncSend then
        return;
      end
      -- Player encounter data
      local data = tremove(parts, 1);
      if data then
        local name, zoneId, encounters, encountersKilled, allstarDataStr, encounterDataStr = strsplit("#", data);
        local playerData = self.db.playerData[realmName][name];
        if playerData and playerData.syncFrom and playerData.syncFrom == syncName then
          allstarDataStr = self:StringifyData(self:UnstringifyData(allstarDataStr, "/"));
          encounterDataStr = self:StringifyData(self:UnstringifyData(encounterDataStr, "/"));
          if not playerData.logs then
            playerData.logs = {};
          end
          playerData.logs[zoneId] = { encounters, encountersKilled, allstarDataStr, encounterDataStr };
          -- Update tooltip if target is active
          local unitName, unitId = GameTooltip:GetUnit();
          if unitId and unitName and (unitName == name) then
            self:LogDebug("Received log data for active tooltip, updating... (Sync from "..syncName..")");
            GameTooltip:SetUnit(unitId);
          end
        end
      end
    elseif action == "rq" then
      if not self.db.syncSend then
        return;
      end
      -- Request for player data
      local data = tremove(parts, 1);
      local names = { strsplit("#", data) };
      local amount = self:SyncSendByNames(names, source, sender);
      self:LogDebug("Sync v1 Request (base)", syncName, "Sent " .. amount .. " / " .. #names .. " players");
    elseif action == "rqL" then
      if not self.db.syncSend then
        return;
      end
      -- Request for player logs
      local data = tremove(parts, 1);
      local names = { strsplit("#", data) };
      local amount = self:SyncSendByNames(names, source, sender, true);
      self:LogDebug("Sync v1 Request (logs)", syncName, "Sent " .. amount .. " / " .. #names .. " players");
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

function LogTracker:OnChatMsgSystemFilter(_, _, text)
  local offlineName = strmatch(text, gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "%%s", "(.+)"));
  if offlineName then
    local peer = self:GetSyncPeer(offlineName, true, true);
    if peer then
      peer.isOnline = false;
      return true;
    end
  end
  return false;
end

function LogTracker:OnChatMsgChannel(text, sender)
  local playerName = strsplit("-", sender);
  self:OnPlayerOnline(playerName);
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
  if not unitId or not UnitIsPlayer(unitId) then
    return;
  end
  local _, _, classIdGame = UnitClass(unitId);
  local classId = self:GetWclClassId(classIdGame);
  local unitName, unitRealm = UnitName(unitId);
  local unitLevel = UnitLevel(unitId);
  local playerData, playerName, playerRealm = self:GetPlayerData(unitName, unitRealm, classId, unitLevel, true);
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
  self:SyncPlayerAdd(playerName);
  -- Remove from request list if present
  self:SyncRequestRemove(playerName);
  --self:LogDebug("Updated achievements for ", playerName);
  -- Update tooltip if target is active
  local unitName, unitId = GameTooltip:GetUnit();
  if unitId and unitName and (unitName == playerName) then
    self:LogDebug("Updated encounter data for active tooltip, updating...");
    GameTooltip:SetUnit(unitId);
  end
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
  self:SyncCheck();
end

function LogTracker:OnMouseoverUnit()
  self:CompareAchievements("mouseover");
  self:SyncCheck();
end

function LogTracker:OnNameplateUnitAdded(unitId)
  self:CompareAchievements(unitId);
  self:SyncCheck();
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

function LogTracker:OnFriendlistUpdate()
  self:SyncUpdateWhisper();
  self:SyncCheck();
end

function LogTracker:OnPlayerOnline(name) -- Called when a player is observed to be online
  local realmName = GetRealmName();
  local peer = self:GetSyncPeer(name, true, true);
  if peer then
    peer.isOnline = true;
  else
    if not self.db.syncPeers[realmName] then
      self.db.syncPeers[realmName] = {};
    end
    if self.db.syncPeers[realmName][name] then
      -- Had communication in the past, create peer and set as online
      peer = self:GetSyncPeer(name, true);
      if peer then
        peer.isOnline = true;
      end
    end
  end
end

function LogTracker:OnLfgListSearchResultUpdated(resultID)
  -- Only prioritize if at least one activity is selected
  local prioritizeResult = false;
  if #LFGBrowseFrame.ActivityDropDown.selectedValues > 0 then
    prioritizeResult = true;
  end
  -- Query all members for a lfg entry
	local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID);
	local numMembers = searchResultInfo.numMembers;
  for i=1, numMembers do
    local name, role, classFileName, className, level, isLeader = C_LFGList.GetSearchResultMemberInfo(resultID, i);
    if name then
      self:OnPlayerOnline(name);
      local classId = self:GetClassId(classFileName);
      local _, _, _, playerDataRaw = self:GetPlayerData(name, nil, classId, level, true);
      if playerDataRaw and prioritizeResult then
        playerDataRaw.priority = 5; -- Add to priority queue
      end
    end
  end
  self:UpdateAppQueue();
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
  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID);
  local logTargets = self:GetGroupFinderLogTargets(searchResultInfo);
  -- Tooltip for lead / single player
  local tooltipName = tooltip:GetName();
  local playerLine = tooltip.Leader.Name:GetText();
  if playerLine == nil then
    return;
  end
  local playerNameTooltip = strsplit("-", playerLine);
  playerNameTooltip = strtrim(playerNameTooltip);
  local playerData, playerName, playerRealm = self:GetPlayerData(playerNameTooltip, nil, nil, nil, true);
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
  tooltip:SetWidth(tooltip:GetWidth() + 110);
end

function LogTracker:OnTooltipShow_LFGMember(frame, logTargets)
  if not frame.Logs then
    frame.Logs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    frame.Logs:SetPoint("TOPLEFT", frame.Role, "TOPRIGHT", 32, -2)
  end
  local memberName = frame.Name:GetText();
  local playerData, playerName, playerRealm = self:GetPlayerData(memberName, nil, nil, nil, true);
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

function LogTracker:GetColoredPercent(value, muted)
  value = floor(value);
  if (value >= 99) then
    return (muted and "|cff7b375b" or "|cffe268a8") .. value .. "|r";
  elseif (value >= 95) then
    return (muted and "|cff805000" or "|cffff8000") .. value .. "|r";
  elseif (value >= 75) then
    return (muted and "|cff561a80" or "|cffa335ee") .. value .. "|r";
  elseif (value >= 50) then
    return (muted and "|cff303888" or "|cff0070ff") .. value .. "|r";
  elseif (value >= 25) then
    return (muted and "|cff0f8800" or "|cff1eff00") .. value .. "|r";
  else
    return (muted and "|cff606060" or "|cff808080") .. value .. "|r";
  end
end

function LogTracker:GetRegion(realmName)
  local addonLoaded = LoadAddOn("LogTracker_BaseData");
  if not addonLoaded or not LogTracker_BaseData or not LogTracker_BaseData.regionByServerName then
    return nil;
  end
  return LogTracker_BaseData.regionByServerName[realmName];
end

function LogTracker:GetClassId(class)
  if class == "DEATHKNIGHT" then
    return 1;
  elseif class == "DRUID" then
    return 2;
  elseif class == "HUNTER" then
    return 3;
  elseif class == "MAGE" then
    return 4;
  elseif class == "PALADIN" then
    return 6;
  elseif class == "PRIEST" then
    return 7;
  elseif class == "ROGUE" then
    return 8;
  elseif class == "SHAMAN" then
    return 9;
  elseif class == "WARLOCK" then
    return 10;
  elseif class == "WARRIOR" then
    return 11;
  end
  return nil;
end

function LogTracker:GetPlayerLink(playerName)
  return self:GetColoredText("player", "|Hplayer:" .. playerName .. "|h[" .. playerName .. "]|h");
end

function LogTracker:GetPlayerData(playerFull, realmNameExplicit, classId, level, rescanMissing)
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
    -- Group data by zone
    local characterZones = {};
    if playerDataRaw.logs then
      for zoneIdSize, zonePerformance in pairs(playerDataRaw.logs) do
        characterZones[zoneIdSize] = characterZones[zoneIdSize] or { count = 0, hardmodes = 0 };
        characterZones[zoneIdSize].logs = {
          encountersOverall = tonumber(zonePerformance[1]), encountersLogged = tonumber(zonePerformance[2]),
          allstars = {}, ratings = {}
        };
        local allstarsRaw = self:UnstringifyData(zonePerformance[3]);
        for _, zoneAllstarsEntry in ipairs(allstarsRaw) do
          tinsert(characterZones[zoneIdSize].logs.allstars, {
            ['spec'] = tonumber(zoneAllstarsEntry[1]),
            ['percentRank'] = zoneAllstarsEntry[2]
          });
        end
        if zonePerformance[4] ~= "" then
          local zoneEncountersRaw = self:UnstringifyData(zonePerformance[4]);
          characterZones[zoneIdSize].count = max(characterZones[zoneIdSize].count, #zoneEncountersRaw);
          for zoneEncounterIndex, zoneEncountersEntry in ipairs(zoneEncountersRaw) do
            tinsert(characterZones[zoneIdSize].logs.ratings, {
              spec = tonumber(zoneEncountersEntry[1] or 0),
              percentRank = tonumber(zoneEncountersEntry[2] or 0),
              percentMedian = tonumber(zoneEncountersEntry[3] or 0)
            });
          end
        end
      end
    end
    if playerDataRaw.encounters then
      for zoneIdSize, zonePerformance in pairs(playerDataRaw.encounters) do
        characterZones[zoneIdSize] = characterZones[zoneIdSize] or { count = 0, hardmodes = 0 };
        characterZones[zoneIdSize].encounters = {};
        local zoneEncountersRaw = { strsplit("/", zonePerformance) };
        characterZones[zoneIdSize].count = max(characterZones[zoneIdSize].count, #zoneEncountersRaw);
        for zoneEncounterIndex, zoneEncounterRaw in ipairs(zoneEncountersRaw) do
          if zoneEncounterRaw == "" then
            tinsert(characterZones[zoneIdSize].encounters, {
              kills = 0,
              hardmode = "not down",
              hardmodeDiff = 0
            });
          else
            local zoneEncounterKills, zoneEncounterHmDiff, zoneEncounterHmLabel = strsplit(",", zoneEncounterRaw);
            zoneEncounterKills = tonumber(zoneEncounterKills);
            if zoneEncounterKills > 0 then
              zoneEncounterHmDiff = tonumber(zoneEncounterHmDiff);
              if zoneEncounterHmDiff > 1 then
                characterZones[zoneIdSize].hardmodes = characterZones[zoneIdSize].hardmodes + 1;
              end
            else
              zoneEncounterHmDiff = 0;
            end
            tinsert(characterZones[zoneIdSize].encounters, {
              kills = zoneEncounterKills,
              hardmode = self:GetColoredText("hardmode" .. zoneEncounterHmDiff, zoneEncounterHmLabel),
              hardmodeDiff = zoneEncounterHmDiff
            });
          end
        end
      end
    end
    -- Generate optimized data
    local characterPerformance = {};
    local characterLogs = 0;
    local characterKills = 0;
    for zoneIdSize, zoneData in pairs(characterZones) do
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
      if zoneData.logs then
        zoneAllstars = zoneData.logs.allstars;
      end
      -- Encounters
      local zoneEncounters = {};
      local zoneEncountersKilled = 0;
      for zoneEncounterIndex = 1, zoneData.count do
        local encounterData = LogTracker_BaseData.zoneEncounters[zoneId][zoneEncounterIndex];
        local zoneEncounterData = {
          spec = 0, percentRank = 0, percentMedian = 0,
          kills = 0, hardmode = "", hardmodeDiff = 0,
          encounter = LogTracker_BaseData.zoneEncounters[zoneId][zoneEncounterIndex]
        };
        if zoneData.logs and zoneData.logs.ratings[zoneEncounterIndex] then
          local zoneEncounterRating = zoneData.logs.ratings[zoneEncounterIndex];
          zoneEncounterData.spec = zoneEncounterRating.spec;
          zoneEncounterData.percentRank = zoneEncounterRating.percentRank;
          zoneEncounterData.percentMedian = zoneEncounterRating.percentMedian;
          characterLogs = characterLogs + 1;
        end
        if zoneData.encounters and zoneData.encounters[zoneEncounterIndex] then
          local zoneEncounterProgress = zoneData.encounters[zoneEncounterIndex];
          zoneEncounterData.kills = zoneEncounterProgress.kills;
          zoneEncounterData.hardmode = zoneEncounterProgress.hardmode;
          zoneEncounterData.hardmodeDiff = zoneEncounterProgress.hardmodeDiff;
        end
        if zoneEncounterData.percentRank > 0 or zoneEncounterData.kills > 0 then
          zoneEncountersKilled = zoneEncountersKilled + 1;
        end
        tinsert(zoneEncounters, zoneEncounterData);
      end
      -- Zone details
      characterPerformance[zoneIdSize] = {
        ['zoneName'] = zoneName,
        ['zoneEncounters'] = zoneData.count,
        ['hardmodes'] = zoneData.hardmodes,
        ['encountersKilled'] = zoneEncountersKilled,
        ['allstars'] = zoneAllstars,
        ['encounters'] = zoneEncounters
      }
      characterKills = characterKills + zoneEncountersKilled;
    end
    -- Character details
    characterData = {
      ['level'] = playerDataRaw.level,
      ['faction'] = playerDataRaw.faction,
      ['class'] = tonumber(playerDataRaw.class),
      ['last_update'] = playerDataRaw.lastUpdateLogs or playerDataRaw.lastUpdate,
      ['logs'] = characterPerformance,
    };
    local characterLogsAge = GetTime() - (playerDataRaw.lastUpdateLogs or 0);
    if characterLogsAge > playerLogsInterval then
      -- Data older than desired, request update
      self:SyncRequestLogs(playerName);
    elseif (characterKills > 0 and characterLogs == 0) then
      -- No logs present despite kills tracked, request update and queue update (if desired)
      self:SyncRequestLogs(playerName);
      if rescanMissing then
        self:SyncRequeue(playerName, plalyerDataRaw);
      end
    end
  else
    -- No character data available
    self:SyncRequest(playerName);
    if classId then
      self.db.playerData[realmName][playerName] = {
        class = classId,
        level = level or 0,
        faction = "Unknown",
        encounters = {},
        lastUpdate = 0
      };
    end
  end
  return characterData, playerName, realmName, playerDataRaw;
end

function LogTracker:SyncRequeue(playerName, playerData)
  if playerData and (playerData.lastUpdateLogs or 0) > 0 and playerData.updateFails < 2 then
    playerData.lastUpdateLogs = 0;
    playerData.priority = 5;
    self:LogDebug("Queued rescan for player ", playerName)
  end
end

function LogTracker:GetPlayerOverallPerformance(playerData, logTargets)
  -- Actual logs
  if playerData["logs"] then
    local logScoreValue = 0;
    local logScoreCount = 0;
    for zoneId, zoneData in pairs(playerData["logs"]) do
      for _, encounterData in ipairs(zoneData['encounters']) do
        local targetEncounters = nil;      
        if logTargets and logTargets[zoneId] then
          targetEncounters = logTargets[zoneId];
        end
        if not logTargets or (targetEncounters and tContains(targetEncounters, encounterData['encounter']['id'])) then
          -- logTargets is either nil (include every encounter) or it contains the given encounter
          if encounterData['percentRank'] > 0 then
            logScoreValue = logScoreValue + encounterData['percentRank'];
            logScoreCount = logScoreCount + 1;
          end
        end
      end
    end
    if (logScoreCount > 0) then
      return self:GetColoredPercent(logScoreValue / logScoreCount);
    else
      -- Fallback for overall average
      for zoneId, zoneData in pairs(playerData["logs"]) do
        for _, encounterData in ipairs(zoneData['encounters']) do
          if encounterData['percentRank'] > 0 then
            logScoreValue = logScoreValue + encounterData['percentRank'];
            logScoreCount = logScoreCount + 1;
          end
        end
      end
      if (logScoreCount > 0) then
        return self:GetColoredPercent(logScoreValue / logScoreCount, true);
      else
        return self:GetColoredText("muted", "--");
      end
    end
  end
  -- Archivement progression
  local progression = "";
  for zoneIdSize, zoneData in pairs(playerData['performance']) do
    local zoneId, zoneSize = strsplit("-", zoneIdSize);
    if progression ~= "" then
      progression = progression .. self:GetColoredText("muted", " / ");
    end
    local hardmodes = (zoneData['hardmodes'] or 0);
    if hardmodes > 0 then
      progression = progression .. zoneSize .. " " .. self:GetColoredText("hardmode4", hardmodes .. "HM");
    end
  end
  if (progression ~= "") then
    return progression;
  else
    return self:GetColoredText("muted", "--");
  end
end

function LogTracker:GetPlayerZonePerformance(zone, playerClass)
  local zoneName = zone.zoneName;
  local zoneProgress = self:GetColoredProgress(tonumber(zone.encountersKilled), tonumber(zone.zoneEncounters));
  local zoneHardmodesStr = "";
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
    zoneHardmodesStr = zoneHardmodesStr .. self:GetColoredText("hardmode4", zone.hardmodes .. "HM");
  end
  return self:GetColoredText("zone", zoneName), self:GetColoredText("progress", zoneProgress), zoneHardmodesStr, zoneRatingsStr;
end

function LogTracker:GetPlayerEncounterPerformance(encounter, playerClass, reversed)
  local encounterName = encounter.encounter.name;
  if not encounter.spec and encounter.kills then
    if (encounter.kills > 0) then
      return self:GetColoredText("encounter", encounterName), encounter.hardmode .. " " .. self:GetColoredText("kills", encounter.kills .. "x");
    else
      return self:GetColoredText("encounter", encounterName), self:GetColoredText("muted", "not down");
    end
  end
  if (encounter.spec == 0) then
    return self:GetColoredText("encounter", encounterName), "---";
  end
  local encounterRating = self:GetSpecIcon(playerClass, encounter.spec) .. " " .. self:GetColoredPercent(encounter.percentRank);
  if (reversed) then
    encounterRating = self:GetColoredPercent(encounter.percentRank) .. " " .. self:GetSpecIcon(playerClass, encounter.spec);
  end
  return self:GetColoredText("encounter", encounterName) .. " " .. encounter.hardmode, encounterRating;
end

function LogTracker:GetPlayerLogsZonePerformance(zone, playerClass)
  local zoneName = zone.zoneName;
  local zoneProgress = self:GetColoredProgress(tonumber(zone.encountersKilled), tonumber(zone.zoneEncounters));
  local zoneHardmodesStr = "";
  local zoneRatingsStr = "";
  local zoneRatings = {};
  for _, allstarsRating in ipairs(zone.allstars) do
    if allstarsRating.percentRank then
      tinsert(zoneRatings, self:GetSpecIcon(playerClass, allstarsRating.spec).." "..self:GetColoredPercent(allstarsRating.percentRank));
    end
  end
  if #(zoneRatings) > 0 then
    zoneRatingsStr = strjoin(" ", unpack(zoneRatings));
  end
  if zone.hardmodes and zone.hardmodes > 0 then
    zoneHardmodesStr = zoneHardmodesStr .. self:GetColoredText("hardmode4", zone.hardmodes .. "HM");
  end
  return self:GetColoredText("zone", zoneName), self:GetColoredText("progress", zoneProgress), zoneHardmodesStr, zoneRatingsStr;
end

function LogTracker:GetPlayerLogsEncounterPerformance(encounter, playerClass, reversed)
  local encounterName = encounter.encounter.name;
  if (encounter.spec == 0) then
    if (encounter.kills > 0) then
      return self:GetColoredText("encounter", encounterName), encounter.hardmode .. " " .. self:GetColoredText("kills", encounter.kills .. "x");
    else
      return self:GetColoredText("encounter", encounterName), self:GetColoredText("muted", "not down");
    end
  end
  local encounterRating = self:GetSpecIcon(playerClass, encounter.spec).." "..self:GetColoredPercent(encounter.percentRank);
  if (reversed) then
    encounterRating = self:GetColoredPercent(encounter.percentRank).." "..self:GetSpecIcon(playerClass, encounter.spec);
  end
  if (encounter.hardmodeDiff > 0) then
    encounterRating = encounter.hardmode .. " " .. encounterRating;
  end
  return self:GetColoredText("encounter", encounterName), encounterRating;
end

function LogTracker:GetSyncPeer(name, noUpdate, noCreate, version)
  local realmName = GetRealmName();
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
    syncOffset = self.syncStatus.offsetStart,
    isOnline = false,
    isGuild = false,
    isParty = false,
    isRaid = false,
    isWhisper = false,
    receivedOverall = 0,
    receivedUpdates = 0,
    sentOverall = 0,
    version = version or syncVersion
  };
  -- Add/update peer history
  if not self.db.syncPeers[realmName] then
    self.db.syncPeers[realmName] = {};
  end
  if not self.db.syncPeers[realmName][name] then
    self.db.syncPeers[realmName][name] = { lastUpdate = time() };
  end
  -- Update timestamps
  if not noUpdate then
    self.syncStatus.peers[name].isOnline = true;
    self.syncStatus.peers[name].chatReported = false;
    self.syncStatus.peers[name].lastSeen = GetTime();
    self.db.syncPeers[realmName][name].lastUpdate = time();
  end
  if not self.syncStatus.peers[name].lastUpdate then
    self.syncStatus.peers[name].lastUpdate = GetTime();
  end
  return self.syncStatus.peers[name];
end

function LogTracker:GetGroupFinderLogTargets(searchResultInfo)
  local logTargets = nil;
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
  return logTargets;
end

function LogTracker:GetWclClassId(classIdGame)
  local classId = 0;
  if classIdGame == 1 then
    classId = 11; -- Warrior
  elseif classIdGame == 2 then
    classId = 6; -- Paladin
  elseif classIdGame == 3 then
    classId = 3; -- Hunter
  elseif classIdGame == 4 then
    classId = 8; -- Rogue
  elseif classIdGame == 5 then
    classId = 7; -- Priest
  elseif classIdGame == 6 then
    classId = 1; -- DeathKnight
  elseif classIdGame == 7 then
    classId = 9; -- Shaman
  elseif classIdGame == 8 then
    classId = 4; -- Mage
  elseif classIdGame == 9 then
    classId = 10; -- Warlock
  elseif classIdGame == 11 then
    classId = 2; -- Druid
  end
  return classId;
end

function LogTracker:CompareAchievements(unitId, priority)
  if not UnitIsPlayer(unitId) then
    return;
  end
  if self.achievementTime ~= nil then
    local timeGone = GetTime() - self.achievementTime;
    if (timeGone < 10) then
      return;
    end
  end
  local realmName = GetRealmName();
  local ownGuild = GetGuildInfo("player");
  local playerName = UnitName(unitId);
  local playerGuild = GetGuildInfo(unitId);
  if UnitInRaid(unitId) then
    priority = max(priority or 10, 10);
  end
  if ownGuild and playerGuild and (playerGuild == ownGuild) then
    priority = max(priority or 20, 20);
  end
  local _, _, classIdGame = UnitClass(unitId);
  local classId = self:GetWclClassId(classIdGame);
  self.db.playerData[realmName] = self.db.playerData[realmName] or {};
  local playerDetails = self.db.playerData[realmName][playerName];
  local playerAge = playerUpdateInterval + 1;
  if playerDetails then
    playerAge = time() - playerDetails.lastUpdate;
  else
    playerDetails = { encounters = {}, lastUpdate = time() - playerUpdateInterval };
    self.db.playerData[realmName][playerName] = playerDetails;
  end
  playerDetails.class = classId;
  playerDetails.level = UnitLevel(unitId);
  playerDetails.faction = UnitFactionGroup(unitId);
  if priority then
    playerDetails.priority = priority;
  end
  if CheckInteractDistance(unitId, 1) and (playerAge > playerUpdateInterval) then
    self.achievementTime = GetTime();
    self.achievementUnit = unitId;
    self.achievementGuid = UnitGUID(unitId);
    self.achievementDetails.name = playerName;
    ClearAchievementComparisonUnit();
    SetAchievementComparisonUnit(unitId);
  end
  self:OnPlayerOnline(playerName);
end

function LogTracker:CleanupPlayerData()
  local playerData = self.db.playerData;
  local kept = 0;
  local removed = 0;
  self.db.playerData = {};
  for realmName, playerList in pairs(playerData) do
    local realmPlayers = {};
    local realmCount = 0;
    for name, playerDetails in pairs(playerList) do
      local playerAge = time() - playerDetails.lastUpdate;
      if playerAge < playerAgeLimit then
        if type(playerDetails.class) == "string" then
          playerDetails.class = tonumber(playerDetails.class);
        end
        if type(playerDetails.level) == "string" then
          playerDetails.level = tonumber(playerDetails.level);
        end
        realmPlayers[name] = playerDetails;
        kept = kept + 1;
        realmCount = realmCount + 1;
      else
        removed = removed + 1;
      end
    end
    if realmCount > 0 then
      self.db.playerData[realmName] = realmPlayers;
    end
  end
  self:LogDebug("Player data cleanup done!", "Removed " .. removed .. " / " .. (kept + removed) .. " players.");
  return removed, kept;
end

function LogTracker:CleanupPeerData()
  local peerData = self.db.syncPeers;
  local kept = 0;
  local removed = 0;
  self.db.syncPeers = {};
  for realmName, peerList in pairs(peerData) do
    self.db.syncPeers[realmName] = {};
    for name, peerDetails in pairs(peerList) do
      local peerAge = time() - peerDetails.lastUpdate;
      if peerAge < peerAgeLimit then
        self.db.syncPeers[realmName][name] = peerDetails;
        kept = kept + 1;
      else
        removed = removed + 1;
      end
    end
  end
  self:LogDebug("Peer data cleanup done!", "Removed " .. removed .. " / " .. (kept + removed) .. " peers.");
  return removed, kept;
end

function LogTracker:ImportAppData()
  if not LogTracker_AppData then
    return;
  end
  local importCount = 0;
  local realmNamePlayer = GetRealmName();
  for realmName, playerList in pairs(LogTracker_AppData) do
    if not self.db.playerData[realmName] then
      self.db.playerData[realmName] = {};
    end
    for playerName, playerDetails in pairs(playerList) do
      local playerDetailsFinal = nil;
      local playerDetailsLocal = self.db.playerData[realmName][playerName];
      if not playerDetailsLocal or (playerDetailsLocal.lastUpdate <= playerDetailsLocal.lastUpdate) then
        playerDetailsFinal = { 
          level = playerDetails[1], faction = playerDetails[2], class = playerDetails[3],
          lastUpdate = playerDetails[4], lastUpdateLogs = playerDetails[4], updateFails = 0,
          encounters = {},
          logs = {}
        };
        if playerDetailsLocal then
          playerDetailsFinal.updateFails = playerDetailsLocal.updateFails or 0;
          playerDetailsFinal.encounters = playerDetailsLocal.encounters or {};
          playerDetailsFinal.logs = playerDetailsLocal.logs or {};
        end
      else
        playerDetailsFinal = playerDetailsLocal;
        playerDetailsFinal.lastUpdateLogs = playerDetails[4];
      end
      if not playerDetailsFinal.encounters then
        playerDetailsFinal.encounters = {};
      end
      if playerDetailsFinal.priority and playerDetailsFinal.priority < 10 then
        -- Priorities below 10 are only used for a single update
        playerDetailsFinal.priority = nil;
      end
      local zoneCount = 0;
      local zoneData = playerDetailsFinal.logs or {};
      for zoneIdSize, zoneRankings in pairs(playerDetails[5]) do
        if zoneRankings[4] and type(zoneRankings[3]) == "table" then
          -- At least one boss down?
          if zoneRankings[2] > 0 then
            zoneRankings[3] = self:StringifyData(zoneRankings[3]); -- Stringify allstar data to save space
            zoneData[zoneIdSize] = zoneRankings;
            zoneCount = zoneCount + 1;
          end
        end
      end
      if zoneCount > 0 then
        playerDetailsFinal.logs = zoneData;
        playerDetailsFinal.updateFails = 0;
      else
        playerDetailsFinal.updateFails = playerDetailsFinal.updateFails + 1;
      end
      if playerDetailsFinal.class > 0 then
        self.db.playerData[realmName][playerName] = playerDetailsFinal;
        if realmName == realmNamePlayer then
          self:SyncPlayerAdd(playerName);
        end
        importCount = importCount + 1;
      end
    end
  end  
  self.db.appImportCount = self.db.appImportCount + importCount;
  self:LogDebug("AppData", "Imported ", importCount, " players from app data.");
end

function LogTracker:UpdateAppQueue()
  local now = time();
  if (self.appSyncStatusTime > now) or InCombatLockdown() then
    -- Throttle updates / do not update while in combat
    return;
  end
  local update_interval_turbo = 86400;    -- 1 day
  local update_interval_fast = 86400 * 2; -- 2 days
  local update_interval_slow = 86400 * 7; -- 1 week
  local prio_new, prio_update, regular_new, regular_update = 0, 0, 0, 0;
  for realmName, playerList in pairs(self.db.playerData) do
    for playerName, playerDetails in pairs(playerList) do
      if (playerDetails.level == 0 or playerDetails.level == 80) and (playerDetails.class > 0) then
        local priority = playerDetails.priority or 0;
        local last_seen = now - playerDetails.lastUpdate;
        local last_updated = now;
        if playerDetails.lastUpdateLogs then
          last_updated = now - playerDetails.lastUpdateLogs;
        end
        if last_updated == now then -- New entry
          if priority > 0 then
            prio_new = prio_new + 1;
          else
            regular_new = regular_new + 1;
          end
        elseif (last_updated > update_interval_turbo) and (priority > 0) then -- Prioritised update
          prio_update = prio_update + 1;
        elseif (last_updated > update_interval_fast) and (last_seen < update_interval_fast) then -- Regular update (fast)
          regular_update = regular_update + 1;
        elseif (last_updated > update_interval_slow) then -- Regular update (slow)
          regular_update = regular_update + 1;
        end
      end
    end
  end
  if self.appSyncStatus then
    self.appSyncStatus:SetText(
      "LogTracker App updates queued:\n"..
      "Priority: |cffffffff"..prio_new.."|r new + |cffffffff"..prio_update.."|r Regular: |cffffffff"..regular_new.."|r new + |cffffffff"..regular_update.."|r"
    );
  end
  self.appSyncStatusTime = now + appQueueUpdateInterval;
  return prio_new, prio_update, regular_new, regular_update;
end

function LogTracker:SyncCheck()
  if not self.db.syncSend and not self.db.syncReceive then
    return;
  end
  local now = GetTime();
  if self.syncStatus.throttleTimer > now then
    return;
  end
  --self:LogDebug("SyncCheck");
  self.syncStatus.throttleTimer = now + syncThrottle;
  -- Bandwidth
  local chatBandwidth = ChatThrottleLib:UpdateAvail();
  if chatBandwidth < 1000 then
    --self:LogDebug("SyncPeers", "Chat bandwidth limited, skipping sync for now.", chatBandwidth);
    return;
  end
  if (self.syncStatus.requestsTimer < now) then
    if self:SyncSendRequest() then
      return;
    end
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
    self:LogDebug("SyncPeers", "Updated persistent sync history.");
    return;
  end
  if self.syncStatus.timer < now and self.db.syncSend then
    -- Check for pending sync data (Every 5 seconds if due and chat bandwidth available)
    self.syncStatus.timer = now + syncInterval;
    local playerCount = #(self.syncStatus.players);
    if playerCount > 0 then
      -- Check guild
      local guildPeers, guildOffset, guildVersion = self:SyncUpdateGuild();
      if guildPeers > 0 and guildOffset < playerCount then
        local offset, sent = self:SyncSend("GUILD", nil, guildOffset, syncBatchPlayers, guildVersion);
        self.syncStatus.guild = offset;
        self:LogDebug("Sync v" .. guildVersion, guildPeers, "Guild", offset, "/", playerCount, " (" .. sent .. ")");
        return;
      end
      -- Check party
      local partyPeers, partyOffset, partyVersion = self:SyncUpdateParty();
      if partyPeers > 0 and partyOffset < playerCount then
        local offset, sent = self:SyncSend("PARTY", nil, partyOffset, syncBatchPlayers, partyVersion);
        self.syncStatus.party = offset;
        self:LogDebug("Sync v" .. partyVersion, partyPeers, "Party", offset, "/", playerCount, " (" .. sent .. ")");
        return;
      end
      -- Check raid
      local raidPeers, raidOffset, raidVersion = self:SyncUpdateRaid();
      if raidPeers > 0 and raidOffset < playerCount then
        local offset, sent = self:SyncSend("RAID", nil, raidOffset, syncBatchPlayers, raidVersion);
        self.syncStatus.party = offset;
        self:LogDebug("Sync v" .. raidVersion, raidPeers, "Raid", offset, "/", playerCount, " (" .. sent .. ")");
        return;
      end
      -- Check whisper
      local whisperPeers, whisperOffset = self:SyncUpdateWhisper();
      if whisperPeers > 0 and whisperOffset < playerCount then
        for name, peer in pairs(self.syncStatus.peers) do
          if peer.isWhisper and peer.isOnline and peer.syncOffset == whisperOffset and peer.syncOffset < playerCount and peer.version >= 2 then
            peer.lastSeen = GetTime();
            local offset, sent = self:SyncSend("WHISPER", name, peer.syncOffset, syncBatchPlayers, peer.version);
            peer.syncOffset = offset;
            self:LogDebug("Sync v" .. peer.version, name, "Whisper", offset, "/", playerCount, " (" .. sent .. ")");
            return;
          end
        end
      end
    end
  end
  if self:SyncPeersOnlineCheck() then
    return;
  end
  self:SyncReportPeers();
end

function LogTracker:SyncUpdateFull()
  local guild = self:SyncUpdateGuild(true);
  local party = self:SyncUpdateParty(true);
  local raid = self:SyncUpdateRaid(true);
  local whisper = self:SyncUpdateWhisper(true);
  return guild, party, raid, whisper;
end

function LogTracker:SyncVersionByType(type)
  if type == "GUILD" then
    return self.syncStatus.guildVersion;
  elseif type == "PARTY" then
    return self.syncStatus.partyVersion;
  elseif type == "RAID" then
    return self.syncStatus.raidVersion;
  else
    return syncVersion;
  end
end

function LogTracker:SyncUpdateGuild(no_yell)
  if not IsInGuild() then
    return 0, 0, 0;
  end
  if not no_yell then
    -- Send greeting if not throttled
    self:SyncSendHello("GUILD");
  end
  -- Clear existing guild flags
  for name, peer in pairs(self.syncStatus.peers) do
    peer.isGuild = false;
  end
  -- Set guild flags for currently online members
  local peers = 0;
  local numTotalMembers, numOnlineMaxLevelMembers, numOnlineMembers = GetNumGuildMembers();
  self.syncStatus.guild = #(self.syncStatus.players);
  self.syncStatus.guildVersion = syncVersion;
  for i = 1, numTotalMembers do
    local nameFull, _, _, level, class, _, _, _, online = GetGuildRosterInfo(i);
    if nameFull then
      local name, realm = strsplit("-", nameFull);
      if online then
        self:OnPlayerOnline(name);
      end
      local peer = self:GetSyncPeer(name, true, true);
      if peer then
        peer.isOnline = online;
        if peer.isOnline then
          peer.isGuild = true;
          peer.lastSeen = GetTime();
          self.syncStatus.guild = max(0, min(self.syncStatus.guild, peer.syncOffset));
          peers = peers + 1;
          self.syncStatus.guildVersion = min(self.syncStatus.guildVersion, peer.version or 1);
        end
      end
    end
  end
  if peers == 0 then
    self.syncStatus.guild = 0;
  end
  return peers, self.syncStatus.guild, self.syncStatus.guildVersion;
end

function LogTracker:SyncUpdateParty(no_yell)
  if not IsInGroup() or IsInRaid() then
    return 0, 0, 0;
  end
  if not no_yell then
    -- Send greeting if not throttled
    self:SyncSendHello("PARTY");
  end
  -- Clear existing party flags
  for name, peer in pairs(self.syncStatus.peers) do
    peer.isParty = false;
  end
  -- Set party flags for currently online members
  local peers = 0;
  local members = GetNumGroupMembers();
  self.syncStatus.party = #(self.syncStatus.players);
  self.syncStatus.partyVersion = syncVersion;
  for i = 1, members do
    local unitId = "party" .. i;
    local name = UnitName(unitId);
    if name then
      self:OnPlayerOnline(name);
      local peer = self:GetSyncPeer(name, true, true);
      if peer then
        peer.isOnline = UnitIsConnected(unitId);
        if peer.isOnline then
          peer.isParty = true;
          peer.lastSeen = GetTime();
          self.syncStatus.party = max(0, min(self.syncStatus.party, peer.syncOffset));
          peers = peers + 1;
          self.syncStatus.partyVersion = min(self.syncStatus.partyVersion, peer.version or 1);
        end
      end
      self:CompareAchievements(unitId);
    end
  end
  if peers == 0 then
    self.syncStatus.party = 0;
  end
  return peers, self.syncStatus.party, self.syncStatus.partyVersion;
end

function LogTracker:SyncUpdateRaid(no_yell)
  if not IsInRaid() then
    return 0, 0, 0;
  end
  if not no_yell then
    -- Send greeting if not throttled
    self:SyncSendHello("RAID");
  end
  -- Clear existing raid flags
  for name, peer in pairs(self.syncStatus.peers) do
    peer.isRaid = false;
  end
  -- Set raid flags for currently online members
  local peers = 0;
  local members = GetNumGroupMembers();
  self.syncStatus.raid = #(self.syncStatus.players);
  self.syncStatus.raidVersion = #(self.syncStatus.players);
  for i = 1, members do
    local unitId = "raid" .. i;
    local name = UnitName(unitId);
    if name then
      self:OnPlayerOnline(name);
      local peer = self:GetSyncPeer(name, true, true);
      if peer then
        peer.isOnline = UnitIsConnected(unitId);
        if peer.isOnline then
          peer.isRaid = true;
          peer.lastSeen = GetTime();
          self.syncStatus.raid = max(0, min(self.syncStatus.raid, peer.syncOffset));
          peers = peers + 1;
          self.syncStatus.raidVersion = min(self.syncStatus.raidVersion, peer.version or 1);
        end
      end
      self:CompareAchievements(unitId);
    end
  end
  if peers == 0 then
    self.syncStatus.raid = 0;
  end
  return peers, self.syncStatus.raid, self.syncStatus.raidVersion;
end

function LogTracker:SyncUpdateWhisper(no_yell)
  local peers = 0;
  self.syncStatus.whisper = #(self.syncStatus.players);
  -- Check peers from friends list
  local friends = C_FriendList.GetNumFriends();
  for i = 1, friends do
    local friendInfo = C_FriendList.GetFriendInfoByIndex(i);
    if friendInfo.connected then
      local peer = self:GetSyncPeer(friendInfo.name, false, true);
      if not no_yell then
        -- Send greeting if not throttled
        self:SyncSendHello("WHISPER", friendInfo.name);
      end
    end
  end
  for name, peer in pairs(self.syncStatus.peers) do
    -- Update online status
    if peer.isOnline then
      local peerAge = GetTime() - peer.lastSeen;
      if peerAge > syncPeerTimeout then
        peer.isOnline = false;
      end
    end
    -- Check if peer should sync via whisper
    if peer.isOnline and not peer.isGuild and not peer.isParty and not peer.isRaid then
      peer.isWhisper = true;
      self.syncStatus.whisper = max(0, min(self.syncStatus.whisper, peer.syncOffset));
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

function LogTracker:SyncPlayerAdd(playerName)
  if not tContains(self.syncStatus.players, playerName) then
    tinsert(self.syncStatus.players, playerName);
  end
  if #(self.syncStatus.players) > syncHistoryLimit then
    self.syncStatus.offsetStart = max(0, syncHistoryLimit - #(self.syncStatus.players));
  end
end

function LogTracker:SyncRequest(name)
  self:SyncRequestBase(name);
end

function LogTracker:SyncRequestCheck(name)
  local playerName, realmName = strsplit("-", name);
  if not realmName then
    realmName = GetRealmName();
  end
  self.db.playerData[realmName] = self.db.playerData[realmName] or {};
  local playerDataRaw = self.db.playerData[realmName][playerName];
  if playerDataRaw then
    local playerLevel = tonumber(playerDataRaw.level);
    if (playerLevel > 0) and (playerLevel < 80) then
      return false;
    end
  end
  return true;
end

function LogTracker:SyncRequestBase(name)
  if not self.db.syncReceive then
    return;
  end
  if not self:SyncRequestCheck(name) then
    return; -- Do not request players below level 80
  end
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
  -- Remove from log request list
  self:SyncRequestRemoveLogs(name);
end

function LogTracker:SyncRequestLogs(name)
  if not self.db.syncReceive then
    return;
  end
  if not self:SyncRequestCheck(name) then
    return; -- Do not request players below level 80
  end
  -- Check if user is already in the request list
  local requestIndex = nil;
  for i, requestName in ipairs(self.syncStatus.requestsLogs) do
    if requestName == name then
      requestIndex = i;
      break;
    end
  end
  -- Remove existing entry if present (will be prepended)
  if requestIndex ~= nil then
    tremove(self.syncStatus.requestsLogs, requestIndex);
  end
  -- Shorten list to respect limit
  while #(self.syncStatus.requestsLogs) >= syncRequestLimit do
    tremove(self.syncStatus.requestsLogs, syncRequestLimit);
  end
  -- Prepend requested player
  tinsert(self.syncStatus.requestsLogs, 1, name);
end

function LogTracker:SyncRequestRemove(name)
  self:SyncRequestRemoveLogs(name);
  self:SyncRequestRemoveBase(name);
end

function LogTracker:SyncRequestRemoveBase(name)
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

function LogTracker:SyncRequestRemoveLogs(name)
  -- Check if user is already in the request list
  local requestIndex = nil;
  for i, requestName in ipairs(self.syncStatus.requestsLogs) do
    if requestName == name then
      requestIndex = i;
      break;
    end
  end
  -- Remove existing entry if present (will be prepended)
  if requestIndex ~= nil then
    tremove(self.syncStatus.requestsLogs, requestIndex);
    return true;
  end
  return false;
end

function LogTracker:SyncSend(type, target, offset, limit, version)
  local playerCount = #(self.syncStatus.players);
  if playerCount == 0 then
    return;
  end
  -- Version
  if not version then
    version = self:SyncVersionByType(type);
  end
  -- Apply defaults
  offset = (offset or 0) + 1;
  limit = limit or 20;
  local last = min(playerCount, limit + offset - 1);
  local amount = 0;
  local realmName = GetRealmName();
  if version == 1 then
    -- Sync Version 1
    -- Send messages
    self.db.playerData[realmName] = self.db.playerData[realmName] or {};
    for i = offset, last do
      local playerName = self.syncStatus.players[i];
      if self:QueuePlayerData(playerName) then
        amount = amount + 1;
      end
    end
    -- Flush messages
    self:FlushAddonMessages(type, target);
  else
    -- Sync Version 2 and beyond
    local messageData = {
      version = syncVersion, players = {}
    };
    for i = offset, last do
      local playerName = self.syncStatus.players[i];
      if self:InsertPlayerData(messageData.players, playerName) then
        amount = amount + 1;
      end
    end
    self:SendCommMessage("pl", messageData, type, target);
  end
  -- Update peers
  self:SyncUpdatePeers(type, target, amount, last);
  -- Return new offset
  return last, amount;
end

function LogTracker:SyncSendByNames(names, type, target, requireLogs, version)
  -- Version
  if not version then
    version = self:SyncVersionByType(type);
  end
  local amount = 0;
  if version == 1 then
    -- Sync Version 1
    for _, name in ipairs(names) do
      if requireLogs then
        if self.syncStatus.requestsLockLogs[name] and self:QueuePlayerData(name, true) then
          self.syncStatus.requestsLockLogs[name] = true;
          amount = amount + 1;
        end
      else
        if not self.syncStatus.requestsLock[name] and self:QueuePlayerData(name, false) then
          self.syncStatus.requestsLock[name] = true;
          amount = amount + 1;
        end
      end
    end
    if amount > 0 then
      if type ~= "WHISPER" then
        target = nil;
      end
      self:FlushAddonMessages(type, target);
    end
  else
    -- Sync Version 2 and beyond
    local messageData = {
      version = syncVersion, players = {}
    };
    for _, name in ipairs(names) do
      if requireLogs then
        if self.syncStatus.requestsLockLogs[name] and self:InsertPlayerData(messageData.players, name, true) then
          self.syncStatus.requestsLockLogs[name] = true;
          amount = amount + 1;
        end
      else
        if not self.syncStatus.requestsLock[name] and self:InsertPlayerData(messageData.players, name, false) then
          self.syncStatus.requestsLock[name] = true;
          amount = amount + 1;
        end
      end
    end
    if amount > 0 then
      if type ~= "WHISPER" then
        target = nil;
      end
      self:SendCommMessage("pl", messageData, type, target);
    end
  end
  return amount;
end

function LogTracker:SyncSendRequestByNames(names_base, names_logs, type, target, version)
  -- Version
  if not version then
    version = self:SyncVersionByType(type);
  end
  if version < 3 then
    -- Sync Version 1
    if (#names_base > 0) then
      self:SyncSendRequestV1ByNames(names_base, false, type, target, version);
    end
    if (#names_logs > 0) then
      self:SyncSendRequestV1ByNames(names_logs, true, type, target, version);
    end
  else
    -- Sync Version 3 and beyond
    local messageData = {
      version = syncVersion, names_base = names_base, names_logs = names_logs
    };
    if type ~= "WHISPER" then
      target = nil;
    end
    self:SendCommMessage("rqC", messageData, type, target);
  end
end

function LogTracker:SyncSendRequestV1ByNames(names, requireLogs, type, target, version)
  -- Version
  if not version then
    version = self:SyncVersionByType(type);
  end
  if version == 1 then
    -- Sync Version 1
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
    if type ~= "WHISPER" then
      target = nil;
    end
    if requireLogs then
      self:SendAddonMessage("rqL", namesList, type, target);
    else
      self:SendAddonMessage("rq", namesList, type, target);
    end
  else
    -- Sync Version 2 and beyond
    local messageData = {
      version = syncVersion, names = names
    };
    if type ~= "WHISPER" then
      target = nil;
    end
    if requireLogs then
      self:SendCommMessage("rqL", messageData, type, target);
    else
      self:SendCommMessage("rq", messageData, type, target);
    end
  end
end

function LogTracker:SyncSendRequest()
  local requestCount = min(syncRequestLimit, #self.syncStatus.requests + #self.syncStatus.requestsLogs);
  if requestCount == 0 then
    return;
  end
  local guild, party, raid, whisper = self:SyncUpdateFull();
  if (guild + party + raid + whisper) > 0 then
    self:LogDebug("Requesting Sync for ", requestCount, " players");
  end
  if guild > 0 then
    self:SyncSendRequestByNames(self.syncStatus.requests, self.syncStatus.requestsLogs, "GUILD");
  end
  if party > 0 then
    self:SyncSendRequestByNames(self.syncStatus.requests, self.syncStatus.requestsLogs, "PARTY");
  end
  if raid > 0 then
    self:SyncSendRequestByNames(self.syncStatus.requests, self.syncStatus.requestsLogs, "RAID");
  end
  if whisper > 0 then
    for name, peer in pairs(self.syncStatus.peers) do
      if peer.isWhisper then
        self:SyncSendRequestByNames(self.syncStatus.requests, self.syncStatus.requestsLogs, "WHISPER", name, peer.version);
      end
    end
  end
  wipe(self.syncStatus.requests);
  wipe(self.syncStatus.requestsLogs);
  if requestCount > 0 then
    -- Clear request timer
    local ratio = 1 - requestCount / syncRequestLimit;
    self.syncStatus.requestsTimer = GetTime() + syncRequestDelay * ratio;
    return true;
  end
end

function LogTracker:SyncSendHello(channel, target)
  local now = GetTime();
  if (channel == "GUILD") and (self.syncStatus.peersChannel.guild < now) then
    self.syncStatus.peersChannel.guild = now + syncPeerGreeting + random(1, 10);
    self:SyncSendHelloFinal(channel, target);
  elseif (channel == "PARTY") and (self.syncStatus.peersChannel.party < now) then
    self.syncStatus.peersChannel.party = now + syncPeerGreeting + random(1, 10);
    self:SyncSendHelloFinal(channel, target);
  elseif (channel == "RAID") and (self.syncStatus.peersChannel.raid < now) then
    self.syncStatus.peersChannel.raid = now + syncPeerGreeting + random(1, 10);
    self:SyncSendHelloFinal(channel, target);
  elseif (channel == "YELL") and (self.syncStatus.peersChannel.yell < now) then
    self.syncStatus.peersChannel.yell = now + syncPeerGreeting + random(1, 10);
    self:SyncSendHelloFinal(channel, target, syncVersion);
  elseif (channel == "WHISPER") then
    local lastHello = self.syncStatus.peersChannel.whisper[target];
    if not lastHello or (lastHello < now) then
      self.syncStatus.peersChannel.whisper[target] = now + syncPeerGreeting + random(1, 10);
      self:SyncSendHelloFinal(channel, target);
    end
  end
end

function LogTracker:SyncSendHelloFinal(channel, target, version)
  -- Version
  if not version then
    version = self:SyncVersionByType(channel);
  end
  if version == 1 then
    -- Sync Version 1
    self:SendAddonMessage("hi", nil, channel, target);
  else
    -- Sync Version 2 and beyond
    local messageData = { version = syncVersion, versionAddon = GetAddOnMetadata("LogTracker", "version"), peers = {} };
    for name, peer in pairs(self.syncStatus.peers) do
      if peer.isOnline and peer.version >= 2 then
        tinsert(messageData.peers, name);
      end
    end
    self:SendCommMessage("hi", messageData, channel, target);
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

function LogTracker:SyncPeersOnlineCheck()
  local realmName = GetRealmName();
  if not self.db.syncPeers[realmName] then
    self.db.syncPeers[realmName] = {};
  end
  for name, peerStatus in pairs(self.syncStatus.peers) do
    local peerAge = time() - peerStatus.lastUpdate;
    if peerAge > syncPeerOnlineCheck then
      self:GetSyncPeer(name);
      self:SyncSendHello("WHISPER", name);
      return true; -- Only check one peer at a time
    end
  end
  return false;
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
          "Sent: " .. peerStatus.sentOverall,
          "Version: " .. peerStatus.version
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
  if playerData.logs then
    -- Actual logs
    for zoneId, zone in pairs(playerData.logs) do
      self:SendSystemChatLine( self:GetPlayerLink(playerName).." "..strjoin(" ", self:GetPlayerZonePerformance(zone, playerData.class)) );
      if showEncounters then
        for _, encounter in ipairs(zone.encounters) do
          local encounterName, encounterRating = self:GetPlayerEncounterPerformance(encounter, playerData.class);
          self:SendSystemChatLine("  "..encounterName..": "..encounterRating);
        end
      end
    end
  else
    -- Progress by archivments
    for zoneId, zone in pairs(playerData.performance) do
      self:SendSystemChatLine(self:GetPlayerLink(playerName) .. " " .. strjoin(" ", self:GetPlayerZonePerformance(zone, playerData.class)));
      if showEncounters then
        for _, encounter in ipairs(zone.encounters) do
          local encounterName, encounterRating = self:GetPlayerEncounterPerformance(encounter, playerData.class);
          self:SendSystemChatLine("  " .. encounterName .. ": " .. encounterRating);
        end
      end
    end
  end
  self:SendSystemChatLine(L["DATE_UPDATE"] .. ": " .. date(L["DATE_FORMAT"], playerData.last_update));
end

function LogTracker:SetPlayerInfoTooltip(playerData, playerName, playerRealm, disableShiftNotice)
  if playerData.logs then
    -- Actual logs
    for zoneIdSize, zone in pairs(playerData.logs) do
      local zoneId, zoneSize = strsplit("-", zoneIdSize);
      if (zoneSize == "10" and not self.db.hide10Player) or (zoneSize == "25" and not self.db.hide25Player) then
        local zoneName, zoneProgress, zoneHardmodes, zoneSpecs = self:GetPlayerLogsZonePerformance(zone, playerData.class);
        GameTooltip:AddDoubleLine(
          zoneName .. " " .. zoneProgress .. " " .. zoneHardmodes, zoneSpecs,
          1, 1, 1, 1, 1, 1
        );
        if IsShiftKeyDown() then
          for _, encounter in ipairs(zone.encounters) do
            local encounterName, encounterRating = self:GetPlayerLogsEncounterPerformance(encounter, playerData.class, true);
            GameTooltip:AddDoubleLine(
              "  " .. encounterName, encounterRating,
              1, 1, 1, 1, 1, 1
            );
          end
        end
      end
    end
  else
    -- Progress by archivments
    for zoneIdSize, zone in pairs(playerData.performance) do
      local zoneId, zoneSize = strsplit("-", zoneIdSize);
      if (zoneSize == "10" and not self.db.hide10Player) or (zoneSize == "25" and not self.db.hide25Player) then
        local zoneName, zoneProgress, zoneHardmodes, zoneSpecs = self:GetPlayerZonePerformance(zone, playerData.class);
        GameTooltip:AddDoubleLine(
          zoneName .. " " .. zoneProgress .. " " .. zoneHardmodes, zoneSpecs,
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
