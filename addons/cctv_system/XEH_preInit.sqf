/*
  CCTV - XEH_preInit.sqf
  CBA Settings initialization
*/

[
    "CCTV_allowAIHelmetCameras", // Internal setting name
    "CHECKBOX", // Setting type
    ["Allow AI Helmet Cameras", "Enable helmet cameras for AI units. When disabled, only players can use helmet cameras."], // [Display name, tooltip]
    "CCTV System", // Category
    false, // Default value (disabled)
    true, // isGlobal (synced across all clients)
    {} // Script to execute on change (optional)
] call CBA_fnc_addSetting;
