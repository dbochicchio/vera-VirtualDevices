------------------------------------------------------------------------
-- Copyright (c) 2019-2021 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualAlarmPartition1", package.seeall)

local MYSID									= "urn:bochicchio-com:serviceId:VirtualAlarmPartition1"
local SECURITYSID							= "urn:micasaverde-com:serviceId:SecuritySensor1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"
local ALARMSID								= "urn:micasaverde-com:serviceId:AlarmPartition2"
local ALTUISID								= "urn:upnp-org:serviceId:altui1"

local COMMANDS_ARM							= "SetRequestArmModeURL"
local COMMANDS_PANICMODE					= "SetRequestPanicModeURL"

-- implementation
local function setVerboseDisplay(devNum, line1, line2)
	if line1 then setVar(ALTUISID, "DisplayLine1", line1 or "", devNum) end
	if line2 then setVar(ALTUISID, "DisplayLine2", line2 or "", devNum) end
end

function actionRequestArmMode(devNum, state, pinCode)
	lib.D(devNum, "actionArmed(%1,%2,%3,%4)", devNum, state, pinCode, COMMANDS_ARM)

	-- send command
	lib.sendDeviceCommand(MYSID, COMMANDS_ARM, {state or "Disarmed", pinCode or ""}, devNum, function()
		local simpleState = state ~= "Disarmed" and "Armed" or "Disarmed"
		lib.setVar(ALARMSID, "ArmMode", simpleState, devNum)
		lib.setVar(ALARMSID, "DetailedArmMode", state, devNum)
	end)
end

function actionRequestPanicMode(devNum, state)
	lib.D(devNum, "actionTripped(%1,%2,%3)", devNum, state, state == "1" and COMMANDS_TRIPPED or COMMANDS_UNTRIPPED)

	-- send command
	lib.sendDeviceCommand(MYSID, COMMANDS_PANICMODE, state, devNum, function()
		--lib.setVar(ALARMSID, "ArmMode", state, devNum)
	end)
end

-- Watch callback
function sensorWatch(devNum, sid, var, oldVal, newVal)
	lib.D(devNum, "sensorWatch(%1,%2,%3,%4,%5)", devNum, sid, var, oldVal, newVal)

	if oldVal == newVal then return end

	if sid == ALARMSID then
		if var == "Alarm" and (newVal or false) == true then
			setVerboseDisplay(devNum, nil, 'Alarm: triggered')
		elseif var == "VendorStatus" or var == "LastUser" or var == "DetailedArmMode" then
			updateStatus(devNum)
		end
	end
end

function updateStatus(devNum)
	local vendorStatus = lib.getVar(ALARMSID, "VendorStatus", "", devNum)
	local lastUser = lib.getVar(ALARMSID, "LastUser", "", devNum)
	local state = lib.getVar(ALARMSID, "DetailedArmMode", "", devNum)
	local simpleState = state ~= "Disarmed" and "Armed" or "Disarmed"

	setVerboseDisplay(devNum, 
						string.format('Status: %s%s', simpleState, simpleState == "Disarmed" and "" or (" (" .. state .. ")")),
						string.format('%s - %s', vendorStatus, lastUser))
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
		lib.initVar(ALARMSID, "Alarm", "None", deviceID)
		lib.initVar(ALARMSID, "ArmMode", "Disarmed", deviceID)
		lib.initVar(ALARMSID, "DetailedArmMode", "Ready", deviceID)
		lib.initVar(ALARMSID, "LastAlarmActive", "0", deviceID)
		lib.initVar(ALARMSID, "VendorStatus", "Disarmed", deviceID)
		lib.initVar(ALARMSID, "VendorStatusCode", "", deviceID)
		lib.initVar(ALARMSID, "LastUser", "", deviceID)

		-- http calls init
		lib.initVar(MYSID, COMMANDS_ARM, lib.DEFAULT_ENDPOINT, deviceID)
		lib.initVar(MYSID, COMMANDS_PANICMODE, lib.DEFAULT_ENDPOINT, deviceID)

		-- set at first run, then make it configurable
		if luup.attr_get("category_num", deviceID) == nil then
			local category_num = 23
			luup.attr_set("category_num", category_num, deviceID) 
		end

		lib.setVar(HASID, "Configured", 1, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)

		-- watches
		luup.variable_watch("alarmSensorWatch", ALARMSID, "Alarm", deviceID)
		luup.variable_watch("alarmSensorWatch", ALARMSID, "LastUser", deviceID)
		luup.variable_watch("alarmSensorWatch", ALARMSID, "VendorStatus", deviceID)
		luup.variable_watch("alarmSensorWatch", ALARMSID, "DetailedArmMode", deviceID)

		-- status
		luup.set_failure(0, deviceID)

		lib.D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", lib._PLUGIN_NAME
end