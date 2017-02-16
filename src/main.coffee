b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World
b2FixtureDef = require('box2dweb').Dynamics.b2FixtureDef
b2CircleShape = require('box2dweb').Collision.Shapes.b2CircleShape
b2BodyDef = require('box2dweb').Dynamics.b2BodyDef
b2Body = require('box2dweb').Dynamics.b2Body

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
  constructor: (x, y) ->
    fixDef = new b2FixtureDef()
    fixDef.density = 200.0
    fixDef.friction = 2.0
    fixDef.restitution = 0.1
    fixDef.shape = new b2CircleShape(0.5)

    bodyDef = new b2BodyDef()
    bodyDef.type = b2Body.b2_dynamicBody
    bodyDef.position.x = x
    bodyDef.position.y = y

    @_mainBody = world.CreateBody(bodyDef)
    @_mainBody.CreateFixture(fixDef)
    @_mainBody.SetAngularDamping(1.8)

personRendererPropsList = []

class PersonRendererProps
  constructor: (person) ->
    console.log person
    @_pos = vec3.create()
    @_srcMainBodyPos = person._mainBody.GetPosition()

    @model = mat4.create()
    @colorTop = [ 1, 1, 0.8, 1 ]
    @colorBottom = [ 1, 0.8, 1, 1 ]

  update: ->
    vec3.set @_pos, @_srcMainBodyPos.x, @_srcMainBodyPos.y, 0

    mat4.identity @model # @todo reuse one identity source?
    mat4.translate @model, @model, @_pos

personRendererPropsList.push new PersonRendererProps(new Person(0, 0))
personRendererPropsList.push new PersonRendererProps(new Person(-0.5, 0.5))
personRendererPropsList.push new PersonRendererProps(new Person(0.4, 0.1))

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
