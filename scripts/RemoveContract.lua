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

        if not found and contractsFrame.menuButtonInfo then
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

    -- Refresh the UI
    contractsFrame:updateList()

    return true
end

-- Hook into onFrameOpen
InGameMenuContractsFrame.onFrameOpen = Utils.appendedFunction(
    InGameMenuContractsFrame.onFrameOpen,
    RemoveContract.onFrameOpen
)

-- Hook into setButtonsForState to add our button to the list
InGameMenuContractsFrame.setButtonsForState = Utils.appendedFunction(
    InGameMenuContractsFrame.setButtonsForState,
    RemoveContract.setButtonsForState
)

RmLogging.logInfo("RemoveContract script loaded successfully")
