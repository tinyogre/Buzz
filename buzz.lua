#!/Users/ogre/src/luajit-2.0/src/luajit
module(..., package.seeall)

local Socket = require('socket')
local Request = require('request')
require('slice')
require('log')
require('date')

getreqs = {}
postreqs = {}

--
-- Add a get handler
--
-- Examples:
-- Simple URL
-- buzz.get('/', main_handler)
-- 
-- A handler that takes an argument
-- buzz.get('/list/(.*)', list_handler)
--
function get(pattern, func)
  di = debug.getinfo(func, 'S')
  log('adding get: '..pattern..'=>'..di.short_src..':'..di.linedefined)
  getreqs[pattern] = func
end

function post(pattern, func)
  di = debug.getinfo(func, 'S')
  log('adding post: '..pattern..'=>'..di.short_src..':'..di.linedefined)
  postreqs[pattern] = func
end

function trim(s) 
  return s:match'^%s*(.*%S)' or '' 
end

function add_headers(request)
  if not request.headers then request.headers = {} end

  local d = date(true)
  local base = {
	['Content-Type'] = 'text/html; charset=utf-8',
	['Date'] = d:toutc():fmt('%a, %d %b %Y %H:%M:%S GMT'),
	['Server'] = 'Buzz',
	['Connection'] = 'close'
  }
  for k,v in pairs(base) do 
	if not request.headers[k] then
	  request.headers[k:lower()] = v 
	end
  end
end

errors = {
  [400] = 'Bad Request',
  [404] = 'Not Found',
  [500] = 'Internal Server Error'
}

function write_headers(request)
  for k,v in pairs(request.headers) do
	request.socket:write(k..': '..v..'\r\n')
  end
end

function send_error(request, code, resp)
  error(request, code, resp)
end

function error(request, code, resp)
  log('ERR '..code..' '..resp)

  add_headers(request)
  if not errors[code] then code = 500 end
  request.socket:write('HTTP/1.1 '..code..' '..errors[code]..'\r\n')
  write_headers(request)
  request.socket:write('\r\n')
end
  
function response(request, resp)
  add_headers(request)

  request.socket:write('HTTP/1.1 200 OK\r\n') -- Call error() for anything other than 200
  write_headers(request)

  request.socket:write('\r\n')
  request.socket:write(resp)
end

function check_cli_headers(request)
  -- HTTP 1.1 clients must provide Host
  if request.proto ~= 'HTTP/1.0' and not request.cli_headers['host'] then
	return false
  end
  return true
end

function call_handler(request, reqtable)
  for k,v in pairs(reqtable) do
    local args = {string.find(request.uri, k)}
    if #args > 0 then
      -- Found a matching handler, build a request object and call it
      v(request, table_slice(args, 3))
      found = true
      break
    end
  end
  if not found then
    error(request, 404, '')
  end
end

function handle_request(request)
  log('uri:'..request.uri)

  -- Validate
  if not check_cli_headers(request) then
    log('check_cli_headers failed')
    error(request, 400, '')
    return false
  end

  local found = false
  if not request.headers then request.headers = {} end

  -- What method?
  if request.method == "GET" then
    call_handler(request, getreqs)
  elseif request.method == "POST" then
    call_handler(request, postreqs)
  end
  return true
end

local conns = {}

function add_conn(newsock)
  conns[#conns + 1] = newsock
end

function del_conn(sock)
  for i=1,#conns do
	if conns[i] == sock then
	  trace('removed socket with fd='..sock.fd)
	  table.remove(conns, i)
	  return
	end
  end
end

function do_read(sock)
  trace('do_read')
  if not sock.request then
	sock.request = Request()
	sock.request.socket = sock
  end
  repeat
	size, buf = sock:read(1024)
	if size > 0 then
	  sock.request:add_data(buf)
	end
  until size ~= 1024
  if size < 0 then
	perror('read')
	sock:close()
	del_conn(sock)
	return
  end

  if not sock.request.headers_complete then	return end
  if sock.request.method == "POST" and not sock.request.data_complete then return end

  handle_request(sock.request)

  log('Closing connection')
  sock:close()
  del_conn(sock)
end

function init(port)
  if not port then port = 9001 end
  listensock = Socket()
  if not listensock:listen(0, port) then
	log('Failed to open listen socket, exiting')
	return
  end
  
  conns[1] = listensock
end

function poll(delay)
  trace('polling '..#conns..' sockets')
  local ready = Socket.poll(conns, delay)
  trace('poll returned')
  for s=1,#ready do
    trace('socket with fd='..ready[s].fd..' ready')
    if ready[s] == listensock then
      trace('Calling accept')
      newsock = listensock:accept()
      if newsock.fd < 0 then
        perror('accept')
        break
      else
        add_conn(newsock)
      end
    else
      do_read(ready[s])
    end
  end
end

function run(port)
  init(port)

  while true do
    poll(1000)
  end
end
