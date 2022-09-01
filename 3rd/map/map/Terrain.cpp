#include <include/IMap.h>
#include <include/Define.h>
#include <include/ITerrain.h>
#include <string>
extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

  
static int CreateSource(lua_State* L)
{
    size_t len = 0;
    int64 version         = (int64)luaL_checknumber(L, 1);
    float length          = (float)luaL_checknumber(L, 2);
    int64 width_count     = (int64)luaL_checknumber(L, 3);
    int64 height_count    = (int64)luaL_checknumber(L, 4);
    const char* grid_data = luaL_checklstring(L, 5, &len);
    if (version <= 0 || length <=0 || width_count <= 0 || height_count <= 0 || (size_t)(width_count * height_count) != len)
    {
        return luaL_error(L, "CreateSource param is invalid");
    }

    ITerrain* terrain = new TerrainSource();
    terrain->SetVersion(version);
    terrain->SetGridLength(length);
    terrain->SetWidthGridCount(width_count);
    terrain->SetHeightGridCount(height_count);
    terrain->SetGridsData(grid_data, len);
    
	lua_pushlightuserdata(L, terrain);
	return 1;
}


static int DestroySource(lua_State* L)
{
    ITerrain* p_terrain = (ITerrain*)lua_touserdata(L, 1);
    if (nullptr == p_terrain)
    {
        return luaL_error(L, "DestroySource p_terrain is invalid");
    }
    delete p_terrain;
    return 0;
}


static int CreateMap(lua_State* L)
{
    ITerrain* p_terrain = (ITerrain*)lua_touserdata(L, 1);
    if (nullptr == p_terrain)
    {
        return luaL_error(L, "CreateMap p_terrain is invalid");
    }
	new((IMap*)lua_newuserdata(L, sizeof(Map)))Map(p_terrain);
    luaL_getmetatable(L, MAP_METATABLE);
    lua_setmetatable(L, -2);
	return 1;
}


static luaL_Reg methods[] = {
    { "CreateSource",	CreateSource },
    { "DestroySource",	DestroySource },
	{ "CreateMap",		CreateMap },
	{NULL,NULL}
};


extern void MakeMapMetatable(lua_State* L);

extern "C" {
    LUA_API int luaopen_map(lua_State* L)
    {
        MakeMapMetatable(L);

        lua_newtable(L);
        luaL_setfuncs(L, methods, 0);

        return 1;
    }
}