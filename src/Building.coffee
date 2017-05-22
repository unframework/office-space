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

unionAll = (shape, otherShapeList) ->
  otherShapeList.reduce (sh, osh) ->
    sh.union osh
  , shape

subtractAll = (shape, otherShapeList) ->
  otherShapeList.reduce (sh, osh) ->
    sh.subtract osh
  , shape

# @todo roof (edge lip), balconies, sun-shade protrusions
# @todo awnings, recessed entrance, extra first floor base
# @todo doodads (AC, rooftop gribble, newspaper stands, vending machines)
# @todo ad space, signs
class Building
  constructor: (leftX, rightX, frontY) ->
    width = rightX - leftX
    depth = 8

    buildingColor = new color.HSL(0.05 + Math.random() * 0.6, 0.6 + Math.random() * 0.2, 0.15 + Math.random() * 0.1)
    windowColor = new color.HSL(0.1 + Math.random() * 0.2, 0.1 + Math.random() * 0.1, 0.05 + Math.random() * 0.05)
    galleryPillarColor = windowColor.lightness(-0.04, true)

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
    windowSideOffset = randomAmount(0.06, 0.2, 0.02)
    windowDepth = windowSideOffset / 2

    coreShape = CSG.cube(
      center: [ leftX + width / 2, frontY + depth / 2, height / 2 ]
      radius: [ width / 2, depth / 2, height / 2 ]
    )

    paint coreShape, buildingColor

    windowBoxList = [].concat.apply [], (for floorIndex in [ 1...floorCount ]
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

    coreShapeWithWindows = subtractAll(
      coreShape,
      windowBoxList
    )

    gallerySideOffset = windowSideOffset
    galleryTopHeight = floorHeight - randomAmount(0.06, 0.3, 0.02)
    galleryDepth = windowDepth
    galleryPillarRadius = Math.min(randomAmount(0.06, 0.1, 0.02), galleryDepth - 0.02)

    galleryBox = CSG.cube(
      center: [ leftX + width / 2, frontY + galleryDepth / 2, galleryTopHeight / 2 ]
      radius: [ width / 2 - gallerySideOffset, galleryDepth / 2, galleryTopHeight / 2 ]
    )
    paint galleryBox, windowColor

    galleryPillarBoxList = for panelIndex in [ 1...panelCount ]
      pillarBox = CSG.cube(
        center: [ leftX + panelIndex * panelWidth, frontY + galleryDepth, galleryTopHeight / 2 ]
        radius: [ galleryPillarRadius, galleryPillarRadius, galleryTopHeight / 2 ]
      )
      paint pillarBox, galleryPillarColor

      pillarBox

    coreShapeWithWindowsAndGallery = unionAll(
      coreShapeWithWindows.subtract(galleryBox),
      galleryPillarBoxList
    )

    # console.log windowBoxList

    @leftX = leftX
    @rightX = rightX
    @_csg = coreShapeWithWindowsAndGallery

module.exports = Building
