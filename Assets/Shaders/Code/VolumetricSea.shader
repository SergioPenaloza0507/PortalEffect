Shader "XEXO/URP/CloudSea"
{
    Properties
    { 
        _MainTex("Main Texture", 2D) = "white" {}
        _Color ("Normal Color", color) = (1.0,1.0,1.0,1.0)
        _Displacement("Displacement map", 2D) = "bump" {}
        _DisplacementAmount ("Displacement amount", float) = 0.0
        _HeightWs ("World Space Height", float) = 0.0
        _DisplacementMapping("Displacement Mapping", vector) = (1.0,1.0,0.0,0.0)
        _NoiseDithering("Noise Dithering", 2D) = "grey" {}
    }
 
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            HLSLPROGRAM
            #define SDF_EPSILON 0.1
            #define NORMAL_EPSILON 0.01
            #define  RAY_MARCH_SAMPLING_RATE 1024
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 texcoord     : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 texcoord     : TEXCOORD0;
                float3 rayPosWS     : TEXCOORD2;
                float3 rayDirWS     : TEXCOORD3;
                float2 texcoordMain : TEXCOORD4;
            };

            half4 _Color;
            sampler2D _Displacement;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NoiseDithering;
            float4 _NoiseDithering_ST;
            half _DisplacementAmount;
            half _HeightWs;
            float4 _SphereDescription;

            uniform float4x4 _InverseProjectionMatrix;
            uniform float4x4 _InverseViewMatrix;
            uniform float3 _WorldSpaceCameraPosition;

            float4 _DisplacementMapping;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.texcoord = (IN.texcoord * _NoiseDithering_ST.xy) + _NoiseDithering_ST.zw;
                float4 homogenousClipSpace = OUT.positionHCS;
                homogenousClipSpace.y *= -1;
                float4 worldSpacePos = mul(_InverseViewMatrix, mul(_InverseProjectionMatrix, homogenousClipSpace));
                OUT.rayPosWS = worldSpacePos.xyz / worldSpacePos.w;
                OUT.rayDirWS = normalize(OUT.rayPosWS - _WorldSpaceCameraPosition);
                OUT.texcoordMain = IN.texcoord;
                return OUT;
            }

            float SDVolumetricSea(float3 rayPosWS, half midLevel, sampler2D heightMap, half displacementMultiplier)
            {
                return distance(float3(rayPosWS.x, midLevel + tex2D(heightMap, (rayPosWS.xz + _DisplacementMapping.zw) / _DisplacementMapping.xy).r * displacementMultiplier, rayPosWS.z), rayPosWS);
            }

            float4 RayMarch(float3 rayPosWS, float3 rayDirWS, half midLevel, sampler2D heightMap, half displacementMultiplier)
            {
                [loop]for(float i = 0; i < RAY_MARCH_SAMPLING_RATE; i ++)
                {
                    const float dist = SDVolumetricSea(rayPosWS, midLevel, heightMap, displacementMultiplier);
                    if(dist < SDF_EPSILON)
                    {
                        return float4(normalize
                        (
                          float3
                          (
                              SDVolumetricSea(rayPosWS - float3(NORMAL_EPSILON, 0.0, 0.0), midLevel, heightMap, displacementMultiplier) - SDVolumetricSea(rayPosWS + float3(NORMAL_EPSILON, 0.0, 0.0),  midLevel, heightMap, displacementMultiplier),
                              SDVolumetricSea(rayPosWS - float3(0.0, NORMAL_EPSILON, 0.0), midLevel, heightMap, displacementMultiplier) - SDVolumetricSea(rayPosWS + float3(0.0, NORMAL_EPSILON, 0.0),  midLevel, heightMap, displacementMultiplier),
                              SDVolumetricSea(rayPosWS - float3(0.0, 0.0, NORMAL_EPSILON), midLevel, heightMap, displacementMultiplier) - SDVolumetricSea(rayPosWS + float3(0.0, 0.0, NORMAL_EPSILON),  midLevel, heightMap, displacementMultiplier)
                          )  
                        ), 1.0);
                    }
                    rayPosWS += rayDirWS * (_ProjectionParams.z / RAY_MARCH_SAMPLING_RATE);
                }
                return 0.0;
            }
            
            float4 VolumetricSeaSDF(float3 rayPosWS, float3 rayDirWS, half midLevel, sampler2D heightMap, half displacementMultiplier)
            {
                return float4(RayMarch(rayPosWS, rayDirWS, midLevel, heightMap, displacementMultiplier));
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float4 normDepth = VolumetricSeaSDF(IN.rayPosWS, IN.rayDirWS, _HeightWs, _Displacement, _DisplacementAmount);
                float lighting = saturate(dot(_MainLightPosition.xyz, -normDepth.xyz)) * tex2D(_NoiseDithering, IN.texcoord);
                //return float4(-normDepth.xyz, 1.0);
                return lighting * normDepth.w;
            }
            ENDHLSL
        }
    }
}