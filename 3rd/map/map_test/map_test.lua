local terrain_gen = require "map"



local source = terrain_gen.CreateSource(1, 0.5, 5, 5, "0011111111111111111111111")
local map	 = terrain_gen.CreateMap(source);
print(map:GetGridLength())
print(map:GetWidthGridCount())
print(map:GetHeightGridCount())
print(map:GridsData())
print(map:GridData(1,1))
print(map:SetGridData(1,1,0))
print(map:GridData(1,1))