vec2 = require('gl-matrix').vec2
vec3 = require('gl-matrix').vec3

# @todo in general, fasten the cycle when strides need to be longer?
class WalkCycleTracker
  constructor: (@_physicsStepDuration, @_physicsBody, @_footOffsetDistance) ->
    @_physicsBodyPos = @_physicsBody.GetPosition()

    @_walkPos = vec2.fromValues(@_physicsBodyPos.x, @_physicsBodyPos.y)
    @_walkCycleTime = 0
    @_walkFootLPos = vec2.create() # last grounded nominal foot position
    @_walkFootRPos = vec2.create()
    @_walkFootLNextPos = vec2.create() # expected next nominal foot position
    @_walkFootRNextPos = vec2.create()
    @_footLocalOffset = vec2.create()
    @_movingFootCurrentPos = vec2.create() # computation helper for current nominal foot position

    @footLMeshOffset = vec3.create() # displayed foot offset in 3D space
    @footRMeshOffset = vec3.create()

    vec2.set @_footLocalOffset, -Math.sin(@_physicsBody.GetAngle()), Math.cos(@_physicsBody.GetAngle())
    vec2.scaleAndAdd @_walkFootLPos, @_walkPos, @_footLocalOffset, @_footOffsetDistance
    vec2.scaleAndAdd @_walkFootRPos, @_walkPos, @_footLocalOffset, -@_footOffsetDistance
    vec2.copy @_walkFootLNextPos, @_walkFootLPos
    vec2.copy @_walkFootRNextPos, @_walkFootRPos

  # the time step is expected to be fixed, for smoother animation
  onPhysicsStep: ->
    vec2.set @_walkPos, @_physicsBodyPos.x, @_physicsBodyPos.y

    FOOT_CYCLE_TIME = 0.5

    @_walkCycleTime += @_physicsStepDuration

    phase = @_walkCycleTime / FOOT_CYCLE_TIME
    phaseFmod = Math.floor phase
    phase -= phaseFmod # fmod 1

    @_walkCycleTime -= FOOT_CYCLE_TIME * phaseFmod # should not accumulate errors easily

    leftFootIsLifted = phase < 0.5
    leftFootSign = (if leftFootIsLifted then 1 else -1)
    footAlong = 0.5 * (1 - leftFootSign * Math.cos(phase * 2 * Math.PI))
    footAnim = (1 - footAlong) * (1 - footAlong) # non-linear foot snap

    [ movingFootRefPos, movingFootNextPos, movingFootOffset ] = if leftFootIsLifted then [ @_walkFootLPos, @_walkFootLNextPos, @footLMeshOffset ] else [ @_walkFootRPos, @_walkFootRNextPos, @footRMeshOffset ]
    [ stuckFootPos, stuckFootNextPos, stuckFootOffset ] = if leftFootIsLifted then [ @_walkFootRPos, @_walkFootRNextPos, @footRMeshOffset ] else [ @_walkFootLPos, @_walkFootLNextPos, @footLMeshOffset ]

    movingFootTimeInAir = FOOT_CYCLE_TIME * (if leftFootIsLifted then phase else phase - 0.5)

    vec2.set @_footLocalOffset, -Math.sin(@_physicsBody.GetAngle()), Math.cos(@_physicsBody.GetAngle())
    vec2.scale @_footLocalOffset, @_footLocalOffset, @_footOffsetDistance * leftFootSign

    vec2.add @_movingFootCurrentPos, @_walkPos, @_footLocalOffset

    # extrapolate position of foot during next quarter-cycle (i.e. mid-way through next foot's lift)
    # @todo lateral foot deviation does not dampen well (keeps wobbling side-to-side)
    vec2.lerp movingFootNextPos, @_movingFootCurrentPos, movingFootRefPos, movingFootTimeInAir and -0.25 * FOOT_CYCLE_TIME / movingFootTimeInAir
    vec2.lerp movingFootNextPos, movingFootRefPos, movingFootNextPos, 1 - footAnim

    maxLift = Math.min 0.1, (0.3 * vec2.distance movingFootNextPos, movingFootRefPos)

    vec3.set movingFootOffset, movingFootNextPos[0] - @_footLocalOffset[0], movingFootNextPos[1] - @_footLocalOffset[1], maxLift * footAnim

    # preserve stuck foot reference position and reset displayed foot to ground level
    vec2.copy stuckFootPos, stuckFootNextPos
    vec3.set stuckFootOffset, stuckFootNextPos[0] + @_footLocalOffset[0], stuckFootNextPos[1] + @_footLocalOffset[1], 0

module.exports = WalkCycleTracker
