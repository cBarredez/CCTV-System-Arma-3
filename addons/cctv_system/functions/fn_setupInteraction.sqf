/*
  CCTV_fnc_setupInteraction
  - Hooks once (Zeus enter/exit, CBA rebuild).
  - On leaving Zeus we clear the local registry and rebuild automatically.
  - Every rebuild recreates all PiP cams and rebuilds ACE menus.
  - Watchdog resurrects dead cams.
  - NOW: Only runs if CCTV system is activated via Init module.

  Important fixes:
  - When creating ACE actions, we now store (path + id) and when cleaning we remove using both.
    * Avoids the ACE error: "Undefined variable in expression: _fullPath" (SP).
  - 0.5s debounce to avoid duplicates if two rebuilds arrive back-to-back.

  Integrated additions:
  - [HCAM] Optional helmet cam support (cTab item or whitelisted helmets).
  - [HCAM] Helmet cams appear as selectable sources on screens.
  - [HCAM] ACE Self menu to toggle local helmet cam.
  - [HCAM] Ensure ACE interaction is enabled on screen objects (covers SimpleObjects).
*/

if (!hasInterface) exitWith {};

// Check if system is active
if !(missionNamespace getVariable ["CCTV_systemActive", false]) exitWith {};

// ========================= [HCAM] Local helpers & defaults =========================
// Defaults are set in XEH_postInit.sqf - no need to duplicate here
// ================================================================================

private _installHooks = isNil { missionNamespace getVariable "CCTV_uiHooksInit" };
if (_installHooks) then {
  missionNamespace setVariable ["CCTV_uiHooksInit", true];

  // --- ACE Arsenal close event ---
  if (isClass (configFile >> "CfgPatches" >> "ace_arsenal")) then {
    ["ace_arsenal_displayClosed", {
      // Don't rebuild if Zeus is still open (prevents breaking Zeus camera)
      private _zeusOpen = !isNull (findDisplay 312);
      if (!_zeusOpen) then {
        systemChat "CCTV: Arsenal closed - rebuilding locally...";
        [] spawn {
          uiSleep 0.1;
          ["CCTV_Rebuild", []] call CBA_fnc_localEvent;
        };
      } else {
        systemChat "CCTV: Arsenal closed in Zeus - skipping rebuild";
      };
    }] call CBA_fnc_addEventHandler;
  };

  // --- Detect Zeus interface enter/exit ---
  [] spawn {
    private _lastWasZeus = false;
    
    while {true} do {
      uiSleep 0.5;
      if (!isNull player) then {
        private _nowZeus = !isNull (findDisplay 312);
        
        if (_lastWasZeus && !_nowZeus) then {
          systemChat "CCTV: Exited Zeus - rebuilding locally...";
          [] spawn {
            uiSleep 0.2;
            ["CCTV_Rebuild", []] call CBA_fnc_localEvent;
          };
        };
        
        _lastWasZeus = _nowZeus;
      };
    };
  };
  
  // --- Detect cTab interface enter/exit ---
  [] spawn {
    private _lastWasCTab = false;
    
    while {true} do {
      uiSleep 0.5;
      if (!isNull player) then {
        // cTab uses display IDDs in the 1775000+ range
        private _nowCTab = false;
        {
          private _idd = ctrlIDD _x;
          if (_idd >= 1775000 && _idd < 1776000) then { 
            _nowCTab = true;
          };
        } forEach allDisplays;
        
        if (_lastWasCTab && !_nowCTab) then {
          systemChat "CCTV: Exited cTab - rebuilding locally...";
          [] spawn {
            uiSleep 0.2;
            ["CCTV_Rebuild", []] call CBA_fnc_localEvent;
          };
        };
        
        _lastWasCTab = _nowCTab;
      };
    };
  };
  
  // --- Extra: CBA player event (robust)
  if (isClass (configFile >> "CfgPatches" >> "cba_events")) then {
    ["unit", {
      // When player changes to a non-curator unit, rebuild locally
      if !(player isKindOf "VirtualCurator_F") then {
        [] spawn { uiSleep 0.2; [] call CCTV_fnc_setupInteraction; };
      };
    }] call CBA_fnc_addPlayerEventHandler;

    // --- Global rebuild event (preserves helmet cams, destroys only fixed cams)
    ["CCTV_Rebuild", {
      // Cleanup only FIXED cameras, preserve helmet cams
      private _oldReg = missionNamespace getVariable ["CCTV_camRegistry", createHashMap];
      {
        private _key = _x;
        private _entry = _y;
        // Only destroy fixed cameras (keys don't start with "HELMET:")
        if ((_key find "HELMET:") != 0) then {
          if (_entry isEqualType [] && {count _entry >= 2}) then {
            private _cam = _entry select 1;
            if (!isNull _cam) then {
              _cam cameraEffect ["Terminate", "BACK"];
              camDestroy _cam;
            };
          };
        };
      } forEach _oldReg;
      
      // Clear only fixed cameras from registry, keep helmet cams
      private _newReg = createHashMap;
      {
        private _key = _x;
        if ((_key find "HELMET:") == 0) then {
          _newReg set [_key, _y];
        };
      } forEach _oldReg;
      
      missionNamespace setVariable ["CCTV_camRegistry", _newReg];
      [] spawn { uiSleep 0.5; [] call CCTV_fnc_setupInteraction; };
    }] call CBA_fnc_addEventHandler;
  };
};

