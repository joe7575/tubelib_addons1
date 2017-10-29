--[[

	Tubelib Addons 1
	================

	Copyright (C) 2017 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	History:
	2017-09-08  v0.01  first version
	2017-09-17  v0.02  harvester added
	2017-10-02  v0.03  fermenter and reformer added
	2017-10-07  v0.04  Ice, now and corals added to the Quarry
	2017-10-24  v0.05  Harvester reworked and optimized
	2017-10-29  v0.06  Adapted to Tubelib v0.07

]]--

if tubelib.version >= 0.07 then
	dofile(minetest.get_modpath("tubelib_addons1") .. "/quarry.lua")
	dofile(minetest.get_modpath("tubelib_addons1") .. "/grinder.lua")
	dofile(minetest.get_modpath("tubelib_addons1") .. '/autocrafter.lua')
	dofile(minetest.get_modpath("tubelib_addons1") .. '/harvester.lua')
	dofile(minetest.get_modpath("tubelib_addons1") .. '/fermenter.lua')
	dofile(minetest.get_modpath("tubelib_addons1") .. '/reformer.lua')
else
	print("[tubelib_addons1] Version 0.07+ of Tubelib Mod is required!")
end