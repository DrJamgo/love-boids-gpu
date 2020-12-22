
World = Class()
function World:init(width, height)
  self.dynamic = love.graphics.newCanvas(width, height)
  self.target = love.graphics.newCanvas(width, height)
end

function World:update()
  self.dynamic = nil
  self.dynamic = self.target
  self.target = love.graphics.newCanvas(self.target:getDimensions())
end

function World:draw()
  love.graphics.draw(self.dynamic)
end