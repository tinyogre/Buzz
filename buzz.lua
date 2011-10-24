#!/Users/ogre/src/luajit-2.0/src/luajit
module(..., package.seeall)

local Socket = require('socket')
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
	['Server'] = 'Buzz'
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
  req = {}
  while true do
	line = newsock:readline(10000)
	if line then
	  if #line == 0 then
		return req
	  else
		table.insert(req, line)
	  end
	end
  end
end

function get_headers(request, httpreq, proto)
  request.headers = {}
  for i=2, #httpreq do
	_,_, key, value = string.find(httpreq[i], '([^:]*): (.*)')
	print(key,value)
	request.headers[key] = value
  end
  -- HTTP 1.1 clients must provide Host
  if not request.headers['Host'] then
	return false
  end
  return true
end

function handle_request(httpreq)
  line = httpreq[1]
  -- What method?
  request = {}
  if string.find(line, "GET ") then
	-- Find the actual URI requested
	reqtext = string.sub(line, 5, nil)
	request.uri = string.gsub(reqtext, ' .*', '')
	request.proto = string.gsub(reqtext, '.* ', '')
	request.method = "GET"
	request.socket = newsock

	if request.proto and #request.proto > 0 then
	  if string.sub(request.proto, 1, 5) ~= 'HTTP/' then
		error(request, 400, '')
		return false
	  end
	  if not get_headers(request, httpreq, request.proto) then
		error(request, 400, '')
		return false
	  end
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

function run()
  listensock = Socket()
  listensock:listen(0, 9001)

  while true do
	newsock = listensock:accept()
	if newsock.fd < 0 then
	  perror('accept')
	  break
	end

	httpreq = read_request(newsock)
	if httpreq and httpreq[1] then
	  print(#httpreq)
	  handle_request(httpreq)
	end
	log('Closing connection')
	newsock:close()
  end
end
