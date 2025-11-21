/*
  fn_initScreen.sqf
  - Marks all synchronized objects as CCTV screens (public variables).
  - Optional: start with black texture if module attribute CCTV_startOff = true.
  - Optional: propagate a label from the module to each screen (CCTV_label).
  - Safe selection detection (same heuristic as setup).
  - Triggers a global rebuild once CBA Events is available.

  Expected module init signature:
    params ["_logic", "_units", "_activated"];
*/

params ["_logic", "_units", "_activated"];
if (isNull _logic) exitWith {};
if (!local _logic) exitWith {};   // Run where the module logic is local (usually the server)

// Read module attributes
private _sideStr   = _logic getVariable ["CCTV_side", "ANY"];
private _startOff  = _logic getVariable ["CCTV_startOff", false];
private _labelMod  = _logic getVariable ["CCTV_label", ""];

// Gather synchronized objects
private _synced = synchronizedObjects _logic;

// Helper: best-guess screen selections by classname
private _fnc_guessScreenSelections = {
  params ["_obj"];
  private _class = typeOf _obj;

  // Tripod large screens: display is selection #0
  if (_class in [
    "Land_TripodScreen_01_large_black_F",
    "Land_TripodScreen_01_large_F",
    "Land_TripodScreen_01_large_sand_F"
  ]) exitWith { [0] };

  private _hs = [];
  private _cfg = configFile >> "CfgVehicles" >> _class;
  if (isClass _cfg) then { _hs = getArray (_cfg >> "hiddenSelections") };

  private _idxs = [];
  { if ((toLower _x) find "screen" >= 0) then { _idxs pushBack _forEachIndex; }; } forEach _hs;

  // Heuristic fallbacks
  if (_idxs isEqualTo [] && { count _hs > 1 }) then { _idxs = [0, (count _hs - 2)] };
  if (_idxs isEqualTo [] && { count _hs == 0 }) then { _idxs = [0, 1] };
  _idxs
};

// Mark and optionally pre-black the screens
{
  private _o = _x;
  if (!isNull _o && { _o != _logic }) then {
    // IMPORTANT: public = true to broadcast to all clients
    _o setVariable ["CCTV_isScreen", true, true];
    _o setVariable ["CCTV_side",     _sideStr, true];

    if (_labelMod != "") then {
      _o setVariable ["CCTV_label", _labelMod, true];
    };

    if (_startOff) then {
      private _selIdxs = [_o] call _fnc_guessScreenSelections;
      {
        _o setObjectTextureGlobal [_x, "#(argb,8,8,3)color(0,0,0,1)"];
      } forEach _selIdxs;
    };
  };
} forEach _synced;

// Trigger a global rebuild once CBA Events is up
[] spawn {
  waitUntil {
    isClass (configFile >> "CfgPatches" >> "cba_events")
    && {!isNil "CBA_fnc_globalEvent"}
    && {!isNil "cba_events_eventNamespace"}
  };
  ["CCTV_Rebuild", []] call CBA_fnc_globalEvent;
};
