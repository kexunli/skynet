#include <string.h>
#include <include/Map.h>
#include <include/Utils.h>
#include <include/TerrainData.h>
extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}


static IMap* GetMap(lua_State* L)
{
    IMap** p_pmap = (IMap**)lua_touserdata(L, 1);
    if (nullptr == p_pmap)
    {
        luaL_error(L, "GetMap p_pmap is nullptr");
    }
    IMap* p_map = *p_pmap;
    if (nullptr == p_map)
    {
        luaL_error(L, "GetMap p_map is invalid");
    }
    return p_map;
}

Map::Map(TerrainData* terrain)
    : m_version(terrain->GetVersion())
    , m_x_count(terrain->GetXCount())
    , m_y_count(terrain->GetYCount())
    , m_grids_count(terrain->GetGridsCount())
    , m_grids(terrain->GetGridsData())
    , m_grid_length(terrain->GetGridLength())
    , m_grids_shared(true)
{

}


Map::~Map()
{ 
    if (!m_grids_shared)
    {
        delete[] m_grids;
    }
    m_grids = nullptr;
}


int64 Map::GetVersion() const
{
    return m_version;
}


float Map::GetGridLength() const
{
    return m_grid_length;
}


int64 Map::GetXCount() const
{
    return m_x_count;
}


int64 Map::GetYCount() const
{
    return m_y_count;
}


EGridStatus Map::GetGridData(int64 x, int64 y) const
{
    uint64 index = BlockToIndex(x, y, m_x_count);
    if (index >= m_grids_count)
    {
        return EGRID_ERROR;
    }
    return (EGridStatus)m_grids[index];
}


bool Map::SetGridData(int64 x, int64 y, EGridStatus block_status)
{
    uint64 index = BlockToIndex(x, y, m_x_count);
    if (index == ERROR_INDEX || index >= m_grids_count || m_grids[index] == (char)block_status)
    {
        return false;
    }

    if (m_grids_shared)
    {
        map_grids* buffer = new map_grids[m_grids_count];
        memcpy(buffer, m_grids, m_grids_count);
        m_grids = buffer;
        m_grids_shared = false;
    }
    m_grids[index] = (char)block_status;
    return true;
}


/// ---------------------------------------------------------
/// lua ·½·¨
/// ---------------------------------------------------------
static int MapGetVersion(lua_State* L)
{
    IMap* p_map = GetMap(L);
    lua_pushinteger(L, p_map->GetVersion());
    return 1;
}


static int MapGetGridLength(lua_State* L)
{
    IMap* p_map = GetMap(L);
    lua_pushnumber(L, p_map->GetGridLength());
    return 1;
}


static int MapGetXCount(lua_State* L)
{
    IMap* p_map = GetMap(L);
    lua_pushinteger(L, p_map->GetXCount());
    return 1;
}


static int MapGetYCount(lua_State* L)
{
    IMap* p_map = GetMap(L);
    lua_pushinteger(L, p_map->GetYCount());
    return 1;
}


static int MapGetGridData(lua_State* L)
{
    IMap* p_map = GetMap(L);
    int64 x     = (int64)luaL_checkinteger(L, 2);
    int64 y     = (int64)luaL_checkinteger(L, 3);
    if (x < 0 || y < 0)
    {
        return luaL_error(L, "MapGetGridData x or y is invalid");
    }
    lua_pushinteger(L, (int64)p_map->GetGridData(x, y));
    return 1;
}


static int MapSetGridData(lua_State* L)
{
    IMap* p_map         = GetMap(L);
    int64 x             = (int64)luaL_checkinteger(L, 2);
    int64 y             = (int64)luaL_checkinteger(L, 3);
    EGridStatus status  = (EGridStatus)luaL_checkinteger(L, 4);
    if (x < 0 || y < 0 || status < EGRID_WALKABLE || status > EGRID_BLOCK)
    {
        return luaL_error(L, "MapSetGridData param is invalid");
    }
    lua_pushboolean(L, p_map->SetGridData(x, y, status)) ;
    return 1;
}


static int MapGC(lua_State* L)
{
    IMap** p_pmap = (IMap**)lua_touserdata(L, 1);
    if (p_pmap)
    {
        IMap* p_map = *p_pmap;
        delete p_map;
        *p_pmap = nullptr;
    }
    return 0;
}


static luaL_Reg map_methods[] = {
    
        { "GetVersion",		    MapGetVersion },
        { "GetGridLength",		MapGetGridLength },
        { "GetWidthGridCount",	MapGetXCount },
        { "GetHeightGridCount",	MapGetYCount },
        { "GridData",	        MapGetGridData },
        { "SetGridData",	    MapSetGridData },
        { "__gc",               MapGC },
        { NULL, NULL },
};


void MakeMapMetatable(lua_State* L)
{

    if (luaL_newmetatable(L, MAP_METATABLE))
    {
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_setfuncs(L, map_methods, 0);
    }
    lua_pop(L, 1);
}