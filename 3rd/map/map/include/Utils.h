#pragma once
#include <include/Define.h>

struct lua_State;

extern void StackDump(lua_State* L);

extern uint64 BlockToIndex(int64 x, int64 y, int64 width_block_count);
