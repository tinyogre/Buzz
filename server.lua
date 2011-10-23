#!/Users/ogre/src/luajit-2.0/src/luajit
module(..., package.seeall)

local socket = require('socket')
require('slice')

function log(s)
  print(s)
end

--
-- Add a get handler
--
-- Examples:
-- Simple URL
-- server.get('/', main_handler)
-- 
-- A handler that takes an argument
-- server.get('/list/(.*)', list_handler)
--

getreqs = {}
function get(pattern, func)
  di = debug.getinfo(func, 'S')
  log('adding get: '..pattern..'=>'..di.short_src..':'..di.linedefined)
  getreqs[pattern] = func
end

function trim(s) 
  return s:match'^%s*(.*%S)' or '' 
end

function response(request, resp)
  socket.write(request.socket, resp)
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
		uri = trim(string.sub(req, 5, nil))
		for k,v in pairs(getreqs) do
		  args = {string.find(uri, k)}
		  if #args > 0 then
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
	socket.close(newsock)
  end
end
