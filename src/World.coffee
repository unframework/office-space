b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World
b2FixtureDef = require('box2dweb').Dynamics.b2FixtureDef
b2PolygonShape = require('box2dweb').Collision.Shapes.b2PolygonShape
b2BodyDef = require('box2dweb').Dynamics.b2BodyDef
b2Body = require('box2dweb').Dynamics.b2Body

Person = require('./Person.coffee')
Train = require('./Train.coffee')

STEP_TIME = 0.02 # @todo smaller time step to avoid frame skip
SLOW_FRACTION = 1

EDGE_EXTENT = 10
EDGE_MARGIN = 1 # to avoid immediate de-spawn when right next to the edge

# @todo use again later
# createCornerRouter = (flowIsOpposite) ->
#   (physicsBody) ->
#     pos = physicsBody.GetPosition()

#     if pos.x < 0 and pos.y < 0
#       Math.atan2(pos.y, pos.x) + (if flowIsOpposite then -Math.PI / 2 else Math.PI / 2)
#     else if pos.x > pos.y
#       if flowIsOpposite then Math.PI else 0
#     else
#       if flowIsOpposite then Math.PI / 2 else -Math.PI / 2

createSimpleRouter = (flowIsOpposite) ->
  (physicsBody) ->
    if flowIsOpposite then Math.PI else 0

populateOrthoBumpers = (orthoBumperList, physicsWorld) ->
  fixDef = new b2FixtureDef()
  fixDef.density = 200.0
  fixDef.friction = 0.4
  fixDef.restitution = 0.1
  fixDef.shape = new b2PolygonShape()

  bodyDef = new b2BodyDef()
  bodyDef.type = b2Body.b2_staticBody
  bodyDef.position.x = 0
  bodyDef.position.y = 0

  for ortho in orthoBumperList
    w = ortho[2] - ortho[0]
    h = ortho[3] - ortho[1]

    bodyDef.position.x = ortho[0] + w / 2
    bodyDef.position.y = ortho[1] + h / 2

    fixDef.shape.SetAsBox(w / 2, h / 2)

    bumperBody = physicsWorld.CreateBody(bodyDef)
    bumperBody.CreateFixture(fixDef)

# run through steps
class TimeStepper
  constructor: (stepTime, onStep) ->
    lastTimeMs = null
    accumulatorMs = 0
    stepTimeMs = stepTime * 1000

    onRAF = (currentTimeMs) =>
      # update time accumulator, limiting the maximum steps to process
      if lastTimeMs isnt null
        deltaMs = currentTimeMs - lastTimeMs
        accumulatorMs = Math.min(200, accumulatorMs + deltaMs)

      lastTimeMs = currentTimeMs

      # run through the fixed steps
      while accumulatorMs > 0
        accumulatorMs -= stepTimeMs

        onStep()

      # schedule next frame
      @_rafRequestId = requestAnimationFrame onRAF

    # schedule first frame
    @_rafRequestId = requestAnimationFrame onRAF

class World
  constructor: (orthoBumperList) ->
    @_physicsWorld = new b2World(new b2Vec2(0, 0), true)
    @_physicsStepDuration = STEP_TIME * SLOW_FRACTION # @todo instead, divide the value passed into TimeStepper?

    populateOrthoBumpers orthoBumperList, @_physicsWorld

    @_personList = for i in [ 0 ... 80 ]
      @_generatePerson(Math.random() * (EDGE_EXTENT + 0.5) - 0.5)

    @_train = new Train(@_physicsStepDuration, 6, -100, 2.8)

    new TimeStepper(STEP_TIME, () =>
      @_physicsWorld.Step(@_physicsStepDuration, 10, 10)

      person.onPhysicsStep() for person in @_personList
      @_train.onPhysicsStep()

      toRemove = (person for person in @_personList when person._mainBody.GetPosition().x > EDGE_EXTENT + EDGE_MARGIN or person._mainBody.GetPosition().x < -(EDGE_EXTENT + EDGE_MARGIN))

      for person in toRemove
        @_personList.splice @_personList.indexOf(person), 1
        person.disconnectPhysics()

        @_personList.push @_generatePerson(EDGE_EXTENT)
    )

  _generatePerson: (setback)->
    across = 0.5 + Math.random() * 2

    if Math.random() > 0.5
      new Person(@_physicsStepDuration, @_physicsWorld, -setback, -across, createSimpleRouter(Math.random() > 0.5))
    else
      new Person(@_physicsStepDuration, @_physicsWorld, setback, -across, createSimpleRouter(Math.random() > 0.5))

module.exports = World
