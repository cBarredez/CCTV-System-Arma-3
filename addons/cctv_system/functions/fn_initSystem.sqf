/*
  CCTV - fn_initSystem.sqf
  Called by the CCTV Init module to activate the system.
  Without this module, CCTV system remains dormant for performance.
*/

params [["_logic", objNull], ["_units", []], ["_activated", true]];

if (!isServer) exitWith {};
if (isNull _logic) exitWith {};

// Wait a frame for module attributes to be applied
uiSleep 0.05;

private _enabled = _logic getVariable ["cctv_enabled", true];
private _allowZeus = _logic getVariable ["cctv_allowzeusplacement", true];

if (!_enabled) exitWith {
  systemChat "CCTV: System disabled by Init module";
};

// Activate the system globally
missionNamespace setVariable ["CCTV_systemActive", true, true];
missionNamespace setVariable ["CCTV_allowZeusPlacement", _allowZeus, true];

systemChat "CCTV: System activated";

// Initialize on all clients
[] spawn {
  uiSleep 0.1;
  ["CCTV_SystemActivated", []] call CBA_fnc_globalEvent;
};
