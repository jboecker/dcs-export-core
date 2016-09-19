# Setup

* Copy the repository contents to `%USERPROFILE%\Saved Games\DCS\Scripts\export-core`
* Edit `C:\Program Files\Eagle Dynamics\DCS World\Scripts\Aircrafts\_Common\COCKPIT\KNEEBOARD\declare_kneeboard_device.lua` and append the following line:
````lua
creators[147] = {"avLuaDevice", lfs.writedir() .. "Scripts\\export-core\\ExportDevice.lua"}
````
* Edit or create `%USERPROFILE%\Saved Games\DCS\Scripts\Export.lua` and append the following line:
````lua
dofile(lfs.writedir()..[[Scripts\export-core\ExportCore.lua]])
````

# Ports and Device IDs

* Device ID 147 for the export device
* UDP 12823 on localhost to get data from device environment to Export.lua environment
* Export.lua sends to UDP mutlicast 239.255.50.10:12800
* Export.lua listens on TCP 12800 and UDP 12801

# Protocol
All communication happens over newline-separated JSON messages. To send a message to DCS, either send it in a UDP packet to localhost:12801 (make sure to add a newline to the end even if sending a single message) or open a TCP connection to localhost:12800 and send it over that.

To receive messages from DCS, listen to the multicast UDP stream (see DCS-BIOS developer guide for details) or open a TCP connection to localhost:12800.

The top-level data type is always a JSON object.

# Data Model
Every piece of data that is exported from DCS is assigned a key. Cockpit arguments start with "c", external draw model arguments start with "e", special keys start with "_".

Examples:
* `c404` is the Master Caution light in the A-10C
* `e182` is the right speed brake in the A-10C
* `_UNITTYPE` is the type of the currently active unit (the only "special" key right now). `_UNITTYPE` is always exported even if it did not change.

# Messages from DCS

## newdata
Example: `{"msg_type":"newdata", "data":{"_UNITTYPE":"A-10C","c404":0}}`

If the "msg_type" attribute is "newdata", the "data" attribute is an object that contains a key => value mapping of all keys that have changed since the last "newdata" event.

## new_unit
Example: `{"msg_type":"new_unit","type":"A-10C"}`

When a new unit is entered, this event is sent out. The "type" attribute lists the unit type. "type" can also be "NONE" when there is no active unit (e.g. spectator mode in multiplayer).

Whenever a new unit is entered, you have to re-send all of your "subscribe" messages!

# Messages to DCS

## subscribe
Example: `{"action":"subscribe","keys":["c404","e182"]}`

If the "action" attribute is "subscribe", the "keys" attribute is a JSON array of keys.
This message tells DCS that you are interested in these keys and they will be monitored and included in all "newdata" events until a new unit is entered.


# Example usage

* Hop into an A-10C
* Connect to `<IP of DCS PC>:12800` via TCP (e.g. `telnet dcs-pc-ip 12800`). You will get 30 "newdata" messages per second which will tell you the unit type.
* Type the following and press return: `{"action":"subscribe","keys":["c404","e182"]}`
* Move the speed brakes or cause a master caution and watch the output in your terminal window
