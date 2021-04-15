------------------------------------------------------------------------
-- Copyright (c) 2020-2021 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualGenericSensor1", package.seeall)

local MYSID									= "urn:bochicchio-com:serviceId:VirtualGenericSensor1"
local SECURITYSID							= "urn:micasaverde-com:serviceId:SecuritySensor1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"

local COMMANDS_TRIPPED						= "SetTrippedURL"
local COMMANDS_UNTRIPPED					= "SetUnTrippedURL"
local COMMANDS_ARMED						= "SetArmedURL"
local COMMANDS_UNARMED						= "SetUnArmedURL"


-- implementation
function actionArmed(devNum, state)
	state = tostring(state or "0")
	
	lib.D(devNum, "actionArmed(%1,%2,%3)", devNum, state, state == "1" and COMMANDS_ARMED or COMMANDS_UNARMED)

	lib.setVar(SECURITYSID, "Armed", state, devNum)

	-- no need to update ArmedTripped, it will be automatic

	-- send command
	lib.sendDeviceCommand(MYSID, state == "1" and COMMANDS_ARMED or COMMANDS_UNARMED, state, devNum)
end

function actionTripped(devNum, state)
	-- no need to update LastTrip, it will be automatic
	state = tostring(state or "0")

	lib.D(devNum, "actionTripped(%1,%2,%3)", devNum, state, state == "1" and COMMANDS_TRIPPED or COMMANDS_UNTRIPPED)

	-- send command
	lib.sendDeviceCommand(MYSID, state == "1" and COMMANDS_TRIPPED or COMMANDS_UNTRIPPED, state, devNum)
end

-- Watch callback
function sensorWatch(devNum, sid, var, oldVal, newVal)
	lib.D(devNum, "sensorWatch(%1,%2,%3,%4,%5)", devNum, sid, var, oldVal, newVal)

	if oldVal == newVal then return end

	if sid == SECURITYSID then
		if var == "Tripped" then
			actionTripped(devNum, newVal or "0")
		end
	end
end

function startPlugin(devNum)
	lib = require("L_VirtualLibrary")
	lib.startup(devNum, MYSID)

	-- enumerate children
	local children = lib.getChildren(devNum)
	for k, deviceID in pairs(children) do
		lib.L(devNum, "Child #%1 - %2", deviceID, luup.devices[deviceID].description)

		-- generic init
		lib.initVar(MYSID, "DebugMode", 0, deviceID)

		-- sensors init
		lib.initVar(SECURITYSID, "Armed", "0", deviceID)
		lib.initVar(SECURITYSID, "Tripped", "0", deviceID)

		-- http calls init
		local commandTripped = lib.initVar(MYSID, COMMANDS_TRIPPED, lib.DEFAULT_ENDPOINT, deviceID)
		local commandArmed = lib.initVar(MYSID, COMMANDS_ARMED, lib.DEFAULT_ENDPOINT, deviceID)

		-- upgrade code
		lib.initVar(MYSID, COMMANDS_UNTRIPPED, commandTripped, deviceID)
		lib.initVar(MYSID, COMMANDS_UNARMED, commandArmed, deviceID)

		-- set at first run, then make it configurable
		if luup.attr_get("category_num", deviceID) == nil then
			local category_num = 4
			luup.attr_set("category_num", category_num, deviceID) -- security sensor
		end

		-- set at first run, then make it configurable
		local subcategory_num = luup.attr_get("subcategory_num", deviceID) or 0
		if subcategory_num == 0 then
			luup.attr_set("subcategory_num", "1", deviceID) -- door sensor
		end

		-- watches
		luup.variable_watch("sensorWatch", SECURITYSID, "Tripped", deviceID)
		--luup.variable_watch("sensorWatch", SECURITYSID, "Armed", deviceID)

		lib.setVar(HASID, "Configured", 1, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)

		-- status
		luup.set_failure(0, deviceID)

		lib.D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", lib._PLUGIN_NAME
end