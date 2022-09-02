#include <include/Utils.h>

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

void stackDump(lua_State* L)
{
    int i;
    int top = lua_gettop(L);
    printf("stackDump(num=%d):\n", top);

    for (i = top; i >= 1; i--) {  /* repeat for each level */
        int t = lua_type(L, i);

        switch (t) {
        case LUA_TSTRING:  /* strings */
            printf("%d, LUA_TSTRING: %s \n", i, lua_tostring(L, i));
            break;
        case LUA_TBOOLEAN:  /* booleans */
            printf("%d, LUA_TBOOLEAN: %s \n", i, lua_toboolean(L, i) ? "true" : "false");
            break;
        case LUA_TNUMBER:  /* numbers */
            printf("%d, LUA_TNUMBER: %g \n", i, lua_tonumber(L, i));
            break;
        case LUA_TTABLE:  /* numbers */
            printf("%d, LUA_TTABLE: %s \n", i, lua_typename(L, i));
            break;
        default:  /* other values */
            printf("%d, OTHER: %s \n", i, lua_typename(L, i));
            break;
        }
    }

    printf("\n");     /* end the listing */

}

uint64 BlockToIndex(int64 x, int64 y, int64 width_block_count)
{
    if (x < 0 || y < 0 || width_block_count < 0)
    {
        return ERROR_INDEX;
    }

    return (width_block_count * y) + x;
}