#!/Users/ogre/src/luajit-2.0/src/luajit
require('buzz')

function index(request)
  print('index request')
  buzz.response(request, '<html><h1>Hello, World!</h1></html>\n')
end

function testarg(request, args)
  print('arg request (arg=\''..args[1]..'\')')
  buzz.response(request, '<html><h1>arg='..args[1]..'</h1></html>\n')
end

buzz.get('/', index)
buzz.get('/testarg/(.*)$', testarg)

buzz.run()
