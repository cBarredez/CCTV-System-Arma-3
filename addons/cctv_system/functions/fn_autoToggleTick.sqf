/*
  Per-tick logic for auto-toggle.
  Evaluates every 0.5s whether helmet cam should be on/off based on equipment.
*/
params ["_unit"];
if (isNull _unit) exitWith {};
if (!alive _unit) exitWith {};
if !(_unit getVariable ["CCTV_autoToggleEnabled", true]) exitWith {};

// Debounce check
private _now = diag_tickTime;
private _next = _unit getVariable ["CCTV_autoToggleNextCheck", 0];
if (_now < _next) exitWith {};
_unit setVariable ["CCTV_autoToggleNextCheck", _now + 0.5];

// Evaluate criteria
private _canUse = [_unit] call CCTV_fnc_isHelmetCamUser;
private _isOn   = _unit getVariable ["CCTV_helmetCamOn", false];

// Turn on / off as appropriate
if (_canUse && !_isOn) then { [_unit] call CCTV_fnc_startHelmetCam; };
if (!_canUse && _isOn)   then { [_unit] call CCTV_fnc_stopHelmetCam; };
