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

CUBEWALL_THICKNESS = 0.04
CUBEWALL_HEIGHT = 1.2

cameraPosition = vec3.create()
camera = mat4.create()

lightProjection = mat4.create()
lightTransform = mat4.create()

renderClayScene = new ClayRenderer regl

world = new World()

color2vec = (color) ->
  vec4.fromValues color.red(), color.green(), color.blue(), 1

class PersonRendererProps
  constructor: (person) ->
    @_debug = person._debug

    @_srcMainBody = person._mainBody
    @_srcMainBodyPos = @_srcMainBody.GetPosition()
    @_srcWalkTracker = person._walkTracker

    @_pos = vec3.create()
    @model = mat4.create()
    @modelFootL = mat4.create()
    @modelFootR = mat4.create()
    @colorTop = color2vec person._color
    @colorBottom = color2vec person._color2

  update: ->
    vec3.set @_pos, @_srcMainBodyPos.x, @_srcMainBodyPos.y, 0

    mat4.identity @model # @todo reuse one identity source?
    mat4.translate @model, @model, @_pos
    mat4.rotateZ @model, @model, @_srcMainBody.GetAngle()

    # feet are positioned independently in world space
    mat4.identity @modelFootL # @todo reuse one identity source?
    mat4.translate @modelFootL, @modelFootL, @_srcWalkTracker.footLMeshOffset
    mat4.rotateZ @modelFootL, @modelFootL, @_srcMainBody.GetAngle()

    mat4.identity @modelFootR # @todo reuse one identity source?
    mat4.translate @modelFootR, @modelFootR, @_srcWalkTracker.footRMeshOffset
    mat4.rotateZ @modelFootR, @modelFootR, @_srcMainBody.GetAngle()

personRendererPropsList = (new PersonRendererProps(person) for person in world._personList)

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

  props.update() for props in personRendererPropsList

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

    if personShape then personShape personRendererPropsList, render

  for person in world._personList
    debugTargetShape
      camera: camera
      color: [ person._color2.red(), person._color2.green(), person._color2.blue(), 0.4 ]
      translate: [ person._walkTarget.x, person._walkTarget.y, 0.001 ]
      size: 0.2

    # foot tracker debug
    debugTargetXRayShape
      camera: camera
      color: [ person._color2.red(), person._color2.green(), person._color2.blue(), 0.8 ]
      translate: [ person._walkTracker._walkFootLNextPos[0], person._walkTracker._walkFootLNextPos[1], 0.001 ]
      size: 0.1

    debugTargetXRayShape
      camera: camera
      color: [ person._color2.red(), person._color2.green(), person._color2.blue(), 0.8 ]
      translate: [ person._walkTracker._walkFootRNextPos[0], person._walkTracker._walkFootRNextPos[1], 0.001 ]
      size: 0.1
