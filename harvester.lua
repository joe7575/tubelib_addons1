--[[

	Tubelib Addons 1
	================

	Copyright (C) 2017 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	harvester.lua
	
	Harvester machine to chop wood and leaves.
	
	The machine is able to harvest an square area of up to 41x41 blocks (radius = 20).
	The base block has to be placed in the middle of the harvesting area.
	The Harvester processes one block every 4 seconds.
	It requires one item Bio Fuel per 16 blocks.

]]--


local CYCLE_TIME = 4
local MAX_HEIGHT = 18
local BURNING_TIME = 16
local TICKS_TO_SLEEP = 5
local STOP_STATE = 0
local FAULT_STATE = -2

local Radius2Idx = {[4]=1 ,[6]=2, [8]=3, [10]=4, [12]=5, [14]=6, [16]=7, [18]=8, [20]=9}

-- valid harvesting nodes and the results for the inventory
local ResultNodes = {
	["default:tree"] = "default:tree",
	["default:aspen_tree"] = "default:aspen_tree",
	["default:pine_tree"] = "default:pine_tree",
	["default:acacia_tree"] = "default:acacia_tree",
	["default:jungletree"] = "default:jungletree",
	
	["default:leaves"] = "default:leaves",
	["default:aspen_leaves"] = "default:aspen_leaves",
	["default:pine_needles"] = "default:pine_needles",
	["default:acacia_leaves"] = "default:acacia_leaves",
	["default:jungleleaves"] = "default:jungleleaves",
	
	["default:bush_leaves"] = "default:bush_leaves",
	["default:acacia_bush_leaves"] = "default:acacia_bush_leaves",
	
	["default:cactus"] = "default:cactus",
	["default:papyrus"] = "default:papyrus",
	
	["farming:wheat_8"] = "farming:wheat",
	["farming:cotton_8"] = "farming:cotton",
	
	["default:apple"] = "default:apple",
}

-- Which sapling belongs to which tree
local SaplingList = {
	["default:tree"] = "default:sapling",
	["default:aspen_tree"] = "default:aspen_sapling",
	["default:pine_tree"] = "default:pine_sapling",
	["default:acacia_tree"] = "default:acacia_sapling",
	["default:jungletree"] = "default:junglesapling",
	["farming:wheat_8"] = "farming:seed_wheat",
	["farming:cotton_8"] = "farming:seed_cotton",
}


local function formspec(meta, state)
	local radius = meta:get_int("radius") or 6
	local endless = meta:get_int("endless") or 0
	local fuel = meta:get_int("fuel") or 0
	-- some recalculations
	endless = endless == 1 and "true" or "false"
	if state == tubelib.RUNNING then
		fuel = fuel * 100/BURNING_TIME
	else
		fuel = 0
	end
	
	return "size[9,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"dropdown[0,0;1.5;radius;4,6,8,10,12,14,16,18,20;"..Radius2Idx[radius].."]".. 
	"label[1.6,0.2;Area radius]"..
	"checkbox[0,1;endless;Run endless;"..endless.."]"..
	"list[context;main;5,0;4,4;]"..
	"list[context;fuel;1.5,3;1,1;]"..
	"item_image[1.5,3;1,1;tubelib_addons1:biofuel]"..
	"image[2.5,3;1,1;default_furnace_fire_bg.png^[lowpart:"..
	fuel..":default_furnace_fire_fg.png]"..
	"image_button[3.5,3;1,1;".. tubelib.state_button(state) ..";button;]"..
	"list[current_player;main;0.5,4.3;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "main" then
		return stack:get_count()
	elseif listname == "fuel" and stack:get_name() == "tubelib_addons1:biofuel" then
		return stack:get_count()
	end
	return 0
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

local DeletableNodes = {
	["air"] = true,
	["tubelib_addons1:copter"] = true,
	["tubelib_addons1:rotor1"] = true,
	["tubelib_addons1:rotor2"] = true,
	["tubelib_addons1:rotor3"] = true,
	["tubelib_addons1:rotor4"] = true,
}	

-- add copter node, considering rights and space
local function add_node(pos, block_name, owner)
	if minetest.is_protected(pos, owner) then
		return false
	end
	local node = minetest.get_node(pos)
	if node == nil or node.name == "ignore" then
		return true  -- ignore unloaded area
	end
	if DeletableNodes[node.name] then
		minetest.remove_node(pos)
		minetest.add_node(pos, {name=block_name})
		return true
	end
	return false
end

-- remove copter node, considering rights and space
local function remove_node(pos, block_name, owner)
	if minetest.is_protected(pos, owner) then
		return false
	end
	if minetest.get_node(pos).name ~= block_name then
		return false
	end
	minetest.remove_node(pos)
	return true
