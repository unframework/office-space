vec3 = require('gl-matrix').vec3
mat4 = require('gl-matrix').mat4
regl = require('regl')()

personShape = null
require('./Person.coffee')(regl).then (v) -> personShape = v

cameraPosition = vec3.create()
camera = mat4.create()
model = mat4.create()

drawShape = regl
  frag: '
    precision mediump float;
    varying vec4 color;
    void main() {
      gl_FragColor = color;
    }
  '

  vert: '
    precision mediump float;
    attribute vec2 position;
    uniform vec4 colorA;
    uniform vec4 colorB;
    varying vec4 color;
    void main() {
      gl_Position = vec4(position, 0, 1);
      color = mix(colorA, colorB, (position.y + 0.5) / 2.0);
    }
  '

  attributes:
    position: regl.buffer [
      [-0.8, -0.8]
      [0.8, -0.8]
      [0.8,  0.8]
      [-0.8, 0.8]
    ]

  uniforms:
    colorA: regl.prop('colorA')
    colorB: regl.prop('colorB')

  primitive: 'triangle fan'
  count: 4

regl.frame ({ time, viewportWidth, viewportHeight }) ->
  vec3.set cameraPosition, 0, 4, -4

  mat4.perspective camera, 45, viewportWidth / viewportHeight, 1, 20
  mat4.rotateX camera, camera, -0.8
  mat4.translate camera, camera, cameraPosition

  mat4.identity model
  mat4.rotateZ model, model, -1

  regl.clear
    color: [0, 0, 0, 0]
    depth: 1

  if personShape then personShape
    model: model
    camera: camera
