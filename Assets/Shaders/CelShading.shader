Shader "NPR_Lab/CelShading" {
	Properties {
		_Color ("Color Tint", Color) = (1,1,1,1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_Ramp ("Ramp Texture", 2D) = "white" {} //控制漫反射色调的渐变纹理
		_Outline ("Outline", Range(0,1)) = 0.1 //用于控制轮廓线的宽度
		_OutlineColor ("Outline Color", Color) = (1,1,1,1) //轮廓线的颜色
		_Specular ("Specular", Color) = (1,1,1,1) //高光反射的颜色
		_SpecularScale ("Specular Scale", Range(0,0.1)) = 0.01
	}
	SubShader {
		Tags { "RenderType"="Opaque" "Queue" = "Geometry"}
		
		//使用过程式几何轮廓渲染方法来描边
		UsePass "NPR_Lab/ToneBasedShading/OUTLINE"

		//渲染模型正面的Pass
		Pass{
			Tags {"LightMode" = "ForwardBase"}

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
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Ramp;
			fixed4 _Specular;
			fixed _SpecularScale;

			//顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			};

			//顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			//定义顶点着色器
			v2f vert(a2v v) {
				v2f o;
				
				//模型空间到裁剪空间的坐标变化
				o.pos = UnityObjectToClipPos(v.vertex);

				o.worldNormal = UnityObjectToWorldNormal(v.normal);

				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				TRANSFER_SHADOW(o);

				return o;
			}

			//定义片段着色器
			float4 frag(v2f i) : SV_Target{
				//计算所需的方向向量
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);

				fixed4 c = tex2D(_MainTex, i.uv);
				fixed3 albedo = c.rgb * _Color.rgb;

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);//计算阴影系数

				fixed diff = dot(worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5) * atten;

				fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;

				float spec = dot(worldNormal, worldHalfDir);
				float w = fwidth(spec) * 2.0;//实现抗锯齿
				spec = lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1));
				fixed3 specular = _Specular.rgb * spec * step(0.0001, _SpecularScale);

				fixed3 color = ambient + diffuse + specular;
				return float4(color, 1.0);

			}
			ENDCG
		}

		//增加多一个Pass叠加效果
		Pass{
			Tags{ "LightMode" = "ForwardAdd" }

			Blend One One

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdadd

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"

			//定义Properties变量
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Ramp;
			fixed4 _Specular;
			fixed _SpecularScale;

			//顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			};

			//顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			//定义顶点着色器
			v2f vert(a2v v) {
				v2f o;

				//模型空间到裁剪空间的坐标变化
				o.pos = UnityObjectToClipPos(v.vertex);

				o.worldNormal = UnityObjectToWorldNormal(v.normal);

				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				TRANSFER_SHADOW(o);

				return o;
			}

			//定义片段着色器
			float4 frag(v2f i) : SV_Target{
				//计算所需的方向向量
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);

				fixed4 c = tex2D(_MainTex, i.uv);
				fixed3 albedo = c.rgb * _Color.rgb;

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);//计算阴影系数

				fixed diff = dot(worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5) * atten;

				fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;

				float spec = dot(worldNormal, worldHalfDir);
				float w = fwidth(spec) * 2.0;//实现抗锯齿
				spec = lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1));
				fixed3 specular = _Specular.rgb * spec * step(0.0001, _SpecularScale);

				fixed3 color = diffuse + specular;
				return float4(color, 1.0);

			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
