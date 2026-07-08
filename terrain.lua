
local SEGMENT_LENGTH = 50
--local POINTS_PER_CHUNK = math.floor(CHUNK_WIDTH / SEGMENT_LENGTH) + 1

local FLAT_ZONE = 500    
local MAX_ROCKY_X = 15000 

-- store common hashes
local STREAM_POS = hash("position")
local STREAM_TEX = hash("texcoord0")

-- cache math.functions
local math_sin = math.sin
local math_max = math.max
local math_min = math.min
local factory_create = factory.create
local math_atan2 = math.atan2
local vmath_vector3 = vmath.vector3
local math_floor = math.floor
local buffer_get_stream = buffer.get_stream
local resource_set_buffer = resource.set_buffer


local POS_STREAM =  hash("position")
local UV_STREAM =  hash("texcoord0")
local TEMP_VEC = vmath.vector3()

local M = {}

-- table to hold collision chunks
M.active_chunks = {}
M.chunk_width = 2000
M.points_per_chunk = math.floor(2000 / SEGMENT_LENGTH) + 1

-- track chunks in both directions
M.min_generated_x = 0
M.max_generated_x = 0

-- point pool
M.point_pool = {}

-- road buffer
M.road_buffer = nil 
M.coin_factory = nil
M.mine_factory = nil

M.spawn_props = {}

-- ground collision body
M.ground_col_body = nil
M.filter_data = nil

M.entity_list = {}

function M.init(ground_col_body,chunk_width)

	-- set chunk width
	M.chunk_width = chunk_width
	M.points_per_chunk = math.floor(chunk_width / SEGMENT_LENGTH) + 1
	
	-- set ground body
	M.ground_col_body = ground_col_body
	
	-- pre-allocate the vector pool
	for i = 1, M.points_per_chunk do
		M.point_pool[i] = vmath.vector3(0,0,0)
	end

	-- set up buffer 
	local vertex_count = ((1100 / SEGMENT_LENGTH) + 1 ) * 2
	M.road_buffer = buffer.create(vertex_count, {
		{name = STREAM_POS, type = buffer.VALUE_TYPE_FLOAT32, count = 3},
		{name = STREAM_TEX, type = buffer.VALUE_TYPE_FLOAT32, count = 2}
	})	

	-- get updated shapes
	local shapes = b2d.body.get_shapes(M.ground_col_body)

	-- get filter data (for collisions masks) from original shape
	-- its needed later when setting chains
	M.filter_data = b2d.shape.get_filter_data(shapes[1].shape_id)

end


local function get_hill_height(x)
	-- calculate how far along the difficulty curve the car is (0.0 to 1.0)
	local progress = (x - FLAT_ZONE) / (MAX_ROCKY_X - FLAT_ZONE)

	-- clamp the intensity 
	local intensity = math_max(0, math_min(1.0, progress))

	local noise_value = simplex.noise2(x*0.0006, 0) * 600 * math.min(1.0 + x/100000,2)

	return noise_value * intensity
end

function M.final(delete_entites)
	
	-- clean up shapes on exit
	for _, chunk in ipairs(M.active_chunks) do
		b2d.chain.destroy(chunk.shape_ref)
	end
	
	-- clear table
	M.active_chunks = {}

	-- delete entities
	if (delete_entites==true) then
		for key, value in pairs(M.entity_list) do
			if (go.exists(key)) then
				go.delete(key)
				pprint("deleting",key)
			end
		end
	end

	M.entity_list = {}

	-- reset generated tracking variables
	M.min_generated_x = 0
	M.max_generated_x = 0
	
end

