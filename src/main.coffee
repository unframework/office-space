CSG = require('csg')
vec2 = require('gl-matrix').vec2
vec3 = require('gl-matrix').vec3
vec4 = require('gl-matrix').vec4
mat4 = require('gl-matrix').mat4
color = require('onecolor')

STREAM_WIDTH = 854
STREAM_HEIGHT = 480

document.title = 'OFFICE-SPACE 3D VIEWPORT'

document.body.style.margin = '0'
document.body.style.padding = '0'
document.body.style.background = '#70787f'
document.body.style.position = 'relative'

canvas = document.createElement 'canvas'
canvas.style.position = 'absolute'
#canvas.style.top = '50vh'
#canvas.style.left = '50vw'
#canvas.style.marginTop = -STREAM_HEIGHT / 2 + 'px'
#canvas.style.marginLeft = -STREAM_WIDTH / 2 + 'px'
canvas.style.width = STREAM_WIDTH + 'px'
canvas.style.height = STREAM_HEIGHT + 'px'

document.body.appendChild canvas

canvas.width = canvas.offsetWidth
canvas.height = canvas.offsetHeight

regl = require('regl')
  canvas: canvas
  extensions: 'oes_texture_float'

World = require('./World.coffee')
ClayRenderer = require('./ClayRenderer.coffee')
createCSGShape = require('./CSGShape.coffee')
autorestart = require('./autorestart.coffee')

personShape = null
require('./PersonShape.coffee')(regl).then (v) -> personShape = v

paint = (shape, polyColor) ->
  rgb = polyColor.rgb() # pre-optimize

  for poly in shape.toPolygons()
    poly.shared = { color: rgb }

groundCSG = CSG.cube(
  center: [ 0, 0, -0.2 ]
  radius: [ 24, 24, 0.1 ]
)
paint groundCSG, new color.HSL(0.6, 0.1, 0.05)

pavementCSG = CSG.cube(
  center: [ 0, 2.5, -0.1 ]
  radius: [ 24, 5.5, 0.1 ]
)
paint pavementCSG, new color.HSL(0, 0, 0.3)

pavementShape = createCSGShape(regl, groundCSG.union(pavementCSG), true)

debugTargetShape = require('./DebugTargetShape.coffee')(regl)
debugTargetXRayShape = require('./DebugTargetShape.coffee')(regl, true)
debugRayXRayShape = require('./DebugRayShape.coffee')(regl, true)

screenShape = null
require('./ScreenShape.coffee')(regl).then (v) -> screenShape = v

CUBEWALL_THICKNESS = 0.04
CUBEWALL_HEIGHT = 1.2

cameraPosition = vec3.create()
camera = mat4.create()

lightPosition = vec3.create()
lightProjection = mat4.create()
lightTransform = mat4.create()

focusCenterPos = mat4.create()
focusCenter = mat4.create()

renderClayScene = new ClayRenderer regl

world = new World()

buildingShapeList = []
tickerList = []

world.buildings.on 'data', (building) =>
  shape = createCSGShape(regl, building._csg)
  shape._building = building

  buildingShapeList.push shape

  tickerList = tickerList.concat building.tickerList.map (ticker) ->
    {
      building: building
      center: vec3.fromValues(ticker[0][0], ticker[0][1], ticker[0][2])
      radius: vec2.fromValues(ticker[1][0], ticker[1][1])
    }

world.buildingsOut.on 'data', (building) =>
  [ shapeIndex ] = (shapeIndex for shape, shapeIndex in buildingShapeList when shape._building is building)

  shape = buildingShapeList[shapeIndex]
  buildingShapeList.splice shapeIndex, 1

  shape.destroy()

  tickerIndexList = (tickerIndex for ticker, tickerIndex in tickerList when ticker.building is building)

  # process from last to first, to avoid problems when splicing
  tickerIndexList.reverse()
  for tickerIndex in tickerIndexList
    tickerList.splice tickerIndex, 1

class TrainRenderer
  constructor: (@_train) ->
    @_pos = vec3.create()
    @_modelList = (mat4.create() for o in @_train._carOffsetList)
    @_shape = createCSGShape(regl, @_train._carCSG, true)

  update: ->
    # recompute position matrix for each car
    for model, carIndex in @_modelList
      vec3.set @_pos, @_train._offsetX, @_train._carOffsetList[carIndex], @_train._offsetZ

      mat4.identity model
      mat4.translate model, model, @_pos

  draw: (command) ->
    for model in @_modelList
      @_shape { model: model }, command

  destroy: ->
    @_shape.destroy()

bridgeShapeList = []
world.bridges.on 'data', (bridge) =>
  shape = createCSGShape(regl, bridge._csg)
  shape._bridge = bridge
  shape._trainRenderer = new TrainRenderer(bridge._train)

  bridgeShapeList.push shape

world.bridgesOut.on 'data', (bridge) =>
  [ shapeIndex ] = (shapeIndex for shape, shapeIndex in bridgeShapeList when shape._bridge is bridge)

  shape = bridgeShapeList[shapeIndex]
  bridgeShapeList.splice shapeIndex, 1

  shape.destroy()
  shape._trainRenderer.destroy()

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

regl.frame ({ time, viewportWidth, viewportHeight }) ->
  vec3.set cameraPosition, 14 - world._focusX, 14, -20 + 0.2 * Math.sin(time / 8)

  mat4.perspective camera, 0.3, viewportWidth / viewportHeight, 1, 80
  mat4.rotateX camera, camera, -Math.PI / 4
  mat4.rotateZ camera, camera, Math.PI / 4
  mat4.translate camera, camera, cameraPosition

  mat4.ortho lightProjection, -20, 20, -20, 20, -26, 6

  vec3.set lightPosition, Math.round(-world._focusX / 4) * 4, 0, 0 # @todo figure out why this needs to be negated
  mat4.identity lightTransform
  mat4.rotateX lightTransform, lightTransform, -Math.PI / 8
  mat4.rotateZ lightTransform, lightTransform, -1 * Math.PI / 4
  mat4.translate lightTransform, lightTransform, lightPosition

  vec3.set focusCenterPos, world._focusX, 0, 0
  mat4.identity focusCenter
  mat4.translate focusCenter, focusCenter, focusCenterPos

  regl.clear
    color: [ 1, 1, 1, 1 ]
    depth: 1

  renderClayScene camera, lightProjection, lightTransform, (render, renderNonShadowing) ->
    pavementShape { model: focusCenter }, renderNonShadowing

    for bridgeShape in bridgeShapeList
      bridgeShape render

      bridgeShape._trainRenderer.update()
      bridgeShape._trainRenderer.draw render

    for bldgShape in buildingShapeList
      bldgShape render

    if personShape then personShape world._personList, (ctx, props) ->
      pr.update props
      pr.draw render

    if screenShape
      screenShape tickerList, render

# auto reload page because sounds seem to cut out after ~24hr
autorestart(86400 * 1000)
