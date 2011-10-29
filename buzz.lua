#!/Users/ogre/src/luajit-2.0/src/luajit
module(..., package.seeall)

local Socket = require('socket')
local Request = require('request')
require('slice')
require('log')
require('date')

getreqs = {}

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
  for k,v in pairs(base) do request.headers[k] = v end
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

function error(request, code, resp)
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

function read_request(newsock)
  local request = Request()
  request.socket = newsock
  while true do
	local line = newsock:readline(10000)
	if line then
	  if #line == 0 then
		return request
	  else
		if not request.method then
		  _,_,request.method,request.uri,request.proto = string.find(line, '^([A-Z]*) ([^ ]*) (HTTP/1.%d)$')
		  if request.method then
			request.request_line = line
			if request.proto and request.proto ~= 'HTTP/1.0' then
			  request.socket:write('HTTP/1.1 100 Continue\r\n\r\n')
			end
			table.insert(request, line)
		  else
			-- HTTP/1.0 maybe?
			_,_,request.method,request.uri = string.find(line, '^([A-Z]*) ([^ ]*)$')
			if not request.method then
			  -- Nope, just bad
			  log('Bad request')
			  error(request, 400, '')
			  return nil
			else
			  request.proto = 'HTTP/1.0'
			end
		  end
		else
		  -- Got request, reading cli_headers
		  local _,_, header, value = string.find(line, '([^:]*): (.*)')
		  request.cli_headers[header] = value
		end
	  end
	end
  end
end

function check_cli_headers(request)
  -- HTTP 1.1 clients must provide Host
  if request.proto ~= 'HTTP/1.0' and not request.cli_headers['Host'] then
	return false
  end
  return true
end

function handle_request(request)
  -- What method?
  if request.method == "GET" then
	if not check_cli_headers(request) then
	  log('check_cli_headers failed')
	  error(request, 400, '')
	  return false
	end

	log('uri:'..request.uri)

	local found = false
	for k,v in pairs(getreqs) do
	  args = {string.find(request.uri, k)}
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
trace = print

function do_read(sock)
  trace('do_read')
  request = read_request(sock)
  if request then
	handle_request(request)
  end
  log('Closing connection')
  sock:close()
  del_conn(sock)
end

function run()
  listensock = Socket()
  if not listensock:listen(0, 9001) then
	log('Failed to open listen socket, exiting')
	return
  end
  
  conns[1] = listensock

  while true do
	trace('polling '..#conns..' sockets')
	local ready = Socket.poll(conns, 1000)
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
end
