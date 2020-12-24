module("L_VirtualBinaryLight1", package.seeall)

local _PLUGIN_NAME = "VirtualBinaryLight"
local _PLUGIN_VERSION = "2.40"

local debugMode = false

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
local DEFAULT_ENDPOINT						= "http://"

local function dump(t, seen)
	if t == nil then return "nil" end
	if seen == nil then seen = {} end
	local sep = ""
	local str = "{ "
	for k, v in pairs(t) do
		local val
		if type(v) == "table" then
			if seen[v] then
				val = "(recursion)"
			else
				seen[v] = true
				val = dump(v, seen)
			end
		elseif type(v) == "string" then
			if #v > 255 then
				val = string.format("%q", v:sub(1, 252) .. "...")
			else
				val = string.format("%q", v)
			end
		elseif type(v) == "number" and (math.abs(v - os.time()) <= 86400) then
			val = string.format("%s(%s)", v, os.date("%x.%X", v))
		else
			val = tostring(v)
		end
		str = str .. sep .. k .. "=" .. val
		sep = ", "
	end
	str = str .. " }"
	return str
end

local function getVarNumeric(sid, name, dflt, devNum)
	local s = luup.variable_get(sid, name, devNum) or ""
	if s == "" then return dflt end
	s = tonumber(s)
	return (s == nil) and dflt or s
end

local function getVar(sid, name, dflt, devNum)
	local s = luup.variable_get(sid, name, devNum) or ""
	if s == "" then return dflt end
	return (s == nil) and dflt or s
end

local function L(devNum, msg, ...) -- luacheck: ignore 212
	local str = string.format("%s[%s@%s]", _PLUGIN_NAME, _PLUGIN_VERSION, devNum)
	local level = 50
	if type(msg) == "table" then
		str = string.format("%s%s:%s", str, msg.prefix or _PLUGIN_NAME, msg.msg)
		level = msg.level or level
	else
		str = string.format("%s:%s", str, msg)
	end
	
	str = string.gsub(str, "%%(%d+)", function(n)
		n = tonumber(n, 10)
		if n < 1 or n > #arg then return "nil" end
		local val = arg[n]
		if type(val) == "table" then
			return dump(val)
		elseif type(val) == "string" then
			return string.format("%q", val)
		elseif type(val) == "number" and math.abs(val - os.time()) <= 86400 then
			return string.format("%s(%s)", val, os.date("%x.%X", val))
		end
		return tostring(val)
	end)
	luup.log(str, level)
end

local function D(devNum, msg, ...)
	debugMode = getVarNumeric(MYSID, "DebugMode", 0, devNum) == 1

	if debugMode then
		local t = debug.getinfo(2)
		local pfx = string.format("(%s@%s)", t.name or "", t.currentline or "")
		L(devNum, {msg = msg, prefix = pfx}, ...)
	end
end

-- Set variable, only if value has changed.
local function setVar(sid, name, val, devNum)
	val = (val == nil) and "" or tostring(val)
	local s = luup.variable_get(sid, name, devNum) or ""
	D(devNum, "setVar(%1,%2,%3,%4) old value %5", sid, name, val, devNum, s)
	if s ~= val then
		luup.variable_set(sid, name, val, devNum)
		return true, s
	end
	return false, s
end

local function split(str, sep)
	if sep == nil then sep = "," end
	local arr = {}
	if #(str or "") == 0 then return arr, 0 end
	local rest = string.gsub(str or "", "([^" .. sep .. "]*)" .. sep,
		function(m)
			table.insert(arr, m)
			return ""
		end)
	table.insert(arr, rest)
	return arr, #arr
end

local function trim(s)
	if s == nil then return "" end
	if type(s) ~= "string" then s = tostring(s) end
	local from = s:match "^%s*()"
	return from > #s and "" or s:match(".*%S", from)
end

-- Array to map, where f(elem) returns key[,value]
local function map(arr, f, res)
	res = res or {}
	for ix, x in ipairs(arr) do
		if f then
			local k, v = f(x, ix)
			res[k] = (v == nil) and x or v
		else
			res[x] = x
		end
	end
	return res
end

local function initVar(sid, name, dflt, devNum)
	local currVal = luup.variable_get(sid, name, devNum)
	if currVal == nil then
		luup.variable_set(sid, name, tostring(dflt), devNum)
		return tostring(dflt)
	end
	return currVal
