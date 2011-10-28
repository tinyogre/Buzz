local M = {}; M.__index = M
require('log')

local function construct()
  local self = setmetatable({
							  fd = -1
							}, M)
  return self
end
setmetatable(M, {__call = construct})

local ffi = require('ffi')

-- This file is ultimately a losing battle, every OS is going to implement this stuff slightly differently
-- But it'll do to get things started (on OS X)
-- Later, this should just be a C module itself with a configure script or WHATEVER
ffi.cdef [[
	typedef size_t socklen_t;
	typedef struct { 
	  uint8_t sa_len;
	  unsigned char sa_family;
	  unsigned char sa_data[14];
	} sockaddr;

	typedef struct {
	  uint8_t	sin_len;
	  uint8_t	sin_family;
	  uint16_t	sin_port;
	  uint32_t  sin_addr;
	  char		sin_zero[8];
	} sockaddr_in;

	int socket(int domain, int type, int protocol);
	int bind(int socket, const sockaddr_in *address, socklen_t address_len);
	int	listen(int socket, int backlog);
	int accept(int socket, struct sockaddr *restrict address, socklen_t *address_len);
	size_t read(int fildes, void *buf, size_t nbyte);
	size_t write(int fildes, const void *buf, size_t nbyte);
	int close(int fd);
]]

PF_INET = 2
SOCK_STREAM = 1

local sockaddr_in
local mt = {}

sockaddr_in = ffi.metatype('sockaddr_in', mt)

local bit = require('bit')
local function htons(num)
  return bit.bor(bit.lshift(bit.band(num, 0xff), 8), bit.rshift(bit.band(num, 0xff00), 8))
end

function M:listen(addr, port)
  self.fd = ffi.C.socket(PF_INET, SOCK_STREAM, 0)
  if self.fd < 0 then
	perror('socket')
	return -1
  end

  local addr = sockaddr_in(16, PF_INET, htons(port), addr, '\0\0\0\0\0\0\0\0')
  res = ffi.C.bind(self.fd, addr, 16)
  if res ~= 0 then
	perror('bind')
	return -1
  end

  res = ffi.C.listen(self.fd, 100)
  if res ~= 0 then
	perror('listen')
	return -1
  end

  return true
end

function M:accept()
  newsock = construct()
  newsock.fd = ffi.C.accept(self.fd, nil, nil)
  return newsock
end

function M:read(len)
  buffer = ffi.new("char[?]", len)
  size = ffi.C.read(self.fd, buffer, len)
  return size, ffi.string(buffer)
end

function M:readline(len)
  -- This seems really really dumb (inefficient), FIXME later (build it into the C module when there is one)
  -- Or at least do buffered reads and smartly build the line up
  local cbuf = ffi.new("char[1]")
  local line = ''
  local state = 0
  local done = false
  while not done do
	local size = ffi.C.read(self.fd, cbuf, 1)
	if size < 0 then
	  return nil
	elseif size == 1 then
	  local c = ffi.string(cbuf, 1)
	  if state == 0 then
		if c == '\r' then
		  state = 1
		elseif c == '\n' then
		  -- Something's behaving badly sending just a \n line ending, but useful for testing with netcat,
		  -- and probably wise in general
		  done=true
		else
		  line = line..c
		end
	  elseif state == 1 then
		if c == '\n' then
		  done=true
		else
		  state = 0
		end
	  end
	end
  end
  return line
end

function M:write(str)
  ffi.C.write(self.fd, str, #str)
end

function M:close()
  ffi.C.close(self.fd)
end

return M
