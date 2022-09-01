#pragma once
#include <include/Define.h>

class ITerrain;

class IMap
{
public:
    virtual ~IMap() {}
    virtual int64 GetVersion()	        const = 0;
    virtual float GetGridLength()		const = 0;
    virtual int64 GetWidthGridCount()	const = 0;
    virtual int64 GetHeightGridCount()	const = 0;

    virtual const map_grids& GetGridsData() const = 0;
    virtual EGridStatus GetGridData(int64 x, int64 y) const = 0;
    virtual bool SetGridData(int64 x, int64 y, EGridStatus block_data) = 0;
};


class Map : public IMap
{
public:
    explicit Map(ITerrain* source);
    virtual ~Map();

    virtual int64 GetVersion()	        const;
    virtual float GetGridLength()		const;
    virtual int64 GetWidthGridCount()	const;
    virtual int64 GetHeightGridCount()	const;

    virtual const map_grids& GetGridsData() const;
    virtual EGridStatus GetGridData(int64 x, int64 y) const;
    virtual bool SetGridData(int64 x, int64 y, EGridStatus block_data);

private:
    ITerrain*	m_source;
    map_grids	m_grids;
};
