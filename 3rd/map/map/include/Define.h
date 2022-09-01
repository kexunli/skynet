#pragma once
#include <vector>

#define MAP_METATABLE		"__MAP_MT"

using int32  = int;
using uint32 = unsigned int;
using int64  = long long;
using uint64 = unsigned long long;
using map_grids = std::vector<char>;

enum EGridStatus
{
    EGRID_WALKABLE	= 0,
    EGRID_BLOCK	    = 1,
    EGRID_ERROR	    = 2,
};
