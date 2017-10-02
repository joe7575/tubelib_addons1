--[[

	Tubelib Addons 1
	================

	Copyright (C) 2017 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

]]--

local CYCLE_TIME = 4

local leaves = {
	["default:leaves"] = true,
	["default:aspen_leaves"] = true,
	["default:pine_needles"] = true,
	["default:acacia_leaves"] = true,
	["default:jungleleaves"] = true,
	["default:bush_leaves"] = true,
	["default:acacia_bush_leaves"] = true,
}

local formspec =
	"size[8,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[context;src;0,0;3,3;]"..
	"item_image[0,0;1,1;default:leaves]"..
	"image[3.5,1;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
	"list[context;dst;5,0;3,3;]"..
	"item_image[5,0;1,1;tubelib_addons1:biogas]"..
	"list[current_player;main;1,4.3;8,4;]"..
  "listring[context;dst]"..
  "listring[current_player;main]"..
  "listring[context;src]"..
  "listring[current_player;main]"


local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "src" and leaves[stack:get_name()] then
		return stack:get_count()
	elseif listname == "dst" then
		return stack:get_count()
	end
	return 0
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end


local function place_top(pos, facedir, placer)
	if minetest.is_protected(pos, placer:get_player_name()) then
		return false
	end
	local node = minetest.get_node(pos)
	if node.name ~= "air" then
		return false
	end
	minetest.add_node(pos, {name="tubelib_addons1:fermenter_top", param2=facedir})
	return true
end

local function convert_leaves_to_biogas(inv)
	local biogas = ItemStack("tubelib_addons1:biogas")
	if inv:room_for_item("dst", biogas) and tubelib.get_num_items(inv, "src", 2) then
		inv:add_item("dst", biogas)
		return true
	end
	return false
end

local function start_the_machine(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_int("running") == 0 then
		meta:set_int("running", 1)
		local number = meta:get_string("number")
		minetest.get_node_timer(pos):start(CYCLE_TIME)
		meta:set_string("infotext", "Tubelib Fermenter "..number..": running")
	end
end

local function stop_the_machine(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_int("running") == 1 then
		meta:set_int("running", 0)
		local number = meta:get_string("number")
		minetest.get_node_timer(pos):stop()
		meta:set_string("infotext", "Tubelib Fermenter "..number..": stopped")
	end
end

local function keep_running(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local inv = meta:get_inventory()
	if convert_leaves_to_biogas(inv) == true then
		meta:set_string("infotext", "Tubelib Fermenter "..number..": running")
	elseif not inv:is_empty("src") then
		meta:set_string("infotext", "Tubelib Fermenter "..number..": blocked")
	else
		stop_the_machine(pos)
	end
	return meta:get_int("running") == 1
end

minetest.register_node("tubelib_addons1:fermenter", {
	description = "Tubelib Fermenter",
	inventory_image = "tubelib_addons1_fermenter_inventory.png",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_front.png',
		'tubelib_front.png',
		'tubelib_addons1_fermenter_bottom.png',
		'tubelib_addons1_fermenter_bottom.png',
		'tubelib_addons1_fermenter_bottom.png',
		'tubelib_addons1_fermenter_bottom.png',
	},

	selection_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16,   8/16, 24/16, 8/16 },
	},
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", formspec)
		local inv = meta:get_inventory()
		inv:set_size('src', 9)
		inv:set_size('dst', 9)
	end,
	
	after_place_node = function(pos, placer)
		local facedir = minetest.dir_to_facedir(placer:get_look_dir(), false)
		if place_top({x=pos.x, y=pos.y+1, z=pos.z}, facedir, placer) == false then
			minetest.remove_node(pos)
			return
		end
		local number = tubelib.get_node_number(pos, "tubelib_addons1:fermenter")
		local meta = minetest.get_meta(pos)
		meta:set_string("number", number)
		meta:set_int("running", 0)
		meta:set_int("facedir", facedir)
		meta:set_string("infotext", "Tubelib Fermenter "..number..": stopped")
		
	end,

	on_metadata_inventory_put = function(pos)
		start_the_machine(pos)
	end,
	
	on_metadata_inventory_move = function(pos)
		start_the_machine(pos)
	end,
	
	on_metadata_inventory_take = function(pos)
		start_the_machine(pos)
	end,

	on_dig = function(pos, node, puncher, pointed_thing)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if inv:is_empty("dst") and inv:is_empty("src") then
			minetest.node_dig(pos, node, puncher, pointed_thing)
			minetest.remove_node({x=pos.x, y=pos.y+1, z=pos.z})
			tubelib.remove_node(pos)
		end
	end,
	
	on_timer = keep_running,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	paramtype2 = "facedir",
	groups = {crumbly=2, cracky=2},
	is_ground_content = false,
})


minetest.register_node("tubelib_addons1:fermenter_top", {
	description = "Tubelib Fermenter Top",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_front.png',
		"tubelib_front.png",
		'tubelib_addons1_fermenter_top.png',
		'tubelib_addons1_fermenter_top.png',
		'tubelib_addons1_fermenter_top.png',
		'tubelib_addons1_fermenter_top.png',
	},

	paramtype2 = "facedir",
	groups = {crumbly=0, not_in_creative_inventory=1},
	is_ground_content = false,
})

minetest.register_craftitem("tubelib_addons1:biogas", {
	description = "Bio Gas",
	inventory_image = "tubelib_addons1_biogas.png",
})


minetest.register_craft({
	output = "tubelib_addons1:fermenter",
	recipe = {
		{"default:steel_ingot", "default:dirt",  		"default:steel_ingot"},
		{"tubelib:tube1", 		"default:mese_crystal",	"tubelib:tube1"},
		{"default:steel_ingot", "group:wood",  			"default:steel_ingot"},
	},
})


tubelib.register_node("tubelib_addons1:fermenter", {}, {
	on_pull_item = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return tubelib.get_item(inv, "dst")
	end,
	on_push_item = function(pos, item)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return tubelib.put_item(inv, "src", item)
	end,
	on_recv_message = function(pos, topic, payload)
		if topic == "start" then
			start_the_machine(pos)
		elseif topic == "stop" then
			stop_the_machine(pos)
		end
	end,
})	
