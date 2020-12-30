
World = Class()
local testimage = love.graphics.newImage('test3.png')

function World:init(width, height)
  self.dynamic = love.graphics.newCanvas(testimage:getDimensions())
  self.target = love.graphics.newCanvas(testimage:getDimensions())
end

function World:addBorder(target, d)
  target:renderTo(
    function()
      love.graphics.clear(0,0,0,0)
      local w,h = self:getDimensions()
      local d = 10
      love.graphics.setBlendMode('replace','premultiplied')
      love.graphics.setColor(0,0.5,0.5,1)
      love.graphics.draw(testimage)

      -- Add a Frame around the world
      love.graphics.rectangle('fill',0,0,d,h)
      love.graphics.rectangle('fill',w-d,0,d,h)
      love.graphics.rectangle('fill',0,0,w,d)
      love.graphics.rectangle('fill',0,h-d,w,d)
    end
  )
  love.graphics.reset()
end

function World:update()
  self.dynamic = nil
  self.dynamic = self.target
  self.target = love.graphics.newCanvas(self.target:getDimensions())
  
  self:addBorder(self.target, 10)
end

function World:getDimensions()
  return self.dynamic:getDimensions()
end

function World:draw()
  love.graphics.rectangle('line',0,0,love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.draw(self.dynamic)
end