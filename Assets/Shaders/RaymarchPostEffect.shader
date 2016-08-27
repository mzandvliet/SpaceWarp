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
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"

			float4 _FrustumCorners[4];

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

				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
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
				return sin(_Time[1] * PI * freq);
			}

			float toDc(float val) {
				return 0.5 + 0.5 * val;
			}

			//-----------------------------------------------------------------------------------------
			// Scene Mapping
			//-----------------------------------------------------------------------------------------

			float sdAnimatedSpheres(float3 p) {
				return sdSMin(
					sdSphere(p, float3(-1, 0, 0), (0.5 + 0.5 * toDc(sinOsc(1.0)) * 4)),
					sdSphere(p, float3( 1, 0, 0), (0.3 + 0.7 * toDc(sinOsc(1.1)) * 3)),
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
				return sdMorpingBoxSpheres(p);
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
				const float eps = 0.01;

				return normalize(
					float3(
						map(p + float3(eps, 0, 0)) - map(p - float3(eps, 0, 0)),
						map(p + float3(0, eps, 0)) - map(p - float3(0, eps, 0)),
						map(p + float3(0, 0, eps)) - map(p - float3(0, 0, eps))
						)
				);
			}

			// Todo
			float3 render(float3 p, float r) {
				const float3 l = normalize(float3(-1, 4, -2)); // single const direction light

				float3 n = mapNormal(p);
				float3 c = float3(1, 0, 0);
				c = lambert(n, l, r, c, 1, 1.4);
				return c;
			}

			//-----------------------------------------------------------------------------------------
			// RayMarch
			//-----------------------------------------------------------------------------------------

			float4 RayMarch(float3 rayStart, float3 rayDir)
			{
				const float dMin = 0.001;

				float3 p = rayStart;
				for (int i = 0; i < 64; i++) {
					float d = map(p);

					if (d < dMin) {
						return float4(render(p, rayDir), 1);
					}

					p += rayDir * d;
				}

				return float4(1, 1, 1, 1);
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
				float3 rayDir = normalize(wpos - _WorldSpaceCameraPos);

				float4 color = RayMarch(rayStart, rayDir);

				return color;
			}
			ENDCG
		}
	}
}

