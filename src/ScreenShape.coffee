moment = require('moment')

svgData = '''
<svg
  xmlns="http://www.w3.org/2000/svg"
  width="64" height="16" viewBox="0 0 128 32"

>
  <rect x="0" y="0" width="100%" height="100%" fill="black" />
  <text
    x="64" y="28"
    font-family="Courier New"
    font-size="36"
    font-weight="bold"
    fill="red"
    text-anchor="middle"
  >
    ''' + moment().format('HH:mm') + '''
  </text>
</svg>
'''

loadImage = (onLoad) ->
  img = new Image()
  img.onload = -> onLoad img
  img.src = 'data:image/svg+xml,' + encodeURIComponent(svgData)

ScreenShape = (regl) -> new Promise (resolve) -> loadImage (img) -> resolve regl
  context:
    clay:
      vert: '''
        precision mediump float;

        attribute vec2 position;

        varying vec2 fUV;

        void claySetup() {
          fUV = vec2(position.x + 1.0, 1.0 - position.y) / 2.0;
        }

        vec4 clayPosition() {
          return vec4(0, -2, 2, 0) + vec4(position.x * 1.6, position.y * 0.5, 0, 1);
        }

        #pragma glslify: export(claySetup)
      '''

      frag: '''
        precision mediump float;

        uniform sampler2D image;

        varying vec2 fUV;

        void claySetup() {
          // nothing to prepare
        }

        vec4 clayNormal() {
          return vec4(0, 0, 1, 0);
        }

        vec4 clayPigment() {
          return texture2D(image, fUV);
        }

        #pragma glslify: export(claySetup)
      '''

  uniforms:
    image: regl.texture(img, mag: 'nearest', min: 'nearest')

  attributes:
    position: regl.buffer [
      [1, -1]
      [1,  1]
      [-1, 1]
      [-1, -1]
    ]

  primitive: 'triangle fan'
  count: 4

module.exports = ScreenShape
