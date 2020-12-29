require 'physics.dynamic'

Boids = Class({__includes={Dynamic}})
Boids.uniforms.ruleSeparation = 2000
Boids.uniforms.ruleAlignment = 10
Boids.uniforms.ruleCohesion = 30

function Boids:init(...)
  Dynamic.init(self, ...)
  self.behaviourshader = self.behaviourshader:gsub('PIXELSPEC', self:pixelSpecCode())
  self.behaviourshader = love.graphics.newShader(self.shadercommons .. self.behaviourshader)
  self.ectoshader = self.ectoshader:gsub('PIXELSPEC', self:pixelSpecCode())
  self.ectoshader = love.graphics.newShader(self.shadercommons .. self.ectoshader)
  self.uniforms.heatPalette = love.graphics.newImage('darknesspalette.png')
  self.uniforms.heatPalette:setFilter('nearest','nearest')
  self.uniforms.densityOrderHeat = 1
  self.uniforms.heatTest = 1

  gWiggleValues:add('c', self.uniforms, 'ruleCohesion')
  gWiggleValues:add('a', self.uniforms, 'ruleAlignment')
  gWiggleValues:add('s', self.uniforms, 'ruleSeparation')
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

Boids.behaviourshader = [[

uniform Image dynamicTex;
uniform vec2  dynamicTexSize;
uniform float dt;
uniform vec2 target;

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
  PIXELSPEC

  vec2 pos = vec2(_x,_y);
  vec2 velo = vec2(_vx,_vy);
  float radius = _r+2;
  float mass = _m;

  vec4 result;

  // x,y,vx,vy
  if (_output_row == 0) {
    vec2 targetDiff = vec2(0,0);
    //if(screen_coords.x == 1.5 && all(greaterThan(target, vec2(0,0)))) {
    if(all(greaterThan(target, vec2(0,0)))) {
      // has target
      targetDiff = target - pos;
    }

    float v = length(velo);
    velo *= pow(0.1, dt);

    float f = dt;
    velo = velo * (1-dt) + targetDiff * dt;

    const int sight = 50;
    const int step = 5;

    vec2 vecSeparation = vec2(0,0);
    vec2 vecCohesion = vec2(0,0);
    vec2 vecAlignment = vec2(0,0);
    float sumSeperation = 0;
    float sumCohesion = 0;
    float sumAlignment = 0;

    for(int x = -sight; x <= sight; x+=step) {
      for(int y = -sight; y <= sight; y+=step) {
        vec2 dv = vec2(float(x),float(y)) + velo/4;
        if (min(abs(x),abs(y)) > radius+1) {
          vec4 dynamic = Texel(dynamicTex, (pos + dv) / dynamicTexSize);

          // my boids
          if (dynamic.r > 0) {
            vec2 velocity = (dynamic.gb - vec2(0.45,0.45)) * SPEED_FACTOR;
            vecCohesion += dv;
            vecAlignment += velocity;
            sumCohesion++;
            sumAlignment++;
          }
          if (dynamic.a > 0) {
            float l = length(dv);
            if(l < sight) {
              float f = pow((sight)-l/3,1.5);
              sumSeperation += f;
              vecSeparation += -normalize(dv) * f;
            }
          }
        }
      } 
    }

    if(sumSeperation > 0) {
      vecSeparation /= sumSeperation;
      velo += vecSeparation * ruleSeparation * dt;
    }
    if(sumCohesion > 0) {
      vecCohesion /= sumCohesion;
      velo += vecCohesion * ruleCohesion * dt;
    }
    if(sumAlignment > 0) {
      vecAlignment /= sumAlignment;
      velo += vecAlignment * ruleAlignment * dt;
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

function Boids:update(dt)
  Dynamic.update(self, dt)
  if love.mouse.isDown(1) then
    self:setUniform('target', {self.world.transform:inverseTransformPoint(love.mouse.getPosition())})
  else
    self:setUniform('target', {-1,-1})
  end
  self:updatePixels(self.behaviourshader)
end

Boids.ectoshader = [[

uniform Image bodiesTex;
uniform Image heatPalette;
uniform vec2  bodiesTexSize;
uniform float densityOrderHeat;
uniform float heatTest;

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
  vertex_position.xy += vertex_position.xy * 2 * v_radius + pos;
  return transform_projection * vertex_position;
}
#endif
 
#ifdef PIXEL
vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(tex, texture_coords);
    float distToCenter = length(v_vertex.xy); // <- circle
    vec4 result = vec4(1,1,1,1);
    float density = (1.0-pow(distToCenter,densityOrderHeat)+0.2) * heatTest;
    result = Texel(heatPalette, vec2(density,0.5));
    result.a *= 1-distToCenter;
    if(distToCenter > 1) {
      discard;
    }
    return result;
}
#endif
]]

function Boids:draw()
  love.graphics.setShader(self.ectoshader)
  self:sendUniforms()
  self.ectoshader:send('bodiesTex', self.canvas)
  self.ectoshader:send('bodiesTexSize', {self.data:getDimensions()})
  love.graphics.drawInstanced(mesh, self.size)
  love.graphics.reset()
end