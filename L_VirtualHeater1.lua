------------------------------------------------------------------------
-- Copyright (c) 2020-2021 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualHeater1", package.seeall)

local MYSID									= "urn:bochicchio-com:serviceId:VirtualHeater1"
local SWITCHSID								= "urn:upnp-org:serviceId:SwitchPower1"
local HVACSID								= "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
local HVACSTATESID							= "urn:micasaverde-com:serviceId:HVAC_OperatingState1"
local TEMPSETPOINTSID						= "urn:upnp-org:serviceId:TemperatureSetpoint1"
local TEMPSETPOINTSID_HEAT					= "urn:upnp-org:serviceId:TemperatureSetpoint1_Heat"
local TEMPSENSORSSID						= "urn:upnp-org:serviceId:TemperatureSensor1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"

local COMMANDS_SETPOWER						= "SetPowerURL"
local COMMANDS_SETPOWEROFF					= "SetPowerOffURL"

-- implementation

-- turn on/off compatibility
function actionPower(devNum, state)
	lib.D(devNum, "actionPower(%1,%2)", devNum, state)

	-- Switch on/off
	if type(state) == "string" then
		state = (tonumber(state) or 0) ~= 0
	elseif type(state) == "number" then
		state = state ~= 0
	end

	-- update variables
	lib.setVar(SWITCHSID, "Target", state and "1" or "0", devNum)
	lib.setVar(HVACSTATESID, "ModeState", state and "Heating" or "Idle", devNum)

	-- send command
	lib.sendDeviceCommand(MYSID, state and COMMANDS_SETPOWER or COMMANDS_SETPOWEROFF, state and "on" or "off", devNum, function()
		lib.setVar(SWITCHSID, "Status", state and "1" or "0", devNum)
		lib.setVar(HVACSID, "ModeStatus", state and "HeatOn" or "Off", devNum)
	end)
end

function updateSetpointAchieved(devNum)
	local tNow = os.time()
	local modeStatus, lastChanged = lib.getVar(HVACSID, "ModeStatus", "Off", devNum)
	local temp = lib.getVarNumeric(TEMPSENSORSSID, "CurrentTemperature", 18, devNum)
	local targetTemp = lib.getVarNumeric(TEMPSETPOINTSID_HEAT, "CurrentSetpoint", -1, devNum)
	
	lastChanged = lastChanged or tNow
	local achieved = (modeStatus == "HeatOn" and temp>targetTemp)

	lib.D(devNum, "updateSetpointAchieved(%1, %2, %3, %4, %5)", modeStatus, temp, targetTemp, achieved, lastChanged)

	-- TODO: implement cooldown, to prevent the device from being turned on/off too frequently
	-- TODO: implement differential temp, to prevent bouncing
	local bounceTimeoutSecs = 30 -- prevent bouncing -- TODO: make it a param
	if (tNow - lastChanged <= bounceTimeoutSecs) and targetTemp>-1 then
		lib.D(devNum, "updateSetpointAchieved: check for status: %1", (achieved and modeStatus ~= "Off"))

		lib.setVar(TEMPSETPOINTSID, "SetpointAchieved", achieved and "1" or "0", devNum)
		lib.setVar(TEMPSETPOINTSID_HEAT, "SetpointAchieved", achieved and "1" or "0", devNum)

		-- turn on if setpoint is not achieved
--		if not achieved and modeStatus == "Off" then -- not heating, start it
--			lib.L(devNum, "Turning on - achieved: %1 - status: %2", achieved == 1, modeStatus)
--			actionPower(devNum, 1)
--		end

		-- setpoint achieved, turn it off
		if achieved and modeStatus ~= "Off" then -- heating, stop it
			lib.L(devNum, "Turning off - achieved: %1 - status: %2", achieved, modeStatus)
			actionPower(devNum, 0)
		end
	else
		lib.D(devNum, "updateSetpointAchieved: bounced (%1, %2)", tNow - lastChanged, bounceTimeoutSecs)
	end
end

-- change setpoint
function actionSetCurrentSetpoint(devNum, newSetPoint)
	local modeStatus = lib.getVar(HVACSID, "ModeStatus", "Off", devNum)
	local modeState = lib.getVar(HVACSTATESID, "ModeState", "Off", devNum)

	lib.D(devNum, "actionSetCurrentSetpoint(%1,%2,%3,%4)", devNum, newSetPoint, modeStatus, modeState)

	if modeStatus == "Off" or modeState == "Idle" then
		-- on off/idle, just ignore?
		lib.D(devNum, "actionSetCurrentSetpoint: skipped")
	else
		-- just set variable, watch will do the real work
		lib.setVar(TEMPSETPOINTSID, "CurrentSetpoint", newSetPoint, devNum)
		lib.D(devNum, "actionSetCurrentSetpoint: set to %1", newSetPoint)
	end
end

-- set energy mode
function actionSetEnergyModeTarget(devNum, newMode)
	lib.D(devNum, "actionSetEnergyModeTarget(%1,%2)", devNum, newMode)

	lib.setVar(HVACSID, "EnergyModeTarget", newMode, devNum)
	lib.setVar(HVACSID, "EnergyModeStatus", newMode, devNum)
end

-- change mode target
function actionSetModeTarget(devNum, newMode)
	if (newMode or "") == "" then newMode = "Off" end
	lib.D(devNum, "actionSetModeTarget(%1,%2)", devNum, newMode)
	
	-- just set variable, watch will do the real work
	local updated = lib.setVar(HVACSID, "ModeTarget", newMode, devNum, true)

	-- race condition: target is set, status is not updated
	if not updated then
		actionPower(devNum, (newMode == "Off" and "0" or "1"))
	end

	return true
