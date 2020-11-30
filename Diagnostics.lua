-- DIANGOSTICS
-- Use this file to see your configuration and get some warning about the configuration
-- Go to http://VeraIP/cmh/#develop_apps, copy this code, excute and see results into logs
-- http://VeraIP/cgi-bin/cmh/log.sh?Device=LuaUPnP

for deviceID, v in pairs(luup.devices) do
	local deviceType = luup.attr_get("device_file", deviceID) or ""
	local impl_file = luup.attr_get("impl_file", deviceID) or ""

	if	deviceType == "D_DimmableLight1.xml" or 
		deviceType == "D_VirtualDimmableLight1.xml" or
		deviceType == "D_VirtualAlarmPartition1.xml" or
		deviceType == "D_VirtualDoorLock1.xml" or
		deviceType == "D_VirtualHeater1.xml" or
		deviceType == "D_VirtualRGBW1.xml" or
		deviceType == "D_VirtualRGBW2.xml" or
		deviceType == "D_VirtualSceneController1.xml" or
		deviceType == "D_VirtualDoorSensor1.xml" or
		deviceType == "D_VirtualSmokeSensor1.xml" or
		deviceType == "D_VirtualFloodSensor1.xml" or
		deviceType == "D_VirtualFreezeSensor1.xml" or
		deviceType == "D_VirtualWindowCovering1.xml" or
		-- impl_file
		impl_file == "I_VirtualBinaryLight1.xml" or
		impl_file == "I_VirtualRGBW1.xml" or
		impl_file == "I_VirtualHeater1.xml" or
		impl_file == "I_VirtualGenericSensor1" or
		impl_file == "I_VirtualDoorLock1.xml" or
		impl_file == "I_VirtualAlarmPartition1.xml" or
		impl_file == "I_VirtualSceneController1.xml"
		then

		local parentID = luup.attr_get("id_parent", deviceID)
		local debugMode = 0 -- TODO

		-- warnings
		local warning = ""
		if parentID ~= "0" and #impl_file>0 then
			warning = warning .. 'Parent ID specified, please remove impl_file attr / '
		end

		if parentID == "0" and not impl_file:lower():find("^i_virtual") then
			warning = warning .. 'impl_file should be set to the virtual one / '
		end

		luup.log('Virtual Device #' .. tostring(deviceID) .. ' - ' .. luup.devices[deviceID].description .. ' - Parent: ' .. tostring(parentID) .. ' - impl_file: ' .. impl_file .. ' - DebugMode: ' .. debugMode .. ' - Warning: ' .. (warning ~= "" and warning or "none"))
	end
end