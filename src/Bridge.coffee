color = require('onecolor')
CSG = require('csg')

randomAmount = (min, max, resolution) ->
  min + Math.round(Math.random() * (max - min) / resolution) * resolution

paint = (shape, polyColor) ->
  rgb = polyColor.rgb() # pre-optimize

  for poly in shape.toPolygons()
    poly.shared = { color: rgb }

class Bridge
  constructor: (leftX, rightX, frontY) ->
    width = rightX - leftX
    depth = 8
    height = 5

    footColor = new color.HSL(Math.random() * 0.05, 0.3 + Math.random() * 0.2, 0.1 + Math.random() * 0.1)
    bridgeColor = new color.HSL(0.2 + Math.random() * 0.1, 0.6 + Math.random() * 0.2, 0.2 + Math.random() * 0.1)

    footShape = CSG.cube(
      center: [ 4 + width / 2, frontY + 4 / 2, height / 2 ]
      radius: [ width / 2, 4 / 2, height / 2 ]
    )
    paint footShape, footColor

    coverShape = CSG.cube(
      center: [ 4 + width / 2, frontY, height + 1.2 / 2]
      radius: [ width / 2, 12, 1.2 / 2]
    )
    paint coverShape, bridgeColor

    @_csg = footShape.union coverShape

module.exports = Bridge
