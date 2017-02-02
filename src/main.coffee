vec3 = require('gl-matrix').vec3
mat4 = require('gl-matrix').mat4
regl = require('regl')
  extensions: 'oes_texture_float'

# code inspired by https://github.com/regl-project/regl/blob/gh-pages/example/shadow_map.js
personShape = null
require('./Person.coffee')(regl).then (v) -> personShape = v

groundShape = regl
  vert: '''
    uniform mat4 lightProjection, lightView;

    uniform vec4 colorA;
    uniform vec4 colorB;
    uniform mat4 camera;
    attribute vec2 position;

    varying vec4 color;
    varying vec4 vShadowCoord;

    void main() {
      vec4 worldPosition = vec4(position, 0, 1);
      gl_Position = camera * worldPosition;
      color = mix(colorA, colorB, (position.y + 8.0) / 16.0);
      vShadowCoord = lightProjection * lightView * worldPosition;
    }
  '''

  frag: '''
    varying mediump vec4 color;
    varying mediump vec4 vShadowCoord;
    uniform sampler2D shadowMap;

    float shadowSample(vec2 co, float z, float bias) {
      float a = texture2D(shadowMap, co).z;
      float b = vShadowCoord.z;

      return step(b - bias, a);
    }

    void main() {
      vec2 co = vShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]

      float bias = 0.005;

      float v = 1.0; // shadow value
      v = shadowSample(co, vShadowCoord.z, bias);

      gl_FragColor = vec4(color.xyz * (0.8 + 0.2 * v), 1.0);
    }
  '''

  attributes:
    position: regl.buffer [
      [-8, -8]
      [8, -8]
      [8,  8]
      [-8, 8]
    ]

  uniforms:
    camera: regl.prop('camera')
    lightView: regl.prop('lightView')
    lightProjection: regl.prop('lightProjection')
    colorA: regl.prop('colorA')
    colorB: regl.prop('colorB')
    shadowMap: regl.prop('shadowMap')

  primitive: 'triangle fan'
  count: 4

cameraPosition = vec3.create()
camera = mat4.create()
model = mat4.create()

lightDir = [ 0.29, 0.39, 0.87 ]
lightView = mat4.lookAt([], lightDir, [ 0, 0, 0 ], [ 0, 1, 0 ])
lightProjection = mat4.ortho([], -12, 12, -12, 12, -12, 12)

shadowFBO = regl.framebuffer
  color: regl.texture
    width: 1024
    height: 1024
    wrap: 'clamp'
    type: 'float'

  depth: true

renderView = regl
  vert: '''
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
  '''

  frag: '''
    varying mediump vec4 fColor;
    varying mediump vec2 fUV;
    uniform sampler2D texture;

    void main() {
      gl_FragColor = texture2D(texture, fUV) * fColor;
    }
  '''

  uniforms:
    model: regl.prop 'model'
    camera: regl.prop 'camera'

    colorTop: [ 1, 1, 0.8, 1 ]
    colorBottom: [ 1, 0.8, 1, 1 ]

renderDepth = regl
  vert: '''
    attribute vec4 position;
    uniform mat4 lightProjection, lightView, model;

    varying vec3 fPosition;

    void main() {
      vec4 pos = lightProjection * lightView * model * position;
      gl_Position = pos;
      fPosition = pos.xyz;
    }
  '''

  frag: '''
    varying mediump vec3 fPosition;

    void main () {
      gl_FragColor = vec4(vec3(fPosition.z), 1.0);
    }
  '''

  uniforms:
    model: regl.prop 'model'
    lightView: regl.prop 'lightView'
    lightProjection: regl.prop 'lightProjection'

withShadowFBO = regl
  framebuffer: shadowFBO

regl.frame ({ time, viewportWidth, viewportHeight }) ->
  vec3.set cameraPosition, 0, 4, -4

  mat4.perspective camera, 45, viewportWidth / viewportHeight, 1, 20
  mat4.rotateX camera, camera, -0.8
  mat4.translate camera, camera, cameraPosition

  mat4.identity model
  mat4.rotateZ model, model, -1

  withShadowFBO ->
    regl.clear
      color: [ 1, 1, 1, 1 ]
      depth: 1

    if personShape then personShape -> renderDepth
      model: model
      lightView: lightView
      lightProjection: lightProjection

  regl.clear
    color: [ 1, 1, 1, 1 ]
    depth: 1

  groundShape
    camera: camera
    lightView: lightView
    lightProjection: lightProjection
    colorA: [ 0.8, 0.8, 0.8, 1 ]
    colorB: [ 0.98, 0.98, 0.98, 1 ]
    shadowMap: shadowFBO

  if personShape then personShape -> renderView
    model: model
    camera: camera
