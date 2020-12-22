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
  for i = 0, 500 do
    local r = love.math.random(5,20)
    local mass = math.sqrt(r)
    gSwarm
  :addBody({x=love.math.random(0,800),y=love.math.random(0,800),m=mass,r=r})
  end
end
local FPS
function love.update(dt)
  local count = 1
  if love.keyboard.isDown('s') then
    count = 10
  end

  for i=1,count do
    gSwarm:updateBodies(dt/count)
    gSwarm:renderToWorld()
    gWorld:update()
  end
  local f = 0.05
  FPS = (FPS or (1/f)) * (1-f) + (1/dt) * f
end

function love.draw()
  gWorld:draw()
  gSwarm:draw()
  love.graphics.printf(string.format('FPS:%.1f',FPS),love.graphics.getWidth()-200,0,200,'right')
  love.graphics.printf(string.format('Bodies:%d',gSwarm.size),love.graphics.getWidth()-200,20,200,'right')
end