end

-- Toggle state
function actionToggleState(devNum) 
	lib.D(devNum, "actionToggleState(%1)", devNum)
	local status = lib.getVarNumeric(SWITCHSID, "Status", 0, devNum)
	actionPower(devNum, status == 1 and 0 or 1)
end

-- Watch callbacks
function virtualThermostatWatch(devNum, sid, var, oldVal, newVal)
	lib.D(devNum, "virtualThermostatWatch(%1,%2,%3,%4,%5)", devNum, sid, var, oldVal, newVal)
	local hasChanged = oldVal ~= newVal
	devNum = tonumber(devNum)

	if sid == HVACSID then
		if var == "ModeTarget" then
			if (newVal or "") == "" then newVal = "Off" end -- AltUI+Openluup bug
			-- no need to check is changed, because sometimes ModeTarget and ModeStatus are out of sync
			lib.actionPower(devNum, (newVal == "Off" and "0" or "1"))
		elseif var == "ModeStatus" then
			-- nothing to to do at the moment
		end
	elseif sid == TEMPSETPOINTSID then
		if (newVal or "") ~= "" and var == "CurrentSetpoint" and hasChanged then
			lib.setVar(TEMPSETPOINTSID_HEAT, "CurrentSetpoint", newVal, devNum) -- copy and keep it in sync
		end
	elseif sid == TEMPSETPOINTSID_HEAT then
		if (newVal or "") ~= "" and var == "CurrentSetpoint" and hasChanged then
			updateSetpointAchieved(devNum)
		end
	elseif sid == TEMPSENSORSSID then
		updateSetpointAchieved(devNum)
	end
end

function virtualThermostatWatchSync(devNum, sid, var, oldVal, newVal)
	lib.D(devNum, "virtualThermostatWatchSync(%1,%2,%3,%4,%5)", devNum, sid, var, oldVal, newVal)
	local hasChanged = oldVal ~= newVal
	devNum = tonumber(devNum)

	if sid == TEMPSENSORSSID then
		-- update thermostat temp from external temp sensor
		if (newVal or "") ~= "" and var == "CurrentTemperature" and hasChanged then
			lib.D(devNum, "Temperature sync: %1", newVal)

			local thermostatID = lib.getVarNumeric(MYSID, "ThermostatDeviceID", 0, devNum)
			if thermostatID > 0 then
				lib.setVar(TEMPSENSORSSID, "CurrentTemperature", newVal, thermostatID)
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
		lib.initVar(SWITCHSID, "Target", "0", deviceID)
		lib.initVar(SWITCHSID, "Status", "0", deviceID)

		-- heater init
		lib.initVar(HVACSID, "ModeStatus", "Off", deviceID)
		lib.initVar(TEMPSETPOINTSID, "CurrentSetpoint", "18", deviceID)
		lib.initVar(TEMPSETPOINTSID_HEAT, "CurrentSetpoint", "18", deviceID)
		lib.initVar(TEMPSENSORSSID, "CurrentTemperature", "18", deviceID)
		lib.initVar(MYSID, "TemperatureDevice", "0", deviceID)

		-- http calls init
		lib.initVar(MYSID, COMMANDS_SETPOWER, lib.DEFAULT_ENDPOINT, deviceID)
		lib.initVar(MYSID, COMMANDS_SETPOWEROFF, lib.DEFAULT_ENDPOINT, deviceID)

		-- set at first run, then make it configurable
		if luup.attr_get("category_num", deviceID) == nil then
			local category_num = 5
			luup.attr_set("category_num", category_num, deviceID) -- heater
		end

		-- set at first run, then make it configurable
		local subcategory_num = luup.attr_get("subcategory_num", deviceID) or 0
		if subcategory_num == 0 then
			luup.attr_set("subcategory_num", "2", deviceID) -- heater
		end

		-- watches
		luup.variable_watch("virtualThermostatWatch", HVACSID, "ModeTarget", deviceID)
		luup.variable_watch("virtualThermostatWatch", HVACSID, "ModeStatus", deviceID)
		luup.variable_watch("virtualThermostatWatch", TEMPSETPOINTSID, "CurrentSetpoint", deviceID)
		luup.variable_watch("virtualThermostatWatch", TEMPSETPOINTSID_HEAT, "CurrentSetpoint", deviceID)
		luup.variable_watch("virtualThermostatWatch", TEMPSENSORSSID, "CurrentTemperature", deviceID)

		-- external temp sensor
		local temperatureDeviceID = lib.getVarNumeric(MYSID, "TemperatureDevice", 0, deviceID)
		if temperatureDeviceID > 0 then
			local currentTemperature = lib.getVarNumeric(TEMPSENSORSSID, "CurrentTemperature", 0, temperatureDeviceID)
			lib.D(deviceID, "Temperature startup sync: %1 - #%2", currentTemperature, temperatureDeviceID)
			lib.setVar(TEMPSENSORSSID, "CurrentTemperature", currentTemperature, deviceID)
			lib.setVar(MYSID, "ThermostatDeviceID", deviceID, temperatureDeviceID) -- save thermostat ID in the temp sensor, to handle callbacks
			lib.setVar(MYSID, "ThermostatDevice", deviceID, nil) -- updgrade code

			luup.variable_watch("virtualThermostatWatchSync", TEMPSENSORSSID, "CurrentTemperature", temperatureDeviceID)
		end

		lib.setVar(HASID, "Configured", 1, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)

		-- status
		luup.set_failure(0, deviceID)
	end

	return true, "Ready", lib._PLUGIN_NAME
end