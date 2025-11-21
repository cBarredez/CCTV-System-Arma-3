/*
  CCTV_fnc_addVehicleTurretCameras
  
  Automatically detects vehicles with turrets (drones, planes, helis)
  that have crew (player or AI) and adds their turret cameras to the CCTV system.
  
  This function runs on all clients to create local cameras.
*/

// Debug: Show that function is running
systemChat format ["CCTV DEBUG: Turret scan running at %1", time];
diag_log format ["CCTV DEBUG: Turret scan running at %1", time];

// Get registry
private _reg = missionNamespace getVariable ["CCTV_camRegistry", createHashMap];

systemChat format ["CCTV DEBUG: Current registry size: %1", count _reg];
diag_log format ["CCTV DEBUG: Current registry size: %1", count _reg];

// Find all vehicles with turrets that have players
private _vehiclesWithTurrets = vehicles select {
  private _veh = _x;
  
  // Only helicopters, planes, and UAVs (no tanks)
  private _hasTurret = (
    _veh isKindOf "Helicopter" ||
    _veh isKindOf "Plane" ||
    _veh isKindOf "UAV"
  );
  
  // Must have crew (player OR AI)
  private _hasCrew = (count (crew _veh)) > 0;
  
  // Must have a gunner position occupied
  private _hasGunner = !isNull (gunner _veh);
  
  // Must belong to player's side or be civilian
  private _vehSide = side _veh;
  private _playerSide = side player;
  private _sideMatch = (
    _vehSide == _playerSide ||
    _vehSide == civilian ||
    _playerSide == civilian
  );
  
  _hasTurret && _hasCrew && _hasGunner && _sideMatch
};

systemChat format ["CCTV DEBUG: Found %1 vehicles with turrets", count _vehiclesWithTurrets];
diag_log format ["CCTV DEBUG: Found %1 vehicles with turrets", count _vehiclesWithTurrets];
{
  private _crew = crew _x;
  private _gunner = gunner _x;
  systemChat format ["CCTV DEBUG: - %1 (netId: %2, side: %3, crew count: %4, gunner: %5)", 
    typeOf _x, netId _x, side _x, count _crew, if (!isNull _gunner) then {name _gunner} else {"none"}];
  diag_log format ["CCTV DEBUG: - %1 (netId: %2, side: %3, crew count: %4, gunner: %5, is AI: %6)", 
    typeOf _x, netId _x, side _x, count _crew, 
    if (!isNull _gunner) then {name _gunner} else {"none"},
    if (!isNull _gunner) then {!isPlayer _gunner} else {false}];
} forEach _vehiclesWithTurrets;

