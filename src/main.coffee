vec3 = require('gl-matrix').vec3
mat4 = require('gl-matrix').mat4
regl = require('regl')
  extensions: 'oes_texture_float'

LIGHT_MAP_DEPTH_EXTENT = 12

# code inspired by https://github.com/regl-project/regl/blob/gh-pages/example/shadow_map.js
personShape = null
require('./Person.coffee')(regl).then (v) -> personShape = v

groundShape = regl
  vert: '''
    uniform mat4 light;

    uniform vec4 colorA;
    uniform vec4 colorB;
    uniform mat4 camera;
    attribute vec2 position;

    varying vec4 color;
    varying vec4 fShadowCoord;

    void main() {
      vec4 worldPosition = vec4(position, 0, 1);
      gl_Position = camera * worldPosition;
      color = mix(colorA, colorB, (position.y + 8.0) / 16.0);
      fShadowCoord = light * worldPosition;
    }
  '''

  frag: '''
    varying mediump vec4 color;
    varying mediump vec4 fShadowCoord;
    uniform sampler2D shadowMap;

    float shadowSample(vec2 co, float z, float bias) {
      float a = texture2D(shadowMap, co).z;
      float b = fShadowCoord.z;

      return step(b - bias, a);
    }

    void main() {
      vec2 co = fShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]

      float bias = 0.005;

      float v = 1.0; // shadow value
      v = shadowSample(co, fShadowCoord.z, bias);

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
    light: regl.prop('light')
    colorA: regl.prop('colorA')
    colorB: regl.prop('colorB')
    shadowMap: regl.prop('shadowMap')

  primitive: 'triangle fan'
  count: 4

cameraPosition = vec3.create()
camera = mat4.create()
modelA = mat4.create()
modelB = mat4.create()

light = mat4.create()

shadowFBO = regl.framebuffer
  color: regl.texture
    width: 1024
    height: 1024
    wrap: 'clamp'
    type: 'float'

  depth: true

renderView = regl
  vert: '''
    // standard material code
    uniform mediump mat4 camera;
    uniform mediump mat4 light;
    uniform mediump mat4 model;

    varying vec4 fShadowCoord;
    varying vec4 fNormal;

    void applyMaterial(vec4 localPosition, vec3 localNormal) {
      vec4 worldPosition = model * localPosition;

      gl_Position = camera * worldPosition;
      fShadowCoord = light * worldPosition;
      fNormal = model * vec4(localNormal, 0); // normal in world space without translation
    }

    // shape-specific code
    uniform mediump vec4 colorTop;
    uniform mediump vec4 colorBottom;
    attribute vec4 position;
    attribute vec3 normal;
    attribute vec2 uv;

    varying vec4 fColor;
    varying vec2 fUV;

    void main() {
      fColor = mix(colorBottom, colorTop, position.z);
      fUV = uv;

      applyMaterial(position, normal);
    }
  '''

  frag: '''
    // standard material code
    uniform mediump mat4 light;
    uniform sampler2D shadowMap;
    varying mediump vec4 fShadowCoord;
    varying mediump vec4 fNormal;

    float shadowSample(vec2 co, float z, float bias) {
      float a = texture2D(shadowMap, co).z;
      float b = fShadowCoord.z;

      return step(b - bias, a);
    }

    void applyMaterial(vec4 pigment) {
      vec2 co = fShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]
      float lightCosTheta = -float(''' + LIGHT_MAP_DEPTH_EXTENT + ''') * (light * fNormal).z;
      float lightDiffuseAmount =  clamp(lightCosTheta, 0.0, 1.0);

      float bias = max(0.03 * (1.0 - lightCosTheta), 0.005);
      float v = shadowSample(co, fShadowCoord.z, bias);

      gl_FragColor = pigment * vec4(vec3(0.8 + 0.2 * lightDiffuseAmount * v), 1.0);
    }

    // shape-specific code
    uniform sampler2D texture;
    varying mediump vec4 fColor;
    varying mediump vec2 fUV;

    void main() {
      applyMaterial(texture2D(texture, fUV) * fColor);
    }
  '''

  uniforms:
    model: regl.prop 'model'
    camera: regl.prop 'camera'
    light: regl.prop 'light'
    shadowMap: regl.prop 'shadowMap'

    colorTop: [ 1, 1, 0.8, 1 ]
    colorBottom: [ 1, 0.8, 1, 1 ]

renderDepth = regl
  vert: '''
    attribute vec4 position;
    uniform mat4 light, model;

    varying vec3 fPosition;

    void main() {
      vec4 pos = light * model * position;
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
    light: regl.prop 'light'

withShadowFBO = regl
  framebuffer: shadowFBO

regl.frame ({ time, viewportWidth, viewportHeight }) ->
  vec3.set cameraPosition, 10, 10, -15

  mat4.perspective camera, 0.3, viewportWidth / viewportHeight, 1, 50
  mat4.rotateX camera, camera, -Math.PI / 4
  mat4.rotateZ camera, camera, Math.PI / 4
  mat4.translate camera, camera, cameraPosition

  mat4.ortho light, -12, 12, -12, 12, -LIGHT_MAP_DEPTH_EXTENT, LIGHT_MAP_DEPTH_EXTENT
  mat4.rotateX light, light, -0.6
  mat4.rotateZ light, light, 3 * Math.PI / 4

  mat4.identity modelA
  mat4.translate modelA, modelA, [ -0.5, 0.5, 0 ]
  mat4.rotateZ modelA, modelA, -1

  mat4.identity modelB
  mat4.translate modelB, modelB, [ 0.4, 0.1, 0 ]
  mat4.rotateZ modelB, modelB, -3

  withShadowFBO ->
    regl.clear
      color: [ 1, 1, 1, 1 ]
      depth: 1

    if personShape then personShape ->
      renderDepth
        model: modelA
        light: light
      renderDepth
        model: modelB
        light: light

  regl.clear
    color: [ 1, 1, 1, 1 ]
    depth: 1

  groundShape
    camera: camera
    light: light
    colorA: [ 0.8, 0.8, 0.8, 1 ]
    colorB: [ 0.98, 0.98, 0.98, 1 ]
    shadowMap: shadowFBO

  if personShape then personShape ->
    renderView
      model: modelA
      camera: camera
      light: light
      shadowMap: shadowFBO
    renderView
      model: modelB
      camera: camera
      light: light
      shadowMap: shadowFBO
