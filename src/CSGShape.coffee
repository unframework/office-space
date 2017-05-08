module.exports = (regl, shape) -> polygonList = shape.toPolygons(); regl
  context:
    clay:
      vert: '''
        precision mediump float;

        attribute vec3 position;
        attribute vec3 normal;
        attribute vec3 color;

        varying vec4 fNormal;
        varying vec4 fColor;

        void claySetup() {
          fNormal = vec4(normal, 0);
          fColor = vec4(color, 1);
        }

        vec4 clayPosition() {
          return vec4(position, 1);
        }

        #pragma glslify: export(claySetup)
      '''

      frag: '''
        precision mediump float;

        varying mediump vec4 fNormal;
        varying mediump vec4 fColor;

        void claySetup() {
          // nothing to prepare
        }

        vec4 clayNormal() {
          return fNormal;
        }

        vec4 clayPigment() {
          return fColor;
        }

        #pragma glslify: export(claySetup)
      '''

  attributes:
    position: regl.buffer (
      for poly in polygonList
        vert0 = poly.vertices[0]

        for vert, vi in poly.vertices when vi > 1
          vert1 = poly.vertices[vi - 1]
          [
            [ vert0.pos.x, vert0.pos.y, vert0.pos.z ]
            [ vert1.pos.x, vert1.pos.y, vert1.pos.z ]
            [ vert.pos.x, vert.pos.y, vert.pos.z ]
          ]
    )
    normal: regl.buffer (
      for poly in polygonList
        vert0 = poly.vertices[0]
        vert1 = poly.vertices[1]

        for vert, vi in poly.vertices when vi > 1
          [
            [ vert0.normal.x, vert0.normal.y, vert0.normal.z ]
            [ vert1.normal.x, vert1.normal.y, vert1.normal.z ]
            [ vert.normal.x, vert.normal.y, vert.normal.z ]
          ]
    )
    color: regl.buffer (
      for poly in polygonList
        polyColor = poly.shared and poly.shared.color or null
        polyColorValues = if polyColor
          [ polyColor.red(), polyColor.green(), polyColor.blue() ]
        else
          [ 0.3, 0.3, 0.3 ]

        (polyColorValues for i in [ 0 ... (poly.vertices.length - 2) * 3 ])
    )

  cull: enable: true
  primitive: 'triangles'
  count: polygonList.reduce (sum, poly) ->
    (poly.vertices.length - 2) * 3 + sum
  , 0
