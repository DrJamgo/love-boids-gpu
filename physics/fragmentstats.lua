

FragmentStats = Class({__includes={Uniforms}})
function FragmentStats:init(fragmentprogram)
  self.channels = channels
  self.program = love.graphics.newShader(self.program)
  self.functions = {'min','max','sum','avg'}
  local tex = fragmentprogram.canvas
  self.canvas = love.graphics.newCanvas(#self.functions, tex:getHeight(), {format=tex:getFormat()})
  self.fragmentprogram = fragmentprogram
  self.canvas:renderTo(
    function()
      love.graphics.clear(1,1,1,1)
    end
  )
  self.stats = {}
end

FragmentStats.program = [[

#ifdef PIXEL

#define fragmentTex tex
uniform vec2 fragmentTexSize;
uniform int count;

#define _col (screen_coords.x - 0.5)
vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
  vec4 result = vec4(0,0,0,0);
  if(_col == 0) {
    result = Texel(fragmentTex, vec2(0, texture_coords.y));
    for(int i = 1; i < count; i++) {
      vec2 uv = vec2(float(i)/fragmentTexSize.x, texture_coords.y);
      result = min(result, Texel(fragmentTex, uv));
    }
  }
  else  if(_col == 1) {
    result = Texel(fragmentTex, vec2(0, texture_coords.y));
    for(int i = 1; i < count; i++) {
      vec2 uv = vec2(float(i)/fragmentTexSize.x, texture_coords.y);
      result = max(result, Texel(fragmentTex, uv));
    }
  }
  else if(_col == 2) {
    for(int i = 0; i < count; i++) {
      vec2 uv = vec2(float(i)/fragmentTexSize.x, texture_coords.y);
      result += Texel(fragmentTex, uv);
    }
  }
  else if(_col == 3) {
    for(int i = 0; i < count; i++) {
      vec2 uv = vec2(float(i)/fragmentTexSize.x, texture_coords.y);
      result += Texel(fragmentTex, uv) / float(count);
    }
  }
  return result;
}
#endif
]]

function FragmentStats:update(fragmentTex, count)
  self:setUniform('fragmentTexSize', {fragmentTex:getDimensions()})
  self:setUniform('count', count)
    self.canvas:renderTo(
    function()
      love.graphics.setBlendMode('replace','premultiplied')
      love.graphics.setShader(self.program)
      self:sendUniforms()
      love.graphics.draw(fragmentTex)
      love.graphics.reset()
    end
  )
  -- !! sync point
  local data = self.canvas:newImageData()
  for f,func in ipairs(self.functions) do
    local rows = {}
    for i=1,self.canvas:getHeight() do
      rows[i] = {data:getPixel(f-1,i-1)}
    end

    self.fragmentprogram:forEachChannel(
      function(row, component, name)
        if not self.stats[name] then
          self.stats[name] = {}
        end
        self.stats[name][func] = rows[row+1][1]
        table.remove(rows[row+1],1)
      end
    )
  end
end