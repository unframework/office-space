b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2FixtureDef = require('box2dweb').Dynamics.b2FixtureDef
b2CircleShape = require('box2dweb').Collision.Shapes.b2CircleShape
b2BodyDef = require('box2dweb').Dynamics.b2BodyDef
b2Body = require('box2dweb').Dynamics.b2Body

WalkCycleTracker = require('./WalkCycleTracker.coffee')

class Person
  constructor: (physicsStepDuration, physicsWorld, x, y, @_debug) ->
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

    @_mainBody = physicsWorld.CreateBody(bodyDef)
    @_mainBody.CreateFixture(fixDef)
    @_mainBody.SetLinearDamping(1.2)
    @_mainBody.SetAngularDamping(1.8)

    @_walkTracker = new WalkCycleTracker(physicsStepDuration, @_mainBody)

    if @_debug
      # @_mainBody.ApplyImpulse new b2Vec2(0, 200), new b2Vec2(x, y)
      @_mainBody.ApplyImpulse new b2Vec2(Math.cos(bodyDef.angle) * 200, Math.sin(bodyDef.angle) * 200), new b2Vec2(x, y)

  onPhysicsStep: ->
    @_walkTracker.onPhysicsStep()

module.exports = Person
