local _M = {}

_M.data = {}
_M.dirty = {}

function _M.init(args)
	assert(type(args.sendMessage) == "function")
	_M.sendMessage = args.sendMessage
end

function _M.reset()
	_M.data = {}
	_M.dirty = {}
end

function _M.set(key, value, dirtyOverride)
	if dirtyOverride or _M.data[key] ~= value then
		_M.dirty[key] = true
	end
	_M.data[key] = value
end

function _M.sendUpdates()
	local MAX_UPDATES_AT_ONCE = 100
	local datacount = 0
	msg = { msg_type="newdata", data = {} }
	for k, _ in pairs(_M.dirty) do
		if datacount >= MAX_UPDATES_AT_ONCE then
			_M.sendMessage(msg)
			msg.data = {}
			datacount = 0
		end
		msg.data[k] = _M.data[k]
		datacount = datacount + 1
	end
	if datacount > 0 then
		_M.sendMessage(msg)
	end
	_M.dirty = {}
end

ExportCore.KVS = _M

