require 'swarm.dynamicbodies'

MySwarm = Class({__includes={DynamicBodies}})

MySwarm.ectoshader = [[

uniform Image bodiesTex;
uniform vec2  bodiesTexSize;
const float densityOrder = 0.5;

varying float v_mass;
varying float v_radius;
varying vec2  v_vertex;

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

  v_vertex = vertex_position.xy;
  vertex_position.xy += vertex_position.xy * v_radius + pos;
  return transform_projection * vertex_position;
}
#endif
 
#ifdef PIXEL
vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(tex, texture_coords);
    float distToCenter = length(v_vertex.xy); // <- circle
    //float distToCenter = max(abs(v_vertex.x),abs(v_vertex.y)); // <- square
    vec4 result = vec4(1,1,1,1);
    float density = (1.0-pow(distToCenter,densityOrder));
    
    result.r = density * v_mass / MASS_FACTOR;
    result.g = 0;
    result.b = 0.2-(density/2);
    if(distToCenter > 1) {
      discard;
    }
    return result;
}
#endif
]]

function MySwarm:init(...)
  DynamicBodies.init(self, ...)
  self.ectoshader = love.graphics.newShader(self.shadercommons .. self.ectoshader)
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

function MySwarm:draw()
  love.graphics.setShader(self.ectoshader)
  self:_applyUniforms(self.ectoshader)
  self.ectoshader:send('bodiesTex', self.canvas)
  self.ectoshader:send('bodiesTexSize', {self.data:getDimensions()})
  love.graphics.drawInstanced(mesh, self.size)
  love.graphics.reset()
end