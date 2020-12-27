Uniforms = Class()

function Uniforms:setUniform(uniform, value)
  self.uniforms[uniform] = value
end

function Uniforms:sendUniforms()
  local shader = love.graphics.getShader()
  for k,v in pairs(self.uniforms) do
    if shader:hasUniform(k) then
      shader:send(k,v)
    end
  end
end

PixelSpec = Class()

function PixelSpec:init(identifiers)
  self.spec = identifiers
end

function PixelSpec:pixelSpecHeight()
  return math.ceil(#self.spec / 4)
end

function PixelSpec:forEachChannel(func)

end

function PixelSpec:write(index, source)
  for y=0,self.data:getHeight()-1 do
    local values = {0,0,0,0}
    for k=1,4 do
      local v = self.spec[k+y*4]
      values[k] = source[v] or 0
    end
    self.data:setPixel(self.size,y,values)
  end
end

function PixelSpec:read(index, target)
  -- TODO: Optmize
  local target = target or {}
  for k,v in ipairs(self.spec) do
    local values = {self.data:getPixel(index,(k-1)/4)}
    target[v] = values[(k-1)%4+1]
  end
  return target
end

function PixelSpec:pixelSpecCode()
  local code = ''
  local h = self:pixelSpecHeight()
  for i=0,h-1 do
    code = code .. string.format('_pixel_%d = Texel(tex, vec2(_index, %.3f));\n',i,(2*i+1)/(h*2))
  end

  for k,v in pairs(self.spec) do

  end
end