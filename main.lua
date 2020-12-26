--
-- Copyright DrJamgo@hotmail.com 2020
--
love.filesystem.setRequirePath("?.lua;?/init.lua;lua/?.lua;lua/?/init.lua")

if arg[#arg] == "-debug" then
  if pcall(require, "lldebugger") then require("lldebugger").start() end -- << vscode debugger
  if pcall(require, "mobdebug") then require("mobdebug").start() end -- << zerobrain debugger
end

Class = require "hump.class" 
gWiggleValues = require 'wiggle'

require "swarm.myswarm"
require "swarm.world"

gWorld = World(love.graphics.getDimensions())
gSwarm = MySwarm(gWorld, 2048)

gGame = {
  time = 0
}

local canvas = love.graphics.newCanvas(love.graphics.getDimensions())

function love.load()
  for i = 0, 400 do
    local r = love.math.random(2,5)
    local mass = math.sqrt(r)
    gSwarm:addBody({x=love.math.random(0,love.graphics.getWidth()),y=love.math.random(0,love.graphics.getHeight()),m=mass,r=r})
  end
end
local FPS
local FRAME = 0

function love.update(dt)
  local dt = math.min(dt, 1/30)
  gGame.time = gGame.time + dt
  local count = 1
  local factor = 1
  if love.keyboard.isDown('+') then
    count = 2
    factor = 1/count
  end
  if love.mouse.isDown(1) then
    factor = 2
    count = (FRAME % 2 == 0) and 1 or 0
  end

  for i=1,count do
    gSwarm:updateBodies(dt * factor)
    gSwarm:renderToWorld()
    gWorld:update()
  end
  local f = 0.05
  FPS = (FPS or (1/f)) * (1-f) + (1/dt) * f
  FRAME = FRAME + 1
end

local town = love.graphics.newImage('town.png')

function love.draw()
  love.graphics.reset()
  love.graphics.push()
  love.graphics.scale(1)
  --gWorld:draw()
  --gSwarm:draw()

  --love.graphics.setCanvas(canvas)
  --love.graphics.setColor(0,4/255,92/255,0.1)
  --love.graphics.rectangle('fill',0,0,canvas:getDimensions())

  --love.graphics.setColor(20/255,16/255,16/255,1)
  --love.graphics.draw(gWorld.dynamic)
  
  --love.graphics.setCanvas()
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(town,0,0,0,1,1)
  gSwarm:draw()
  love.graphics.draw(canvas)

  love.graphics.pop()

  love.graphics.printf(string.format('FPS:%.1f',FPS),love.graphics.getWidth()-200,0,200,'right')
  love.graphics.printf(string.format('Bodies:%d',gSwarm.size),love.graphics.getWidth()-200,20,200,'right')

  gWiggleValues:draw(love.graphics.getWidth()-300,80,300)
end

function love.keypressed(key)
  gWiggleValues:keypressed(key)
  if key == 'r' then
    gWorld = World(800,800)
    gSwarm = MySwarm(gWorld, 2048)
    love.load()
  end
end