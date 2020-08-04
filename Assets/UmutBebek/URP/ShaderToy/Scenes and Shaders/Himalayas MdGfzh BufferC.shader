﻿Shader "UmutBebek/URP/ShaderToy/Himalayas MdGfzh BufferC"
{
    Properties
    {
        _Channel0("Channel0 (RGB)", 2D) = "" {}
        _Channel1("Channel1 (RGB)", 2D) = "" {}
        _Channel2("Channel2 (RGB)", 2D) = "" {}
        _Channel3("Channel3 (RGB)", 2D) = "" {}
        [HideInInspector]iMouse("Mouse", Vector) = (0,0,0,0)


    }

        SubShader
        {
            // With SRP we introduce a new "RenderPipeline" tag in Subshader. This allows to create shaders
            // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
            // any render pipeline. In case you want your subshader to only run in LWRP set the tag to
            // "UniversalRenderPipeline"
            Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}
            LOD 300

            // ------------------------------------------------------------------
            // Forward pass. Shades GI, emission, fog and all lights in a single pass.
            // Compared to Builtin pipeline forward renderer, LWRP forward renderer will
            // render a scene with multiple lights with less drawcalls and less overdraw.
            Pass
            {
                // "Lightmode" tag must be "UniversalForward" or not be defined in order for
                // to render objects.
                Name "StandardLit"
                //Tags{"LightMode" = "UniversalForward"}

                //Blend[_SrcBlend][_DstBlend]
                //ZWrite Off ZTest Always
                //ZWrite[_ZWrite]
                //Cull[_Cull]

                HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            //do not add LitInput, it has already BaseMap etc. definitions, we do not need them (manually described below)
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            float4 _Channel0_ST;
            TEXTURE2D(_Channel0);       SAMPLER(sampler_Channel0);
            float4 _Channel1_ST;
            TEXTURE2D(_Channel1);       SAMPLER(sampler_Channel1);
            float4 _Channel2_ST;
            TEXTURE2D(_Channel2);       SAMPLER(sampler_Channel2);
            float4 _Channel3_ST;
            TEXTURE2D(_Channel3);       SAMPLER(sampler_Channel3);

            float4 iMouse;


            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                float4 positionCS               : SV_POSITION;
                float4 screenPos                : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
                // Our compiler will strip all unused references (say you don't use view space).
                // Therefore there is more flexibility at no additional cost with this struct.
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                // TRANSFORM_TEX is the same as the old shader library.
                output.uv = TRANSFORM_TEX(input.uv, _Channel0);
                // We just use the homogeneous clip position from the vertex input
                output.positionCS = vertexInput.positionCS;
                output.screenPos = ComputeScreenPos(vertexInput.positionCS);
                return output;
            }

            #define FLT_MAX 3.402823466e+38
            #define FLT_MIN 1.175494351e-38
            #define DBL_MAX 1.7976931348623158e+308
            #define DBL_MIN 2.2250738585072014e-308

             #define iTimeDelta unity_DeltaTime.x
            // float;

            #define iFrame ((int)(_Time.y / iTimeDelta))
            // int;

           #define clamp(x,minVal,maxVal) min(max(x, minVal), maxVal)

           float mod(float a, float b)
           {
               return a - floor(a / b) * b;
           }
           float2 mod(float2 a, float2 b)
           {
               return a - floor(a / b) * b;
           }
           float3 mod(float3 a, float3 b)
           {
               return a - floor(a / b) * b;
           }
           float4 mod(float4 a, float4 b)
           {
               return a - floor(a / b) * b;
           }

           float3 makeDarker(float3 item) {
               float darken = 0.10;
               item.x = max(item.x - darken, 0);
               item.y = max(item.y - darken, 0);
               item.z = max(item.z - darken, 0);
               return item;
           }

           float4 pointSampleTex2D(Texture2D sam, SamplerState samp, float2 uv, float lod=0)//, float4 st) st is aactually screenparam because we use screenspace
           {
               //float2 snappedUV = ((float2)((int2)(uv * st.zw + float2(1, 1))) - float2(0.5, 0.5)) * st.xy;
               float2 snappedUV = ((float2)((int2)(uv * _ScreenParams.zw + float2(1, 1))) - float2(0.5, 0.5)) * _ScreenParams.xy;
               return  SAMPLE_TEXTURE2D_LOD(sam, samp, float4(snappedUV.x, snappedUV.y, 0, 0), lod);
           }

           // Himalayas. Created by Reinder Nijhoff 2018 
// @reindernijhoff 
// 
// https: // www.shadertoy.com / view / MdGfzh 
// 
// This is my first attempt to render volumetric clouds in a fragment shader. 
// 
// 1 unit correspondents to SCENE_SCALE meter. 

#define SCENE_SCALE ( 10. ) 
#define INV_SCENE_SCALE ( .1 ) 

#define MOUNTAIN_HEIGHT ( 5000. ) 
#define MOUNTAIN_HW_RATIO ( 0.00016 ) 

#define SUN_DIR normalize ( float3 ( - .7 , .5 , .75 ) ) 
#define SUN_COLOR ( float3 ( 1. , .9 , .85 ) * 1.4 ) 

#define FLAG_POSITION ( float3 ( 3900.5 , 720. , - 2516. ) * INV_SCENE_SCALE ) 
#define HUMANOID_SCALE ( 2. ) 

#define CAMERA_RO ( float3 ( 3980. , 730. , - 2650. ) * INV_SCENE_SCALE ) 
#define CAMERA_FL 2. 

           static const float HEIGHT_BASED_FOG_B = 0.02;
           static const float HEIGHT_BASED_FOG_C = 0.05;


float3x3 getCamera(in float time , in float4 mouse , inout float3 ro , inout float3 ta) {
    ro = CAMERA_RO;
    float3 cw;
    if (mouse.z > 0.) {
        float2 m = (mouse.xy - .5) * 2.3;
        float my = -sin(m.y);
        cw = normalize(float3 (-sin(-m.x) , my + .15 , cos(-m.x)));
     }
else {
 ro.x += -cos(time * .13) * 5. * INV_SCENE_SCALE;
 ro.z += (-cos(time * .1) * 100. + 20.) * INV_SCENE_SCALE;
 cw = normalize(float3 (-.1 , .18 , 1.));
}
ta = ro + cw * (200. * INV_SCENE_SCALE);
 float3 cp = float3 (0.0 , 1.0 , 0.0);
 float3 cu = normalize(cross(cw , cp));
 float3 cv = normalize(cross(cu , cw));
return float3x3 (cu , cv , cw);
}

void getRay(in float time , in float2 fragCoord , in float2 resolution , in float4 mouse , inout float3 ro , inout float3 rd) {
     float3 ta;
     float3x3 cam = getCamera(time , mouse , ro , ta);
    float2 p = (-resolution.xy + 2.0 * (fragCoord)) / resolution.y;
    rd = mul(cam , normalize(float3 (p , CAMERA_FL)));
 }

// 
// To reduce noise I use temporal reprojection ( both for clouds ( Buffer D ) and the terrain 
// ( Buffer C ) seperatly. The temporal repojection code is based on code from the shader 
// "Rain Forest" ( again by Íñigo Quílez ) : 
// 
// https: // www.shadertoy.com / view / 4ttSWf 
// 
float4 saveCamera(in float time , in float2 fragCoord , in float4 mouse) {
    float3 ro , ta;
    float3x3 cam = getCamera(time , mouse , ro , ta);
    float4 fragColor;

    if (abs(fragCoord.x - 4.5) < 0.5) fragColor = float4 (cam[2] , -dot(cam[2] , ro));
    if (abs(fragCoord.x - 3.5) < 0.5) fragColor = float4 (cam[1] , -dot(cam[1] , ro));
    if (abs(fragCoord.x - 2.5) < 0.5) fragColor = float4 (cam[0] , -dot(cam[0] , ro));

    return fragColor;
 }

float2 reprojectPos(in float3 pos , in float2 resolution , in Texture2D storage, in SamplerState samp) {
    float4x4 oldCam = float4x4 (pointSampleTex2D(storage , samp, int2 (2 , 0) ) ,
                        pointSampleTex2D(storage , samp, int2 (3 , 0) ) ,
                        pointSampleTex2D(storage , samp, int2 (4 , 0) ) ,
                        0.0 , 0.0 , 0.0 , 1.0);

    float4 wpos = float4 (pos , 1.0);
    float3 cpos = (mul(wpos , oldCam)).xyz;
    float2 npos = CAMERA_FL * cpos.xy / cpos.z;
    return 0.5 + 0.5 * npos * float2 (resolution.y / resolution.x , 1.0);
 }

// 
// Fast skycolor function by Íñigo Quílez 
// https: // www.shadertoy.com / view / MdX3Rr 
// 
float3 getSkyColor(float3 rd) {
    float sundot = clamp(dot(rd , SUN_DIR) , 0.0 , 1.0);
     float3 col = float3 (0.2 , 0.5 , 0.85) * 1.1 - max(rd.y , 0.01) * max(rd.y , 0.01) * 0.5;
    col = lerp(col , 0.85 * float3 (0.7 , 0.75 , 0.85) , pow(1.0 - max(rd.y , 0.0) , 6.0));

    col += 0.25 * float3 (1.0 , 0.7 , 0.4) * pow(sundot , 5.0);
    col += 0.25 * float3 (1.0 , 0.8 , 0.6) * pow(sundot , 64.0);
    col += 0.20 * float3 (1.0 , 0.8 , 0.6) * pow(sundot , 512.0);

    col += clamp((0.1 - rd.y) * 10. , 0. , 1.) * float3 (.0 , .1 , .2);
    col += 0.2 * float3 (1.0 , 0.8 , 0.6) * pow(sundot , 8.0);
    return col;
 }

bool letterBox(float2 fragCoord , const float2 resolution , const float aspect) {
    if (fragCoord.x < 0. || fragCoord.x > resolution.x ||
        abs(2. * fragCoord.y - resolution.y) > resolution.x * (1. / aspect)) {
        return true;
     }
else {
return false;
}
}

// 
// Noise functions 
// 
// Hash without Sine by DaveHoskins 
// 
// https: // www.shadertoy.com / view / 4djSRW 
// 
float hash12(float2 p) {
    p = 50.0 * frac(p * 0.3183099);
    return frac(p.x * p.y * (p.x + p.y));
 }

float hash13(float3 p3) {
    p3 = frac(p3 * 1031.1031);
    p3 += dot(p3 , p3.yzx + 19.19);
    return frac((p3.x + p3.y) * p3.z);
 }

float3 hash33(float3 p3) {
     p3 = frac(p3 * float3 (.1031 , .1030 , .0973));
    p3 += dot(p3 , p3.yxz + 19.19);
    return frac((p3.xxy + p3.yxx) * p3.zyx);
 }

float valueHash(float3 p3) {
    p3 = frac(p3 * 0.1031);
    p3 += dot(p3 , p3.yzx + 19.19);
    return frac((p3.x + p3.y) * p3.z);
 }

// 
// Noise functions used for cloud shapes 
// 
float valueNoise(in float3 x , float tile) {
    float3 p = floor(x);
    float3 f = frac(x);
    f = f * f * (3.0 - 2.0 * f);

    return lerp(lerp(lerp(valueHash(mod(p + float3 (0 , 0 , 0) , tile)) ,
                        valueHash(mod(p + float3 (1 , 0 , 0) , tile)) , f.x) ,
                   lerp(valueHash(mod(p + float3 (0 , 1 , 0) , tile)) ,
                        valueHash(mod(p + float3 (1 , 1 , 0) , tile)) , f.x) , f.y) ,
               lerp(lerp(valueHash(mod(p + float3 (0 , 0 , 1) , tile)) ,
                        valueHash(mod(p + float3 (1 , 0 , 1) , tile)) , f.x) ,
                   lerp(valueHash(mod(p + float3 (0 , 1 , 1) , tile)) ,
                        valueHash(mod(p + float3 (1 , 1 , 1) , tile)) , f.x) , f.y) , f.z);
 }

float voronoi(float3 x , float tile) {
    float3 p = floor(x);
    float3 f = frac(x);

    float res = 100.;
    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                float3 b = float3 (i , j , k);
                float3 c = p + b;

                if (tile > 0.) {
                    c = mod(c , float3 (tile, tile, tile));
                 }

                float3 r = float3 (b)-f + hash13(c);
                float d = dot(r , r);

                if (d < res) {
                    res = d;
                 }
             }
         }
     }

    return 1. - res;
 }

