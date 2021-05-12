------------------------------------------------------------------------
-- Copyright (c) 2019-2021 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualRGBW1", package.seeall)

local MYSID									= "urn:bochicchio-com:serviceId:VirtualRGBW1"
local SWITCHSID								= "urn:upnp-org:serviceId:SwitchPower1"
local DIMMERSID								= "urn:upnp-org:serviceId:Dimming1"
local COLORSID								= "urn:micasaverde-com:serviceId:Color1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"

local COMMANDS_SETPOWER						= "SetPowerURL"
local COMMANDS_SETPOWEROFF					= "SetPowerOffURL"
local COMMANDS_SETBRIGHTNESS				= "SetBrightnessURL"
local COMMANDS_SETRGBCOLOR					= "SetRGBColorURL"
local COMMANDS_SETWHITETEMPERATURE			= "SetWhiteTemperatureURL"
local COMMANDS_TOGGLE						= "SetToggleURL"

-- implementation
local function restoreBrightness(devNum)
	-- Restore brightness
	local brightness = lib.getVarNumeric(DIMMERSID, "LoadLevelLast", 0, devNum)
	local brightnessCurrent = lib.getVarNumeric(DIMMERSID, "LoadLevelStatus", 0, devNum)

	if brightness > 0 and brightnessCurrent ~= brightness then
		lib.setVar(DIMMERSID, "LoadLevelTarget", brightness, devNum)
		lib.setVar(DIMMERSID, "LoadLevelLast", brightness, devNum)

		lib.sendDeviceCommand(MYSID, COMMANDS_SETBRIGHTNESS, brightness, devNum, function()
			lib.setVar(DIMMERSID, "LoadLevelStatus", brightness, devNum)
		end)
	end
end

function actionPower(devNum, status)
	lib.D(devNum, "actionPower(%1,%2)", devNum, status)

	-- Switch on/off
	if type(status) == "string" then
		status = (tonumber(status) or 0) ~= 0
	elseif type(status) == "number" then
		status = status ~= 0
	end

	lib.setVar(SWITCHSID, "Target", status and "1" or "0", devNum)
	
	-- UI needs LoadLevelTarget/Status to comport with status according to Vera's rules
	if not status then
		lib.setVar(DIMMERSID, "LoadLevelTarget", 0, devNum)
		lib.setVar(DIMMERSID, "LoadLevelStatus", 0, devNum)

		lib.sendDeviceCommand(MYSID, COMMANDS_SETPOWEROFF, "off", devNum, function()
			lib.setVar(SWITCHSID, "Status", status and "1" or "0", devNum)
		end)
	else
		lib.sendDeviceCommand(MYSID, COMMANDS_SETPOWER, "on", devNum, function()
			lib.setVar(SWITCHSID, "Status", status and "1" or "0", devNum)
			restoreBrightness(devNum)
		end)
	end
end

function actionBrightness(devNum, newVal)
	lib.D(devNum, "actionBrightness(%1,%2)", devNum, newVal)

	-- Dimming level change
	newVal = tonumber(newVal) or 100
	if newVal < 0 then
		newVal = 0
	elseif newVal > 100 then
		newVal = 100
	end -- range

	lib.setVar(DIMMERSID, "LoadLevelTarget", newVal, devNum)

	if newVal > 0 then
		-- Level > 0, if light is off, turn it on.
		local status = lib.getVarNumeric(SWITCHSID, "Status", 0, devNum)
		if status == 0 then
			lib.setVar(SWITCHSID, "Target", 1, devNum)
			lib.sendDeviceCommand(MYSID, COMMANDS_SETPOWER, "on", devNum, function()
				lib.setVar(SWITCHSID, "Status", 1, devNum)
			end)
		end
		lib.sendDeviceCommand(MYSID, COMMANDS_SETBRIGHTNESS, newVal, devNum, function()
			lib.setVar(DIMMERSID, "LoadLevelStatus", newVal, devNum)
		end)
	elseif lib.getVarNumeric(DIMMERSID, "AllowZeroLevel", 0, devNum) ~= 0 then
		-- Level 0 allowed as on status, just go with it.
		lib.setVar(DIMMERSID, "LoadLevelStatus", newVal, devNum)
		lib.sendDeviceCommand(MYSID, COMMANDS_SETBRIGHTNESS, 0, devNum, function()
			lib.setVar(DIMMERSID, "LoadLevelStatus", newVal, devNum)
		end)
	else
		lib.setVar(SWITCHSID, "Target", 0, devNum)

		-- Level 0 (not allowed as an "on" status), switch light off.
		lib.sendDeviceCommand(MYSID, COMMANDS_SETPOWEROFF, "off", devNum, function()
			lib.setVar(SWITCHSID, "Status", 0, devNum)
			lib.setVar(DIMMERSID, "LoadLevelStatus", 0, devNum)
		end)
	end

	if newVal > 0 then lib.setVar(DIMMERSID, "LoadLevelLast", newVal, devNum) end
