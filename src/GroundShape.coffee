module.exports = (regl) -> regl
  context:
    clay:
      vert: '''
        precision mediump float;

        uniform float z;
        uniform vec4 colorA;
        uniform vec4 colorB;
        attribute vec2 position;

        varying vec4 fColor;

        void claySetup() {
          fColor = mix(colorA, colorB, (position.y + 12.0) / 24.0);
        }

        vec4 clayPosition() {
          return vec4(position, z, 1);
        }

        #pragma glslify: export(claySetup)
      '''

      frag: '''
        precision mediump float;

        varying mediump vec4 fColor;

        void claySetup() {
          // nothing to prepare
        }

        vec4 clayNormal() {
          return vec4(0, 0, 1, 0);
        }

        vec4 clayPigment() {
          return fColor;
        }

        #pragma glslify: export(claySetup)
      '''

  attributes:
    position: regl.buffer [
      [-12, -12]
      [12, -12]
      [12,  12]
      [-12, 12]
    ]

  uniforms:
    z: regl.prop 'z'
    colorA: regl.prop 'colorA'
    colorB: regl.prop 'colorB'

  primitive: 'triangle fan'
  count: 4
