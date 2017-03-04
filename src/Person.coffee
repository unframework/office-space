b2Vec2 = require('box2dweb').Common.Math.b2Vec2
b2Math = require('box2dweb').Common.Math.b2Math
b2FixtureDef = require('box2dweb').Dynamics.b2FixtureDef
b2CircleShape = require('box2dweb').Collision.Shapes.b2CircleShape
b2BodyDef = require('box2dweb').Dynamics.b2BodyDef
b2Body = require('box2dweb').Dynamics.b2Body

color = require('onecolor')

WalkCycleTracker = require('./WalkCycleTracker.coffee')

FOOT_OFFSET = 0.1

class Person
  constructor: (@_physicsStepDuration, @_physicsWorld, x, y, @_routerCallback) ->
    @_color = new color.HSL(0.9 + Math.random() * 0.6, 0.6 + Math.random() * 0.2, 0.2 + Math.random() * 0.6).rgb()
    @_color2 = @_color.hue(0.08, true).saturation(-0.4, true).lightness(0.1 + Math.random() * 0.1)

    @_nominalSpeed = 0.2 + Math.random() * 0.3

    fixDef = new b2FixtureDef()
    fixDef.density = 200.0
    fixDef.friction = 0.1
    fixDef.restitution = 0.1
    fixDef.shape = new b2CircleShape(0.125)

    bodyDef = new b2BodyDef()
    bodyDef.type = b2Body.b2_dynamicBody
    bodyDef.position.x = x
    bodyDef.position.y = y
    bodyDef.angle = (Math.random() * 2 - 1) * Math.PI

    @_mainBody = @_physicsWorld.CreateBody(bodyDef)
    @_mainBody.CreateFixture(fixDef)
    @_mainBody.SetLinearDamping(1.2)
    @_mainBody.SetAngularDamping(1.8)
    @_mainBody.__person = this

    @_walkTracker = new WalkCycleTracker(@_physicsStepDuration, @_mainBody, FOOT_OFFSET, 0.3 - @_nominalSpeed * 0.1 - Math.random() * 0.1, 0.05 + Math.random() * 0.05)

    @_orientationAngle = bodyDef.angle
    @_leanAngle = 0

    @_blinkTimerEnd = 1
    @_blinkTimer = @_blinkTimerEnd

    @_gazeTimer = 0
    @_gazeOffsetX = 0

    @_avoidanceTimeout = 0
    @_avoidanceGoLeft = false
    @_avoidanceGoRight = false
    @_avoidanceGoSlow = false

    @_tmpWalkTargetDelta = new b2Vec2(0, 0) # computation helper
    @_tmpWalkImpulse = new b2Vec2(0, 0)
    @_tmpWalkDir = new b2Vec2(0, 0)
    @_tmpWalkRayEnd = new b2Vec2(0, 0)

    @_debugTargetAngle = 0

    # if @_debug
      # @_mainBody.ApplyImpulse new b2Vec2(0, 200), new b2Vec2(x, y)
      # @_mainBody.ApplyImpulse new b2Vec2(Math.cos(bodyDef.angle) * 200, Math.sin(bodyDef.angle) * 200), new b2Vec2(x, y)

  onPhysicsStep: ->
    @_walkTracker.onPhysicsStep()

    @_leanAngle = @_leanAngle * 0.95 + 0.05 * Math.atan2 @_walkTracker.footLMeshOffset[2] - @_walkTracker.footRMeshOffset[2], FOOT_OFFSET * 2

    targetAngle = @_routerCallback @_mainBody

    @_blinkTimer += @_physicsStepDuration

    if @_blinkTimer >= @_blinkTimerEnd
      @_blinkTimer = 0
      @_blinkTimerEnd = 0.5 + Math.random() * 2.5

    @_gazeTimer -= @_physicsStepDuration

    if @_gazeTimer <= 0
      @_gazeTimer = 0.25 + Math.random() * 2.0
      @_gazeOffsetX = Math.random() * 2 - 1

    @_avoidanceTimeout -= @_physicsStepDuration

    if @_avoidanceTimeout <= 0
      @_avoidanceTimeout += 0.05 + Math.random() * 0.1

      @_orientationAngle = targetAngle

      # see if we have any close by folks
      @_tmpWalkDir.Set Math.cos(targetAngle), Math.sin(targetAngle)
      @_tmpWalkRayEnd.SetV @_tmpWalkDir
      @_tmpWalkRayEnd.Multiply 0.4
      @_tmpWalkRayEnd.Add @_mainBody.GetPosition()

      @_avoidanceGoLeft = false
      @_avoidanceGoRight = false
      @_avoidanceGoSlow = false
      @_physicsWorld.RayCast(
        (fixture, point, outputNormal, fraction) =>
          person = fixture.GetBody().__person

          if person
            angleDiff = person._mainBody.GetAngle() - @_mainBody.GetAngle()
            angleCross = Math.cos(angleDiff)
            if angleCross < 0.2
              @_avoidanceGoSlow = true

            @_tmpWalkTargetDelta.SetV person._mainBody.GetPosition()
            @_tmpWalkTargetDelta.Subtract @_mainBody.GetPosition()

            cross = b2Math.CrossVV(@_tmpWalkTargetDelta, @_tmpWalkDir)

            # subtle bias to favour moving to the right if facing each other, or
            # left if following the other, to break stalemates
            if cross > -angleCross * 0.05
              @_avoidanceGoLeft = true
            else
              @_avoidanceGoRight = true

          1 # keep querying for other possible objects in the way
        ,
        @_mainBody.GetPosition(),
        @_tmpWalkRayEnd
      )

    avoidanceAngle = if @_avoidanceGoSlow then 1.1 else 0.4
    targetAngle += (if @_avoidanceGoLeft then avoidanceAngle else 0) + (if @_avoidanceGoRight then -avoidanceAngle else 0)

    @_tmpWalkImpulse.Set Math.cos(targetAngle), Math.sin(targetAngle)
    vel = b2Math.Dot(@_mainBody.GetLinearVelocity(), @_tmpWalkImpulse)
    targetVel = if @_avoidanceGoLeft and @_avoidanceGoRight
      -0.2 * @_nominalSpeed # back up if we would possibly get stuck
    else if @_avoidanceGoSlow
      @_nominalSpeed / 2
    else
      @_nominalSpeed

    diff = b2Math.Clamp(targetVel - vel, -0.3, 0.3)

    @_debugTargetAngle = targetAngle

    @_tmpWalkImpulse.Multiply @_mainBody.GetMass() * diff

    @_mainBody.ApplyImpulse @_tmpWalkImpulse, @_mainBody.GetPosition()

    # face the direction we want
    angleDiff = @_orientationAngle - @_mainBody.GetAngle()
    angleDiff -= 2 * Math.PI * Math.round angleDiff / (Math.PI * 2) # normalize to -pi..pi

    angVel = @_mainBody.GetAngularVelocity()
    targetAngVel = Math.sign(angleDiff) * 4 * Math.min 1, Math.abs(angleDiff) / 0.7
    @_mainBody.SetAngularVelocity angVel + b2Math.Clamp(targetAngVel - angVel, -0.8, 0.8)

  disconnectPhysics: ->
    @_physicsWorld.DestroyBody(@_mainBody)
    @_mainBody = null

module.exports = Person