end

local function remove_copter(pos, owner)
	remove_node(pos, "tubelib_addons1:copter", owner)
	pos.x = pos.x + 1
	pos.z = pos.z + 1
	remove_node(pos, "tubelib_addons1:rotor1", owner)
	pos.z = pos.z - 2
	remove_node(pos, "tubelib_addons1:rotor2", owner)
	pos.x = pos.x - 2
	remove_node(pos, "tubelib_addons1:rotor3", owner)
	pos.z = pos.z + 2
	remove_node(pos, "tubelib_addons1:rotor4", owner)
end

local function add_copter(pos, owner)
	local res = add_node(pos, "tubelib_addons1:copter", owner)
	pos.x = pos.x + 1
	pos.z = pos.z + 1
	res = res and add_node(pos, "tubelib_addons1:rotor1", owner)
	pos.z = pos.z - 2
	res = res and add_node(pos, "tubelib_addons1:rotor2", owner)
	pos.x = pos.x - 2
	res = res and add_node(pos, "tubelib_addons1:rotor3", owner)
	pos.z = pos.z + 2
	res = res and add_node(pos, "tubelib_addons1:rotor4", owner)
	pos.z = pos.z - 1 
	pos.x = pos.x + 1 
	return res
end


-- Calculate the copter position.
-- The copter moves in rows and covers a square area
-- arround the base block at root_pos.
local function calc_copter_pos(radius, root_pos, idx)
	local x_offs
	local diameter = radius*2+1
	idx = idx % (diameter * diameter)
	local z_offs = math.floor(idx / diameter)
	if (z_offs % 2) == 0 then
		x_offs = (diameter - 1) - (idx % diameter)
	else
		x_offs = idx % diameter
	end
	return {x = root_pos.x-radius+x_offs, y = root_pos.y + MAX_HEIGHT, z = root_pos.z-radius+z_offs}
end

-- call this function on each start or collision
local function reset_copter_position(pos)
	local meta = minetest.get_meta(pos)
	local idx = meta:get_int("idx")
	local owner = meta:get_string("owner")
	local radius = meta:get_int("radius")
	local pos = calc_copter_pos(radius, pos, idx)
	remove_copter(pos, owner)
	local diameter = radius*2+1
	meta:set_int("idx", (diameter*diameter)/2)
end	
	
