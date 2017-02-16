b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World
b2FixtureDef = require('box2dweb').Dynamics.b2FixtureDef
b2CircleShape = require('box2dweb').Collision.Shapes.b2CircleShape
b2BodyDef = require('box2dweb').Dynamics.b2BodyDef
b2Body = require('box2dweb').Dynamics.b2Body

vec2 = require('gl-matrix').vec2
vec3 = require('gl-matrix').vec3
mat4 = require('gl-matrix').mat4
regl = require('regl')
  extensions: 'oes_texture_float'

ClayRenderer = require('./ClayRenderer.coffee')

personShape = null
require('./Person.coffee')(regl).then (v) -> personShape = v

groundShape = require('./GroundShape.coffee')(regl)
orthoBoxShape = require('./OrthoBoxShape.coffee')(regl)

CUBEWALL_THICKNESS = 0.04
CUBEWALL_HEIGHT = 1.2

cameraPosition = vec3.create()
camera = mat4.create()

lightProjection = mat4.create()
lightTransform = mat4.create()

renderClayScene = new ClayRenderer regl

world = new b2World(new b2Vec2(0, 0), true)

class Person
  constructor: (x, y, @_debug) ->
    fixDef = new b2FixtureDef()
    fixDef.density = 200.0
    fixDef.friction = 2.0
    fixDef.restitution = 0.1
    fixDef.shape = new b2CircleShape(0.3)

    bodyDef = new b2BodyDef()
    bodyDef.type = b2Body.b2_dynamicBody
    bodyDef.position.x = x
    bodyDef.position.y = y
    bodyDef.angle = (Math.random() * 2 - 1) * Math.PI

    @_mainBody = world.CreateBody(bodyDef)
    @_mainBody.CreateFixture(fixDef)
    @_mainBody.SetLinearDamping(1.2)
    @_mainBody.SetAngularDamping(1.8)

    if @_debug
      # @_mainBody.ApplyImpulse new b2Vec2(0, 200), new b2Vec2(x, y)
      @_mainBody.ApplyImpulse new b2Vec2(Math.cos(bodyDef.angle) * 200, Math.sin(bodyDef.angle) * 200), new b2Vec2(x, y)

personList = [
  new Person(0, -0.2, true)
  new Person(-0.5, 0.5)
  new Person(0.4, 0.1)
]

