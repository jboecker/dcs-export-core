local _M = {}
local JSON = loadfile([[Scripts\JSON.lua]])()

function _M.init(args)
	assert(type(args.sendMessage) == "function")
	_M.sendMessage = args.sendMessage
	_M.KVS = args.KVS
	
	_M.luaFunctions = {}
	
	_M.lastExportTime = LoGetModelTime() or 0
	_M.lastUnitType = nil
	
	local selfData = LoGetSelfData()
	local unitType = "NONE"
	if selfData then unitType = selfData["Name"] end
	_M.lastUnitType = unitType
	_M.newUnit(unitType)
end

function _M.sendUpdate()
	local unitType = "NONE"
	local selfData = LoGetSelfData()
	if selfData then
		unitType = selfData["Name"]
	end
	
	if _M.lastUnitType ~= unitType then
		_M.lastUnitType = unitType
		if unitType == "NONE" then
			_M.newUnit(unitType)
		end
	end
	_M.KVS.set("_UNITTYPE", unitType, true)
	
	local mainPanel = GetDevice(0)
	if type(mainPanel) ~= "number" then
		for k, arg_num in pairs(_M.exportedCockpitArguments) do
			local arg = GetDevice(0):get_argument_value(arg_num)
			_M.KVS.set(k, arg)
		end
	end
	
	for k, arg_num in pairs(_M.exportedExternalModelArguments) do
		local arg = LoGetAircraftDrawArgumentValue(arg_num)
		_M.KVS.set(k, arg)
	end
	
	_M.KVS.sendUpdates()
	
end

function _M.newUnit(unitType)
	_M.exportedCockpitArguments = {}
	_M.exportedExternalModelArguments = {}
	_M.exportedLuaFunctions = {}
	_M.KVS.reset()
	_M.sendMessage({
		["msg_type"] = "new_unit",
		["type"] = unitType
	})
end

function _M.processMessage(msg)
	if not msg then return end
	if msg.action and msg.action == "subscribe" then
		for _, key in pairs(msg.keys) do
			if key:match("^c.*") then
				_M.exportedCockpitArguments[key] = tonumber(key:sub(2))
				_M.KVS.dirty[key] = true
			end
			if key:match("^e.*") then
				_M.exportedExternalModelArguments[key] = tonumber(key:sub(2))
				_M.KVS.dirty[key] = true
			end
		end
	end
end

function _M.step()
	local currentTime = LoGetModelTime()
	if currentTime - _M.lastExportTime > (1/30) then
		_M.lastExportTime = currentTime
		_M.sendUpdate()
	end
end

ExportCore.PROTOCOL = _M

