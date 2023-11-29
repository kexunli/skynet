local socket = require "skynet.socket"
local skynet = require "skynet"

local readbytes = socket.read
local writebytes = socket.write

local sockethelper = {}
local socket_error = setmetatable({} , { __tostring = function(t) return "[Socket Error]: "..(t.errmsg or "") end })

sockethelper.socket_error = socket_error

---@param msg string
local function _error(msg)
	socket_error.errmsg = tostring(msg)
	error(socket_error)
end

local function preread(fd, str)
	return function (sz)
		if str then
			if sz == #str or sz == nil then
				local ret = str
				str = nil
				return ret
			else
				if sz < #str then
					local ret = str:sub(1,sz)
					str = str:sub(sz + 1)
					return ret
				else
					sz = sz - #str
					local ret = readbytes(fd, sz)
					if ret then
						return str .. ret
					else
						_error("read failed")
					end
				end
			end
		else
			local ret = readbytes(fd, sz)
			if ret then
				return ret
			else
				_error("read failed")
			end
		end
	end
end

function sockethelper.readfunc(fd, pre)
	if pre then
		return preread(fd, pre)
	end
	return function (sz)
		local ret = readbytes(fd, sz)
		if ret then
			return ret
		else
			_error("read failed")
		end
	end
end

sockethelper.readall = socket.readall

function sockethelper.writefunc(fd)
	return function(content)
		local ok = writebytes(fd, content)
		if not ok then
			_error("write failed")
		end
	end
end

function sockethelper.connect(host, port, timeout)
	local fd, errmsg
	if timeout then
		local drop_fd
		local co = coroutine.running()
		-- asynchronous connect
		skynet.fork(function()
			fd, errmsg = socket.open(host, port)
			if drop_fd then
				-- sockethelper.connect already return, and raise socket_error
				socket.close(fd)
			else
				-- socket.open before sleep, wakeup.
				skynet.wakeup(co)
			end
		end)
		skynet.sleep(timeout)
		if not fd then
			-- not connect yet
			drop_fd = true
			errmsg = errmsg or "timeout"
		end
	else
		-- block connect
		fd, errmsg = socket.open(host, port)
	end
	if fd then
		return fd
	end
	_error(errmsg)
end

function sockethelper.close(fd)
	socket.close(fd)
end

function sockethelper.shutdown(fd)
	socket.shutdown(fd)
end

return sockethelper
