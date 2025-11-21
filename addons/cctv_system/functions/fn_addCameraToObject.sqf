/*
  CCTV - fn_addCameraToObject.sqf
  Adds a camera to an object during mission runtime (Zeus-compatible).
  In Zeus: Place this module ON an object to make it a camera.
  In Eden: Sync this module to objects.
*/

params [["_logic", objNull], ["_units", []], ["_activated", true]];

systemChat format ["CCTV Add Camera: Logic=%1, Units=%2, Activated=%3", _logic, _units, _activated];
diag_log format ["CCTV Add Camera CALLED: Logic=%1, Units=%2, Activated=%3", _logic, _units, _activated];

if (!isServer) exitWith {
  systemChat "CCTV: Not server, exiting";
};
if (isNull _logic) exitWith {
  systemChat "CCTV: Logic is null, exiting";
};

// Check if system is active
if !(missionNamespace getVariable ["CCTV_systemActive", false]) exitWith {
  systemChat "CCTV: System not active. Place CCTV Init module first.";
  deleteVehicle _logic;
};

// Wait for attributes
uiSleep 0.05;

// Get objects to apply camera to
private _objects = [];

// Method 1: In Zeus, module is placed ON objects, they come in _units parameter
if (count _units > 0) then {
  _objects = _units;
  systemChat format ["CCTV: Using units parameter (%1 objects)", count _objects];
} else {
  // Method 2: Check synchronized objects (Eden)
  private _synced = synchronizedObjects _logic;
  if (count _synced > 0) then {
    _objects = _synced;
    systemChat format ["CCTV: Using synced objects (%1 objects)", count _objects];
  } else {
    // Method 3: In Zeus, get object at module position
    private _nearObjects = nearestObjects [getPos _logic, ["All"], 5];
    _nearObjects = _nearObjects select {_x != _logic && !(_x isKindOf "Logic")};
    if (count _nearObjects > 0) then {
      _objects = [_nearObjects select 0]; // Take the closest non-logic object
      systemChat format ["CCTV: Using nearest object: %1", typeOf (_objects select 0)];
    } else {
      systemChat "CCTV: ERROR - No object found! Place module directly ON an object in Zeus.";
      deleteVehicle _logic;
    };
  };
};

// If we found objects and this looks like a Zeus placement, show dialog
private _isZeusPlacement = (count _objects > 0) && (count synchronizedObjects _logic == 0);
if (_isZeusPlacement) then {
  // Dialog only for the curator who placed it
  private _curator = objNull;
  {
    if ((getAssignedCuratorUnit _x) isEqualTo player) exitWith {
      _curator = _x;
    };
  } forEach allCurators;
  
  if (!isNull _curator) then {
    // This client is the curator - show dialog
    [_logic, _objects] call CCTV_fnc_zeusAddCameraDialog;
    uiSleep 0.1;
  } else {
    // Not curator or on server - use defaults
    _logic setVariable ["cctv_label", "", true];
    _logic setVariable ["cctv_side", "ANY", true];
  };
};

private _sideStr = _logic getVariable ["cctv_side", "ANY"];
private _labelRaw = _logic getVariable ["cctv_label", ""];

systemChat format ["CCTV: Side=%1, Label='%2'", _sideStr, _labelRaw];

// Add camera to each object
{
  if (!isNull _x && {_x != _logic}) then {
    _x setVariable ["CCTV_isCamera", true, true];
    _x setVariable ["CCTV_side", _sideStr, true];
    _x setVariable ["CCTV_label", _labelRaw, true];
    
    private _objName = getText (configFile >> "CfgVehicles" >> typeOf _x >> "displayName");
    private _displayLabel = if (_labelRaw isEqualTo "") then {"(auto-named)"} else {format ["'%1'", _labelRaw]};
    systemChat format ["CCTV: Camera %1 added to %2 (%3)", _displayLabel, _objName, typeOf _x];
    diag_log format ["CCTV: Camera %1 added to %2 (%3)", _displayLabel, _objName, typeOf _x];
  };
} forEach _objects;

// Trigger rebuild on all clients
systemChat "CCTV: Triggering rebuild...";
[] spawn {
  uiSleep 0.1;
  ["CCTV_Rebuild", []] call CBA_fnc_globalEvent;
  uiSleep 0.5;
  systemChat "CCTV: Rebuild event sent - cameras should now be active";
};

// Delete the module after execution
deleteVehicle _logic;
