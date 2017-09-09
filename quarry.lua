--[[

	Tubelib Addons 1
	================

	Copyright (C) 2017 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	History:
	2017-09-08  v0.01  first version

]]--

LEVELS = 25
CYCLE_TIME = 4


local function quarry_formspec(running)
	return "size[8,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"checkbox[1,1;running;On;"..dump(running).."]"..
	"button_exit[1,2;1,1;button;OK]"..
	"list[context;main;4,0;3,3;]"..
	"list[current_player;main;0,4;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"
end

local function get_pos(pos, facedir, side)
	local offs = {F=0, R=1, B=2, L=3, D=4, U=5}
	local dst_pos = table.copy(pos)
	facedir = (facedir + offs[side]) % 4
	local dir = tubelib.facedir_to_dir(facedir)
	return vector.add(dst_pos, dir)
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

local function start_the_machine(pos)
	local node = minetest.get_node(pos)
	if node.name ~= "tubelib_addons1:quarry_active" then
		node.name = "tubelib_addons1:quarry_active"
		minetest.swap_node(pos, node)
		minetest.get_node_timer(pos):start(CYCLE_TIME)
	end
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	meta:set_string("infotext", "Tubelib Quarry "..number..": running")
end

local function stop_the_machine(pos)
	local node = minetest.get_node(pos)
	if node.name ~= "tubelib_addons1:quarry" then
		node.name = "tubelib_addons1:quarry"
		minetest.swap_node(pos, node)
		minetest.get_node_timer(pos):stop()
	end
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	meta:set_string("infotext", "Tubelib Quarry "..number..": stopped")
end

local QuarrySchedule = {0,0,3,3,3,3,2,2,2,2,1,1,1,1,0,3,0,0,3,3,2,2,1,0,0}

local ValidNodes = {"default:stone", "default:desert_stone", "default:clay", 
	"default:stone_with_coal", "default:stone_with_iron", 
	"default:stone_with_copper", "default:stone_with_gold",
	"default:gravel", "default:stone_with_mese", 
	"default:stone_with_tin", "default:stone_with_diamond",
	"default:dirt", "default:dirt_with_grass",
	"default:dirt_with_grass_footsteps", "default:dirt_with_dry_grass",
	"default:dirt_with_snow", "default:dirt_with_rainforest_litter",
	"default:sand", "default:desert_sand", "default:silver_sand",
	"moreores:mineral_silver"; "moreores:mineral_mithril"}

local ResultNodes = {
	["default:stone"] = "default:cobble",
	["default:desert_stone"] = "default:desert_cobble",
	["default:clay"] = "default:clay_lump",
	["default:stone_with_coal"] = "default:coal_lump",
	["default:stone_with_iron"] = "default:iron_lump",
	["default:stone_with_copper"] = "default:copper_lump",
	["default:stone_with_gold"] = "default:gold_lump",
	["default:gravel"] = "default:gravel",
	["default:stone_with_mese"] = "default:meselamp",
	["default:stone_with_tin"] = "default:tin_lump",
	["default:stone_with_diamond"] = "default:diamond",
	["default:dirt"] = "default:dirt",
	["default:dirt_with_grass"] = "default:dirt",
	["default:dirt_with_grass_footsteps"] = "default:dirt",
	["default:dirt_with_dry_grass"] = "default:dirt",
	["default:dirt_with_snow"] = "default:dirt",
	["default:dirt_with_rainforest_litter"] = "default:dirt",
	["default:sand"] = "default:sand",
	["default:desert_sand"] = "default:desert_sand",
	["default:silver_sand"] = "default:silver_sand",
	["moreores:mineral_silver"] = "moreores:silver_lump",
	["moreores:mineral_mithril"] = "moreores:mithril_lump",
	["default:"] = "default:",
}


local function get_next_pos(pos, facedir, dir)
	facedir = (facedir + dir) % 4
	return vector.add(pos, core.facedir_to_dir(facedir))
end

