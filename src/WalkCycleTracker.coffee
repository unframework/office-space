vec2 = require('gl-matrix').vec2
vec3 = require('gl-matrix').vec3

# @todo in general, fasten the cycle when strides need to be longer?
# @todo "drunk mode"? just add random variations
class WalkCycleTracker
  constructor: (@_physicsStepDuration, @_physicsBody, @_footOffsetDistance) ->
    @_physicsBodyPos = @_physicsBody.GetPosition()

    @_walkPos = vec2.fromValues(@_physicsBodyPos.x, @_physicsBodyPos.y)
    @_walkCycleTime = 0
    @_walkFootLStartPos = vec2.create() # last grounded nominal foot position
    @_walkFootRStartPos = vec2.create()
    @_walkFootLLiftPos = vec2.create() # foot position during lift
    @_walkFootRLiftPos = vec2.create()

    @_footLocalOffset = vec2.create()
    @_movingFootCurrentPos = vec2.create() # computation helper for current nominal foot position
    @_movingFootEndPos = vec2.create() # computation helper for finishing foot position (also helps visual debugging)

    @footLMeshOffset = vec3.create() # displayed foot offset in 3D space
    @footRMeshOffset = vec3.create()

    vec2.set @_footLocalOffset, -Math.sin(@_physicsBody.GetAngle()), Math.cos(@_physicsBody.GetAngle())
    vec2.scaleAndAdd @_walkFootLStartPos, @_walkPos, @_footLocalOffset, @_footOffsetDistance
    vec2.scaleAndAdd @_walkFootRStartPos, @_walkPos, @_footLocalOffset, -@_footOffsetDistance
    vec2.copy @_walkFootLLiftPos, @_walkFootLStartPos
    vec2.copy @_walkFootRLiftPos, @_walkFootRStartPos

  # the time step is expected to be fixed, for smoother animation
  onPhysicsStep: ->
    vec2.set @_walkPos, @_physicsBodyPos.x, @_physicsBodyPos.y

    FOOT_CYCLE_TIME = 0.5
    FOOT_SUPPORT_PHASE = 0.25 # 0 .. 1, good values are between 0.25 and 0.5 (higher means more foot lag)

    @_walkCycleTime += @_physicsStepDuration

    phase = @_walkCycleTime / FOOT_CYCLE_TIME
    phaseFmod = Math.floor phase
    phase -= phaseFmod # fmod 1

    @_walkCycleTime -= FOOT_CYCLE_TIME * phaseFmod # should not accumulate errors easily

    leftFootIsLifted = phase < 0.5
    leftFootSign = (if leftFootIsLifted then 1 else -1)
    footAlong = 0.5 * (1 - leftFootSign * Math.cos(phase * 2 * Math.PI))
    footAnim = (1 - footAlong) * (1 - footAlong) # non-linear foot snap

    [ movingFootStartPos, movingFootLiftPos, movingFootOffset ] = if leftFootIsLifted then [ @_walkFootLStartPos, @_walkFootLLiftPos, @footLMeshOffset ] else [ @_walkFootRStartPos, @_walkFootRLiftPos, @footRMeshOffset ]
    [ stuckFootStartPos, stuckFootLiftPos, stuckFootOffset ] = if leftFootIsLifted then [ @_walkFootRStartPos, @_walkFootRLiftPos, @footRMeshOffset ] else [ @_walkFootLStartPos, @_walkFootLLiftPos, @footLMeshOffset ]

    movingFootTimeInAir = FOOT_CYCLE_TIME * (if leftFootIsLifted then phase else phase - 0.5)

    vec2.set @_footLocalOffset, -Math.sin(@_physicsBody.GetAngle()), Math.cos(@_physicsBody.GetAngle())
    vec2.scale @_footLocalOffset, @_footLocalOffset, @_footOffsetDistance * leftFootSign

    vec2.add @_movingFootCurrentPos, @_walkPos, @_footLocalOffset

    # extrapolate position of foot that we want to end up with
    # when lift starts, we have a half-cycle's worth of time to move this foot while leaning on the stuck one
    # we assume this foot was in nominal spot at mid-point of preceding half-cycle (as body support), so the current nominal spot
    # is then at ~quarter-cycle-length past the foot position when we start lifting this foot
    # this lets us infer our body movement speed (i.e. that of the nominal foot position)
    # -> Vnom = (Pnomstart - Pstart) / quarterCycleTime
    # however, our nominal foot position keeps moving as time elapses, so we compensate for that
    # -> Pnom = Pnomstart + Vnom * elapsedCycleTime
    # -> Pnomstart = Pnom - Vnom * elapsedCycleTime
    # -> Vnom = (Pnom - Vnom * elapsedCycleTime - Pstart) / quarterCycleTime
    # -> Vnom = (Pnom - Pstart) / quarterCycleTime - Vnom * elapsedCycleTime / quarterCycleTime
    # -> Vnom * (1 + elapsedCycleTime / quarterCycleTime) = (Pnom - Pstart) / quarterCycleTime
    # -> Vnom = (Pnom - Pstart) / (quarterCycleTime + elapsedCycleTime)
    # we need to place the foot to be our support at the spot where nominal foot position is in the middle of next half-cycle
    # but also we need to anticipate further movement of the body, so we put the foot far enough to act as support for the *next* half-cycle too
    # nominal foot position at end of this lifting half-cycle is:
    # -> Pnomend = Pnomstart + halfCycleTime * Vnom = Pnom - elapsedCycleTime * Vnom + halfCycleTime * Vnom
    # nominal foot position at middle of next half-cycle (and hence actual foot position at end of lift) is:
    # -> Pend = Pnomend + quarterCycleTime * Vnom = Pnom + (halfCycleTime - elapsedCycleTime + quarterCycleTime) * Vnom
    # -> Pend = Pnom + (halfCycleTime - elapsedCycleTime + quarterCycleTime) * (Pnom - Pstart) / (quarterCycleTime + elapsedCycleTime)
    # -> Pend = Pnom + (Pstart - Pnom) * -(halfCycleTime - elapsedCycleTime + quarterCycleTime) / (quarterCycleTime + elapsedCycleTime)
    # -> Pend = lerp(Pnom, Pstart, -(halfCycleTime - elapsedCycleTime + quarterCycleTime) / (quarterCycleTime + elapsedCycleTime))
    # of note: tried using a (halfCycle - elapsed) / (halfCycle + elapsed) coeff instead - also works, but the cycle is then shifted (feet lag behind a bit)
    # @todo lateral foot deviation does not dampen well (keeps wobbling side-to-side)
    vec2.lerp @_movingFootEndPos, @_movingFootCurrentPos, movingFootStartPos, -((1 - FOOT_SUPPORT_PHASE) * FOOT_CYCLE_TIME - movingFootTimeInAir) / (FOOT_SUPPORT_PHASE * FOOT_CYCLE_TIME + movingFootTimeInAir)

    # animate actual foot position towards the target spot
    vec2.lerp movingFootLiftPos, movingFootStartPos, @_movingFootEndPos, 1 - footAnim

    maxLift = Math.min 0.1, (0.3 * vec2.distance movingFootLiftPos, movingFootStartPos)
    vec3.set movingFootOffset, movingFootLiftPos[0] - @_footLocalOffset[0], movingFootLiftPos[1] - @_footLocalOffset[1], maxLift * footAnim

    # preserve stuck foot reference position and reset displayed foot to ground level
    vec2.copy stuckFootStartPos, stuckFootLiftPos
    vec3.set stuckFootOffset, stuckFootStartPos[0] + @_footLocalOffset[0], stuckFootStartPos[1] + @_footLocalOffset[1], 0

module.exports = WalkCycleTracker
