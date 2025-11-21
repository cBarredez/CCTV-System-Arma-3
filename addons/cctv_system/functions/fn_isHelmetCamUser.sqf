/*
  Returns true if the unit "can" use helmet cam:
  - Has any whitelisted item (like ItemcTabHCam), OR
  - Wears a whitelisted helmet
*/
params ["_unit"];

private _itemsWL   = missionNamespace getVariable ["CCTV_helmetCamItems", []];
private _helmetsWL = missionNamespace getVariable ["CCTV_helmetCamHelmets", []];

// Check if has whitelisted item (like cTab helmet cam item)
private _hasItem   = count (_itemsWL arrayIntersect (items _unit)) > 0;

// Check if wearing whitelisted helmet
private _hg        = headgear _unit;
private _wearsHelmetCam = (_hg != "") && { _hg in _helmetsWL };

_hasItem || _wearsHelmetCam
