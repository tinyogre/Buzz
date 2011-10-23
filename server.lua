#!/Users/ogre/src/luajit-2.0/src/luajit
local ffi = require('ffi')
local socket = require('socket')

ffi.cdef[[
	int printf(const char *, ...);
]]

function log(s)
  ffi.C.printf('%s\n', s)
end

sock = listen(0, 9001)
log('Listening, sock='..sock)

newsock = accept(sock)
print('accepted! sock=' .. newsock)
