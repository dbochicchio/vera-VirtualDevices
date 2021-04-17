------------------------------------------------------------------------
-- Copyright (c) 2020-2021 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualSceneController1", package.seeall)

local MYSID									= "urn:bochicchio-com:serviceId:VirtualSceneController1"
local SCENESID								= "urn:micasaverde-com:serviceId:SceneController1"
local SCENELEDSID							= "urn:micasaverde-com:serviceId:SceneControllerLED1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"

-- implementation
function startPlugin(devNum)
	lib = require("L_VirtualLibrary")
	lib.startup(devNum, MYSID)

	-- enumerate children
	local children = lib.getChildren(devNum)
	for k, deviceID in pairs(children) do
		lib.L(devNum, "Child #%1 - %2", deviceID, luup.devices[deviceID].description)

		-- generic init
		lib.initVar(MYSID, "DebugMode", 0, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)

		-- scene controller init
		lib.initVar(SCENESID, "NumButtons", "15,1-1-1=ui7_lang_tap_button 1,2-1-2=ui7_lang_double_tap_button 1,3-1-3=ui7_lang_triple_tap_button 1,4-1-4=ui7_lang_hold_button 1,5-1-5=ui7_lang_release_button 1,6-1-6=ui7_lang_tap_button 2,7-1-7=ui7_lang_double_tap_button 2,8-1-8=ui7_lang_triple_tap_button 2,9-1-9=ui7_lang_hold_button 2,10-1-10=ui7_lang_release_button 2,11-1-6=ui7_lang_tap_button 3,12-1-7=ui7_lang_double_tap_button 3,13-1-8=ui7_lang_triple_tap_button 3,14-1-9=ui7_lang_hold_button 3,15-1-10=ui7_lang_release_button 3", deviceID)
		lib.initVar(SCENESID, "ButtonMapping", "1-0-1,1-3-2,1-4-3,1-2-4,1-1-5,2-0-6,2-3-7,2-4-8,2-2-9,2-1-10,3-0-11,3-3-12,3-4-13,3-2-14,3-1-15", deviceID)

		-- set at first run, then make it configurable
		if luup.attr_get("category_num", deviceID) == nil then
			local category_num = 14
			luup.attr_set("category_num", category_num, deviceID) -- security sensor
		end

		-- watches
		luup.variable_watch("SCSensorWatch", SCENESID, "sl_SceneActivated", deviceID)
		--luup.variable_watch("SCSensorWatch", SECURITYSID, "Armed", deviceID)

		lib.initVar(SCENESID, "sl_SceneActivated", "0", deviceID)
		lib.initVar(SCENESID, "sl_SceneDeactivated", "0", deviceID)
		lib.initVar(SCENESID, "Scenes", "", deviceID)

		lib.setVar(HASID, "Configured", 1, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)
		
		-- status
		luup.set_failure(0, deviceID)

		lib.D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", lib._PLUGIN_NAME
end