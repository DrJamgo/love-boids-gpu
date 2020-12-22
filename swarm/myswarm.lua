require 'swarm.dynamicbodies'

MySwarm = Class({__includes={DynamicBodies}})

function MySwarm:init(...)
  DynamicBodies.init(self, ...)
end