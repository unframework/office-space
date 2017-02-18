b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World

Person = require('./Person.coffee')

STEP_TIME = 0.04
SLOW_FRACTION = 1

EDGE_EXTENT = 6
EDGE_MARGIN = 1 # to avoid immediate de-spawn when right next to the edge

class World
  constructor: ->
    @_physicsWorld = new b2World(new b2Vec2(0, 0), true)
    @_physicsStepDuration = STEP_TIME * SLOW_FRACTION

    @_personList = for i in [ 0 ... 50 ]
      @_generatePerson(Math.random() * (EDGE_EXTENT + 0.5) - 0.5)

    setInterval =>
      @_physicsWorld.Step(@_physicsStepDuration, 10, 10)

      person.onPhysicsStep() for person in @_personList

      toRemove = (person for person in @_personList when person._mainBody.GetPosition().x > EDGE_EXTENT + EDGE_MARGIN or person._mainBody.GetPosition().y > EDGE_EXTENT + EDGE_MARGIN)

      for person in toRemove
        @_personList.splice @_personList.indexOf(person), 1
        person.disconnectPhysics()

        @_personList.push @_generatePerson(EDGE_EXTENT)
    , Math.ceil(STEP_TIME * 1000)

  _generatePerson: (setback)->
    across = Math.random() * 1.5

    if Math.random() > 0.5
      new Person(@_physicsStepDuration, @_physicsWorld, -across, setback)
    else
      new Person(@_physicsStepDuration, @_physicsWorld, setback, -across)

module.exports = World
