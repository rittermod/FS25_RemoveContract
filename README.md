# FS25_RemoveContract

This single purpose mod adds a "Remove Contract" button to quickly clean up contracts you don't want to accept.

**Singleplayer only.**

## Notes
Since there is no proper documentation for modding FS25 yet, this mod is made by trial and error and looking at other mods. It may not work as expected and could potentially cause issues with your game.

Default key binding is `R` to remove the selected contract. You can change this in the game settings under "Controls".

Source code and issue tracker at https://github.com/rittermod/FS25_RemoveContract

## Features
- **Remove Contract Button**: Adds a "Remove Contract" button to the contracts menu interface
- **Keyboard Shortcut**: Press 'R' to quickly remove the selected contract (configurable)

## Installation
1. Download the latest release from the [GitHub releases page](https://github.com/rittermod/FS25_RemoveContract/releases/latest)
2. Move or copy the zip file into your Farming Simulator 2025 mods folder, typically located at:
   - Windows: `Documents/My Games/FarmingSimulator2025/mods`
   - macOS: `~/Library/Application Support/FarmingSimulator2025/mods`
3. Make sure you don't have any older versions of the mod installed in the mods folder

## Screenshots
Contracts menu showing the "Remove Contract" button with keyboard shortcut displayed.
![Remove Contract Button](screenshots/remove_contract.png)

## How It Works
The mod works by:
- Hooking into the `InGameMenuContractsFrame.onFrameOpen` event to create the remove button when the contracts menu opens
- Hooking into the `InGameMenuContractsFrame.setButtonsForState` event to add the button to the menu only when viewing available contracts
- Using the game's `markMissionForDeletion` or `deleteMission` methods to safely remove the selected contract
- Refreshing the contracts list UI after removal to reflect the changes
