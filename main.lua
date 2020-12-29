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

require "physics.boids"
require "physics.world"

gWorld = World(love.graphics.getDimensions())--love.graphics.getDimensions())
gSwarm = Boids(gWorld, 2048)

gGame = {
  time = 0,
  pause = false
}

local canvas = love.graphics.newCanvas(love.graphics.getDimensions())

function love.load()
  gWiggleValues:add('p', gGame, 'pause')
end
local FPS
local FRAME = 0

function love.update(dt)
  local f = 0.05
  FPS = (FPS or (1/f)) * (1-f) + (1/dt) * f
  FRAME = FRAME + 1

  local dt = math.min(dt, 1/30)
  if gGame.pause then
    dt = 0
  end
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

  local r = love.math.random(2,5)
  local mass = math.sqrt(r)
  if love.mouse.isDown(2) then
    local x,y = gWorld.transform:inverseTransformPoint(love.mouse.getPosition())
    gSwarm:addBody({x=x,y=y,m=mass,r=r})
  elseif not gGame.pause then
    if gSwarm.size < 400 then
      gSwarm:addBody({x=200+love.math.random(-1,1),y=200+love.math.random(-1,1),m=mass,r=r})
    end
  end

  for i=1,count do
    gSwarm:update(dt * factor)
    gSwarm:renderToWorld()
    gWorld:update()
  end
end

local town = love.graphics.newImage('town.png')

function love.draw()
  love.graphics.reset()
  love.graphics.push()
  love.graphics.scale(1)

  local canvas2 = love.graphics.newCanvas(canvas:getDimensions())
  love.graphics.setCanvas(canvas2)
  love.graphics.setColor(1,1,1,0.99)
  love.graphics.draw(canvas)
  gSwarm:draw()
  canvas = canvas2

  love.graphics.setCanvas()
  love.graphics.setColor(1,1,1,1)
  --love.graphics.draw(town,0,0,0,1,1)

  
  love.graphics.draw(canvas)
  love.graphics.pop()

    -- debug drawing
  love.graphics.replaceTransform(gWorld.transform)
  gWorld:draw()
  local unit = gSwarm:read(1)
  love.graphics.circle('line', unit.x, unit.y, unit.r)
  love.graphics.reset()
  gSwarm:drawValues(1, gWorld.transform:transformPoint(unit.x,unit.y))

  love.graphics.printf(string.format('FPS:%.1f',FPS),love.graphics.getWidth()-200,0,200,'right')
  love.graphics.printf(string.format('Bodies:%d',gSwarm.size),love.graphics.getWidth()-200,20,200,'right')

  gWiggleValues:draw(love.graphics.getWidth()-300,love.graphics.getHeight()-80,300)


end

function love.keypressed(key)
  gWiggleValues:keypressed(key)
  if key == 'r' then
    gWorld = World(gWorld:getDimensions())
    gSwarm = Boids(gWorld, 2048)
    love.load()
  end
end