#!/Users/ogre/src/luajit-2.0/src/luajit
require('server')

function index(request)
  print('index request')
  server.response(request, '<html><h1>Hello, World!</h1></html>\n')
end

function testarg(request, args)
  print('arg request (arg=\''..args[1]..'\')')
  server.response(request, '<html><h1>arg='..args[1]..'</h1></html>\n')
end

server.get('/', index)
server.get('/testarg/(.*)$', testarg)

server.run()
