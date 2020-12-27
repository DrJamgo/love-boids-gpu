
require 'physics.glslutils'

Dynamic = Class({__includes={Uniforms, PixelSpec}})
Dynamic.spec = {
  'x','y','vx','vy',
  'r','m'}

Dynamic.uniforms = {
  densityOrder = 2,
  velocityFactor = 2500,
  posFactor = 100,
  textureFactor = 10,
  target = {0,0},
  limitVelocity = 100,
}

function Dynamic:init(world, maxbodies)
  PixelSpec.init(self, self.spec)

  local texHeight = self:pixelSpecHeight()
  self.world = world
  self.data = love.image.newImageData(maxbodies, texHeight, 'rgba32f')
  self.size = 0
  self.capacity = maxbodies
  self.updateshader = love.graphics.newShader(self.shadercommons .. self.updateshader)
  self.bodyToWorldShader = love.graphics.newShader(self.shadercommons .. self.bodyToWorldShader)
end

function Dynamic:addBody(body)
  self.size = self.size + 1
  self:write(self.size, body)
  self.needupload = true
end

Dynamic.MASS_FACTOR = 255 / math.pow(10,2)
Dynamic.SPEED_FACTOR = Dynamic.uniforms.limitVelocity * 2

Dynamic.shadercommons = [[
  #pragma language glsl3
  
  #define M_PI 3.1415926535897932384626433832795
  const float MASS_FACTOR = ]]..Dynamic.MASS_FACTOR..[[;
  const float SPEED_FACTOR = ]]..Dynamic.SPEED_FACTOR..[[;
]]

-- controlls behaviour of body
Dynamic.updateshader = [[

uniform Image dynamicTex;
uniform vec2  dynamicTexSize;
uniform float dt;
uniform float velocityFactor;
uniform float posFactor;
uniform float textureFactor;
uniform float limitVelocity ;

uniform vec2 target;

const float numSteps = 32.0;


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
  vec2 pos = body0.xy;
  vec2 velo = body0.zw;
  float radius = body1.x+2;
  float mass = body1.y;

  vec4 result;

  // x,y,r,m
  if (texture_coords.t < 0.5) {
    pos += velo * dt;

    vec2 targetDiff = target - pos;
    targetDiff *= 1000 / length(targetDiff);
    float f = dt;
    velo = velo * (1-dt) + targetDiff * dt;

    vec2 Btor = vec2(0.0,0.0);
    float summed = 0;
    for(float angle = -M_PI; angle < M_PI; angle += M_PI*2/numSteps) {
      vec2 diff = vec2(cos(angle),sin(angle));
      float texval = Texel(dynamicTex, (pos+diff*radius) / dynamicTexSize).r * textureFactor;
      vec2 delta = texval * diff / numSteps * (MASS_FACTOR);
      summed += length(delta) / numSteps;
      Btor += delta;
    }
    vec2 targetVelo = Btor.xy * velocityFactor;
    vec2 diff = velo - targetVelo;
    velo += diff * summed * dt;
    pos += diff * summed * dt * (posFactor / velocityFactor);

    pos = clamp(pos, vec2(radius,radius), dynamicTexSize - vec2(radius,radius));

    float absvelo = length(velo);
    if(absvelo > limitVelocity) {
      velo *= limitVelocity / absvelo;
    }

    result.xy = pos;//floor(pos + vec2(0.5,0.5));
    result.zw = velo;
  }
  // vx,vy
  else {
    result = body1;
 }
  
  return result;
}
#endif
]]

function Dynamic:updateBodies(dt)
  self:setUniform('target', {love.graphics.inverseTransformPoint(love.mouse.getPosition())})
  self:setUniform('dt', dt)
  self:setUniform('dynamicTex', self.world.dynamic)
  self:setUniform('dynamicTexSize', {self.world.dynamic:getDimensions()})

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
      self:sendUniforms()
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
Dynamic.bodyToWorldShader = [[

uniform Image bodiesTex;
uniform vec2  bodiesTexSize;
uniform float densityOrder;

varying float v_mass;
varying float v_radius;
varying vec2  v_vertex;
varying vec2  v_velo;

#ifdef VERTEX

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
  float bodiesTexU = float(love_InstanceID) / bodiesTexSize.x;
  vec4 body0 = Texel(bodiesTex, vec2(bodiesTexU, 0.25));
  vec4 body1 = Texel(bodiesTex, vec2(bodiesTexU, 0.75));
  vec2 pos = body0.xy;
  vec2 velo = body0.zw;
  float radius = body1.x;
  float mass = body1.y;

  v_radius = radius;
  v_mass = mass;
  v_velo = velo;

  v_vertex = vertex_position.xy;
  vertex_position.xy += vertex_position.xy * v_radius + pos;
  return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    float distToCenter = length(v_vertex.xy); // <- circle
    vec4 result = vec4(1,1,1,1);
    float density = (1.0-pow(distToCenter,densityOrder));
    
    result.r = density * v_mass / MASS_FACTOR;
    result.gb = ((v_velo / SPEED_FACTOR * result.r) + vec2(0.5,0.5));
    result.a = 1-distToCenter;
    if(result.a <= 0) {
      discard;
    }
    return result;
}
#endif
]]

function Dynamic:renderToWorld(world)
  love.graphics.setShader(self.bodyToWorldShader)
  self:sendUniforms()
  self.bodyToWorldShader:send('bodiesTex', self.canvas)
  self.bodyToWorldShader:send('bodiesTexSize', {self.data:getDimensions()})
  love.graphics.setBlendMode('lighten','premultiplied')
  self.world.target:renderTo(function()
    love.graphics.drawInstanced(mesh, self.size)
  end)
  love.graphics.reset()
end

-- FOR DEBUG ONLY --

function Dynamic:drawValues(index, sx, sy)
  local text = string.format('index=%f\n',index)
  for k,v in ipairs(self.spec) do
    local values = {self.data:getPixel(index,(k-1)/4)}
    text = text..string.format('%s=%.2f\n',v,values[(k-1)%4+1])
  end
  love.graphics.print(text,sx,sy)
end

function Dynamic:draw()
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