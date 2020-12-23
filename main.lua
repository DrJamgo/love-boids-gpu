--
-- Copyright DrJamgo@hotmail.com 2020
--
love.filesystem.setRequirePath("?.lua;?/init.lua;lua/?.lua;lua/?/init.lua")

if arg[#arg] == "-debug" then
  if pcall(require, "lldebugger") then require("lldebugger").start() end -- << vscode debugger
  if pcall(require, "mobdebug") then require("mobdebug").start() end -- << zerobrain debugger
end

Class = require "hump.class" 
gWiggleValues = {

}

require "swarm.myswarm"
require "swarm.world"

gWorld = World(love.graphics.getDimensions())
gSwarm = MySwarm(gWorld, 2048)

gGame = {
  time = 0
}

function love.load()
  for i = 0, 200 do
    local r = love.math.random(3,10)
    local mass = math.sqrt(r)
    gSwarm
  :addBody({x=love.math.random(0,love.graphics.getWidth()),y=love.math.random(0,love.graphics.getHeight()),m=mass,r=r})
  end
end
local FPS


function love.update(dt)
  local dt = math.min(dt, 1/30)
  gGame.time = gGame.time + dt
  local count = 1
  local factor = 1
  if love.keyboard.isDown('+') then
    count = 2
    factor = 1/count
  end
  if love.keyboard.isDown('-') then
    factor = 2
  end

  for i=1,count do
    gSwarm:updateBodies(dt * factor)
    gSwarm:renderToWorld()
    gWorld:update()
  end
  local f = 0.05
  FPS = (FPS or (1/f)) * (1-f) + (1/dt) * f
end

function love.draw()
  love.graphics.push()
  love.graphics.scale(1)
  gWorld:draw()
  --gSwarm:draw()
  love.graphics.pop()

  love.graphics.printf(string.format('FPS:%.1f',FPS),love.graphics.getWidth()-200,0,200,'right')
  love.graphics.printf(string.format('Bodies:%d',gSwarm.size),love.graphics.getWidth()-200,20,200,'right')

  local y = 80
  for k,v in pairs(gWiggleValues) do
    local t = gWiggleValues[k].table
    local name = gWiggleValues[k].value
    love.graphics.printf(string.format('[%s] %s=%f',k,name,t[name]),love.graphics.getWidth()-400,y,400,'right')
    y = y + 20
  end
end

function love.keypressed(key)
  if gWiggleValues[key] then
    local t = gWiggleValues[key].table
    local name = gWiggleValues[key].value
    if love.keyboard.isDown('lshift') then
      t[name] = t[name] * 1.2
    else
      t[name] = t[name] * (1/1.2)
    end
  end
  if key == 'r' then
    gWorld = World(800,800)
    gSwarm = MySwarm(gWorld, 2048)
    love.load()
  end
end