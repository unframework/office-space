regl = require('regl')()

drawShape = regl
  frag: '
    precision mediump float;
    varying vec4 color;
    void main() {
      gl_FragColor = color;
    }
  '

  vert: '
    precision mediump float;
    attribute vec2 position;
    uniform vec4 colorA;
    uniform vec4 colorB;
    varying vec4 color;
    void main() {
      gl_Position = vec4(position, 0, 1);
      color = mix(colorA, colorB, (position.y + 0.5) / 2.0);
    }
  '

  attributes:
    position: regl.buffer [
      [-0.8, -0.8]
      [0.8, -0.8]
      [0.8,  0.8]
      [-0.8, 0.8]
    ]

  uniforms:
    colorA: regl.prop('colorA')
    colorB: regl.prop('colorB')

  primitive: 'triangle fan'
  count: 4

regl.frame ({ time }) ->
  regl.clear
    color: [0, 0, 0, 0]
    depth: 1

  drawShape
    colorA: [
      Math.cos(time * 0.1)
      Math.sin(time * 0.08)
      Math.cos(time * 0.3)
      1
    ]
    colorB: [
      Math.cos((time + 2.5) * 0.1)
      Math.sin((time + 2.5) * 0.08)
      Math.cos((time + 2.5) * 0.3)
      1
    ]
