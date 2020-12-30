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

FragmentProgram = Class()
function FragmentProgram:init(channels, maxbodies)
  self.channels = channels
  self.data = love.image.newImageData(maxbodies, self:FragmentProgramHeight(), 'rgba32f')
  self.needupload = true
  self.size = 0
  self.capacity = maxbodies
end

function FragmentProgram:makeProgram(shadercode)
  code = shadercode:gsub('DECLARE_CHANNELS', self:getDeclareChannels())
  return love.graphics.newShader(code)
end

function FragmentProgram:FragmentProgramHeight()
  return math.ceil(#self.channels / 4)
end

-- callback: function(row, component, name)
function FragmentProgram:forEachChannel(callback)
  local comps ={'x','y','z','w'}
  for c=0,#self.channels-1 do
    callback(math.floor((c)/4), comps[(c % 4)+1], self.channels[c+1])
  end
end

function FragmentProgram:write(index, source)
  if not self.data then
    self.data = self.canvas:newImageData()
  end
  for y=0,self.data:getHeight()-1 do
    local values = {0,0,0,0}
    for k=1,4 do
      local v = self.channels[k+y*4]
      values[k] = source[v] or 0
    end
    self.data:setPixel(self.size,y,values)
  end
end

function FragmentProgram:read(index, target)
  -- TODO: Optmize
  if not self.data then
    self.data = self.canvas:newImageData()
  end
  local target = target or {}
  for y=0,self.data:getHeight()-1 do
    local values = {self.data:getPixel(index,y)}
    for k=1,4 do
      local v = self.channels[k+y*4]
      if v then
        target[v] = values[k]
      end
    end
  end
  return target
end

function FragmentProgram:getDeclareChannels()
  local code = '\n  //auto-code BEGIN\n'
  local h = self:FragmentProgramHeight()
  for i=0,h-1 do
    code = code .. string.format('  vec4 _input_row_%d = Texel(_input_tex, vec2(_input_u, %.3f));\n',i,(2*i+1)/(h*2))
  end

  self:forEachChannel(
    function(row, component, name)
      code = code .. string.format('  #define _out_%s %s\n', name, component)
      code = code .. string.format('  float _%s = _input_row_%d.%s;\n', name, row, component)
    end
  )
  code = code .. '  //auto-code END\n'
  return code
end

function FragmentProgram:updatePixels(shader)
  local source = self.canvas
  if self.needupload then
    -- uploads self.data to GPU
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
  self.data = nil
end

function FragmentProgram:drawValues(index, sx, sy)
  local text = string.format('index=%f\n',index)
  local values = self:read(index)
  for k,v in ipairs(self.channels) do
    text = text..string.format('%s=%.2f\n',v,values[v])
  end
  love.graphics.print(text,sx,sy)
end