local function start_the_machine(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	reset_copter_position(pos)
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", "Tubelib Harvester "..number..": running")
	meta:set_string("formspec", formspec(meta, tubelib.RUNNING))
	minetest.get_node_timer(pos):start(CYCLE_TIME)
	return false
end

local function stop_the_machine(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	-- remove the copter
	local idx = meta:get_int("idx")
	local radius = meta:get_int("radius")
	local old_pos = calc_copter_pos(radius, pos, idx)	
	local owner = meta:get_string("owner")
	remove_copter(old_pos, owner)
	-- update infotext
	meta:set_int("running", STOP_STATE)
	meta:set_string("infotext", "Tubelib Harvester "..number..": stopped")
	meta:set_string("formspec", formspec(meta, tubelib.STOPPED))
	minetest.get_node_timer(pos):stop()
	return false
end

local function goto_fault(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	-- remove the copter
	local idx = meta:get_int("idx")
	local radius = meta:get_int("radius")
	local old_pos = calc_copter_pos(radius, pos, idx)	
	local owner = meta:get_string("owner")
	remove_copter(old_pos, owner)
	-- update infotext
	meta:set_int("running", FAULT_STATE)
	meta:set_string("infotext", "Tubelib Harvester "..number..": fault")
	meta:set_string("formspec", formspec(meta, tubelib.FAULT))
	minetest.get_node_timer(pos):stop()
	return false
end

-- Remove saplings lying arround
local function remove_all_sapling_items(pos)
	for _, object in pairs(minetest.get_objects_inside_radius(pos, 3)) do
		local lua_entity = object:get_luaentity()
		if not object:is_player() and lua_entity and lua_entity.name == "__builtin:item" then
			object:remove()
		end
	end
end

-- Remove wood/leave nodes and place sapling if necessary
local function remove_or_replace_node(pos, inv, node)
	local next_pos = table.copy(pos)
	next_pos.y = next_pos.y - 1
	local next_node = minetest.get_node_or_nil(next_pos)
	if next_node then
		-- don't remove the last cactus block
		if node.name == "default:cactus" and next_node.name ~= "default:cactus" then
			return true
		end
		-- don't remove the last papyrus block
		if node.name == "default:papyrus" and next_node.name ~= "default:papyrus" then
			return true
		end
		-- enough space in the inventory
		if inv:room_for_item("main", ItemStack(node.name)) then
			minetest.remove_node(pos)
			inv:add_item("main", ItemStack(ResultNodes[node.name]))
			if ResultNodes[next_node.name] == nil and next_node.name ~= "air" then  -- hit the ground?
				if SaplingList[node.name] then
					node.name = SaplingList[node.name]
					-- For seed and saplings we have to simulate "on_place" and start the timer by hand
					-- because the after_place_node function checks player rights and can't therefore
					-- be used.
					if node.name == "farming:seed_wheat" or node.name == "farming:seed_cotton" then
						minetest.set_node(pos, {name=node.name, paramtype2 = "wallmounted", param2=1})
						minetest.get_node_timer(pos):start(math.random(166, 286))
					else
						minetest.set_node(pos, {name=node.name})
						minetest.get_node_timer(pos):start(math.random(2400,4800))
					end
				end
			remove_all_sapling_items(pos)
			end
		else
			return false
		end
	end
	return true
end	

-- Scan the space below the given position
-- Return false if inventory is full
local function harvest_field(pos, owner, inv)
	local y_pos = pos.y - 1
	while true do
		pos.y = y_pos
		if minetest.is_protected(pos, owner) then
			return true
		end
		local node = minetest.get_node_or_nil(pos)
		if node then
			if node.name ~= "air" then
				if ResultNodes[node.name] then
					if not remove_or_replace_node(pos, inv, node) then
						return false
					end
				else 	
					return true	-- hit the ground
				end
			end
		end
		y_pos = y_pos - 1
		if y_pos < (pos.y - MAX_HEIGHT) then	-- deep enough?
			return true
		end
	end
	return true
end


-- move the copter and harvest next field
local function keep_running(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local running = meta:get_int("running") - 1
	local idx = meta:get_int("idx")
	local radius = meta:get_int("radius")
	local owner = meta:get_string("owner")
	local inv = meta:get_inventory()
	local fuel = meta:get_int("fuel") or 0
	
	-- check fuel
	if fuel <= 0 then
		if tubelib.get_this_item(meta, "fuel", 1) == nil then
			return goto_fault(pos)
		end
		fuel = BURNING_TIME
	else
		fuel = fuel - 1
	end
	meta:set_int("fuel", fuel) 
	
	-- remove old copter...
	local old_pos = calc_copter_pos(radius, pos, idx)
	remove_copter(old_pos, owner)
	-- ...and place on new pos
	idx = idx + 1
	meta:set_int("idx", idx)
	local next_pos = calc_copter_pos(radius, pos, idx)
	if not add_copter(next_pos, owner) then
		return goto_fault(pos)
	end
	
	local busy = harvest_field(next_pos, owner, inv)
	if busy == true then 
		if running <= STOP_STATE then
			return start_the_machine(pos)
		else
			running = TICKS_TO_SLEEP
		end
	else
		return goto_fault(pos)
	end
	meta:set_int("running", running)
	meta:set_string("formspec", formspec(meta, tubelib.RUNNING))
	meta:set_string("infotext", "Tubelib Harvester "..
		meta:get_string("number")..
		": running "..
		minetest.pos_to_string(next_pos))
	return true
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local meta = minetest.get_meta(pos)
	
	local radius = meta:get_int("radius") or 6
	if fields.radius ~= nil then
		radius = tonumber(fields.radius)
	end
	if radius ~= meta:get_int("radius") then
		stop_the_machine(pos)
		meta:set_int("radius", radius)
	end

	local endless = meta:get_int("endless") or 0
	if fields.endless ~= nil then
		endless = fields.endless == "true" and 1 or 0
	end
	meta:set_int("endless", endless)
	
	local running = meta:get_int("running") or STOP_STATE
	if fields.button ~= nil then
		if running > STOP_STATE or running == FAULT_STATE then
			stop_the_machine(pos)
		else
			start_the_machine(pos)
		end
	else
		meta:set_string("formspec", formspec(meta, tubelib.state(running)))
	end
end

minetest.register_node("tubelib_addons1:harvester_base", {
	description = "Tubelib Harvester Base",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_front.png',
		'tubelib_addons1_harvester.png',
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('main', 16)
		inv:set_size('fuel', 1)
	end,
	
	after_place_node = function(pos, placer)
		local number = tubelib.add_node(pos, "tubelib_addons1:harvester_base")
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Tubelib Harvester "..number..": stopped")
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_int("running", STOP_STATE)
		meta:set_int("endless", 0)
		meta:set_int("radius", 6)
		meta:set_string("formspec", formspec(meta, tubelib.STOPPED))
	end,

	on_dig = function(pos, node, puncher, pointed_thing)
		if minetest.is_protected(pos, puncher:get_player_name()) then
			return
		end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if inv:is_empty("main") then
			minetest.node_dig(pos, node, puncher, pointed_thing)
			tubelib.remove_node(pos)
		end
	end,

	on_receive_fields = on_receive_fields,
	on_timer = keep_running,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	groups = {cracky=2, crumby=2},
	is_ground_content = false,
})

minetest.register_node("tubelib_addons1:harvester_base_active", {
	description = "Tubelib Harvester Base",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_front.png',
		'tubelib_addons1_harvester.png',
	},

	on_receive_fields = on_receive_fields,
	on_timer = keep_running,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	groups = {cracky=0, not_in_creative_inventory=1},
	is_ground_content = false,
})


minetest.register_node("tubelib_addons1:rotor1", {
	description = "Harvester Copter",
	tiles = {
		"tubelib_addons1_rotor.png",
		"tubelib_addons1_rotor.png^[transformR270]",
		"tubelib_addons1_rotor_side.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -8/16, 7/16, -8/16,  8/16,  8/16, 8/16},
		},
	},
	
	light_source = 4,
	paramtype = 'light',
	groups = {cracky=2, not_in_creative_inventory=1},
	is_ground_content = false,
})

minetest.register_node("tubelib_addons1:rotor2", {
	description = "Harvester Copter",
	tiles = {
		"tubelib_addons1_rotor.png^[transformR270]",
		"tubelib_addons1_rotor.png",
		"tubelib_addons1_rotor_side.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -8/16, 7/16, -8/16,  8/16,  8/16, 8/16},
		},
	},
	
	light_source = 4,
	paramtype = 'light',
	groups = {cracky=2, not_in_creative_inventory=1},
	is_ground_content = false,
})

minetest.register_node("tubelib_addons1:rotor3", {
	description = "Harvester Copter",
	tiles = {
		"tubelib_addons1_rotor.png^[transformR180]",
		"tubelib_addons1_rotor.png^[transformR90]",
		"tubelib_addons1_rotor_side.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -8/16, 7/16, -8/16,  8/16,  8/16, 8/16},
		},
	},
	
	light_source = 4,
	paramtype = 'light',
	groups = {cracky=2, not_in_creative_inventory=1},
	is_ground_content = false,
})

