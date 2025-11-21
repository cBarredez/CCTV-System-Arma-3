/*
  Turns off the helmet cam and cleans up.
*/
params ["_unit"];
if (!local _unit) exitWith {};

private _cam = _unit getVariable ["CCTV_helmetCamCam", objNull];
private _target = _unit getVariable ["CCTV_helmetCamTarget", objNull];
private _rt  = _unit getVariable ["CCTV_helmetCamRT", ""];

if (!isNull _cam) then {
  _cam cameraEffect ["TERMINATE", "BACK"];
  camDestroy _cam;
};

if (!isNull _target) then {
  deleteVehicle _target;
};

_unit setVariable ["CCTV_helmetCamCam", objNull];
_unit setVariable ["CCTV_helmetCamTarget", objNull];
_unit setVariable ["CCTV_helmetCamRT",  ""];
_unit setVariable ["CCTV_helmetCamOn",  false, true];

private _reg = missionNamespace getVariable ["CCTV_camRegistry", createHashMap];
private _key = format ["HELMET:%1", netId _unit];
_reg deleteAt _key;
missionNamespace setVariable ["CCTV_camRegistry", _reg, true];

// Don't trigger rebuild - helmet cam removed from registry, screens will update on next manual rebuild
