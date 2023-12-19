------------------------------------------------------------------------
-- Copyright (c) 2019-2023 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualBinaryLight1", package.seeall)

local MYSID									= "urn:bochicchio-com:serviceId:VirtualBinaryLight1"
local SWITCHSID								= "urn:upnp-org:serviceId:SwitchPower1"
local DIMMERSID								= "urn:upnp-org:serviceId:Dimming1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"
local BLINDSID								= "urn:upnp-org:serviceId:WindowCovering1"
local ENERGYMETERSID						= "urn:micasaverde-com:serviceId:EnergyMetering1"

local COMMANDS_SETPOWER						= "SetPowerURL"
local COMMANDS_SETPOWEROFF					= "SetPowerOffURL"
local COMMANDS_SETBRIGHTNESS				= "SetBrightnessURL"
local COMMANDS_TOGGLE						= "SetToggleURL"
local COMMANDS_UPDATEMETERS					= "SetUpdateMetersURL"
local COMMANDS_MOVESTOP						= "SetMoveStopURL"

-- implementation
local function restoreBrightness(devNum)
	-- Restore brightness
	local brightness = lib.getVarNumeric(DIMMERSID, "LoadLevelLast", 0, devNum)
	local brightnessCurrent = lib.getVarNumeric(DIMMERSID, "LoadLevelStatus", 0, devNum)

	if brightness > 0 and brightnessCurrent ~= brightness then
		lib.setVar(DIMMERSID, "LoadLevelTarget", brightness, devNum)

		local newBrightness = lib.scaleDimming(devNum, brightness)
		lib.sendDeviceCommand(MYSID, COMMANDS_SETBRIGHTNESS, newBrightness, devNum, function()
			lib.setVar(DIMMERSID, "LoadLevelStatus", brightness, devNum)
		end)
	end
end

function actionPowerInternal(devNum, status, shouldRestoreBrightness)
	-- Switch on/off
	if type(status) == "string" then
		status = (tonumber(status) or 0) ~= 0
	elseif type(status) == "number" then
		status = status ~= 0
	end

	lib.D(devNum, "actionPowerInternal(%1,%2,%3)", devNum, status, shouldRestoreBrightness)

	lib.setVar(SWITCHSID, "Target", status and "1" or "0", devNum)

	-- get device type
	local deviceType = luup.attr_get("device_file", devNum)
	local isDimmer = deviceType == "D_DimmableLight1.xml" or deviceType == "D_VirtualDimmableLight1.xml" 
	local isBlind = deviceType == "D_WindowCovering1.xml" or deviceType == "D_VirtualWindowCovering1.xml"

	-- UI needs LoadLevelTarget/Status to conform with status according to Vera's rules.
	if not status then
		if isDimmer or isBlind then
			lib.setVar(DIMMERSID, "LoadLevelTarget", 0, devNum)
		end

		lib.sendDeviceCommand(MYSID, COMMANDS_SETPOWEROFF, "off", devNum, function()
			lib.setVar(SWITCHSID, "Status", "0", devNum)
			if isDimmer or isBlind then
				lib.setVar(DIMMERSID, "LoadLevelStatus", 0, devNum)
			end
		end)
	else
		lib.sendDeviceCommand(MYSID, COMMANDS_SETPOWER, "on", devNum, function()
			lib.setVar(SWITCHSID, "Status", "1", devNum)
			
			-- restore brightness
			if shouldRestoreBrightness and isDimmer and not isBlind then
				restoreBrightness(devNum)
			end

			-- autooff
			local autoOff = lib.getVarNumeric(MYSID, "AutoOff", 0, devNum)
			lib.D(devNum, "Auto off in %1 secs", autoOff)

			if autoOff>0 then
				luup.call_delay("actionAutoOff", autoOff, devNum)
			end
		end)
	end
end

function actionAutoOff(devNum)
	lib.D(devNum, "Auto off called")
	actionPower(tonumber(devNum), 0)
end

function actionPower(devNum, status)
	lib.D(devNum, "actionPower(%1,%2)", devNum, status)

	actionPowerInternal(devNum, status, true)
end

