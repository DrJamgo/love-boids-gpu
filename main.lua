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

gWorld = World(love.graphics.getDimensions())
gBoids = Boids(gWorld, 2048)
gBalls = Dynamic(gWorld, 2048)
gGame = {
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

  local r = love.math.random(2,5)
  local mass = math.sqrt(r)
  if love.mouse.isDown(2) then
    for i=1,10 do
    local x,y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
      gBoids:add({x=x+love.math.random(-1,1),y=y+love.math.random(-1,1),m=mass,r=r,fraction=1,hp=1})
    end
  elseif love.mouse.isDown(1) then
    for i=1,10 do
    local x,y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
      gBalls:add({x=x+love.math.random(-1,1),y=y+love.math.random(-1,1),m=mass,r=r,fraction=1,hp=1})
    end
  end

  gBoids:update(dt)
  gBoids:renderToWorld()

  gBalls:update(dt)
  gBalls:renderToWorld()
  gWorld:update()
end

function love.draw()
  love.graphics.reset()
  love.graphics.push()

  -- This is just for fancy drawing
  local canvas2 = love.graphics.newCanvas(canvas:getDimensions())
  love.graphics.setCanvas(canvas2)
  love.graphics.setColor(1,1,1,0.99) -- <- redraw old canvas with less alpha, makes it fade away over time.
  love.graphics.draw(canvas)
  gBoids:draw()
  gBalls:draw()
  canvas = canvas2

  love.graphics.setCanvas()
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(canvas)
  love.graphics.pop()

  -- debug drawing
  gWorld:draw()
  --gBoids:drawDebug()

  love.graphics.print({{1,0,0,1},'Rightclick',{1,1,1,1},' to add Boids'},10,25)
  love.graphics.printf(string.format('Boids: %d / %d',gBoids.size, gBoids.capacity),10,40,200,'left')

  love.graphics.print({{1,0,0,1},'Leftclick',{1,1,1,1},' to add Balls'},10,65)
  love.graphics.printf(string.format('Balls: %d / %d',gBalls.size, gBalls.capacity),10,80,200,'left')

  love.graphics.printf(string.format('FPS: %.1f',FPS),10,120,200,'left',0,1.5)
  gWiggleValues:draw(10,love.graphics.getHeight()-100,300)
end

function love.keypressed(key)
  gWiggleValues:keypressed(key)
end