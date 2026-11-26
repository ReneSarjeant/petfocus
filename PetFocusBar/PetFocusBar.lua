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

-- Independent Bite timer. The original focus bar above is unchanged.
local biteBar = CreateFrame("StatusBar", nil, anchor)
biteBar:SetSize(210, 20)
biteBar:SetPoint("TOP", bar, "BOTTOM", 0, -3)
biteBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
biteBar:SetMinMaxValues(0, 10)
local bg = biteBar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.08, 0.08, 0.08, 0.9)
local warning = biteBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
warning:SetPoint("CENTER")
local expires, lastStart, debugMode = 0, nil, false
local biteIDs = {[17253]=true,[17255]=true,[17256]=true,[17257]=true,[17258]=true,[17259]=true,[17260]=true,[17261]=true,[27050]=true,[3107]=true}
local function IsBite(id, name)
    if type(issecretvalue) == "function" and (issecretvalue(id) or issecretvalue(name)) then return false end
    return biteIDs[id] or (type(name) == "string" and (name == "Bite" or name:match("^Bite%s*%(")))
end
local function StartBite()
    if GetTime() - (expires - 10) > 0.5 then expires = GetTime() + 10 end
end
local function PollCooldown()
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local name = GetPetActionInfo(i)
        if IsBite(nil, name) then
            local start, duration = GetPetActionCooldown(i)
            if start and duration and duration > 2 and start > 0 and start ~= lastStart then
                lastStart = start
                expires = math.max(expires, start + duration)
            end
            return
        end
    end
end
local function UpdateWarning()
    -- Cooldown errors cannot prevent the warning or original focus display.
    pcall(PollCooldown)
    local left = math.max(0, math.min(10, expires - GetTime()))
    local ok, focus = pcall(function()
        local value = UnitPower("pet", Enum.PowerType.Focus)
        -- Arithmetic probe: do not discard ordinary readable focus values.
        return value + 0
    end)
    -- Fallback is explicitly time-based, not a focus guarantee.
    local safe = left > 5
    local estimated = true
    if ok then
        local success, result = pcall(function()
            local regen = math.max(0, math.floor((left - 0.25) / 2)) * 12
            return left > 1.5 and focus >= 25 and focus - 25 + regen >= 35
        end)
        if success and not (type(issecretvalue) == "function" and issecretvalue(result)) then
            safe = result
            estimated = false
        end
    end
    local message
    if left <= 0 then
        message = "BITE READY"
        biteBar:SetValue(10)
    else
        message = safe and (estimated and "CLAW? (TIME)" or "CLAW") or "STOP CLAW"
        biteBar:SetValue(left)
    end
    if safe then biteBar:SetStatusBarColor(0.12, 0.72, 0.25)
    else biteBar:SetStatusBarColor(0.85, 0.12, 0.12) end
    warning:SetFormattedText("Bite %.1f | %s", left, message)
end
local ticker = CreateFrame("Frame", nil, anchor)
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 0.1 then
        elapsed = 0
        pcall(UpdateWarning)
    end
end)
local castEvents = CreateFrame("Frame")
pcall(castEvents.RegisterUnitEvent, castEvents, "UNIT_SPELLCAST_SUCCEEDED", "pet")
pcall(castEvents.RegisterEvent, castEvents, "COMBAT_LOG_EVENT_UNFILTERED")
castEvents:SetScript("OnEvent", function(_, event, ...)
    local unit, _, id = ...
    pcall(function()
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit == "pet" then
                if debugMode then print("PetFocusBar pet cast:", id) end
                if IsBite(id) then StartBite() end
            end
        elseif CombatLogGetCurrentEventInfo then
            local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, id, name = CombatLogGetCurrentEventInfo()
            if subevent == "SPELL_CAST_SUCCESS" and sourceGUID == UnitGUID("pet") and IsBite(id, name) then StartBite() end
        end
    end)
end)
SLASH_PETFOCUSBAR1 = "/pfb"
SlashCmdList.PETFOCUSBAR = function(msg)
    if msg == "test" then expires = GetTime() + 10
    elseif msg == "debug" then debugMode = not debugMode; print("PetFocusBar debug:", debugMode)
    else print("PetFocusBar: /pfb test or /pfb debug") end
end
