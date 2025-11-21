class CfgPatches {
  class cctv_system {
    name = "CCTV System";
    units[] = {"cctv_moduleInit","cctv_moduleScreen","cctv_moduleCamera","cctv_moduleAddCamera"};
    weapons[] = {};
    requiredVersion = 1.98;
    requiredAddons[] = {
      "A3_Modules_F",
      "cba_main",
      "cba_xeh",
      "cba_events",
      "ace_interact_menu"
    };
    author = "YourName";
    version = "2.0";
  };
};

class Extended_PostInit_EventHandlers {
  class cctv_system {
    init = "call compile preprocessFileLineNumbers '\cctv_system\XEH_postInit.sqf'";
  };
};

class CfgFunctions {
  class CCTV {
    tag = "CCTV";
    class main {
      file = "cctv_system\functions";
      class initSystem {};
      class initScreen {};
      class initCamera {};
      class addCameraToObject {};
      class zeusAddCameraDialog {};
      class setupInteraction {};
      // Helmet cam functions
      class isHelmetCamUser {};
      class startHelmetCam {};
      class stopHelmetCam {};
      class autoToggleTick {};
      // Vehicle turret cameras
      class addVehicleTurretCameras {};
    };
  };
};

class CfgFactionClasses {
  class NO_CATEGORY;
  class CCTV_Modules: NO_CATEGORY {
    displayName = "CCTV";
    priority = 2;
    side = 7;
  };
};

class CfgVehicles {
  class Logic;
  class Module_F: Logic {
    class AttributesBase;
    class ModuleDescription;
  };

  // ===================== INIT MODULE =====================
  class cctv_moduleInit: Module_F {
    scope = 2;
    displayName = "CCTV System Init";
    category = "CCTV_Modules";
    icon = "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\use_ca.paa";
    isGlobal = 1;
    isTriggerActivated = 0;
    curatorCanAttach = 0;

    class Attributes: AttributesBase {
      class CCTV_enabled {
        property = "CCTV_enabled";
        control = "Checkbox";
        displayName = "Enable CCTV System";
        tooltip = "Activates the CCTV system for this mission. Without this module, CCTV features are disabled.";
        typeName = "BOOL";
        defaultValue = "true";
        expression = "_this setVariable ['%s', _value, true];";
      };
      class CCTV_allowZeusPlacement {
        property = "CCTV_allowZeusPlacement";
        control = "Checkbox";
        displayName = "Allow Zeus Camera Placement";
        tooltip = "Allows Zeus to place cameras on objects during the mission.";
        typeName = "BOOL";
        defaultValue = "true";
        expression = "_this setVariable ['%s', _value, true];";
      };
    };

    class ModuleDescription: ModuleDescription {
      description = "Place this module to activate the CCTV system. Required for CCTV functionality.";
      sync[] = {};
    };

    class EventHandlers {
      init = "[_this select 0] spawn { params ['_logic']; waitUntil { !isNil 'CCTV_fnc_initSystem' }; [_logic] call CCTV_fnc_initSystem; };";
    };
  };

  // ===================== ADD CAMERA MODULE (Zeus) =====================
  class cctv_moduleAddCamera: Module_F {
    scope = 1;
    scopeCurator = 2;
    displayName = "Add CCTV Camera";
    category = "CCTV_Modules";
    icon = "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\search_ca.paa";
    isGlobal = 1;
    isTriggerActivated = 0;
    curatorCanAttach = 1;

    class Attributes: AttributesBase {
      class CCTV_side {
        property = "CCTV_side";
        control = "Combo";
        displayName = "Visible to Side";
        tooltip = "Who can see this camera in the ACE menu.";
        typeName = "STRING";
        defaultValue = "'ANY'";
        expression = "_this setVariable ['%s', _value, true];";
        class Values {
          class Any  {name = "Any";         value = "ANY";  default = 1;};
          class West {name = "BLUFOR";      value = "WEST";};
          class East {name = "OPFOR";       value = "EAST";};
          class Guer {name = "Independent"; value = "GUER";};
          class Civ  {name = "Civilian";    value = "CIV"; };
        };
      };
      class CCTV_label {
        property = "CCTV_label";
        control = "Edit";
        displayName = "Camera Label";
        tooltip = "Custom name shown in the ACE menu (leave empty to auto-name).";
        typeName = "STRING";
        defaultValue = "''";
        expression = "_this setVariable ['%s', _value, true];";
      };
    };

