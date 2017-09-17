--[[

	Tubelib Quadcopter Harvester
	============================

	v0.01 by JoSt
	
	Copyright (C) 2017 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

]]--


local CYCLE_TIME = 4
local MAX_HEIGHT = 14

--local Idx2Radius = {4,6,8,10,12,14,16,18,20}
local Radius2Idx = {[4]=1 ,[6]=2, [8]=3, [10]=4, [12]=5, [14]=6, [16]=7, [18]=8, [20]=9}

-- valid harvesting nodes and the results for the inventory
local ResultNodes = {
	["default:tree"] = "default:wood",
	["default:aspen_tree"] = "default:aspen_wood",
	["default:pine_tree"] = "default:pine_wood",
	["default:acacia_tree"] = "default:acacia_wood",
	["default:jungletree"] = "default:junglewood",
	
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


local function formspec(running, radius)
	return "size[8,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"label[0.2,0.2;Harvesting Radius]"..
	"dropdown[0.2,1;2;radius;4,6,8,10,12,14,16,18,20;"..Radius2Idx[radius].."]".. 
	"checkbox[0.2,2;running;On;"..dump(running).."]"..
	"button_exit[2,2;1,1;button;OK]"..
	"list[context;main;4,0;4,4;]"..
	"list[current_player;main;0,4;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"
end

local function formspec_active(running)
	return "size[8,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"checkbox[0.2,2;running;On;"..dump(running).."]"..
	"button_exit[2,2;1,1;button;OK]"..
	"list[context;main;4,0;4,4;]"..
	"list[current_player;main;0,4;8,4;]"..
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
	end
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

-- add copter node, considering rights and space
local function add_node(pos, block_name, owner)
	if minetest.is_protected(pos, owner) then
		return false
	end
	if minetest.get_node(pos).name ~= "air" then
		return false
	end
	minetest.add_node(pos, {name=block_name})
	return true
end

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
	add_node(pos, "tubelib_addons1:copter", owner)
	pos.x = pos.x + 1
	pos.z = pos.z + 1
	add_node(pos, "tubelib_addons1:rotor1", owner)
	pos.z = pos.z - 2
	add_node(pos, "tubelib_addons1:rotor2", owner)
	pos.x = pos.x - 2
	add_node(pos, "tubelib_addons1:rotor3", owner)
	pos.z = pos.z + 2
	add_node(pos, "tubelib_addons1:rotor4", owner)
	pos.z = pos.z - 1 
	pos.x = pos.x + 1 
end


-- Calculate the next copter position.
-- The copter moves in rows and covers a square area
-- arround the base block at root_pos.
local function get_next_pos(radius, root_pos, idx)
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

local function start_the_machine(pos)
	minetest.get_node_timer(pos):start(CYCLE_TIME)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	meta:set_string("infotext", "Tubelib Harvester "..number..": running")
end

local function stop_the_machine(pos)
	minetest.get_node_timer(pos):stop()
	local meta = minetest.get_meta(pos)
	-- remobe the copter
	local idx = meta:get_int("idx")
	local radius = meta:get_int("radius")
	local owner = meta:get_string("owner")
	local old_pos = get_next_pos(radius, pos, idx)	
	remove_copter(old_pos, owner)
	-- update infotext
	local number = meta:get_string("number")
	meta:set_string("infotext", "Tubelib Harvester "..number..": stopped")
end

-- Remove saplings lying arround
local function remove_all_sapling_items(pos)
	for _, object in pairs(minetest.get_objects_inside_radius(pos, 2)) do
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
		-- enough space inb the inventory
		if inv:room_for_item("main", ItemStack(node.name)) then
			minetest.remove_node(pos)
			inv:add_item("main", ItemStack(ResultNodes[node.name]))
			if ResultNodes[next_node.name] == nil then  -- hit the ground?
				if SaplingList[node.name] then
					node.name = SaplingList[node.name]
					minetest.place_node(pos, node)
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
local function harvest_next_field(pos, meta, inv)
	local idx = meta:get_int("idx")
	local radius = meta:get_int("radius")
	local owner = meta:get_string("owner")
	-- remove old copter...
	local old_pos = get_next_pos(radius, pos, idx)
	remove_copter(old_pos, owner)
	-- ...and place on new pos
	idx = idx + 1
	meta:set_int("idx", idx)
	local next_pos = get_next_pos(radius, pos, idx)
	add_copter(next_pos, owner)
	
	local y_pos = next_pos.y - 1
	while true do
		next_pos.y = y_pos
		if minetest.is_protected(next_pos, owner) then
			return true
		end
		local node = minetest.get_node_or_nil(next_pos)
		if node then
			if node.name ~= "air" then
				if ResultNodes[node.name] then
					if not remove_or_replace_node(next_pos, inv, node) then
						stop_the_machine(pos)
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


local function keep_running(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if not harvest_next_field(pos, meta, inv) then
		stop_the_machine(pos)
	end
	return true
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local meta = minetest.get_meta(pos)
	local radius = meta:get_int("radius")
	local fs_running = meta:get_int("fs_running")
	local running = meta:get_int("running")
	
	if fields.radius ~= nil then
		radius = tonumber(fields.radius)
	end

	if fields.running then
		fs_running = fields.running == "true" and 1 or 0
	end
	
	if fields.button ~= nil then
		running = fs_running
		if fs_running == 1 then
			start_the_machine(pos)
		else
			stop_the_machine(pos)
		end
	end
	meta:set_int("fs_running", fs_running)
	meta:set_int("running", running)
	meta:set_int("radius", radius)
	if running == 1 then
		meta:set_string("formspec", formspec_active(fs_running == 1))
	else
		meta:set_string("formspec", formspec(fs_running == 1, radius))
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
		meta:set_int("radius", 6)
		meta:set_string("formspec", formspec(false, 6))
		local inv = meta:get_inventory()
		inv:set_size('main', 16)
	end,
	
	after_place_node = function(pos, placer)
		local number = tubelib.get_node_number(pos, "tubelib_addons1:harvester_base")
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Tubelib Harvester "..number..": stopped")
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_int("fs_running", 0)
		meta:set_int("running", 0)
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
		local inv = meta:get_inventory()
		return tubelib.get_item(inv, "main")
	end,
	on_recv_message = function(pos, topic, payload)
		if topic == "start" then
			start_the_machine(pos)
		elseif topic == "stop" then
			stop_the_machine(pos)
		end
	end,
})	
