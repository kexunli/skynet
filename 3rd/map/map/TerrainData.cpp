#include <assert.h>
#include <include/Define.h>
#include <include/TerrainData.h>
#include <include/Utils.h>


TerrainData::TerrainData(int64 version, int64 x_count, int64 y_count, uint64 grids_count, float grid_length, map_grids* grids)
	: m_version(version)
	, m_x_count(x_count)
    , m_y_count(y_count)
    , m_grids_count(grids_count)
    , m_grid_length(grid_length)
	, m_grids(grids)
{

}


TerrainData::~TerrainData()
{
	if (nullptr != m_grids)
	{
		delete[] m_grids;
        m_grids = nullptr;
    }
}


float TerrainData::GetGridLength() const
{
	return m_grid_length;
}


int64 TerrainData::GetVersion() const
{
	return m_version;
}


int64 TerrainData::GetXCount() const
{
	return m_x_count;
}


int64 TerrainData::GetYCount() const
{
	return m_y_count;
}


int64 TerrainData::GetGridsCount() const
{
	return m_grids_count;
}


map_grids* TerrainData::GetGridsData() const
{
	return m_grids;
}


EGridStatus TerrainData::GetGridData(int64 x, int64 y) const
{
	if (x < 0 || y < 0)
	{
		return EGRID_ERROR;
	}

	uint64 index = BlockToIndex(x, y, GetXCount());
	if (index >= m_grids_count)
	{
		return EGRID_ERROR;
	}
	return (EGridStatus)m_grids[index];
}
