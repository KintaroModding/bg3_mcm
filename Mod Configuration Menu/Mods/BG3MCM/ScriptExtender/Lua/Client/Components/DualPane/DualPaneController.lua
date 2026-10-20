--------------------------------------------
-- DualPaneController (Facade)
-- Manages the dual-pane interface and wires together the left
-- and right panes.
-- It supports adding mod-specific content and menu sections, facilitating a structured presentation of mod configurations.
--------------------------------------------

---@class DualPaneController
---@field window any
---@field leftPane LeftPane
---@field rightPane RightPane
---@field isCollapsed boolean
---@field isHovered boolean
---@field userHasInteracted boolean
---@field hoverSubscription any
---@field currentAnimationState string|nil
---@field currentAnimation any
---@field menuScrollChildWindow ExtuiChildWindow
---@field contentScrollChildWindow ExtuiChildWindow
---@field mainLayoutTable ExtuiTable
---@field menuCell ExtuiTableCell
---@field contentCell ExtuiTableCell
---@field lastExpandedWidth number
DualPaneController = _Class:Create("DualPaneController", nil, {
    window = nil,
    leftPane = nil,
    rightPane = nil,
    isCollapsed = false,
    isHovered = false,
    userHasInteracted = false,
    hoverSubscription = nil,
    currentAnimation = nil,
    menuScrollChildWindow = nil,
    contentScrollChildWindow = nil,
    mainLayoutTable = nil,
    menuCell = nil,
    contentCell = nil,
    lastExpandedWidth = nil,
})
DualPaneController.__index = DualPaneController

-- Constants
ICON_TOGGLE_COLLAPSE = "panner_left_d"
ICON_TOGGLE_EXPAND = "ico_menu_h"
ICON_DOCS = "ico_secret_h"
ICON_DETACH = "ico_popup_d"

-- Get proportion of screen size based on working number for 4K
-- TODO: Generate dynamic expanded target when SE adds support for calculating text width
TARGET_WIDTH_EXPANDED = function()
    return MCM.Get("sidebar_width")
end
TARGET_WIDTH_COLLAPSED = 0
HOVER_DELAY_MS = 5000

--- @type HeaderActions|nil
HeaderActionsInstance = nil

local RX = {
    TimerScheduler = Ext.Require("Lib/reactivex/schedulers/timerscheduler.lua")
}

local function GetMenuColumnWidth()
    return MCM.Get("sidebar_width")
end

-- bg3_mcm build (2026-10-20, see FORK.md): the sidebar with the mod list is always shown. It never collapses or
-- fades, and nothing toggles it: no hover expansion, no automatic collapse, no start collapsed, no Caps Lock, button
-- or gamepad toggle. The settings enable_hover, enable_auto_collapse, collapsed_by_default,
-- toggle_mcm_sidebar_keybinding and animation_duration are gone from the blueprint; only sidebar_width stays.

function DualPaneController:InitWithWindow(window)
    local self = setmetatable({}, DualPaneController)
    self.window = window
    self:initLayout()
    self.leftPane = LeftPane:New(self.menuScrollChildWindow)
    self.rightPane = RightPane:New(self.contentScrollChildWindow)

    -- bg3_mcm build: the sidebar always starts shown.
    self.isCollapsed = false
    self.isHovered = false
    self.userHasInteracted = false
    self.hoverSubscription = nil
    self.currentAnimation = nil
    self.lastExpandedWidth = GetMenuColumnWidth()
    return self
end

function DualPaneController:initLayout()
    self.mainLayoutTable = self.window:AddTable("MainLayout", 2)
    self.mainLayoutTable:AddColumn("Menu", "WidthFixed", GetMenuColumnWidth())
    self.mainLayoutTable:AddColumn("Content", "WidthStretch")

    if self.mainLayoutTable.SetStyle then
        self.mainLayoutTable:SetStyle("CellPadding", 2)
    end
    local row = self.mainLayoutTable:AddRow()
    local menuCell = row:AddCell()
    local contentCell = row:AddCell()

    local contentWindow = contentCell:AddChildWindow("MainContentScrollChildWindow")

    HeaderActionsInstance = HeaderActions:New(contentWindow)

    self.menuScrollChildWindow = menuCell:AddChildWindow("MenuScrollChildWindow")
    -- Important to set as, by default, the style (alpha) would be unknown when calling GetStyle
    self.menuScrollChildWindow:SetStyle("Alpha", 1)
    self.contentScrollChildWindow = contentWindow:AddChildWindow("ContentScrollChildWindow")
