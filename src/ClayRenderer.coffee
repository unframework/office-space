mat4 = require('gl-matrix').mat4
vec4 = require('gl-matrix').vec4
glslifyBundle = require('glslify-bundle')

# references:
# - http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-16-shadow-mapping/ (google search "opengl shadows")
# - https://github.com/regl-project/regl/blob/gh-pages/example/shadow_map.js
# - http://ogldev.atspace.co.uk/www/tutorial18/tutorial18.html
# - http://marcinignac.com/blog/pragmatic-pbr-hdr/
# - http://filmicworlds.com/blog/filmic-tonemapping-operators/
# - http://www.slideshare.net/ozlael/hable-john-uncharted2-hdr-lighting

CACHE_KEY_PREFIX = '__clay_cache' + Math.round(Math.random() * 1000000)
CACHE_DEPTH_VERT_KEY = CACHE_KEY_PREFIX + '_dv'
CACHE_VIEW_VERT_KEY = CACHE_KEY_PREFIX + '_vv'
CACHE_VIEW_FRAG_KEY = CACHE_KEY_PREFIX + '_vf'

cachingGenerator = (cacheKey, cb) ->
  (definition) ->
    definition[cacheKey] or (definition[cacheKey] = cb definition)

importUpstream = (upstream, src) ->
  glslifyBundle [
    { id: 0, deps: { '__upstream': 1 }, file: 'entry.glsl', source: src, entry: true }
    { id: 1, deps: {}, file: 'upstream.glsl', source: upstream, entry: false }
  ]

generateDepthVertShader = cachingGenerator CACHE_DEPTH_VERT_KEY, (definition) ->
  importUpstream definition.vert, '''
    #pragma glslify: claySetup = require('__upstream', clayPosition=clayPosition)

    precision mediump float;

    uniform mat4 light;

    varying vec4 fPosition;

    // invoke standard entry points
    void main() {
      vec4 worldPosition = clayPosition();
      fPosition = light * worldPosition;
      gl_Position = fPosition;
    }
  '''

generateViewVertShader = cachingGenerator CACHE_VIEW_VERT_KEY, (definition) ->
  importUpstream definition.vert, '''
    #pragma glslify: claySetup = require('__upstream', clayPosition=clayPosition)

    precision mediump float;

    // standard material code
    uniform mat4 camera;
    uniform mat4 light;

    varying vec4 fShadowCoord;

    // invoke standard entry points
    void main() {
      claySetup();

      vec4 worldPosition = clayPosition();
      gl_Position = camera * worldPosition;
      fShadowCoord = light * worldPosition;
    }
  '''

generateViewFragShader = cachingGenerator CACHE_VIEW_FRAG_KEY, (definition) ->
  importUpstream definition.frag, '''
    #pragma glslify: claySetup = require('__upstream', clayNormal=clayNormal, clayPigment=clayPigment)

    precision mediump float;

    // standard material code
    uniform mat4 light;
    uniform vec3 lightColor;
    uniform vec3 ambientColor;
    uniform float lightProjectionDepth;
    uniform sampler2D shadowMap;
    varying vec4 fShadowCoord;

    float shadowSample(vec2 co, float z, float bias) {
      float a = texture2D(shadowMap, co).z;
      float b = fShadowCoord.z;

      return step(b - bias, a);
    }

    vec3 hdrReinhard(vec3 color) {
      return color / (color + vec3(1.0));
    }

    vec3 hdrFilmic(vec3 color) {
      vec3 x = max(vec3(0), color - 0.004);
      return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
    }

    // invoke standard entry points
    void main() {
      claySetup();

      vec4 pigment = clayPigment();
      vec4 normal = clayNormal();

      // diffuse light component masked by the computed shadows
      vec2 co = fShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]
      float lightCosTheta = -lightProjectionDepth * (light * normal).z;
      float lightDiffuseAmount =  clamp(lightCosTheta, 0.0, 1.0);

      float bias = max(0.01 * (1.0 - lightCosTheta), 0.005);
      float lightShadowMask = shadowSample(co, fShadowCoord.z, bias);

      // ambient light component with ever so slightly varying shading for extra texture
      float ambientAmount = 0.92 + 0.08 * clamp(normal.z, -1.0, 1.0);

      // mix up the combined illumination and pigment light response components
      vec3 rgbLinear = pigment.rgb * (lightColor * lightDiffuseAmount * lightShadowMask + ambientColor * ambientAmount);

      // convert from scene linear space into compressed monitor-friendly output
      vec3 rgbCompressed = hdrFilmic(rgbLinear);

      gl_FragColor = vec4(rgbCompressed, 1.0);
    }
  '''

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
      vert: (context) ->
        generateDepthVertShader context.clay

    vert: regl.context 'vert'

    frag: '''
      precision mediump float;

      varying vec4 fPosition;

      // ignore shape-specific pigmentation
      void main () {
        gl_FragColor = vec4(vec3(fPosition.z), 1.0);
      }
    '''

  withDepthScope = regl
    uniforms:
      light: regl.prop 'light'

    framebuffer: shadowFBO

  cnt = 0

  renderView = regl
    context:
      vert: (context) ->
        generateViewVertShader context.clay

      frag: (context) ->
        generateViewFragShader context.clay

    vert: regl.context 'vert'
    frag: regl.context 'frag'

  withViewScope = regl
    uniforms:
      camera: regl.prop 'camera'
      light: regl.prop 'light'
      lightColor: regl.prop 'lightColor'
      ambientColor: regl.prop 'ambientColor'
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

      cb (-> renderDepth()), (->)

    withViewScope
      camera: camera
      light: light
      lightColor: [ 1.4, 1.35, 1.2 ]
      ambientColor: [ 0.3, 0.4, 0.8 ]
      lightProjectionDepth: lightProjectionDepth
      shadowMap: shadowFBO
    , ->
      cb (-> renderView()), (-> renderView())
