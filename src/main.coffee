vec3 = require('gl-matrix').vec3
mat4 = require('gl-matrix').mat4
regl = require('regl')
  extensions: 'oes_texture_float'

ClayRenderer = require('./ClayRenderer.coffee')

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

      void claySetup() {
        fColor = mix(colorA, colorB, (position.y + 8.0) / 16.0);
      }

      vec4 clayPosition() {
        return vec4(position, 0, 1);
      }
    '''

    clayFrag: '''
      varying mediump vec4 fColor;

      vec4 clayNormal() {
        return vec4(0, 0, 1, 0);
      }

      vec4 clayPigment() {
        return fColor;
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

CUBEWALL_THICKNESS = 0.04
CUBEWALL_HEIGHT = 1.2

orthoBoxShape = regl
  context:
    clayVert: '''
      uniform mediump vec3 origin;
      uniform mediump vec3 size;
      attribute vec3 position;

      varying vec3 fNormal;

      void claySetup() {
        fNormal = position.xyz;
      }

      vec4 clayPosition() {
        return vec4(origin + step(vec3(0), position) * size, 1);
      }
    '''

    clayFrag: '''
      varying mediump vec3 fNormal;

      vec4 clayNormal() {
        vec3 mags = floor(abs(fNormal) + 0.0001);
        mags = mags / (mags.x + mags.y + mags.z); // "poor man's normalization" around cusps
        return vec4(mags * sign(fNormal), 0);
      }

      vec4 clayPigment() {
        return vec4(0.85, 0.85, 0.85, 1);
      }
    '''

  uniforms:
    origin: regl.prop 'origin'
    size: regl.prop 'size'

  attributes:
    position: regl.buffer [
      [ -1, -1, -1 ]
      [ -1, 1, -1 ]
      [ 1, -1, -1 ]
      [ 1, 1, -1 ]
      [ 1, -1, 1 ]
      [ 1, 1, 1 ]
      [ -1, -1, 1 ]
      [ -1, 1, 1 ]
      # strip split (draws two dummy triangles inside)
      [ 1, -1, -1 ]
      [ 1, -1, 1 ]
      [ -1, -1, -1 ]
      [ -1, -1, 1 ]
      [ -1, 1, -1 ]
      [ -1, 1, 1 ]
      [ 1, 1, -1 ]
      [ 1, 1, 1 ]
    ]

  cull: enable: true
  primitive: 'triangle strip'
  count: 16

cameraPosition = vec3.create()
camera = mat4.create()
modelA = mat4.create()
modelB = mat4.create()

lightProjection = mat4.create()
lightTransform = mat4.create()

renderClayScene = new ClayRenderer regl

orthoBoxes = [].concat ([].concat (
  for r in [ -1 .. 1 ]
    for n in [ -3 .. 3 ]
      for [ x, y, dx, dy ] in [
        [ n * 2 + 0, r * 6 + -1, 1, 0 ]
        [ n * 2 + 1, r * 6 + -1, 0, 4 ]
        [ n * 2 + -1, r * 6 + 1, 2, 0 ]
        [ n * 2 + 0, r * 6 + 3, 1, 0 ]
      ]
        {
          origin: vec3.fromValues(x - CUBEWALL_THICKNESS / 2, y - CUBEWALL_THICKNESS / 2, 0)
          size: vec3.fromValues(dx + CUBEWALL_THICKNESS, dy + CUBEWALL_THICKNESS, CUBEWALL_HEIGHT)
        }
)...)...

regl.frame ({ time, viewportWidth, viewportHeight }) ->
  vec3.set cameraPosition, 10, 10, -15

  mat4.perspective camera, 0.3, viewportWidth / viewportHeight, 1, 50
  mat4.rotateX camera, camera, -Math.PI / 4
  mat4.rotateZ camera, camera, Math.PI / 4
  mat4.translate camera, camera, cameraPosition

  mat4.ortho lightProjection, -12, 12, -12, 12, -12, 12

  mat4.identity lightTransform
  mat4.rotateX lightTransform, lightTransform, -0.6
  mat4.rotateZ lightTransform, lightTransform, 3 * Math.PI / 4

  mat4.identity modelA
  mat4.translate modelA, modelA, [ -0.5, 0.5, 0 ]
  mat4.rotateZ modelA, modelA, -1

  mat4.identity modelB
  mat4.translate modelB, modelB, [ 0.4, 0.1, 0 ]
  mat4.rotateZ modelB, modelB, -3

  regl.clear
    color: [ 1, 1, 1, 1 ]
    depth: 1

  renderClayScene camera, lightProjection, lightTransform, (renderer) ->
    groundShape
      colorA: [ 0.8, 0.8, 0.8, 1 ]
      colorB: [ 0.98, 0.98, 0.98, 1 ]
    , renderer false

    orthoBoxShape orthoBoxes, renderer true

    if personShape then personShape [
      { model: modelA, colorTop: [ 1, 1, 0.8, 1 ], colorBottom: [ 1, 0.8, 1, 1 ] }
      { model: modelB, colorTop: [ 1, 0.8, 1, 1 ], colorBottom: [ 0.8, 1, 1, 1 ] }
    ], renderer true
