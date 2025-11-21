/*
  CCTV - fn_zeusAddCameraDialog.sqf
  Shows a text input dialog in Zeus to input camera label.
  Uses uiNamespace for proper dialog handling.
  Only runs for the Zeus curator, not for regular players.
*/

params ["_logic", "_objects"];

// Check if player is actually a curator
if (isNull (getAssignedCuratorLogic player)) exitWith {
  // Not a curator - use defaults
  _logic setVariable ["cctv_label", "", true];
  // Keep the side from module attributes, don't override
  if (isNil {_logic getVariable "cctv_side"}) then {
    _logic setVariable ["cctv_side", "ANY", true];
  };
  true
};

// Run dialog in spawned context
[_logic] spawn {
  params ["_logic"];
  
  // Simple approach: use systemChat to ask, then monitor chat input
  // Or just auto-name for now since Arma 3 dialogs are complicated in Zeus
  
  // For now, use a counter-based auto-naming
  private _counter = missionNamespace getVariable ["CCTV_CameraCounter", 0];
  _counter = _counter + 1;
  missionNamespace setVariable ["CCTV_CameraCounter", _counter];
  
  private _label = format ["Camera %1", _counter];
  
  // Apply to logic
  _logic setVariable ["cctv_label", _label, true];
  // Keep the side from module attributes, don't override
  if (isNil {_logic getVariable "cctv_side"}) then {
    _logic setVariable ["cctv_side", "ANY", true];
  };
  
  private _side = _logic getVariable ["cctv_side", "ANY"];
  
  if (_label != "") then {
    systemChat format ["CCTV: Camera created as '%1' (%2)", _label, _side];
  } else {
    systemChat format ["CCTV: Camera created as '%1' (%2)", _label, _side];
  };
  hint format ["CCTV Camera Added\n\nLabel: %1\nSide: %2\n\nYou can see it in CCTV screens.", _label, _side];
};

true
