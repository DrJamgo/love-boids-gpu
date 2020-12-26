
World = Class()
function World:init(width, height)
  self.dynamic = love.graphics.newCanvas(width, height)
  self.target = love.graphics.newCanvas(width, height)
end

local testimage = love.graphics.newImage('test.png')

function World:update()
  self.dynamic = nil
  self.dynamic = self.target
  self.target = love.graphics.newCanvas(self.target:getDimensions())
  
  self.target:renderTo(
    function()
      love.graphics.clear(0,0,0,0)
      love.graphics.draw(testimage)
    end
  )
end

function World:draw()
  love.graphics.draw(self.dynamic)
end