float tilableVoronoi(float3 p , const int octaves , float tile) {
    float f = 1.;
    float a = 1.;
    float c = 0.;
    float w = 0.;

    if (tile > 0.) f = tile;

    for (int i = 0; i < octaves; i++) {
        c += a * voronoi(p * f , f);
        f *= 2.0;
        w += a;
        a *= 0.5;
     }

    return c / w;
 }

float tilableFbm(float3 p , const int octaves , float tile) {
    float f = 1.;
    float a = 1.;
    float c = 0.;
    float w = 0.;

    if (tile > 0.) f = tile;

    for (int i = 0; i < octaves; i++) {
        c += a * valueNoise(p * f , f);
        f *= 2.0;
        w += a;
        a *= 0.5;
     }

    return c / w;
 }

// Himalayas. Created by Reinder Nijhoff 2018 
// @reindernijhoff 
// 
// https: // www.shadertoy.com / view / MdGfzh 
// 
// This is my first attempt to render volumetric clouds in a fragment shader. 
// 
// 
// To create an interesting scene and to add some scale to the clouds , I render a 
// terrain using a simple heightmap , based on the work by Íñigo Quílez on value noise and its 
// analytical derivatives.[3] 
// 
// In fact , the heightmap of this shader is almost exactly the same as the heightmap that 
// is used in Íñigo Quílez' shader Elevated: 
// 
// https: // www.shadertoy.com / view / MdX3Rr 
// 
// To reduce noise I use temporal reprojection ( both for clouds ( Buffer D ) and the terrain 
// ( Buffer C ) ) separatly. The temporal reprojection code is based on code from the shader 
// "Rain Forest" ( again by Íñigo Quílez ) : 
// 
// https: // www.shadertoy.com / view / 4ttSWf 
// 
float3 noised(in float2 x) {
    float2 f = frac(x);
    float2 u = f * f * (3.0 - 2.0 * f);

    float2 p = float2 (floor(x));
    float a = hash12((p + float2 (0 , 0)));
     float b = hash12((p + float2 (1 , 0)));
     float c = hash12((p + float2 (0 , 1)));
     float d = hash12((p + float2 (1 , 1)));

     return float3 (a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y ,
                    6.0 * f * (1.0 - f) * (float2 (b - a , c - a) + (a - b - c + d) * u.yx));
 }

