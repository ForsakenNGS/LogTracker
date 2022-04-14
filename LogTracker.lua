local _, L = ...;

LogTracker = CreateFrame("Frame", "LogTracker", UIParent);

function LogTracker:Init()
  self.debug = true;
  self:LogOutput("Init");
  self:SetScript("OnEvent", self.OnEvent);
  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
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
  if (event == "UPDATE_MOUSEOVER_UNIT") {
    self:OnMouseoverUnit();
  } else {
    self:LogOutput("OnEvent", event, ...);
  }
end

function LogTracker:OnMouseoverUnit()

end

-- Kickstart the addon
LogTracker:Init();
