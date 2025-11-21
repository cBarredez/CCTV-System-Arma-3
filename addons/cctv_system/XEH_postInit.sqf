/*
  CCTV - XEH_postInit.sqf
  - Initializes globals/whitelists and optional cTab integration (no hard deps).
  - Starts the local auto-toggle loop for helmet cams (item or helmet whitelist).
  - Adds cleanup on death/disconnect.
  - NOW: Only activates when CCTV Init module is placed in mission.
*/

////////////////////////////////////////////////////////////////////////////////
// Global state (replicated where needed)
////////////////////////////////////////////////////////////////////////////////

// System starts inactive - requires Init module to activate
missionNamespace setVariable ["CCTV_systemActive", false, true];

if (isNil { missionNamespace getVariable "CCTV_camRegistry" }) then {
  // Registry schema (HashMap):
  //  - Fixed cameras (world objects marked with CCTV_isCamera):
  //      key = BIS_fnc_netId of source object (string)
  //      value = [rtName (string), camObj (object), label (string)]
  //  - Helmet cameras (players/AI):
  //      key = "HELMET:<netId unit>" (string)
  //      value = [rtName (string), camObj (object), label (string), "helmet"]
  missionNamespace setVariable ["CCTV_camRegistry", createHashMap, true];
};

// Whitelists can be extended at runtime (mission/server scripts)
if (isNil { missionNamespace getVariable "CCTV_helmetCamItems" }) then {
  missionNamespace setVariable ["CCTV_helmetCamItems", [], true];
};
if (isNil { missionNamespace getVariable "CCTV_helmetCamHelmets" }) then {
  missionNamespace setVariable ["CCTV_helmetCamHelmets", [], true];
};

// Default visibility filter for cameras (you can filter in menus/monitors)
missionNamespace setVariable ["CCTV_helmetCamDefaultSide", "ANY", true];

// Auto-toggle ON by default (each client can toggle from ACE Self)
missionNamespace setVariable ["CCTV_autoToggleDefault", true];

// AI helmet camera support (disabled by default)
// Can be enabled via CBA settings: CCTV > Allow AI Helmet Cameras
if (isNil "CCTV_allowAIHelmetCameras") then {
  CCTV_allowAIHelmetCameras = false; // Default: disabled
};

// Optional cTab integration (soft-check only; no hard dependency)
systemChat "CCTV: Checking for cTab...";
if (isClass (configFile >> "CfgWeapons" >> "ItemcTabHCam")) then {
  systemChat "CCTV: cTab detected, adding integration...";
  private _items = missionNamespace getVariable ["CCTV_helmetCamItems", []];
  if (!("ItemcTabHCam" in _items)) then {
    _items pushBack "ItemcTabHCam";
    missionNamespace setVariable ["CCTV_helmetCamItems", _items, true];
  };
  
  // Also add cTab's helmet classes with built-in cameras
  private _helmets = missionNamespace getVariable ["CCTV_helmetCamHelmets", []];
  private _cTabHelmets = [
    "H_HelmetB_light",
    "H_Helmet_Kerry",
    "H_HelmetSpecB",
    "H_HelmetO_ocamo",
    "BWA3_OpsCore_Fleck_Camera",
    "BWA3_OpsCore_Schwarz_Camera",
    "BWA3_OpsCore_Tropen_Camera"
  ];
  
  // Check if cTab userconfig overrides exist
  if (!isNil "cTab_helmetClass_has_HCam") then {
    _cTabHelmets = cTab_helmetClass_has_HCam;
  };
  
  // Merge cTab helmets into CCTV whitelist (avoid duplicates)
  {
    if (!(_x in _helmets)) then {
      _helmets pushBack _x;
    };
  } forEach _cTabHelmets;
  
  missionNamespace setVariable ["CCTV_helmetCamHelmets", _helmets, true];
  systemChat format ["CCTV: Added %1 items, %2 helmets", count _items, count _helmets];
} else {
  systemChat "CCTV: cTab not detected";
};

////////////////////////////////////////////////////////////////////////////////
// Local (client) auto-toggle loop for helmet cam
////////////////////////////////////////////////////////////////////////////////
if (hasInterface) then {

  // Wait for system activation event
  ["CCTV_SystemActivated", {
    
    systemChat "CCTV: Client system activated";

    // Start state
    player setVariable [
      "CCTV_autoToggleEnabled",
      missionNamespace getVariable ["CCTV_autoToggleDefault", true]
    ];
    player setVariable ["CCTV_autoToggleNextCheck", 0];

    // PFH: every 0.5s evaluate auto-toggle using dedicated function
    [{
      // Only run if system is active
      if !(missionNamespace getVariable ["CCTV_systemActive", false]) exitWith {};
      [player] call CCTV_fnc_autoToggleTick;
    }, 0.5, []] call CBA_fnc_addPerFrameHandler;

    // Clean up on death
    ["CAManBase", "Killed", {
      params ["_unit"];
      if (local _unit && { _unit getVariable ["CCTV_helmetCamOn", false] }) then {
        [_unit] call CCTV_fnc_stopHelmetCam;
      };
    }] call CBA_fnc_addClassEventHandler;

    // Reset auto-toggle after respawn (will re-evaluate next tick)
    ["CAManBase", "Respawn", {
      params ["_unit"];
      if (local _unit) then {
        _unit setVariable [
          "CCTV_autoToggleEnabled",
          missionNamespace getVariable ["CCTV_autoToggleDefault", true]
        ];
        _unit setVariable ["CCTV_autoToggleNextCheck", 0];
      };
    }] call CBA_fnc_addClassEventHandler;
    
    // Initialize interaction menus
    [] spawn {
      uiSleep 0.5;
      [] call CCTV_fnc_setupInteraction;
    };
    
    // Start periodic vehicle turret camera detection (every 5 seconds)
    // DISABLED FOR NOW - needs further development
    /*
    [{
      // Only run if system is active
      if !(missionNamespace getVariable ["CCTV_systemActive", false]) exitWith {};
      [] call CCTV_fnc_addVehicleTurretCameras;
    }, 5, []] call CBA_fnc_addPerFrameHandler;
    */
  }] call CBA_fnc_addEventHandler;
};

////////////////////////////////////////////////////////////////////////////////
// Server cleanup on disconnect
////////////////////////////////////////////////////////////////////////////////
if (isServer) then {
  addMissionEventHandler ["HandleDisconnect", {
    params ["_unit", "_id", "_uid", "_name"];
    private _reg = missionNamespace getVariable ["CCTV_camRegistry", createHashMap];
    // Remove both fixed and helmet entries related to this unit (if any)
    private _keyH = format ["HELMET:%1", netId _unit];
    _reg deleteAt _keyH;
    missionNamespace setVariable ["CCTV_camRegistry", _reg, true];
    true
  }];
};
