#include <include/Map.h>
#include <include/Define.h>
#include <include/TerrainData.h>
#include <string>

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

  
static int CreateSource(lua_State* L)
{
    int64 version       = (int64)luaL_checkinteger(L, 1);
    float length        = (float)luaL_checknumber(L, 2);
    int64 x_count       = (int64)luaL_checkinteger(L, 3);
    int64 y_count       = (int64)luaL_checkinteger(L, 4);
    luaL_checktype(L, 5, LUA_TTABLE);
    uint64 grids_count   = (int64)luaL_len(L, 5);
    if (version <= 0 || length <=0 || x_count <= 0 || y_count <= 0 || (uint64)(x_count * y_count) != grids_count)
    {
        return luaL_error(L, "CreateSource param is invalid");
    }

    map_grids* p_grids = new map_grids[grids_count];
    for (uint64 i = 1; i <= grids_count; ++i)
    {
        lua_geti(L, 5, i);
        int isnum;
        lua_Integer grid = lua_tointegerx(L, -1, &isnum);
        if (!isnum || grid < 0 || grid > 255) {
            delete[] p_grids;
            return luaL_error(L, "invalid element at pos:%d for argument #5", i);
        }
        lua_pop(L, 1);
        p_grids[i - 1] = (char)grid;
    }
    TerrainData* terrain = new TerrainData(version, x_count, y_count, grids_count, length, p_grids);
    
	lua_pushlightuserdata(L, terrain);
	return 1;
}


static int DestroySource(lua_State* L)
{
    TerrainData* p_terrain = (TerrainData*)lua_touserdata(L, 1);
    if (nullptr == p_terrain)
    {
        return luaL_error(L, "DestroySource p_terrain is invalid");
    }
    delete p_terrain;
    return 0;
}


static int CreateMap(lua_State* L)
{
    TerrainData* p_terrain = (TerrainData*)lua_touserdata(L, 1);
    if (nullptr == p_terrain)
    {
        return luaL_error(L, "CreateMap p_terrain is invalid");
    }
    IMap* p_map = new Map(p_terrain);
    //IMap**pp_map = (IMap**)lua_newuserdata(L, sizeof(Map*));
    //*pp_map = p_map;
    *(IMap**)lua_newuserdata(L, sizeof(Map*)) = p_map;
    luaL_setmetatable(L, MAP_METATABLE);
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