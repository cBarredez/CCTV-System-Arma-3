/*
  Turns on the player's helmet cam.
*/
params ["_unit"];
if (!local _unit) exitWith {};

if (_unit getVariable ["CCTV_helmetCamOn", false]) exitWith {};

// Create camera and target object (cTab-compatible approach)
private _rtName = format ["CCTV_RT_HCAM_%1", getPlayerUID _unit];

// Create target sphere (hidden)
private _target = "Sign_Sphere10cm_F" createVehicleLocal position _unit;
hideObject _target;
_target attachTo [_unit, [0,8,1]];

// Create camera with cTab-compatible settings
private _cam = "camera" camCreate getPosATL _unit;
_cam camPrepareFov 0.700;
_cam camPrepareTarget _target;
_cam camCommitPrepared 0;
_cam attachTo [_unit, [0.12,0,0.15], "head"];
_cam cameraEffect ["INTERNAL", "BACK", _rtName];

_unit setVariable ["CCTV_helmetCamCam", _cam];
_unit setVariable ["CCTV_helmetCamTarget", _target];
_unit setVariable ["CCTV_helmetCamRT",  _rtName];
_unit setVariable ["CCTV_helmetCamOn",  true, true];

// Register in registry (array format to match fixed cameras)
private _reg = missionNamespace getVariable ["CCTV_camRegistry", createHashMap];
private _key = format ["HELMET:%1", netId _unit];
private _entry = [_rtName, _cam, format ["%1 (Helmet)", name _unit], "helmet", _target];
_reg set [_key, _entry];
missionNamespace setVariable ["CCTV_camRegistry", _reg, true];

// Don't trigger rebuild - helmet cam is already in registry and screens will pick it up on next manual rebuild
