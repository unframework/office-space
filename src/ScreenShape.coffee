moment = require('moment')

PIXEL_WIDTH = 32
PIXEL_HEIGHT = 8

svgData = '''
<svg
  xmlns="http://www.w3.org/2000/svg"
  width="''' + PIXEL_WIDTH + '''" height="''' + PIXEL_HEIGHT + '''" viewBox="0 0 128 32"
  text-rendering="optimizeLegibility"
>
  <rect x="0" y="0" width="100%" height="100%" fill="black" />
  <text
    x="64" y="28"
    font-family="Courier New"
    font-size="40"
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

        uniform vec3 center;
        uniform vec2 radius;
        attribute vec2 position;

        varying vec2 fUV;

        void claySetup() {
          fUV = vec2(position.x + 1.0, 1.0 - position.y) / 2.0;
        }

        vec4 clayPosition() {
          return vec4(center, 0) + vec4(position.x * radius.x, 0, position.y * radius.y, 1);
        }

        #pragma glslify: export(claySetup)
      '''

      frag: '''
        precision mediump float;

        uniform int pixelWidth;
        uniform int pixelHeight;
        uniform sampler2D image;

        varying vec2 fUV;

        void claySetup() {
          // nothing to prepare
        }

        vec4 clayNormal() {
          return vec4(0, 0, 1, 0);
        }

        vec4 clayPigment() {
          vec2 pixelPos = fUV * vec2(pixelWidth, pixelHeight);
          vec2 pixelPlace = pixelPos - floor(pixelPos) - vec2(0.5, 0.5);
          vec2 pixelIntensity = vec2(1.0, 1.0) - pixelPlace * pixelPlace / 0.25;
          float pixelBrightness = pixelIntensity.x * pixelIntensity.y * 1.1;
          return vec4(0.01, 0.01, 0.01, 0) + pixelBrightness * texture2D(image, fUV);
        }

        #pragma glslify: export(claySetup)
      '''

  uniforms:
    center: regl.prop('center')
    radius: regl.prop('radius')
    pixelWidth: PIXEL_WIDTH
    pixelHeight: PIXEL_HEIGHT
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