end

local function getChildren(masterID)
	local children = {}
	for k, v in pairs(luup.devices) do
		if tonumber(v.device_num_parent) == masterID then
			D(masterID, "Child found: %1", k)
			table.insert(children, k)
		end
	end

	table.insert(children, masterID)
	return children
end

function httpGet(devNum, url, onSuccess)
	local useCurl = url:lower():find("^curl://")
	local ltn12 = require("ltn12")
	local _, async = pcall(require, "http_async")
	local response_body = {}
	
	D(devNum, "httpGet(%1)", useCurl and "curl" or type(async) == "table" and "async" or "sync")

	-- curl
	if useCurl then
		local randommName = tostring(math.random(os.time()))
		local fileName = "/tmp/httpcall" .. randommName:gsub("%s+", "") ..".dat" 
		-- remove file
		os.execute('/bin/rm ' .. fileName)

		local httpCmd = string.format("curl -o '%s' %s", fileName, url:gsub("^curl://", ""))
		local res, err = os.execute(httpCmd)

		if res ~= 0 then
			D(devNum, "[HttpGet] CURL failed: %1 %2: %3", res, err, httpCmd)
			return false, nil
		else
			local file, err = io.open(fileName, "r")
			if not file then
				D(devNum, "[HttpGet] Cannot read response file: %1 - %2", fileName, err)

				os.execute('/bin/rm ' .. fileName)
				return false, nil
			end

			response_body = file:read('*all')
			file:close()

			D(devNum, "[HttpGet] %1 - %2", httpCmd, (response_body or ""))
			os.execute('/bin/rm ' .. fileName)

			if onSuccess ~= nil then
				D(devNum, "httpGet: onSuccess(%1)", status)
				onSuccess(response_body)
			end
			return true, response_body
		end

	-- async
	elseif type(async) == "table" then
		-- Async Handler for HTTP or HTTPS
		async.request(
		{
			method = "GET",
			url = url,
			headers = {
				["Content-Type"] = "application/json; charset=utf-8",
				["Connection"] = "keep-alive"
			},
			sink = ltn12.sink.table(response_body)
		},
		function (response, status, headers, statusline)
			D(devNum, "httpGet.Async(%1, %2, %3, %4)", url, (response or ""), (status or "-1"), table.concat(response_body or ""))

			status = tonumber(status or 100)

			if onSuccess ~= nil and status >= 200 and status < 400 then
				D(devNum, "httpGet: onSuccess(%1)", status)
				onSuccess(table.concat(response_body or ""))
			end
		end)

		return true, "" -- async requests are considered good unless they"re not
	else
		-- Sync Handler for HTTP or HTTPS
		local requestor = url:lower():find("^https:") and require("ssl.https") or require("socket.http")
		local response, status, headers = requestor.request{
			method = "GET",
			url = url,
			headers = {
				["Content-Type"] = "application/json; charset=utf-8",
				["Connection"] = "keep-alive"
			},
			sink = ltn12.sink.table(response_body)
		}

		D(devNum, "httpGet(%1, %2, %3, %4)", url, (response or ""), (status or "-1"), table.concat(response_body or ""))

		status = tonumber(status or 100)

		if status >= 200 and status < 400 then
			if onSuccess ~= nil then
				D(devNum, "httpGet: onSuccess(%1)", status)
				onSuccess(table.concat(response_body or ""))
			end

			return true, tostring(table.concat(response_body or ""))
		else
			return false, nil
		end
	end
end

local function sendDeviceCommand(cmd, params, devNum, onSuccess)
	D(devNum, "sendDeviceCommand(%1,%2,%3)", cmd, params, devNum)

	local pv = {}
	if type(params) == "table" then
		for k, v in ipairs(params) do
			if type(v) == "string" then
				pv[k] = v
			else
				pv[k] = tostring(v)
			end
		end
	elseif type(params) == "string" then
		table.insert(pv, params)
	elseif params ~= nil then
		table.insert(pv, tostring(params))
	end
	local pstr = table.concat(pv, ",")

	local cmdUrl = getVar(MYSID, cmd, DEFAULT_ENDPOINT, devNum)

	-- SKIP command, just update variables
	if (cmdUrl == "skip") then
		D(devNum, "sendDeviceCommand: skipped")
		onSuccess("skip")
		return true
	end

	if (cmdUrl ~= DEFAULT_ENDPOINT) then
		local urls = split(cmdUrl, "\n")
		for _, url in pairs(urls) do
			D(devNum, "sendDeviceCommand.url(%1)", url)
			if #trim(url) > 0 then
				httpGet(devNum, string.format(url, pstr), onSuccess)
			end
		end
	end

	return false
