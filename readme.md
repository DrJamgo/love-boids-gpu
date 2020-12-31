# love-boids-gpu
A [Boids](https://en.wikipedia.org/wiki/Boids) algorithm implementation for [LÖVE](https://love2d.org/) Framework running mostly on GPU

The collision and boids math runs on GPU, using fragment shaders as general purpose compute units.

## Demo
The Demo shows interaction betwen up to 2047 Solid Balls and 2047 Boids.

Left/Right clicks add either Boids or Solid Balls:<br>
Watch the Video (click):<br>
[![Screenshot](doc/demo1.gif?raw=true)](doc/L%C3%96VE%20Boids%20GPU%20Demo%202020-12-30%2016-45-57.mp4?raw=true)<br>

Boids behaviour (i.e. __rules__) can be adjusted with values displayed at bottom left corner.

## Design
The implementation is Designed around following principles:
 - Minimize data transfer to and from GPU (sincs this is a real performance killer)
 - Make use of Buffer orphaning (use OpenGLs buffer management)
 - Boids are handled as Swarm, no information about indivuals are necessary (on CPU)