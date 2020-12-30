
require 'physics.glslutils'

Dynamic = Class({__includes={Uniforms, FragmentProgram}})
Dynamic.channels = {
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
  FragmentProgram.init(self, self.channels, maxbodies)
  self.world = world
  self.updateshader = self:makeProgram(self.updateshader)
  self.bodyToWorldShader = self:makeProgram(self.bodyToWorldShader)
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

Dynamic.glslcommons = [[
  #pragma language glsl3
  
  #define M_PI 3.1415926535897932384626433832795
  const float MASS_FACTOR = ]]..Dynamic.MASS_FACTOR..[[;
  const float SPEED_FACTOR = ]]..Dynamic.SPEED_FACTOR..[[;
]]

Dynamic.glslfunc_run_colision = [[
uniform float velocityFactor;
uniform float posFactor;
uniform float textureFactor;

const float numSteps = 32.0;

void run_colisions(inout vec2 pos, inout vec2 velo, in float radius)
{
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
}
]]

Dynamic.glslfunc_limit_pos_velo = [[
uniform float limitVelocity;

void limit_pos_velo(inout vec2 pos, inout vec2 velo, in float radius)
{
  pos = clamp(pos, vec2(radius,radius), dynamicTexSize - vec2(radius,radius));

  float absvelo = length(velo);
  if(absvelo > limitVelocity) {
    velo *= limitVelocity / absvelo;
  }
}
]]

-- controlls behaviour of body
Dynamic.updateshader = 
Dynamic.glslcommons..
[[
uniform Image dynamicTex;
uniform vec2  dynamicTexSize;
uniform float dt;
]]..
Dynamic.glslfunc_run_colision..
Dynamic.glslfunc_limit_pos_velo..
[[

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
  // This line will be replaced by auto-code
  DECLARE_CHANNELS

  vec2 pos = vec2(_x,_y);
  vec2 velo = vec2(_vx,_vy);
  float radius = _r+2;
  float mass = _m;

  vec4 result;

  // x,y,vx,vy
  if (_output_row == 0) {
    run_colisions(pos, velo, radius);
    limit_pos_velo(pos, velo, radius);
    pos += velo * dt;

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
Dynamic.bodyToWorldShader = 
Dynamic.glslcommons..
[[
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

  // This line will be replaced by auto-code
  DECLARE_CHANNELS

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

const vec2 offset = vec2(1,1) * 0.5;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    float distToCenter = length(v_vertex.xy); // <- circle
    vec4 result = vec4(1,1,1,1);
    float density = (1.0-pow(distToCenter,densityOrder));
    
    result.a = density * v_mass / MASS_FACTOR;
    result.rg = ((v_velo / SPEED_FACTOR) + offset);
    result.b = 1;
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
  self.bodyToWorldShader:send('bodiesTexSize', {self.canvas:getDimensions()})
  love.graphics.setBlendMode('lighten','premultiplied')
  self.world.target:renderTo(function()
    love.graphics.drawInstanced(mesh, self.size)
  end)
  love.graphics.reset()
end

-- FOR DEBUG ONLY --

function Dynamic:draw()

end