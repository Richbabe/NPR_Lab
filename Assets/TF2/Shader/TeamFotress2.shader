Shader "NPR_Lab/TeamFotress2" {
	Properties {
		_Color("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_RampTex ("Ramp Texture", 2D) = "white" {}
	}
	SubShader {
		Pass{
			Tags{"LightMode" = "ForwardBase"}

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"

			//定义Properties变量
			fixed4 _Color;
			sampler2D _MainTex;//主纹理贴图
			float4 _MainTex_ST;
			sampler2D _RampTex;//漫反射变形贴图，通过查找映射创建一个硬阴影
			float4 _RampTex_ST;

			//定义顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			};

			//定义顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float2 mainTex_uv : TEXCOORD2;
				float2 rampTex_uv : TEXCOORD3;
			};

			//顶点着色器
			v2f vert(a2v v) {
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				o.mainTex_uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.rampTex_uv = TRANSFORM_TEX(v.texcoord, _RampTex);

				return o;
			}

			//片段着色器
			fixed4 frag(v2f i) : SV_Target{
				//计算所需的方向向量
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

				//计算非视角相关部分
				fixed4 c = tex2D(_MainTex, i.mainTex_uv) * _Color;
			    fixed3 kd = c.rgb;//albedo

				half difLight = dot(worldNormal, worldLightDir);//n·l
				half halfLambert = pow(0.5 * difLight + 0.5, 1.0);//半兰伯特因子

				half3 ramp = tex2D(_RampTex, float2(halfLambert, halfLambert)).rgb;//漫反射变形
				half3 difWarping = ramp * 2;//乘2使得模型更加明亮
				half3 difLightTerm = _LightColor0.rgb * difWarping;



				return fixed4(difLightTerm,1.0);
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
