// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "ImageEffects/RaymarchPostEffect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            float4 _FrustumCorners[4];
            sampler2D _primBuffer;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                uint vertexId : SV_VertexID;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wpos : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.wpos = _FrustumCorners[v.vertexId];

                return o;
            }
            
            sampler2D _MainTex;
            float _MaxRayLength;

            /*

            Todo:

            Reduce per pixel ray/map evaluation by culling (e.g. this ray will never hit this element of map())

            - lods?
            - adaptive or sparse mapping

            Quality increase

            - adaptive supersampling for antialiasing

            */

            //-----------------------------------------------------------------------------------------
            // Distance Field Operators
            //-----------------------------------------------------------------------------------------

            #define PI 3.14159265

            float sdSMin(float a, float b, float k = 32) {
                float res = exp(-k * a) + exp(-k * b);
                return -log(max(0.0001, res)) / k;
            }

            float sdBlend(float d1, float d2, float a) {
                return a * d1 + (1 - a) * d2;
            }

            //-----------------------------------------------------------------------------------------
            // Distance Field Primitives
            //-----------------------------------------------------------------------------------------

            float sdSphere(float3 p, float3 sp, float r)
            {
                return length(p-sp) - r;
            }

            float sdBox(float3 p, float3 c, float3 s) {
                float x = max(
                    p.x - c.x - float3(s.x * 0.5, 0, 0),
                    c.x - p.x - float3(s.x * 0.5, 0, 0)
                );

                float y = max(
                    p.y - c.y - float3(s.y * 0.5, 0, 0),
                    c.y - p.y - float3(s.y * 0.5, 0, 0)
                );

                float z = max(
                    p.z - c.z - float3(s.z * 0.5, 0, 0),
                    c.z - p.z - float3(s.z * 0.5, 0, 0)
                );

                float d = x;
                d = max(d, y);
                d = max(d, z);
                return d;
            }

            //-----------------------------------------------------------------------------------------
            // Utilities
            //-----------------------------------------------------------------------------------------

            float sinOsc(float freq) {
                return sin(0.0 * PI * freq); //_Time[1]
            }

            float toDc(float val) {
                return 0.5 + 0.5 * val;
            }

            //-----------------------------------------------------------------------------------------
            // Scene Mapping
            //-----------------------------------------------------------------------------------------

            float sphereFloor(float3 p, float3 c) {
                //float3 q = fmod(p, c) - 0.5 * c;

                p.y +=
                    sin(frac(p.x / 16 + _Time[1] * 0.5) * PI) * _SinTime[3] *
                    sin(frac(p.z / 16 + _Time[1] * 0.25) * PI) * _SinTime[2] *
                    4;

                float r = sin(frac(p.x / 16 + _Time[1] * 0.5) * PI) * _SinTime[3] *
                    sin(frac(p.z / 16 + _Time[1] * 0.25) * PI) * _SinTime[2] *
                    0.5 + 0.5;

                float3 q = p;
                q.x = fmod(p.x, c.x) - 0.5 * c.x;
                q.z = fmod(p.z, c.z) - 0.5 * c.z;
                return sdSphere(q, float3(0, -1, 0), r);
            }

            float sdAnimatedSpheres(float3 p) {
                return sdSMin(
                    sdSphere(p, float3(-1, 0, 0), (0.5 + 0.5 * toDc(sinOsc(1.0)) * 1)),
                    sdSphere(p, float3( 1, 0, 0), (0.3 + 0.7 * toDc(sinOsc(1.1)) * 2)),
                    8
                );
            }

            float sdMorpingBoxSpheres(float3 p) {
                return sdBlend(
                    sdAnimatedSpheres(p),
                    sdBox(p, float3(0, 0, 0), float3(2, 1, 1)),
                    toDc(sinOsc(0.45))
                );
            }

            float map(float3 p) {
                /*
                // Todo: lol this is the worst idea for rendering distance field compositions
                const int numPrims = 8;
                float d = 999999.0;
                for (uint i = 0; i < numPrims; i++) {
                    float4 primInfo = tex2D(_primBuffer, half2(i / numPrims + (1.0/numPrims), 0));
                    d = min(d, sdSphere(p, primInfo.xyz, primInfo.w));
                }
                return d;
                */

                return sdSMin(sdSphere(p, float3(0, 0, 0), 1), sdMorpingBoxSpheres(p));
            }

            //-----------------------------------------------------------------------------------------
            // Lighting
            //-----------------------------------------------------------------------------------------
            
            float3 lambert(float3 n, float3 l, float3 r, float3 albedo, float specPow, float specGloss) {
                // Simple lambert with specular
                float nDotL = max(dot(n, l), 0);
                float3 h = (l - r) * 0.5;
                float s = pow(dot(n, h), specPow) * specGloss;
                return albedo * nDotL * s;
            }

            // Todo: can we generalize lighting functions and pass then a context defined here?
            // Function pointers or macros or something

            float3 mapNormal(float3 p) {
                const float eps = 0.001;

                return normalize(
                    float3(
                        map(p + float3(eps, 0, 0)) - map(p - float3(eps, 0, 0)),
                        map(p + float3(0, eps, 0)) - map(p - float3(0, eps, 0)),
                        map(p + float3(0, 0, eps)) - map(p - float3(0, 0, eps))
                        )
                );
            }


            float3 render(float3 p, float3 r) {
                const float3 l = normalize(float3(-1, 4, -2)); // single const direction light

                float3 n = mapNormal(p);
                float3 c = float3(1, 0, 0);
                c = lambert(n, l, r, c, 1, 1.4);
                return c;
            }

            float3 renderPerf(float3 p, float r, float numSteps) {
                return lerp(float3(1, 1, 1), float3(1, 0, 0), numSteps);
            }

            //-----------------------------------------------------------------------------------------
            // RayMarch
            //-----------------------------------------------------------------------------------------

            float4 RayMarch(float3 rayStart, float3 rayDir)
            {
                const float dMin = 0.01;
                const int maxSteps = 512;
                const float maxStepsInv = 1.0 / (float)maxSteps;

                float3 p = rayStart;
                
                for (int i = 0; i < maxSteps; i++) {
                    float d = map(p);

                    if (d < dMin) {
                        return float4(render(p, rayDir), 1);
                        //return float4(renderPerf(p, rayDir, (float)i * maxStepsInv), 1);
                    }

                    p += rayDir * d;
                }

                return float4(1, 1, 1, 1);
            }

            float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float4 mod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float4 perm(float4 x) { return mod289(((x * 34.0) + 1.0) * x); }

            float noise(float3 p) {
                float3 a = floor(p);
                float3 d = p - a;
                d = d * d * (3.0 - 2.0 * d);

                float4 b = a.xxyy + float4(0.0, 1.0, 0.0, 1.0);
                float4 k1 = perm(b.xyxy);
                float4 k2 = perm(k1.xyxy + b.zzww);

                float4 c = k2 + a.zzzz;
                float4 k3 = perm(c);
                float4 k4 = perm(c + 1.0);

                float4 o1 = frac(k3 * (1.0 / 41.0));
                float4 o2 = frac(k4 * (1.0 / 41.0));

                float4 o3 = o2 * d.z + o1 * (1.0 - d.z);
                float2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

                return o4.y * d.y + o4.x * (1.0 - d.y);
            }

            //-----------------------------------------------------------------------------------------
            // Fragment Shader
            //-----------------------------------------------------------------------------------------

            fixed4 frag (v2f i) : SV_Target
            {
                //float2 uv = i.uv.xy;
                //float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
                //float linearDepth = Linear01Depth(depth);

                float3 wpos = i.wpos;
                float3 rayStart = _WorldSpaceCameraPos;
                float3 rayDir = normalize(wpos - _WorldSpaceCameraPos//);
                    + noise(float3(-1.0 + 2.0 * i.uv.x, -1.0 + 2.0 * i.uv.y, _Time[3] * 10) * 10.0));

                float4 color = RayMarch(rayStart, rayDir);

                return color;
            }
            ENDCG
        }
    }
}

