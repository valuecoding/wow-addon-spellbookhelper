-- SpellBook Helper für MoP Classic
-- Zeigt an, welche Zauber bereits in Aktionsleisten sind

local addonName, addon = ...
local frame = CreateFrame("Frame")
local spellBookFrame = nil
local actionBars = {}

-- Konstanten
local SPELLS_PER_PAGE = SPELLS_PER_PAGE or 12 -- Fallback für MoP Classic

-- Farben für die Anzeige
local COLORS = {
    IN_ACTIONBAR = {0.2, 1.0, 0.2}, -- Grün für Zauber in Aktionsleiste
    NOT_IN_ACTIONBAR = {1.0, 0.2, 0.2}, -- Rot für Zauber nicht in Aktionsleiste
    NORMAL = {1.0, 1.0, 1.0} -- Weiß für normale Anzeige
}

-- Lokalisierung
local L = {}
local locale = GetLocale()

if locale == "deDE" then
    L.IN_ACTIONBAR = "✓ In Aktionsleiste"
    L.NOT_IN_ACTIONBAR = "✗ Nicht in Aktionsleiste"
    L.ACTIONBARS_RESCANNED = "Aktionsleisten neu gescannt!"
    L.COMMANDS_HEADER = "SpellBook Helper Kommandos:"
    L.CMD_RELOAD = "/sbh reload - Aktionsleisten neu scannen"
    L.CMD_HELP = "/sbh help - Diese Hilfe anzeigen"
    L.USE_HELP = "Verwende /sbh help für Kommandos"
else
    -- Default: English for all other locales
    L.IN_ACTIONBAR = "✓ In Action Bar"
    L.NOT_IN_ACTIONBAR = "✗ Not in Action Bar"
    L.ACTIONBARS_RESCANNED = "Action bars rescanned!"
    L.COMMANDS_HEADER = "SpellBook Helper Commands:"
    L.CMD_RELOAD = "/sbh reload - Rescan action bars"
    L.CMD_HELP = "/sbh help - Show this help"
    L.USE_HELP = "Use /sbh help for commands"
end

-- Tooltip-Flags zurücksetzen
local function resetTooltipFlags(tooltip)
    tooltip.hasActionBarInfo = false
end

-- Action Bar Info zu Spell-Tooltips hinzufügen  
local function addActionBarInfo(tooltip)
    if tooltip.hasActionBarInfo then return end
    
    local _, spellID = tooltip:GetSpell()
    if spellID then
        -- Prüfe ob diese Spell-ID in den Aktionsleisten ist
        local isInActionBar = actionBars[spellID]
        
        if isInActionBar then
            tooltip:AddLine("|cFF00FF00" .. L.IN_ACTIONBAR .. "|r", 0.2, 1.0, 0.2)
        else
            tooltip:AddLine("|cFFFF0000" .. L.NOT_IN_ACTIONBAR .. "|r", 1.0, 0.2, 0.2)
        end
        
        tooltip:Show()
        tooltip.hasActionBarInfo = true
    end
end

-- Tooltip Update Handler
local function onTooltipUpdate(tooltip)
    -- Nur im Zauberbuch aktiv
    if SpellBookFrame and SpellBookFrame:IsVisible() then
        local currentTab = SpellBookFrame.selectedSkillLine or 2
        if currentTab >= 2 then  -- Nur in Spezialisierungs-Tabs
            addActionBarInfo(tooltip)
        end
    end
end

-- Tooltip Show Handler  
local function onTooltipShow(tooltip)
    resetTooltipFlags(tooltip)
end

-- Initialisierung
function addon:Initialize()
    -- Hook in das Zauberbuch
    local success, err = pcall(function()
        self:HookSpellBook()
    end)
    
    if not success then
        print("|cFFFF0000SpellBook Helper|r: Fehler beim Hooken des Zauberbuchs: " .. tostring(err))
    end
    
    -- Tooltip-Hooks registrieren (wie dein Spellid-Addon)
    local success2, err2 = pcall(function()
        GameTooltip:HookScript("OnShow", function(tooltip)
            onTooltipShow(tooltip)
        end)
        GameTooltip:HookScript("OnUpdate", function(tooltip)
            onTooltipUpdate(tooltip)
        end)
        GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
            resetTooltipFlags(tooltip)
        end)
        print("|cFF00FF00SpellBook Helper|r: Tooltip-Hooks erfolgreich registriert")
    end)
    
    if not success2 then
        print("|cFFFF0000SpellBook Helper|r: Fehler beim Initialisieren: " .. tostring(err2))
    end
    
    -- Event Handler registrieren
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        addon:OnEvent(event, ...)
    end)
    
    print("|cFF00FF00SpellBook Helper|r geladen! Tooltip-Hooks aktiviert.")
