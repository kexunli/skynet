local skynet = require "skynet"
local core = require "skynet.core"
require "skynet.manager"	-- import manager apis
local string = string

local services = {}
local command = {}
local instance = {} -- for confirm (function command.LAUNCH / command.ERROR / command.LAUNCHOK)
local launch_session = {} -- for command.QUERY, service_address -> session

local function handle_to_address(handle)
	return tonumber("0x" .. string.sub(handle , 2))
end

local NORET = {}

function command.LIST()
	local list = {}
	for k,v in pairs(services) do
		list[skynet.address(k)] = v
	end
	return list
end

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

local function show_func(show_fmt, addr, result)
	local result_s = type(result) == "table" and format_table(result) or tostring(result)
	if show_fmt then
		return string.format(show_fmt, tostring(services[addr]), result_s)
	else
		return result_s 
	end
end

local function list_srv(ti, svcs, show_svc, fmt_func, ...)
	local list = {}
	local sessions = {}
	local req = skynet.request()
	local svc_offset = 0
	for addr, service in pairs(svcs) do
		local r = { addr, "debug", ... }
		req:add(r)
		sessions[r] = addr
		svc_offset = math.max(svc_offset, #tostring(service))
	end
	local show_fmt = show_svc and "%-"..svc_offset.."s\t%s" or nil
	for req, resp in req:select(ti) do
		local addr = req[1]
		if resp then
			list[skynet.address(addr)] = show_func(show_fmt, addr, fmt_func(addr, nil, table.unpack(resp, 1, resp.n)))
		else
			list[skynet.address(addr)] = show_func(show_fmt, addr, fmt_func(addr, "ERROR"))
		end
		sessions[req] = nil
	end
	for session, addr in pairs(sessions) do
		list[skynet.address(addr)] = show_func(show_fmt, addr, fmt_func(addr, "TIMEOUT"))
	end
	return list
end

local function select_pat(pattern)
	local svcs = {}
	local pattern_s = pattern and "^"..pattern.."$" or nil
	for addr, service in pairs(services) do
		if not pattern_s or string.find(service, pattern_s) then
			svcs[addr] = service
		end
	end
	return svcs
end

local function list_pat(ti, pattern, show_svc, fmt_func, ...)
	local handle = tonumber(pattern)
	if handle then
		return list_srv(ti, { [handle] = tostring(services[handle]) }, show_svc, fmt_func, ...)
	elseif pattern then
		return list_srv(ti, pattern == "*" and services or select_pat(pattern), show_svc, fmt_func, ...)
	end
end

function command.STAT(addr, ti, pattern)
	return list_pat(ti, pattern, true, function(_, err, stat) return err or stat end, "STAT")
end

function command.KILL(_, handle)
	skynet.kill(handle)
	local ret = { [skynet.address(handle)] = tostring(services[handle]) }
	services[handle] = nil
	return ret
end

function command.MEM(addr, ti)
	return list_srv(ti, services, true, function(addr, err, kb)
		return err or string.format("%.3f KB", kb)
	end, "MEM")
end

-- function command.GC(addr, ti)
-- 	for k,v in pairs(services) do
-- 		skynet.send(k,"debug","GC")
-- 	end
-- 	return command.MEM(addr, ti)
-- end

function command.GC(addr, ti, pattern)
	return list_pat(ti, pattern, true, function(addr, err, kb_before, kb_after, cost_sec)
		return err or string.format("%.3f KB <- %.3f KB, %.2f sec", kb_after, kb_before, cost_sec)
	end, "GC")
end

function command.INFO(addr, ti, pattern, ...)
	return list_pat(ti, pattern, true, function(_, err, info) return err or info end, "INFO", ...)
end

function command.RUN(addr, ti, pattern, source, filename, ...)
	return list_pat(ti, pattern, true, function(_, err, ok, output)
		if err then
			return err
		end
		local msg = type(output) == "table" and format_table(output) or tostring(output)
		return (ok and "OK" or "ERROR") .. "\t" .. msg
	end, "RUN", source, filename, ...)
end

function command.RELOAD(addr, ti, pattern, ...)
	return list_pat(ti, pattern, true, function(_, err, result) return err or result end, "RELOAD", ...)
end

function command.REMOVE(_, handle, kill)
	services[handle] = nil
	local response = instance[handle]
	if response then
		-- instance is dead
		response(not kill)	-- return nil to caller of newservice, when kill == false
		instance[handle] = nil
		launch_session[handle] = nil
	end

	-- don't return (skynet.ret) because the handle may exit
	return NORET
end

local function launch_service(service, ...)
	local param = table.concat({...}, " ")
	local inst = skynet.launch(service, param)
	local session = skynet.context()
	local response = skynet.response()
	if inst then
		services[inst] = service .. " " .. param
		instance[inst] = response
		launch_session[inst] = session
	else
		response(false)
		return
	end
	return inst
end

function command.LAUNCH(_, service, ...)
	launch_service(service, ...)
	return NORET
end

function command.LOGLAUNCH(_, service, ...)
	local inst = launch_service(service, ...)
	if inst then
		core.command("LOGON", skynet.address(inst))
	end
	return NORET
end

function command.ERROR(address)
	-- see serivce-src/service_lua.c
	-- init failed
	local response = instance[address]
	if response then
		response(false)
		launch_session[address] = nil
		instance[address] = nil
	end
	services[address] = nil
	return NORET
end

function command.LAUNCHOK(address)
	-- init notice
	local response = instance[address]
	if response then
		response(true, address)
		instance[address] = nil
		launch_session[address] = nil
	end

	return NORET
end

function command.QUERY(_, request_session)
	for address, session in pairs(launch_session) do
		if session == request_session then
			return address
		end
	end
end

-- for historical reasons, launcher support text command (for C service)

skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(session, address , cmd)
		if cmd == "" then
			command.LAUNCHOK(address)
		elseif cmd == "ERROR" then
			command.ERROR(address)
		else
			error ("Invalid text command " .. cmd)
		end
	end,
}

skynet.dispatch("lua", function(session, address, cmd , ...)
	cmd = string.upper(cmd)
	local f = command[cmd]
	if f then
		local ret = f(address, ...)
		if ret ~= NORET then
			skynet.ret(skynet.pack(ret))
		end
	else
		skynet.ret(skynet.pack {"Unknown command"} )
	end
end)

skynet.start(function() end)
