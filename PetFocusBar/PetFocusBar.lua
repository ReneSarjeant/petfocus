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

-- Bite display shares the focus bar's anchor and dimensions.
local biteBar = CreateFrame("StatusBar", nil, anchor)
biteBar:SetSize(210, 20)
biteBar:SetPoint("TOP", bar, "BOTTOM", 0, -3)
biteBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
biteBar:SetMinMaxValues(0, 10)
local biteBackground = biteBar:CreateTexture(nil, "BACKGROUND")
biteBackground:SetAllPoints()
biteBackground:SetColorTexture(0.08, 0.08, 0.08, 0.9)
local biteLabel = biteBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
biteLabel:SetPoint("CENTER")

local BITE_COST, CLAW_COST = 35, 25
-- Conservative allowance: 10 focus per full two-second interval.
-- Do not count bonus regeneration from talents or crits.
local function UpdateBite()
    if not UnitExists("pet") then return end
    local slot
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local name, _, isToken = GetPetActionInfo(i)
        if name and not isToken and (name == "Bite" or name:match("^Bite%s*%(")) then
            slot = i
            break
        end
    end
    if not slot then
        biteBar:Hide()
        return
    end
    biteBar:Show()
    local start, duration = GetPetActionCooldown(slot)
    local remaining = 0
    if start and duration and duration > 2 then
        remaining = math.max(0, start + duration - GetTime())
    end
    local focus = UnitPower("pet", Enum.PowerType.Focus)
    local regen = math.max(0, math.floor((remaining - 0.25) / 2)) * 10
    local reserve = remaining <= 0 or focus < CLAW_COST or
        focus - CLAW_COST + regen < BITE_COST
    biteBar:SetValue(remaining > 0 and math.min(10, remaining) or 10)
    if reserve then
        biteBar:SetStatusBarColor(0.85, 0.12, 0.12)
    else
        biteBar:SetStatusBarColor(0.15, 0.7, 0.25)
    end
    if remaining <= 0 then
        biteLabel:SetText(focus >= BITE_COST and "Bite READY" or "Bite - SAVE FOCUS")
    else
        biteLabel:SetFormattedText("Bite  %.1f  %s", remaining, reserve and "SAVE" or "CLAW")
    end
end

local elapsed = 0
anchor:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 0.1 then
        elapsed = 0
        UpdateBite()
    end
end)

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

    local focus = UnitPower("pet", Enum.PowerType.Focus)
    local maxFocus = UnitPowerMax("pet", Enum.PowerType.Focus)
    bar:SetMinMaxValues(0, maxFocus)
    bar:SetValue(focus)
    label:SetFormattedText("Pet Focus  %d / %d", focus, maxFocus)
    anchor:Show()
    UpdateBite()
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
