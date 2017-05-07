color = require('onecolor')
CSG = require('csg')

MIN_PANEL_WIDTH = 1.2
MAX_PANEL_WIDTH = 3

randomAmount = (min, max, resolution) ->
  min + Math.round(Math.random() * (max - min) / resolution) * resolution

paint = (shape, polyColor) ->
  rgb = polyColor.rgb() # pre-optimize

  for poly in shape.toPolygons()
    poly.shared = { color: rgb }

subtractAll = (shape, otherShapeList) ->
  otherShapeList.reduce (sh, osh) ->
    sh.subtract osh
  , shape

class Building
  constructor: (leftX, rightX, frontY) ->
    width = rightX - leftX
    depth = 8

    buildingColor = new color.HSL(0.05 + Math.random() * 0.6, 0.6 + Math.random() * 0.2, 0.15 + Math.random() * 0.1)
    windowColor = buildingColor.saturation(-0.3, true).lightness(-0.05, true)

    floorHeight = randomAmount(2, 2.5, 0.1)
    floorCount = randomAmount(3, 6, 1)
    height = floorHeight * floorCount

    minPanelCount = Math.ceil(width / MAX_PANEL_WIDTH)
    maxPanelCount = Math.floor(width / MIN_PANEL_WIDTH)
    panelCount = minPanelCount + Math.floor(Math.random() * (1 + maxPanelCount - minPanelCount))
    panelWidth = width / panelCount

    windowSillHeight = randomAmount(0.4, 0.6, 0.02)
    windowTopHeight = floorHeight - randomAmount(0.05, 0.3, 0.02)
    windowHeight = windowTopHeight - windowSillHeight
    windowSideOffset = randomAmount(0.02, 0.2, 0.02)
    windowDepth = windowSideOffset / 2

    coreShape = CSG.cube(
      center: [ leftX + width / 2, frontY + depth / 2, height / 2 ]
      radius: [ width / 2, depth / 2, height / 2 ]
    )

    paint coreShape, buildingColor

    windowBoxList = [].concat.apply [], (for floorIndex in [ 0...floorCount ]
      for panelIndex in [ 0...panelCount ]
        panelBottom = floorIndex * floorHeight
        panelLeftX = leftX + panelIndex * panelWidth
        windowBox = CSG.cube(
          center: [ panelLeftX + panelWidth / 2, frontY + windowDepth / 2, panelBottom + windowSillHeight + windowHeight / 2 ]
          radius: [ panelWidth / 2 - windowSideOffset, windowDepth / 2, windowHeight / 2 ]
        )

        paint windowBox, windowColor

        windowBox
    )

    # console.log windowBoxList

    @_csg = subtractAll(
      coreShape,
      windowBoxList
    )

module.exports = Building
