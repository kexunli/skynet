local skynet = require "skynet"
local codecache = require "skynet.codecache"
local core = require "skynet.core"
local socket = require "skynet.socket"
local snax = require "skynet.snax"
local memory = require "skynet.memory"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"

local arg = table.pack(...)
assert(arg.n <= 2)
local ip = (arg.n == 2 and arg[1] or "127.0.0.1")
local port = tonumber(arg[arg.n])
local TIMEOUT = 300 -- 3 sec

local COMMAND = {}
local COMMANDX = {}

local function format_table(t)
	local index = {}
	for k in pairs(t) do
		table.insert(index, k)
	end
	table.sort(index, function(a, b) return tostring(a) < tostring(b) end)
	local result = {}
	for _,v in ipairs(index) do
		table.insert(result, string.format("%s:%s",v,tostring(t[v])))
	end
	return table.concat(result," ")
end

local function dump_line(lines, key, value, format)
	if type(value) == "table" then
		table.insert(lines, string.format(format, key, format_table(value)))
	else
		table.insert(lines, string.format(format, key, tostring(value)))
	end
end

local function dump_list(list)
	local index = {}
	local offset = 0
	for k in pairs(list) do
		table.insert(index, k)
		offset = math.max(offset, #tostring(k))
	end
	table.sort(index, function(a, b) return tostring(a) < tostring(b) end)
	local format = "%-"..offset.."s\t%s"
	local lines = {}
	for _,v in ipairs(index) do
		dump_line(lines, v, list[v], format)
	end
	return table.concat(lines, "\r\n")
end

local function dump_pipeline(print, lines, pipeline)
	if lines == nil or lines == "" or not pipeline or pipeline == "" then
		print(lines)
		return		
	end

	lines = lines:gsub("\"", "\\\"")
	local fd = io.popen("echo \"" .. lines .. "\" " .. pipeline, 'r')
	if not fd then
		print("Failed to open pipeline")
		return
	end

	local result = fd:read("*a")
    fd:close()
    if result then
		print((result:gsub("\r?\n$", "")))
	else
		print("Failed to read pipeline")
	end
end

local bracket_l = ('['):byte(1)
local quotation_s = ("'"):byte(1)
local quotation_d = ('"'):byte(1)
local vertical = ('|'):byte(1)

---@param cmdline string
---@return string[]|nil, string|nil, string|nil
local function split_cmdline(cmdline)
	cmdline = cmdline:gsub("^%s*(.-)%s*$", "%1")
	if cmdline == "" or not cmdline:match("^%a") then
		return { cmdline }
	end

	local cmd = {}
	local pos = 1
	while true do
		local s = cmdline:find("%S", pos)
		if not s then
			return cmd
		end
		local b1, b2 = cmdline:byte(s, s + 1)
		if (b1 == bracket_l and b2 == bracket_l) or b1 == quotation_s or b1 == quotation_d then
			local m = (b1 == bracket_l and b2 == bracket_l) and "]]" or string.char(b1)
			local e = cmdline:find(m, s + #m, true)
			if e then
				table.insert(cmd, cmdline:sub(s + #m, e - 1))
				pos = e + #m
			else
				return nil, nil, "Invalid arguments, missing " .. m
			end	
		elseif b1 == vertical then -- and (not b2 or string.char(b2):match("%s")) then
			return cmd, cmdline:sub(s) --Warning: pipeline conntains |
		else
			local e1, e2, token = cmdline:find("^(%S*)", s)
			local e3 = token:find('|', 1, true)
			if e3 then
				table.insert(cmd, token:sub(1, e3 - 1))
				return cmd, cmdline:sub(e1 + e3 - 1)  --Warning: pipeline conntains |
			else
				table.insert(cmd, token)
				pos = e2 + 1
			end
		end
	end
end

local function docmd(cmdline, print, fd)
	local split, pipeline, errmsg = split_cmdline(cmdline)
	if errmsg then
		print(errmsg)
		return
	end

	local command = split[1]
	local cmd = COMMAND[command]
	local ok, list
	if cmd then
		ok, list = pcall(cmd, table.unpack(split,2))
	else
		cmd = COMMANDX[command]
		if cmd then
			split.fd = fd
			-- split[1] = cmdline
			ok, list = pcall(cmd, split)
		else
			if command and command ~= "" then
				print("Invalid command, type help for command list")
			else
				print()
			end			
			return
		end
	end

	if ok then
		if list then
			if type(list) == "string" then
				dump_pipeline(print, list, pipeline)
			else
				dump_pipeline(print, dump_list(list), pipeline)
			end
		elseif not split.quit then
			print()
		end
		-- print("<CMD OK>")
	else
		print(list)
		-- print("<CMD Error>")
	end

	return split.quit
end

local function console_main_loop(stdin, print, addr)
	print("Welcome to skynet console")
	skynet.error(addr, "connected")
	local ok, err = pcall(function()
		while true do
			local cmdline = socket.readline(stdin, "\n")
			if not cmdline then
				break
			end
			if cmdline:sub(1,4) == "GET " then
				-- http
				local code, url = httpd.read_request(sockethelper.readfunc(stdin, cmdline.. "\n"), 8192)
				local cmdline = url:sub(2):gsub("/"," ")
				docmd(cmdline, print, stdin)
				break
			end
			if cmdline ~= "" and docmd(cmdline, print, stdin) then
				socket.write(stdin, "Bye!\r\n")
				break
			end
		end
	end)
	if not ok then
		skynet.error(stdin, err)
	end
	skynet.error(addr, "disconnect")
	socket.close(stdin)
end

skynet.start(function()
	local listen_socket, ip, port = socket.listen (ip, port)
	skynet.error("Start debug console at " .. ip .. ":" .. port)
	socket.start(listen_socket , function(id, addr)
		local function print(...)
			local t = table.pack(...)
			if t.n > 0 then
				for i = 1, t.n do
					t[i] = tostring(t[i])
				end
				socket.write(id, table.concat(t,"\t"))
				socket.write(id, "\r\n")
			end
			socket.write(id, "#")
		end
		socket.start(id)
		skynet.fork(console_main_loop, id, print, addr)
	end)
end)

function COMMAND.help()
	return {
		help = "This help message",
		list = "List all the service",
		stat = "Dump all stats",
		info = "info address : get service infomation",
		exit = "exit address : kill a lua service",
		kill = "kill address : kill service",
		mem = "mem : show memory status",
		gc = "gc : force every lua service do garbage collect",
		start = "lanuch a new lua service",
		snax = "lanuch a new snax service",
		clearcache = "clear lua code cache",
		service = "List unique service",
		task = "task address : show service task detail",
		uniqtask = "task address : show service unique task detail",
		inject = "inject address luascript.lua",
		logon = "logon address",
		logoff = "logoff address",
		log = "launch a new lua service with log",
		debug = "debug address : debug a lua service",
		signal = "signal address sig",
		cmem = "Show C memory info",
		jmem = "Show jemalloc mem stats",
		ping = "ping address",
		call = "call address ...",
		trace = "trace address [proto] [on|off]",
		netstat = "netstat : show netstat",
		profactive = "profactive [on|off] : active/deactive jemalloc heap profilling",
		dumpheap = "dumpheap : dump heap profilling",
		killtask = "killtask address threadname : threadname listed by task",
		dbgcmd = "run address debug command",
	}
end

function COMMAND.clearcache()
	codecache.clear()
end

function COMMAND.start(...)
	local ok, addr = pcall(skynet.newservice, ...)
	if ok then
		if addr then
			return { [skynet.address(addr)] = ... }
		else
			return "Exit"
		end
	else
		return "Failed"
	end
end

function COMMAND.log(...)
	local ok, addr = pcall(skynet.call, ".launcher", "lua", "LOGLAUNCH", "snlua", ...)
	if ok then
		if addr then
			return { [skynet.address(addr)] = ... }
		else
			return "Failed"
		end
	else
		return "Failed"
	end
end

function COMMAND.snax(...)
	local ok, s = pcall(snax.newservice, ...)
	if ok then
		local addr = s.handle
		return { [skynet.address(addr)] = ... }
	else
		return "Failed"
	end
end

function COMMAND.service()
	return skynet.call("SERVICE", "lua", "LIST")
end

local function adjust_address(address)
	local prefix = address:sub(1,1)
	if prefix == '.' then
		return assert(skynet.localname(address), "Not a valid name")
	elseif prefix ~= ':' then
		address = assert(tonumber("0x" .. address), "Need an address") | (skynet.harbor(skynet.self()) << 24)
	end
	return address
end

local function pattern_address(address)
	if not address then
		error("Need an address")
	end
	if address == "*" then
		return "*"
	end
	local prefix = address:sub(1,1)
	if prefix == 's' and address:sub(1, 5) == "snlua" then
		return address
	end
	if prefix == '.' then
		return assert(skynet.localname(address), "Not a valid name")
	else
		return assert(tonumber(prefix == ':' and address:sub(2) or address, 16), "Need an address") | (skynet.harbor(skynet.self()) << 24)
	end
end

function COMMAND.list()
	return skynet.call(".launcher", "lua", "LIST")
end

COMMAND.ls = COMMAND.list

local function timeout(ti)
	if ti then
		ti = tonumber(ti)
		if ti <= 0 then
			ti = nil
		end
	else
		ti = TIMEOUT
	end
	return ti
end

-- function COMMAND.stat(ti)
-- 	return skynet.call(".launcher", "lua", "STAT", timeout(ti))
-- end

function COMMAND.stat(address)
	return skynet.call(".launcher", "lua", "STAT", timeout(), pattern_address(address or "*"))
end

local function convert_bytes(bytes, humanize)
    if not bytes then
        return "unknown"
    end
	if humanize == "-h" or humanize == "-H" then
		if bytes < 1024 then
			return tostring(bytes) .. " B"
		end
		if bytes < 1024 * 1024 then
			return string.format("%.3f KB", bytes / 1024)
		end
		if bytes < 1024 * 1024 * 1024 then
			return string.format("%.3f MB", bytes / (1024 * 1024))
		end
		return string.format("%.3f GB", bytes / (1024 * 1024 * 1024))
	end
	if humanize == "-k" or humanize == "-K" then
		return string.format("%.3f KB", bytes / 1024)
	end
	if humanize == "-m" or humanize == "-M" then
		return string.format("%.3f MB", bytes / (1024 * 1024))
	end
	if humanize == "-g" or humanize == "-G" then
		return string.format("%.3f GB", bytes / (1024 * 1024 * 1024))
	end
	return tostring(bytes) .. " B"
end

local function convert_mem_list(list, humanize)
	if type(list) == "table" then
		local convert = function(kb)
			return convert_bytes(math.floor(tonumber(kb)*1024), humanize)
		end
		for addr, meminfo in pairs(list) do
			list[addr] = meminfo:gsub("(%d+%.?%d*) KB", convert)
		end
	end
	return list
end

function COMMAND.mem(humanize)
	local list = skynet.call(".launcher", "lua", "MEM", timeout())
	return convert_mem_list(list, humanize)
end

function COMMAND.kill(address)
	return skynet.call(".launcher", "lua", "KILL", adjust_address(address))
end

function COMMAND.gc(address, humanize)
	if address and address:byte(1) == ('-'):byte(1) then
		address, humanize = humanize, address
	end
	local list = skynet.call(".launcher", "lua", "GC", timeout(3000), pattern_address(address or "*"))
	return convert_mem_list(list, humanize)
end

function COMMAND.exit(address)
	skynet.send(adjust_address(address), "debug", "EXIT")
end

local function run(address, source, filename, ...)
	return skynet.call(".launcher", "lua", "RUN", timeout(), pattern_address(address), source, filename, ...)
end

function COMMAND.run(address, source, ...)
	return run(address, source, nil, ...)
end
COMMAND.exec = COMMAND.run

function COMMAND.inject(address, filename, ...)
	local f = io.open(filename, "rb")
	if not f then
		return "Can't open " .. filename
	end
	local source = f:read "*a"
	f:close()
	return run(address, source, filename, ...)	
end

-- function COMMAND.inject(address, filename, ...)
-- 	address = adjust_address(address)
-- 	local f = io.open(filename, "rb")
-- 	if not f then
-- 		return "Can't open " .. filename
-- 	end
-- 	local source = f:read "*a"
-- 	f:close()
-- 	local ok, output = skynet.call(address, "debug", "RUN", source, filename, ...)
-- 	if ok == false then
-- 		error(output)
-- 	end
-- 	return output
-- end

local function check_modules(...)
	local modules = {}
	local count = 0
	for i = 1, select("#", ...) do
		local module = select(i, ...)
		if not module or module == "" then
			error("Invalid module name: " .. tostring(module))
		end
		local path = package.searchpath(module, package.path)
		if not path then
			error("Invalid module name: " .. tostring(module))
		end
		if modules[path] then
			error("Duplicate module name: " .. tostring(module))
		end
		modules[path] = module
		count = count + 1
	end
	assert(count > 0, "Module name needed")
end

function COMMAND.reload(address, ...)
	address = pattern_address(address)
	check_modules(...)
	codecache.clear()
	return skynet.call(".launcher", "lua", "RELOAD", timeout(), address, ...)
end

function COMMAND.dbgcmd(address, cmd, ...)
	address = adjust_address(address)
	return skynet.call(address, "debug", cmd, ...)
end

function COMMAND.task(address)
	return COMMAND.dbgcmd(address, "TASK")
end

function COMMAND.killtask(address, threadname)
	return COMMAND.dbgcmd(address, "KILLTASK", threadname)
end

function COMMAND.uniqtask(address)
	return COMMAND.dbgcmd(address, "UNIQTASK")
end

function COMMAND.info(address, ...)
	-- return COMMAND.dbgcmd(address, "INFO", ...)
	return skynet.call(".launcher", "lua", "INFO", timeout(), pattern_address(address or "*"), ...)
end

function COMMANDX.debug(cmd)
	local address = adjust_address(cmd[2])
	local agent = skynet.newservice "debug_agent"
	local stop
	local term_co = coroutine.running()
	local function forward_cmd()
		repeat
			-- notice :  It's a bad practice to call socket.readline from two threads (this one and console_main_loop), be careful.
			skynet.call(agent, "lua", "ping")	-- detect agent alive, if agent exit, raise error
			local cmdline = socket.readline(cmd.fd, "\n")
			-- cmdline = cmdline and cmdline:gsub("(.*)\r$", "%1")
			cmdline = cmdline and cmdline:gsub("^%s*(.-)%s*$", "%1")
			if not cmdline then
				skynet.send(agent, "lua", "cmd", "cont")
				break
			end
			skynet.send(agent, "lua", "cmd", cmdline)
			if cmdline == "quit" then
				cmd.quit = true
			end
		until stop or cmdline == "cont" or cmdline == "quit"
	end
	skynet.fork(function()
		pcall(forward_cmd)
		if not stop then	-- block at skynet.call "start"
			term_co = nil
		else
			skynet.wakeup(term_co)
		end
	end)
	local ok, err = skynet.call(agent, "lua", "start", address, cmd.fd)
	stop = true
	if term_co then
		-- wait for fork coroutine exit.
		skynet.wait(term_co)
	end

	if not ok then
		error(err)
	end
end

function COMMANDX.quit(cmd)
	cmd.quit = true
end

function COMMAND.logon(address)
	address = adjust_address(address)
	core.command("LOGON", skynet.address(address))
end

function COMMAND.logoff(address)
	address = adjust_address(address)
	core.command("LOGOFF", skynet.address(address))
end

function COMMAND.signal(address, sig)
	address = skynet.address(adjust_address(address))
	if sig then
		core.command("SIGNAL", string.format("%s %d",address,sig))
	else
		core.command("SIGNAL", address)
	end
end

function COMMAND.cmem(humanize)
	local info = memory.info()
	local tmp = {}
	for k,v in pairs(info) do
		tmp[skynet.address(k)] = convert_bytes(v, humanize)
	end
	tmp.total = convert_bytes(memory.total(), humanize)
	tmp.block = convert_bytes(memory.block(), humanize)

	return tmp
end

function COMMAND.jmem()
	local info = memory.jestat()
	local tmp = {}
	for k,v in pairs(info) do
		tmp[k] = string.format("%11d  %8.2f Mb", v, v/1048576)
	end
	return tmp
end

function COMMAND.ping(address)
	address = adjust_address(address)
	local ti = skynet.now()
	skynet.call(address, "debug", "PING")
	ti = skynet.now() - ti
	return tostring(ti)
end

local function toboolean(x)
	return x and (x == "true" or x == "on")
end

function COMMAND.trace(address, proto, flag)
	address = adjust_address(address)
	if flag == nil then
		if proto == "on" or proto == "off" then
			proto = toboolean(proto)
		end
	else
		flag = toboolean(flag)
	end
	skynet.call(address, "debug", "TRACELOG", proto, flag)
end

-- function COMMANDX.call(cmd)
-- 	local address = adjust_address(cmd[2])
-- 	local cmdline = assert(cmd[1]:match("%S+%s+%S+%s(.+)") , "need arguments")
-- 	local args_func = assert(load("return " .. cmdline, "debug console", "t", {}), "Invalid arguments")
-- 	local args = table.pack(pcall(args_func))
-- 	if not args[1] then
-- 		error(args[2])
-- 	end
-- 	local rets = table.pack(skynet.call(address, "lua", table.unpack(args, 2, args.n)))
-- 	return rets
-- end

function COMMANDX.call(address, params)
	local address = adjust_address(address)
	if not params or #params == 0 then
		error("Need arguments for call")
	end
	local args_func = assert(load("return " .. params, "debug console", "t", {}), "Invalid arguments")
	local args = table.pack(pcall(args_func))
	if not args[1] then
		error(args[2])
	end
	local rets = table.pack(skynet.call(address, "lua", table.unpack(args, 2, args.n)))
	return rets
end

local function convert_stat(info)
	local now = skynet.now()
	local function time(t)
		if t == nil then
			return
		end
		t = now - t
		if t < 6000 then
			return tostring(t/100) .. "s"
		end
		local hour = t // (100*60*60)
		t = t - hour * 100 * 60 * 60
		local min = t // (100*60)
		t = t - min * 100 * 60
		local sec = t / 100
		return string.format("%s%d:%.2gs",hour == 0 and "" or (hour .. ":"),min,sec)
	end

	info.address = skynet.address(info.address)
	info.read = convert_bytes(info.read, "-h")
	info.write = convert_bytes(info.write, "-h")
	info.wbuffer = convert_bytes(info.wbuffer, "-h")
	info.rtime = time(info.rtime)
	info.wtime = time(info.wtime)
end

function COMMAND.netstat()
	local stat = socket.netstat()
	for _, info in ipairs(stat) do
		convert_stat(info)
	end
	return stat
end

function COMMAND.dumpheap()
	memory.dumpheap()
end

function COMMAND.profactive(flag)
	if flag ~= nil then
		if flag == "on" or flag == "off" then
			flag = toboolean(flag)
		end
		memory.profactive(flag)
	end
	local active = memory.profactive()
	return "heap profilling is ".. (active and "active" or "deactive")
end

local function convert_time(ts)
    if not ts then
        return "unknown"
    end
    local day, hour, min, sec = 0, 0, 0, 0
    day    = math.floor(ts/24/3600)
    ts     = ts - day * 24*3600
    hour   = math.floor(ts/3600)
    ts     = ts - hour * 3600
    min    = math.floor(ts/60)
    ts     = ts - min * 60
    sec    = ts
    return string.format("%dd %dh %dm %ds", day, hour, min, sec)
end

function COMMAND.uptime()
	return string.format("START: %s, UPTIME: %s", os.date('%Y-%m-%d %X', skynet.starttime()), convert_time(math.floor(skynet.now()/100)))
end
COMMAND.up = COMMAND.uptime
