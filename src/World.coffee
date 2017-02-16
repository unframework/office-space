b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World

Person = require('./Person.coffee')

class World
  constructor: ->
    physicsWorld = new b2World(new b2Vec2(0, 0), true)
    physicsStepDuration = 0.04

    @_personList = [
      new Person(physicsStepDuration, physicsWorld, 0, -0.2, true)
      new Person(physicsStepDuration, physicsWorld, -0.5, 0.5)
      new Person(physicsStepDuration, physicsWorld, 0.4, 0.1)
    ]

    setInterval =>
      physicsWorld.Step(physicsStepDuration, 10, 10)

      person.onPhysicsStep() for person in @_personList
    , Math.ceil(physicsStepDuration * 1000)

module.exports = World
