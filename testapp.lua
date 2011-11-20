#!/Users/ogre/src/luajit-2.0/src/luajit
require('buzz')

-- Create and register a handler for /
function index(request)
  print('index request')
  buzz.response(request, '<html><h1>Hello, World!</h1></html>\n')
end
buzz.get('^/$', index)

-- Create a handler that takes one argument
function testarg(request, args)
  print('arg request (arg=\''..args[1]..'\')')
  buzz.response(request, '<html><h1>arg='..args[1]..'</h1></html>\n')
end
buzz.get('^/testarg/([^/]*)/?$', testarg)

-- Create a handler for two arguments, define the handler inline
buzz.get('^/test2args/([^/]*)/([^/]*)/?$', 
		 function(request, args)
		   print('test2args (arg1=\''..args[1]..'\', arg2=\''..args[2]..'\')')
		   buzz.response(request, '<html><h1>arg1=\''..args[1]..'\', arg2=\''..args[2]..'\'</h1></html>\n')
		 end)

function static_file(request, args)
  print("Static: ".. args[1])
  -- Probably not a sufficient security check.  Don't allow any path
  -- that contains a ./, to at least avoid, say,
  -- '../../../../etc/passwd' type things.
  -- TODO: find a library written by someone smart to do this
  -- TODO2: Complain to someone about chroot requiring root privileges!
  -- TODO3: luajit has problems parsing '\./' as a pattern, but [.]/ works.  lua 5.1 likes either just fine
  if string.find(args[1], '[.]/') then
	buzz.error(request, 404, 'Invalid path')
	return
  end

  local file = io.open('static/'..args[1])
  buzz.response(request, file:read('*a'))
end
buzz.get('^/static/(.*)$', static_file)

function post(request, args)
  print('post data: '..request.data)
end
buzz.post('^/post/(.*)$', post)

buzz.run()
