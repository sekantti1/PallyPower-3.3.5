--[[
  PallyPowerQuickAssign.lua  (v3)

  Adds two quick-assign features to PallyPower:

  1. HOVER PANEL on the main buff window drag handle (PallyPowerAnchor):
     Mouse over the drag handle to reveal a panel with 5 buttons.

  2. PER-PLAYER BUTTONS in the config frame:
     5 small icon buttons to the left of each paladin's name row.

  Blessing IDs:  0=none  1=Wisdom  2=Might  3=Kings  4=Sanctuary
  Class IDs:     1=Warrior 2=Rogue 3=Priest 4=Druid 5=Paladin
                 6=Hunter  7=Mage  8=Warlock 9=Shaman 10=DK 11=Pet
]]

-- ---------------------------------------------------------------------------
-- Class sets
-- ---------------------------------------------------------------------------

local PP_QA_MIGHT_CLASSES = {
    [1]=true, [2]=true, [4]=true, [5]=true,
    [6]=true, [9]=true, [10]=true, [11]=true,
}
local PP_QA_WISDOM_CLASSES = {
    [3]=true, [4]=true, [5]=true, [6]=true,
    [7]=true, [8]=true, [9]=true, [11]=true,
}

local function PP_QA_SmartBid(classID)
    if classID == 1 or classID == 2 or classID == 5 or classID == 6 or classID == 10 then
        return 2  
    elseif classID == 11 then
        return 2  -- Pet → Might
    else
        return 1  -- Everyone else  → Wisdom
    end
end

-- Icon paths for WoW 3.3.5a
local PP_QA_Icons = {
    kings     = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
    wisdom    = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom",
    might     = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
    sanctuary = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary",
    smart     = "Interface\\Icons\\spell_holy_layonhands",
}

-- ---------------------------------------------------------------------------
-- Core assign / mode helpers
-- ---------------------------------------------------------------------------

local function PP_QA_Assign(pallyName, classID, blessingID)
    --if InCombatLockdown() then return end
    if not PallyPower:CanControl(pallyName) then return end
    if not PallyPower_Assignments[pallyName] then
        PallyPower_Assignments[pallyName] = {}
        for i = 1, PALLYPOWER_MAXCLASSES do
            PallyPower_Assignments[pallyName][i] = 0
        end
    end
    PallyPower_Assignments[pallyName][classID] = blessingID
    PallyPower:SendMessage("ASSIGN " .. pallyName .. " " .. classID .. " " .. blessingID)
end

local function PP_QA_ApplyMode(pallyName, mode)
    --if InCombatLockdown() then return end
    if not PallyPower:CanControl(pallyName) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444PallyPower QuickAssign:|r Cannot control " .. pallyName)
        return
    end
    for classID = 1, PALLYPOWER_MAXCLASSES do
        local bid = 0
        if     mode == "kings"     then bid = 3
        elseif mode == "sanctuary" then bid = 4
        elseif mode == "wisdom"    then bid = PP_QA_WISDOM_CLASSES[classID] and 1 or 0
        elseif mode == "might"     then bid = PP_QA_MIGHT_CLASSES[classID]  and 2 or 0
        elseif mode == "class"     then bid = PP_QA_SmartBid(classID)
        end
        PP_QA_Assign(pallyName, classID, bid)
    end
end

local function PP_QA_ApplyModeAll(mode)
    --if InCombatLockdown() then return end
    for pallyName in pairs(AllPallys) do
        PP_QA_ApplyMode(pallyName, mode)
    end
    PallyPower:UpdateLayout()
    PallyPowerConfigGrid_Update()
end

-- ---------------------------------------------------------------------------
-- Skin helper — reads the user's current PallyPower skin setting
-- ---------------------------------------------------------------------------

local function PP_QA_GetSkinBg()
    local skinName = PallyPower.opt and PallyPower.opt.skin or "None"
    return PallyPower.Skins and PallyPower.Skins[skinName]
           or "Interface\\Tooltips\\UI-Tooltip-Background"
end

local function PP_QA_GetEdge()
    if PallyPower.opt and PallyPower.opt.display and PallyPower.opt.display.edges then
        return PallyPower.Edge or "Interface\\Tooltips\\UI-Tooltip-Border"
    end
    return nil
end

