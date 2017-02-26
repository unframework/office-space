`var glsl = require('glslify')` # glslify transform does not detect generated expression otherwise

DebugRayShape = (regl, isXray) -> regl
  vert: glsl '''
    precision mediump float;

    uniform mat4 camera;
    uniform vec3 translate;
    uniform float radius;
    uniform float length;
    uniform float direction;
    attribute vec2 position;

    varying vec2 fPosition;

    void main() {
      fPosition = position;

      float dirX = cos(direction);
      float dirY = sin(direction);

      vec2 xy = mat2(dirX, dirY, -dirY, dirX) * (position.xy * vec2(length, radius));

      gl_Position = camera * vec4(translate + vec3(xy, 0), 1);
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
      if (dither(gl_FragCoord.xy, color.a) < 1.0) {
        discard;
      }
    }
  '''

  depth:
    if isXray
      func: 'always'
      mask: false
    else
      func: 'lequal'

  uniforms:
    camera: regl.prop 'camera'
    translate: regl.prop 'translate'
    length: regl.prop 'length'
    direction: regl.prop 'direction'
    radius: regl.prop 'radius'
    color: regl.prop 'color'

  attributes:
    position: regl.buffer [
      [0, -1]
      [1, 0]
      [0, 1]
    ]

  primitive: 'triangle fan'
  count: 3

module.exports = DebugRayShape
