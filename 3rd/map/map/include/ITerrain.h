#pragma once
#include <cstddef>
#include <include/Define.h>

class ITerrain
{
public:
    virtual ~ITerrain() {}
    virtual float GetGridLength() const = 0;
    virtual void  SetGridLength(const float length) = 0;

    virtual int64 GetVersion() const = 0;
    virtual void  SetVersion(int64 version) = 0;

    virtual int64 GetWidthGridCount()	const = 0;
    virtual void  SetWidthGridCount(const int64 count) = 0;

    virtual int64 GetHeightGridCount()	const = 0;
    virtual void  SetHeightGridCount(const int64 count) = 0;

    virtual const map_grids& GetGridsData() const = 0;
    virtual void SetGridsData(const char* data, const size_t len) = 0;
    virtual EGridStatus GetGridData(int64 x, int64 y) const = 0;
};


class TerrainSource : public ITerrain
{
public:
    TerrainSource();
    virtual ~TerrainSource();

    virtual float GetGridLength() const;
    virtual void  SetGridLength(const float length);

    virtual int64 GetVersion() const;
    virtual void  SetVersion(const int64 version);

    virtual int64 GetWidthGridCount() const;
    virtual void  SetWidthGridCount(const int64 count);

    virtual int64 GetHeightGridCount() const;
    virtual void  SetHeightGridCount(const int64 count);

    virtual const map_grids& GetGridsData() const;
    virtual void SetGridsData(const char* data, const size_t len);
    virtual EGridStatus GetGridData(int64 x, int64 y) const;

private:
    int64       m_version;
    int64       m_width_count;
    int64       m_height_count;
    float       m_grid_length;
    map_grids	m_grids;
};