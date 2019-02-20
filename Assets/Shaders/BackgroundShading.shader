///
///  Reference: 	Lake A, Marshall C, Harris M, et al. Stylized rendering techniques for scalable real-time 3D animation[C]
///						Proceedings of the 1st international symposium on Non-photorealistic animation and rendering. ACM, 2000: 13-20.
///

Shader "NPR_Lab/BackgroundShading" {
	Properties {
		_Color("Diffuse Color", Color) = (1, 1, 1, 1)
		_MainTex("Paper Texture", 2D) = "white" {}
	}
	SubShader{
		Tags { "RenderType" = "Opaque" }
		LOD 200

		Pass{
			Tags{ "LightMode" = "ForwardBase" }

			Cull Back

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdbase

			#pragma glsl

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"

			fixed4 _Color;
			sampler2D _MainTex;

			// 定义顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			};

			// 定义顶点着色器输出
			struct v2f {
				float4 pos : POSITION;
				float4 scrPos : TEXCOORD0;  // 保存屏幕空间坐标
			};

			// 定义顶点着色器
			v2f vert(a2v v) {
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex);
				o.scrPos = ComputeScreenPos(o.pos);  // 计算屏幕空间坐标

				return o;
			}

			// 定义像素着色器
			float4 frag(v2f i) : COLOR{
				fixed2 scrPos = i.scrPos.xy / i.scrPos.w;  // 获取屏幕空间uv坐标
				fixed3 fragColor = tex2D(_MainTex, scrPos);  // 用屏幕空间uv坐标进行采样

				fragColor *= _Color.rgb;

				return fixed4(fragColor, 1.0);
			}

			ENDCG
		}
	}
}
