# Virtual HTTP Devices plug-in for Vera and openLuup
This plug-in intented to provide support for Virtual Devices that performs their actions using HTTP calls.

It's intended to be used with Tasmota, Shelly or any similar device, or with a companion hub (Home Assistant, domoticz, Zway Server, etc).
This could be used to simulate the entire set of options, still using a native interface and native services, with 100% compatibility to external plug-ins or code.

Partially based with permission on [Yeelight-Vera](https://github.com/toggledbits/Yeelight-Vera) by Patrick Rigney (aka toggledbits).

# Installation via MiOS App Store
The files are available via MiOS App Store. Plug-in ID is 9281 if you want to install it manually.

Go to your Vera web interface, then Apps, Install Apps and search for "Virtual HTTP Light Devices (Switch, Dimmer, RGB)". Click Details, then Install.

# Manual Installation
To install, simply upload the files in this directory (except readme) using Vera's feature (Go to *Apps*, then *Develop Apps*, then *Luup files* and select *Upload*) and then create a new device under Vera.
App Store is recommended for stable version, but you'll find new features on GitHub first.

# Async HTTP support (version 1.5+)
Version 1.5 introduced support for async HTTP calls. This will make your device faster, because it's not blocking until the HTTP call is completed.
This is supported out of the box on openLuup.

Just download [this file](https://github.com/akbooer/openLuup/blob/master/openLuup/http_async.lua) if you're running this plug-in on Vera, and copy it with the plug-in files.

Async HTTP is strongly recommended. The plug-in will automatically detect it and use it if present, unless curl commands are specified.

# Async update of device's status
Version 2.0 introduced support for async updates of device's commands.

If you want to automatically acknowledge the command, simply return a status code from 200 (included) to 400 (excluded). That's what devices will do anyway.

If you want to control the result, simply return a different status code (ie 112) and then update the variable on your own via Vera/openLuup HTTP interface.

This is useful if you have an API that supports retry logic and you want to reflect the real status of the external devices.

This features doesn't work with curl commands.

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

Be sure to start your command URL with *curl://*, then write your curl arguments. Be sure to test it via command line to be sure it'll work.

# Create a new device
To create a new device, got to Apps, then Develops, then Create device.

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

[More info here.](http://wiki.micasaverde.com/index.php/Luup_Device_Categories)

### Dimmers
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualDimmableLight1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_DimmableLight1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualBinaryLight1.xml*

|Device Type|Category|Subcategory|
|---|---|---|
|Bulb|2|1|
|Plugged|2|2|
|In wall|3|3|

[More info here.](http://wiki.micasaverde.com/index.php/Luup_Device_Categories)

### RGB(CCT) Lights
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualRGBW1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_DimmableRGBLight1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualRGBW1.xml*

If your light only supports RGB, please change variable *SupporteColor* to *R,G,B*. By default it's set to *W,D,R,G,B* to support white channels.
The device will be automatically configured to category 2, subcategory 4 (RGB).

### Heaters
- Upnp Device Filename/Device File (2.0+, master/children mode): *D_VirtualHeater1.xml*
- Upnp Device Filename/Device File (legacy mode): *D_Heater1.xml*
- Upnp Implementation Filename/Implementation file: *I_VirtualHeater1.xml*

The device will emulate a basic Heater, and turn on or off the associated device, translating this actions to a virtual thermostat handler.

Temperature setpoints are supported, but only as cosmetic feature. Experimental setpoints support is added.

External temperature sensor can be specified with *urn:bochicchio-com:serviceId:VirtualHeater1*/*TemperatureDevice*. If specified, the thermostat will copy its temperature from an external device. If omitted, you can update the corresponding variable of the thermostat using HTTP call or LUA code.

### Sensors (Door, Leak, Motion, Smoke, CO, Glass Break, Freeze or Binary Sensor)
- Upnp Device Filename/Device File:
	|Sensor Type|Filename|Device JSON|Category|Subcategory|
	|---|---|---|---|---|
	|Door sensor|*D_DoorSensor1.xml*|*D_DoorSensor1.json*|4|1|
	|Leak sensor|*D_LeakSensor1.xml*|*D_LeakSensor1.json*|4|2|
	|Motion sensor|*D_MotionSensor1.xml*|*D_MotionSensor1.json* or *D_MotionSensorWithTamper1.json* |4|3|
	|Smoke sensor|*D_SmokeSensor1.xml*|*D_SmokeCoSensor1.json* or *D_SmokeSensor1.json* or *D_SmokeSensorWithTamper1.json*|4|4|
	|CO sensor|*D_SmokeSensor1.xml*|*D_COSensor1.json* or *D_SmokeCoSensor1.json*|4|5|
	|Glass Break|*D_MotionSensor1.xml*|*D_GlassBreakSensor.json* or *D_GlassBreakSensorWithTamper.json*|4|6|
	|Freeze Break|*D_FreezeSensor1.xml*|*D_FreezeSensor1.json*|4|7|
	|Binary sensor (not really implemented)|*D_MotionSensor1.xml*|*D_MotionSensor1.json*|4|8|
	|Doorbell|*D_Doorbell1.xml*|*D_Doorbell1.json*|30|0|
- Upnp Implementation Filename/Implementation file: *I_VirtualGenericSensor1.xml*

Subcategory number must be changed manually as [reported here](http://wiki.micasaverde.com/index.php/Luup_Device_Categories).

Some categories share the device file, and a JSON implementation must be manually specified, according to the previous table. It's usually possibile after a reload. Another reaload is necessary after the JSON file is changed.

Support for master devices is not ready yet.

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

See [docs](http://wiki.micasaverde.com/index.php/Luup_Devices) for more

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
AltUI friendly, with two lines showing the status.

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

**Attention**: due to the way scene controllers are implemented under openLuup, this device will not trigger scenes under this system.

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
*Attention: do not include %20 in your URL, this will cause problems.*

To turn ON, set *SetPowerURL* variable to the corresponding HTTP call.
 - For Tasmota: ```http://mydevice/cm?cmnd=Power+On```
 - For Shelly: ```http://mydevice/relay/0?turn=on```

To turn OFF, set *SetPowerOffURL* variable to the corresponding HTTP call.
 - For Tasmota: ```http://mydevice/cm?cmnd=Power+Off```
 - For Shelly: ```http://mydevice/relay/0?turn=off```

You can also specify only *SetPowerURL*, like this: ```http://mydevice/cm?cmnd=Power+%s```
The %s parameter will be replace with On/Off (this very same case), based on the required action.

#### Toggle (All)
Set *SetToggleURL* variable to the corresponding HTTP call.
- For Tasmota: ```http://mydevice/cm?cmnd=Power+Toggle```
- For Shelly: ```http://mydevice/relay/0?turn=toggle```

No params required.
If omitted (blank value or 'http://'), the device will try to change the status according to the local current status. (1.5.1+).

#### Dimming (Dimmers, RGB Lights, Window Covers/Roller Shutters/Blinds)
Set *SetBrightnessURL* variable to the corresponding HTTP call.
- For a custom device: ```http://mydevice/brigthness?v=%s```

The %s parameter will be replace with the desired dimming (0/100). Leave 'http://' if not supported.

#### Color (RGB Lights)
Set *SetRGBColorURL* variable to the corresponding HTTP call.
- For a custom device: ```http://mydevice/setcolor?v=%s```

The %s parameter will be replace with the RBG color.

#### White Temperature (RGB Lights)
Set *SetWhiteTemperatureURL* variable to the corresponding HTTP call.
 - For a custom device: ```http://mydevice/setwhitemode?v=%s```

The %s parameter will be replace with temperature (from 2000 to 6500 k). Leave 'http://' if not supported.

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

#### Alarms
Set *SetRequestArmModeURL* variable to the corresponding HTTP call to change the alarm state.
 - For a custom device: ```http://mydevice/alarm/state?state=%s&pincode=%s```

Set *SetRequestPanicModeURL* variable to the corresponding HTTP call to request panic mode.
 - For a custom device: ```http://mydevice/alarm/panic?state=%s```

Your script should update the variables *Alarm*, *AlarmMemory*, *LastAlarmActive*, *LastUser*, *VendorStatus*, *VendorStatusCode* and *VendorStatusData* if necessary, via standard LUUP HTTP call/code.

### Power consumption (Lights only, 2.1+)
It's now possible to poll an endpoint and extract power consumption.
- *SetUpdateMetersURL:* the URL to poll. For Shelly it's: ```http://mydevice/status```
- *MeterUpdate*: how frequently you want to poll. 60 seconds by default.
- *MeterPowerFormat*: the JSON (LUA) path to get the instant power. It's *"meters[1].power* for the first relay in a Shelly.
- *MeterTotalFormat*: the JSON (LUA) path to get the total consumption. It's *"meters[1].total* for the first relay in a Shelly.

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

This handler is intended to turn a switch on/off, but can be adapted for other variables as well.

### Ping device for status
If you want to ping a device and have its status associated to the device, you can write a simple scene like this, to be executed every *x* minutes.

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
- *Attention: do not include %20 in your URL, this will cause problems. It is usually safe to replace with +, in case of %20.*

### Support
If you need more help, please post on Vera's forum and tag me (@therealdb).

https://community.getvera.com/t/virtual-http-light-devices-supporting-rgb-ww-dimmers-switch-and-much-more-tasmota-esp-shelly/209297