// --- Rebuild (always runs) ---
[] spawn {
  private _FOV   = 0.85;
  private _AHEAD = 6;

  // Local rebuild debounce (prevents duplicates if two events arrive back-to-back)
  private _last = missionNamespace getVariable ["CCTV_lastRebuildAt", -1000];
  if (time - _last < 0.5) exitWith {};
  missionNamespace setVariable ["CCTV_lastRebuildAt", time];

  // Readiness
  waitUntil { time > 0 && !isNull player };
  waitUntil {
    isClass (configFile >> "CfgPatches" >> "ace_interact_menu")
    && isClass (configFile >> "CfgPatches" >> "cba_events")
  };
  uiSleep 0.1;

  // Helpers
  private _fnc_sideMatches = {
    params ["_filterStr"];
    if (_filterStr isEqualTo "ANY") exitWith { true };
    private _map = createHashMapFromArray [
      ["WEST", west], ["EAST", east], ["GUER", independent], ["CIV", civilian]
    ];
    (side player) isEqualTo (_map getOrDefault [_filterStr, sideUnknown])
  };

  private _fnc_screenSelections = {
    params ["_pc"];
    private _class = typeOf _pc;

    // Tripod large screens: panel is selection #0
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
    if (_idxs isEqualTo [] && {count _hs > 1}) then { _idxs = [0, (count _hs - 2)] };
    if (_idxs isEqualTo [] && {count _hs == 0}) then { _idxs = [0,1] };
    _idxs
  };

  // --- Action cleanup: now uses (path + id) ---
  private _fnc_removeActions = {
    params ["_obj"];
    private _acts = _obj getVariable ["CCTV_actions", []];
    {
      // Each element: [_pathArray, _id]
      _x params ["_path", "_id"];
      // We use the signature with priority (0) to be 100% compatible
      [_obj, 0, _path, _id] call ace_interact_menu_fnc_removeActionFromObject;
    } forEach _acts;
    _obj setVariable ["CCTV_actions", []];
  };

  // --- Add action and register (path + id) ---
  private _fnc_addAndStore = {
    params ["_obj", "_path", "_action"];
    private _id = [_obj, 0, _path, _action] call ace_interact_menu_fnc_addActionToObject;
    private _acts = _obj getVariable ["CCTV_actions", []];
    _acts pushBack [_path, _id];
    _obj setVariable ["CCTV_actions", _acts];
  };

  // Collect marked objects (side-aware)
  private _screensAll = allMissionObjects "All" select { _x getVariable ["CCTV_isScreen",false] };
  private _camsAll    = allMissionObjects "All" select { _x getVariable ["CCTV_isCamera",false] };

  private _screens = _screensAll select { [_x getVariable ["CCTV_side","ANY"]] call _fnc_sideMatches };
  private _cams    = _camsAll    select { [_x getVariable ["CCTV_side","ANY"]] call _fnc_sideMatches };

  // Proximity filter: only process screens within 100m of player (performance optimization)
  private _nearScreens = _screens select { player distance _x < 100 };
  systemChat format ["CCTV: Processing %1 nearby screens (out of %2 total)", count _nearScreens, count _screens];

  // Store current state for future comparison
  private _curCamIds    = _cams apply { _x call BIS_fnc_netId };
  private _curScreenIds = _screens apply { _x call BIS_fnc_netId };
  
  missionNamespace setVariable ["CCTV_lastCamIds", _curCamIds];
  missionNamespace setVariable ["CCTV_lastScreenIds", _curScreenIds];
  missionNamespace setVariable ["CCTV_forceRebuild", false];


  // ===== CLEANUP: Remove old ACE actions from ALL screens (not just nearby) =====
  {
    [_x] call _fnc_removeActions;
    // Force ACE to clear its cache for this object
    _x setVariable ["ace_interact_menu_actions", nil];
    _x setVariable ["ace_interact_menu_actionParams", nil];
  } forEach _screensAll;

  // ===== Add ACE action: Sync TVs (local refresh) - nearby screens only =====
  {
    private _screen = _x;
    [_screen, 0, ["ACE_MainActions"], [
      "CCTV_SyncTVs", // 1: actionId
      "Sync TVs",     // 2: displayName
      "",             // 3: icon
      {
        systemChat "CCTV: Syncing/refreshing CCTV list (local only)...";
        ["CCTV_Rebuild", []] call CBA_fnc_localEvent;
      },              // 4: statement
      {true},         // 5: condition
      {},             // 6: insertChildren
      [],             // 7: modifier function args
      "",             // 8: selection
      5,              // 9: distance
      [false, false, false, false, false], // 10: showDisabled
      {}              // 11: custom data
    ]] call ace_interact_menu_fnc_addActionToObject;
  } forEach _nearScreens;

  // ===== CLEANUP: Destroy ONLY fixed cameras, preserve helmet cams =====
  private _reg = missionNamespace getVariable ["CCTV_camRegistry", createHashMap];
  
  // Destroy only fixed camera PiP cameras (not helmet cams)
  {
    private _key = _x;
    private _entry = _y;
    // Only destroy fixed cameras (keys don't start with "HELMET:")
    if ((_key find "HELMET:") != 0) then {
      if (_entry isEqualType [] && {count _entry >= 2}) then {
        private _rtName = _entry select 0;
        private _camObj = _entry select 1;
        
        if (!isNull _camObj) then {
          _camObj cameraEffect ["Terminate", "BACK", _rtName];
          detach _camObj;
          camDestroy _camObj;
        };
      };
    };
  } forEach _reg;
  
  // Keep helmet cams in registry, remove only fixed cams
  private _newReg = createHashMap;
  {
    private _key = _x;
    if ((_key find "HELMET:") == 0) then {
      _newReg set [_key, _y];
      // Re-activate helmet camera rendering after rebuild
      private _entry = _y;
      if (_entry isEqualType [] && {count _entry >= 2}) then {
        private _rtName = _entry select 0;
        private _camObj = _entry select 1;
        if (!isNull _camObj) then {
          _camObj cameraEffect ["INTERNAL", "BACK", _rtName];
        };
      };
    };
  } forEach _reg;
  
  _reg = _newReg;
  missionNamespace setVariable ["CCTV_camRegistry", _reg, true];
  
  // ===== Register/Recreate fixed cameras (fresh) =====
  private _camsInfo = [];
  private _camIndex = 0;

  {
    private _src = _x;
    private _id  = _src call BIS_fnc_netId;

    // Label or fallback
    private _lblRaw = _src getVariable ["CCTV_label", ""];
    private _label  =
      if (_lblRaw isEqualType "" && { _lblRaw != "" }) then { _lblRaw }
      else { _camIndex = _camIndex + 1; format ["Camera %1", _camIndex] };

    // Create fresh RT name
    private _rtName = format ["cctv_rt_%1", _id];

    // Fresh PiP cam
    private _cam = "camera" camCreate (getPosWorld _src);
    
    // Calculate attachment offset for vehicles (front edge) vs static objects (center)
    private _offset = [0,0,0];
    private _isVehicle = (_src isKindOf "AllVehicles" && !(_src isKindOf "CAManBase"));
    if (_isVehicle) then {
      // Get bounding box and position camera at front edge with slight height
      private _bbox = boundingBoxReal _src;
      private _frontY = (_bbox select 1) select 1; // Front Y coordinate
      _offset = [0, _frontY, 0.5]; // Add 0.5m height
    };
    
    _cam attachTo [_src, _offset];
    
    // Set direction AFTER attachment - direction is relative to parent vehicle
    // For vehicles: look straight ahead (no rotation needed, attachTo handles it)
    // For static objects: flip 180 degrees (front is back)
    if (_isVehicle) then {
      // Direction relative to vehicle: straight forward = [0,1,0] in model space
      _cam setVectorDirAndUp [[0,1,0], [0,0,1]];
    } else {
      // Static objects: use world direction but flip 180
      private _dir = vectorDirVisual _src;
      _dir = [-(_dir select 0), -(_dir select 1), (_dir select 2)];
      _cam setVectorDirAndUp [_dir, vectorUpVisual _src];
    };
    _cam camSetFov _FOV; _cam camCommit 0;
    _cam cameraEffect ["Internal","BACK", _rtName];

    _reg set [_id, [_rtName, _cam, _label]];
    _camsInfo pushBack [_rtName, _src, _label];

  } forEach _cams;

  // ======================= [HCAM] Append helmet cams as sources =======================
  private _helmetCount = 0;
  {
    private _k = _x;
    if ((_k find "HELMET:") == 0) then {
      private _entry = _reg get _k;
      if (_entry isEqualType [] && {count _entry >= 3}) then {
        private _rtH = _entry select 0;
        private _camObj = _entry select 1;
        private _lbl = _entry select 2;
        _camsInfo pushBack [_rtH, objNull, _lbl];
        _helmetCount = _helmetCount + 1;
      };
    };
  } forEach (keys _reg);
  // ===================================================================================

  missionNamespace setVariable ["CCTV_camRegistry", _reg];

  // ===== Build ACE menu per nearby screen =====
  {
    private _pc = _x;

    // [HCAM] Ensure ACE interaction is allowed on this object (covers SimpleObjects)
    _pc setVariable ["ace_interaction_enable", true, true];
    _pc setVariable ["ace_interaction_canInteractWithCondition", {true}, true];

    if !([_pc getVariable ["CCTV_side","ANY"]] call _fnc_sideMatches) then { continue };
    private _selIdxs = [_pc] call _fnc_screenSelections;
    if (_selIdxs isEqualTo []) then { continue };

    // Root
    private _rootId  = format ["cctv_root_%1", _pc call BIS_fnc_netId];
    private _actRoot = [_rootId, "CCTV", "", { }, { true }] call ace_interact_menu_fnc_createAction;
    [_pc, ["ACE_MainActions"], _actRoot] call _fnc_addAndStore;

    {
      private _sel = _x;

      // Node per selection
      private _scrId = format ["cctv_scr_%1_%2", _pc call BIS_fnc_netId, _sel];
      private _actNode = [_scrId, format ["Screen #%1", _sel], "", { }, { true }]
        call ace_interact_menu_fnc_createAction;
      [_pc, ["ACE_MainActions", _rootId], _actNode] call _fnc_addAndStore;

      // Turn off
      private _offId = format ["cctv_off_%1_%2", _pc call BIS_fnc_netId, _sel];
      private _actOff = [
        _offId, "Turn off", "",
        {
          _this params ["_target","_player","_param"];
          private _selIdx = if (_param isEqualType []) then { _param param [0,0] } else { _param };
          _target setObjectTextureGlobal [_selIdx, "#(argb,8,8,3)color(0,0,0,1)"];
        },
        { true }, {}, _sel
      ] call ace_interact_menu_fnc_createAction;
      [_pc, ["ACE_MainActions", _rootId, _scrId], _actOff] call _fnc_addAndStore;

      // Camera entries (fixed + helmet)
      if (_camsInfo isEqualTo []) then {
        private _noId = format ["cctv_none_%1_%2", _pc call BIS_fnc_netId, _sel];
        private _actNone = [_noId, "No cameras available", "", { }, { false }]
          call ace_interact_menu_fnc_createAction;
        [_pc, ["ACE_MainActions", _rootId, _scrId], _actNone] call _fnc_addAndStore;
      } else {
        {
          _x params ["_rtName", "_src", "_label"];
          private _id = format ["cctv_set_%1_%2_%3", _pc call BIS_fnc_netId, _sel, _rtName];

          private _actCam = [
            _id, _label, "",
            {
              _this params ["_target","_player","_param"];
              private _selIdx = _param param [0,0];
              private _rt     = _param param [1,""];
              if (_rt != "") then {
                _target setObjectTextureGlobal [_selIdx, format ["#(argb,512,512,1)r2t(%1,1)", _rt]];
              } else { hintSilent "CCTV: Invalid RT."; };
            },
            { true }, {}, [_sel, _rtName]
          ] call ace_interact_menu_fnc_createAction;

          [_pc, ["ACE_MainActions", _rootId, _scrId], _actCam] call _fnc_addAndStore;
        } forEach _camsInfo;
      };
      } forEach _selIdxs;

  } forEach _nearScreens;  // ===== [HCAM] ACE Self: simple toggle for local helmet cam =====
  private _showSelf = {
    ([player] call CCTV_fnc_isHelmetCamUser) || { player getVariable ["CCTV_helmetCamOn", false] }
  };

  if (isNil { player getVariable "CCTV_aceRootHelmetCamAdded" }) then {
    private _rootSelf = [
      "CCTV_HCAM_ROOT",
      "CCTV: Helmet Cam",
      "\A3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
      { true },
      { call _showSelf }
    ] call ace_interact_menu_fnc_createAction;
    [player, 1, ["ACE_SelfActions","ACE_Equipment"], _rootSelf] call ace_interact_menu_fnc_addActionToObject;

    private _toggleSelf = [
      "CCTV_HCAM_TOGGLE",
      { if (player getVariable ["CCTV_helmetCamOn", false]) then { "Turn Off Camera" } else { "Turn On Camera" } },
      "",
      {
        if (player getVariable ["CCTV_helmetCamOn", false]) then {
          [player] call CCTV_fnc_stopHelmetCam;
        } else {
          [player] call CCTV_fnc_startHelmetCam;
        };
      },
      { call _showSelf }
    ] call ace_interact_menu_fnc_createAction;
    [player, 1, ["ACE_SelfActions","ACE_Equipment","CCTV_HCAM_ROOT"], _toggleSelf] call ace_interact_menu_fnc_addActionToObject;

    player setVariable ["CCTV_aceRootHelmetCamAdded", true];
  };
  // =====================================================================

  // ===== Watchdog (create once) =====
  if (isNil "CCTV_watchdog") then {
    CCTV_watchdog = [] spawn {
      while {true} do {
        private _reg = missionNamespace getVariable ["CCTV_camRegistry", createHashMap];
        {
          private _id = _x;
          private _entry = _reg getOrDefault [_id, objNull];
          if (_entry isEqualType [] && {count _entry >= 2}) then {
            private _rtName = _entry select 0;
            private _cam    = _entry select 1;

            if (isNull _cam) then {
              // Recreate missing cam
              private _isHelmet = (count _entry >= 4) && { (_entry select 3) isEqualTo "helmet" };

              if (_isHelmet) then {
                // For helmet cams we try to locate the unit by netId suffix
                private _uid = _id select [7]; // strip "HELMET:" prefix
                private _unit = objNull;
                {
                  if (format ["%1", netId _x] isEqualTo _uid) exitWith { _unit = _x };
                } forEach allUnits;

                if (!isNull _unit) then {
                  // Recreate with cTab-compatible parameters
                  private _target = "Sign_Sphere10cm_F" createVehicleLocal position _unit;
                  hideObject _target;
                  _target attachTo [_unit, [0,8,1]];
                  
                  private _camNew = "camera" camCreate getPosATL _unit;
                  _camNew camPrepareFov 0.700;
                  _camNew camPrepareTarget _target;
                  _camNew camCommitPrepared 0;
                  _camNew attachTo [_unit, [0.12,0,0.15], "head"];
                  _camNew cameraEffect ["INTERNAL","BACK", _rtName];
                  
                  _reg set [_id, [_rtName, _camNew, (_entry select 2), "helmet", _target]];
                } else {
                  _reg deleteAt _id;
                };
              } else {
                // Fixed camera
                private _src = objectFromNetId _id;
                if (!isNull _src) then {
                  private _camNew = "camera" camCreate (getPosWorld _src);
                  
                  // Calculate attachment offset for vehicles (front edge) vs static objects (center)
                  private _offset = [0,0,0];
                  private _isVehicle = (_src isKindOf "AllVehicles" && !(_src isKindOf "CAManBase"));
                  if (_isVehicle) then {
                    // Get bounding box and position camera at front edge with slight height
                    private _bbox = boundingBoxReal _src;
                    private _frontY = (_bbox select 1) select 1; // Front Y coordinate
                    _offset = [0, _frontY, 0.5]; // Add 0.5m height
                  };
                  
                  _camNew attachTo [_src, _offset];
                  
                  // Set direction using relative coordinates for vehicles, world for static
                  if (_isVehicle) then {
                    // Direction relative to vehicle: straight forward in model space
                    _camNew setVectorDirAndUp [[0,1,0], [0,0,1]];
                  } else {
                    // Static objects: use world direction but flip 180
                    private _dir = vectorDirVisual _src;
                    _dir = [-(_dir select 0), -(_dir select 1), (_dir select 2)];
                    _camNew setVectorDirAndUp [_dir, vectorUpVisual _src];
                  };
                  _camNew camSetFov 0.85; _camNew camCommit 0;
                  _camNew cameraEffect ["Internal","BACK", _rtName];
                  _reg set [_id, [_rtName, _camNew, (_entry select 2)]];
                } else {
                  _reg deleteAt _id;
                };
              };
            } else {
              // Camera exists - update direction for all cameras (vehicles AND static objects)
              private _isHelmet = (count _entry >= 4) && { (_entry select 3) isEqualTo "helmet" };
              if (!_isHelmet) then {
                private _src = objectFromNetId _id;
                if (!isNull _src && !isNull _cam) then {
                  private _isVehicle = (_src isKindOf "AllVehicles" && !(_src isKindOf "CAManBase"));
                  
                  if (_isVehicle) then {
                    // For vehicles: use relative direction (straight forward in model space)
                    _cam setVectorDirAndUp [[0,1,0], [0,0,1]];
                  } else {
                    // For static objects: use world direction with 180 flip
                    private _dir = vectorDirVisual _src;
                    _dir = [-(_dir select 0), -(_dir select 1), (_dir select 2)];
                    _cam setVectorDirAndUp [_dir, vectorUpVisual _src];
                  };
                };
              };
            };
          };
        } forEach (keys _reg);
        missionNamespace setVariable ["CCTV_camRegistry", _reg, true];
        uiSleep 1;
      };
    };
  };
};