end

function DualPaneController:NormalizeTabName(str)
    if not str or str == "" then
        return ""
    end

    return string.lower(str:gsub(" ", "_"))
end

local function isMatchingTab(modUUID, identifier, tab)
    local storedId = tab.UserData and tab.UserData.tabId or ""
    local normalizedIdentifier = DualPaneController:NormalizeTabName(identifier)
    local normalizedTabIdSuffix = storedId:sub(#modUUID + 2)
    local normalizedStoredName = DualPaneController:NormalizeTabName(tab.UserData and tab.UserData.tabName or "")

    return normalizedTabIdSuffix == normalizedIdentifier
        or normalizedStoredName == normalizedIdentifier
        or storedId:find(normalizedIdentifier)
end

function DualPaneController:GenerateTabId(modUUID, tabName)
    return modUUID .. "_" .. self:NormalizeTabName(tabName)
end

--- Shows the sidebar at its full width, without animation. bg3_mcm build: the sidebar is always shown, so this only
--- restores it (for example after a detach) and never takes the focus.
function DualPaneController:Expand()
    self.currentAnimation = nil
    self.isCollapsed = false
    self.menuScrollChildWindow.Visible = true
    self.menuScrollChildWindow:SetStyle("Alpha", 1)
    self.mainLayoutTable.ColumnDefs[1].Width = GetMenuColumnWidth()
end

--- bg3_mcm build: the sidebar never collapses; Collapse keeps it shown.
function DualPaneController:Collapse()
    self:Expand()
end

--- bg3_mcm build: the sidebar cannot be toggled; ToggleSidebar keeps it shown.
function DualPaneController:ToggleSidebar()
    self:Expand()
end

-- Tab management API; delegates to RightPane.
function DualPaneController:CreateModTab(modUUID, tabName)
    return self.rightPane:CreateTab(modUUID, tabName)
end

function DualPaneController:CreateTabWithDisclaimer(modUUID, tabName, disclaimerLocaKey)
    local tab = self:CreateModTab(modUUID, tabName)
    local disclaimerElement = nil

    if tab then
        local text = Ext.Loca.GetTranslatedString(disclaimerLocaKey)
        text = VCString:ReplaceBrWithNewlines(text)
        disclaimerElement = tab:AddText(text)
        disclaimerElement:SetColor("Text", Color.NormalizedRGBA(255, 165, 0, 1))
        disclaimerElement.TextWrapPos = 0
    end

    return tab, disclaimerElement
end

function DualPaneController:InsertModTab(modUUID, tabName, callback, skipDisclaimer)
    return self.rightPane:InsertTab(modUUID, tabName, callback, skipDisclaimer)
end

-- Helper to find tab by identifier in a mod's tab bar
---@param modUUID string The UUID of the mod to find the tab in
---@param tabIdentifier string|nil The identifier of the tab to find
---@return ExtuiTabItem|nil tab The tab, or nil if not found
local function isTablessSpecialPage(modUUID)
    return modUUID == ClientGlobals.MCM_HOTKEYS
        or modUUID == ClientGlobals.MCM_PROFILES
end

function DualPaneController:FindTab(modUUID, tabIdentifier)
    local modTabBar = self.rightPane:GetModTabBar(modUUID)
    if not modTabBar then
        if tabIdentifier and tabIdentifier ~= "" and not isTablessSpecialPage(modUUID) then
            MCMWarn(1, "Tab bar not found for mod " .. modUUID)
        end
        return nil
    end
    for _, tab in ipairs(modTabBar.Children) do
        if isMatchingTab(modUUID, tabIdentifier, tab) then
            MCMSuccess(1, "Found tab for mod " .. modUUID)
            ---@type ExtuiTabItem
            return tab
        end
    end
    return nil
end

-- Helper to activate a tab and open window if needed
---@param modUUID string The UUID of the mod to activate
---@param targetTab ExtuiTabItem The tab to activate
---@param shouldOpenWindow boolean|nil If true, opens the MCM window
function DualPaneController:ActivateTab(modUUID, targetTab, shouldOpenWindow)
    targetTab.SetSelected = true
    self.rightPane:FocusModContentChildWindow()
    ModEventManager:Emit(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, {
        modUUID = modUUID,
        tabName = targetTab.UserData.tabName
    }, true)
    if shouldOpenWindow ~= false then
        IMGUIAPI:OpenMCMWindow(true)
    end
end

-- Helper to handle sidebar expansion or collapse. bg3_mcm build: the sidebar is always shown, so opening a mod page
-- changes nothing here.
function DualPaneController:HandleSidebarStateChange(keepSidebarState)
end

-- Helper to avoid select lockdown by unselecting the tab after a few ticks
function DualPaneController:UnselectTabAfterDelay(targetTab)
    VCTimer:OnTicks(2, function()
        if not targetTab then return end
        targetTab.SetSelected = false
    end)
end

-- Open a specific mod page and optionally a tab
---@param modUUID string The UUID of the mod to open
---@param tabIdentifier string|nil The identifier of the tab to open
---@param shouldEmitEvent boolean|nil If true (default), will emit events; if false, won't emit events
---@param keepSidebarState boolean|nil If true, retains current sidebar state (expanded/collapsed)
---@param shouldOpenWindow boolean|nil If true, opens the MCM window
function DualPaneController:OpenModPage(modUUID, tabIdentifier, shouldEmitEvent, keepSidebarState, shouldOpenWindow)
    local targetTab = self:FindTab(modUUID, tabIdentifier)
    if targetTab then
        self:ActivateTab(modUUID, targetTab, shouldOpenWindow)
    elseif tabIdentifier then
        MCMWarn(2, "Tab not immediately found for mod " .. modUUID .. ": " .. tabIdentifier)
    end
    self:SetVisibleFrame(modUUID, shouldEmitEvent)

    self:HandleSidebarStateChange(keepSidebarState)
    self:UnselectTabAfterDelay(targetTab)
end

function DualPaneController:_getContentGroup(identifier)
    return self.rightPane and self.rightPane.contentGroups and self.rightPane.contentGroups[identifier] or nil
end

function DualPaneController:_findKeybindingsGroup(hotkeysGroup)
    if not hotkeysGroup or not hotkeysGroup.Children then return nil end
    for _, child in ipairs(hotkeysGroup.Children) do
        if child and child.IDContext == "MCM Keybindings" then
            return child
        end
    end

    for _, child in ipairs(hotkeysGroup.Children) do
        if child and child.Children then
            for _, sub in ipairs(child.Children) do
                if sub and sub.IDContext and string.find(sub.IDContext, "_CollapsingHeader", 1, true) then
                    return child
                end
            end
        end
    end
    return nil
end

function DualPaneController:_computeTargetHeaderId(modUUID)
    if not modUUID or not MCMClientState or not MCMClientState.GetModName then
        return nil, nil
    end
    local modName = MCMClientState:GetModName(modUUID)
    if modName and modName ~= "" then
        return modName .. "_CollapsingHeader", modName
    end
    return nil, modName
end

function DualPaneController:_toggleCollapsingHeaders(group, targetHeaderId, modName)
    if not group or not group.Children then return end
    for _, elem in ipairs(group.Children) do
        if elem and elem.IDContext and string.find(elem.IDContext, "_CollapsingHeader", 1, true) then
            MCMDebug(0, "Found collapsing header: " .. elem.IDContext)
            local isTarget = (targetHeaderId ~= nil) and (elem.IDContext == targetHeaderId)
            if isTarget and elem.Label == modName then
                elem.IDContext = modName .. "#" .. math.random(1, 1000)
            end
            elem.DefaultOpen = isTarget
            elem.Selected = isTarget
        end
    end
end

-- Open the Hotkeys page and focus the collapsing header for a given mod (if provided)
---@param modUUID string|nil Optional mod UUID to focus in the Hotkeys page; defaults to current mod
function DualPaneController:OpenKeybindingsPage(modUUID)
    -- Resolve target mod UUID
    if not modUUID and self.rightPane and self.rightPane.currentMod then
        modUUID = self.rightPane.currentMod.modUUID
    end

    if IMGUIAPI and IMGUIAPI.OpenMCMWindow then
        IMGUIAPI:OpenMCMWindow(true)
    end

    self:OpenModPage(ClientGlobals.MCM_HOTKEYS, nil, false, nil, true)

    -- Locate the Hotkeys content group and Keybindings group
    local hotkeysGroup = self:_getContentGroup(ClientGlobals.MCM_HOTKEYS)
    if not hotkeysGroup or not hotkeysGroup.Children then
        MCMDebug(0, "Hotkeys content group not found or has no children; cannot focus collapsing header.")
        return
    end

    local mcmBindingsGroup = self:_findKeybindingsGroup(hotkeysGroup)
    if not mcmBindingsGroup or not mcmBindingsGroup.Children then
        MCMDebug(0, "MCM Keybindings group not found or empty; cannot focus collapsing header.")
        return
    end

    -- Compute target header and toggle the appropriate collapsing header
    local targetHeaderId, modName = self:_computeTargetHeaderId(modUUID)
    if not targetHeaderId then
        return
    end
    self:_toggleCollapsingHeaders(mcmBindingsGroup, targetHeaderId, modName)

    -- Respect auto-collapse/expand preferences for the sidebar
    self:HandleSidebarStateChange(nil)
end

-- FIXME: Here or on Mod Uninstaller: not triggering tab callback for some reason even if event is emitted
-- Sets the visible frame for a mod UUID
---@param modUUID string The UUID of the mod to show
---@param shouldEmitEvent boolean|nil If true (default), will emit events; if false, won't emit events (prevents recursive loops)
function DualPaneController:SetVisibleFrame(modUUID, shouldEmitEvent)
    -- Set the visible group in the right pane
    self.leftPane:SetActiveItem(modUUID)
    self.rightPane:SetVisibleGroup(modUUID)

    -- Default to true if not specified
    if shouldEmitEvent == nil then shouldEmitEvent = true end

    if shouldEmitEvent and (not MCMProxy.IsMainMenu() or modUUID == ModuleUUID) then
        ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ACTIVATED, { modUUID = modUUID }, true)
    end

    self.rightPane:FocusModContentChildWindow()
