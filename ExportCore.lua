package.path  = package.path..";.\\LuaSocket\\?.lua"
package.cpath = package.cpath..";.\\LuaSocket\\?.dll"
  
socket = require("socket")
lfs = require("lfs")

ExportCore = {}
function ExportCore.init()
	dofile(lfs.writedir()..[[Scripts\export-core\Network.lua]])
	dofile(lfs.writedir()..[[Scripts\export-core\KeyValueStore.lua]])
	dofile(lfs.writedir()..[[Scripts\export-core\Protocol.lua]])
	ExportCore.KVS.init({sendMessage = ExportCore.NET.sendMessage})
	ExportCore.NET.init({processMessage = ExportCore.PROTOCOL.processMessage})
	ExportCore.PROTOCOL.init({sendMessage = ExportCore.NET.sendMessage, KVS = ExportCore.KVS})
end

-- Prev Export functions.
local PrevExport = {}
PrevExport.LuaExportStart = LuaExportStart
PrevExport.LuaExportStop = LuaExportStop
PrevExport.LuaExportBeforeNextFrame = LuaExportBeforeNextFrame
PrevExport.LuaExportAfterNextFrame = LuaExportAfterNextFrame

-- Lua Export Functions
function LuaExportStart()
	ExportCore.init()
	
	-- Chain previously-included export as necessary
	if PrevExport.LuaExportStart then
		PrevExport.LuaExportStart()
	end
end

LuaExportStop = function()
	
	ExportCore.NET.stop()
	
	-- Chain previously-included export as necessary
	if PrevExport.LuaExportStop then
		PrevExport.LuaExportStop()
	end
end

function LuaExportBeforeNextFrame()
	
	ExportCore.NET.step()
	ExportCore.PROTOCOL.step()
	
	-- Chain previously-included export as necessary
	if PrevExport.LuaExportBeforeNextFrame then
		PrevExport.LuaExportBeforeNextFrame()
	end
	
end

function LuaExportAfterNextFrame()
	
	ExportCore.NET.step()

	-- Chain previously-included export as necessary
	if PrevExport.LuaExportAfterNextFrame then
		PrevExport.LuaExportAfterNextFrame()
	end
end