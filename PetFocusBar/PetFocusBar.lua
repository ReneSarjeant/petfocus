local anchor = CreateFrame("Frame", nil, UIParent)
anchor:SetSize(210, 20)
anchor:SetFrameStrata("MEDIUM")
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:Hide()

local bar = CreateFrame("StatusBar", nil, anchor)
bar:SetAllPoints()
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(1, 0.53, 0.25)

local background = bar:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0.08, 0.08, 0.08, 0.9)

local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("CENTER")
label:SetText("Pet Focus")

local function SavePosition(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    PetFocusBarPosition = { x = x - centerX, y = y - centerY }
end

anchor:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        self:StartMoving()
    end
end)
anchor:SetScript("OnDragStop", SavePosition)
anchor:SetScript("OnHide", function(self)
    self:StopMovingOrSizing()
end)

local function UpdateBar()
    if not UnitExists("pet") then
        anchor:Hide()
        return
    end

    bar:SetMinMaxValues(0, UnitPowerMax("pet", Enum.PowerType.Focus))
    bar:SetValue(UnitPower("pet", Enum.PowerType.Focus))
    anchor:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_PET", "player")
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "pet")
events:RegisterUnitEvent("UNIT_MAXPOWER", "pet")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        local position = PetFocusBarPosition or { x = 0, y = -160 }
        anchor:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
        self:UnregisterEvent(event)
    end
    UpdateBar()
end)
