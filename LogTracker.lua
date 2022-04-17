local _, L = ...;

LogTracker = CreateFrame("Frame", "LogTracker", UIParent);

function LogTracker:Init()
  self.debug = false;
  self:LogDebug("Init");
  self:SetScript("OnEvent", self.OnEvent);
  self:RegisterEvent("CHAT_MSG_SYSTEM");
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

function LogTracker:OnTooltipSetUnit()
  local unitName, unitId = GameTooltip:GetUnit();
  if not UnitIsPlayer(unitId) then
    return;
  end
  local playerData, playerName, playerRealm = self:GetPlayerData( UnitName(unitId) );
  if playerData then
    self:SetPlayerInfoTooltip(playerData, playerName, playerRealm);
  end
end

function LogTracker:GetColoredText(type, text)
  if (type == "zone") then
    return "|cff8000ff"..text.."|r";
  elseif (type == "spec") then
    return "|cffffffff"..text.."|r";
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
    if not realmNameExplicit then
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
  local characterDataRaw = _G["LogTracker_CharacterData_"..region][playerFull];
  local characterData = nil;
  -- Unpack character data into a more accessible format
  if characterDataRaw then
    local characterPerformance = {};
    for zoneId, zonePerformance in pairs(characterDataRaw[4]) do
      -- Zone name
      local zoneName = "Unknown";
      if LogTracker_BaseData.zoneNames and LogTracker_BaseData.zoneNames[zoneId] then
        zoneName = LogTracker_BaseData.zoneNames[zoneId]['name'];
      end
      -- Allstars rankings
      local zoneAllstars = {};
      for _, zoneAllstarsRaw in ipairs(zonePerformance[3]) do
        tinsert(zoneAllstars, {
          ['spec'] = zoneAllstarsRaw[1],
          ['percentRank'] = zoneAllstarsRaw[2]
        });
      end
      -- Zone details
      characterPerformance[zoneId] = {
        ['zoneName'] = zoneName,
        ['zoneEncounters'] = zonePerformance[1],
        ['encountersKilled'] = zonePerformance[2],
        ['allstars'] = zoneAllstars
      }
    end
    -- Character details
    characterData = {
      ['level'] = characterDataRaw[1],
      ['faction'] = characterDataRaw[2],
      ['last_update'] = characterDataRaw[3],
      ['performance'] = characterPerformance,
    };
  end
  return characterData, playerName, realmName;
end

function LogTracker:GetPlayerZonePerformance(zone)
  local zoneName = zone.zoneName;
  local zoneProgress = self:GetColoredProgress(tonumber(zone.encountersKilled), tonumber(zone.zoneEncounters));
  local zoneRatingsStr = "";
  local zoneRatings = {};
  for _, allstarsRating in ipairs(zone.allstars) do
    tinsert(zoneRatings, self:GetColoredText("spec", allstarsRating.spec)..": "..self:GetColoredPercent(allstarsRating.percentRank));
  end
  if #(zoneRatings) > 0 then
    zoneRatingsStr = "("..strjoin(", ", unpack(zoneRatings))..")";
  end
  return self:GetColoredText("zone", zoneName), self:GetColoredText("progress", zoneProgress), zoneRatingsStr;
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
    self:SendSystemChatLine( self:GetPlayerLink(playerName).." "..strjoin(" ", self:GetPlayerZonePerformance(zone)) );
  end
end

function LogTracker:SetPlayerInfoTooltip(playerData, playerName, playerRealm)
  for zoneId, zone in pairs(playerData.performance) do
    local zoneName, zoneProgress, zoneSpecs = self:GetPlayerZonePerformance(zone);
    GameTooltip:AddDoubleLine(
      zoneName.." "..zoneProgress, zoneSpecs,
      255, 255, 255, 255, 255, 255
    );
    GameTooltip:Show();
  end
end

-- Kickstart the addon
LogTracker:Init();
