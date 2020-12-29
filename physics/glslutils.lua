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

function PixelSpec:init(identifiers, maxbodies)
  self.spec = identifiers
  self.data = love.image.newImageData(maxbodies, self:pixelSpecHeight(), 'rgba32f')
  self.needupload = true
  self.size = 0
  self.capacity = maxbodies
end

function PixelSpec:pixelSpecHeight()
  return math.ceil(#self.spec / 4)
end

-- callback: function(row, component, name)
function PixelSpec:forEachChannel(callback)
  local comps ={'x','y','z','w'}
  for c=0,#self.spec-1 do
    callback(math.floor((c)/4), comps[(c % 4)+1], self.spec[c+1])
  end
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
  local code = '\n'
  local h = self:pixelSpecHeight()
  for i=0,h-1 do
    code = code .. string.format('  vec4 _input_row_%d = Texel(_input_tex, vec2(_input_u, %.3f));\n',i,(2*i+1)/(h*2))
  end

  self:forEachChannel(
    function(row, component, name)
      code = code .. string.format('  #define _out_%s %s\n', name, component)
      code = code .. string.format('  float _%s = _input_row_%d.%s;\n', name, row, component)
    end
  )

  return code
end

function PixelSpec:updatePixels(shader)
  local source = self.canvas
  if self.needupload then
    source = love.graphics.newImage(self.data)
    self.needupload = nil
  end
  local destination = love.graphics.newCanvas(source:getWidth(), source:getHeight(), {format=source:getFormat()})  
  destination:renderTo(
    function()
      love.graphics.setBlendMode('replace','premultiplied')
      love.graphics.setShader(shader)
      self:sendUniforms()
      love.graphics.setScissor(0,0,self.size+1,source:getHeight())
      love.graphics.draw(source)
      love.graphics.reset()
    end
  )
  destination:setFilter('nearest','nearest')
  self.canvas = destination
  self.data = self.canvas:newImageData()
end

function PixelSpec:drawValues(index, sx, sy)
  local text = string.format('index=%f\n',index)
  for k,v in ipairs(self.spec) do
    local values = {self.data:getPixel(index,(k-1)/4)}
    text = text..string.format('%s=%.2f\n',v,values[(k-1)%4+1])
  end
  love.graphics.print(text,sx,sy)
end