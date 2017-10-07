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

]]--

--------------------------- conversion to v0.03
minetest.register_lbm({
	label = "[Tubelib] Distributor update",
	name = "tubelib_addons1:update",
	nodenames = {"tubelib_addons1:harvester_base", "tubelib_addons1:quarry", "tubelib_addons1:quarry_active"},
	run_at_every_load = false,
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('main', 16)
		inv:set_size('fuel', 1)
	end
})


dofile(minetest.get_modpath("tubelib_addons1") .. "/quarry.lua")
dofile(minetest.get_modpath("tubelib_addons1") .. "/grinder.lua")
dofile(minetest.get_modpath("tubelib_addons1") .. '/autocrafter.lua')
dofile(minetest.get_modpath("tubelib_addons1") .. '/harvester.lua')
dofile(minetest.get_modpath("tubelib_addons1") .. '/fermenter.lua')
dofile(minetest.get_modpath("tubelib_addons1") .. '/reformer.lua')
