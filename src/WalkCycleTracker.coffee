vec2 = require('gl-matrix').vec2
vec3 = require('gl-matrix').vec3

# @todo in general, fasten the cycle when strides need to be longer?
# @todo "drunk mode"? just add random variations
class WalkCycleTracker
  constructor: (@_physicsStepDuration, @_physicsBody, @_footOffsetDistance, @_strideDuration, @_footLift) ->
    @_physicsBodyPos = @_physicsBody.GetPosition()

    @_walkPos = vec2.fromValues(@_physicsBodyPos.x, @_physicsBodyPos.y)
    @_strideTime = 0
    @_walkFootLStartPos = vec2.create() # last grounded nominal foot position
    @_walkFootRStartPos = vec2.create()
    @_walkFootLLiftPos = vec2.create() # foot position during lift
    @_walkFootRLiftPos = vec2.create()
    @_leftFootIsMoving = true

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

    vec3.set @footLMeshOffset, @_walkPos[0], @_walkPos[1], 0
    vec3.set @footRMeshOffset, @_walkPos[0], @_walkPos[1], 0

  # the time step is expected to be fixed, for smoother animation
  onPhysicsStep: ->
    vec2.set @_walkPos, @_physicsBodyPos.x, @_physicsBodyPos.y

    STRIDE_FOOT_SUPPORT_FRACTION = 0.75 # 0 .. 1, good values are between 0.5 and 1 (higher means more foot lag)

    @_strideTime += @_physicsStepDuration
    strideOverflow = Math.floor @_strideTime / @_strideDuration
    @_strideTime -= strideOverflow * @_strideDuration # should not accumulate errors easily

    # flip the moving foot if finished last stride
    if strideOverflow > 0
      @_leftFootIsMoving = not @_leftFootIsMoving

    phase = @_strideTime / @_strideDuration
    footAlong = 0.5 * (1 - Math.cos(Math.PI * phase))
    footAnim = (1 - footAlong) * (1 - footAlong) # non-linear foot snap

    [ movingFootStartPos, movingFootLiftPos, movingFootOffset ] = if @_leftFootIsMoving then [ @_walkFootLStartPos, @_walkFootLLiftPos, @footLMeshOffset ] else [ @_walkFootRStartPos, @_walkFootRLiftPos, @footRMeshOffset ]
    [ stuckFootStartPos, stuckFootLiftPos, stuckFootOffset ] = if @_leftFootIsMoving then [ @_walkFootRStartPos, @_walkFootRLiftPos, @footRMeshOffset ] else [ @_walkFootLStartPos, @_walkFootLLiftPos, @footLMeshOffset ]

    vec2.set @_footLocalOffset, -Math.sin(@_physicsBody.GetAngle()), Math.cos(@_physicsBody.GetAngle())
    vec2.scale @_footLocalOffset, @_footLocalOffset, @_footOffsetDistance * (if @_leftFootIsMoving then 1 else -1)

    vec2.add @_movingFootCurrentPos, @_walkPos, @_footLocalOffset

    # extrapolate position of foot that we want to end up with
    # when lift starts, we have a stride's worth of time to move this foot while leaning on the stuck one
    # we assume this foot was in nominal spot at mid-point of preceding stride (as body support), so the current nominal spot
    # is then at ~half-stride-length past the foot position when we start lifting this foot
    # this lets us infer our body movement speed (i.e. that of the nominal foot position)
    # -> Vnom = (Pnomstart - Pstart) / halfStrideDur
    # however, our nominal foot position keeps moving as time elapses, so we compensate for that
    # -> Pnom = Pnomstart + Vnom * elapsedCycleTime
    # -> Pnomstart = Pnom - Vnom * elapsedCycleTime
    # -> Vnom = (Pnom - Vnom * elapsedCycleTime - Pstart) / halfStrideDur
    # -> Vnom = (Pnom - Pstart) / halfStrideDur - Vnom * elapsedCycleTime / halfStrideDur
    # -> Vnom * (1 + elapsedCycleTime / halfStrideDur) = (Pnom - Pstart) / halfStrideDur
    # -> Vnom = (Pnom - Pstart) / (halfStrideDur + elapsedCycleTime)
    # we need to place the foot to be our support at the spot where nominal foot position is in the middle of next stride
    # nominal foot position at end of this stride is:
    # -> Pnomend = Pnomstart + strideDur * Vnom = Pnom - elapsedCycleTime * Vnom + strideDur * Vnom
    # nominal foot position at middle of next stride (and hence actual foot position at end of lift) is:
    # -> Pend = Pnomend + halfStrideDur * Vnom = Pnom + (strideDur - elapsedCycleTime + halfStrideDur) * Vnom
    # -> Pend = Pnom + (strideDur - elapsedCycleTime + halfStrideDur) * (Pnom - Pstart) / (halfStrideDur + elapsedCycleTime)
    # -> Pend = Pnom + (Pstart - Pnom) * -(strideDur - elapsedCycleTime + halfStrideDur) / (halfStrideDur + elapsedCycleTime)
    # -> Pend = lerp(Pnom, Pstart, -(strideDur - elapsedCycleTime + halfStrideDur) / (halfStrideDur + elapsedCycleTime))
    # @todo lateral foot deviation does not dampen well (keeps wobbling side-to-side)
    remainingStrideTime = @_strideDuration - @_strideTime
    vec2.lerp @_movingFootEndPos, @_movingFootCurrentPos, movingFootStartPos, -(remainingStrideTime + (1 - STRIDE_FOOT_SUPPORT_FRACTION) * @_strideDuration) / (STRIDE_FOOT_SUPPORT_FRACTION * @_strideDuration + @_strideTime)

    # animate actual foot position towards the target spot
    vec2.lerp movingFootLiftPos, movingFootStartPos, @_movingFootEndPos, 1 - footAnim

    vec3.set movingFootOffset, movingFootLiftPos[0] - @_footLocalOffset[0], movingFootLiftPos[1] - @_footLocalOffset[1], phase * footAnim * 2 * @_footLift

    # preserve stuck foot reference position and reset displayed foot to ground level
    vec2.copy stuckFootStartPos, stuckFootLiftPos
    vec3.set stuckFootOffset, stuckFootStartPos[0] + @_footLocalOffset[0], stuckFootStartPos[1] + @_footLocalOffset[1], 0

module.exports = WalkCycleTracker