    class ModuleDescription: ModuleDescription {
      description = "Sync to an object to add it as a camera during the mission. Zeus only.";
      sync[] = {"AnyBrain","AllVehicles","Logic"};
    };

    class EventHandlers {
      init = "[_this select 0] spawn { params ['_logic']; waitUntil { !isNil 'CCTV_fnc_addCameraToObject' }; [_logic] call CCTV_fnc_addCameraToObject; };";
    };
  };

  // ===================== SCREEN MODULE =====================
  class cctv_moduleScreen: Module_F {
    scope = 2;
    displayName = "CCTV Screen";
    category = "CCTV_Modules";
    icon = "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\interact_ca.paa";
    isGlobal = 1;
    isTriggerActivated = 0;
    curatorCanAttach = 1;

    class Attributes: AttributesBase {
      class CCTV_side {
        property = "CCTV_side";
        control = "Combo";
        displayName = "Side";
        tooltip = "Who can use/see this screen in the ACE menu.";
        typeName = "STRING";
        defaultValue = "ANY";
        class Values {
          class Any  {name = "Any";         value = "ANY";  default = 1;};
          class West {name = "BLUFOR";      value = "WEST";};
          class East {name = "OPFOR";       value = "EAST";};
          class Guer {name = "Independent"; value = "GUER";};
          class Civ  {name = "Civilian";    value = "CIV"; };
        };
      };
      // Optional: start black
      class CCTV_startOff {
        property = "CCTV_startOff";
        control = "Checkbox";
        displayName = "Start Off (black)";
        tooltip   = "If enabled, the screen starts turned off (black).";
        typeName  = "BOOL";
        defaultValue = "false";
      };
    };

    class ModuleDescription: ModuleDescription {
      description = "Sync this module to one or more screen objects to enable the CCTV ACE menu.";
      sync[] = {"AnyBrain","AllVehicles","Logic"};
    };

    // ---- EVENT HANDLER: executes fn_initScreen when the module is created ----
    class EventHandlers {
      init = "[_this] spawn { params ['_args']; waitUntil { !isNil 'CCTV_fnc_initScreen' }; _args call CCTV_fnc_initScreen; };";
    };
  };

  // ===================== CAMERA MODULE =====================
  class cctv_moduleCamera: Module_F {
    scope = 2;
    displayName = "CCTV Camera";
    category = "CCTV_Modules";
    icon = "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\search_ca.paa";
    isGlobal = 1;
    isTriggerActivated = 0;
    curatorCanAttach = 1;

    class Attributes: AttributesBase {
      class CCTV_side {
        property = "CCTV_side";
        control = "Combo";
        displayName = "Side";
        tooltip = "Who can see this camera in the ACE menu.";
        typeName = "STRING";
        defaultValue = "'ANY'";
        expression = "_this setVariable ['%s', _value, true];";
        class Values {
          class Any  {name = "Any";         value = "ANY";  default = 1;};
          class West {name = "BLUFOR";      value = "WEST";};
          class East {name = "OPFOR";       value = "EAST";};
          class Guer {name = "Independent"; value = "GUER";};
          class Civ  {name = "Civilian";    value = "CIV"; };
        };
      };
      class CCTV_label {
        property = "CCTV_label";
        control = "Edit";
        displayName = "Label";
        tooltip = "Name shown in the ACE menu (leave empty to auto-name as 'Camera N').";
        typeName = "STRING";
        defaultValue = "''";
        expression = "_this setVariable ['%s', _value, true];";
      };
    };

    class ModuleDescription: ModuleDescription {
      description = "Sync to any object (logic/prop/etc.) to use it as a CCTV camera source.";
      sync[] = {"AnyBrain","AllVehicles","Logic"};
    };

    // ---- EVENT HANDLER: executes fn_initCamera when the module is created ----
    class EventHandlers {
      init = "[_this select 0] spawn { params ['_logic']; waitUntil { !isNil 'CCTV_fnc_initCamera' }; [_logic] call CCTV_fnc_initCamera; };";
    };
  };
};
