vec2 = require('gl-matrix').vec2
vec3 = require('gl-matrix').vec3

class WalkCycleTracker
  constructor: (physicsBody) ->
    @_physicsBody = physicsBody
    @_physicsBodyPos = physicsBody.GetPosition()

    @_walkPos = vec2.fromValues(@_physicsBodyPos.x, @_physicsBodyPos.y)
    @_walkPhase = 0
    @_walkFootLPos = vec2.create() # last grounded nominal foot position
    @_walkFootRPos = vec2.create()
    @_walkFootLNextPos = vec2.create() # expected next nominal foot position
    @_walkFootRNextPos = vec2.create()
    @_footLocalOffset = vec2.create()
    @_movingFootCurrentPos = vec2.create() # computation helper for current nominal foot position

    @footLMeshOffset = vec3.create() # displayed foot offset in 3D space
    @footRMeshOffset = vec3.create()

    vec2.set @_footLocalOffset, -Math.sin(@_physicsBody.GetAngle()), Math.cos(@_physicsBody.GetAngle())
    vec2.scaleAndAdd @_walkFootLPos, @_walkPos, @_footLocalOffset, 0.4
    vec2.scaleAndAdd @_walkFootRPos, @_walkPos, @_footLocalOffset, -0.4
    vec2.copy @_walkFootLNextPos, @_walkFootLPos
    vec2.copy @_walkFootRNextPos, @_walkFootRPos

  update: (deltaTime) ->
    vec2.set @_walkPos, @_physicsBodyPos.x, @_physicsBodyPos.y

    FOOT_CYCLE_TIME = 0.5

    @_walkPhase += deltaTime / FOOT_CYCLE_TIME # @todo this accumulates error; significant? should be part of physics, right?
    @_walkPhase -= Math.floor @_walkPhase # fmod 1

    leftFootIsLifted = @_walkPhase < 0.5
    footPhaseAngle = @_walkPhase * 2 * Math.PI
    footLift = Math.sin footPhaseAngle
    footAlong = 0.5 * (1 - (if leftFootIsLifted then 1 else -1) * Math.cos(footPhaseAngle))
    footAnim = (1 - footAlong) * (1 - footAlong) # non-linear foot snap

    [ movingFootRefPos, movingFootNextPos, movingFootOffset ] = if leftFootIsLifted then [ @_walkFootLPos, @_walkFootLNextPos, @footLMeshOffset ] else [ @_walkFootRPos, @_walkFootRNextPos, @footRMeshOffset ]
    [ stuckFootPos, stuckFootNextPos, stuckFootOffset ] = if leftFootIsLifted then [ @_walkFootRPos, @_walkFootRNextPos, @footRMeshOffset ] else [ @_walkFootLPos, @_walkFootLNextPos, @footLMeshOffset ]

    movingFootTimeInAir = FOOT_CYCLE_TIME * (if leftFootIsLifted then @_walkPhase else @_walkPhase - 0.5)

    vec2.set @_footLocalOffset, -Math.sin(@_physicsBody.GetAngle()), Math.cos(@_physicsBody.GetAngle())
    if leftFootIsLifted
      vec2.scale @_footLocalOffset, @_footLocalOffset, 0.4
    else
      vec2.scale @_footLocalOffset, @_footLocalOffset, -0.4

    vec2.add @_movingFootCurrentPos, @_walkPos, @_footLocalOffset

    # extrapolate next position of foot, while damping a bit
    vec2.lerp movingFootNextPos, movingFootRefPos, @_movingFootCurrentPos, movingFootTimeInAir and 0.6 * FOOT_CYCLE_TIME / movingFootTimeInAir
    vec2.lerp movingFootNextPos, movingFootRefPos, movingFootNextPos, 1 - footAnim

    maxLift = Math.min 0.1, (0.3 * vec2.distance movingFootNextPos, movingFootRefPos)

    vec3.set movingFootOffset, movingFootNextPos[0] - @_footLocalOffset[0], movingFootNextPos[1] - @_footLocalOffset[1], maxLift * footAnim

    # preserve stuck foot reference position and reset displayed foot to ground level
    vec2.copy stuckFootPos, stuckFootNextPos
    vec3.set stuckFootOffset, stuckFootNextPos[0] + @_footLocalOffset[0], stuckFootNextPos[1] + @_footLocalOffset[1], 0

module.exports = WalkCycleTracker
