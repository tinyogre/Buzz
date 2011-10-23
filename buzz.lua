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

function error(request, code, resp)
  add_headers(request)

end
  
function response(request, resp)
  add_headers(request)

  request.socket:write('HTTP/1.1 200 OK\r\n') -- Call error() for anything other than 200
  for k,v in pairs(request.headers) do
	request.socket:write(k..': '..v..'\r\n')
  end
  
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
	  line = httpreq[1]
	  -- What method?
	  if string.find(line, "GET ") then

		-- Find the actual URI requested
		uri = string.gsub(trim(string.sub(line, 5, nil)), ' .*', '')
		log('uri:'..uri)
		for k,v in pairs(getreqs) do
		  args = {string.find(uri, k)}
		  if #args > 0 then
			-- Found a matching handler, build a request object and call it
			request = {
			  method="GET",
			  uri=uri,
			  socket=newsock
			}
			v(request, table_slice(args, 3))
			break
		  end
		end
	  end
	end
	log('Closing connection')
	newsock:close()
  end
end
