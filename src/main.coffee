vec3 = require('gl-matrix').vec3
mat4 = require('gl-matrix').mat4
regl = require('regl')
  extensions: 'oes_texture_float'

LIGHT_MAP_DEPTH_EXTENT = 12

# code inspired by https://github.com/regl-project/regl/blob/gh-pages/example/shadow_map.js
personShape = null
require('./Person.coffee')(regl).then (v) -> personShape = v

groundShape = regl
  context:
    clayVert: '''
      uniform vec4 colorA;
      uniform vec4 colorB;
      attribute vec2 position;

      varying vec4 fColor;

      void clayPigment() {
        fColor = mix(colorA, colorB, (position.y + 8.0) / 16.0);
      }

      void clayPosition() {
        applyPosition(vec4(position, 0, 1));
      }

      void clayNormal() {
        applyNormal(vec4(0, 0, 1, 0));
      }
    '''

    clayFrag: '''
      varying mediump vec4 fColor;

      void clayPigment() {
        applyPigment(fColor);
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
    colorA: regl.prop 'colorA'
    colorB: regl.prop 'colorB'

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
  context:
    vert: (context) -> '''
      // standard material code
      uniform mediump mat4 camera;
      uniform mediump mat4 light;

      varying vec4 fShadowCoord;
      varying vec4 fNormal;

      void applyPosition(vec4 worldPosition) {
        gl_Position = camera * worldPosition;
        fShadowCoord = light * worldPosition;
      }

      void applyNormal(vec4 worldNormal) {
        fNormal = worldNormal;
      }

      // shape-specific code

      ''' + context.clayVert + '''

      // invoke standard entry points
      void main() {
        clayPigment();
        clayPosition();
        clayNormal();
      }
    '''

    frag: (context) -> '''
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

      void applyPigment(vec4 pigment) {
        vec2 co = fShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]
        float lightCosTheta = -float(''' + LIGHT_MAP_DEPTH_EXTENT + ''') * (light * fNormal).z;
        float lightDiffuseAmount =  clamp(lightCosTheta, 0.0, 1.0);

        float bias = max(0.03 * (1.0 - lightCosTheta), 0.005);
        float v = shadowSample(co, fShadowCoord.z, bias);

        gl_FragColor = pigment * vec4(vec3(0.8 + 0.2 * lightDiffuseAmount * v), 1.0);
      }

      // shape-specific code

      ''' + context.clayFrag + '''

      // invoke standard entry points
      void main() {
        clayPigment();
      }
    '''

  vert: regl.context 'vert'
  frag: regl.context 'frag'

  uniforms:
    camera: regl.prop 'camera'
    light: regl.prop 'light'
    shadowMap: regl.prop 'shadowMap'

renderDepth = regl
  context:
    vert: (context) -> '''
      uniform mat4 light;

      varying vec4 fPosition;

      void applyPosition(vec4 worldPosition) {
        fPosition = light * worldPosition;
        gl_Position = fPosition;
      }

      void applyNormal(vec4 worldNormal) {
        // not in use
      }

      // shape-specific code

      ''' + context.clayVert + '''

      // invoke standard entry points
      void main() {
        clayPosition();
      }
    '''

  vert: regl.context 'vert'

  frag: '''
    varying mediump vec4 fPosition;

    // ignore shape-specific pigmentation
    void main () {
      gl_FragColor = vec4(vec3(fPosition.z), 1.0);
    }
  '''

  uniforms:
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

    if personShape then personShape [
      { model: modelA }
      { model: modelB }
    ], ->
      renderDepth
        light: light

  regl.clear
    color: [ 1, 1, 1, 1 ]
    depth: 1

  groundShape
    colorA: [ 0.8, 0.8, 0.8, 1 ]
    colorB: [ 0.98, 0.98, 0.98, 1 ]
  , ->
    renderView
      camera: camera
      light: light
      shadowMap: shadowFBO

  if personShape then personShape [
    { model: modelA, colorTop: [ 1, 1, 0.8, 1 ], colorBottom: [ 1, 0.8, 1, 1 ] }
    { model: modelB, colorTop: [ 1, 0.8, 1, 1 ], colorBottom: [ 0.8, 1, 1, 1 ] }
  ], ->
    renderView
      camera: camera
      light: light
      shadowMap: shadowFBO
