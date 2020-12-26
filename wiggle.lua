local Wiggle  = {}

function Wiggle:add(key, table, value)
  self[key] = {table=table, value=value}
end

function Wiggle:keypressed(key)
  if self[key] then
    local t = self[key].table
    local name = self[key].value
    if type(t[name]) == 'number' then
      if love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
        t[name] = t[name] * 1.2
      else
        t[name] = t[name] * (1/1.2)
      end
    end
    if type(t[name]) == 'boolean' or not t[name] then
      t[name] = not t[name]
    end
  end
end

function Wiggle:draw(x, y, width, align)
  for k,v in pairs(self) do
    if type(v) == 'table' then
      local t = self[k].table
      local name = self[k].value
      love.graphics.printf(string.format('[%s] %s=%.1f',k,name,t[name]),x, y, width, align or 'left')
      y = y + 20
    end
  end
end

return Wiggle