end

-- Event Handler
function addon:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:UpdateActionBars()
    elseif event == "SPELLS_CHANGED" then
        self:UpdateActionBars()
        self:UpdateSpellBookDisplay()
    elseif event == "ACTIONBAR_UPDATE_STATE" then
        self:UpdateActionBars()
        self:UpdateSpellBookDisplay()
    end
end

-- Aktionsleisten scannen und Zauber sammeln
function addon:UpdateActionBars()
    actionBars = {}
    
    -- Alle Aktionsleisten durchgehen - MoP Classic verwendet 1-120 Slots
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        
        if actionType == "spell" and id then
            local spellName = GetSpellInfo(id)
            if spellName then
                actionBars[spellName] = true
                actionBars[id] = true -- Auch nach ID speichern
            end
        end
    end
    
    -- Pet-Aktionsleiste
    for slot = 1, 10 do
        local spellName, _, _, isToken = GetPetActionInfo(slot)
        if spellName and not isToken then
            actionBars[spellName] = true
        end
    end
end

-- Zauberbuch Hook
function addon:HookSpellBook()
    -- Hook für das Öffnen des Zauberbuchs
    hooksecurefunc("ShowUIPanel", function(panel)
        if panel == SpellBookFrame then
            C_Timer.After(0.2, function()
                self:UpdateActionBars()  -- Aktionsleisten neu scannen
                self:UpdateSpellBookDisplay()
            end)
        end
    end)
    
    -- Hook für das Schließen des Zauberbuchs
    hooksecurefunc("HideUIPanel", function(panel)
        if panel == SpellBookFrame then
            self:ResetSpellBookDisplay()
        end
    end)
    
    -- Hook für Seitenwechsel im Zauberbuch - verwende SpellBookFrame direkt
    if SpellBookFrame then
        SpellBookFrame:HookScript("OnShow", function()
            C_Timer.After(0.2, function()
                self:UpdateSpellBookDisplay()
            end)
        end)
        
        -- Hook für Seitenwechsel
        if SpellBookFrame.PageNavigationFrame then
            SpellBookFrame.PageNavigationFrame:HookScript("OnValueChanged", function()
                C_Timer.After(0.1, function()
                    self:ResetSpellBookDisplay()  -- Erst reset
                    self:UpdateSpellBookDisplay()
                end)
            end)
        end
    end
    
    -- Alternative: Hook für SpellBookFrame_Update falls verfügbar
    if _G["SpellBookFrame_Update"] then
        hooksecurefunc("SpellBookFrame_Update", function()
            C_Timer.After(0.1, function()
                self:ResetSpellBookDisplay()  -- Erst reset
                self:UpdateSpellBookDisplay()
            end)
        end)
    end
    
    -- Hook für Tab-Wechsel (SpellBookFrame_UpdateSkillLineTabs existiert nicht in Classic)
    -- Alternative: Hook anderer Tab-Events wenn verfügbar
    
    -- Zusätzlicher Hook für alle möglichen Spellbook-Events
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    frame:RegisterEvent("PLAYER_LOGIN")
end

-- Zauberbuch-Anzeige aktualisieren
function addon:UpdateSpellBookDisplay()
    -- Tooltip-Hooks sind bereits aktiv
end

