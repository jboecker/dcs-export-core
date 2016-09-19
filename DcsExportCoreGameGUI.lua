DCS.setUserCallbacks({
	["onSimulationStart"] = function()
		net.log("DcsExportCoreGameGUI: loading DcsExportCore into export.lua")
		net.dostring_in("export", "dofile(lfs.writedir()..[[Scripts\\DcsExportCore\\ExportCore.lua]])")
	end
})
