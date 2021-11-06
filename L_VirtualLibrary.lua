------------------------------------------------------------------------
-- Copyright (c) 2019-2021 Daniele Bochicchio
-- License: MIT License
-- Source Code: https://github.com/dbochicchio/Vera-VirtualDevices
------------------------------------------------------------------------

module("L_VirtualLibrary", package.seeall)

_PLUGIN_NAME = "VirtualDevices"
_PLUGIN_VERSION = "3.0-beta5"

DEFAULT_ENDPOINT						= "http://"
local MYSID								= ""
local HASID								= "urn:micasaverde-com:serviceId:HaDevice1"

openLuup = false
local debugMode = false

function dump(t, seen)
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

function getVarNumeric(sid, name, dflt, devNum)
	local s = luup.variable_get(sid, name, devNum) or ""
	if s == "" then return dflt end
	s = tonumber(s)
	return (s == nil) and dflt or s
end

function getVar(sid, name, dflt, devNum)
	local s = luup.variable_get(sid, name, devNum) or ""
	if s == "" then return dflt end
	return (s == nil) and dflt or s
end

function L(devNum, msg, ...) -- luacheck: ignore 212
	local str = string.format("%s[%s@%s]", _PLUGIN_NAME, _PLUGIN_VERSION or 'dev', devNum or -1)
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

function D(devNum, msg, ...)
	debugMode = getVarNumeric(MYSID, "DebugMode", 0, devNum) == 1

	if debugMode then
		local t = debug.getinfo(2)
		local pfx = string.format("(%s@%s)", t.name or "", t.currentline or "")
		L(devNum, {msg = msg, prefix = pfx}, ...)
	end
end

-- Set variable, only if value has changed.
function setVar(sid, name, val, devNum)
	val = (val == nil) and "" or tostring(val)
	local s = luup.variable_get(sid, name, devNum) or ""
	D(devNum, "setVar(%1,%2,%3,%4) old value %5", sid, name, val, devNum, s)
	if s ~= val then
		luup.variable_set(sid, name, val, devNum)
		return true, s
	end
	return false, s
end

function split(str, sep)
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

function trim(s)
	if s == nil then return "" end
	if type(s) ~= "string" then s = tostring(s) end
	local from = s:match "^%s*()"
	return from > #s and "" or s:match(".*%S", from)
end

function round(num, numDecimalPlaces)
	local mult = 10 ^ (numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

-- Array to map, where f(elem) returns key[,value]
function map(arr, f, res)
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

function initVar(sid, name, dflt, devNum)
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

function getChildren(masterID)
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

function sendDeviceCommand(MYSID, cmd, params, devNum, onSuccess)
	D(devNum, "sendDeviceCommand(%1,%2,%3)", cmd, params, devNum)

	local cmdUrl = getVar(MYSID, cmd, DEFAULT_ENDPOINT, devNum)

	-- params
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

	-- SKIP command, just update variables
	if (cmdUrl:lower() == "skip") then
		L(devNum, "sendDeviceCommand: skipped")
		onSuccess("skip")
		return true
	elseif cmdUrl:lower():find("^mqtt://") then
		L(devNum, "sendDeviceCommand: mqtt - %1", openLuup)
		-- EXPERIMENTAL! openLuup only!
		if openLuup then
			-- format is topic/=/message
			local topic, payload = cmdUrl:gsub("^mqtt://", "") :match "^(.-)/=/(.+)"
			payload = string.format(payload, pstr)
			D(devNum, "sendDeviceCommand.mqtt - Topic: %1 - Payload: %2", topic, payload)

			local mqtt = require "openLuup.mqtt"
			mqtt.publish(topic, payload)
			
			onSuccess('mqtt')
		else
			deviceMessage(devNum, "This feature requires openLuup", true, 0)
		end
		return true
	elseif cmdUrl:lower():find("^lua://") then
		-- EXPERIMENTAL!
		local code = cmdUrl:gsub("^lua://", "")
		L(devNum, "sendDeviceCommand: RunLua: %1", code)
		luup.call_action("urn:micasaverde-com:serviceId:HomeAutomationGateway1", "RunLua", {code = code}, 1)
		onSuccess("lua")
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

function _G.virtualDeviceMQTTHandler(w, payload, args)
	D(args.deviceID, "virtualDeviceMQTTHandler(%1,%2,%3)", w, payload, args)
	local opts = args.opts

	local path, valueToMatch = args.payload :match "^(.-)/=/(.+)"

	if path ~= nil and valueToMatch ~= nil then -- check for payload and a value to match
		D(devNum, "virtualDeviceMQTTHandler: processing %1, %2", path, valueToMatch)

		local json = require "dkjson"
		local data = json.decode(payload)
		local x = data or ""
		for field in path: gmatch "[^%.%[%]]+" do
			if x ~= nil and field ~= nil then
				x = x[tonumber(field) or field]
			end
		end
		local matchedValue = x or ""
		
		D(devNum, "virtualDeviceMQTTHandler: got %1", matchedValue)
		if matchedValue == valueToMatch or valueToMatch == "*" then
			D(devNum, "virtualDeviceMQTTHandler: matched %1", valueToMatch == "*" and matchedValue or opts.Value)
			setVar(opts.Service, opts.Variable, valueToMatch == "*" and matchedValue or opts.Value, args.deviceID)
		end
	elseif payload == args.payload or args.payload == "*" then -- check for payload, or just update with the value
		D(devNum, "virtualDeviceMQTTHandler: processing %1", args.topic)
		setVar(opts.Service, opts.Variable, opts.Value or payload, args.deviceID)
	else
		D(devNum, "virtualDeviceMQTTHandler: ignored %1", args.topic)
	end
end

function subscribeToMqtt(devNum, opts)
	--local mqtt = require "openLuup.mqtt"
	D(devNum, "subscribeToMqtt(%1,%2,%3)", devNum, opts.topic, opts)
	luup.register_handler("virtualDeviceMQTTHandler", "mqtt:" .. opts.topic, opts)
end

function initializeMqtt(devNum, opts)
	D(devNum, "initializeMqtt(%1,%2) - openLuup: %3", devNum, opts, openLuup)
	if not openLuup then return end -- openLuup only

	-- [COMMANDS_SETPOWER] = { Service = SWITCHSID, Variable = "Status" },
	for name, item in next, opts do
		local mqttCommand = initVar(item.Service, "MQTT_" .. name, '', devNum)
		if mqttCommand ~= nil and mqttCommand ~= "" then
			local topic, payload = mqttCommand:gsub("^mqtt://", "") :match "^(.-)/=/(.+)"
			subscribeToMqtt(devNum, {opts = item, deviceID = devNum, topic = topic, payload = payload })
		end
	end
end

function startup(devNum, sid)
	MYSID = sid
	L(devNum, "Plugin starting")
	deviceMessage(devNum, "Starting...", false, 5)

	-- detect OpenLuup
	for k,v in pairs(luup.devices) do
		if v.device_type == "openLuup" then
			openLuup = true
		end
	end
end