// Process each vehicle
private _newCamerasAdded = false;
{
  private _veh = _x;
  private _vehId = netId _veh;
  
  // Check if already in registry
  private _keyTurret = format ["TURRET:%1", _vehId];
  
  systemChat format ["CCTV DEBUG: Checking vehicle %1 with key %2", typeOf _veh, _keyTurret];
  diag_log format ["CCTV DEBUG: Checking vehicle %1 with key %2", typeOf _veh, _keyTurret];
  
  if !(_reg getOrDefault [_keyTurret, []] isEqualTo []) then {
    // Already registered - check if camera still exists
    systemChat format ["CCTV DEBUG: %1 already registered", _keyTurret];
    diag_log format ["CCTV DEBUG: %1 already registered", _keyTurret];
    private _entry = _reg get _keyTurret;
    private _cam = _entry select 1;
    
    if (isNull _cam) then {
      // Camera was deleted, remove from registry and mark for re-add
      _reg deleteAt _keyTurret;
      _newCamerasAdded = true;
    };
  } else {
    // Not registered - add it
    systemChat format ["CCTV DEBUG: Adding new turret camera for %1", typeOf _veh];
    diag_log format ["CCTV DEBUG: Adding new turret camera for %1", typeOf _veh];
    
    private _vehName = getText (configOf _veh >> "displayName");
    if (_vehName == "") then {
      _vehName = typeOf _veh;
    };
    
    private _label = format ["%1 Turret", _vehName];
    
    // Determine side for camera
    private _vehSide = side _veh;
    private _sideStr = "ANY";
    switch (_vehSide) do {
      case west: { _sideStr = "WEST"; };
      case east: { _sideStr = "EAST"; };
      case resistance: { _sideStr = "GUER"; };
      case civilian: { _sideStr = "CIV"; };
    };
    
    // Get the gunner to access their optics view
    private _gunner = gunner _veh;
    if (isNull _gunner) then {
      // No gunner yet, skip this vehicle for now
      systemChat format ["CCTV DEBUG: %1 has no gunner, skipping", typeOf _veh];
      diag_log format ["CCTV DEBUG: %1 has no gunner, skipping", typeOf _veh];
      continue;
    };
    
    systemChat format ["CCTV DEBUG: Creating camera for %1, gunner: %2", _vehName, name _gunner];
    diag_log format ["CCTV DEBUG: Creating camera for %1, gunner: %2", _vehName, name _gunner];
    
    // Create render target name
    private _rtName = format ["CCTV_turret_%1", _vehId];
    _rtName remoteExec ["BIS_fnc_addRenderTarget", 2];
    
    // Create camera that will show the gunner's turret view
    private _cam = "camera" camCreate getPosATL _veh;
    _cam cameraEffect ["Internal", "Back", _rtName];
    _cam camSetFov 0.7;
    _cam camCommit 0;
    
    // Add to registry with side information BEFORE starting the loop
    _reg set [_keyTurret, [_rtName, _cam, _label, "turret", _vehId, _sideStr]];
    
    systemChat format ["CCTV: Added turret camera for %1 (%2)", _vehName, _sideStr];
    systemChat format ["CCTV DEBUG: Registry entry: key=%1, rtName=%2, label=%3", _keyTurret, _rtName, _label];
    diag_log format ["CCTV DEBUG: Registry entry: key=%1, rtName=%2, label=%3, side=%4", _keyTurret, _rtName, _label, _sideStr];
    
    // Mark that a new camera was added
    _newCamerasAdded = true;
    
    // Store the vehicle and start monitoring loop
    [_cam, _veh] spawn {
      params ["_cam", "_veh"];
      
      while {!isNull _cam && !isNull _veh} do {
        private _gunner = gunner _veh;
        
        if (!isNull _gunner) then {
          // Get gunner's turret direction
          private _turretDir = _veh weaponDirection (currentWeapon _gunner);
          
          // Position camera at gunner location
          private _gunnerPos = getPosASLVisual _gunner;
          _cam setPosASL _gunnerPos;
          
          if (!(_turretDir isEqualTo [0,0,0])) then {
            _cam setVectorDirAndUp [_turretDir, [0,0,1]];
          };
        };
        
        uiSleep 0.1;  // Update 10 times per second
      };
      
      // Cleanup when done
      if (!isNull _cam) then {
        deleteVehicle _cam;
      };
    };
  };
} forEach _vehiclesWithTurrets;

// Update registry
missionNamespace setVariable ["CCTV_camRegistry", _reg, true];

systemChat format ["CCTV DEBUG: Registry updated, new size: %1", count _reg];
diag_log format ["CCTV DEBUG: Registry updated, new size: %1", count _reg];

// Only trigger rebuild if we actually added NEW cameras
if (_newCamerasAdded) then {
  systemChat "CCTV DEBUG: New cameras added - triggering LOCAL rebuild...";
  diag_log "CCTV DEBUG: New cameras added - triggering LOCAL rebuild...";
  
  // Use local event to only rebuild for this player, not globally (prevents breaking Zeus for others)
  [] spawn {
    uiSleep 0.2;
    ["CCTV_Rebuild", []] call CBA_fnc_localEvent;
  };
} else {
  systemChat "CCTV DEBUG: No new cameras, skipping rebuild";
  diag_log "CCTV DEBUG: No new cameras, skipping rebuild";
};

// Clean up turret cameras for vehicles that no longer have players
private _keysToRemove = [];
{
  private _key = _x;
  private _entry = _y;
  
  // Check if this is a turret camera
  if (count _entry >= 5 && {(_entry select 3) isEqualTo "turret"}) then {
    private _vehId = _entry select 4;
    private _veh = objectFromNetId _vehId;
    
    // Remove if vehicle doesn't exist or has no crew
    if (isNull _veh || {(count (crew _veh)) == 0}) then {
      private _cam = _entry select 1;
      if (!isNull _cam) then {
        deleteVehicle _cam;
      };
      _keysToRemove pushBack _key;
      
      if (!isNull _veh) then {
        systemChat format ["CCTV: Removed turret camera from %1 (no crew)", getText (configOf _veh >> "displayName")];
      };
    };
  };
} forEach _reg;

// Remove dead entries
{
  _reg deleteAt _x;
} forEach _keysToRemove;

missionNamespace setVariable ["CCTV_camRegistry", _reg, true];
