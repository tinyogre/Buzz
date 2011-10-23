#!/Users/ogre/src/luajit-2.0/src/luajit
module(..., package.seeall)

local Socket = require('socket')
require('slice')

function log(s)
  print(s)
end

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

function response(request, resp)
  request.socket:write(resp)
end

function run()
  listensock = Socket()
  listensock:listen(0, 9001)

  while true do
	newsock = listensock:accept()
	if newsock.fd < 0 then
	  Socket.perror('accept')
	  break
	end

	line = newsock:readline(10000)
	if line then
	  -- What method?
	  if string.find(line, "GET ") then

		-- Find the actual URI requested
		uri = trim(string.sub(line, 5, nil))
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
	newsock:close()
  end
end
