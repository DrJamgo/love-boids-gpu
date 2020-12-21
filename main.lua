--
-- Copyright DrJamgo@hotmail.com 2020
--
love.filesystem.setRequirePath("?.lua;?/init.lua;lua/?.lua;lua/?/init.lua")

local STI = require 'sti/sti'
require 'blur'
require 'utils/vec'

local Game = {
  time=0,
  options={},
  count={}
}
local VELOSCALE = 200
local SENSE = 12
local RADIUS = 16
local RADIUSVELO = 100
local COUNT = 100

-- handle vscode and zerobrain debuggers
if arg[#arg] == "-debug" then
  if pcall(require, "lldebugger") then require("lldebugger").start() end
  if pcall(require, "mobdebug") then require("mobdebug").start() end
end

local gradientimage = love.graphics.newImage('assets/gradient_image.png')
local sprites = love.graphics.newImage('sprites.png')
sprites:setFilter('nearest','nearest')
local series = {}
for i=0,8 do
  table.insert(series, love.graphics.newQuad(i*16,0,16,16,sprites:getDimensions()))
end

function drawSheeps()
  table.sort (Game.swarm, function (k1, k2) return k1:getY() < k2:getY() end )

  for _,body in ipairs(Game.swarm) do
    local x,y = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local v = math.sqrt(vx*vx+vy*vy)
    local dir = math.atan2(vx, vy)
    local frame = math.floor(dir / (2*math.pi) * 8 + 1.5 )
    if frame < 1 then frame = frame + 8 end
    local sy = 1 * RADIUS / 8
    local sx = 1 * RADIUS / 8
    local d = ((_/10 + Game.time * (v/8)) % 2) > 1 and 2 or 0
    if frame ~= 8 then
      print(frame)
    end
    love.graphics.draw(sprites, series[frame], x,y,0,sx,sy,8,8+d)
  end
end

-- Clamps a number to within a certain range, with optional rounding
function math.clamp(low, n, high) return math.min(math.max(n, low), high) end

function love.load()
  love.physics.setMeter(64)
  Game.map = STI('map0.lua', { "box2d" })
  Game.world = love.physics.newWorld(0, 0, true)
  Game.map:box2d_init(Game.world)
  Game.image = love.graphics.newCanvas(love.graphics.getDimensions())

  love.graphics.setCanvas(Game.image)
  drawAllFixtures('fill')
  Game.image = blurImage(Game.image, 2)

  Game.canvas = love.graphics.newCanvas(love.graphics.getDimensions())
  Game.velos = love.graphics.newCanvas(love.graphics.getDimensions())
  local x,y = 400,300

  Game.swarm = {}
  Game.dist = {}
  for i = 1, COUNT do
    local body = love.physics.newBody(Game.world, x+i, y+i, 'dynamic')
    body:setLinearDamping(11)
    body:setMass(0.1)
    table.insert(Game.swarm, body)
    table.insert(Game.dist, 0)
    Game.one = body
  end
end

function love.update(dt)

  local x,y = love.mouse.getPosition()
  local gradientmap = Game.canvas:newImageData()
  local velocitymap = Game.velos:newImageData()
  for _,body in ipairs(Game.swarm) do
    local fx,fy = 0,0

    if love.mouse.isDown(1) 
      --and body == Game.one
      then
      local maxV = 100
      local dx, dy = x - body:getX(), y - body:getY()
      local force = 10 * body:getMass()
      fx,fy = math.max(math.min(maxV, dx * force), -maxV), math.max(math.min(maxV, dy * force), -maxV)
    end

    local x,y = math.floor(body:getX() - 0.5), math.floor(body:getY() - 0.5)

    if x > SENSE+1 and x < gradientmap:getWidth() - SENSE and y > SENSE+1 and y < gradientmap:getHeight()-SENSE then
      local r0,g0,b0,a0 = velocitymap:getPixel(x, y) -- center
      local r1,g1,b1,a1 = gradientmap:getPixel(x-SENSE, y) -- left
      local r2,g2,b2,a2 = gradientmap:getPixel(x+SENSE, y) -- right
      local r3,g3,b3,a3 = gradientmap:getPixel(x, y-SENSE) -- up
      local r4,g4,b4,a4 = gradientmap:getPixel(x, y+SENSE) -- down

      local vx,vy = (math.min(g0/r0,1) - 0.5) * VELOSCALE, (math.min((b0/r0),1) - 0.5) * VELOSCALE
      fx,fy = fx + vx*(Game.count.v or 0)/10, fy + vy*(Game.count.v or 0)/10

      local dmax = 10
      local shift = 0.2
      local dx = math.clamp(-dmax, (math.max(r2-shift,0) - math.max(r1-shift,0)) * 100, dmax)
      local dy = math.clamp(-dmax, (math.max(r4-shift,0) - math.max(r3-shift,0)) * 100, dmax)
      local force = 5 * body:getMass()
      local tangent = vec2(fx,fy)
      local ddx, ddy = math.abs(dx*dx) * -dx * force, math.abs(dy*dy) * -dy * force
      local v = vec2_proj(vec2(ddy,-ddx), tangent)
      body:applyForce(ddx,ddy)
      body:applyForce(fx,fy)
    end
  end
  Game.world:update(dt)
  
  love.graphics.setCanvas(Game.canvas)
  love.graphics.clear()
  love.graphics.draw(Game.image)
  for _,body in ipairs(Game.swarm) do
    local vx, vy = body:getLinearVelocity()
    love.graphics.setColor(1, vx/VELOSCALE+0.5, vy/VELOSCALE+0.5, 0.2)
    --love.graphics.setColorMask(true,false,false,true)
    love.graphics.draw(gradientimage, body:getX(), body:getY(), 0, RADIUS/40, nil, gradientimage:getWidth() / 2, gradientimage:getHeight() / 2)
    --love.graphics.setColorMask(false,true,true,true)
    --love.graphics.draw(gradientimage, body:getX(), body:getY(), 0, RADIUSVELO/40, nil, gradientimage:getWidth() / 2, gradientimage:getHeight() / 2)
  end

  love.graphics.setCanvas(Game.velos)
  love.graphics.clear()
  for _,body in ipairs(Game.swarm) do
    local vx, vy = body:getLinearVelocity()
    love.graphics.setColor(1, vx/VELOSCALE+0.5, vy/VELOSCALE+0.5, 0.2)
    love.graphics.draw(gradientimage, body:getX(), body:getY(), 0, RADIUSVELO/40, nil, gradientimage:getWidth() / 2, gradientimage:getHeight() / 2)
  end
  love.graphics.setColor(1,1,1,1)
  love.graphics.setColorMask()
  love.graphics.setCanvas()
  Game.time = Game.time + dt
end

function drawAllFixtures(style)
  for _, body in pairs(Game.world:getBodies()) do
    for _, fixture in pairs(body:getFixtures()) do
        local shape = fixture:getShape()
        if shape:typeOf("CircleShape") then
            local cx, cy = body:getWorldPoints(shape:getPoint())
            love.graphics.circle(style, cx, cy, shape:getRadius())
        elseif shape:typeOf("PolygonShape") then
            love.graphics.polygon(style, body:getWorldPoints(shape:getPoints()))
        else
            love.graphics.line(body:getWorldPoints(shape:getPoints()))
        end
    end
    local x,y = body:getLinearVelocity()
    --love.graphics.print(string.format("%d\n%d", x,y), body:getPosition())
  end
end

function love.draw()
  love.graphics.clear(0, 0, 0, 1, true, true)
  --drawAllFixtures('line')
  Game.map:draw()
  
  for _,body in ipairs(Game.swarm) do
    love.graphics.setColor(1,1,1,0.05)
    --love.graphics.circle("line", body:getX(), body:getY(), RADIUS)
    love.graphics.setColor(1,1,1,1)
    love.graphics.circle("line", body:getX(), body:getY(), 3)
  end
  love.graphics.setColor(1,1,1,1)
  love.graphics.print(string.format("%f",Game.time), 0,0)

  drawSheeps()

  local size = 200
  love.graphics.draw(Game.canvas, love.graphics.getWidth()-size, 0, 0, size/Game.canvas:getWidth())
  love.graphics.draw(Game.velos, love.graphics.getWidth()-size, 0, 0, size/Game.canvas:getWidth())
  love.graphics.rectangle('line', love.graphics.getWidth()-size, 0, size, size*Game.canvas:getHeight()/Game.canvas:getWidth())

  local y = 40
  for k,v in pairs(Game.count) do
    love.graphics.print(string.format("%s=%f",k,v), 0,y)
    y = y + 30
  end

  
  local diff = love.timer.getTime() - (time or love.timer.getTime())
  time = love.timer.getTime()
  local a = 1
  fps = (1-a) * (fps or 60) + a * (1/diff)
  love.graphics.printf(string.format('FPS: %.1f', fps), love.graphics.getWidth() - 100, 200, 100, 'right')
end

function love.keypressed( key, scancode, isrepeat )
  Game.count[key] = (Game.count[key] or 0) + 1
end