end

-- Approximate RGB from color temperature. We don't both with most of the algorithm
-- linked below because the lower limit is 2000 (Vera) and the upper is 6500 (Yeelight).
-- We're also not going nuts with precision, since the only reason we're doing this is
-- to make the color spot on the UI look somewhat sensible when in temperature mode.
-- Ref: https://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
local function approximateRGB(t)
	local function bound(v)
		if v < 0 then
			v = 0
		elseif v > 255 then
			v = 255
		end
		return math.floor(v)
	end
	local r, g, b = 255
	t = t / 100
	g = bound(99.471 * math.log(t) - 161.120)
	b = bound(138.518 * math.log(t - 10) - 305.048)
	return r, g, b
end

local function updateColor(devNum, w, c, r, g, b)
	local targetColor = string.format("0=%d,1=%d,2=%d,3=%d,4=%d", w, c, r, g, b)
	lib.D(devNum, "updateColor(%1,%2)", device, targetColor)
	lib.setVar(COLORSID, "CurrentColor", targetColor, devNum)
end

function actionSetColor(devNum, newVal, sendToDevice)
	lib.D(devNum, "actionSetColor(%1,%2,%3)", devNum, newVal, sendToDevice)

	newVal = newVal or ""

	local status = lib.getVarNumeric(SWITCHSID, "Status", 0, devNum)
	local turnOnBeforeDim = lib.getVarNumeric(DIMMERSID, "TurnOnBeforeDim", 0, devNum)
	
	if status == 0 and turnOnBeforeDim == 1 and sendToDevice then
		lib.setVar(SWITCHSID, "Target", 1, devNum)
		lib.sendDeviceCommand(MYSID, COMMANDS_SETPOWER, "on", devNum, function()
			lib.setVar(SWITCHSID, "Status", 1, devNum)
		end)
	end
	local w, c, r, g, b

	local s = split(newVal, ",")

	if (#newVal == 6 or #newVal == 7) and #s == 1 then
		-- #RRGGBB or RRGGBB
		local startIndex = #newVal == 7 and 2 or 1
		r = tonumber(string.sub(newVal, startIndex, 2), 16) or 0
		g = tonumber(string.sub(newVal, startIndex+2, startIndex+3), 16) or 0
		b = tonumber(string.sub(newVal, startIndex+4, startIndex+5), 16) or 0
		w, c = 0, 0
		
		lib.D(devNum, "actionSetColor.RGBFromHex(%1,%2,%3)", r, g, b)

		if r ~= nil and g  ~= nil and  b ~= nil and sendToDevice then
			lib.sendDeviceCommand(MYSID, COMMANDS_SETRGBCOLOR, {r, g, b}, devNum, function()
				updateColor(devNum, w, c, r, g, b)
			end)
		end

		restoreBrightness(devNum)
	elseif #s == 3 or #s == 5 then
		-- R,G,B -- handle both 255,0,255 OR R255,G0,B255 value
		-- also handle W0,D0,R255,G0,B255

		local startIndex = #s == 5 and 2 or 0
		r = tonumber(s[startIndex+1]) or tonumber(string.sub(s[startIndex+1], 2))
		g = tonumber(s[startIndex+2]) or tonumber(string.sub(s[startIndex+2], 2))
		b = tonumber(s[startIndex+3]) or tonumber(string.sub(s[startIndex+3], 2))
		w, c = 0, 0
		lib.D(devNum, "actionSetColor.RGB(%1,%2,%3)", r, g, b)
		
		if r ~= nil and g  ~= nil and  b ~= nil and sendToDevice then
			lib.sendDeviceCommand(MYSID, COMMANDS_SETRGBCOLOR, {r, g, b}, devNum, function()
				updateColor(devNum, w, c, r, g, b)
			end)
		end

		restoreBrightness(devNum)
	else
		-- Wnnn, Dnnn (color range)
		local tempMin = lib.getVarNumeric(MYSID, "MinTemperature", 1600, devNum)
		local tempMax = lib.getVarNumeric(MYSID, "MaxTemperature", 6500, devNum)
		local filteredVal = newVal:gsub("W255", ""):gsub("D255", "") -- handle both
		local code, temp = filteredVal:upper():match("([WD])(%d+)")
		local t
		if code == "W" then
			t = tonumber(temp) or 128
			temp = 2000 + math.floor(t * 3500 / 255)
			if temp < tempMin then
				temp = tempMin
			elseif temp > tempMax then
				temp = tempMax
			end
			w = t
			c = 0
		elseif code == "D" then
			t = tonumber(temp) or 128
			temp = 5500 + math.floor(t * 3500 / 255)
			if temp < tempMin then
				temp = tempMin
			elseif temp > tempMax then
				temp = tempMax
			end
			c = t
			w = 0
		elseif code == nil then
			-- Try to evaluate as integer (2000-9000K)
			temp = tonumber(newVal) or 2700
			if temp < tempMin then
				temp = tempMin
			elseif temp > tempMax then
				temp = tempMax
			end
			if temp <= 5500 then
				if temp < 2000 then temp = 2000 end -- enforce Vera min
				w = math.floor((temp - 2000) / 3500 * 255)
				c = 0
				--targetColor = string.format("W%d", w)
			elseif temp > 5500 then
				if temp > 9000 then temp = 9000 end -- enforce Vera max
				c = math.floor((temp - 5500) / 3500 * 255)
				w = 0
				--targetColor = string.format("D%d", c)
			else
				lib.L(devNum, "Unable to set color, target value %1 invalid", newVal)
				return
			end
		end

		r, g, b = approximateRGB(temp)

		lib.D(devNum, "actionSetColor.whiteTemp(%1,%2,%3)", w, c, temp)

		if sendToDevice then
			lib.sendDeviceCommand(MYSID, COMMANDS_SETWHITETEMPERATURE, temp, devNum, function()
				updateColor(devNum, w, c, r, g, b)
			end)
		else
			updateColor(devNum, w, c, r, g, b)
		end
		restoreBrightness(devNum)

		lib.D(devNum, "aprox RGB(%1,%2,%3)", r, g, b)
	end

	local targetColor = string.format("0=%d,1=%d,2=%d,3=%d,4=%d", w, c, r, g, b)
	lib.setVar(COLORSID, "TargetColor", targetColor, devNum)
end

-- Toggle status
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

		lib.initVar(DIMMERSID, "LoadLevelTarget", "0", deviceID)
		lib.initVar(DIMMERSID, "LoadLevelStatus", "0", deviceID)
		lib.initVar(DIMMERSID ,"LoadLevelLast", "100", deviceID)
		lib.initVar(DIMMERSID, "TurnOnBeforeDim", "1", deviceID)
		lib.initVar(DIMMERSID, "AllowZeroLevel", "0", deviceID)

		lib.initVar(COLORSID, "TargetColor", "0=51,1=0,2=0,3=0,4=0", deviceID)
		lib.initVar(COLORSID, "CurrentColor", "", deviceID)
		lib.initVar(COLORSID, "SupportedColors", "W,D,R,G,B", deviceID)

		-- TODO: white mode scale?
		lib.initVar(MYSID, "MinTemperature", "2000", deviceID)
		lib.initVar(MYSID, "MaxTemperature", "6500", deviceID)

		lib.initVar(MYSID, COMMANDS_SETBRIGHTNESS, lib.DEFAULT_ENDPOINT, deviceID)
		lib.initVar(MYSID, COMMANDS_SETWHITETEMPERATURE, lib.DEFAULT_ENDPOINT, deviceID)
		lib.initVar(MYSID, COMMANDS_SETRGBCOLOR, lib.DEFAULT_ENDPOINT, deviceID)

		local commandPower = lib.initVar(MYSID, COMMANDS_SETPOWER, lib.DEFAULT_ENDPOINT, deviceID)

		-- upgrade code to support power off command
		lib.initVar(MYSID, COMMANDS_SETPOWEROFF, commandPower, deviceID)

		-- device categories
		local category_num = luup.attr_get("category_num", deviceID) or 0
		if category_num == 0 then
			luup.attr_set("category_num", "2", deviceID)
			luup.attr_set("subcategory_num", "4", deviceID)
		end

		lib.setVar(HASID, "Configured", 1, deviceID)
		lib.setVar(HASID, "CommFailure", 0, deviceID)
		
		-- MQTT
		lib.initializeMqtt(devNum, {
			["PowerStatusOn"] = { Service = SWITCHSID, Variable = "Status", Value = "1" },
			["PowerStatusOff"] = { Service = SWITCHSID, Variable = "Status", Value = "0" },
			["BrightnessValue"] = { Service = DIMMERSID, Variable = "LoadLevelStatus" },
			["BrightnessValue"] = { Service = DIMMERSID, Variable = "LoadLevelTarget" },
			["Color"] = { Service = COLORSID, Variable = "CurrentColor" }, -- TODO: parse it?
			["WhiteTemperature"] = { Service = COLORSID, Variable = "CurrentColor" } -- TODO: parse it?
			})

		-- status
		luup.set_failure(0, deviceID)

		lib.D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", lib._PLUGIN_NAME
end