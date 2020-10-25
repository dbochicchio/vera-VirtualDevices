module("L_VirtualDoorLock1", package.seeall)

local _PLUGIN_NAME = "VirtualDoorLock"
local _PLUGIN_VERSION = "2.1.0"

local debugMode = false

local MYSID									= "urn:bochicchio-com:serviceId:VirtualDoorLock1"
local SECURITYSID							= "urn:micasaverde-com:serviceId:SecuritySensor1"
local SWITCHSID								= "urn:upnp-org:serviceId:SwitchPower1"
local LOCKSID								= "urn:micasaverde-com:serviceId:DoorLock1"
local HASID									= "urn:micasaverde-com:serviceId:HaDevice1"

local COMMANDS_LOCK							= "SetLockURL"
local COMMANDS_UNLOCK						= "SetUnLockURL"
local DEFAULT_ENDPOINT						= "http://"

local deviceID = -1

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
			val = tostring(v) .. "(" .. os.date("%x.%X", v) .. ")"
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
	local str = (_PLUGIN_NAME .. "[" .. _PLUGIN_VERSION .. "]@" .. tostring(devNum))
	local level = 50
	if type(msg) == "table" then
		str = str .. tostring(msg.prefix or _PLUGIN_NAME) .. ": " .. tostring(msg.msg)
		level = msg.level or level
	else
		str = str .. ": " .. tostring(msg)
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
			return tostring(val) .. "(" .. os.date("%x.%X", val) .. ")"
		end
		return tostring(val)
	end)
	luup.log(str, level)
end

local function D(devNum, msg, ...)
	debugMode = getVarNumeric(MYSID, "DebugMode", 0, devNum) == 1

	if debugMode then
		local t = debug.getinfo(2)
		local pfx = "(" .. tostring(t.name) .. "@" .. tostring(t.currentline) .. ")"
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

function deviceMessage(devNum, message, error, timeout)
	local status = error and 2 or 4
	timeout = timeout or 15
	D(devNum, "deviceMessage(%1,%2,%3,%4)", devNum, message, error, timeout)
	luup.device_message(devNum, status, message, timeout, _PLUGIN_NAME)
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

			local response_body = file:read('*all')
			file:close()

			D(devNum, "[HttpGet] %1 - %2", httpCmd, (response_body or ""))
			os.execute('/bin/rm ' .. fileName)

			if onSuccess ~= nil then
				D(devNum, "httpGet: onSuccess(%1)", status)
				onSuccess()
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
				onSuccess()
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
				onSuccess()
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
	if (cmdUrl ~= DEFAULT_ENDPOINT) then return httpGet(devNum, string.format(cmdUrl, pstr), onSuccess) end

	return false
end

-- implementation
function actionLock(devNum, state)
	state = tostring(state or "0")
	
	D(devNum, "actionLock(%1,%2,%3)", devNum, state, state == "1" and COMMANDS_ARMED or COMMANDS_UNARMED)

	-- send command
	sendDeviceCommand(state == "1" and COMMANDS_LOCK or COMMANDS_UNLOCK, state, devNum, function()
		setVar(LOCKSID, "Status", state, devNum)
		setVar(SWITCHSID, "Status", state, devNum)
	end)
end

-- Watch callback
function virtualDoorLockWatchSync(devNum, sid, var, oldVal, newVal)
	D(devNum, "virtualDoorLockWatchSync(%1,%2,%3,%4,%5)", devNum, sid, var, oldVal, newVal)

	if oldVal == newVal then return end

	if sid == SECURITYSID then
		if var == "Tripped" then
			local masterID = getVarNumeric(MYSID, "DoorLockDeviceID", 0, devNum)
			if masterID > 0 then
				local v = tostring(newVal or "0") == "0" and "1" or "0"
				setVar(LOCKSID, "Status", v, masterID)
				setVar(SWITCHSID, "Status", v, masterID)
			end
		end
	end
end

function startPlugin(devNum)
	L(devNum, "Plugin starting")

	-- enumerate children
	local children = getChildren(devNum)
	for k, deviceID in pairs(children) do
		L(devNum, "Plugin start: child #%1 - %2", deviceID, luup.devices[deviceID].description)

		-- generic init
		initVar(MYSID, "DebugMode", 0, deviceID)

		-- sensors init
		--initVar(SECURITYSID, "Armed", "0", deviceID)
		--initVar(SECURITYSID, "Tripped", "0", deviceID)

		-- http calls init
		initVar(MYSID, COMMANDS_LOCK, DEFAULT_ENDPOINT, deviceID)
		initVar(MYSID, COMMANDS_UNLOCK, DEFAULT_ENDPOINT, deviceID)

		-- set at first run, then make it configurable
		if luup.attr_get("category_num", deviceID) == nil then
			local category_num = 7
			luup.attr_set("category_num", category_num, deviceID) -- security sensor
		end

		-- watches
		-- external sensor
		local sensorDeviceID = tonumber((initVar(MYSID, "SensorDeviceID", 0, deviceID)))
		if sensorDeviceID > 0 then
			local currentStatus = getVarNumeric(SECURITYSID, "Tripped", 0, sensorDeviceID)
			D(deviceID, "Sensor startup sync: %1 - #%2", currentStatus, sensorDeviceID)
			setVar(LOCKSID, "Status", currentStatus, deviceID)
			setVar(MYSID, "DoorLockDeviceID", deviceID, sensorDeviceID) -- save door lock ID in the device sensor, to handle callbacks

			luup.variable_watch("virtualDoorLockWatchSync", SECURITYSID, "Tripped", sensorDeviceID)
		end

		setVar(HASID, "Configured", 1, deviceID)
		setVar(HASID, "CommFailure", 0, deviceID)

		-- status
		luup.set_failure(0, deviceID)

		D(devNum, "Plugin start (completed): child #%1", deviceID)
	end

	return true, "Ready", _PLUGIN_NAME
end