minetest.register_node("tubelib_addons1:rotor4", {
	description = "Harvester Copter",
	tiles = {
		"tubelib_addons1_rotor.png^[transformR90]",
		"tubelib_addons1_rotor.png^[transformR180]",
		"tubelib_addons1_rotor_side.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -8/16, 7/16, -8/16,  8/16,  8/16, 8/16},
		},
	},
	
	light_source = 4,
	paramtype = 'light',
	groups = {cracky=2, not_in_creative_inventory=1},
	is_ground_content = false,
})

-- ground mounted booking machine
minetest.register_node("tubelib_addons1:copter", {
	description = "Harvester  Copter",
	tiles = {
		"tubelib_front.png",
		"tubelib_addons1_copter_bottom.png",
		{
			image = 'tubelib_addons1_copter.png',
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 2.0,
			},
		},
	},
	
	light_source = 6,
	paramtype = 'light',
	groups = {cracky=2, not_in_creative_inventory=1},
	is_ground_content = false,
})


minetest.register_craft({
	output = "tubelib_addons1:harvester_base",
	recipe = {
		{"default:steel_ingot", "default:mese_crystal", "default:steel_ingot"},
		{"default:steel_ingot", "default:mese_crystal",	"tubelib:tube1"},
		{"group:wood", 			"default:mese_crystal", "group:wood"},
	},
})


tubelib.register_node("tubelib_addons1:harvester_base", {}, {
	on_pull_item = function(pos, side)
		local meta = minetest.get_meta(pos)
		return tubelib.get_item(meta, "main")
	end,
	on_push_item = function(pos, side, item)
		if item:get_name() == "tubelib_addons1:biofuel" then
			local meta = minetest.get_meta(pos)
			return tubelib.put_item(meta, "fuel", item)
		end
		return false
	end,
	on_unpull_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		return tubelib.put_item(meta, "main", item)
	end,
	on_recv_message = function(pos, topic, payload)
		if topic == "start" then
			start_the_machine(pos)
		elseif topic == "stop" then
			stop_the_machine(pos)
		elseif topic == "state" then
			local meta = minetest.get_meta(pos)
			local running = meta:get_int("running")
			return tubelib.statestring(running)
		else
			return "unsupported"
		end
	end,
})	
