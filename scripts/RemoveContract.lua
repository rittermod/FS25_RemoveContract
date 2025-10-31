-- RemoveContract.lua
-- Author: Ritter
-- Description: Adds functionality to remove unwanted contracts from the contracts menu

-- Module declaration
RemoveContract = {}

-- Module constants
RemoveContract.LOG_PREFIX = "[RemoveContract]"
RemoveContract.STATE_AVAILABLE = 0

-- Initialize logging
RmLogging.setLogPrefix(RemoveContract.LOG_PREFIX)
-- RmLogging.setLogLevel(RmLogging.LOG_LEVEL.DEBUG)

---Initializes remove button info when contracts frame opens
---@param contractsFrame table The InGameMenuContractsFrame instance
function RemoveContract.onFrameOpen(contractsFrame)
    RmLogging.logDebug("Contracts frame opened")

    -- Validate frame parameter
    if not contractsFrame or type(contractsFrame) ~= "table" then
        RmLogging.logWarning("Invalid contractsFrame parameter in onFrameOpen")
        return
    end

    -- Create button info on the frame (like acceptButtonInfo/leaseButtonInfo)
    if not contractsFrame.removeButtonInfo then
        contractsFrame.removeButtonInfo = {
            inputAction = InputAction.REMOVE_CONTRACT,
            text = g_i18n:getText("button_removeContract") or "Remove Contract",
            callback = function()
                RmLogging.logDebug("Remove button callback triggered")
                contractsFrame:onButtonRemove()
            end
        }
        RmLogging.logDebug("Button info created on contracts frame")
    end
end

---Adds remove button to menu when viewing available contracts
---@param contractsFrame table The InGameMenuContractsFrame instance
---@param state number Contract state (0=available, 1=running, etc)
---@param canLease boolean Whether lease button should be shown (unused)
function RemoveContract.setButtonsForState(contractsFrame, state, canLease)
    -- canLease parameter unused but required by hook signature
    RmLogging.logTrace("setButtonsForState called - state: %s", tostring(state))

    -- Validate frame parameter
    if not contractsFrame or type(contractsFrame) ~= "table" then
        RmLogging.logTrace("Invalid contractsFrame parameter in setButtonsForState")
        return
    end

    -- Only add button for available contracts (state == 0)
    if state == RemoveContract.STATE_AVAILABLE and contractsFrame.removeButtonInfo then
        -- Check if already in list
        local found = false
        for _, info in ipairs(contractsFrame.menuButtonInfo or {}) do
            if info == contractsFrame.removeButtonInfo then
                found = true
                break
            end
        end

        if not found and contractsFrame.menuButtonInfo and type(contractsFrame.menuButtonInfo) == "table" then
            table.insert(contractsFrame.menuButtonInfo, contractsFrame.removeButtonInfo)
            contractsFrame:setMenuButtonInfoDirty()
            RmLogging.logTrace("Remove button added to menu button list")
        end
    end
end

---Handles remove button press event
function InGameMenuContractsFrame:onButtonRemove()
    RmLogging.logDebug("onButtonRemove called")
    RemoveContract.onRemoveButtonClick(self)
end

