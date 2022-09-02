#pragma once
#include <cstddef>
#include <include/Define.h>

class TerrainData
{
public:
    TerrainData(int64 version, int64 x_count, int64 y_count, uint64 grids_count, float grid_length, map_grids* grids);
    virtual ~TerrainData();

    virtual float GetGridLength()   const;
    virtual int64 GetVersion()      const;
    virtual int64 GetXCount()       const;
    virtual int64 GetYCount()       const;
    virtual int64 GetGridsCount()   const;

    virtual map_grids* GetGridsData() const;
    virtual EGridStatus GetGridData(int64 x, int64 y) const;

private:
    int64                   m_version;
    int64                   m_x_count;
    int64                   m_y_count;
    uint64                  m_grids_count;
    float                   m_grid_length;
    map_grids* 	            m_grids;
};