Shader "ysj/NoiseDissolve" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NoiseTex("Noise Tex",2D) = "white" {}
		_DissolvePoint("Dissolve point", Vector) = (0,0,0,0)
		_DissolveAmount("Disolve amount", Range(0,2)) = 1
		_MaxDistance("Max distance", float) = 1
		_Intensity("Intensity", Range(0,6)) = 1
		_NoiseFreq("Noise frequency", float) = 1
		_Border("Border size", float) = 0.1
		_BorderColor("Border color", Color) = (1,0,0,1)
		_BorderEmission("Border emission", Color) = (1,0,0,1)
		[Toggle]_Inverse("Inverse", float) = 0
	}


	SubShader {
		Tags {
            "Queue"="AlphaTest"
            "RenderType"="TransparentCutout"
        }

		Pass {
			Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            Cull back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define UNITY_PASS_FORWARDBASE

            #include "UnityCG.cginc"
            #include "noiseSimplex.cginc"

            #pragma multi_compile_fwdbase_fullshadows
            #pragma exclude_renderers d3d11_9x xbox360 xboxone ps3 ps4 psp2 
            #pragma target 2.0

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NoiseTex;

			fixed4 _Color;
			fixed _NoiseFreq;
			fixed _Border;
			fixed _Inverse;
			fixed4 _BorderColor;
			fixed4 _BorderEmission;

			uniform fixed _DissolveAmount;
			uniform fixed _MaxDistance;
			uniform fixed _Intensity;
			uniform float3 _DissolvePoint;


            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 worldPos : TEXCOORD1;
            };

            v2f vert (appdata v) {
                v2f o = (v2f)0;
                o.pos = mul(UNITY_MATRIX_MVP, v.vertex );
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);


                return o;
            }


            float4 frag(v2f i) : SV_Target {

	                // texture and color
					fixed4 color = tex2D(_MainTex, i.uv) * _Color;

					// calculate distance between current position and dissolve point
					float dist = distance(i.worldPos, _DissolvePoint);

					// get gradient by distance
					float gradient = clamp(dist / _MaxDistance, 0, 2);

					// calculate final value
					float finalValue = (_DissolveAmount - gradient) * _Intensity;

					// Inverse
					finalValue = lerp(finalValue, 1 - finalValue, _Inverse);

					// snoise is expensive
					// do not call it if we are sure the final value is large enough
					if (finalValue > _Border + 1) {
						discard;
					}

					// get noise by world position, snoise return -1~1
					// make the noise 0~1
					//for pc
//					float ns = snoise(i.worldPos * _NoiseFreq) / 2 + 0.5f;

					//for mobile
					float4 worldPosNoise =  i.worldPos * _NoiseFreq;
					float ns = tex2D(_NoiseTex, float2(worldPosNoise.x, worldPosNoise.y)).r;

					if (ns + _Border < finalValue) {
						discard;
					}

					// after clip, ns should be finalValue ~ (finalValue - _Border)
					// if (finalValue >= ns)
					//		isBorder
					// else
					//		!isBorder
					fixed isBorder = step(ns, finalValue);


					fixed4 albedo = lerp(color, _BorderColor, isBorder);
					fixed4 emission = lerp(fixed4(0, 0, 0, 0), _BorderEmission, isBorder);

					return  albedo + emission ;

            }
            ENDCG

		}
	}


	FallBack "Diffuse"
}