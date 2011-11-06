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
-- Something that generated this block from system headers could work too.  I do like not having any actual C.
-- Tested on Linux and it seems to work just fine with only a couple of constants changed for SO_REUSEADDR.  
-- Maybe I'll just keep it unless someone complains.
ffi.cdef [[
	typedef size_t socklen_t;
	typedef unsigned int nfds_t;
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

	typedef struct {
	  int fd;
	  short events;
	  short revents;
	} pollfd;

	int socket(int domain, int type, int protocol);
	int bind(int socket, const sockaddr_in *address, socklen_t address_len);
	int	listen(int socket, int backlog);
	int accept(int socket, struct sockaddr *restrict address, socklen_t *address_len);
	size_t read(int fildes, void *buf, size_t nbyte);
	size_t write(int fildes, const void *buf, size_t nbyte);
	int close(int fd);
	int fcntl(int fd, int cmd, ...);
	int poll(pollfd *fds, nfds_t nfds, int timeout);
	int setsockopt(int socket, int level, int option_name, const void *option_value, socklen_t option_len);
]]

PF_INET = 2
SOCK_STREAM = 1

POLLIN=0x0001
POLLPRI=0x0002
POLLOUT=0x0004
POLLRDNORM=0x0040
POLLWRNORM=POLLOUT
POLLRDBAND=0x0080
POLLWRBAND=0x0100
POLLERR=0x0008
POLLHUP=0x0010
POLLNVAL=0x0020

O_NONBLOCK=0x0004

F_GETFL=3
F_SETFL=4

if ffi.os == 'Linux' then
  SO_REUSEADDR=2
  SOL_SOCKET=1
elseif ffi.os == 'OSX' then
  SO_REUSEADDR=4
  SOL_SOCKET=0xffff
else
  print("Hey!  I don't know what platform you're on, go add your platform values to socket.lua!")
end

local sockaddr_in
local mt = {}

sockaddr_in = ffi.metatype('sockaddr_in', mt)
pollfd = ffi.metatype('pollfd', mt)

--
-- Internal functions
--
local bit = require('bit')
local function htons(num)
  return bit.bor(bit.lshift(bit.band(num, 0xff), 8), bit.rshift(bit.band(num, 0xff00), 8))
end

function nonblock(fd)
  flags = ffi.C.fcntl(fd, F_GETFL, ffi.new("int", 0))
  if flags == -1 then
	flags = 0
  end
  ffi.C.fcntl(fd, F_SETFL, ffi.new("int", bit.bor(flags, O_NONBLOCK)))
end

function M:listen(addr, port)
  self.fd = ffi.C.socket(PF_INET, SOCK_STREAM, 0)
  if self.fd < 0 then
	perror('socket')
	return false
  end

  local val = ffi.new("int[1]", 1)
  if ffi.C.setsockopt(self.fd, SOL_SOCKET, SO_REUSEADDR, val, ffi.sizeof("int")) ~= 0 then
	perror('setsockopt '..ffi.errno()..' ')
  end

  local addr = sockaddr_in(16, PF_INET, htons(port), addr, '\0\0\0\0\0\0\0\0')
  res = ffi.C.bind(self.fd, addr, 16)
  if res ~= 0 then
	perror('bind')
	return false
  end

  res = ffi.C.listen(self.fd, 100)
  if res ~= 0 then
	perror('listen')
	return false
  end
  nonblock(self.fd)
  return true
end

-- take an array of sockets (this lua structure variety)
-- return an array of sockets with pending events
function M.poll(socks, timeout)
  local fds = ffi.new('pollfd[?]', #socks)
  for i=0,#socks - 1 do
	fds[i].fd = socks[i+1].fd
	fds[i].events = bit.bor(bit.bor(POLLIN, POLLERR), POLLHUP)
	fds[i].revents = 0 -- Not necessary, ffi.new zeros memory
  end
  res = ffi.C.poll(fds, #socks, timeout)
  local retsocks = {}
  for i=0,#socks - 1 do
	if bit.band(fds[i].revents, POLLIN) ~= 0 then
	  retsocks[#retsocks + 1] = socks[i + 1]
	end
  end
  return retsocks
end

--function M:poll(timeout)
--  local pfd = pollfd(self.fd, POLLIN, 0)

--  res = ffi.C.poll(pfd, 1, timeout)
--  return res > 0
--end

function M:accept()
  newsock = construct()
  newsock.fd = ffi.C.accept(self.fd, nil, nil)
  nonblock(newsock.fd)
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
