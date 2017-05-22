color = require('onecolor')
CSG = require('csg')

Train = require('./Train.coffee')

randomAmount = (min, max, resolution) ->
  min + Math.round(Math.random() * (max - min) / resolution) * resolution

paint = (shape, polyColor) ->
  rgb = polyColor.rgb() # pre-optimize

  for poly in shape.toPolygons()
    poly.shared = { color: rgb }

class Bridge
  constructor: (@_physicsStepDuration, leftX, rightX, frontY) ->
    width = rightX - leftX
    depth = 8
    height = 2.8
    coverThickness = 0.4

    footColor = new color.HSL(Math.random() * 0.05, 0.3 + Math.random() * 0.2, 0.1 + Math.random() * 0.1)
    bridgeColor = new color.HSL(0.2 + Math.random() * 0.1, 0.6 + Math.random() * 0.2, 0.3 + Math.random() * 0.1)

    footShape = CSG.cube(
      center: [ leftX + width / 2, frontY + 4 / 2, height / 2 ]
      radius: [ width / 2, 4 / 2, height / 2 ]
    )
    paint footShape, footColor

    coverShape = CSG.cube(
      center: [ leftX + width / 2, frontY, height + coverThickness / 2]
      radius: [ width / 2, 30, coverThickness / 2]
    ).union CSG.cube(
      center: [ leftX + 0.2, frontY, height + coverThickness + 0.6 / 2]
      radius: [ 0.1, 30, 0.6 / 2]
    )
    paint coverShape, bridgeColor

    @leftX = leftX
    @rightX = rightX
    @_csg = footShape.union coverShape

    @_train = new Train(@_physicsStepDuration, leftX + 2, -100, 2.8)

  onPhysicsStep: ->
    @_train.onPhysicsStep()

module.exports = Bridge
