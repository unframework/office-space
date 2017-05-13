color = require('onecolor')
CSG = require('csg')

randomAmount = (min, max, resolution) ->
  min + Math.round(Math.random() * (max - min) / resolution) * resolution

unionAll = (shape, otherShapeList) ->
  otherShapeList.reduce (sh, osh) ->
    sh.union osh
  , shape

paint = (shape, polyColor) ->
  rgb = polyColor.rgb() # pre-optimize

  for poly in shape.toPolygons()
    poly.shared = { color: rgb }

class Train
  constructor: (@_offsetX, @_offsetY, @_offsetZ) ->
    carWidth = 3
    carLength = 16
    carHeight = 3.2
    carBodyOffsetZ = 1 # rail to bottom of the body
    carSpacing = 0.5
    carCount = 4

    carColor = new color.HSL(0.5 + Math.random() * 0.2, 0.3 + Math.random() * 0.2, 0.4 + Math.random() * 0.1)

    @_carCSG = CSG.cube(
        center: [ 0, @_offsetY + carLength / 2, (carHeight - carBodyOffsetZ) / 2 + carBodyOffsetZ ]
        radius: [ carWidth / 2, carLength / 2, (carHeight - carBodyOffsetZ) / 2 ]
      )
    paint @_carCSG, carColor

    @_carOffsetList = for i in [ 0...carCount ]
      i * (carLength + carSpacing)

module.exports = Train
