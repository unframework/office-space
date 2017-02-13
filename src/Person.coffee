fs = require('fs')
Readable = require('stream').Readable
parseOBJ = require('parse-obj')

TEXTURE_DATA = fs.readFileSync(__dirname + '/Person.png', 'binary')
MESH_DATA = fs.readFileSync __dirname + '/Person.objdata'
MESH_SCALE = 1
MESH_HEIGHT = 1.5

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
    context:
      modelTop: (context, props) ->
        props.modelTop or props.model

      clay:
        vert: '''
          precision mediump float;

          uniform mat4 model;
          uniform mat4 modelTop;
          uniform vec4 colorTop;
          uniform vec4 colorBottom;
          attribute vec4 position;
          attribute vec3 normal;
          attribute vec2 uv;

          varying vec4 fNormal;
          varying vec4 fColor;
          varying vec2 fUV;

          vec4 interp(vec4 item) {
            vec4 deformedTop = modelTop * item;
            vec4 deformedBottom = model * item;

            return mix(deformedBottom, deformedTop, position.z / ''' + MESH_HEIGHT + ''');
          }

          void claySetup() {
            fNormal = interp(vec4(normal, 0)); // normal in world space without translation
            fColor = mix(colorBottom, colorTop, position.z);
            fUV = uv;
          }

          vec4 clayPosition() {
            return interp(position);
          }

          #pragma glslify: export(claySetup)
        '''

        frag: '''
          precision mediump float;

          uniform sampler2D texture;
          varying vec4 fNormal;
          varying vec4 fColor;
          varying vec2 fUV;

          void claySetup() {
            // nothing to prepare
          }

          vec4 clayNormal() {
            return fNormal;
          }

          vec4 clayPigment() {
            return texture2D(texture, fUV) * fColor;
          }

          #pragma glslify: export(claySetup)
        '''

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
            1

            v1[0] * MESH_SCALE
            v1[1] * MESH_SCALE
            v1[2] * MESH_SCALE
            1

            v2[0] * MESH_SCALE
            v2[1] * MESH_SCALE
            v2[2] * MESH_SCALE
            1
          ]
      )

      normal: regl.buffer (
        for tri in mesh.faceNormals
          vn0 = mesh.vertexNormals[tri[0]]
          vn1 = mesh.vertexNormals[tri[1]]
          vn2 = mesh.vertexNormals[tri[2]]

          [
            vn0[0]
            vn0[1]
            vn0[2]

            vn1[0]
            vn1[1]
            vn1[2]

            vn2[0]
            vn2[1]
            vn2[2]
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
      modelTop: regl.context 'modelTop'

      colorTop: regl.prop 'colorTop'
      colorBottom: regl.prop 'colorBottom'

      texture: regl.texture
        data: texture
        flipY: true
        wrapS: 'repeat'
        wrapT: 'repeat'

    count: mesh.facePositions.length * 3
