module.exports = (regl) -> regl
  context:
    clay:
      vert: '''
        precision mediump float;

        uniform mediump vec3 origin;
        uniform mediump vec3 size;
        attribute vec3 position;

        varying vec3 fNormal;

        void claySetup() {
          fNormal = position.xyz;
        }

        vec4 clayPosition() {
          return vec4(origin + step(vec3(0), position) * size, 1);
        }

        #pragma glslify: export(claySetup)
      '''

      frag: '''
        precision mediump float;

        varying mediump vec3 fNormal;

        void claySetup() {
          // nothing to prepare
        }

        vec4 clayNormal() {
          vec3 mags = floor(abs(fNormal) + 0.0001);
          mags = mags / (mags.x + mags.y + mags.z); // "poor man's normalization" around cusps
          return vec4(mags * sign(fNormal), 0);
        }

        vec4 clayPigment() {
          return vec4(0.45, 0.45, 0.45, 1);
        }

        #pragma glslify: export(claySetup)
      '''

  uniforms:
    origin: regl.prop 'origin'
    size: regl.prop 'size'

  attributes:
    position: regl.buffer [
      [ -1, -1, -1 ]
      [ -1, 1, -1 ]
      [ 1, -1, -1 ]
      [ 1, 1, -1 ]
      [ 1, -1, 1 ]
      [ 1, 1, 1 ]
      [ -1, -1, 1 ]
      [ -1, 1, 1 ]
      # strip split (draws two dummy triangles inside)
      [ 1, -1, -1 ]
      [ 1, -1, 1 ]
      [ -1, -1, -1 ]
      [ -1, -1, 1 ]
      [ -1, 1, -1 ]
      [ -1, 1, 1 ]
      [ 1, 1, -1 ]
      [ 1, 1, 1 ]
    ]

  cull: enable: true
  primitive: 'triangle strip'
  count: 16
