local vec = require "hump.vector-light"

DynamicBodies = Class()
DynamicBodies.spec = {'x','y','r','m','vx','vy'}

function DynamicBodies:init(world, maxbodies)
  local texHeight = math.ceil(#self.spec / 4)
  self.world = world
  self.data = love.image.newImageData(maxbodies, texHeight, 'rgba32f')
  self.size = 0
  self.capacity = maxbodies
  self.updateshader = love.graphics.newShader(self.shadercommons .. self.updateshader)
  self.worldshader = love.graphics.newShader(self.shadercommons .. self.worldshader)
end

function DynamicBodies:write(index, source)
  local c = 1
  for y=0,self.data:getHeight()-1 do
    local values = {0,0,0,0}
    for k=1,4 do
      local v = self.spec[k+y*4]
      values[k] = source[v] or 0
    end
    self.data:setPixel(self.size,y,values)
  end
end

function DynamicBodies:read(index, target)
  -- TODO: Optmize
  local target = target or {}
  for k,v in ipairs(self.spec) do
    local values = {self.data:getPixel(index,(k-1)/4)}
    target[v] = values[(k-1)%4+1]
  end
  return target
end

function DynamicBodies:addBody(body)
  self.size = self.size + 1
  self:write(self.size, body)
  self.needupload = true
end


DynamicBodies.shadercommons = [[
  #pragma language glsl3
  
  #define M_PI 3.1415926535897932384626433832795
  const float MASS_FACTOR = 20;
]]

-- controlls behaviour of body
DynamicBodies.updateshader = [[

uniform Image dynamicTex;
uniform vec2  dynamicTexSize;
uniform float dt;

const float numSteps = 32.0;
const float maxSpeed = 100;

#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position )
{
  return transform_projection * vertex_position;
}
#endif
 
#ifdef PIXEL
vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
  vec4 body0 = Texel(tex, vec2(texture_coords.s, 0.25));
  vec4 body1 = Texel(tex, vec2(texture_coords.s, 0.75));

  float radius = body0.z+1;

  vec4 result;

  // x,y,r,m
  if (texture_coords.t < 0.5) {
    result = body0;
    result.xy += body1.xy * dt;
    result.xy = clamp(result.xy, vec2(radius,radius), dynamicTexSize - vec2(radius,radius));
  }
  // vx,vy
  else {
    result = body1;
    vec2 pos = body0.xy;
    float mass = body0.w;

    // gravity
    result.xy += vec2(0,800)*dt;
    //const speed
    //result.xy = vec2(0,800);

    // friction
    result.xy -= result.xy * clamp(abs(result.xy) * dt * 0.5 , vec2(0,0), vec2(1,1));

    vec2 vector = vec2(0.0,0.0);
    float summed = 0;
    for(float angle = -M_PI; angle < M_PI; angle += M_PI*2/numSteps) {
      vec2 diff = vec2(cos(angle),sin(angle));
      float texval = Texel(dynamicTex, (pos+diff*radius) / dynamicTexSize).r * 10;
      vec2 delta = texval * diff / numSteps * (MASS_FACTOR);
      summed += length(delta) / numSteps;
      vector += delta;
    }
    vec2 targetVelo = vector.xy * 1000;
    vec2 diff = result.xy - targetVelo;
    result.xy += diff * summed *dt;
 }
  
  return result;
}
#endif
]]

function DynamicBodies:updateBodies(dt)
  local source = self.canvas
  if self.needupload then
    source = love.graphics.newImage(self.data)
    self.needupload = nil
  end
  local destination = love.graphics.newCanvas(source:getWidth(), source:getHeight(), {format=source:getFormat()})  
  destination:renderTo(
    function()
      love.graphics.setBlendMode('replace','premultiplied')
      love.graphics.setShader(self.updateshader)
      if self.updateshader:hasUniform('dt') then self.updateshader:send('dt', dt) end
      self.updateshader:send('dynamicTex', self.world.dynamic)
      self.updateshader:send('dynamicTexSize', {self.world.dynamic:getDimensions()})
      love.graphics.draw(source)
      love.graphics.reset()
    end
  )
  destination:setFilter('nearest','nearest')
  self.canvas = destination
  self.data = self.canvas:newImageData()
end

-- A simple small triangle with the default position, texture coordinate, and color vertex attributes.
local vertices = {
  { 0,  0},
	{-1, -1},
	{ 1, -1},
  { 1,  1},
  {-1,  1},
  {-1, -1},
}
 
local mesh = love.graphics.newMesh(vertices, "fan", "static")

-- updates dynamic image layers
DynamicBodies.worldshader = [[

uniform Image bodiesTex;
uniform vec2  bodiesTexSize;

varying float v_mass;
varying float v_radius;
varying vec2  v_vertex;

#ifdef VERTEX

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
  float bodiesTexU = float(love_InstanceID) / bodiesTexSize.x;
  vec4 body0 = Texel(bodiesTex, vec2(bodiesTexU, 0));
  vec2 pos = body0.xy;
  v_radius = body0.z;
  v_mass = body0.w;
  v_vertex = vertex_position.xy;
  vertex_position.xy += vertex_position.xy * v_radius + pos;
  return transform_projection * vertex_position;
}
#endif
 
#ifdef PIXEL
vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(tex, texture_coords);
    float distToCenter = length(v_vertex.xy);
    texcolor.rgb *= (1.0-pow(distToCenter,5)) * v_mass / MASS_FACTOR;
    return texcolor * color;
}
#endif
]]

function DynamicBodies:renderToWorld(world)
  love.graphics.setShader(self.worldshader)
  self.worldshader:send('bodiesTex', self.canvas)
  self.worldshader:send('bodiesTexSize', {self.data:getDimensions()})
  love.graphics.setBlendMode('lighten','premultiplied')
  self.world.target:renderTo(function()
    love.graphics.drawInstanced(mesh, self.size)
  end)
  love.graphics.reset()
end

-- FOR DEBUG ONLY --

function DynamicBodies:drawValues(index, sx, sy)
  local text = string.format('index=%f\n',index)
  for k,v in ipairs(self.spec) do
    local values = {self.data:getPixel(index,(k-1)/4)}
    text = text..string.format('%s=%.2f\n',v,values[(k-1)%4+1])
  end
  love.graphics.print(text,sx,sy)
end

function DynamicBodies:draw()
  local canvas = self.canvas
  love.graphics.push()
  love.graphics.translate(0,0)
  local scale = 40
  local w,h = canvas:getWidth(), canvas:getHeight()
  love.graphics.rectangle('line',0,0,w*scale,h*scale)
  love.graphics.push()
  
  love.graphics.scale(scale,scale)
  local x,y = love.graphics.inverseTransformPoint(love.mouse.getPosition())

  love.graphics.setShader(shader)
  love.graphics.setBlendMode('replace','premultiplied')
  --love.graphics.draw(canvas,0,0)
  love.graphics.reset()
  
  love.graphics.pop()

  if x < w and x > 0 and y < h and y > 0 then
    x = math.floor(x)
    love.graphics.rectangle('line',x*scale,0,scale,scale*canvas:getHeight())
    self:drawValues(x,x*scale,canvas:getHeight()*scale)
  end
  love.graphics.pop()

  local body = {}
  for i=1,self.size do
    --self:read(i, body)
    --love.graphics.circle('line', body.x, body.y, body.r)
  end
end