float2x2 m2 = float2x2 (1.6 , -1.2 , 1.2 , 1.6);

float terrainMap(in float2 x , const int OCTAVES) {
     float2 p = x * (MOUNTAIN_HW_RATIO * SCENE_SCALE);
    float s = lerp(1. , smoothstep(.0 , .4 , abs(p.y)) , .75);

    float a = 0.;
    float b = 1.;
     float2 d = float2 (0.0 , 0.0);
    for (int i = 0; i < OCTAVES; i++) {
        float3 n = noised(p);
        d += n.yz;
        a += b * n.x / (1.0 + dot(d , d));
          b *= 0.5;
        p = mul(m2 , p);
     }
     return s * a * (MOUNTAIN_HEIGHT * INV_SCENE_SCALE * .5);
 }

float terrainMapB(in float2 x , const int OCTAVES) {
     float2 p = x * (MOUNTAIN_HW_RATIO * SCENE_SCALE);
    float s = lerp(1. , smoothstep(.0 , .4 , abs(p.y)) , .75);

    float a = 0.;
    float b = 1.;
     float2 d = float2 (0.0 , 0.0);
    for (int i = 0; i < OCTAVES; i++) {
        float3 n = noised(p);
        d += n.yz;
        a += b * n.x / (1.0 + dot(d , d));
          b *= 0.5;
        p = mul(m2 , p);
     }
     return s * a * (MOUNTAIN_HEIGHT * INV_SCENE_SCALE * .5);
 }
