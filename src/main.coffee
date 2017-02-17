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

    @model = mat4.create()
    @modelFootL = mat4.create()
    @modelFootR = mat4.create()
    @colorTop = vec4.create()
    @colorBottom = vec4.create()

  update: (person) ->
    mainBody = person._mainBody
    mainBodyPos = mainBody.GetPosition()
    walkTracker = person._walkTracker

    vec3.set @_pos, mainBodyPos.x, mainBodyPos.y, 0

    mat4.identity @model # @todo reuse one identity source?
    mat4.translate @model, @model, @_pos
    mat4.rotateZ @model, @model, mainBody.GetAngle()

    # feet are positioned independently in world space
    mat4.identity @modelFootL # @todo reuse one identity source?
    mat4.translate @modelFootL, @modelFootL, walkTracker.footLMeshOffset
    mat4.rotateZ @modelFootL, @modelFootL, mainBody.GetAngle()

    mat4.identity @modelFootR # @todo reuse one identity source?
    mat4.translate @modelFootR, @modelFootR, walkTracker.footRMeshOffset
    mat4.rotateZ @modelFootR, @modelFootR, mainBody.GetAngle()

    vec4.set @colorTop, person._color.red(), person._color.green(), person._color.blue(), 1
    vec4.set @colorBottom, person._color2.red(), person._color2.green(), person._color2.blue(), 1

  draw: regl
    # override default person shape parameters to source from computed data attached to "this"
    uniforms:
      model: regl.this 'model'
      modelTop: regl.this 'model'
      modelFootL: regl.this 'modelFootL'
      modelFootR: regl.this 'modelFootR'

      colorTop: regl.this 'colorTop'
      colorBottom: regl.this 'colorBottom'

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

    # @todo avoid rendering if no physics processed yet - or maybe just init the cycle tracker properly!
    if personShape then personShape world._personList, (ctx, props) ->
      pr.update props
      pr.draw render

  for person in world._personList
    debugTargetShape
      camera: camera
      color: [ person._color2.red(), person._color2.green(), person._color2.blue(), 0.4 ]
      translate: [ person._walkTarget.x, person._walkTarget.y, 0.001 ]
      radius: 0.2

    debugRayXRayShape
      camera: camera
      color: [ 0.2, 0.2, 0.2, if person._avoidanceGoSlow then 0.4 else 0.8 ]
      translate: [ person._mainBody.GetPosition().x, person._mainBody.GetPosition().y, 0.001 ]
      radius: 0.01
      length: 0.8
      direction: person._debugTargetAngle
