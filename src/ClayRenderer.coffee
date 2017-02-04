mat4 = require('gl-matrix').mat4
vec4 = require('gl-matrix').vec4

module.exports = (regl) ->
  light = mat4.create()
  lightExtent = vec4.create()

  shadowFBO = regl.framebuffer
    color: regl.texture
      width: 1024
      height: 1024
      wrap: 'clamp'
      type: 'float'

    depth: true

  renderDepth = regl
    context:
      vert: (context) -> '''
        // shape-specific code

        ''' + context.clayVert + '''

        uniform mat4 light;

        varying vec4 fPosition;

        void applyPosition(vec4 worldPosition) {
        }

        void applyNormal(vec4 worldNormal) {
          // not in use
        }

        // invoke standard entry points
        void main() {
          vec4 worldPosition = clayPosition();
          fPosition = light * worldPosition;
          gl_Position = fPosition;
        }
      '''

    vert: regl.context 'vert'

    frag: '''
      varying mediump vec4 fPosition;

      // ignore shape-specific pigmentation
      void main () {
        gl_FragColor = vec4(vec3(fPosition.z), 1.0);
      }
    '''

  withDepthScope = regl
    uniforms:
      light: regl.prop 'light'

    framebuffer: shadowFBO

  renderView = regl
    context:
      vert: (context) -> '''
        // shape-specific code

        ''' + context.clayVert + '''

        // standard material code
        uniform mediump mat4 camera;
        uniform mediump mat4 light;

        varying vec4 fShadowCoord;
        varying vec4 fNormal;

        void applyPosition(vec4 worldPosition) {
        }

        void applyNormal(vec4 worldNormal) {
        }

        // invoke standard entry points
        void main() {
          claySetup();

          vec4 worldPosition = clayPosition();
          gl_Position = camera * worldPosition;
          fShadowCoord = light * worldPosition;

          vec4 worldNormal = clayNormal();
          fNormal = worldNormal;
        }
      '''

      frag: (context) -> '''
        // shape-specific code

        ''' + context.clayFrag + '''

        // standard material code
        uniform mediump mat4 light;
        uniform mediump float lightProjectionDepth;
        uniform sampler2D shadowMap;
        varying mediump vec4 fShadowCoord;
        varying mediump vec4 fNormal;

        float shadowSample(vec2 co, float z, float bias) {
          float a = texture2D(shadowMap, co).z;
          float b = fShadowCoord.z;

          return step(b - bias, a);
        }

        // invoke standard entry points
        void main() {
          vec4 pigment = clayPigment();

          vec2 co = fShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]
          float lightCosTheta = -lightProjectionDepth * (light * fNormal).z;
          float lightDiffuseAmount =  clamp(lightCosTheta, 0.0, 1.0);

          float bias = max(0.03 * (1.0 - lightCosTheta), 0.005);
          float v = shadowSample(co, fShadowCoord.z, bias);

          gl_FragColor = pigment * vec4(vec3(0.8 + 0.2 * lightDiffuseAmount * v), 1.0);
        }
      '''

    vert: regl.context 'vert'
    frag: regl.context 'frag'

  withViewScope = regl
    uniforms:
      camera: regl.prop 'camera'
      light: regl.prop 'light'
      lightProjectionDepth: regl.prop 'lightProjectionDepth'
      shadowMap: regl.prop 'shadowMap'

  # return the scene renderer
  (camera, lightProjection, lightTransform, cb) ->
    # pre-calculate the non-uniform projection depth of the light
    # (this helps isolate uniform light direction when calculating world surface incidence angle)
    vec4.set lightExtent, 0, 0, 1, 0
    vec4.transformMat4 lightExtent, lightExtent, lightProjection
    lightProjectionDepth = 1 / vec4.length(lightExtent)

    mat4.mul light, lightProjection, lightTransform

    withDepthScope
      light: light
    , ->
      regl.clear
        color: [ 1, 1, 1, 1 ]
        depth: 1

      cb (isShadowing) -> (-> if isShadowing then renderDepth())

    withViewScope
      camera: camera
      light: light
      lightProjectionDepth: lightProjectionDepth
      shadowMap: shadowFBO
    , ->
      cb (isShadowing) -> (-> renderView())
