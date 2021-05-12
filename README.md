# Virtual Devices plug-in for Vera and openLuup
This plug-in intented to provide support for Virtual Devices that performs their actions using HTTP calls, lua code or MQTT messages (openLuup only).

It's intended to be used with Tasmota, Shelly or any similar device, or with a companion hub (Home Assistant, domoticz, Zway Server, etc).
This could be used to simulate the entire set of options, still using a native interface and native services, with 100% compatibility to external plug-ins or code.

RGB virtual devices are partially based with permission on [Yeelight-Vera](https://github.com/toggledbits/Yeelight-Vera) by Patrick Rigney (aka rigpapa on Vera's forums).

# Installation via MiOS App Store
The files are available via MiOS App Store. Plug-in ID is 9281 if you want to install it manually.

Go to your Vera web interface, then Apps, Install Apps and search for "Virtual Devices". Click Details, then Install.

# Manual Installation
To install, simply upload the files in the release package, using Vera's feature (Go to *Apps*, then *Develop Apps*, then *Luup files* and select *Upload* - multiple files can be selected when uploading).
To create a new device under Vera, go to *Apps*, then *Develop Apps* and *Create device*. See later for instructions on how to insert the values.

If you're under openLuup, you'd already know how to do ;)

App Store is recommended for stable version, but you'll find new features on GitHub first.

# Async HTTP support (version 1.5+)
Version 1.5 introduced support for async HTTP calls. This will make your device faster, because it's not blocking until the HTTP call is completed.
This is supported out of the box on openLuup.

