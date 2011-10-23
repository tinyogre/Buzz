#!/Users/ogre/src/luajit-2.0/src/luajit
require('server')

function index(request)
  print('index request')
end

function testarg(request, args)
  print('arg request (arg=\''..args[1]..'\')')
end

server.get('/', index)
server.get('/testarg/(.*)\n', testarg)

server.run()
