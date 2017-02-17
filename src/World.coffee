b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World

Person = require('./Person.coffee')

STEP_TIME = 0.04
SLOW_FRACTION = 1

class World
  constructor: ->
    physicsWorld = new b2World(new b2Vec2(0, 0), true)
    physicsStepDuration = STEP_TIME * SLOW_FRACTION

    @_personList = for i in [ 0 ... 2 ]
      new Person(physicsStepDuration, physicsWorld, Math.random() * 5 - 2.5, Math.random() * 5 - 2.5)

    setInterval =>
      physicsWorld.Step(physicsStepDuration, 10, 10)

      person.onPhysicsStep() for person in @_personList
    , Math.ceil(STEP_TIME * 1000)

module.exports = World
