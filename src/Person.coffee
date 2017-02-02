fs = require('fs')
Readable = require('stream').Readable
parseOBJ = require('parse-obj')

TEXTURE_DATA = fs.readFileSync(__dirname + '/Person.png', 'binary')
MESH_DATA = fs.readFileSync __dirname + '/Person.objdata'
MESH_SCALE = 1.5

createReadableFromData = (data) ->
  fileStream = new Readable read: -> # no-op read
  [ data, null ].map (v) -> fileStream.push v

  fileStream

textureLoad = new Promise (resolve) ->
  loader = new Image()
  loader.crossOrigin = "anonymous" # prevent "tainted canvas" warning when blitting this
  loader.onload = -> resolve loader
  loader.src = 'data:application/octet-stream;base64,' + btoa(TEXTURE_DATA) # kick off loading as the last thing

module.exports = (regl) -> textureLoad.then (texture) -> new Promise (resolve) -> parseOBJ createReadableFromData(MESH_DATA), (err, mesh) ->
  resolve regl
    vert: '
      uniform mat4 camera;
      uniform mat4 model;
      uniform mediump vec4 colorTop;
      uniform mediump vec4 colorBottom;
      attribute vec4 position;
      attribute vec2 uv;

      varying vec2 fUV;
      varying vec4 fColor;

      void main() {
        gl_Position = camera * model * position;
        fColor = mix(colorBottom, colorTop, position.z);
        fUV = uv;
      }
    '

    frag: '
      varying mediump vec4 fColor;
      varying mediump vec2 fUV;
      uniform sampler2D texture;

      void main() {
        gl_FragColor = texture2D(texture, fUV) * fColor;
      }
    '

    attributes:
      position: regl.buffer (
        for tri in mesh.facePositions
          v0 = mesh.vertexPositions[tri[0]]
          v1 = mesh.vertexPositions[tri[1]]
          v2 = mesh.vertexPositions[tri[2]]

          [
            v0[0] * MESH_SCALE
            v0[1] * MESH_SCALE
            v0[2] * MESH_SCALE

            v1[0] * MESH_SCALE
            v1[1] * MESH_SCALE
            v1[2] * MESH_SCALE

            v2[0] * MESH_SCALE
            v2[1] * MESH_SCALE
            v2[2] * MESH_SCALE
          ]
      )
      uv: regl.buffer (
        for tri in mesh.faceUVs
          uv0 = mesh.vertexUVs[tri[0]]
          uv1 = mesh.vertexUVs[tri[1]]
          uv2 = mesh.vertexUVs[tri[2]]

          [
            uv0[0]
            uv0[1]

            uv1[0]
            uv1[1]

            uv2[0]
            uv2[1]
          ]
      )

    uniforms:
      model: regl.prop 'model'
      camera: regl.prop 'camera'

      colorTop: [ 1, 1, 0.8, 1 ]
      colorBottom: [ 1, 0.8, 1, 1 ]
      texture: regl.texture
        data: texture
        flipY: true
        wrapS: 'repeat'
        wrapT: 'repeat'

    count: mesh.facePositions.length * 3
