
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
  PixelSpec.init(self, self.spec, maxbodies)

  self.world = world
  self.size = 0
  self.capacity = maxbodies
  self.updateshader = self.updateshader:gsub('PIXELSPEC', self:pixelSpecCode())
  self.updateshader = love.graphics.newShader(self.shadercommons .. self.updateshader)
  self.bodyToWorldShader = self.bodyToWorldShader:gsub('PIXELSPEC', self:pixelSpecCode())
  self.bodyToWorldShader = love.graphics.newShader(self.shadercommons .. self.bodyToWorldShader)
end

function Dynamic:addBody(body)
  if self.size < self.capacity-1 then
    self.size = self.size + 1
    self:write(self.size, body)
    self.needupload = true
  end
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
uniform float limitVelocity;

const float numSteps = 32.0;


#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position )
{
  return transform_projection * vertex_position;
}
#endif
 
#ifdef PIXEL

#define _input_tex tex
#define _input_u texture_coords.s
#define _output_row screen_coords.y - 0.5

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
  PIXELSPEC

  vec2 pos = vec2(_x,_y);
  vec2 velo = vec2(_vx,_vy);
  float radius = _r+2;
  float mass = _m;

  vec4 result;

  // x,y,vx,vy
  if (_output_row == 0) {
    pos += velo * dt;

    vec2 vector = vec2(0.0,0.0);
    float summed = 0;
    for(float angle = -M_PI; angle < M_PI; angle += M_PI*2/numSteps) {
      vec2 diff = vec2(cos(angle),sin(angle));
      float texval = Texel(dynamicTex, (pos+diff*radius) / dynamicTexSize).a * textureFactor;
      vec2 delta = texval * diff / numSteps * (MASS_FACTOR);
      summed += length(delta) / numSteps;
      vector += delta;
    }
    vec2 targetVelo = vector.xy * velocityFactor;
    vec2 diff = velo - targetVelo;
    velo += diff * summed * dt;
    pos += diff * summed * dt * (posFactor / velocityFactor);


    if(pos.x < radius || pos.x > dynamicTexSize.x-radius) {
      velo.x = 0;
    }
    if(pos.y < radius || pos.y > dynamicTexSize.y-radius) {
      velo.y = 0;
    }

    pos = clamp(pos, vec2(radius,radius), dynamicTexSize - vec2(radius,radius));

    float absvelo = length(velo);
    if(absvelo > limitVelocity) {
      velo *= limitVelocity / absvelo;
    }

    result._out_x = pos.x;
    result._out_y = pos.y;
    result._out_vx = velo.x;
    result._out_vy = velo.y;
  }
  // r,m
  else if(_output_row == 1){
    result = _input_row_1;
  }
  
  return result;
}
#endif
]]

function Dynamic:update(dt)
  self:setUniform('dt', dt)
  self:setUniform('dynamicTex', self.world.dynamic)
  self:setUniform('dynamicTexSize', {self.world.dynamic:getDimensions()})

  self:updatePixels(self.updateshader)
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

#define _input_tex bodiesTex

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
  float _input_u = float(love_InstanceID) / bodiesTexSize.x;

  PIXELSPEC

  vec2 pos = vec2(_x,_y);
  v_velo = vec2(_vx,_vy);
  v_radius = _r;
  v_mass = _m;

  v_vertex = vertex_position.xy;
  vertex_position.xy += vertex_position.xy * v_radius + pos;
  return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL

const vec2 offset = vec2(1,1) * 0.5 + 0.5/255;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    float distToCenter = length(v_vertex.xy); // <- circle
    vec4 result = vec4(1,1,1,1);
    float density = (1.0-pow(distToCenter,densityOrder));
    
    result.a = density * v_mass / MASS_FACTOR;
    result.gb = ((v_velo / SPEED_FACTOR) + offset);
    result.r = 1-distToCenter;
    if(result.r <= 0) {
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