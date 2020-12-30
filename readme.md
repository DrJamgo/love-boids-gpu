# love-boids-gpu
A [Boids](https://en.wikipedia.org/wiki/Boids) algorithm implementation for LÖVE Framework running mostly on GPU

This is a Boids and Solid object colision implementation for [LÖVE](https://love2d.org/). (I use version 11.3)<br>
The Math runs on GPU, abusing fragment shaders as general purpose compute units.

## Demo
The Demo shows interaction betwen up to 2047 Solid Balls and 2047 Boids.

Left/Right clicks add either Boids or Solid Balls:<br>
Watch the Video (click):<br>
[![Screenshot](doc/demo1.gif?raw=true)](doc/L%C3%96VE%20Boids%20GPU%20Demo%202020-12-30%2016-45-57.mp4?raw=true)<br>

Boids behaviour (i.e. __rules__) can be adjusted with values displayed at bottom left corner.
