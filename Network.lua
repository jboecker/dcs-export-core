local JSON = loadfile("Scripts\\JSON.lua")()
local _M = {}

local function shallowCopy(source, dest)
	dest = dest or {}
	for k, v in pairs(source) do
		dest[k] = v
	end
	return dest
end

_M = {}
_M.connections = {}

_M.LuaSocketConnection = {
	conn = nil,
	rxbuf = ""
}
function _M.LuaSocketConnection:create(args)
	args = args or {}
	local self = shallowCopy(_M.LuaSocketConnection)
	return self
end
function _M.LuaSocketConnection:close()
	self.conn:close()
end

_M.TCPServer = {}
function _M.TCPServer:create(args)
	args = args or {}
	local self = _M.LuaSocketConnection:create()
	shallowCopy(_M.TCPServer, self)
	self.host = args.host or "*"
	self.port = args.port or 12800
	return self
end
function _M.TCPServer:init()
	self.acceptor = socket.bind(self.host, self.port, 10)
	self.acceptor:settimeout(0)
	self.connections = {}
end
function _M.TCPServer:step()
	-- accept new connections
	local newconn = self.acceptor:accept()
	if newconn then
		newconn:settimeout(0)
		local newconn_info = { conn = newconn, txbuf = "", rxbuf = "" }
		self.connections[#self.connections+1] = newconn_info
	end

	local have_closed_connections = false
	-- receive data
	for _, conninfo in pairs(self.connections) do
	
		local data, err, partial = conninfo.conn:receive(4096)
		if data then
			conninfo.rxbuf = conninfo.rxbuf .. data
		elseif partial and #partial > 0 then
			conninfo.rxbuf = conninfo.rxbuf .. partial
		elseif err == "closed" then
			conninfo.closed = true
			have_closed_connections = true
		end
	
		while true do
			local line, rest = conninfo.rxbuf:match("^([^\n]*)\n(.*)")
			if line then
				conninfo.rxbuf = rest
				_M.processInputLine(line)
			else
				break
			end
		end
	end
	
	-- eliminate closed connections
	if have_closed_connections then
		local old_connections = self.connections
		self.connections = {}
		for _, conninfo in pairs(old_connections) do
			if not conninfo.closed then
				self.connections[#self.connections+1] = conninfo
			end
		end
	end
end
function _M.TCPServer:send(msg)
	for _, conninfo in pairs(self.connections) do
		socket.try(conninfo.conn:send(msg))
	end
end
function _M.TCPServer:close()
	for _, conninfo in pairs(self.connections) do
		socket.try(conninfo.conn:close())
	end
	self.connections = {}
end

_M.DefaultMulticastSender = {}
function _M.DefaultMulticastSender:create()
	local self = _M.LuaSocketConnection:create()
	shallowCopy(_M.DefaultMulticastSender, self)
	return self
end
function _M.DefaultMulticastSender:init()
	self.conn = socket.udp()
	self.conn:settimeout(0)
end
function _M.DefaultMulticastSender:send(msg)
	socket.try(self.conn:sendto(msg, "239.255.50.10", 12800))
end


_M.UDPListener = {}
function _M.UDPListener:create(args)
	args = args or {}
	local self = _M.LuaSocketConnection:create()
	shallowCopy(_M.UDPListener, self)
	self.port = args.port or 12801
	self.host = args.host or "*"
	return self
end
function _M.UDPListener:init()
	self.conn = socket.udp()
	self.conn:setsockname("*", self.port)
	self.conn:settimeout(0)
end
function _M.UDPListener:step()
	local lInput = nil
	
	while true do
		lInput = self.conn:receive()
		if not lInput then break end
		self.rxbuf = self.rxbuf .. lInput
	end
	
	while true do
		local line, rest = self.rxbuf:match("^([^\n]*)\n(.*)")
		if line then
			self.rxbuf = rest
			_M.processInputLine(line)
		else
			break
		end
	end
	
end

_M.UDPSender = {}
function _M.UDPSender:create(args)
	args = args or {}
	local self = _M.LuaSocketConnection:create()
	shallowCopy(_M.UDPSender, self)
	self.port = args.port or 12800
	self.host = args.host or "127.0.0.1"
	return self
end
function _M.UDPSender:init()
	self.conn = socket.udp()
	self.conn:settimeout(0)
end
function _M.UDPSender:send(msg)
	socket.try(self.conn:sendto(msg, self.host, self.port))
end

local msg_buf = {}
function _M.queue(msg)
	msg_buf[#msg_buf+1] = msg
end
function _M.flush()
	local MAX_PAYLOAD_SIZE = 8192
	
	local packet = ""
	for _, v in pairs(msg_buf) do
		if packet:len() + v:len() > MAX_PAYLOAD_SIZE then
			for _, v in pairs(_M.connections) do
				if v.send then v:send(packet) end
			end			
			packet = ""
		end
		packet = packet .. v
	end
	if packet:len() > 0 then
		for _, v in pairs(_M.connections) do
			if v.send then v:send(packet) end
		end
	end
	msg_buf = {}
end

function _M.processInputLine(line)
	local success, result = pcall(function() return JSON:decode(line) end)
	if not success then 
		return
	end
	
	_M.processMessage(result)
end

function _M.init(args)
	assert(type(args.processMessage) == "function")
	_M.processMessage = args.processMessage
	assert(type(args.processExportDevicePacket) == "function")
	_M.processExportDevicePacket = args.processExportDevicePacket

	-- set up UDP listener for ExportDevice
	_M.exportDeviceListener = socket.udp()
	_M.exportDeviceListener:setsockname("127.0.0.1", 12823)
	_M.exportDeviceListener:settimeout(0)
	
	_M.connections = {
		_M.TCPServer:create(),
		_M.UDPListener:create(),
		_M.DefaultMulticastSender:create()
	}
	
	for _, c in pairs(_M.connections) do
		c:init()
	end
end

function _M.stop()

end

function _M.step()
	while true do
		local data = _M.exportDeviceListener:receive()
		if not data then break end
		_M.processExportDevicePacket(data)
	end
	
	for _, c in pairs(_M.connections) do
		if c.step then c:step() end
	end
end

function _M.sendMessage(msg)
	msgstr = JSON:encode(msg):gsub("\n", "") .. "\n"
	for _, c in pairs(_M.connections) do
		if c.send then c:send(msgstr) end
	end
end

ExportCore.NET = _M
