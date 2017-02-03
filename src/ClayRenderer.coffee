mat4 = require('gl-matrix').mat4

LIGHT_MAP_DEPTH_EXTENT = 12

module.exports = (regl) ->
  light = mat4.create()

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
        uniform mat4 light;

        varying vec4 fPosition;

        void applyPosition(vec4 worldPosition) {
          fPosition = light * worldPosition;
          gl_Position = fPosition;
        }

        void applyNormal(vec4 worldNormal) {
          // not in use
        }

        // shape-specific code

        ''' + context.clayVert + '''

        // invoke standard entry points
        void main() {
          clayPosition();
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
        // standard material code
        uniform mediump mat4 camera;
        uniform mediump mat4 light;

        varying vec4 fShadowCoord;
        varying vec4 fNormal;

        void applyPosition(vec4 worldPosition) {
          gl_Position = camera * worldPosition;
          fShadowCoord = light * worldPosition;
        }

        void applyNormal(vec4 worldNormal) {
          fNormal = worldNormal;
        }

        // shape-specific code

        ''' + context.clayVert + '''

        // invoke standard entry points
        void main() {
          clayPigment();
          clayPosition();
          clayNormal();
        }
      '''

      frag: (context) -> '''
        // standard material code
        uniform mediump mat4 light;
        uniform sampler2D shadowMap;
        varying mediump vec4 fShadowCoord;
        varying mediump vec4 fNormal;

        float shadowSample(vec2 co, float z, float bias) {
          float a = texture2D(shadowMap, co).z;
          float b = fShadowCoord.z;

          return step(b - bias, a);
        }

        void applyPigment(vec4 pigment) {
          vec2 co = fShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]
          float lightCosTheta = -float(''' + LIGHT_MAP_DEPTH_EXTENT + ''') * (light * fNormal).z;
          float lightDiffuseAmount =  clamp(lightCosTheta, 0.0, 1.0);

          float bias = max(0.03 * (1.0 - lightCosTheta), 0.005);
          float v = shadowSample(co, fShadowCoord.z, bias);

          gl_FragColor = pigment * vec4(vec3(0.8 + 0.2 * lightDiffuseAmount * v), 1.0);
        }

        // shape-specific code

        ''' + context.clayFrag + '''

        // invoke standard entry points
        void main() {
          clayPigment();
        }
      '''

    vert: regl.context 'vert'
    frag: regl.context 'frag'

  withViewScope = regl
    uniforms:
      camera: regl.prop 'camera'
      light: regl.prop 'light'
      shadowMap: regl.prop 'shadowMap'

  # return the scene renderer
  (camera, lightTransform, cb) ->
    mat4.ortho light, -12, 12, -12, 12, -LIGHT_MAP_DEPTH_EXTENT, LIGHT_MAP_DEPTH_EXTENT
    mat4.mul light, light, lightTransform

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
      shadowMap: shadowFBO
    , ->
      cb (isShadowing) -> (-> renderView())
