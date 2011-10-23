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

buzz.run()
