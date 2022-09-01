#include <assert.h>
#include <include/Define.h>
#include <include/ITerrain.h>
#include <include/Utils.h>

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

TerrainSource::TerrainSource()
	: m_version(0)
	, m_width_count(0)
	, m_height_count(0)
    , m_grid_length(0.0)
{

}


TerrainSource::~TerrainSource()
{
	m_grids.clear();
}


float TerrainSource::GetGridLength() const
{
	return m_grid_length;
}


void TerrainSource::SetGridLength(const float length)
{
	m_grid_length = length;
}


int64 TerrainSource::GetVersion() const
{
	return m_version;
}

void  TerrainSource::SetVersion(const int64 version)
{
	if (version < 0)
	{
		return;
	}
	m_version = version;
}


int64 TerrainSource::GetWidthGridCount() const
{
	return m_width_count;
}


void TerrainSource::SetWidthGridCount(const int64 count)
{
    if (count < 0)
    {
        return;
    }
	m_width_count = count;
}


int64 TerrainSource::GetHeightGridCount() const
{
	return m_height_count;
}


void TerrainSource::SetHeightGridCount(const int64 count)
{
    if (count < 0)
    {
        return;
    }
	m_height_count = count;
}


const map_grids& TerrainSource::GetGridsData() const
{
	return m_grids;
}


void TerrainSource::SetGridsData(const char* data, const size_t len)
{
	m_grids.clear();
	m_grids.reserve(len + 1);
	for (uint64 i = 0; i < len; ++i)
	{
        m_grids.push_back(data[i] - '0');

	}
}


EGridStatus TerrainSource::GetGridData(int64 x, int64 y) const
{
	if (x < 0 || y < 0)
	{
		return EGRID_ERROR;
	}

	uint64 index = BlockToIndex(x, y, GetWidthGridCount());
	if (index >= m_grids.size())
	{
		return EGRID_ERROR;
	}
	return (EGridStatus)m_grids[index];
}