function actionBrightness(devNum, newVal)
	lib.D(devNum, "actionBrightness(%1,%2)", devNum, newVal)

	-- dimmer or not?
	local deviceType = luup.attr_get("device_file", devNum)
	local isDimmer = deviceType == "D_DimmableLight1.xml" or deviceType == "D_VirtualDimmableLight1.xml" 
	local isBlind = deviceType == "D_WindowCovering1.xml" or deviceType == "D_VirtualWindowCovering1.xml"
	local isBlindNoPosition = isBlind and lib.getVarNumeric(MYSID, "BlindAsSwitch", 0, devNum) == 1

	-- Dimming level change
	newVal = math.floor(tonumber(newVal or 100))
	
	if newVal < 0 then
		newVal = 0
	elseif newVal > 100 then
		newVal = 100
	end -- range

	-- support for blind mapped as on/off only
	if isBlindNoPosition then
		local newPosition = newVal<=50 and 0 or 100
		lib.D(devNum, "New Position: %1 - original %2", newPosition, newVal)

		lib.setVar(DIMMERSID, "LoadLevelStatus", newPosition, devNum)
		lib.setVar(DIMMERSID, "LoadLevelTarget", newPosition, devNum)
		actionPowerInternal(devNum, newPosition == 0 and 0 or 1, false)
	else
		-- normal dimmer or blind
		lib.setVar(DIMMERSID, "LoadLevelTarget", newVal, devNum)

		if newVal > 0 then
			-- Level > 0, if light is off, turn it on.
			if isDimmer then
				local status = lib.getVarNumeric(SWITCHSID, "Status", 0, devNum)
				if status == 0 then
					actionPowerInternal(devNum, 1, false)
				end
			end

			local newBrightness = lib.scaleDimming(devNum, newVal)
			lib.sendDeviceCommand(MYSID, COMMANDS_SETBRIGHTNESS, newBrightness, devNum, function()
				lib.setVar(DIMMERSID, "LoadLevelStatus", newVal, devNum)
			end)
		elseif newVal == 0 and lib.getVarNumeric(DIMMERSID, "AllowZeroLevel", 0, devNum) ~= 0 then
			-- Level 0 allowed as on status, just go with it.
			lib.sendDeviceCommand(MYSID, COMMANDS_SETBRIGHTNESS, newVal, devNum, function()
				lib.setVar(DIMMERSID, "LoadLevelStatus", newVal, devNum)
			end)
		else
			-- Level 0 (not allowed as an "on" status), switch light off.
			actionPowerInternal(devNum, 0, false)
		end
	end

	if newVal > 0 then lib.setVar(DIMMERSID, "LoadLevelLast", newVal, devNum) end
end

-- Toggle state
function actionToggleState(devNum)
	local cmdUrl = lib.getVar(MYSID, COMMANDS_TOGGLE, lib.DEFAULT_ENDPOINT, devNum)

	local status = lib.getVarNumeric(SWITCHSID, "Status", 0, devNum)

	if (cmdUrl == lib.DEFAULT_ENDPOINT or cmdUrl == "") then
		-- toggle by using the current status
		actionPower(devNum, status == 1 and 0 or 1)
	else
		-- update variables
		lib.setVar(SWITCHSID, "Target", status == 1 and 0 or 1, devNum)

		-- toggle command specifically defined
		lib.sendDeviceCommand(MYSID, COMMANDS_TOGGLE, nil, devNum, function()
			lib.setVar(SWITCHSID, "Status", status == 1 and 0 or 1, devNum)		
		end)
	end
end

-- stop for blinds
function actionStop(devNum) 
	lib.D(devNum, "actionStop(%1)", devNum)
	lib.sendDeviceCommand(MYSID, COMMANDS_MOVESTOP, nil, devNum) 
end

