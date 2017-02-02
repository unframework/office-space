vec3 = require('gl-matrix').vec3
mat4 = require('gl-matrix').mat4
regl = require('regl')()

personShape = null
require('./Person.coffee')(regl).then (v) -> personShape = v

groundShape = regl
  vert: '
    uniform vec4 colorA;
    uniform vec4 colorB;
    uniform mat4 camera;
    attribute vec2 position;

    varying vec4 color;

    void main() {
      gl_Position = camera * vec4(position, 0, 1);
      color = mix(colorA, colorB, (position.y + 8.0) / 16.0);
    }
  '

  frag: '
    varying mediump vec4 color;

    void main() {
      gl_FragColor = color;
    }
  '

  attributes:
    position: regl.buffer [
      [-8, -8]
      [8, -8]
      [8,  8]
      [-8, 8]
    ]

  uniforms:
    camera: regl.prop('camera')
    colorA: regl.prop('colorA')
    colorB: regl.prop('colorB')

  primitive: 'triangle fan'
  count: 4

cameraPosition = vec3.create()
camera = mat4.create()
model = mat4.create()

renderView = regl
  vert: '
    uniform mat4 camera;
    uniform mat4 model;
    uniform mediump vec4 colorTop;
    uniform mediump vec4 colorBottom;
    attribute vec4 position;
    attribute vec2 uv;

    varying vec2 fUV;
    varying vec4 fColor;

    void main() {
      gl_Position = camera * model * position;
      fColor = mix(colorBottom, colorTop, position.z);
      fUV = uv;
    }
  '

  frag: '
    varying mediump vec4 fColor;
    varying mediump vec2 fUV;
    uniform sampler2D texture;

    void main() {
      gl_FragColor = texture2D(texture, fUV) * fColor;
    }
  '

  uniforms:
    model: regl.prop 'model'
    camera: regl.prop 'camera'

    colorTop: [ 1, 1, 0.8, 1 ]
    colorBottom: [ 1, 0.8, 1, 1 ]

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

  groundShape
    camera: camera
    colorA: [ 0.8, 0.8, 0.8, 1 ]
    colorB: [ 0.98, 0.98, 0.98, 1 ]

  if personShape then personShape -> renderView
    model: model
    camera: camera
