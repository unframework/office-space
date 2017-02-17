b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2Math = require('box2dweb').Common.Math.b2Math
b2FixtureDef = require('box2dweb').Dynamics.b2FixtureDef
b2CircleShape = require('box2dweb').Collision.Shapes.b2CircleShape
b2BodyDef = require('box2dweb').Dynamics.b2BodyDef
b2Body = require('box2dweb').Dynamics.b2Body

color = require('onecolor')

WalkCycleTracker = require('./WalkCycleTracker.coffee')

class Person
  constructor: (physicsStepDuration, physicsWorld, x, y, @_debug) ->
    @_color = new color.HSL(Math.random(), 0.8, 0.8).rgb()
    @_color2 = @_color.hue(0.08, true).lightness(0.7)

    fixDef = new b2FixtureDef()
    fixDef.density = 200.0
    fixDef.friction = 0.4
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

    @_walkTarget = new b2Vec2(Math.random() * 5 - 2.5, Math.random() * 5 - 2.5)
    @_orientationAngle = bodyDef.angle
    @_walkImpulse = new b2Vec2(0, 0)

    # if @_debug
      # @_mainBody.ApplyImpulse new b2Vec2(0, 200), new b2Vec2(x, y)
      # @_mainBody.ApplyImpulse new b2Vec2(Math.cos(bodyDef.angle) * 200, Math.sin(bodyDef.angle) * 200), new b2Vec2(x, y)

  onPhysicsStep: ->
    @_walkTracker.onPhysicsStep()

    # update our targeted walking
    @_walkImpulse.SetV @_walkTarget
    @_walkImpulse.Subtract @_mainBody.GetPosition()

    dist = @_walkImpulse.Length()

    # update direction we face when far enough from target
    if dist > 0.2
        @_orientationAngle = Math.atan2(@_walkImpulse.y, @_walkImpulse.x)

    if dist > 0.1
        vel = b2Math.Dot(@_mainBody.GetLinearVelocity(), @_walkImpulse) / dist
        max = Math.min(1, dist / 0.4) * 0.7
        diff = b2Math.Clamp(max - vel, -0.3, 0.3)

        @_walkImpulse.Multiply @_mainBody.GetMass() * diff / dist
    else
        # simply damp any velocity
        @_walkImpulse.SetV @_mainBody.GetLinearVelocity()
        @_walkImpulse.Multiply @_mainBody.GetMass() * -0.8

    @_mainBody.ApplyImpulse @_walkImpulse, @_mainBody.GetPosition()

    # face the direction we want
    angleDiff = @_orientationAngle - @_mainBody.GetAngle()
    angleDiff -= 2 * Math.PI * Math.round angleDiff / (Math.PI * 2) # normalize to -pi..pi

    angVel = @_mainBody.GetAngularVelocity()
    targetAngVel = Math.sign(angleDiff) * 4 * Math.min 1, Math.abs(angleDiff) / 0.7
    @_mainBody.SetAngularVelocity angVel + b2Math.Clamp(targetAngVel - angVel, -0.8, 0.8)

module.exports = Person