class PersonRendererProps
  constructor: (person) ->
    @_debug = person._debug

    @_srcMainBody = person._mainBody
    @_srcMainBodyPos = @_srcMainBody.GetPosition()

    @_walkPos = vec2.fromValues(@_srcMainBodyPos.x, @_srcMainBodyPos.y)
    @_walkPhase = 0
    @_walkFootLPos = vec2.create() # last grounded nominal foot position
    @_walkFootRPos = vec2.create()
    @_walkFootLNextPos = vec2.create() # expected next nominal foot position
    @_walkFootRNextPos = vec2.create()
    @_footLocalOffset = vec2.create()
    @_movingFootCurrentPos = vec2.create() # computation helper for current nominal foot position

    @_footLMeshOffset = vec3.create() # displayed foot offset in 3D space
    @_footRMeshOffset = vec3.create()

    @_pos = vec3.create()
    @model = mat4.create()
    @modelFootL = mat4.create()
    @modelFootR = mat4.create()
    @colorTop = [ 1, 1, 0.8, 1 ]
    @colorBottom = [ 1, 0.8, 1, 1 ]

    vec2.set @_footLocalOffset, -Math.sin(@_srcMainBody.GetAngle()), Math.cos(@_srcMainBody.GetAngle())
    vec2.scaleAndAdd @_walkFootLPos, @_walkPos, @_footLocalOffset, 0.4
    vec2.scaleAndAdd @_walkFootRPos, @_walkPos, @_footLocalOffset, -0.4
    vec2.copy @_walkFootLNextPos, @_walkFootLPos
    vec2.copy @_walkFootRNextPos, @_walkFootRPos

  _updateWalk: (deltaTime) ->
    vec2.set @_walkPos, @_srcMainBodyPos.x, @_srcMainBodyPos.y

    FOOT_CYCLE_TIME = 0.5

    @_walkPhase += deltaTime / FOOT_CYCLE_TIME # @todo this accumulates error; significant?
    @_walkPhase -= Math.floor @_walkPhase # fmod 1

    leftFootIsLifted = @_walkPhase < 0.5
    footPhaseAngle = @_walkPhase * 2 * Math.PI
    footLift = Math.sin footPhaseAngle
    footAlong = 0.5 * (1 - (if leftFootIsLifted then 1 else -1) * Math.cos(footPhaseAngle))
    footAnim = (1 - footAlong) * (1 - footAlong) # non-linear foot snap

    [ movingFootRefPos, movingFootNextPos, movingFootOffset ] = if leftFootIsLifted then [ @_walkFootLPos, @_walkFootLNextPos, @_footLMeshOffset ] else [ @_walkFootRPos, @_walkFootRNextPos, @_footRMeshOffset ]
    [ stuckFootPos, stuckFootNextPos, stuckFootOffset ] = if leftFootIsLifted then [ @_walkFootRPos, @_walkFootRNextPos, @_footRMeshOffset ] else [ @_walkFootLPos, @_walkFootLNextPos, @_footLMeshOffset ]

    movingFootTimeInAir = FOOT_CYCLE_TIME * (if leftFootIsLifted then @_walkPhase else @_walkPhase - 0.5)

    vec2.set @_footLocalOffset, -Math.sin(@_srcMainBody.GetAngle()), Math.cos(@_srcMainBody.GetAngle())
    if leftFootIsLifted
      vec2.scale @_footLocalOffset, @_footLocalOffset, 0.4
    else
      vec2.scale @_footLocalOffset, @_footLocalOffset, -0.4

    vec2.add @_movingFootCurrentPos, @_walkPos, @_footLocalOffset

    # extrapolate next position of foot, while damping a bit
    vec2.lerp movingFootNextPos, movingFootRefPos, @_movingFootCurrentPos, movingFootTimeInAir and 0.6 * FOOT_CYCLE_TIME / movingFootTimeInAir
    vec2.lerp movingFootNextPos, movingFootRefPos, movingFootNextPos, 1 - footAnim

    maxLift = Math.min 0.1, (0.3 * vec2.distance movingFootNextPos, movingFootRefPos)

    vec3.set movingFootOffset, movingFootNextPos[0] - @_footLocalOffset[0], movingFootNextPos[1] - @_footLocalOffset[1], maxLift * footAnim

    # preserve stuck foot reference position and reset displayed foot to ground level
    vec2.copy stuckFootPos, stuckFootNextPos
    vec3.set stuckFootOffset, stuckFootNextPos[0] + @_footLocalOffset[0], stuckFootNextPos[1] + @_footLocalOffset[1], 0

  update: (deltaTime) ->
    @_updateWalk deltaTime

    vec3.set @_pos, @_srcMainBodyPos.x, @_srcMainBodyPos.y, 0

    mat4.identity @model # @todo reuse one identity source?
    mat4.translate @model, @model, @_pos
    mat4.rotateZ @model, @model, @_srcMainBody.GetAngle()

    # feet are positioned independently in world space
    mat4.identity @modelFootL # @todo reuse one identity source?
    mat4.translate @modelFootL, @modelFootL, @_footLMeshOffset
    mat4.rotateZ @modelFootL, @modelFootL, @_srcMainBody.GetAngle()

    mat4.identity @modelFootR # @todo reuse one identity source?
    mat4.translate @modelFootR, @modelFootR, @_footRMeshOffset
    mat4.rotateZ @modelFootR, @modelFootR, @_srcMainBody.GetAngle()

personRendererPropsList = (new PersonRendererProps(person) for person in personList)

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

setInterval ->
  world.Step(0.04, 10, 10)
, 40

lastRenderTime = null

regl.frame ({ time, viewportWidth, viewportHeight }) ->
  deltaTime = if lastRenderTime is null then 0 else time - lastRenderTime
  lastRenderTime = time

  vec3.set cameraPosition, 10, 10, -15 + 0.2 * Math.sin(time / 8)

  mat4.perspective camera, 0.3, viewportWidth / viewportHeight, 1, 50
  mat4.rotateX camera, camera, -Math.PI / 4
  mat4.rotateZ camera, camera, Math.PI / 4
  mat4.translate camera, camera, cameraPosition

  mat4.ortho lightProjection, -12, 12, -12, 12, -12, 12

  mat4.identity lightTransform
  mat4.rotateX lightTransform, lightTransform, -0.6
  mat4.rotateZ lightTransform, lightTransform, 3 * Math.PI / 4

  props.update(deltaTime) for props in personRendererPropsList

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
