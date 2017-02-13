mat4 = require('gl-matrix').mat4
vec4 = require('gl-matrix').vec4
glslifyBundle = require('glslify-bundle')

# references:
# - http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-16-shadow-mapping/ (google search "opengl shadows")
# - https://github.com/regl-project/regl/blob/gh-pages/example/shadow_map.js

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
    uniform float lightProjectionDepth;
    uniform sampler2D shadowMap;
    varying vec4 fShadowCoord;

    float shadowSample(vec2 co, float z, float bias) {
      float a = texture2D(shadowMap, co).z;
      float b = fShadowCoord.z;

      return step(b - bias, a);
    }

    // invoke standard entry points
    void main() {
      claySetup();

      vec4 pigment = clayPigment();

      vec2 co = fShadowCoord.xy * 0.5 + 0.5; // go from range [-1, +1] to range [0, +1]
      float lightCosTheta = -lightProjectionDepth * (light * clayNormal()).z;
      float lightDiffuseAmount =  clamp(lightCosTheta, 0.0, 1.0);

      float bias = max(0.01 * (1.0 - lightCosTheta), 0.005);
      float v = shadowSample(co, fShadowCoord.z, bias);

      gl_FragColor = pigment * vec4(vec3(0.8 + 0.2 * lightDiffuseAmount * v), 1.0);
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
      lightProjectionDepth: lightProjectionDepth
      shadowMap: shadowFBO
    , ->
      cb (-> renderView()), (-> renderView())
