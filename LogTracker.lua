local _, L = ...;

LogTracker = CreateFrame("Frame", "LogTracker", UIParent);

function LogTracker:Init()
  self.debug = false;
  self.playerDataFiltered = false;
  self:LogDebug("Init");
  self:SetScript("OnEvent", self.OnEvent);
  self:RegisterEvent("CHAT_MSG_SYSTEM");
  self:RegisterEvent("MODIFIER_STATE_CHANGED");
  --self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
  GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    LogTracker:OnTooltipSetUnit();
  end);
end

function LogTracker:LogOutput(...)
  print("|cffff0000LT|r", ...);
end

function LogTracker:LogDebug(...)
  if self.debug then
    print("|cffff0000LT|r", "|cffffff00Debug|r", ...);
  end
end

function LogTracker:OnEvent(event, ...)
  if (event == "CHAT_MSG_SYSTEM") then
    self:OnChatMsgSystem(...);
  elseif (event == "UPDATE_MOUSEOVER_UNIT") then
    self:OnMouseoverUnit(...);
  elseif (event == "MODIFIER_STATE_CHANGED") then
    self:OnModifierStateChanged(...);
  else
    self:LogDebug("OnEvent", event, ...);
  end
end

function LogTracker:OnChatMsgSystem(text)
  local _, _, name, linkText = string.find(text, "|Hplayer:([^:]*)|h%[([^%[%]]*)%]?|h");
  if name then
    local playerData, playerName, playerRealm = self:GetPlayerData(name);
    if playerData then
      self:SendPlayerInfoToChat(playerData, playerName, playerRealm);
    end
  end
end

function LogTracker:OnModifierStateChanged()
  if (UnitExists("mouseover")) then
    GameTooltip:SetUnit("mouseover");
  end
end

function LogTracker:OnTooltipSetUnit()
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

function LogTracker:GetIconSized(iconTemplate, width, height)
  local iconString = gsub(gsub(iconTemplate, "%%w", width), "%%h", height);
  return "|T"..iconString.."|t";
end

-- /script print(LogTracker:GetClassIcon("Priest"))
-- /script print("\124TInterface/AddOns/LogTracker/Icons/classes:36:36:0:0:256:512:180:216:36:72\124t")
-- /script print("\124TInterface/InventoryItems/WoWUnknownItem01\124t")
function LogTracker:GetClassIcon(classNameOrId, width, height)
  if not width then
    width = 18;
  end
  if not height then
    height = 18;
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
    return "|cff8000ff"..text.."|r";
  elseif (type == "spec") then
    return "|cffffffff"..text.."|r";
  elseif (type == "muted") then
    return "|cff808080"..text.."|r";
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
  if (value >= 95) then
    return "|cffffa000"..value.."|r";
  elseif (value >= 75) then
    return "|cffa000ff"..value.."|r";
  elseif (value >= 50) then
    return "|cff0000d0"..value.."|r";
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
  if not addonLoaded then
    return nil;
  end
  if not self.playerDataFiltered then
    self.playerDataFiltered = true;
    local playerRealm = GetRealmName();
    local removeCount = 0;
    for playerName, playerData in pairs(_G["LogTracker_CharacterData_"..region]) do
      if not string.match(playerName, "\-"..playerRealm.."$") then
        _G["LogTracker_CharacterData_"..region][playerName] = nil;
        removeCount = removeCount + 1;
      end
    end
  end
  local characterDataRaw = _G["LogTracker_CharacterData_"..region][playerFull];
  local characterData = nil;
  -- Unpack character data into a more accessible format
  if characterDataRaw then
    local characterPerformance = {};
    for zoneId, zonePerformance in pairs(characterDataRaw[5]) do
      -- Zone name
      local zoneName = "Unknown";
      if LogTracker_BaseData.zoneNames and LogTracker_BaseData.zoneNames[zoneId] then
        zoneName = LogTracker_BaseData.zoneNames[zoneId]['name'];
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
      local zoneEncountersStr = { strsplit("|", zonePerformance[4]) };
      for zoneEncounterIndex, zoneEncountersRaw in ipairs(zoneEncountersStr) do
        zoneEncountersRaw = { strsplit(",", zoneEncountersRaw) };
        tinsert(zoneEncounters, {
          ['spec'] = tonumber(zoneEncountersRaw[1]),
          ['encounter'] = LogTracker_BaseData.zoneEncounters[zoneId][zoneEncounterIndex],
          ['percentRank'] = zoneEncountersRaw[2],
          ['percentMedian'] = zoneEncountersRaw[3]
        });
      end
      -- Zone details
      characterPerformance[zoneId] = {
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

function LogTracker:GetPlayerZonePerformance(zone, playerClass)
  local zoneName = zone.zoneName;
  local zoneProgress = self:GetColoredProgress(tonumber(zone.encountersKilled), tonumber(zone.zoneEncounters));
  local zoneRatingsStr = "";
  local zoneRatings = {};
  for _, allstarsRating in ipairs(zone.allstars) do
    tinsert(zoneRatings, self:GetColoredPercent(allstarsRating.percentRank).." "..self:GetSpecIcon(playerClass, allstarsRating.spec));
  end
  if #(zoneRatings) > 0 then
    zoneRatingsStr = strjoin(" ", unpack(zoneRatings));
  end
  return self:GetColoredText("zone", zoneName), self:GetColoredText("progress", zoneProgress), zoneRatingsStr;
end

function LogTracker:GetPlayerEncounterPerformance(encounter, playerClass)
  local encounterName = encounter.encounter.name;
  if (encounter.spec == 0) then
    return "---";
  end
  local encounterRating = self:GetColoredPercent(encounter.percentRank).." "..self:GetSpecIcon(playerClass, encounter.spec);
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

function LogTracker:SendPlayerInfoToChat(playerData, playerName, playerRealm)
  for zoneId, zone in pairs(playerData.performance) do
    self:SendSystemChatLine( self:GetPlayerLink(playerName).." "..strjoin(" ", self:GetPlayerZonePerformance(zone, playerData.class)) );
  end
end

function LogTracker:SetPlayerInfoTooltip(playerData, playerName, playerRealm)
  for zoneId, zone in pairs(playerData.performance) do
    local zoneName, zoneProgress, zoneSpecs = self:GetPlayerZonePerformance(zone, playerData.class);
    GameTooltip:AddDoubleLine(
      zoneName.." "..zoneProgress, zoneSpecs,
      255, 255, 255, 255, 255, 255
    );
    if IsShiftKeyDown() then
      for _, encounter in ipairs(zone.encounters) do
        local encounterName, encounterRating = self:GetPlayerEncounterPerformance(encounter, playerData.class);
        GameTooltip:AddDoubleLine(
          "  "..encounterName, encounterRating,
          255, 255, 255, 255, 255, 255
        );
      end
    end
  end
  if not IsShiftKeyDown() then
    GameTooltip:AddLine(
      self:GetColoredText("muted", L["SHIFT_FOR_DETAILS"]),
      255, 255, 255
    );
  end
  GameTooltip:Show();
end

-- Kickstart the addon
LogTracker:Init();
