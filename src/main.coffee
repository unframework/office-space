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
    @_mainBody.SetAngularDamping(1.8)

    if @_debug
      @_mainBody.ApplyImpulse new b2Vec2(Math.cos(bodyDef.angle) * 20, Math.sin(bodyDef.angle) * 20), new b2Vec2(x, y)

personList = [
  new Person(0, 0, true)
  new Person(-0.5, 0.5)
  new Person(0.4, 0.1)
]

class PersonRendererProps
  constructor: (person) ->
    @_debug = person._debug

    @_srcMainBody = person._mainBody
    @_srcMainBodyPos = @_srcMainBody.GetPosition()

    @_walkPos = vec2.create()
    @_walkDelta = vec2.create()
    @_walkDir = vec2.create()
    @_walkDirCross = vec3.create()
    @_walkAlongPhase = 0
    @_walkAcrossPhase = 0

    @_pos = vec3.create()
    @_footOffset = vec3.create()
    @model = mat4.create()
    @modelTop = mat4.create()
    @modelFootL = mat4.create()
    @modelFootR = mat4.create()
    @colorTop = [ 1, 1, 0.8, 1 ]
    @colorBottom = [ 1, 0.8, 1, 1 ]

  _updateWalk: ->
    vec2.copy @_walkDelta, @_walkPos
    vec2.set @_walkPos, @_srcMainBodyPos.x, @_srcMainBodyPos.y
    vec2.sub @_walkDelta, @_walkPos, @_walkDelta

    vec2.set @_walkDir, Math.cos(@_srcMainBody.GetAngle()), Math.sin(@_srcMainBody.GetAngle())
    along = vec2.dot @_walkDelta, @_walkDir
    vec2.cross @_walkDirCross, @_walkDelta, @_walkDir

    @_walkAlongPhase += along

    if @_walkAlongPhase > 1
      @_walkAlongPhase -= Math.floor @_walkAlongPhase
    else if @_walkAlongPhase < 0
      @_walkAlongPhase += Math.ceil -@_walkAlongPhase

    @_walkAcrossPhase += @_walkDirCross[2]

    if @_walkAcrossPhase > 1
      @_walkAcrossPhase -= Math.floor @_walkAcrossPhase
    else if @_walkAcrossPhase < 0
      @_walkAcrossPhase += Math.ceil -@_walkAcrossPhase

  update: ->
    @_updateWalk()

    vec3.set @_pos, @_srcMainBodyPos.x, @_srcMainBodyPos.y, 0

    mat4.identity @model # @todo reuse one identity source?
    mat4.translate @model, @model, @_pos
    mat4.rotateZ @model, @model, @_srcMainBody.GetAngle()

    mat4.rotateZ @modelTop, @model, -0.05 * Math.sin(8 * @_walkAlongPhase * 2 * Math.PI)

    vec3.set @_footOffset, 0, 0, 0.08 * Math.sin(8 * @_walkAlongPhase * 2 * Math.PI)
    mat4.translate @modelFootL, @model, @_footOffset

    vec3.set @_footOffset, 0, 0, -0.08 * Math.sin(8 * @_walkAlongPhase * 2 * Math.PI)
    mat4.translate @modelFootR, @model, @_footOffset

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

    orthoBoxShape orthoBoxes, render

    if personShape then personShape personRendererPropsList, render
