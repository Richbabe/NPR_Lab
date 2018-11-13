Shader "NPR_Lab/SurfaceAngleSilhouette" {
	Properties {
		_Color("Diffuse Color", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Outline ("Outline", Range(0,1)) = 0.4
		_SilhouetteTex ("Silhouette Texture", 2D) = "White" {}
	}
	SubShader {
		Pass{
			Tags{ "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM
			#include "UnityCG.cginc"
			#include "Lighting.cginc"  
			#include "AutoLight.cginc" 

			#pragma vertex vert
			#pragma fragment frag

			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Outline;
			sampler2D _SilhouetteTex;

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
			};

			//顶点着色器
			v2f vert(appdata_full v) {
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				return o;
			}

			//通过一个参数_Outline作为阈值来控制轮廓线宽度
			fixed3 GetSilhouetteUseConstant(fixed3 normal, fixed3 viewDir) {
				fixed edge = saturate(dot(normal, viewDir));
				edge = edge < _Outline ? edge / 4 : 1;

				return fixed3(edge, edge, edge);
			}

			//通过一张一维纹理来控制轮廓线宽度
			fixed3 GetSilhouetteUseTexture(fixed3 normal, fixed3 viewDir) {
				fixed edge = dot(normal, viewDir);
				edge = edge * 0.5 + 0.5;//从[-1,1]转化到[0,1]作为纹理采样坐标
				return tex2D(_SilhouetteTex, fixed2(edge, edge)).rgb;
			}

			//片段着色器
			fixed4 frag(v2f i) : SV_Target{
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldViewDir = UnityWorldSpaceViewDir(i.worldPos);

				fixed3 col = tex2D(_MainTex, i.uv).rgb;

				//通过一个参数_Outline作为阈值来控制轮廓线宽度
				//fixed3 silhouetteColor = GetSilhouetteUseConstant(worldNormal, worldViewDir);

				//通过一张一维纹理来控制轮廓线宽度
				fixed3 silhouetteColor = GetSilhouetteUseTexture(worldNormal, worldViewDir);

				fixed4 fragColor;
				fragColor.rgb = _Color * silhouetteColor;//混合模型颜色和边缘颜色
				fragColor.a = 1;

				return fragColor;
			}

			ENDCG
		}
	}
	FallBack "Diffuse"
}