-- meters support
function updateMeters(devNum)
	function getValue(data, path)
		lib.D(devNum, "updateMeters.getValue(%1)", path)
		local x = data or ""
		for field in path: gmatch "[^%.%[%]]+" do
			if x ~= nil and field ~= nil then
				x = x[tonumber(field) or field]
			end
		end
		return x or ""
	end

	devNum = tonumber(devNum)

	local meterUpdate = lib.getVarNumeric(MYSID, "MeterUpdate", 0, devNum)

	if meterUpdate == 0 then
		lib.L(devNum, "updateMeters: disabled")
		return
	end

	local status = lib.getVar(SWITCHSID, "Status", "0", devNum)
	local wattsPath = lib.getVar(MYSID, "MeterPowerFormat", "", devNum)
	local kwhPath = lib.getVar(MYSID, "MeterTotalFormat", "", devNum)
	local format = lib.getVarNumeric(MYSID, "MeterTotalUnit", 0, devNum) -- 0 KWH, 1 Wmin, 2 WH

	local url = lib.getVar(MYSID, COMMANDS_UPDATEMETERS, lib.DEFAULT_ENDPOINT, devNum)

	lib.D(devNum, "updateMeters(%1)", url)

	if cmdUrl ~= lib.DEFAULT_ENDPOINT or (cmdUrl or "" ~= "") then
		lib.httpGet(devNum, url, function(response)
			lib.D(devNum, "updateMeters: %1", response)

			local json = require "dkjson"
			local data = json.decode(response)

			if kwhPath ~= "" then
				local value = tonumber(getValue(data, kwhPath))
				local transformedValue = value

				-- EXPERIMENTAL!
				if format == 1 then -- Wmin
					-- special case for shellies - if value < stored value, then add value, otherwise compute delta
					local oldValue = lib.getVarNumeric(MYSID, "KWMin", 0, devNum)
					lib.setVar(MYSID, "KWMin", value, devNum)

					transformedValue = lib.round(lib.round(value / 60, 4) / 1000, 4) -- from Wmin to KWH
					local storedValue = lib.getVarNumeric(ENERGYMETERSID, "KWH", 0, devNum)
					local delta = 0

					--if status == "0" then -- ignore reported consumption when turned off
					--	lib.D(devNum, "[D] Switch is OFF")	
					--	delta = 0
					--	transformedValue = storedValue
					--else
					if value > oldValue then
						delta = transformedValue - storedValue
					elseif value < oldValue then
						delta = storedValue
					end

					transformedValue = lib.round(transformedValue + delta, 2) -- round to 2

					lib.D(devNum, "[updateMeters] Format %1 - Delta %2 - Original %3", format, delta, storedValue)
				elseif format == 2 then -- WH
					transformedValue = lib.round(value / 60, 2) -- from WH to KWH
				end
				
				lib.L(devNum, "[updateMeters] KWH - Path %1 - Raw Value: %2 - Transformed Value: %3", kwhPath, value, transformedValue)
				lib.setVar(ENERGYMETERSID, "KWH", lib.round(transformedValue, 4), devNum)
			end

			if wattsPath ~= "" then
				local value = tonumber(getValue(data, wattsPath))
				lib.L(devNum, "[updateMeters] Watts - Path: %1 - Value: %2", wattsPath, value)
				lib.setVar(ENERGYMETERSID, "Watts", value, devNum)
			end
		end)
	end

	lib.L(devNum, "updateMeters: next call in %1 secs", meterUpdate)
	luup.call_delay("updateMeters", meterUpdate, devNum)
end