end

-- Helper called from LeftPane buttons.
function DualPaneController:SwitchVisibleContent(button, uuid)
    self:SetVisibleFrame(uuid)
    self.leftPane:SetActiveItem(uuid)
end

function DualPaneController:DoesModPageExist(ID)
    local modTabBar = self.rightPane:GetModTabBar(ID)
    return modTabBar ~= nil
end

--- Add a new menu section with a separator and button
---@param sectionName string The name of the section to add
---@param pageName string The name of the page
---@param identifier string The unique identifier for this section
function DualPaneController:AddMenuSection(sectionName, pageName, identifier)
    self.leftPane:AddMenuSeparator(sectionName)
    self.leftPane:CreateMenuButton(pageName, nil, identifier)
end

--- Create a content group for a menu section
---@param identifier string The unique identifier for the content group
---@return any The created content group
function DualPaneController:CreateContentGroup(identifier)
    local contentGroup = self.contentScrollChildWindow:AddGroup(identifier)
    self.rightPane.contentGroups[identifier] = contentGroup
    return contentGroup
end

--- Add a new menu section with associated content group
---@param sectionName string The name of the section to add
---@param pageName string The name of the page
---@param identifier string The unique identifier for this section
---@return any The created content group
function DualPaneController:AddMenuSectionWithContent(sectionName, pageName, identifier)
    self:AddMenuSection(sectionName, pageName, identifier)
    return self:CreateContentGroup(identifier)
end
