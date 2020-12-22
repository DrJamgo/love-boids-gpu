--
-- Copyright DrJamgo@hotmail.com 2020
--
love.filesystem.setRequirePath("?.lua;?/init.lua;lua/?.lua;lua/?/init.lua")

if arg[#arg] == "-debug" then
  if pcall(require, "lldebugger") then require("lldebugger").start() end -- << vscode debugger
  if pcall(require, "mobdebug") then require("mobdebug").start() end -- << zerobrain debugger
end

Class = require "hump.class" 
require "swarm.myswarm"
require "swarm.world"

gWorld = World(800,800)
gSwarm = MySwarm(gWorld, 2048)

function love.load()
  for i = 0, 400 do
    local r = love.math.random(10,20)
    local mass = math.sqrt(r)
    gSwarm
  :addBody({x=love.math.random(0,800),y=love.math.random(0,800),m=mass,r=r})
  end
end
local FPS
function love.update(dt)
  gSwarm:updateBodies(dt)
  gSwarm:renderToWorld()
  
  gWorld:update()
  local f = 0.05
  FPS = (FPS or (1/f)) * (1-f) + (1/dt) * f
end

function love.draw()
  gWorld:draw()
  gSwarm:draw()
  love.graphics.printf(string.format('FPS:%.1f',FPS),love.graphics.getWidth()-200,0,200,'right')
end