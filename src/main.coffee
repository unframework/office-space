vec3 = require('gl-matrix').vec3
vec4 = require('gl-matrix').vec4
mat4 = require('gl-matrix').mat4
regl = require('regl')
  extensions: 'oes_texture_float'

World = require('./World.coffee')
ClayRenderer = require('./ClayRenderer.coffee')

personShape = null
require('./PersonShape.coffee')(regl).then (v) -> personShape = v

groundShape = require('./GroundShape.coffee')(regl)
orthoBoxShape = require('./OrthoBoxShape.coffee')(regl)
debugTargetShape = require('./DebugTargetShape.coffee')(regl)
debugTargetXRayShape = require('./DebugTargetShape.coffee')(regl, true)
debugRayXRayShape = require('./DebugRayShape.coffee')(regl, true)

CUBEWALL_THICKNESS = 0.04
CUBEWALL_HEIGHT = 1.2

cameraPosition = vec3.create()
camera = mat4.create()

lightProjection = mat4.create()
lightTransform = mat4.create()

renderClayScene = new ClayRenderer regl

WALKWAY_MARGIN = 0.1
bumperList = [
  [ -WALKWAY_MARGIN, -WALKWAY_MARGIN, 8, 8 ]
  [ -4, -4, -3 + WALKWAY_MARGIN, 8 ]
  [ -4, -4, 8, -3 + WALKWAY_MARGIN ]
]
world = new World(bumperList)

class PersonRenderer
  constructor: ->
    @_pos = vec3.create()

    @_model_out = mat4.create()
    @_modelFootL_out = mat4.create()
    @_modelFootR_out = mat4.create()
    @_colorTop_out = vec4.create()
    @_colorBottom_out = vec4.create()
    @_eyesOpenRatio_out = 0
    @_gazeOffsetX_out = 0

  update: (person) ->
    mainBody = person._mainBody
    mainBodyPos = mainBody.GetPosition()
    walkTracker = person._walkTracker

    @_eyesOpenRatio_out = Math.min(1, person._blinkTimer / 0.18)
    @_gazeOffsetX_out = person._gazeOffsetX

    vec3.set @_pos, mainBodyPos.x, mainBodyPos.y, 0

    mat4.identity @_model_out # @todo reuse one identity source?
    mat4.translate @_model_out, @_model_out, @_pos
    mat4.rotateZ @_model_out, @_model_out, mainBody.GetAngle()
    mat4.rotateX @_model_out, @_model_out, person._leanAngle

    # feet are positioned independently in world space
    mat4.identity @_modelFootL_out # @todo reuse one identity source?
    mat4.translate @_modelFootL_out, @_modelFootL_out, walkTracker.footLMeshOffset
    mat4.rotateZ @_modelFootL_out, @_modelFootL_out, mainBody.GetAngle()

    mat4.identity @_modelFootR_out # @todo reuse one identity source?
    mat4.translate @_modelFootR_out, @_modelFootR_out, walkTracker.footRMeshOffset
    mat4.rotateZ @_modelFootR_out, @_modelFootR_out, mainBody.GetAngle()

    vec4.set @_colorTop_out, person._color.red(), person._color.green(), person._color.blue(), 1
    vec4.set @_colorBottom_out, person._color2.red(), person._color2.green(), person._color2.blue(), 1

  draw: regl
    # override default person shape parameters to source from computed data attached to "this"
    uniforms:
      model: regl.this '_model_out'
      modelTop: regl.this '_model_out'
      modelFootL: regl.this '_modelFootL_out'
      modelFootR: regl.this '_modelFootR_out'

      eyesOpenRatio: regl.this '_eyesOpenRatio_out'
      gazeOffsetX: regl.this '_gazeOffsetX_out'
      colorTop: regl.this '_colorTop_out'
      colorBottom: regl.this '_colorBottom_out'

pr = new PersonRenderer()

orthoBoxes = [
  {
    origin: vec3.fromValues(0, 0, 0)
    size: vec3.fromValues(8, 8, 10)
  }
  {
    origin: vec3.fromValues(-3, -3, -0.1)
    size: vec3.fromValues(3 + 8, 3, 0.1)
  }
  {
    origin: vec3.fromValues(-3, -3, -0.1)
    size: vec3.fromValues(3, 3 + 8, 0.1)
  }
]

regl.frame ({ time, viewportWidth, viewportHeight }) ->
  vec3.set cameraPosition, 11, 11, -15 + 0.2 * Math.sin(time / 8)

  mat4.perspective camera, 0.3, viewportWidth / viewportHeight, 1, 50
  mat4.rotateX camera, camera, -Math.PI / 4
  mat4.rotateZ camera, camera, Math.PI / 4
  mat4.translate camera, camera, cameraPosition

  mat4.ortho lightProjection, -12, 12, -12, 12, -12, 12

  mat4.identity lightTransform
  mat4.rotateX lightTransform, lightTransform, -0.6
  mat4.rotateZ lightTransform, lightTransform, 3 * Math.PI / 4

  regl.clear
    color: [ 1, 1, 1, 1 ]
    depth: 1

  renderClayScene camera, lightProjection, lightTransform, (render, renderNonShadowing) ->
    groundShape
      z: -0.1
      colorA: [ 0.22, 0.22, 0.2, 1 ]
      colorB: [ 0.29, 0.29, 0.28, 1 ]
    , renderNonShadowing

    orthoBoxShape orthoBoxes, render

    if personShape then personShape world._personList, (ctx, props) ->
      pr.update props
      pr.draw render
