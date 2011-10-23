
local ffi = require('ffi')
require('date')

ffi.cdef [[
	char *strerror(int errnum);
]]

-- Sure, could just wrap perror, but this is more flexible
function perror(msg)
  print(msg .. ': ' .. ffi.string(ffi.C.strerror(ffi.errno())))
end

function log(s)
  print(s)
end

