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
    depth = 12

    isHighlight = Math.random() < 0.2

    buildingColor = if isHighlight
      new color.HSL(-0.1 + Math.random() * 0.7, 0.7 + Math.random() * 0.2, 0.15 + Math.random() * 0.2)
    else
      new color.HSL(0.0 + Math.random() * 0.65, 0.2 + Math.random() * 0.1, 0.25 + Math.random() * 0.4)

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

    tickerList = []
    signageList = []

    if Math.random() < 0.3
      marqueeBottom = galleryTopHeight
      marqueeHeight = floorHeight + windowSillHeight - marqueeBottom

      marqueeBox = CSG.cube(
        center: [ leftX + width / 2, frontY + 0.049, marqueeBottom + marqueeHeight / 2 ]
        radius: [ width / 2 - windowSideOffset, 0.05, marqueeHeight / 2 - 0.1 ]
      )
      paint marqueeBox, new color.HSL(
        buildingColor.hue() + 0.2 + Math.random() * 0.6, # avoid building hue
        0.9 + Math.random() * 0.1,
        buildingColor.lightness() - 0.05 - Math.random() * 0.1) # always darker than building

      signageList.push marqueeBox

    if true
      tickerPanelIndex = Math.floor(Math.random() * panelCount)
      tickerSideOffset = randomAmount(0.05, 0.25, 0.02)
      tickerLeftEdge = if tickerPanelIndex is 0 then windowSideOffset else galleryPillarRadius
      tickerRightEdge = if tickerPanelIndex is panelCount - 1 then windowSideOffset else galleryPillarRadius
      tickerWidth = panelWidth - tickerLeftEdge - tickerRightEdge - tickerSideOffset * 2
      tickerCenter = leftX + panelWidth * tickerPanelIndex + panelWidth / 2 + (tickerLeftEdge - tickerRightEdge) / 2
      tickerHeight = (1 + randomAmount(0.2, 0.4, 0.05)) * tickerWidth / 4
      tickerTopOffset = randomAmount(0.05, 0.2, 0.02)

      tickerList.push [
        [ tickerCenter, galleryDepth - 0.01, galleryTopHeight - tickerTopOffset - tickerHeight / 2 ]
        [ tickerWidth / 2, tickerHeight / 2 ]
      ]
    else if Math.random() < 0.3
      galleryBannerBottom = randomAmount(0.2, 0.4, 0.02)
      galleryBannerHeight = galleryTopHeight - randomAmount(0.2, galleryBannerBottom, 0.02) - galleryBannerBottom

      galleryBannerPanelIndex = Math.floor(Math.random() * panelCount)
      galleryBannerSideOffset = randomAmount(0.05, 0.25, 0.02)

      galleryBannerLeftEdge = if galleryBannerPanelIndex is 0 then windowSideOffset else galleryPillarRadius
      galleryBannerRightEdge = if galleryBannerPanelIndex is panelCount - 1 then windowSideOffset else galleryPillarRadius
      galleryBannerWidth = panelWidth - galleryBannerLeftEdge - galleryBannerRightEdge - galleryBannerSideOffset * 2
      galleryBannerCenter = leftX + panelWidth * galleryBannerPanelIndex + panelWidth / 2 + (galleryBannerLeftEdge - galleryBannerRightEdge) / 2

      galleryBannerBox = CSG.cube(
        center: [ galleryBannerCenter, galleryDepth + 0.049, galleryBannerBottom + galleryBannerHeight / 2 ]
        radius: [ galleryBannerWidth / 2, 0.05, galleryBannerHeight / 2 ]
      )
      paint galleryBannerBox, new color.HSL(
        buildingColor.hue() + 0.2 + Math.random() * 0.6, # avoid building hue
        0.6 + Math.random() * 0.2,
        windowColor.lightness() + Math.random() * 0.1) # lighter than windows

      signageList.push galleryBannerBox

    # console.log windowBoxList

    @leftX = leftX
    @rightX = rightX
    @tickerList = tickerList
    @_csg = unionAll coreShapeWithWindowsAndGallery, signageList

module.exports = Building
