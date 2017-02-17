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

world = new World()

class PersonRenderer
  constructor: ->
    @_pos = vec3.create()

    @_model_out = mat4.create()
    @_modelFootL_out = mat4.create()
    @_modelFootR_out = mat4.create()
    @_colorTop_out = vec4.create()
    @_colorBottom_out = vec4.create()

  update: (person) ->
    mainBody = person._mainBody
    mainBodyPos = mainBody.GetPosition()
    walkTracker = person._walkTracker

    vec3.set @_pos, mainBodyPos.x, mainBodyPos.y, 0

    mat4.identity @_model_out # @todo reuse one identity source?
    mat4.translate @_model_out, @_model_out, @_pos
    mat4.rotateZ @_model_out, @_model_out, mainBody.GetAngle()

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

      colorTop: regl.this '_colorTop_out'
      colorBottom: regl.this '_colorBottom_out'

pr = new PersonRenderer()

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
  vec3.set cameraPosition, 10, 10, -15 + 0.2 * Math.sin(time / 8)

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
      colorA: [ 0.8, 0.8, 0.8, 1 ]
      colorB: [ 0.98, 0.98, 0.98, 1 ]
    , renderNonShadowing

    # @todo restore
    # orthoBoxShape orthoBoxes, render

    if personShape then personShape world._personList, (ctx, props) ->
      pr.update props
      pr.draw render

  for person in world._personList
    debugTargetShape
      camera: camera
      color: [ person._color2.red(), person._color2.green(), person._color2.blue(), 0.4 ]
      translate: [ person._walkTarget.x, person._walkTarget.y, 0.001 ]
      radius: 0.2