local function quarry_next_node(pos, meta)
	local idx = meta:get_int("idx")
	local facedir = meta:get_int("facedir")
	local owner = meta:get_string("owner")
	local levels = meta:get_int("levels")
	local quarry_pos = minetest.string_to_pos(meta:get_string("quarry_pos"))
	if quarry_pos == nil then
		quarry_pos = get_pos(pos, facedir, "L")
		quarry_pos.y = quarry_pos.y - 1
		idx = 1
	elseif idx < #QuarrySchedule then
		quarry_pos = get_next_pos(quarry_pos, facedir, QuarrySchedule[idx])
		idx = idx + 1
	elseif levels < LEVELS then
		levels = levels + 1
		local y = quarry_pos.y
		quarry_pos = get_pos(pos, facedir, "L")
		quarry_pos.y = y - 1
		idx = 1
	else
		stop_the_machine(pos)
	end
	meta:set_int("levels", levels)
	meta:set_int("idx", idx)
	meta:set_string("quarry_pos", minetest.pos_to_string(quarry_pos))

	if minetest.is_protected(pos, owner) then
		minetest.chat_send_player(owner, "[Tubelib Quarry] Area is protected!")
		return false
	end

	local node = minetest.get_node_or_nil(quarry_pos)
	if node == nil then
		minetest.chat_send_player(owner, "[Tubelib Quarry] Node is nil!")
		return true
	end

	local inv = meta:get_inventory()
	for _,name in ipairs(ValidNodes) do
		if node.name == name then
			if inv:room_for_item("main", ItemStack(node.name)) then
				minetest.remove_node(quarry_pos)
				inv:add_item("main", ItemStack(ResultNodes[node.name]))
				return true
			else
				return false
			end
		end
	end
	return true
end

local function keep_running(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local inv = meta:get_inventory()
	if quarry_next_node(pos, meta) then
		meta:set_string("infotext", "Tubelib Quarry "..number..": running")
	elseif not inv:is_empty("src") then
		meta:set_string("infotext", "Tubelib Quarry "..number..": blocked")
	else
		stop_the_machine(pos)
	end
	return true
end

local function on_receive_fields(pos, formname, fields, player)
	local meta = minetest.get_meta(pos)
	if fields.running ~= nil then
		meta:set_int("running", fields.running == "true" and 1 or 0)
		meta:set_string("formspec", quarry_formspec(fields.running == "true"))
	end
	if fields.button ~= nil then
		if meta:get_int("running") == 1 then
			start_the_machine(pos)
		else
			stop_the_machine(pos)
		end
	end
end

minetest.register_node("tubelib_addons1:quarry", {
	description = "Tubelib Quarry",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_front.png',
		'tubelib_front.png',
		'tubelib_front.png',
		'tubelib_addons1_quarry.png',
		'tubelib_front.png',
		'tubelib_front.png',
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", quarry_formspec(false))
		local inv = meta:get_inventory()
		inv:set_size('main', 9)
	end,
	
	after_place_node = function(pos, placer)
		local number = tubelib.get_node_number(pos, "tubelib_addons1:quarry")
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Quarry "..number..": stopped")
		local facedir = minetest.dir_to_facedir(placer:get_look_dir(), false)
		meta:set_int("facedir", facedir)
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_int("running", 0)
		meta:set_int("levels", 0)
	end,

	on_receive_fields = on_receive_fields,

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

	allow_metadata_inventory_put = allow_metadata_inventory,
	allow_metadata_inventory_take = allow_metadata_inventory,

	paramtype2 = "facedir",
	groups = {cracky=1},
	is_ground_content = false,
})


minetest.register_node("tubelib_addons1:quarry_active", {
	description = "Tubelib Quarry",
	tiles = {
		-- up, down, right, left, back, front

		'tubelib_front.png',
		'tubelib_front.png',
		'tubelib_front.png',
		{
			image = 'tubelib_addons1_quarry_active.png',
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 2.0,
			},
		},
		'tubelib_front.png',
		'tubelib_front.png',
	},

	on_receive_fields = on_receive_fields,

	on_timer = keep_running,

	paramtype2 = "facedir",
	groups = {crumbly=0, not_in_creative_inventory=1},
	is_ground_content = false,
})

local function get_items(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	return tubelib.get_item(inv, "main")
end

tubelib.register_node("tubelib_addons1:quarry", {"tubelib_addons1:quarry_active"},
	{
	on_pull_item = function(pos)
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