---Removes the currently selected contract from the mission manager
---@param contractsFrame table The InGameMenuContractsFrame instance
---@return boolean Success status of contract removal
function RemoveContract.onRemoveButtonClick(contractsFrame)
    RmLogging.logDebug("Remove button clicked")

    -- Validate frame parameter
    if not contractsFrame or type(contractsFrame) ~= "table" then
        RmLogging.logError("Invalid contractsFrame parameter in onRemoveButtonClick")
        return false
    end

    -- Validate frame methods exist
    if not contractsFrame.getSelectedContract then
        RmLogging.logError("contractsFrame.getSelectedContract method not available")
        return false
    end

    -- Use frame's built-in method to get selected contract (like onButtonDismiss does)
    local contract = contractsFrame:getSelectedContract()

    -- Validate contract and mission exist
    if not contract or not contract.mission then
        RmLogging.logWarning("No valid contract selected")
        return false
    end

    -- Check if contract is currently active
    if contract.mission.status == AbstractMission.STATUS_RUNNING then
        RmLogging.logWarning("Cannot remove active contract")
        return false
    end

    -- Log contract details
    local contractType = "unknown"
    local fieldId = "unknown"

    if contract.mission.type then
        contractType = tostring(contract.mission.type.name)
    end

    -- Get field ID from farmland property (Field objects store ID in farmland.name or farmland.id)
    if contract.mission.field and contract.mission.field.farmland then
        if contract.mission.field.farmland.name then
            fieldId = tostring(contract.mission.field.farmland.name)
        elseif contract.mission.field.farmland.id then
            fieldId = tostring(contract.mission.field.farmland.id)
        end
    end

    -- Fallback checks for alternative field storage locations
    if fieldId == "unknown" then
        if contract.mission.field and contract.mission.field.name then
            fieldId = tostring(contract.mission.field.name)
        elseif contract.mission.fieldId then
            fieldId = tostring(contract.mission.fieldId)
        elseif contract.field and contract.field.name then
            fieldId = tostring(contract.field.name)
        end
    end

    RmLogging.logInfo("Removing contract - Type: %s, Field: %s", contractType, fieldId)

    -- Validate mission manager exists before attempting deletion
    if not g_missionManager then
        RmLogging.logError("Mission manager not available - cannot remove contract")
        return false
    end

    -- Try FS25's safe deletion method first, fall back to direct deletion
    local success, result = pcall(function()
        if g_missionManager.markMissionForDeletion ~= nil then
            g_missionManager:markMissionForDeletion(contract.mission)
            return "marked"
        elseif g_missionManager.deleteMission ~= nil then
            g_missionManager:deleteMission(contract.mission)
            return "deleted"
        else
            error("No deletion method available")
        end
    end)

    if not success then
        RmLogging.logError("Failed to remove contract: %s", tostring(result))
        return false
    end

    -- Log successful removal
    if result == "marked" then
        RmLogging.logInfo("Contract marked for deletion")
    elseif result == "deleted" then
        RmLogging.logInfo("Contract deleted")
    end

    -- Refresh the UI (with validation)
    if contractsFrame.updateList then
        contractsFrame:updateList()
    else
        RmLogging.logWarning("contractsFrame.updateList method not available - UI may not refresh")
    end

    return true
end

---Validates that all required game dependencies are available
---@return boolean True if all dependencies are valid, false otherwise
local function validateDependencies()
    -- Check InGameMenuContractsFrame exists
    if not InGameMenuContractsFrame then
        RmLogging.logError("InGameMenuContractsFrame not available - cannot initialize mod")
        return false
    end

    -- Check Utils.appendedFunction exists
    if not Utils or not Utils.appendedFunction then
        RmLogging.logError("Utils.appendedFunction not available - cannot hook into game functions")
        return false
    end

    -- Check InputAction.REMOVE_CONTRACT exists
    if not InputAction or not InputAction.REMOVE_CONTRACT then
        RmLogging.logError("InputAction.REMOVE_CONTRACT not registered - check modDesc.xml configuration")
        return false
    end

    RmLogging.logDebug("All dependencies validated successfully")
    return true
end

---Sets up hooks into Giants Engine functions with error protection
---@return boolean True if hooks were successfully attached, false otherwise
local function setupHooks()
    local success, err = pcall(function()
        -- Hook into onFrameOpen to initialize button info
        InGameMenuContractsFrame.onFrameOpen = Utils.appendedFunction(
            InGameMenuContractsFrame.onFrameOpen,
            RemoveContract.onFrameOpen
        )

        -- Hook into setButtonsForState to add our button to the list
        InGameMenuContractsFrame.setButtonsForState = Utils.appendedFunction(
            InGameMenuContractsFrame.setButtonsForState,
            RemoveContract.setButtonsForState
        )
    end)

    if not success then
        RmLogging.logError("Failed to attach hooks: %s", tostring(err))
        return false
    end

    RmLogging.logDebug("Hooks attached successfully")
    return true
end

-- Validate dependencies before attempting initialization
if not validateDependencies() then
    RmLogging.logError("RemoveContract failed to load - missing dependencies")
    return
end

-- Set up hooks with error protection
if not setupHooks() then
    RmLogging.logError("RemoveContract failed to load - hook setup failed")
    return
end

RmLogging.logInfo("RemoveContract loaded successfully")
