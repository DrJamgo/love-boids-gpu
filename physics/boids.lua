require 'physics.dynamic'
require 'physics.fragmentstats'

Boids = Class({__includes={Dynamic}})
Boids.uniforms.ruleSeparation = 20
Boids.uniforms.ruleAlignment = 10
Boids.uniforms.ruleCohesion = 30
Boids.uniforms.sight = 50
table.insert(Boids.channels, 'fraction')
table.insert(Boids.channels, 'hp')

function Boids:init(...)
  Dynamic.init(self, ...)
  self.behaviourshader = self:makeProgram(self.behaviourshader)
  self.visualshader = self:makeProgram(self.visualshader)

  self.uniforms.palette = love.graphics.newImage('palette.png')
  self.uniforms.palette:setFilter('nearest','nearest')
  self.uniforms.densityOrderHeat = 1

  gWiggleValues:add('c', self.uniforms, 'ruleCohesion')
  gWiggleValues:add('a', self.uniforms, 'ruleAlignment')
  gWiggleValues:add('s', self.uniforms, 'ruleSeparation')
  gWiggleValues:add('v', self.uniforms, 'sight')

  self.stats = FragmentStats(self)
end

Boids.behaviourshader = 
Dynamic.glslcommons..
[[
uniform Image dynamicTex;
uniform vec2  dynamicTexSize;
uniform float dt;
]]..
Dynamic.glslfunc_run_update..
[[
uniform vec2 target;

uniform int sight;
uniform float ruleCohesion;
uniform float ruleAlignment;
uniform float ruleSeparation;

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
  float radius = _r;
  float mass = _m;

  vec4 result;

  // x,y,vx,vy
  if (_output_row == 0) {

    int step = sight/20;        // <- number of steps to sample the map
    vec2 sightOffset = velo/4.0; // <- offsets the sight window into moving direction

    vec2 vecSeparation = vec2(0,0);
    vec2 vecCohesion = vec2(0,0);
    vec2 vecAlignment = vec2(0,0);
    float sumSeperation = 0;
    float sumCohesion = 0;
    float sumAlignment = 0;

    for(int x = -sight; x <= sight; x+=step) {
      for(int y = -sight; y <= sight; y+=step) {
        vec2 dv = vec2(float(x),float(y)) + sightOffset;
        float dist = length(dv);
        vec4 dynamic = Texel(dynamicTex, (pos + dv) / dynamicTexSize);

        // only sample outside own body.
        if(dist > radius+1) {
          // my boids
          if (dynamic.b == 1) {
            vec2 velocity = (dynamic.rg - vec2(0.5,0.5)) * SPEED_FACTOR;
            vecCohesion += dv;
            vecAlignment += velocity;
            sumCohesion++;
            sumAlignment++;
          }
          if (dynamic.a > 0) {
            float f = pow(max(0,(sight-dist/2)/sight),3);
            vecSeparation += -normalize(dv) * f;
          }
        }
      }
    }

    velo += vecSeparation * ruleSeparation * dt;

    if(sumCohesion > 0) {
      vecCohesion /= sumCohesion;
      velo += vecCohesion * ruleCohesion * dt;
    }
    if(sumAlignment > 0) {
      vecAlignment /= sumAlignment;
      velo += vecAlignment * ruleAlignment * dt;
    }

    run_update(pos, velo, radius);

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

function Boids:update(dt)
  self:setUniform('dt', dt)
  self:setUniform('dynamicTex', self.world.dynamic)
  self:setUniform('dynamicTexSize', {self.world.dynamic:getDimensions()})
  self:updatePixels(self.behaviourshader)
  self.stats:update(self.canvas, self.size)
end

Boids.visualshader = 
Dynamic.glslcommons..
[[

uniform Image bodiesTex;
uniform Image palette;
uniform vec2  bodiesTexSize;
uniform float densityOrderHeat;

varying float v_mass;
varying float v_radius;
varying vec2  v_vertex;

#ifdef VERTEX

#define _input_tex bodiesTex
#define _input_u (float(love_InstanceID) / bodiesTexSize.x)

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
  // This line will be replaced by auto-code
  DECLARE_CHANNELS

  vec2 pos = vec2(_x,_y);
  float v_radius = _r;
  float v_mass = _m;

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
    vec4 result = vec4(1,1,1,1);
    float density = (1.0-pow(distToCenter,densityOrderHeat)+0.2);
    result = Texel(palette, vec2(density,0.5));
    result.a *= 1-distToCenter;
    if(distToCenter > 1) {
      discard;
    }
    return result;
}
#endif
]]

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

function Boids:draw()
  love.graphics.setShader(self.visualshader)
  self:sendUniforms()
  self.visualshader:send('bodiesTex', self.canvas)
  self.visualshader:send('bodiesTexSize', {self.canvas:getDimensions()})
  love.graphics.drawInstanced(mesh, self.size)
  love.graphics.reset()
end

function Boids:drawDebug()
  local stats = self.stats.stats
  local x,y = stats.x.min, stats.y.min
  local w,h = stats.x.max - x, stats.y.max - y
  love.graphics.rectangle('line', x,y,w,h)
  love.graphics.print(string.format('count=%d',self.size),x,y)
  love.graphics.circle('line', stats.x.avg, stats.y.avg,10)
end