-- Apply (or re-apply) the current skin to our hover frame
local function PP_QA_ReskinHoverFrame(f)
    if not f then return end
    f:SetBackdrop({
        bgFile   = PP_QA_GetSkinBg(),
        edgeFile = PP_QA_GetEdge(),
        tile = false, tileSize = 8, edgeSize = 8,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0.0, 0.7, 0.0, 0.5)
end

-- ---------------------------------------------------------------------------
-- Hide-delay ticker  (WoW 3.3.5 has no C_Timer; use OnUpdate)
-- ---------------------------------------------------------------------------

local PP_QA_HIDE_DELAY  = 1   -- seconds before the panel hides
local PP_QA_HideElapsed = 0
local PP_QA_HidePending = false

local PP_QA_HideTicker = CreateFrame("Frame")
PP_QA_HideTicker:Hide()
PP_QA_HideTicker:SetScript("OnUpdate", function(self, elapsed)
    if not PP_QA_HidePending then self:Hide(); return end
    PP_QA_HideElapsed = PP_QA_HideElapsed + elapsed
    if PP_QA_HideElapsed >= PP_QA_HIDE_DELAY then
        PP_QA_HidePending = false
        self:Hide()
        if PallyPowerQuickAssignHover then
            PallyPowerQuickAssignHover:Hide()
        end
    end
end)

local function PP_QA_ScheduleHide()
    PP_QA_HideElapsed = 0
    PP_QA_HidePending = true
    PP_QA_HideTicker:Show()
end

local function PP_QA_CancelHide()
    PP_QA_HidePending = false
    PP_QA_HideTicker:Hide()
end

-- ---------------------------------------------------------------------------
-- Button definitions for hover panel
-- ---------------------------------------------------------------------------

local PP_QA_HoverDefs = {
    {
        icon  = PP_QA_Icons.kings,
        label = "Kings",
        tip   = "|cffffd700Kings ALL|r\nGreater Blessing of Kings to every class.",
        mode  = "kings",
    },
    {
        icon  = PP_QA_Icons.wisdom,
        label = "Wisd",
        tip   = "|cffffd700Wisdom|r\nGreater Blessing of Wisdom to mana classes.",
        mode  = "wisdom",
    },
    {
        icon  = PP_QA_Icons.might,
        label = "Might",
        tip   = "|cffffd700Might|r\nGreater Blessing of Might to melee classes.",
        mode  = "might",
    },
    {
        icon  = PP_QA_Icons.sanctuary,
        label = "Sanc",
        tip   = "|cffffd700Sanctuary ALL|r\nGreater Blessing of Sanctuary to every class.",
        mode  = "sanctuary",
    },
    {
        icon  = PP_QA_Icons.smart,
        label = "Class",
        tip   = "|cffffd700Smart Class Buff|r",
        mode  = "class",
    },
}

-- ---------------------------------------------------------------------------
-- FEATURE 1 — Hover panel
-- ---------------------------------------------------------------------------

local PP_QA_HoverFrame = nil

local function PP_QA_CreateHoverFrame()
    if PP_QA_HoverFrame then return end

    local BTN_SIZE = 22
    local BTN_GAP  = 6
    local PADDING  = 6
    local numBtns  = #PP_QA_HoverDefs
    local panelW   = PADDING * 2 + numBtns * BTN_SIZE + (numBtns - 1) * BTN_GAP
    local panelH   = 50

    local f = CreateFrame("Frame", "PallyPowerQuickAssignHover", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetWidth(panelW)
    f:SetHeight(panelH)
    f:SetPoint("TOPRIGHT", _G["PallyPowerAnchor"] or PallyPowerFrame, "TOPLEFT", -4, 4)
    f:Hide()

    -- Apply current skin (will be re-applied whenever ApplySkin is called)
    PP_QA_ReskinHoverFrame(f)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT",  f, "TOPLEFT",  PADDING, -4)
    title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -4)
    title:SetText("|cffffd700Quick Assign|r")
    title:SetJustifyH("CENTER")

    -- Divider (use ChatFrameBackground as a solid 1-px line, 3.3.5-safe)
    local line = f:CreateTexture(nil, "OVERLAY")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  f, "TOPLEFT",  PADDING,  -14)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -14)
    line:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    line:SetVertexColor(0.6, 0.5, 0.1, 0.8)

    for i, def in ipairs(PP_QA_HoverDefs) do
        local xOff = PADDING + (i - 1) * (BTN_SIZE + BTN_GAP)

        local btn = CreateFrame("Button", "PallyPowerQAHoverBtn" .. i, f)
        btn:SetWidth(BTN_SIZE)
        btn:SetHeight(BTN_SIZE)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", xOff, -17)

        local ic = btn:CreateTexture(nil, "ARTWORK")
        ic:SetAllPoints()
        ic:SetTexture(def.icon)
        ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
        lbl:SetPoint("TOP", btn, "BOTTOM", 0, 0)
        lbl:SetWidth(BTN_SIZE + 6)
        lbl:SetText("|cffcccccc" .. def.label .. "|r")
        lbl:SetJustifyH("CENTER")

        local mode    = def.mode
        local tipText = def.tip

        btn:SetScript("OnEnter", function()
            PP_QA_CancelHide()
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(tipText, 1, 1, 1, true)
            if GameTooltipTextLeft1 then
                GameTooltipTextLeft1:SetFont(
                    "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
            PP_QA_ScheduleHide()
        end)
        btn:SetScript("OnClick", function()
            PP_QA_ApplyModeAll(mode)
        end)
    end

    f:EnableMouse(true)
    f:SetScript("OnEnter", function() PP_QA_CancelHide() end)
    f:SetScript("OnLeave", function() PP_QA_ScheduleHide() end)

    PP_QA_HoverFrame = f
end

local function PP_QA_HookMainFrame()
    PP_QA_CreateHoverFrame()

    local trigger = _G["PallyPowerAnchor"] or PallyPowerFrame
    trigger:HookScript("OnEnter", function()
        if not InCombatLockdown() then
            PP_QA_CancelHide()
            PP_QA_HoverFrame:Show()
        end
    end)
    trigger:HookScript("OnLeave", function()
        PP_QA_ScheduleHide()
    end)
end

-- ---------------------------------------------------------------------------
-- FEATURE 2 — Per-player quick buttons in config frame
-- ---------------------------------------------------------------------------

local PP_QA_PlayerContainers = {}
local PP_QA_MAX_PALLYS = 10

local PP_QA_PlayerDefs = {
    { icon = PP_QA_Icons.kings,     tip = "|cffffd700Kings ALL|r — assign Kings to all classes", mode = "kings"    },
    { icon = PP_QA_Icons.wisdom,    tip = "|cffffd700Wisdom|r — Wisdom to mana classes", mode = "wisdom"   },
    { icon = PP_QA_Icons.might,     tip = "|cffffd700Might|r — Might to physical classes", mode = "might"    },
    { icon = PP_QA_Icons.sanctuary, tip = "|cffffd700Sanctuary ALL|r — assign Sanctuary to all classes.", mode = "sanctuary"},
    { icon = PP_QA_Icons.smart, tip = "|cffffd700Smart Class Buff|r", mode = "class"},
}

local BTN_CFG = 20
local GAP_CFG = 4

local function PP_QA_CreatePlayerRowButtons(pnum)
    if PP_QA_PlayerContainers[pnum] then return end

    local rowFrame  = _G["PallyPowerConfigFramePlayer" .. pnum]
    local nameLabel = _G["PallyPowerConfigFramePlayer" .. pnum .. "Name"]
    if not rowFrame or not nameLabel then return end

    local numBtns = #PP_QA_PlayerDefs
    local totalW  = numBtns * BTN_CFG + (numBtns - 1) * GAP_CFG

    local container = CreateFrame("Frame", "PallyPowerQAPlayer" .. pnum .. "Container", rowFrame)
    container:SetWidth(totalW)
    container:SetHeight(BTN_CFG)
    container:SetPoint("RIGHT", nameLabel, "LEFT", -6, 0)

    for i, def in ipairs(PP_QA_PlayerDefs) do
        local btn = CreateFrame("Button", "PallyPowerQAPlayer" .. pnum .. "Btn" .. i, container)
        btn:SetWidth(BTN_CFG)
        btn:SetHeight(BTN_CFG)
        btn:SetPoint("LEFT", container, "LEFT", (i - 1) * (BTN_CFG + GAP_CFG), 0)

        local ic = btn:CreateTexture(nil, "ARTWORK")
        ic:SetAllPoints()
        ic:SetTexture(def.icon)
        ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")

        local capturedPnum = pnum
        local capturedMode = def.mode
        local capturedTip  = def.tip

        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(capturedTip, 1, 1, 1, true)
            if GameTooltipTextLeft1 then
                GameTooltipTextLeft1:SetFont(
                    "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            local nameFs = _G["PallyPowerConfigFramePlayer" .. capturedPnum .. "Name"]
            local pname  = nameFs and nameFs:GetText()
            if pname and pname ~= "" then
                PP_QA_ApplyMode(pname, capturedMode)
                PallyPower:UpdateLayout()
                PallyPowerConfigGrid_Update()
            end
        end)
    end

    PP_QA_PlayerContainers[pnum] = container
end

local function PP_QA_EnsurePlayerButtons()
    for pnum = 1, PP_QA_MAX_PALLYS do
        if _G["PallyPowerConfigFramePlayer" .. pnum] then
            PP_QA_CreatePlayerRowButtons(pnum)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Initialization — deferred until all addon frames exist
-- ---------------------------------------------------------------------------

local PP_QA_InitFrame = CreateFrame("Frame")
local PP_QA_InitDone  = false

PP_QA_InitFrame:SetScript("OnUpdate", function()
    if PP_QA_InitDone then return end
    if not PallyPowerFrame then return end

    PP_QA_InitDone = true
    PP_QA_InitFrame:SetScript("OnUpdate", nil)

    PP_QA_HookMainFrame()

    local origGridUpdate = PallyPowerConfigGrid_Update
    PallyPowerConfigGrid_Update = function(...)
        origGridUpdate(...)
        PP_QA_EnsurePlayerButtons()
    end

    -- Hook ApplySkin so our panel re-skins when the user changes skin in options
    local origApplySkin = PallyPower.ApplySkin
    PallyPower.ApplySkin = function(self, skinname, ...)
        origApplySkin(self, skinname, ...)
        PP_QA_ReskinHoverFrame(PP_QA_HoverFrame)
    end

    PP_QA_EnsurePlayerButtons()
end)
