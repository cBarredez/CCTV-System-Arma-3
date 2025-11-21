# 📡 CCTV System

This mod adds a fully functional CCTV system for Arma 3, using ACE Interaction and Eden Editor modules.
You can place cameras and screens in your mission and link them to create immersive surveillance systems.

---

## 🛠️ How to use

**1. Place modules in Eden**  
In the editor, go to the category **CCTV**.

You will find these modules:

- **CCTV Init** → Required. Place this module to enable and initialize the CCTV system in your mission. The system will not work without it.
- **CCTV Camera** → Attach to any object—including vehicles—to make it a camera.
- **CCTV Screen** → Attach to any object with screens to make it a monitor.

**2. Synchronization**  
Synchronize (F5 → Connect) the CCTV Camera module with the object you want to use as a camera (for example, a pole, wall, prop, or vehicle).  
Synchronize the CCTV Screen module with the object you want to act as a display (for example, tripod screens, laptops, or computers).  
You can synchronize multiple cameras and screens in the same mission.

**3. Zeus: Add Cameras Dynamically**  
While in Zeus, you can use the **CCTV Add Camera** module to place new cameras on objects—including vehicles—during gameplay.  
This module is only available in Zeus and will not appear in the Eden Editor.

**4. ACE Interaction**  
In-game, approach a synchronized screen.  
Use the ACE Interaction menu (default: Windows key).  
You will see a CCTV menu with all available cameras.  
Select the camera you want to display on that screen.  
You can also turn screens OFF from the same menu.

**5. Labels and Sides**  
Each camera module has an attribute **Label** → the name that will appear in the ACE menu (e.g., Entrance Camera, Control Tower).  
Both cameras and screens can be limited to a **Side** (BLUFOR, OPFOR, Independent, Civilian, or Any). Only players of that side will see the interaction menu.

---

## 🎥 Features

- Unlimited number of cameras and screens
- ACE interaction to switch feeds or turn off screens
- Eden module synchronization → no need to manually edit variables
- Side restriction for factions
- Works in SP and MP (all players see the same feed)
- Helmet Camera Support with cTab integration
- Auto-rebuild when exiting Zeus, ACE Arsenal, or cTab interfaces
- Manual "Sync TVs" ACE action for local-only refresh (prevents global interruptions in multiplayer/Zeus)
- Robust error handling and multiplayer safety

---

## 📦 Requirements

- CBA A3
- ACE3

---

## 🎖️ Optional Integration

- **cTab** – Enables helmet camera functionality with `ItemcTabHCam` item and compatible helmet classes

---

## ✍️ Author

Created by Hela-shi.  
Discord: helashi

---

## 🙏 Credits

- Helmet camera implementation based on cTab by Riouken
- Compatible with ACE3 and CBA frameworks

## 🚧 Planned Features

- Support for streaming turret cameras from drones, planes, and other vehicles directly to CCTV screens (future update)

---

## 🔧 Future Improvements & Considerations

**System Architecture (Deferred):**
1. Long-term: Replace rebuild system with event-driven incremental updates (planned, waiting)

**Pending Enhancements:**
- Further refine proximity system with dynamic radius adjustment
- Turret camera streaming for drones/planes/vehicles
