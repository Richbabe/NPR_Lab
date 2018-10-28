Shader "NPR_Lab/AntialiasedCelShading" {
	Properties {
		_MainTex("Main Tex", 2D) = "white" {}
		_Outline("Outline", Range(0,1)) = 0.1
		_OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
		_DiffuseColor("Diffuse Color", Color) = (1, 1, 1, 1)
		_SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
		_Shininess("Shininess", Range(1, 500)) = 40
		_DiffuseSegment("Diffuse Segment", Vector) = (0.1, 0.3, 0.6, 1.0)
		_SpecularSegment("Specular Segment", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		//使用过程式几何轮廓渲染方法来描边
		UsePass "NPR_Lab/ToneBasedShading/OUTLINE"

		//使用AntialiasedCelShading绘制模型正面
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

			//声明Properties中的变量
			fixed4 _DiffuseColor;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _SpecularColor;
			float _Shininess;
			fixed4 _DiffuseSegment;
			fixed _SpecularSegment;

			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			//顶点着色器
			v2f vert(a2v v) {
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				TRANSFER_SHADOW(o);

				return o;
			}

			//片段着色器
			fixed4 frag(v2f i) : SV_Target{
				//计算光照模型所需的世界空间下的方向向量
				fixed3 worldNormal = normalize(i.worldNormal);//计算法线方向向量
				fixed3 worldLightDir = UnityWorldSpaceLightDir(i.worldPos);//计算光线方向向量
				fixed3 worldViewDir = UnityWorldSpaceViewDir(i.worldPos);//计算视线方向向量
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);//计算半角向量

				//计算光照衰减和阴影
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				//***计算漫反射系数和镜面反射系数***
				fixed diff = dot(worldNormal, worldLightDir);
				diff = diff * 0.5 + 0.5;
				//将漫反射系数划分到固定的4个值，实现卡通渲染中漫反射呈现色块
				fixed w = fwidth(diff) * 2.0;//计算领域内diff的梯度值w
				if (diff < _DiffuseSegment.x + w) {
					diff = lerp(_DiffuseSegment.x, _DiffuseSegment.y, smoothstep(_DiffuseSegment.x - w, _DiffuseSegment.x + w, diff));//根据diff在_DiffuseSegment.x+-w的范围内进行渐变混合
					//diff = lerp(_DiffuseSegment.x, _DiffuseSegment.y, clamp(0.5 * (diff - _DiffuseSegment.x) / w, 0, 1));
				}
				else if (diff < _DiffuseSegment.y + w) {
					diff = lerp(_DiffuseSegment.y, _DiffuseSegment.z, smoothstep(_DiffuseSegment.y - w, _DiffuseSegment.y + w, diff));//根据diff在_DiffuseSegment.y+-w的范围内进行渐变混合
					//diff = lerp(_DiffuseSegment.y, _DiffuseSegment.z, clamp(0.5 * (diff - _DiffuseSegment.y) / w, 0, 1));
				}
				else if (diff < _DiffuseSegment.z + w){
					diff = lerp(_DiffuseSegment.z, _DiffuseSegment.w, smoothstep(_DiffuseSegment.z - w, _DiffuseSegment.z + w, diff));//根据diff在_DiffuseSegment.z+-w的范围内进行渐变混合
					//diff = lerp(_DiffuseSegment.z, _DiffuseSegment.w, clamp(0.5 * (diff - _DiffuseSegment.z) / w, 0, 1));
				}
				else {
					diff = _DiffuseSegment.w;
				}

				//***计算卡通渲染的高光反射系数***
				fixed spec = max(0, dot(worldNormal, worldHalfDir));
				spec = pow(spec, _Shininess);
				w = fwidth(spec);
				if (spec < _SpecularSegment + w) {
					spec = lerp(0, 1, smoothstep(_SpecularSegment - w, _SpecularSegment + w, spec));//根据spec在_SpecularSegment+-w的范围内进行混合
				}
				else {
					spec = 1;
				}

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT;//环境光

				fixed3 texColor = tex2D(_MainTex, i.uv).rgb;//物体纹理颜色
				fixed3 diffuse = diff * _LightColor0.rgb * _DiffuseColor.rgb * texColor;//漫反射光
				fixed3 specular = spec * _LightColor0.rgb * _SpecularColor.rgb;//镜面反射光

				fixed3 color = ambient + (diffuse + specular) * atten;

				return fixed4(color, 1);
			}

			ENDCG
		}
		
		//增加多一个Pass叠加漫反射和镜面反射
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


			fixed4 _DiffuseColor;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _SpecularColor;
			float _Shininess;
			fixed4 _DiffuseSegment;
			fixed _SpecularSegment;

			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			v2f vert(a2v v) {
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				TRANSFER_SHADOW(o);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target{
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = UnityWorldSpaceLightDir(i.worldPos);
				fixed3 worldViewDir = UnityWorldSpaceViewDir(i.worldPos);
				fixed3 worldHalfDir = normalize(worldViewDir + worldLightDir);

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				fixed diff = dot(worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5) * atten;
				fixed spec = max(0, dot(worldNormal, worldHalfDir));
				spec = pow(spec, _Shininess);

				fixed w = fwidth(diff) * 2.0;
				if (diff < _DiffuseSegment.x + w) {
					diff = lerp(_DiffuseSegment.x, _DiffuseSegment.y, smoothstep(_DiffuseSegment.x - w, _DiffuseSegment.x + w, diff));
					//					diff = lerp(_DiffuseSegment.x, _DiffuseSegment.y, clamp(0.5 * (diff - _DiffuseSegment.x) / w, 0, 1));
				}
				else if (diff < _DiffuseSegment.y + w) {
					diff = lerp(_DiffuseSegment.y, _DiffuseSegment.z, smoothstep(_DiffuseSegment.y - w, _DiffuseSegment.y + w, diff));
					//					diff = lerp(_DiffuseSegment.y, _DiffuseSegment.z, clamp(0.5 * (diff - _DiffuseSegment.y) / w, 0, 1));
				}
				else if (diff < _DiffuseSegment.z + w) {
					diff = lerp(_DiffuseSegment.z, _DiffuseSegment.w, smoothstep(_DiffuseSegment.z - w, _DiffuseSegment.z + w, diff));
					//					diff = lerp(_DiffuseSegment.z, _DiffuseSegment.w, clamp(0.5 * (diff - _DiffuseSegment.z) / w, 0, 1));
				}
				else {
					diff = _DiffuseSegment.w;
				}

				w = fwidth(spec);
				if (spec < _SpecularSegment + w) {
					spec = lerp(0, _SpecularSegment, smoothstep(_SpecularSegment - w, _SpecularSegment + w, spec));
				}
				else {
					spec = _SpecularSegment;
				}

				fixed3 texColor = tex2D(_MainTex, i.uv).rgb;
				fixed3 diffuse = diff * _LightColor0.rgb * _DiffuseColor.rgb * texColor;
				fixed3 specular = spec * _LightColor0.rgb * _SpecularColor.rgb;

				return fixed4((diffuse + specular) * atten, 1);
			}

			ENDCG
		}
	}
	FallBack "Diffuse"
}
