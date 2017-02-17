`var glsl = require('glslify')` # glslify transform does not detect generated expression otherwise

DebugTargetShape = (regl) -> regl
  vert: glsl '''
    precision mediump float;

    uniform mat4 camera;
    uniform vec3 translate;
    uniform float size;
    attribute vec2 position;

    varying vec2 fPosition;

    void main() {
      fPosition = position;

      gl_Position = camera * vec4(translate + vec3(position * size, 0), 1);
    }
  '''

  frag: glsl '''
    precision mediump float;

    #pragma glslify: dither = require(glsl-dither/4x4)

    uniform vec4 color;

    varying vec2 fPosition;

    void main() {
      gl_FragColor = vec4(color.rgb, 1);

      // discarding after assigning gl_FragColor, apparently may not discard otherwise due to bug
      if (sqrt(dot(fPosition, fPosition)) > 1.0) {
        discard;
      }

      if (dither(gl_FragCoord.xy, color.a) < 1.0) {
        discard;
      }
    }
  '''

  depth:
    func: 'lequal' # @todo meh just use "always" and disable writing? but then idempotence is not there

  uniforms:
    camera: regl.prop 'camera'
    translate: regl.prop 'translate'
    size: regl.prop 'size'
    color: regl.prop 'color'

  attributes:
    position: regl.buffer [
      [-1, -1]
      [1, -1]
      [1,  1]
      [-1, 1]
    ]

  primitive: 'triangle fan'
  count: 4

module.exports = DebugTargetShape
