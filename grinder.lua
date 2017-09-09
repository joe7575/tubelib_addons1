--[[

	Tubelib Addons 1
	================

	Copyright (C) 2017 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	History:
	2017-09-08  v0.01  first version

]]--

local grinder_formspec =
	"size[8,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[context;src;0,0;3,3;]"..
	"image[3.5,1;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
	"list[context;dst;5,0;3,3;]"..
	"list[current_player;main;0,4;8,4;]"..
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
	if listname == "src" then
		return stack:get_count()
	elseif listname == "dst" then
		return 0
	end
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


local function convert_stone_to_gravel(inv)
	local cobble = ItemStack("default:cobble")
	local gravel = ItemStack("default:gravel")
	if inv:room_for_item("dst", gravel) and inv:contains_item("src", cobble) then
		inv:add_item("dst", gravel)
		inv:remove_item("src", cobble)
		return true
	end
	return false
end


local function start_the_machine(pos)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local number = meta:get_string("number")
	if node.name ~= "tubelib_addons1:grinder_active" then
		node.name = "tubelib_addons1:grinder_active"
		minetest.swap_node(pos, node)
		minetest.get_node_timer(pos):start(2)
		meta:set_string("infotext", "Tubelib Grinder "..number..": running")
	end
end

local function stop_the_machine(pos)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local number = meta:get_string("number")
	if node.name ~= "tubelib_addons1:grinder" then
		node.name = "tubelib_addons1:grinder"
		minetest.swap_node(pos, node)
		minetest.get_node_timer(pos):stop()
		meta:set_string("infotext", "Tubelib Grinder "..number..": stopped")
	end
end

local function keep_running(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local inv = meta:get_inventory()
	if convert_stone_to_gravel(inv) then
		meta:set_string("infotext", "Tubelib Grinder "..number..": running")
	elseif not inv:is_empty("src") then
		meta:set_string("infotext", "Tubelib Grinder "..number..": blocked")
	else
		stop_the_machine(pos)
	end
	return true
end

minetest.register_node("tubelib_addons1:grinder", {
	description = "Tubelib Grinder",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_addons1_grinder.png',
		'tubelib_front.png',
		'tubelib_front.png',
		'tubelib_front.png',
		"tubelib_front.png",
		"tubelib_front.png",
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", grinder_formspec)
		local inv = meta:get_inventory()
		inv:set_size('src', 9)
		inv:set_size('dst', 9)
	end,
	
	after_place_node = function(pos, placer)
		local number = tubelib.get_node_number(pos, "tubelib_addons1:grinder")
		local meta = minetest.get_meta(pos)
		local facedir = minetest.dir_to_facedir(placer:get_look_dir(), false)
		meta:set_string("number", number)
		meta:set_int("facedir", facedir)
		meta:set_string("infotext", "Tubelib Grinder "..number..": stopped")
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
			tubelib.remove_node(pos)
		end
	end,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	paramtype2 = "facedir",
	groups = {cracky=1},
	is_ground_content = false,
})


minetest.register_node("tubelib_addons1:grinder_active", {
	description = "Tubelib Grinder",
	tiles = {
		-- up, down, right, left, back, front
		{
			image = 'tubelib_addons1_grinder_active.png',
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 1.0,
			},
		},
		
		'tubelib_front.png',
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
	},

	on_timer = keep_running,
	
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	paramtype2 = "facedir",
	groups = {crumbly=0, not_in_creative_inventory=1},
	is_ground_content = false,
})

tubelib.register_node("tubelib_addons1:grinder", {"tubelib_addons1:grinder_active"}, {
	on_pull_item = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return tubelib.get_item(inv, "dst")
	end,
	on_push_item = function(pos, item)
		start_the_machine(pos)
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
