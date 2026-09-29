# 🎒 Server-Authoritative Inventory, Equipment & Anti-Dupe Suite

![Luau](https://img.shields.io/badge/Language-Luau-00A2FF?style=flat-square&logo=roblox)
![Rojo](https://img.shields.io/badge/Sync-Rojo%20v7-E04E39?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-Server--Authoritative-success?style=flat-square)
![Security](https://img.shields.io/badge/Integrity-Anti--Dupe%20Session--Locking-blueviolet?style=flat-square)
![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red?style=flat-square)

An enterprise-grade, modular **Inventory, Equipment, and Data Persistence Suite** for Roblox experiences built on **strict server-authoritative architecture** and **session-locking anti-duplication principles**.

> [!NOTE]
> ### ⚙️ Technical Focus & Portfolio Scope
> **Specialization: Server-Authoritative Systems, Security & Game Mechanics**  
> This suite is specifically engineered to demonstrate **pure backend Luau architecture**, atomic inventory state mutations, anti-duplication session-locking, and zero-client-trust network replication. The included user interface is a functional, programmatic testing harness created in code to demonstrate event routing, hotbar keybinds, and equipment state. In a production studio pipeline, this robust backend engine is designed to plug directly into any 2D UI artist's sprite sheets, Figma exports, or design systems with zero friction.

---

## ⚡ Key Highlights & Architecture

* **Zero Client Trust:** The client never commands data changes. All inventory modifications (moving, splitting, equipping, consuming, dropping) are submitted as discrete intent requests and strictly validated by the server before any mutation occurs.
* **Anti-Dupe Session-Locking:** Implements atomic session ownership locks preventing race-condition item duplications commonly caused by rapid disconnects, trade exploits, or concurrent remote spam.
* **Equipment & Stat Engine:** Equipping weapons or armor applies calibrated visual attachments to character limbs and grants real-time stat buffs (`WalkSpeed`, attack power, shield defense) that persist across character respawns.
* **Interactive 3D World Drops:** Dropping items removes them from inventory and spawns an animated bobbing/rotating 3D world model with rarity auras and distance-validated proximity collection.
* **Toggle Equip/Unequip:** Hotbar keys (1–5) and inventory slots feature instant toggle behavior (sheathe/draw) without removing items from slots.

---

## 📁 Repository Structure

```text
roblox-inventory-suite/
│
├── LICENSE                                    <-- Proprietary portfolio evaluation license
├── default.project.json                       <-- Rojo configuration mapping source tree to DataModel
├── Inventory_Demo_Place.rbxl                  <-- Pre-built, ready-to-run Roblox Studio place file
├── iniciar_rojo.bat                           <-- One-click Rojo server runner (port 34873)
│
└── src/
    ├── ReplicatedStorage/
    │   └── InventorySystem/
    │       ├── ItemDatabase.luau              <-- Authoritative catalog, rarity tiers, and item stats
    │       └── InventoryTypes.luau            <-- Strict Luau types for profiles, slots, and equipment
    │
    ├── ServerScriptService/
    │   └── InventorySystem/
    │       ├── InventoryServer.server.luau    <-- Master server orchestrator and remote routing
    │       ├── DataSessionManager.luau        <-- Session-locking, auto-saving, and mock store support
    │       ├── EquipmentService.luau          <-- Character visual attachments and stat modifiers
    │       ├── WorldDropService.luau          <-- Animated 3D physical world drops and collection
    │       └── WorldSetup.luau                <-- Auto-provisions cyber arena, spawn, and demo drops
    │
    └── StarterPlayer/
        └── StarterPlayerScripts/
            └── InventoryClient/
                └── InventoryController.client.luau <-- Cyber-glassmorphic HUD and hotbar controller
```

---

## 🛡️ Feature Matrix & Capabilities

| Subsystem | Feature | Technical Implementation |
| :--- | :--- | :--- |
| **Data Engine** | Anti-Dupe Protection | Atomic session-locking flag preventing concurrent state mutations |
| **Data Engine** | Persistence & Auto-Save | Cyclic auto-saving (60s) + atomic flush on `BindToClose` & disconnect |
| **Data Engine** | Studio Mock Fallback | Memory fallback in Studio to eliminate DataStore API rate limit throttling |
| **Inventory** | Slot Management | 24-slot grid with stack merging, overflow handling, and atomic swaps |
| **Inventory** | Stack Splitting | Validates source quantity, calculates delta, and populates first empty slot |
| **Equipment** | Visual Attachments | Neon/Forcefield welds attached to character limbs with PointLights |
| **Equipment** | Live Stat Modifiers | Modifies `Humanoid.WalkSpeed` and combat stats; persists upon respawn |
| **World Drops** | 3D Physical Drops | Procedural bobbing/rotation physics with rarity-colored BillboardGuis |
| **World Drops** | Secure Collection | Server verifies player distance ($< 14\text{ studs}$) and available capacity |
| **Controls** | Hotbar (1–5) | Bottom quick-action bar with keyboard bindings for instant use/equip |
| **Controls** | Quick Toggle | Press **[E]** or click HUD button to toggle main inventory window |

---

## 🚀 Setup & Testing (Choose One)

### Option A: Direct Place File (Fastest)
1. Double-click or open [`Inventory_Demo_Place.rbxl`](Inventory_Demo_Place.rbxl) directly in **Roblox Studio**.
2. Press **Play (F5)**. The arena, spawn point, HUD, and initial world drops will initialize automatically.
3. Walk over to the floating drops to collect them, or press **[E]** to inspect your inventory and equip items.

### Option B: Synchronization with Rojo
1. Open a blank **Baseplate** in Roblox Studio.
2. In this folder, run [`iniciar_rojo.bat`](iniciar_rojo.bat) (or `rojo serve default.project.json --port 34873`).
3. In Roblox Studio, open the **Rojo** plugin, enter port `34873`, and click **Connect**.
4. Press **Play (F5)**.

---

## 📜 License & Intellectual Property

**Author:** JV (`lab2` / `lab2SecurityProjectsR`)  
**Copyright:** © 2026 JV. All Rights Reserved.

This repository and its codebase are published strictly as a **technical portfolio showcase and professional evaluation sample** (including HiddenDevs skill accreditation and client review).

* 🚫 **No Unauthorized Redistribution:** Copying, mirroring, re-uploading, or claiming authorship of this codebase or its underlying algorithms is strictly prohibited.
* 🚫 **No Unlicensed Commercial Deployment:** Integration into commercial or public production games without explicit written permission from the author is not permitted.
* 💼 **Custom Commissions & Integration Services:** If you are a studio owner or developer seeking custom inventory, trading, or data architecture tailored to your game, contact the author via Discord (`narutodsfsdfsd`) or HiddenDevs.
