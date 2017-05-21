
# save reference to RAF API
requestAnimationFrame = window.requestAnimationFrame

# run through steps
class TimeStepper
  constructor: (stepTime, onStep) ->
    lastTimeMs = null
    accumulatorMs = 0
    stepTimeMs = stepTime * 1000

    onRAF = (currentTimeMs) =>
      # update time accumulator, limiting the maximum steps to process
      if lastTimeMs isnt null
        deltaMs = currentTimeMs - lastTimeMs
        accumulatorMs = Math.min(200, accumulatorMs + deltaMs)

      lastTimeMs = currentTimeMs

      # run through the fixed steps
      while accumulatorMs > 0
        accumulatorMs -= stepTimeMs

        onStep()

      # schedule next frame
      @_rafRequestId = requestAnimationFrame onRAF

    # schedule first frame
    @_rafRequestId = requestAnimationFrame onRAF

module.exports = TimeStepper