function M.generate_chain_chunk(start_x, forward)

	local end_x = start_x + M.chunk_width
	local pool_index = 1

	
	-- move right to left for Box2D chain winding order
	for x = end_x, start_x, -SEGMENT_LENGTH do
		local p = M.point_pool[pool_index]
		p.x = x
		p.y = get_hill_height(x)	
		pool_index = pool_index + 1
	end

	-- create Box2D chain
	local chunk_shape, segs = b2d.body.create_chain(M.ground_col_body, {
		vertices = M.point_pool,
		friction = 0.9,
		restitution = 0.3,
		category_bits = 1,
		group_index = 0,
		mask_bits = 6
	})

	-- need to set to allow events to come through defold message system
	-- turns out you need to set filter data to the first segment
	b2d.shape.set_filter_data(segs[1].shape_id,M.filter_data)


	-- store data
	table.insert(M.active_chunks, {
		start_x = start_x,
		end_x = end_x,
		shape_ref = chunk_shape
	})

	local chunk = start_x/M.chunk_width

	-- if even chunk generate a mine
	if (chunk%2)==0 and forward==true then
		
		local mine_index = 14

		local dy = M.point_pool[mine_index+1].y - M.point_pool[mine_index].y
		local dx = M.point_pool[mine_index+1].x - M.point_pool[mine_index].x

		local angle = math_atan2(dy, dx)+math.pi

		local mid_x =  (M.point_pool[mine_index].x +  M.point_pool[mine_index+1].x)/2
		local mid_y =  (M.point_pool[mine_index].y +  M.point_pool[mine_index+1].y)/2

		local id = factory_create(M.mine_factory, vmath_vector3(mid_x,mid_y,0.9),vmath.quat_rotation_z(angle),M.spawn_props)
		M.entity_list[id] = true
		
	end


	-- if odd chunk and generating forward spawn some coins...
	if (chunk%2)==1 and forward==true then

		local coin_indices = {10, 12, 14, 16}
		-- generate coins for indices
		for _, index in ipairs(coin_indices) do
			local point = M.point_pool[index]

			TEMP_VEC.x = point.x
			TEMP_VEC.y = point.y + 50
			TEMP_VEC.z = 0.8
			
			local id = factory_create(M.coin_factory, TEMP_VEC, nil, M.spawn_props)
			M.entity_list[id] = true
		end
	end

	-- expand the tracking bounds
	if start_x < M.min_generated_x then
		M.min_generated_x = start_x
	end
	if end_x > M.max_generated_x then
		M.max_generated_x = end_x
	end
end

function M.update_chunks(position)
	
	-- check right
	if position.x > (M.max_generated_x - M.chunk_width * 2) then
		M.generate_chain_chunk(M.max_generated_x,true)
	end

	-- check left
	if position.x < (M.min_generated_x + M.chunk_width * 2) then
		M.generate_chain_chunk(M.min_generated_x - M.chunk_width,false)
	end

	-- cull chunks 
	local cull_distance = M.chunk_width * 3
	local chunks_culled = false

	for i = #M.active_chunks, 1, -1 do
		local chunk = M.active_chunks[i]
		if chunk.end_x < (position.x - cull_distance) or chunk.start_x > (position.x + cull_distance) then
			b2d.chain.destroy(chunk.shape_ref)
			table.remove(M.active_chunks, i)
			chunks_culled = true
		end
	end

	-- recalculate only once, outside the loop
	if chunks_culled then
		M.min_generated_x = math.huge
		M.max_generated_x = -math.huge
		for _, active_chunk in ipairs(M.active_chunks) do
			if active_chunk.start_x < M.min_generated_x then M.min_generated_x = active_chunk.start_x end
			if active_chunk.end_x > M.max_generated_x then M.max_generated_x = active_chunk.end_x end
		end
	end
end

function M.generate_terrain(start_x,vertices_url)

	-- get buffers
	local stream = buffer_get_stream(M.road_buffer , POS_STREAM)
	local uv_stream = buffer_get_stream(M.road_buffer , UV_STREAM)

	-- adjust start to the floor segment length (and take another off)
	start_x = math_floor(start_x/SEGMENT_LENGTH)*SEGMENT_LENGTH-SEGMENT_LENGTH

	-- set u calc for start
	local u= (start_x/50) % 2

	-- index values
	local mesh_index = 1
	local uv_index = 1
	
	for x = start_x,(1100+start_x),SEGMENT_LENGTH do

		local y = get_hill_height(x)

		-- flip u
		u = 1-u
		
		-- top vertex of triangle strip
		stream[mesh_index] = x
		stream[mesh_index+1] = y+15
		stream[mesh_index+2] = 0
		-- top uv
		uv_stream[uv_index] = u 
		uv_stream[uv_index+1] = 1.0

		-- bottom Vertex of triangle strip
		stream[mesh_index+3] = x
		stream[mesh_index+4] = y -740
		stream[mesh_index+5] = 0
		-- bottom uv
		uv_stream[uv_index+2] = u 
		uv_stream[uv_index+3] = 0

		-- increase index values
		mesh_index = mesh_index + 6
		uv_index = uv_index + 4
	end

	--set buffer
	resource_set_buffer(vertices_url,M.road_buffer)
end


return M