float3 calcNormal(in float3 pos , float t , const int OCTAVES) {
    float2 eps = float2 ((0.0015) * t , 0.0);
    return normalize(float3 (terrainMap(pos.xz - eps.xy , OCTAVES) - terrainMap(pos.xz + eps.xy , OCTAVES) ,
                            2.0 * eps.x ,
                            terrainMap(pos.xz - eps.yx , OCTAVES) - terrainMap(pos.xz + eps.yx , OCTAVES)));
 }

float4 render(in float3 ro , in float3 rd) {
     float3 col , bgcol;

    float tmax = 10000.;
    // bouding top plane 
   float topd = ((MOUNTAIN_HEIGHT * INV_SCENE_SCALE) - ro.y) / rd.y;
   if (rd.y > 0.0 && topd > 0.0) {
       tmax = min(tmax , topd);
    }

   // intersect with heightmap 
  float t = 1.;
   for (int i = 0; i < 128; i++) {
      float3 pos = ro + t * rd;
        float h = pos.y - terrainMap(pos.xz , 7);
      if (abs(h) < (0.003 * t) || t > tmax) break; // use abs ( h ) to bounce back if under terrain 
       t += .9 * h;
    }

  bgcol = col = getSkyColor(rd);
   if (t < tmax) {
        float3 pos = ro + t * rd;
      float3 nor = calcNormal(pos , t , 15);

      // terrain color - just back and white 
     float s = smoothstep(0.5 , 0.9 , dot(nor , float3 (.3 , 1. , 0.05)));
     col = lerp(float3 (.01 , .01 , .01) , float3 (0.5 , 0.52 , 0.6) , smoothstep(.1 , .7 , s));

     // lighting 
     // shadow is calculated based on the slope of a low frequency version of the heightmap 
    float shadow = .5 + clamp(-8. + 16. * dot(SUN_DIR , calcNormal(pos , t , 5)) , 0.0 , .5);
    shadow *= smoothstep(20. , 80. , pos.y);

    float ao = terrainMap(pos.xz , 10) - terrainMap(pos.xz , 7);
    ao = clamp(.25 + ao / (MOUNTAIN_HEIGHT * INV_SCENE_SCALE) * 200. , 0. , 1.);

    float ambient = max(0.5 + 0.5 * nor.y , 0.0);
      float diffuse = max(dot(SUN_DIR , nor) , 0.0);
      float backlight = max(0.5 + 0.5 * dot(normalize(float3 (-SUN_DIR.x , 0. , SUN_DIR.z)) , nor) , 0.0);

      // 
      // use a 3 - light setup as described by Íñigo Quílez 
      // http: // iquilezles.org / www / articles / outdoorslighting / outdoorslighting.htm 
      // 
       float3 lin = (diffuse * shadow * 3.) * SUN_COLOR;
       lin += (ao * ambient) * float3 (0.40 , 0.60 , 1.00);
     lin += (backlight) * float3 (0.40 , 0.50 , 0.60);
       col *= lin;
     col *= (.6 + .4 * smoothstep(400. , 100. , abs(pos.z))); // dark in the distance 

      // height based fog , see http: // iquilezles.org / www / articles / fog / fog.htm 
     float fogAmount = HEIGHT_BASED_FOG_C * (1. - exp(-t * rd.y * HEIGHT_BASED_FOG_B)) / rd.y;
     col = lerp(col , bgcol , fogAmount);
  }
else {
t = 10000.;
}

return float4 (col , t);
}


