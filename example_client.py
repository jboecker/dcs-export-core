# Python 3 example to read the speed brake position of the A-10C

import socket
import json

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 12800))
sf = s.makefile()

def sendMessage(msg):
	# json.dumps will not do any pretty-printing, so we do not have to remove
	# newlines from its output
	s.send( (json.dumps(msg) + "\n").encode("ascii") )

def onNewUnit(unitName):
	# when a new unit is entered, we have to tell dcs-export-core
	# which keys we are interested in. In this example, we only need
	# key "e182" in the A-10C.
	print("new unit: %s" % unitName)
	if unitName == "A-10C":
		sendMessage(
			{"action":"subscribe", "keys":["e182"]}
		)


# wait for first update event to get current aircraft
while True:
	msg = json.loads(sf.readline())
	if "event" in msg and msg["event"] == "new_unit":
		onNewUnit(msg["type"])
		break
	if "event" in msg and "_UNITTYPE" in msg["data"]:
		onNewUnit(msg["data"]["_UNITTYPE"])
		break
		
# process incoming messages
while True:
	msg = json.loads(sf.readline())
	if "event" in msg:
		if msg["event"] == "new_unit":
			onNewUnit(msg["type"])
		if msg["event"] == "newdata":
			if "e182" in msg["data"] and msg["data"]["_UNITTYPE"] == "A-10C":
				print("New A-10C speed brake position: %f" % msg["data"]["e182"])
				