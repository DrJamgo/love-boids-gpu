
World = Class()
local testimage = love.graphics.newImage('test3.png')


function World:init(width, height, maxspeed, maxmass)
  self.dynamic = love.graphics.newCanvas(testimage:getDimensions())
  self.target = love.graphics.newCanvas(testimage:getDimensions())
  self.transform = love.math.newTransform(0,0,0,1)
end


function World:update()
  self.dynamic = nil
  self.dynamic = self.target
  self.target = love.graphics.newCanvas(self.target:getDimensions())
  
  self.target:renderTo(
    function()
      love.graphics.clear(0,0,0,0)
      local w,h = self:getDimensions()
      local d = 10
      love.graphics.setBlendMode('replace','premultiplied')
      love.graphics.setColor(0,0.5,0.5,1)
      love.graphics.draw(testimage)
      love.graphics.rectangle('fill',0,0,d,h)
      love.graphics.rectangle('fill',w-d,0,d,h)
      love.graphics.rectangle('fill',0,0,w,d)
      love.graphics.rectangle('fill',0,h-d,w,d)
    end
  )
  love.graphics.reset()
end

function World:getDimensions()
  return self.dynamic:getDimensions()
end

function World:draw()
  love.graphics.rectangle('line',0,0,love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.draw(self.dynamic)

  local data = self.dynamic:newImageData()
  local cx, cy = love.mouse.getPosition()

  --love.graphics.print(string.format("cursor %d,%d: %.2f %.2f %.2f %.2f", cx, cy, data:getPixel(cx, cy)), 0, love.graphics.getHeight()-80)
end