Just download [this file](https://github.com/akbooer/openLuup/blob/master/openLuup/http_async.lua) if you're running this plug-in on Vera, and copy it with the plug-in files.

> **Remarks**: async HTTP is strongly recommended. The plug-in will automatically detect it and use it if present, unless curl commands are specified.

# Async update of device's status
Version 2.0 introduced support for async updates of device's commands.

If you want to automatically acknowledge the command, simply return a status code from 200 (included) to 400 (excluded). That's what devices will do anyway.

If you want to control the result, simply return a different status code (ie 112) and then update the variable on your own via Vera/openLuup HTTP interface.

This is useful if you have an API that supports retry logic and you want to reflect the real status of the external devices.

> **Remarks**: this feature doesn't work with curl commands.

# curl support (version 2.1+)
Starting from version 2.1, curl commands are supported. This means you can send POST/PUT/whatever calls you need, send cookies, headers and much more. [Please refer to curl manual for syntax](https://curl.haxx.se/docs/manual.html).

All commands are supportting this new syntax, but it's not automatically applied unless you'll need it.

Here's an example of POSTing to a form (this should be set in the corresponding command variables):
```
curl://-d 'param1=value1&param2=value2' -H 'Content-Type: application/x-www-form-urlencoded' -X POST 'http://localhost:1234/data'
```

or sending a JSON payload via POST:

```
curl://-d '{"key1":"value1", "key2":"value2"}' -H 'Content-Type: application/json' -X POST 'http://localhost:1234/data'
```

Be sure to start your command URL with *curl://*, then write your curl arguments. Be sure to test it via command line to be sure it'll work. All the commands are supported.

# Lua Code support (version 2.4+)
You can also specify lua code as an action to be executed.

Use this format:

```
lua://yourluacode()
```

This is useful to execute code in your libraries. All the commands are supported.

# MQTT support (version 3.0+)
Starting with version 3.0, MQTT messages could be triggered, on openLuup only (be sure to install the latest development version od openLuup).

Use this format:
```
mqtt://topic/=/message
```

If:
- your command topic is *shellies/myshelly/relay/0/command*
- your topic value is *on*

just use:

```
mqtt://shellies/myshelly/relay/0/command/=/on
```

All the commands are supported on all devices.

## MQTT Status
Status from MQTT message is supported as well, and on openLuup only.

Look for *MQTT_* variables and insert something like this:

```
payload/=/value
```

If you specify this value:

```
shellies/shelly-rain/input/0/+/0
```

you can set the corresponding status when a message in topic *shellies/shelly-rain/input/0/* is sent with a value of *0*.

To pass the value to the corresponding variable, just specificy "*" as *value*.

Here's an example to get the value from a topic:

```
shellies/shelly-rain/ext_temperature/0/+/*
```

# Multiple calls per action (version 2.2+)
Starting from version 2.2, multiple calls per action could be specified. Just specifiy each command in its own line.

On AltUI use code to modify it (UI doesn't support multi-line values). openLuup devices console and Vera are OK.

You can specify only HTTP calls.

> Remarks: multiple commands will slow down your system. Do not exceed 3-4 commands per action. Async HTTP are strongly suggested, because they will not block the execution and nicely run in parallel.

# Create a new device
To create a new device, open your Vera web GUI, go to *Apps*, then *Develop Apps*, then *Create device*.

Every time you want a new virtual device, just repeat this operation.

This plug-ins support different kind of virtual devices, so choose the one you want to use and follow this guide.

### Switches, Lights, Garage Doors
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualBinaryLight1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_BinaryLight1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualBinaryLight1.xml*

Many different devices could be mapped with this service.

|Device Type|Category|Subcategory|
|---|---|---|
|Interior|3|1|
|Exterior|3|2|
|In Wall|3|3|
|Refrigerator|3|4|
|Doorbell (legacy)|3|5|
|Garage door (legacy)|3|6|
|Water Valve|3|7|
|Relay|3|8|
|Garage Door|32|8|

> **Remarks**: [More info are here.](http://wiki.micasaverde.com/index.php/Luup_Device_Categories)

### Dimmers
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualDimmableLight1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_DimmableLight1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualBinaryLight1.xml*

|Device Type|Category|Subcategory|
|---|---|---|
|Bulb|2|1|
|Plugged|2|2|
|In wall|3|3|

> **Remarks**: [More info are here.](http://wiki.micasaverde.com/index.php/Luup_Device_Categories)

### RGB(CCT) Lights
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualRGBW1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_DimmableRGBLight1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualRGBW1.xml*

> **Remarks**: if your light only supports RGB, please change *SupportedColor* variable to *R,G,B*. By default it's set to *W,D,R,G,B* to support white channels.
> The device will be automatically configured to category 2, subcategory 4 (RGB).

### Heaters
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualHeater1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_Heater1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualHeater1.xml*

The device will emulate a basic Heater, and turn on or off the associated device, translating this actions to a virtual thermostat handler.

Temperature setpoints are supported, but only as cosmetic feature. Experimental setpoints support is added.

> **Remarks**: An external temperature sensor could be specified with *urn:bochicchio-com:serviceId:VirtualHeater1*/*TemperatureDevice*. If specified, the thermostat will copy its temperature from an external device. If omitted, you can update the corresponding variable of the thermostat using HTTP call or LUA code.

### Sensors (Door, Leak, Motion, Smoke, CO, Glass Break, Freeze or Binary Sensor)
- Upnp Device Filename/Device File:
	|Sensor Type|Filename|Device JSON|Category|Subcategory|
	|---|---|---|---|---|
	|Door sensor|*D_VirtualDoorSensor1.xml*|*D_DoorSensor1.json*|4|1|
	|Leak sensor|*D_VirtualFloodSensor1.xml*|*D_FloodSensor1.json*|4|2|
	|Motion sensor|*D_VirtualMotionSensor1.xml*|*D_MotionSensor1.json* or *D_MotionSensorWithTamper1.json* |4|3|
	|Smoke sensor|*D_VirtualSmokeSensor1.xml*|*D_SmokeCoSensor1.json* or *D_SmokeSensor1.json* or *D_SmokeSensorWithTamper1.json*|4|4|
	|CO sensor|*D_VirtualSmokeSensor1.xml*|*D_COSensor1.json* or *D_SmokeCoSensor1.json*|4|5|
	|Glass Break|*D_VirtualMotionSensor1.xml*|*D_GlassBreakSensor.json* or *D_GlassBreakSensorWithTamper.json*|4|6|
	|Freeze Break|*D_FreezeSensor1.xml*|*D_FreezeSensor1.json*|4|7|
	|Binary sensor (not really implemented)|*D_VirtualMotionSensor1.xml*|*D_MotionSensor1.json*|4|8|
- Upnp Implementation Filename/Implementation file: *I_VirtualGenericSensor1.xml*

Subcategory number must be changed manually as [reported here](http://wiki.micasaverde.com/index.php/Luup_Device_Categories).

```
luup.attr_set("subcategory_num", "2", deviceID)
```

> **Remarks**: Some categories share the device file, and a JSON implementation must be manually specified, according to the previous table. It's usually possibile after a reload. Another reaload is necessary after the JSON file is changed.

### Other sensors: Temperature, Humidity, UV, Generic Sensor
Generic level sensor, such as temperature, humidity, UV and the generic sensor itself, don't need a specific plug-in to work as virtual devices, because no actions are executed by those devices.

You can set the corresponding variables via HTTP and create the logic corresponding to the changes in your Luup environement (code, scenes, etc).

Here's an example for a virtual temperature device:
- Upnp Device Filename/Device File: *D_TemperatureSensor1.xml*
- Upnp Implementation Filename/Implementation file: *I_TemperatureSensor1.xml*

Then update your device's with a call similar to this:

```
http://*veraip*:3480/data_request?id=variableset&DeviceNum=6&serviceId=urn:upnp-org:serviceId:TemperatureSensor1&Variable=CurrentTemperature&Value=24.5
```

See [docs](http://wiki.micasaverde.com/index.php/Luup_Devices) for more.

### Window Covers/Roller Shutters/Blinds
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualWindowCovering1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_WindowCovering1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualBinaryLight1.xml*

The device will be automatically configured to category 8, subcategory 1 (Window Covering).

### Door Locks (2.1+)
- Upnp Device Filename/Device File (2.1+, master/children mode): *D_VirtualDoorLock1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualDoorLock1.xml*

External status can be specified via *SensorDeviceID* and must be a security device ID (a virtual one is OK). If omitted, status will be reflected by the door actions (ie: open the lock will set it to open).
This could be used with Vera's/openLuup's devices (switch+sensor) to combine into a single door lock device. Just insert standard luup HTTP call to turn on/off the switch.

### Alarm Partitions (2.1+)
- Upnp Device Filename/Device File (2.1+, master/children mode): *D_VirtualAlarmPartition1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualAlarmPartition1.xml*

This is standard alarm partition, implementing *urn:schemas-micasaverde-com:service:AlarmPartition:2*.

A simplified device template file is offered via *D_VirtualAlarmPartition2.json*, if you just want to mirror your alarm's status with no actions on the UI.
This device file is AltUI friendly, with two lines showing the status.

#### Commands
 - *RequestArmMode*: *State* (see *DetailedArmMode* variable), *PINCode*
 - *RequestQuickArmMode*: *State* (see *DetailedArmMode* variable)
 - *RequestPanicMode*: *State*

#### Variables
- *DetailedArmMode*: any of *Armed*, *ArmedInstant*, *Stay*, *StayInstant*, *Night*, *NightInstant*, *Force*, *Ready*, *Vacation*, *NotReady*, *FailedToArm*, *EntryDelay*, *ExitDelay*
- *ArmMode*: *Armed* or *Disarmed*
- *Alarm*: *None* or *Active* (alarm triggered)
- *AlarmMemory*: boolean (true if alarm occurred, false if no alarm or cleared)
- *LastAlarmActive*: last alarm as epoch
- *LastUser*: last user who last initiated a command against the partition
- *VendorStatus*: a custom status
- *VendorStatusCode*: a custom code
- *VendorStatusData*: custom data

### Scene Controllers (2.0+)
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualSceneController1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualSceneController1.xml*

This defaults to 3 buttons with single, double, triple press support, but you can modify it. Look for [official doc](http://wiki.mios.com/index.php/Luup_UPnP_Variables_and_Actions#SceneController1) for more info.
This device will not perform any action, but just receive input from an external device to simulate a scene controller, attached to scenes.

> **Attention**: due to the way scene controllers are implemented under openLuup, this device will not trigger scenes under this system.

### Configuration
All devices are auto-configuring. At its first run, the code will create all the variables and set the category/sub_category numbers, for optimal compatibility. 

To configure a virtual device, just enter its details, then go to Advanced and select Variables tab.

In order to configure a device, you must specify its remote HTTP endpoints. Those vary depending on the device capabilities, so search for the corresponding API. As with any HTTP device, a static IP is recommended. Check your device or router for instruction on how to do that.

### Master Devices vs legacy mode (version 2.0+)
If you're running the plug-in on openLuup, chooosing between an indipendent device (legacy mode) configuration or a master/children configuration doesn't really matter.

On Vera luup engine, instead, a master/children configuration will save memory (this could be a lot of memory, depending on how many devices you have).

If you've already created your devices with a previous version, choose one as the master (it doesn't matter which one), and get its ID. Be sure to use the new D_Virtual*.xml files as device_file parameter.

Go to every device you want to adopt as children, and
 - change *device_file* to the new *D_Virtual\*.xml* version
 - remove *impl_file* attribute (it's not used) on every child
 - set *id_parent* to your master ID

Do a *luup.reload()* and you should be good to go.

This procedure is similar if you want to create new child for a given master.

There's no limit to how many children a master could handle.

It's suggested to have one master per controller and how many children you want.

#### Switch On/Off (All)

> **Attention: `%` in your URL must be escaped, so you need to double them. ie `Power%20On` must be set as `Power%%20On`.*

To turn ON, set *SetPowerURL* variable to the corresponding HTTP call.
 - For Tasmota: ```http://mydevice/cm?cmnd=Power+On```
 - For Shelly: ```http://mydevice/relay/0?turn=on```

To turn OFF, set *SetPowerOffURL* variable to the corresponding HTTP call.
 - For Tasmota: ```http://mydevice/cm?cmnd=Power+Off```
 - For Shelly: ```http://mydevice/relay/0?turn=off```

You can also specify only *SetPowerURL*, like this: ```http://mydevice/cm?cmnd=Power+%s```
The *%s* parameter will be replace with *On*/*Off* (this very same case), based on the required action.

#### AutoOff (Dimmers, RGB lights, Window Covers/Roller Shutters/Blinds) (v 2.3+)

You can now specify an auto off timer (in seconds) to automatically turn off a light after a given amount of time.
The corresponding variable is *AutoOff*.

If you want to implement auto inching and you don't need to call the Off endpoint, just specify `skip` as *SetPowerOffURL* variable.
This will just update the status and no HTTP calls will be made.

#### Toggle (All)
Set *SetToggleURL* variable to the corresponding HTTP call.
- For Tasmota: ```http://mydevice/cm?cmnd=Power+Toggle```
- For Shelly: ```http://mydevice/relay/0?turn=toggle```

No params required.
If omitted (blank value or `http://`), the device will try to change the status according to current local status as reported by *Status* variable. (1.5.1+).

#### Dimming (Dimmers, RGB Lights, Window Covers/Roller Shutters/Blinds)
Set *SetBrightnessURL* variable to the corresponding HTTP call.
- For a custom device: ```http://mydevice/brigthness?v=%s```

The %s parameter will be replaced with the desired dimming (0/100) value. Leave `http://` or blank if not supported.

##### Binary Window Covers/Roller Shutters/Blinds (2.40+)
If you want to emulate a Window Cover/Roller Shutter/Blind but your device is supporting only ON/OFF commands, simply leave *SetBrightnessURL* to its default (`http://`).

Then go to the device's variable and set *BlindAsSwitch* to 1. The device will now work as follows:
- when position is set to a value between 0 and 50, or down/close buttons are pressed, the switch off command is sent
- when position is set to a value between 51 and 100, or up/open buttosn are pressed, the switch off command is sent

#### Color (RGB Lights)
Set *SetRGBColorURL* variable to the corresponding HTTP call.
- For a custom device: ```http://mydevice/setcolor?v=%s```

The %s parameter will be replace with the RBG color.

#### White Temperature (RGB Lights)
Set *SetWhiteTemperatureURL* variable to the corresponding HTTP call.
 - For a custom device: ```http://mydevice/setwhitemode?v=%s```

The %s parameter will be replace with temperature (from 2000 to 6500 k). Leave `http://` or blank if not supported

#### Sensors
- Set *SetTrippedURL* variable to the corresponding HTTP call (to trip).
- Set *SetUnTrippedURL* variable to the corresponding HTTP call (to untrip).
- Set *SetArmedURL* variable to the corresponding HTTP call (to arm).
- Set *SetUnArmedURL* variable to the corresponding HTTP call (to disarm).

For a custom device: ```http://mydevice/tripped?v=%s```

The *%s* parameter will be replace with status (1 for active, 0 for disabled). You can omit it from the URL if you want.

Device can be armed/disarmed via UI, and tripped/untripped via HTTP similar to this:

```
http://*veraip*/port_3480/data_request?id=variableset&DeviceNum=6&serviceId=urn:micasaverde-com:serviceId:SecuritySensor1&Variable=Tripped&Value=*1*
```

where *value* is *1* when tripped, *0* when untripped.

#### Stop (Window Covers/Roller Shutters/Blinds)
Set *SetMoveStopURL* variable to the corresponding HTTP call.
 - For a custom device: ```http://mydevice/stop```

No parameters are sent.

#### Setpoint for Heaters
Set *SetSetpointURL* variable to the corresponding call to change the setpoint for your heater.
 - For a custom device: ```http://mydevice/heater/temperature?v=%s```

#### Alarms
Set *SetRequestArmModeURL* variable to the corresponding call to change the alarm state.
 - For a custom device: ```http://mydevice/alarm/state?state=%s&pincode=%s```

Set *SetRequestPanicModeURL* variable to the corresponding call to request panic mode.
 - For a custom device: ```http://mydevice/alarm/panic?state=%s```

Your script should update the variables *Alarm*, *AlarmMemory*, *LastAlarmActive*, *LastUser*, *VendorStatus*, *VendorStatusCode* and *VendorStatusData* if necessary, via standard luup HTTP call/code.

### Power consumption (Lights only, 2.1+)
It's now possible to poll an endpoint and extract power consumption and instant power.

Each device support a single meter endpoint. Create multiple devices to track multiple endpoints.

Options:
- *SetUpdateMetersURL:* the URL to poll. For Shelly it's: ```http://mydevice/status``` or ```http://mydevice/meters``` or ```http://mydevice/emeters``` (try it in a browser before and choose the one giving you the best results).
- *MeterUpdate*: how frequently you want to poll. 60 seconds by default.
- *MeterPowerFormat*: the JSON (LUA) path to get the instant power (in Watts). It's *meters[1].power* for the first relay in a Shelly. If you're calling */meters/0*, *power* could be specified as well. Change your index accordingly for multi-meters devices.
- *MeterTotalFormat*: the JSON (LUA) path to get the total consumption (KWH). It's *meters[1].total* for the first relay in a Shelly. If you're calling */meters/0*, *total* could be specified as well. Change your index accordingly for multi-meters devices.
- *MeterTotalUnit*: *0* if is the device is reporting KWH, *1* if Watt-minute (Shelly Plug, 2, EM, etc), *2* if Watt-hour (Shelly 3EM). Options 1 and 2 are specifically created for Shellies. Use 0 if your device is reporting KWH.

### Update your Vera/openLuup status
This integration is useful when the Vera system is the primary and only controller for your remote lights.
It's possible to sync the status, using standard Vera calls. The example is for RGB:

```
http://*veraip*:3480/data_request?id=variableset&DeviceNum=6&serviceId=urn:micasaverde-com:serviceId:Color1&Variable=CurrentColor&Value=0=0,1=0,2=255,3=0,4=0
http://*veraip*/port_3480/data_request?id=variableset&DeviceNum=6&serviceId=urn:micasaverde-com:serviceId:Color1&Variable=CurrentColor&Value=0=0,1=0,2=255,3=0,4=0
```

If you cannot use a long URL like this, you can place a custom handler in your startup code:
```
 -- http://ip:3480/data_request?id=lr_updateSwitch&device=170&status=0
function lr_updateSwitch(lul_request, lul_parameters, lul_outputformat)
	local devNum = tonumber(lul_parameters["device"], 10)
	local status = tonumber(lul_parameters["status"] or "0")
	luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", status or "1", devNum)
end

luup.register_handler("lr_updateSwitch", "updateSwitch")
```

This can be called with a short URL like this:
```
http://*veraip*:3480/data_request?id=lr_updateSwitch&device=214&status=0
```

> **Remarks**: this handler is intended to turn a switch on/off, but can be adapted for other variables as well.

### Update your Vera/openLuup status with Tasmota's rules
Tasmota has a rules engine and you use it directly to update virtual device in your Vera/openLuup.

It is possible to create up to three rules for each sensor, each with several `Do` stamements in each rule.

```
Rule<x> ON <trigger> DO <command> ENDON
```

It is very easy to find out the name of each sensor for using in the rules by looking at ```http://IP_address/cm?cmnd=Status%2010```

A rule is defined by pasting the rule to the Console window of the sensor.
After that the rule needs to be enabled by ```Rule1 1```, ```Rule2 1```, etc. A rule is deactivated by ```Rule1 0```, etc.
After enabling a rule, check in the console that the rule is sending values.
To see the contents of a rule just type ```Rule1```, ```Rule2```, etc.

Here's an example to update the temperature sensor via a rule, based on a AM3201 sensor.

```
Rule1 ON tele-AM2301#Temperature DO Var1 %value% ENDON ON tele-AM2301#Temperature DO WebSend http://veraIP:3480/data_request?id=lu_action&DeviceNum=*devID*&id=variableset&serviceId=urn:upnp-org:serviceId:TemperatureSensor1&Variable=CurrentTemperature&Value=%Var1% ENDON
```

Here's another one to update the switch status back in your luup system:

```
Rule1 
	ON Power1#State=1 do websend [veraIP:3480] /data_request?id=lu_action&DeviceNum=*devID*&id=variableset&serviceId=urn:upnp-org:serviceId:SwitchPower1&Variable=Status&Value=1 ENDON
	ON Power1#State=0 do websend [veraIP:3480] /data_request?id=lu_action&DeviceNum=*devID*&id=variableset&serviceId=urn:upnp-org:serviceId:SwitchPower1&Variable=Status&Value=0 ENDON
```

Be sure to insert both *devID* and *VeraIP* according to your settings

[More info on Tasmota docs.](https://tasmota.github.io/docs/Rules/)

### Ping device for status
If you want to ping a device and have its status associated to the virtual device, you can write a simple scene like this, to be executed every *x* minutes.

```
local function ping(address)
	local returnCode = os.execute("ping -c 1 -w 2 " .. address)

	if(returnCode ~= 0) then
		returnCode = os.execute("arping -f -w 3 -I br-wan " .. address)
	end

	return tonumber(returnCode)
end

local status = ping('192.168.1.42')
luup.set_failure(status, devID)
```

Where *devID* is the device ID and *192.168.1.42* is your IP address.

### openLuup/ALTUI
The devices are working and supported under openLuup and ALTUI. In this case, just be sure the get the base service file from Vera (it's automatic if you have the Vera Bridge installed).

### Known issues
- *Attention: `%` in your URL must be escaped, so you need to double them. ie `Power%20On` must be set as `Power%%20On`. It is usually safe to replace with `+`, in case of `%20`.*

### Support
Before asking for support, please:
 - change *DebugMode* variable to 1 (on the device itself, not on the master)
 - repeat your problem and capture logs
 - logs could be captured via SSH or by navigating to `http://VeraIP/cgi-bin/cmh/log.sh?Device=LuaUPnP`. [More Info](http://wiki.micasaverde.com/index.php/Logs)

If you need help, visit [SmartHome.Community](https://smarthome.community/) and tag me (therealdb).