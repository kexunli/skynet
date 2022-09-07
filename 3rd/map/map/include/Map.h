#pragma once
#include <include/Define.h>

class TerrainData;

class IMap
{
public:
    virtual ~IMap() {}
    virtual int64 GetVersion()      const = 0;
    virtual float GetGridLength()   const = 0;
    virtual int64 GetXCount()	    const = 0;
    virtual int64 GetYCount()	    const = 0;

    virtual EGridStatus GetGridData(int64 x, int64 y) const = 0;
    virtual bool SetGridData(int64 x, int64 y, EGridStatus block_status) = 0;
};


class Map : public IMap
{
public:
    explicit Map(TerrainData* terrain);
    virtual ~Map();

    virtual int64 GetVersion()      const;
    virtual float GetGridLength()   const;
    virtual int64 GetXCount()	    const;
    virtual int64 GetYCount()	    const;

    virtual EGridStatus GetGridData(int64 x, int64 y) const;
    virtual bool SetGridData(int64 x, int64 y, EGridStatus block_status);

private:
    int64       m_version;
    int64       m_x_count;
    int64       m_y_count;
    uint64      m_grids_count;
    map_grids*  m_grids;
    float       m_grid_length;
    bool        m_grids_shared;
};
