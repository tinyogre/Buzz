Buzz
====

version 0.02
------------
Serves pages according to HTTP spec.

Licensing
---------
Copyright (c) 2011 Joe Rumsey

Released under the MIT License, see LICENSE for details

About
-----

A mini lua web app framework.  Lua is portugese for moon.  Buzz Aldrin
was the second man on the moon.  This is the second lua web server.
(Alright, you got me, there are several more besides just Xavante, I
just like the name Buzz.  Plus Google's not using it any more.)

Goals
 * Learn me some Lua
 * Usefulness - I am toying with writing a blog app using this and making it my real blog
 * Simplicity - Writing simple web apps should require only simple code
 * Speed - Should scale to reasonable loads
 * Modular and agnostic - if you want to replace some piece, the framework shouldn't make it hard

At this point, I'm just messing around for my own education and
amusement.  As of this writing, you should check out the Kepler
project at http://www.keplerproject.org/ for more information on
"real" (or at least more mature) lua web app frameworks and other
useful stuff.

Also, Tir (http://tir.mongrel2.org/), which I hadn't seen when I
started working on this, is close in spirit to what I'm trying to do.

Requirements
------------

Luajit.  I have only targeted and tested with 2.0 from version control

Mac OS X or Linux - socket.lua is implemented with straight calls via
ffi (which is why luajit is required) to functions like bind,
setsockopt, poll, etc. which rely on system dependent headers.  Mostly
these are the same on OS X and Linux, but there are already a few
things set conditionally in there.  Longer term, the socket module
should probably be replaced by a C module, either a new one, or luasocket.

Installation
------------
	Nope.  Just run testapp.py with luajit