function startPlugin(devNum)
	lib = require("L_VirtualLibrary")
	lib.startup(devNum, MYSID)

	-- enumerate children
	local children = lib.getChildren(devNum)
	for k, deviceID in pairs(children) do
		lib.L(devNum, "Child #%1 - %2", deviceID, luup.devices[deviceID].description)

		local deviceType = luup.attr_get("device_file", deviceID)

		-- generic init
		lib.initVar(MYSID, "DebugMode", 0, deviceID)
		lib.initVar(SWITCHSID, "Target", "0", deviceID)
		lib.initVar(SWITCHSID, "Status", "0", deviceID)

		-- device specific code
		if deviceType == "D_DimmableLight1.xml" or deviceType == "D_VirtualDimmableLight1.xml" then
			-- dimmer
			lib.initVar(DIMMERSID, "LoadLevelTarget", "0", deviceID)
			lib.initVar(DIMMERSID, "LoadLevelStatus", "0", deviceID)
			lib.initVar(DIMMERSID, "LoadLevelLast", "100", deviceID)
			lib.initVar(DIMMERSID, "TurnOnBeforeDim", "1", deviceID)
			lib.initVar(DIMMERSID, "AllowZeroLevel", "0", deviceID)

			lib.initVar(MYSID, COMMANDS_SETBRIGHTNESS, lib.DEFAULT_ENDPOINT, deviceID)
			lib.initVar(MYSID, "AutoOff", "0", deviceID)
			lib.initVar(MYSID, "DimmingScale", "100", deviceID)

		elseif deviceType == "D_WindowCovering1.xml" or deviceType == "D_VirtualWindowCovering1.xml" then
			-- roller shutter
			lib.initVar(DIMMERSID, "AllowZeroLevel", "1", deviceID)
			lib.initVar(DIMMERSID, "LoadLevelTarget", "0", deviceID)
			lib.initVar(DIMMERSID, "LoadLevelStatus", "0", deviceID)
			lib.initVar(DIMMERSID, "LoadLevelLast", "100", deviceID)
			
			lib.initVar(MYSID, COMMANDS_SETBRIGHTNESS, lib.DEFAULT_ENDPOINT, deviceID)
			lib.initVar(MYSID, COMMANDS_MOVESTOP, lib.DEFAULT_ENDPOINT, deviceID)
			lib.initVar(MYSID, "BlindAsSwitch", 0, deviceID)
			lib.initVar(MYSID, "DimmingScale", "100", deviceID)
		else
			-- binary light
			lib.setVar(DIMMERSID, "LoadLevelTarget", nil, deviceID)
			lib.setVar(DIMMERSID, "LoadLevelTarget", nil, deviceID)
			lib.setVar(DIMMERSID, "LoadLevelStatus", nil, deviceID)
			lib.setVar(DIMMERSID, "LoadLevelLast", nil, deviceID)
			lib.setVar(DIMMERSID, "TurnOnBeforeDim", nil, deviceID)
			lib.setVar(DIMMERSID, "AllowZeroLevel", nil, deviceID)

			lib.setVar(MYSID, COMMANDS_SETBRIGHTNESS, nil, deviceID)
			lib.initVar(MYSID, "AutoOff", "0", deviceID)
			lib.initVar(MYSID, "DimmingScale", "100", deviceID)
		end

		-- normal switch
		local commandPower = lib.initVar(MYSID, COMMANDS_SETPOWER, lib.DEFAULT_ENDPOINT, deviceID)
		lib.initVar(MYSID, COMMANDS_SETPOWEROFF, commandPower, deviceID)
		lib.initVar(MYSID, COMMANDS_TOGGLE, lib.DEFAULT_ENDPOINT, deviceID)

		-- meters
		local commandUpdateMeters = lib.initVar(MYSID, COMMANDS_UPDATEMETERS, lib.DEFAULT_ENDPOINT, deviceID)
		lib.initVar(MYSID, "MeterPowerFormat", "meters[1].power", deviceID)
		lib.initVar(MYSID, "MeterTotalFormat", "meters[1].total", deviceID)
		lib.initVar(MYSID, "MeterTotalUnit", "0", deviceID)
		lib.initVar(MYSID, "MeterUpdate", 0, deviceID)

		if commandUpdateMeters ~= lib.DEFAULT_ENDPOINT then
			-- start updating meters after 4 secs
			luup.call_delay("updateMeters", 4, deviceID)
		end

		local category_num = luup.attr_get("category_num", deviceID) or 0
		-- set at first run, then make it configurable
		if category_num == 0 then
			category_num = 3
			if deviceType == "D_DimmableLight1.xml" then category_num = 2 end -- dimmer
			if deviceType == "D_WindowCovering1.xml" then category_num = 8 end -- blind

			luup.attr_set("category_num", category_num, deviceID) -- switch
		end

		-- set at first run, then make it configurable
		if tonumber(category_num or "-1") == 3 and luup.attr_get("subcategory_num", deviceID) == nil then
			luup.attr_set("subcategory_num", "3", deviceID) -- in wall switch
		end

		-- MQTT
		if lib.openLuup then
			lib.initializeMqtt(devNum, {
				["PowerStatusOn"] = { Service = SWITCHSID, Variable = "Status", Value = "1" },
				["PowerStatusOff"] = { Service = SWITCHSID, Variable = "Status", Value = "0" },
				["BrightnessValue"] = { Service = DIMMERSID, Variable = "LoadLevelStatus" }
				})
		end

		-- status
		lib.setVar(HASID, "Configured", 1, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)
		luup.set_failure(0, deviceID)

		lib.D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", lib._PLUGIN_NAME
end