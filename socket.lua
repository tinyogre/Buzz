module(..., package.seeall)

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
	char *strerror(int errnum);
	int errno;
]]

PF_INET = 2
SOCK_STREAM = 1

local sockaddr_in
local mt = {}

sockaddr_in = ffi.metatype('sockaddr_in', mt)

local bit = require('bit')
function htons(num)
  return bit.bor(bit.lshift(bit.band(num, 0xff), 8), bit.rshift(bit.band(num, 0xff00), 8))
end

-- Sure, could just wrap perror, but this is more flexible
function perror(msg)
  log(msg .. ': ' .. ffi.string(ffi.C.strerror(ffi.errno)))
end

function listen(addr, port)
  sock = ffi.C.socket(PF_INET, SOCK_STREAM, 0)
  if sock < 0 then
	perror('socket')
	return -1
  end

  local addr = sockaddr_in(16, PF_INET, htons(port), addr, '\0\0\0\0\0\0\0\0')
  res = ffi.C.bind(sock, addr, 16)
  if res ~= 0 then
	perror('bind')
	return -1
  end

  res = ffi.C.listen(sock, 16)
  if res ~= 0 then
	perror('listen')
	return -1
  end

  return sock
end

function accept(sock)
  newsock = ffi.C.accept(sock, nil, nil)
  return newsock
end

function read(sock, len)
  buffer = ffi.new("char[?]", len)
  size = ffi.C.read(sock, buffer, len)
  return size, ffi.string(buffer)
end

function write(sock, str)
  ffi.C.write(sock, str, #str)
end

function close(sock)
  ffi.C.close(sock)
end
