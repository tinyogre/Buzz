#!/Users/ogre/src/luajit-2.0/src/luajit

module(..., package.seeall)

local ffi = require('ffi')
local socket = require('socket')
require('slice')

ffi.cdef[[
	int printf(const char *, ...);
]]

function log(s)
  ffi.C.printf('%s\n', s)
end

getreqs = {}
function get(pattern, func)
  di = debug.getinfo(func, 'S')
  log('adding get: '..pattern..'=>'..di.short_src..':'..di.linedefined)
  getreqs[pattern] = func
end

--args = {string.find('/abc/', '^/(.*)/', 0)}
--if args then
--  print(args[3])
--end

function response(resp)
end

function run()
  sock = socket.listen(0, 9001)

  while true do
	newsock = socket.accept(sock)
	if sock < 0 then
	  socket.perror('accept')
	  break
	end

	size, req = socket.read(newsock, 1024)
	if size > 0 then	  
	  if string.find(req, "GET ") then
		uri = string.sub(req, 5, nil)
		for k,v in pairs(getreqs) do
		  args = {string.find(uri, k)}
		  if args then
			v(req, table_slice(args, 3))
			break
		  end
		end
	  end
	end
	socket.close(newsock)
  end
end