-- Zauber-Button Farbe aktualisieren
function addon:UpdateSpellButtonColor(spellButton, spellName, spellID)
    if not spellButton or not spellButton:IsVisible() then
        return
    end
    
    -- Versuche verschiedene Icon-Namen
    local icon = spellButton.icon or spellButton.iconTexture or spellButton:GetNormalTexture()
    
    -- Alternative: Suche nach Child-Frames
    if not icon then
        for i = 1, spellButton:GetNumChildren() do
            local child = select(i, spellButton:GetChildren())
            if child and child.SetVertexColor then
                icon = child
                break
            end
        end
    end
    
    -- Alternative: Suche nach Regionen
    if not icon then
        for i = 1, spellButton:GetNumRegions() do
            local region = select(i, spellButton:GetRegions())
            if region and region.SetVertexColor and region:GetObjectType() == "Texture" then
                icon = region
                break
            end
        end
    end
    
    if not icon then
        return
    end
    
    -- Prüfen ob Zauber in Aktionsleiste ist
    local isInActionBar = actionBars[spellName] or (spellID and actionBars[spellID])
    
    if isInActionBar then
        -- Zauber ist in Aktionsleiste - grüner Rahmen
        icon:SetVertexColor(unpack(COLORS.IN_ACTIONBAR))
        
        -- Tooltip erweitern
        local originalOnEnter = spellButton:GetScript("OnEnter")
        local originalOnLeave = spellButton:GetScript("OnLeave")
        spellButton.originalOnEnter = originalOnEnter  -- Store for reset
        spellButton.originalOnLeave = originalOnLeave
        
        spellButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if spellID then
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:AddLine("|cFF00FF00" .. L.IN_ACTIONBAR .. "|r", 0.2, 1.0, 0.2)
            end
            GameTooltip:Show()
        end)
        
        spellButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    else
        -- Zauber ist nicht in Aktionsleiste - roter Rahmen
        icon:SetVertexColor(unpack(COLORS.NOT_IN_ACTIONBAR))
        
        -- Tooltip erweitern
        local originalOnEnter = spellButton:GetScript("OnEnter")
        local originalOnLeave = spellButton:GetScript("OnLeave")
        spellButton.originalOnEnter = originalOnEnter  -- Store for reset
        spellButton.originalOnLeave = originalOnLeave
        
        spellButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if spellID then
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:AddLine("|cFFFF0000" .. L.NOT_IN_ACTIONBAR .. "|r", 1.0, 0.2, 0.2)
            end
            GameTooltip:Show()
        end)
        
        spellButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
end

-- Zauberbuch-Anzeige zurücksetzen
function addon:ResetSpellBookDisplay()
    for i = 1, SPELLS_PER_PAGE do
        local spellButton = _G["SpellButton" .. i]
        if spellButton then
            local icon = spellButton.icon
            if icon then
                icon:SetVertexColor(1, 1, 1) -- Normale Farbe
            end
            
            -- Restore original tooltip handlers
            if spellButton.originalOnEnter then
                spellButton:SetScript("OnEnter", spellButton.originalOnEnter)
                spellButton.originalOnEnter = nil
            end
            if spellButton.originalOnLeave then
                spellButton:SetScript("OnLeave", spellButton.originalOnLeave)
                spellButton.originalOnLeave = nil
            end
        end
        
        -- Alternative: SpellBookSpellIcons
        local spellIcon = _G["SpellBookSpellIcons" .. i]
        if spellIcon then
            local icon = spellIcon.icon
            if icon then
                icon:SetVertexColor(1, 1, 1) -- Normale Farbe
            end
        end
    end
end

-- Slash Commands
SLASH_SPELLBOOKHELPER1 = "/sbh"
SLASH_SPELLBOOKHELPER2 = "/spellbookhelper"

SlashCmdList["SPELLBOOKHELPER"] = function(msg)
    if msg == "reload" then
        addon:UpdateActionBars()
        addon:UpdateSpellBookDisplay()
        print("|cFF00FF00SpellBook Helper|r: " .. L.ACTIONBARS_RESCANNED)
    elseif msg == "help" then
        print("|cFF00FF00" .. L.COMMANDS_HEADER .. "|r")
        print(L.CMD_RELOAD)
        print(L.CMD_HELP)
    else
        print("|cFF00FF00SpellBook Helper|r: " .. L.USE_HELP)
    end
end

-- Addon initialisieren
local success, err = pcall(function()
    addon:Initialize()
end)

if not success then
    print("|cFFFF0000SpellBook Helper|r: Fehler beim Initialisieren: " .. tostring(err))
end
