
Shader "ImageEffects/RaymarchPostEffect" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            float4 _FrustumCorners[4];
            sampler2D _primBuffer;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                uint vertexId : SV_VertexID;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wpos : TEXCOORD1;
            };

            v2f vert (appdata v) {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.wpos = _FrustumCorners[v.vertexId];

                return o;
            }
            
            sampler2D _MainTex;
            float _MaxRayLength;

         
            //-----------------------------------------------------------------------------------------
            // Distance Field Operators
            //-----------------------------------------------------------------------------------------

            #define PI 3.14159265

            float sdSMin(float a, float b, float k = 16) {
                float res = exp(-k * a) + exp(-k * b);
                return -log(max(0.0001, res)) / k;
            }

            float sdBlend(float d1, float d2, float a) {
                return a * d1 + (1 - a) * d2;
            }

            //-----------------------------------------------------------------------------------------
            // Distance Field Primitives
            //-----------------------------------------------------------------------------------------

            float sdSphere(float3 p, float3 sp, float r)             {
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
                return sin(0 * PI * freq); //_Time[1]
            }

            float cosOsc(float freq) {
                return cos(0 * PI * freq); //_Time[1]
            }

            float toDc(float val) {
                return 0.5 + 0.5 * val;
            }

            float rand(float n) {
                return frac(sin(n) * 43758.5453123);
            }

            //-----------------------------------------------------------------------------------------
            // Scene Mapping (The actual distance fields, you know)
            //-----------------------------------------------------------------------------------------

            float sdAnimatedSpheres(float3 p) {
                return sdSMin(
                    sdSphere(p, float3(-1, 1, 0), (0.5 + 0.5 * toDc(sinOsc(1.0)) * 1)),
                    sdSphere(p, float3( 1, 1, 0), (0.3 + 0.7 * toDc(sinOsc(1.1)) * 2)),
                    8
                );
            }

            float sdMorpingBoxSpheres(float3 p, float3 c) {
                return sdBlend(
                    sdAnimatedSpheres(p),
                    sdBox(p, c, float3(2, 1, 1)),
                    toDc(sinOsc(0.45))
                );
            }

            float map(float3 p) {
                return sdSMin(
                    sdBox(p, float3(0, -0.7, 0), float3(10, 1, 10)),
                    sdSMin(
                        sdSphere(p, float3(sinOsc(0.25), 1, cosOsc(0.25)), 0.33),
                        sdMorpingBoxSpheres(p, float3(0,0.6,0)))
                );
            }

            // Todo: can we generalize lighting functions and pass then a context defined here?
            // Function pointers or macros or something

            float3 mapNormal(float3 p) {
                // Expensive finite differencing to find surface normal

                const float eps = 0.001;

                return normalize(float3(
                    map(p + float3(eps, 0, 0)) - map(p - float3(eps, 0, 0)),
                    map(p + float3(0, eps, 0)) - map(p - float3(0, eps, 0)),
                    map(p + float3(0, 0, eps)) - map(p - float3(0, 0, eps))
                ));
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

            float shade(float3 rayStart, float3 rayDir) {
                // Basic shadow casting, testing to see if a light can be reached
                // from the chosen starting point

                const float dMin = 0.0033;
                const float dMax = 16.0;
                const int maxSteps = 64;

                float dist = 0;

                for (int i = 0; i < maxSteps; i++) {
                    float3 p = rayStart + rayDir * dist;
                    float d = map(p);

                    if (dist > dMax) {
                        return 1.0;
                    }
                    if (d < dMin) {
                        return 0.0;
                    }

                    dist += d;
                }

                return 1.0;
            }

            float3 render(float3 p, float3 r) {
                // single const directional light
                const float3 l = normalize(float3(-3, 3, -5));

                float3 n = mapNormal(p);
                float3 c = float3(1, 1, 1); // Base material color
                c = lambert(n, l, r, c, 2.0, 1.0); // Diffuse/specular
                c *= shade(p + n * 0.05, l); // Trick: offset march start pos to get out of min-distance region
                c += float3(0.1, 0.1, 0.2); // constant ambient term
                return c;
            }

            float3 renderPerf(float3 p, float r, float numSteps) {
                // Rendered color represents cost of sampling operations
                return lerp(float3(1, 1, 1), float3(1, 0, 0), numSteps);
            }

            //-----------------------------------------------------------------------------------------
            // RayMarch
            //-----------------------------------------------------------------------------------------

            float4 rayMarch(float3 rayStart, float3 rayDir) {
                const float dMin = 0.002;
                const float dMax = 32.0;
                const int maxSteps = 128;
                const float maxStepsInv = 1.0 / (float)maxSteps;

                const float4 background = float4(0.3, 0.2, 0.7, 1);

                float dist = 0;
                for (int i = 0; i < maxSteps; i++) {
                    float3 p = rayStart + rayDir * dist;
                    float d = map(p);

                    if (dist > dMax) {
                        // Escape? background color
                        return background;
                    }
                    if (d < dMin) {
                        // Hit boundary? object color
                        return float4(render(p, rayDir), 1);
                    }

                    dist += d;
                }

                return background;
            }

            //-----------------------------------------------------------------------------------------
            // Fragment Shader
            //-----------------------------------------------------------------------------------------

            fixed4 frag (v2f i) : SV_Target {
                // Todo: Integrate with Unity's rendering pipeline through depth buffer

                //float2 uv = i.uv.xy;
                //float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
                //float linearDepth = Linear01Depth(depth);

                // Crude multisampling for anti-aliasing

                const int raysPerPix = 5;
                const float raysPerPixF = (float)raysPerPix;

                float4 color = float4(0, 0, 0, 0);
                for (int r = 0; r < raysPerPix; r++) {
                    float3 noise = float3(
                        rand(0.1 * (float)r),
                        rand(0.2 * (float)r),
                        rand(0.3 * (float)r));

                    float3 rayDir = normalize(i.wpos - _WorldSpaceCameraPos + noise);

                    color += rayMarch(_WorldSpaceCameraPos, rayDir);
                }
                color /= raysPerPixF;
               
                return color;
            }
            ENDCG
        }
    }
}