end

local function restoreBrightness(devNum)
	-- Restore brightness
	local brightness = getVarNumeric(DIMMERSID, "LoadLevelLast", 0, devNum)
	local brightnessCurrent = getVarNumeric(DIMMERSID, "LoadLevelStatus", 0, devNum)

	if brightness > 0 and brightnessCurrent ~= brightness then
		setVar(DIMMERSID, "LoadLevelTarget", brightness, devNum)	
		sendDeviceCommand(COMMANDS_SETBRIGHTNESS, brightness, devNum, function()
			setVar(DIMMERSID, "LoadLevelStatus", brightness, devNum)
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

	D(devNum, "actionPowerInternal(%1,%2,%3)", devNum, status, shouldRestoreBrightness)

	setVar(SWITCHSID, "Target", status and "1" or "0", devNum)

	-- get device type
	local deviceType = luup.attr_get("device_file", devNum)
	local isDimmer = deviceType == "D_DimmableLight1.xml" or deviceType == "D_VirtualDimmableLight1.xml" 
	local isBlind = deviceType == "D_WindowCovering1.xml" or deviceType == "D_VirtualWindowCovering1.xml"

	-- UI needs LoadLevelTarget/Status to conform with status according to Vera's rules.
	if not status then
		if isDimmer or isBlind then
			setVar(DIMMERSID, "LoadLevelTarget", 0, devNum)
		end

		sendDeviceCommand(COMMANDS_SETPOWEROFF, "off", devNum, function()
			setVar(SWITCHSID, "Status", "0", devNum)
			if isDimmer or isBlind then
				setVar(DIMMERSID, "LoadLevelStatus", 0, devNum)
			end
		end)
	else
		sendDeviceCommand(COMMANDS_SETPOWER, "on", devNum, function()
			setVar(SWITCHSID, "Status", "1", devNum)
			
			-- restore brightness
			if shouldRestoreBrightness and isDimmer and not isBlind then
				restoreBrightness(devNum)
			end

			-- autooff
			local autoOff = getVarNumeric(MYSID, "AutoOff", 0, devNum)
			D(devNum, "Auto off in %1 secs", autoOff)

			if autoOff>0 then
				luup.call_delay("actionAutoOff", autoOff, devNum)
			end
		end)
	end
end

function actionAutoOff(devNum)
	D(devNum, "Auto off called")
	actionPower(tonumber(devNum), 0)
end

function actionPower(devNum, status)
	D(devNum, "actionPower(%1,%2)", devNum, status)

	actionPowerInternal(devNum, status, true)
end

function actionBrightness(devNum, newVal)
	D(devNum, "actionBrightness(%1,%2)", devNum, newVal)

	-- dimmer or not?
	local deviceType = luup.attr_get("device_file", devNum)
	local isDimmer = deviceType == "D_DimmableLight1.xml" or deviceType == "D_VirtualDimmableLight1.xml" 
	local isBlind = deviceType == "D_WindowCovering1.xml" or deviceType == "D_VirtualWindowCovering1.xml"
	local isBlindNoPosition = isBlind and getVarNumeric(MYSID, "BlindAsSwitch", 0, devNum) == 1

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
		D(devNum, "New Position: %1 - original %2", newPosition, newVal)

		setVar(DIMMERSID, "LoadLevelStatus", newPosition, devNum)
		setVar(DIMMERSID, "LoadLevelTarget", newPosition, devNum)
		actionPowerInternal(devNum, newPosition == 0 and 0 or 1, false)
	else
		-- normal dimmer or blind
		setVar(DIMMERSID, "LoadLevelTarget", newVal, devNum)

		if newVal > 0 then
			-- Level > 0, if light is off, turn it on.
			if isDimmer then
				local status = getVarNumeric(SWITCHSID, "Status", 0, devNum)
				if status == 0 then
					actionPowerInternal(devNum, 1, false)
				end
			end

			sendDeviceCommand(COMMANDS_SETBRIGHTNESS, newVal, devNum, function()
				setVar(DIMMERSID, "LoadLevelStatus", newVal, devNum)
			end)
		elseif newVal == 0 and getVarNumeric(DIMMERSID, "AllowZeroLevel", 0, devNum) ~= 0 then
			-- Level 0 allowed as on status, just go with it.
			sendDeviceCommand(COMMANDS_SETBRIGHTNESS, newVal, devNum, function()
				setVar(DIMMERSID, "LoadLevelStatus", newVal, devNum)
			end)
		else
			-- Level 0 (not allowed as an "on" status), switch light off.
			actionPowerInternal(devNum, 0, false)
		end
	end

	if newVal > 0 then setVar(DIMMERSID, "LoadLevelLast", newVal, devNum) end
end

-- Toggle state
function actionToggleState(devNum)
	local cmdUrl = getVar(MYSID, COMMANDS_TOGGLE, DEFAULT_ENDPOINT, devNum)

	local status = getVarNumeric(SWITCHSID, "Status", 0, devNum)

	if (cmdUrl == DEFAULT_ENDPOINT or cmdUrl == "") then
		-- toggle by using the current status
		actionPower(devNum, status == 1 and 0 or 1)
	else
		-- update variables
		setVar(SWITCHSID, "Target", status == 1 and 0 or 1, devNum)

		-- toggle command specifically defined
		sendDeviceCommand(COMMANDS_TOGGLE, nil, devNum, function()
			setVar(SWITCHSID, "Status", status == 1 and 0 or 1, devNum)		
		end)
	end
end

-- stop for blinds
function actionStop(devNum) 
	D(devNum, "actionStop(%1)", devNum)
	sendDeviceCommand(COMMANDS_MOVESTOP, nil, devNum) 
end

-- meters support
function updateMeters(devNum)
	function getValue(data, path)
		D(devNum, "updateMeters.getValue(%1)", path)
		local x = data or ""
		for field in path: gmatch "[^%.%[%]]+" do
			if x ~= nil and field ~= nil then
				x = x[tonumber(field) or field]
			end
		end
		return x or ""
	end
	function round(num, numDecimalPlaces)
		local mult = 10 ^ (numDecimalPlaces or 0)
		return math.floor(num * mult + 0.5) / mult
	end

	local meterUpdate = getVarNumeric(MYSID, "MeterUpdate", 0, devNum)

	if meterUpdate == 0 then
		L(devNum, "updateMeters: disabled")
	end

	local wattsPath = getVar(MYSID, "MeterPowerFormat", "", devNum)
	local kwhPath = getVar(MYSID, "MeterTotalFormat", "", devNum)
	local format = getVarNumeric(MYSID, "MeterTotalUnit", 0, devNum) -- 0 KWH, 1 Wmin, 2 WH

	local url = getVar(MYSID, COMMANDS_UPDATEMETERS, DEFAULT_ENDPOINT, devNum)

	D(devNum, "updateMeters(%1)", url)

	if cmdUrl ~= DEFAULT_ENDPOINT or (cmdUrl or "" ~= "") then
		httpGet(devNum, url, function(response)
			D(devNum, "updateMeters: %1", response)

			local json = require "dkjson"
			local data = json.decode(response)

			if kwhPath ~= "" then
				local value = tonumber(getValue(data, kwhPath))
				local transformedValue = value

				-- EXPERIMENTAL!
				if format == 1 then -- Wmin
					transformedValue = round(round(value / 60, 4) / 1000, 4) -- from Wmin to KWH
					
					-- special case for shellies - if value <= stored value, then add value, otherwise compute delta
					local storedValue = getVarNumeric(ENERGYMETERSID, "KWH", 0, devNum)
					local delta = 0

					if transformedValue > storedValue then
						delta = transformedValue - storedValue
					elseif transformedValue < storedValue then
						delta = storedValue
					else
						delta = -transformedValue -- same value, do not update
					end

					transformedValue = transformedValue + delta

					D(devNum, "[updateMeters] Format %1 - Delta %2 - Original %3", format, delta, storedValue)
				elseif format == 2 then -- WH
					transformedValue = value / 60 -- from WH to KWH
				end
				
				L(devNum, "[updateMeters] KWH Path %1 - Raw Value: %2 - Transformed Value: %3", kwhPath, value, transformedValue)
				setVar(ENERGYMETERSID, "KWH", round(transformedValue, 4), devNum)
			end

			if wattsPath ~= "" then
				local value = tonumber(getValue(data, wattsPath))
				L(devNum, "[updateMeters] Watts Path: %1 - Value: %2", wattsPath, value)
				setVar(ENERGYMETERSID, "Watts", value, devNum)
			end
		end)
	end

	L(devNum, "updateMeters: next call in %1 secs", meterUpdate)
	luup.call_delay("updateMeters", meterUpdate, devNum)
end

function startPlugin(devNum)
	L(devNum, "Plugin starting")

	-- enumerate children
	local children = getChildren(devNum)
	for k, deviceID in pairs(children) do
		L(devNum, "Plugin start: child #%1 - %2", deviceID, luup.devices[deviceID].description)

		local deviceType = luup.attr_get("device_file", deviceID)

		-- generic init
		initVar(MYSID, "DebugMode", 0, deviceID)
		initVar(SWITCHSID, "Target", "0", deviceID)
		initVar(SWITCHSID, "Status", "-1", deviceID)

		-- device specific code
		if deviceType == "D_DimmableLight1.xml" or deviceType == "D_VirtualDimmableLight1.xml" then
			-- dimmer
			initVar(DIMMERSID, "LoadLevelTarget", "0", deviceID)
			initVar(DIMMERSID, "LoadLevelStatus", "0", deviceID)
			initVar(DIMMERSID, "LoadLevelLast", "100", deviceID)
			initVar(DIMMERSID, "TurnOnBeforeDim", "1", deviceID)
			initVar(DIMMERSID, "AllowZeroLevel", "0", deviceID)

			initVar(MYSID, COMMANDS_SETBRIGHTNESS, DEFAULT_ENDPOINT, deviceID)
			initVar(MYSID, "AutoOff", "0", deviceID)

		elseif deviceType == "D_WindowCovering1.xml" or deviceType == "D_VirtualWindowCovering1.xml" then
			-- roller shutter
			initVar(DIMMERSID, "AllowZeroLevel", "1", deviceID)
			initVar(DIMMERSID, "LoadLevelTarget", "0", deviceID)
			initVar(DIMMERSID, "LoadLevelStatus", "0", deviceID)
			initVar(DIMMERSID, "LoadLevelLast", "100", deviceID)
			
			initVar(MYSID, COMMANDS_SETBRIGHTNESS, DEFAULT_ENDPOINT, deviceID)
			initVar(MYSID, COMMANDS_MOVESTOP, DEFAULT_ENDPOINT, deviceID)
			initVar(MYSID, "BlindAsSwitch", 0, deviceID)
		else
			-- binary light
			setVar(DIMMERSID, "LoadLevelTarget", nil, deviceID)
			setVar(DIMMERSID, "LoadLevelTarget", nil, deviceID)
			setVar(DIMMERSID, "LoadLevelStatus", nil, deviceID)
			setVar(DIMMERSID, "LoadLevelLast", nil, deviceID)
			setVar(DIMMERSID, "TurnOnBeforeDim", nil, deviceID)
			setVar(DIMMERSID, "AllowZeroLevel", nil, deviceID)

			setVar(MYSID, COMMANDS_SETBRIGHTNESS, nil, deviceID)
			initVar(MYSID, "AutoOff", "0", deviceID)
		end

		-- normal switch
		local commandPower = initVar(MYSID, COMMANDS_SETPOWER, DEFAULT_ENDPOINT, deviceID)
		initVar(MYSID, COMMANDS_TOGGLE, DEFAULT_ENDPOINT, deviceID)

		-- meters
		local commandUpdateMeters = initVar(MYSID, COMMANDS_UPDATEMETERS, DEFAULT_ENDPOINT, deviceID)
		initVar(MYSID, "MeterPowerFormat", "meters[1].power", deviceID)
		initVar(MYSID, "MeterTotalFormat", "meters[1].total", deviceID)
		initVar(MYSID, "MeterTotalUnit", "0", deviceID)
		initVar(MYSID, "MeterUpdate", 0, deviceID)

		if commandUpdateMeters ~= DEFAULT_ENDPOINT then updateMeters(deviceID) end

		-- upgrade code
		initVar(MYSID, COMMANDS_SETPOWEROFF, commandPower, deviceID)

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

		setVar(HASID, "Configured", 1, deviceID)
		setVar(HASID, "CommFailure", 0, deviceID)

		-- status
		luup.set_failure(0, deviceID)

		D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", _PLUGIN_NAME
end