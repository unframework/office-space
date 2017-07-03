b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2World = require('box2dweb').Dynamics.b2World
b2FixtureDef = require('box2dweb').Dynamics.b2FixtureDef
b2PolygonShape = require('box2dweb').Collision.Shapes.b2PolygonShape
b2BodyDef = require('box2dweb').Dynamics.b2BodyDef
b2Body = require('box2dweb').Dynamics.b2Body

Howl = require('howler').Howl

Readable = require('stream').Readable

TimeStepper = require('./TimeStepper.coffee')
Bridge = require('./Bridge.coffee')
Building = require('./Building.coffee')
Person = require('./Person.coffee')

STEP_TIME = 0.02 # @todo smaller time step to avoid frame skip
SLOW_FRACTION = 1

EDGE_EXTENT = 16
EDGE_MARGIN = 1 # to avoid immediate de-spawn when right next to the edge

# looping city sound
cityLoopHowl = new Howl({
  src: ['./src/city-loop.wav']
})

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

  bumperBody = physicsWorld.CreateBody(bodyDef)

  for ortho in orthoBumperList
    w = ortho[2] - ortho[0]
    h = ortho[3] - ortho[1]

    pos = new b2Vec2(ortho[0] + w / 2, ortho[1] + h / 2)
    fixDef.shape.SetAsOrientedBox(w / 2, h / 2, pos, 0)

    bumperBody.CreateFixture(fixDef)

  bumperBody

WALKWAY_MARGIN = 0.2
orthoBumperList = [
  [ -EDGE_EXTENT, -WALKWAY_MARGIN, EDGE_EXTENT, 1 + WALKWAY_MARGIN ]
  [ -EDGE_EXTENT, -4, EDGE_EXTENT, -3 + WALKWAY_MARGIN ]
]

class World
  constructor: () ->
    # ambient base loop
    @_cityLoopSound = cityLoopHowl.play()
    cityLoopHowl.loop true, @_cityLoopSound

    @_focusX = 0

    @buildings = new Readable({ objectMode: true, read: () => {} })
    @buildingsOut = new Readable({ objectMode: true, read: () => {} })
    @bridges = new Readable({ objectMode: true, read: () => {} })
    @bridgesOut = new Readable({ objectMode: true, read: () => {} })

    @_physicsWorld = new b2World(new b2Vec2(0, 0), true)
    @_physicsStepDuration = STEP_TIME * SLOW_FRACTION # @todo instead, divide the value passed into TimeStepper?

    @_bumperBody = populateOrthoBumpers orthoBumperList, @_physicsWorld
    bumperBodyPos = new b2Vec2() # for dynamic updates

    @_focusedBuildingList = []
    @_nextBuildingX = -EDGE_EXTENT

    @_bridge = null
    @_nextBridgeX = 4

    @_nextTickerX = -8

    @_personList = for i in [ 0 ... 80 ]
      @_generatePerson(Math.random() * (EDGE_EXTENT + 0.5) - 0.5)

    new TimeStepper(STEP_TIME, () =>
      @_focusX += STEP_TIME * 0.12
      focusRightX = @_focusX + EDGE_EXTENT
      focusLeftX = @_focusX - EDGE_EXTENT

      bumperBodyPos.Set @_focusX, 0
      @_bumperBody.SetPosition bumperBodyPos

      # fill up buildings until next bridge
      while @_nextBuildingX < focusRightX and @_nextBuildingX < @_nextBridgeX
        requiresTicker = @_nextBuildingX >= @_nextTickerX
        if requiresTicker
          @_nextTickerX += 14

        building = new Building(@_nextBuildingX, @_nextBuildingX + 4, 0, requiresTicker)

        @_focusedBuildingList.push building
        @buildings.push building

        @_nextBuildingX = building.rightX

      while @_focusedBuildingList[0].rightX < focusLeftX
        @buildingsOut.push @_focusedBuildingList.shift()

      # create next bridge
      if @_nextBridgeX < focusRightX
        if @_bridge
          @bridgesOut.push @_bridge
          @_bridge = null

        @_bridge = new Bridge(@_physicsStepDuration, @_nextBridgeX, @_nextBridgeX + 4, 0.5)
        @bridges.push @_bridge

        @_nextBridgeX = @_bridge.rightX + Math.ceil((EDGE_EXTENT * 2) / 4) * 4

        # next building starts after bridge
        @_nextBuildingX = @_bridge.rightX

      @_physicsWorld.Step(@_physicsStepDuration, 10, 10)

      person.onPhysicsStep() for person in @_personList

      if @_bridge
        @_bridge.onPhysicsStep()

      toRemove = (person for person in @_personList when person._mainBody.GetPosition().x > @_focusX + EDGE_EXTENT or person._mainBody.GetPosition().x < @_focusX - EDGE_EXTENT)

      for person in toRemove
        @_personList.splice @_personList.indexOf(person), 1
        person.disconnectPhysics()

        @_personList.push @_generatePerson(EDGE_EXTENT - EDGE_MARGIN)
    )

  _generatePerson: (setback)->
    across = 0.5 + Math.random() * 2

    if Math.random() > 0.6 # skew probability because folks walking in camera pan direction stay on screen longer
      new Person(@_physicsStepDuration, @_physicsWorld, @_focusX - setback, -across, createSimpleRouter(Math.random() > 0.5))
    else
      new Person(@_physicsStepDuration, @_physicsWorld, @_focusX + setback, -across, createSimpleRouter(Math.random() > 0.5))

module.exports = World
