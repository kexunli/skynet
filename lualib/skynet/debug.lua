local table = table
local extern_dbgcmd = {}

local function init(skynet, export)
	local internal_info_func

	function skynet.info_func(func)
		internal_info_func = func
	end

	---@alias debug_genenv_t fun(printer:fun(...), env:table)
	
	---@type debug_genenv_t
	local debug_genenv
	---@param func  debug_genenv_t|nil
	function skynet.debug_genenv(func)
		assert(func == nil or type(func) == "function")
		debug_genenv = func
	end

	local dbgcmd

	local function init_dbgcmd()
		dbgcmd = {}

		function dbgcmd.MEM()
			local kb = collectgarbage "count"
			skynet.ret(skynet.pack(kb))
		end

		-- local gcing = false
		-- function dbgcmd.GC()
		-- 	if gcing then
		-- 		return
		-- 	end
		-- 	gcing = true
		-- 	local before = collectgarbage "count"
		-- 	local before_time = skynet.now()
		-- 	collectgarbage "collect"
		-- 	-- skip subsequent GC message
		-- 	skynet.yield()
		-- 	local after = collectgarbage "count"
		-- 	local after_time = skynet.now()
		-- 	skynet.error(string.format("GC %.2f Kb -> %.2f Kb, cost %.2f sec", before, after, (after_time - before_time) / 100))
		-- 	gcing = false
		-- end
	
		function dbgcmd.GC()
			local before = collectgarbage "count"
			local before_time = skynet.now()
			collectgarbage "collect"
			local after = collectgarbage "count"
			local after_time = skynet.now()
			skynet.ret(skynet.pack(before, after, (after_time - before_time) / 100))
		end

		function dbgcmd.STAT()
			local stat = {}
			stat.task = skynet.task()
			stat.mqlen = skynet.stat "mqlen"
			stat.cpu = skynet.stat "cpu"
			stat.message = skynet.stat "message"
			skynet.ret(skynet.pack(stat))
		end

		function dbgcmd.KILLTASK(threadname)
			local co = skynet.killthread(threadname)
			if co then
				skynet.error(string.format("Kill %s", co))
				skynet.ret()
			else
				skynet.error(string.format("Kill %s : Not found", threadname))
				skynet.ret(skynet.pack "Not found")
			end
		end

		function dbgcmd.TASK(session)
			if session then
				skynet.ret(skynet.pack(skynet.task(session)))
			else
				local task = {}
				skynet.task(task)
				skynet.ret(skynet.pack(task))
			end
		end

		function dbgcmd.UNIQTASK()
			skynet.ret(skynet.pack(skynet.uniqtask()))
		end

		function dbgcmd.INFO(...)
			if internal_info_func then
				skynet.ret(skynet.pack(internal_info_func(...)))
			else
				skynet.ret(skynet.pack(nil))
			end
		end

		function dbgcmd.EXIT()
			skynet.exit()
		end

		-- function dbgcmd.RUN(source, filename, ...)
		-- 	local inject = require "skynet.inject"
		-- 	local args = table.pack(...)
		-- 	local ok, output = inject(skynet, nil, source, filename, args, export.dispatch, skynet.register_protocol)
		-- 	collectgarbage "collect"
		-- 	skynet.ret(skynet.pack(ok, table.concat(output, "\r\n")))
		-- end

		function dbgcmd.RUN(source, filename, ...)
			local output = {}
			local function print(...)
				local argc = select("#", ...)
				if argc <= 0 then
					return
				end
				if argc == 1 then
					table.insert(output, tostring(...))
					return
				end
				local value = { ... }
				for k = 1, argc do
					value[k] = tostring(value[k])
				end
				table.insert(output, table.concat(value, "\t"))
			end
			local env = setmetatable({ print = print }, { __index = _ENV })
			if debug_genenv then
				debug_genenv(print, env)
			end

			local inject = require "skynet.inject"
			local args = table.pack(...)
			local ok, err = inject(skynet, env, source, filename, args, export.dispatch, skynet.register_protocol)
			if not ok and err ~= nil then
				table.insert(output, tostring(err))
			end
			collectgarbage "collect"
			skynet.ret(skynet.pack(ok, table.concat(output, "\r\n")))
		end

		function dbgcmd.RELOAD(...)
            local modules = {}
            for i = 1, select("#", ...) do
                local module = select(i, ...)
				if package.loaded[module] then
					package.loaded[module] = nil
					table.insert(modules, module)
				end
            end
			table.sort(modules)
            for _, module in ipairs(modules) do
                require(module)
            end
			skynet.ret(skynet.pack(table.concat(modules, ", ")))
		end

		function dbgcmd.TERM(service)
			skynet.term(service)
		end

		function dbgcmd.REMOTEDEBUG(fd, ...)
			local socketdriver = require "skynet.socketdriver"
			local function _puts(...)
				local tmp = table.pack(...)
				for i=1,tmp.n do
					tmp[i] = tostring(tmp[i])
				end
				return table.concat(tmp, "\t")
			end
			local function puts(...)
				socketdriver.send(fd, _puts(...))
			end
			local function print(...)
				socketdriver.send(fd, _puts(...).."\r\n")
			end
			local env = { print = print, puts = puts }
			if debug_genenv then
				debug_genenv(print, env)
			end
			local remotedebug = require "skynet.remotedebug"
			remotedebug.start(export, env, ...)
		end

		function dbgcmd.SUPPORT(pname)
			return skynet.ret(skynet.pack(skynet.dispatch(pname) ~= nil))
		end

		function dbgcmd.PING()
			return skynet.ret()
		end

		function dbgcmd.LINK()
			skynet.response()	-- get response , but not return. raise error when exit
		end

		function dbgcmd.TRACELOG(proto, flag)
			if type(proto) ~= "string" then
				flag = proto
				proto = "lua"
			end
			skynet.error(string.format("Turn trace log %s for %s", flag, proto))
			skynet.traceproto(proto, flag)
			skynet.ret()
		end

		return dbgcmd
	end -- function init_dbgcmd

	local function _debug_dispatch(session, address, cmd, ...)
		dbgcmd = dbgcmd or init_dbgcmd() -- lazy init dbgcmd
		local f = dbgcmd[cmd] or extern_dbgcmd[cmd]
		assert(f, cmd)
		f(...)
	end

	skynet.register_protocol {
		name = "debug",
		id = assert(skynet.PTYPE_DEBUG),
		pack = assert(skynet.pack),
		unpack = assert(skynet.unpack),
		dispatch = _debug_dispatch,
	}
end

local function reg_debugcmd(name, fn)
	extern_dbgcmd[name] = fn
end

return {
	init = init,
	reg_debugcmd = reg_debugcmd,
}
