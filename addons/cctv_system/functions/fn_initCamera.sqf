/*
  Mark all synchronized objects as cameras.
  Sanitize the label: if it's not a string (or empty), keep "" and later the setup assigns "Camera N".
  NOTE: Eden module attributes are applied asynchronously, so we need to delay reading them.
*/
if (!isServer) exitWith {};

private _logic = if (_this isEqualType objNull) then {_this} else {_this param [0,objNull]};
if (isNull _logic) exitWith {};

// Wait a frame for Eden to apply module attributes to the logic object
uiSleep 0.05;

private _synced  = synchronizedObjects _logic;
private _sideStr = _logic getVariable ["cctv_side","ANY"];

// Read module label - stored as lowercase by Eden
private _labelRaw = _logic getVariable ["cctv_label", ""];

// For every synced object: mark as camera and set public vars
{
  if (!isNull _x) then {
    if (_x != _logic) then {
      _x setVariable ["CCTV_isCamera", true,  true];
      _x setVariable ["CCTV_side",     _sideStr, true];
      _x setVariable ["CCTV_label",    _labelRaw,   true];
    };
  };
} forEach _synced;

// Notify clients once CBA Events is ready
[] spawn {
  uiSleep 0.1;
  ["CCTV_Rebuild", []] call CBA_fnc_globalEvent;
};
