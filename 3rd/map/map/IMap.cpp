#include <assert.h>
#include <include/IMap.h>
#include <include/Utils.h>
#include <include/ITerrain.h>

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

Map::Map(ITerrain* source)
    : m_source(source)
{

}


Map::~Map()
{
    m_source = nullptr;
    m_grids.clear();
}


int64 Map::GetVersion() const
{
    if (nullptr == m_source)
    {
        return 0;
    }

    return m_source->GetVersion();
}


float Map::GetGridLength() const
{
    if (nullptr == m_source)
    {
        return 0.0f;
    }

    return m_source->GetGridLength();
}


int64 Map::GetWidthGridCount() const
{
    if (nullptr == m_source)
    {
        return 0;
    }

    return m_source->GetWidthGridCount();
}


int64 Map::GetHeightGridCount() const
{
    if (nullptr == m_source)
    {
        return 0;
    }

    return m_source->GetHeightGridCount();
}


EGridStatus Map::GetGridData(int64 x, int64 y) const
{
    if (nullptr == m_source || x < 0 || y < 0)
    {
        return EGRID_ERROR;
    }

    if (!m_grids.empty())
    {
        uint64 index = BlockToIndex(x, y, m_source->GetWidthGridCount());
        if (index >= m_grids.size())
        {
            return EGRID_ERROR;
        }
        return (EGridStatus)m_grids[index];
    }
    return m_source->GetGridData(x, y);
}


const map_grids& Map::GetGridsData() const
{
    if (!m_grids.empty() || nullptr == m_source)
    {
        return  m_grids;
    }
    return m_source->GetGridsData();

}

bool Map::SetGridData(int64 x, int64 y, EGridStatus block_data)
{
    if (nullptr == m_source || x < 0 || y < 0)
    {
        assert(false);
        return false;
    }

    if (m_grids.empty())
    {
        m_grids = m_source->GetGridsData();
    }
    uint64 index = BlockToIndex(x, y, m_source->GetWidthGridCount());
    if (index >= m_grids.size())
    {
        return false;
    }
    m_grids[index] = (char)block_data;
    return true;
}


/// ---------------------------------------------------------
/// lua ·½·¨
/// ---------------------------------------------------------
static int MapGetVersion(lua_State* L)
{
    IMap* p_map = (IMap*)lua_touserdata(L, 1);
    if (nullptr == p_map)
    {
        return luaL_error(L, "MapGetVersion p_terrain is invalid");
    }
    lua_pushinteger(L, p_map->GetVersion());
    return 1;
}


static int MapGetGridLength(lua_State* L)
{
    IMap* p_map = (IMap*)lua_touserdata(L, 1);
    if (nullptr == p_map)
    {
        return luaL_error(L, "MapGetGridLength p_map is invalid");
    }
    lua_pushnumber(L, p_map->GetGridLength());
    return 1;
}


static int MapGetWidthGridCount(lua_State* L)
{
    IMap* p_map = (IMap*)lua_touserdata(L, 1);
    if (nullptr == p_map)
    {
        return luaL_error(L, "MapGetWidthGridCount p_map is invalid");
    }
    lua_pushinteger(L, p_map->GetWidthGridCount());
    return 1;
}


static int MapGetHeightGridCount(lua_State* L)
{
    IMap* p_map = (IMap*)lua_touserdata(L, 1);
    if (nullptr == p_map)
    {
        return luaL_error(L, "MapGetHeightGridCount p_map is invalid");
    }
    lua_pushinteger(L, p_map->GetHeightGridCount());
    return 1;
}


static int MapGetGridData(lua_State* L)
{
    IMap* p_map = (IMap*)lua_touserdata(L, 1);
    int64 x     = (int64)luaL_checkinteger(L, 2);
    int64 y     = (int64)luaL_checkinteger(L, 3);
    if (nullptr == p_map || x < 0 || y < 0)
    {
        return luaL_error(L, "MapGetGridData p_map is invalid");
    }
    lua_pushinteger(L, (int64)p_map->GetGridData(x, y));
    return 1;
}


static int MapSetGridData(lua_State* L)
{
    IMap* p_map         = (IMap*)lua_touserdata(L, 1);
    int64 x             = (int64)luaL_checkinteger(L, 2);
    int64 y             = (int64)luaL_checkinteger(L, 3);
    EGridStatus status  = (EGridStatus)luaL_checkinteger(L, 4);
    if (nullptr == p_map || x < 0 || y < 0 || status < EGRID_WALKABLE || status > EGRID_BLOCK)
    {
        return luaL_error(L, "MapSetGridData param is invalid");
    }
    lua_pushboolean(L, p_map->SetGridData(x, y, status)) ;
    return 1;
}


static luaL_Reg terrain_methods[] = {
    
        { "GetVersion",		    MapGetVersion },
        { "GetGridLength",		MapGetGridLength },
        { "GetWidthGridCount",	MapGetWidthGridCount },
        { "GetHeightGridCount",	MapGetHeightGridCount },
        { "GridData",	        MapGetGridData },
        { "SetGridData",	    MapSetGridData },
        { NULL, NULL },
};


void MakeMapMetatable(lua_State* L)
{

    if (luaL_newmetatable(L, MAP_METATABLE))
    {
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_setfuncs(L, terrain_methods, 0);
    }
    lua_pop(L, 1);
}