b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World

Person = require('./Person.coffee')

STEP_TIME = 0.04
SLOW_FRACTION = 1

RUN_EXTENT = 8

class World
  constructor: ->
    physicsWorld = new b2World(new b2Vec2(0, 0), true)
    physicsStepDuration = STEP_TIME * SLOW_FRACTION

    @_personList = for i in [ 0 ... 50 ]
      new Person(physicsStepDuration, physicsWorld, RUN_EXTENT * (Math.random() * 2 - 1), Math.random() * 5 - 2.5)

    setInterval =>
      physicsWorld.Step(physicsStepDuration, 10, 10)

      person.onPhysicsStep() for person in @_personList

      toRemove = (person for person in @_personList when Math.abs(person._mainBody.GetPosition().x) > RUN_EXTENT)

      for person in toRemove
        @_personList.splice @_personList.indexOf(person), 1
        person.disconnectPhysics()

        @_personList.push new Person(physicsStepDuration, physicsWorld, Math.sign(Math.random() - 0.5) * RUN_EXTENT, Math.random() * 5 - 2.5)
    , Math.ceil(STEP_TIME * 1000)

module.exports = World
