local lib	 = require "map"

local map_parser  = {}
local __localfuncs = {}


----------------------------
---���������ļ�
---@param  path string
---@return map_source_data
map_parser.CreateMapSourceData = function(path)
    local map_file = io.open(path)
    if not map_file then
        skynet.error("map_parser.CreateMapSoureData can not open file path:", path)
        return
    end

    local map_reader = __localfuncs.create_reader(map_file:read("a"))
    local data ={
        version       = __localfuncs.load_number(map_reader),
        grid_length   = __localfuncs.load_number(map_reader),
        width_count   = __localfuncs.load_number(map_reader),
        height_count  = __localfuncs.load_number(map_reader),
        grids         = __localfuncs.load_grids(map_reader)
    }
    return lib.CreateSource(data.version, data.grid_length, data.width_count, data.height_count, data.grids)
end


----------------------------
---��ȡ�ļ���
---@param  path string
---@return string
map_parser.GetFileName = function(path)
    return path
end


---------------------------Local function---------------------
---@return map_parser_reader
__localfuncs.create_reader = function(data)
    local reader = {
        data        = data,
        read_pos    = 1
    }
    return reader;
end


local number_size = 1
local unpack_number_format = "B"
----------------------------
---@param reader map_parser_reader
__localfuncs.load_number = function(reader)
    local len   = __localfuncs.steal_number(reader, unpack_number_format, number_size)
    local str   = string.unpack("s" .. number_size, string.sub(reader.data, reader.read_pos, reader.read_pos + len))
    reader.read_pos = reader.read_pos + len + 1
    return tonumber(str)
end


----------------------------
---@param reader map_parser_reader
__localfuncs.load_grids = function(reader)
    local str   = string.sub(reader.data, reader.read_pos, -1)
    reader.read_pos = #reader.data
    return __localfuncs.str_to_byte(str)
end


----------------------------
__localfuncs.debug_to_hex = function(data)
    local hex = {}
    for i=1, #data do
        table.insert(hex, string.format("%02x", string.byte(data, i)))
    end
    return table.concat(hex, " ")
end


----------------------------
---@param reader map_parser_reader
---@param format string
---@param number_length int
__localfuncs.steal_number = function(reader, format, number_length)
    local number = string.unpack(format, string.sub(reader.data, reader.read_pos, reader.read_pos + number_length - 1))
    return tonumber(number)
end


local bit_mask = 1
__localfuncs.number_to_byte = function(char, out_bytes)
    for i = 7, 0, -1 do
        local block = (char >> i) & bit_mask
        table.insert(out_bytes, block)
    end

end


__localfuncs.str_to_byte = function(data)
    if type(data) ~= "string" then
        return __localfuncs.number_to_byte(data)
    end
    
    local bytes = {}
    for i=1, #data do
        local char = string.byte(data, i)
        __localfuncs.number_to_byte(char, bytes)
        -- print(type())
        -- table.insert(bytes, __localfuncs.number_to_byte(char)) 
    end
    -- print("str_to_byte", table.concat(bytes, ""))
    return bytes
end

local maps = {}
local map_data = map_parser.CreateMapSourceData("tile_0.grid")


local  function test()
    maps = {}
    for i=1,100000 do
	    local map = lib.CreateMap(map_data);
        map:SetGridData(32,32,0)
	    -- local map = {[1] =1 }
        maps[i] = map
    end
end

local  function clean()
    -- for i=1,100000 do
    --     maps[i] = nil
    -- end
    maps = nil
end

local a
while true do
    print("input to begin")
    a = io.read()
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    print("test count:", collectgarbage("count"))
    test()
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    print("test end count:", collectgarbage("count"))

    print("input to release")
    a = io.read()
    clean()
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    print("clean end count:", collectgarbage("count"))
    -- collectgarbage("collect")
end


--local source = terrain_gen.CreateSource(1, 0.5, 5, 5, "0011111111111111111111111")
--local source = terrain_gen.CreateSource(1, 0.5, 5, 5, {0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1})
--local map	 = terrain_gen.CreateMap(source);
--print(map:GetGridLength())
--print(map:GetWidthGridCount())
--print(map:GetHeightGridCount())
--print(map:GridData(1,1))
--print(map:SetGridData(1,1,0))
--print(map:GridData(1,1))