bool resolutionChanged() {
    return floor(pointSampleTex2D(_Channel1 , sampler_Channel1 , int2 (0,0) ).r) != floor(_ScreenParams.x);
 }

bool mouseChanged() {
    //return iMouse.z * pointSampleTex2D(_Channel1, sampler_Channel1, int2 (1, 0), 1).w < 0.;
    return iMouse.z * pointSampleTex2D(_Channel1 , sampler_Channel1 , int2 (1 , 0) , 1).w < 0.;
 }

half4 LitPassFragment(Varyings input) : SV_Target  {
UNITY_SETUP_INSTANCE_ID(input);
UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

m2 = float2x2 (1.6, -1.2, 1.2, 1.6);

 half4 fragColor = half4 (1 , 1 , 1 , 1);
 float2 fragCoord = ((input.screenPos.xy) / (input.screenPos.w + FLT_MIN)) * _ScreenParams.xy;
     if (letterBox(fragCoord , _ScreenParams.xy , 2.25)) {
         fragColor = float4 (0. , 0. , 0. , 1.);
         return fragColor;
      }
 else {
 float3 ro , rd;
 float3 o = hash33(float3 (fragCoord , iFrame)) - 0.5; // dither 
 getRay(_Time.y , (fragCoord + o.xy) , _ScreenParams.xy , iMouse / _ScreenParams.xyxy , ro , rd);

 float4 res = render(ro + rd * o.z , rd);

 float2 spos = reprojectPos(ro + rd * res.w , _ScreenParams.xy , _Channel1 , sampler_Channel1);
 spos -= o.xy / _ScreenParams.xy; // undo dither 

 float2 rpos = spos * _ScreenParams.xy;

 if (!letterBox(rpos.xy , _ScreenParams.xy , 2.3)
     && !resolutionChanged() && !mouseChanged()) {
     float4 ocol = SAMPLE_TEXTURE2D(_Channel0 , sampler_Channel0 , spos );
     res.rgb = lerp(max(ocol.rgb , float3 (0 , 0 , 0)) , res.rgb , .125);
  }

 fragColor = res;
}
return fragColor;
}

//half4 LitPassFragment(Varyings input) : SV_Target
//{
//    [FRAGMENT]
//    //float2 uv = input.uv;
//    //SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_BaseMap, uv + float2(-onePixelX, -onePixelY), _Lod);
//    //_ScreenParams.xy 
//    //half4 color = half4(1, 1, 1, 1);
//    //return color;
//}
ENDHLSL
}
        }
}