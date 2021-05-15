------------------------------------------------------------------------
-- Copyright (c) 2019-2021 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualDoorLock1", package.seeall)

local MYSID									= "urn:bochicchio-com:serviceId:VirtualDoorLock1"
local SECURITYSID							= "urn:micasaverde-com:serviceId:SecuritySensor1"
local SWITCHSID								= "urn:upnp-org:serviceId:SwitchPower1"
local LOCKSID								= "urn:micasaverde-com:serviceId:DoorLock1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"

local COMMANDS_LOCK							= "SetLockURL"
local COMMANDS_UNLOCK						= "SetUnLockURL"

-- implementation
function actionLock(devNum, state)
	state = tostring(state or "0")
	
	lib.D(devNum, "actionLock(%1,%2,%3)", devNum, state, state == "1" and COMMANDS_ARMED or COMMANDS_UNARMED)

	-- send command
	lib.sendDeviceCommand(MYSID, state == "1" and COMMANDS_LOCK or COMMANDS_UNLOCK, state, devNum, function()
		lib.setVar(LOCKSID, "Status", state, devNum)
		lib.setVar(SWITCHSID, "Status", state, devNum)
	end)
end

-- Toggle state
function actionToggleState(devNum)
	local status = lib.getVarNumeric(LOCKSID, "Status", 0, devNum)

	-- toggle by using the current status
	actionLock(devNum, status == 1 and 0 or 1)
end

-- Watch callback
function virtualDoorLockWatchSync(devNum, sid, var, oldVal, newVal)
	lib.D(devNum, "virtualDoorLockWatchSync(%1,%2,%3,%4,%5)", devNum, sid, var, oldVal, newVal)

	if oldVal == newVal then return end

	if sid == SECURITYSID then
		if var == "Tripped" then
			local masterID = lib.getVarNumeric(MYSID, "DoorLockDeviceID", 0, devNum)
			if masterID > 0 then
				local v = tostring(newVal or "0") == "0" and "1" or "0"
				lib.D(devNum, "virtualDoorLockWatchSync: #%1 - Master: #%2 - Status: %3", devNum, masterID, v)
				lib.setVar(LOCKSID, "Status", v, masterID)
				lib.setVar(SWITCHSID, "Status", v, masterID)
			end
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

		-- commands init
		lib.initVar(MYSID, COMMANDS_LOCK, lib.DEFAULT_ENDPOINT, deviceID)
		lib.initVar(MYSID, COMMANDS_UNLOCK, lib.DEFAULT_ENDPOINT, deviceID)

		-- set at first run, then make it configurable
		if luup.attr_get("category_num", deviceID) == nil then
			local category_num = 7
			luup.attr_set("category_num", category_num, deviceID)
		end

		-- watches
		-- external sensor
		local sensorDeviceID = tonumber((lib.initVar(MYSID, "SensorDeviceID", 0, deviceID)))
		if sensorDeviceID > 0 then
			local currentStatus = lib.getVarNumeric(SECURITYSID, "Tripped", 0, sensorDeviceID)
			lib.D(deviceID, "Sensor startup sync: %1 - #%2", currentStatus, sensorDeviceID)
			lib.setVar(LOCKSID, "Status", currentStatus == 0 and "1" or "0", deviceID)
			lib.setVar(MYSID, "DoorLockDeviceID", deviceID, sensorDeviceID) -- save door lock ID in the device sensor, to handle callbacks

			luup.variable_watch("virtualDoorLockWatchSync", SECURITYSID, "Tripped", sensorDeviceID)
		end
		-- status
		luup.set_failure(0, deviceID)
		lib.setVar(HASID, "Configured", 1, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)

		lib.D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", lib._PLUGIN_NAME
end