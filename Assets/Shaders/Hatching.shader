Shader "NPR_Lab/Hatching" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)  // 控制模型颜色的属性
		_TileFactor ("Tile Factor", Float) = 1  // 纹理平铺系数，_TileFactor越大，模型上素描线条越密
		_Outline ("Outline", Range(0, 1)) = 0.1  // 轮廓宽度
		_OutlineColor("Outline Color", Color) = (0, 0, 0, 1)  // 轮廓颜色
		// 6张素描纹理，线条密度依次增大
		_Hatch0("Hatch 0", 2D) = "white" {}
		_Hatch1("Hatch 1", 2D) = "white" {}
		_Hatch2("Hatch 2", 2D) = "white" {}
		_Hatch3("Hatch 3", 2D) = "white" {}
		_Hatch4("Hatch 4", 2D) = "white" {}
		_Hatch5("Hatch 5", 2D) = "white" {}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		// 使用过程式几何轮廓渲染方法来描边
		UsePass "NPR_Lab/ToneBasedShading/OUTLINE"

		// 渲染模型正面的Pass
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
			float _TileFactor;
			sampler2D _Hatch0;
			sampler2D _Hatch1;
			sampler2D _Hatch2;
			sampler2D _Hatch3;
			sampler2D _Hatch4;
			sampler2D _Hatch5;

			// 定义顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float4 tangent : TANGENT;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
			};

			// 定义顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				// 把6张纹理的6个混合权重保存再两个fixed3类型的变量中
				fixed3 hatchWeights0 : TEXCOORD1;
				fixed3 hatchWeights1 : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
				SHADOW_COORDS(4)
			};

			// 定义顶点着色器
			v2f vert(a2v v) {
				v2f o;

				// 模型空间到裁剪空间的坐标变化
				o.pos = UnityObjectToClipPos(v.vertex);

				// 使用TileFactor得到纹理采样坐标
				o.uv = v.texcoord.xy * _TileFactor;

				// 计算逐顶点光照所需的方向向量
				fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));  // 计算世界坐标系下的光照方向
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);    // 计算世界坐标系下的法线方向
				
				// 计算逐顶点光照
				fixed diff = max(0, dot(worldLightDir, worldNormal));  // 漫反射系数

				// 初始化6个纹理混合权重为0
				o.hatchWeights0 = fixed3(0, 0, 0);
				o.hatchWeights1 = fixed3(0, 0, 0);

				// 把漫反射系数diff的范围从[0,1]扩大到[0.7]得到hatchFactor
				float hatchFactor = diff * 7.0;

				// 把[0,7]的区间均匀划分为7个子区间
				// 通过判断hatchFactor所处的子区间来计算对应的纹理混合权重
				// 权重计算是先计算上一张的权重，用1-上一张的权重得到下一张的权重
				if (hatchFactor > 6.0) {
					// (6.0, 7.0]
					// 纯白，无笔触, 每张TAM权重都为0
				}
				else if (hatchFactor > 5.0) {
					// (5.0, 6.0]
					o.hatchWeights0.x = hatchFactor - 5.0;  // 计算第一张TAM的权重
				}
				else if (hatchFactor > 4.0) {
					// (4.0, 5.0]
					o.hatchWeights0.x = hatchFactor - 4.0;  // 计算第一张TAM的权重
					o.hatchWeights0.y = 1.0 - o.hatchWeights0.x;  // 计算第二张TAM的权重
				}
				else if (hatchFactor > 3.0) {
					// (3.0, 4.0]
					o.hatchWeights0.y = hatchFactor - 3.0;  // 计算第二张TAM的权重
					o.hatchWeights0.z = 1.0 - o.hatchWeights0.y;  // 计算第三张TAM的权重
				}
				else if (hatchFactor > 2.0) {
					// (2.0, 3.0]
					o.hatchWeights0.z = hatchFactor - 2.0;  // 计算第三张TAM的权重
					o.hatchWeights1.x = 1.0 - o.hatchWeights0.z;  // 计算第四张TAM的权重
				}
				else if (hatchFactor > 1.0) {
					// (1.0, 2.0]
					o.hatchWeights1.x = hatchFactor - 1.0;  // 计算第四张TAM的权重
					o.hatchWeights1.y = 1.0 - o.hatchWeights1.x;  // 计算第五张TAM的权重
				}
				else {
					// [0.0, 1.0]
					o.hatchWeights1.y = hatchFactor;  // 计算第五章TAM的权重
					o.hatchWeights1.z = 1.0 - o.hatchWeights1.y;  // 计算第六张TAM的权重
				}

				// 计算顶点的世界坐标
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				// 根据顶点世界坐标计算阴影纹理采样坐标
				TRANSFER_SHADOW(o);

				return o;
			}

			// 定义片段着色器
			fixed4 frag(v2f i) : SV_Target{
				// 对每张纹理采样并乘上权重值得到当前片段每张纹理的采样颜色
				fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeights0.x;
				fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeights0.y;
				fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeights0.z;
				fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeights1.x;
				fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeights1.y;
				fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeights1.z;

				// 通过纯白的权重计算留白部分
				fixed4 whiteColor = fixed4(1, 1, 1, 1) * (1 - i.hatchWeights0.x - i.hatchWeights0.y - i.hatchWeights0.z -
					i.hatchWeights1.x - i.hatchWeights1.y - i.hatchWeights1.z);

				// 混合各个颜色值
				fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;

				// 计算光照衰减和阴影
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				// 返回最终渲染结果
				return fixed4(hatchColor.rgb * _Color.rgb * atten, 1.0);
			}
			ENDCG
		}
		
		// 增加多一个Pass叠加效果
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
			float _TileFactor;
			sampler2D _Hatch0;
			sampler2D _Hatch1;
			sampler2D _Hatch2;
			sampler2D _Hatch3;
			sampler2D _Hatch4;
			sampler2D _Hatch5;

			// 定义顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float4 tangent : TANGENT;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
			};

			// 定义顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				// 把6张纹理的6个混合权重保存再两个fixed3类型的变量中
				fixed3 hatchWeights0 : TEXCOORD1;
				fixed3 hatchWeights1 : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
				SHADOW_COORDS(4)
			};

			// 定义顶点着色器
			v2f vert(a2v v) {
				v2f o;

				// 模型空间到裁剪空间的坐标变化
				o.pos = UnityObjectToClipPos(v.vertex);

				// 使用TileFactor得到纹理采样坐标
				o.uv = v.texcoord.xy * _TileFactor;

				// 计算逐顶点光照所需的方向向量
				fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));  // 计算世界坐标系下的光照方向
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);    // 计算世界坐标系下的法线方向

																			// 计算逐顶点光照
				fixed diff = max(0, dot(worldLightDir, worldNormal));  // 漫反射系数

																	   // 初始化6个纹理混合权重为0
				o.hatchWeights0 = fixed3(0, 0, 0);
				o.hatchWeights1 = fixed3(0, 0, 0);

				// 把漫反射系数diff的范围从[0,1]扩大到[0.7]得到hatchFactor
				float hatchFactor = diff * 7.0;

				// 把[0,7]的区间均匀划分为7个子区间
				// 通过判断hatchFactor所处的子区间来计算对应的纹理混合权重
				// 权重计算是先计算上一张的权重，用1-上一张的权重得到下一张的权重
				if (hatchFactor > 6.0) {
					// (6.0, 7.0]
					// 纯白，无笔触, 每张TAM权重都为0
				}
				else if (hatchFactor > 5.0) {
					// (5.0, 6.0]
					o.hatchWeights0.x = hatchFactor - 5.0;  // 计算第一张TAM的权重
				}
				else if (hatchFactor > 4.0) {
					// (4.0, 5.0]
					o.hatchWeights0.x = hatchFactor - 4.0;  // 计算第一张TAM的权重
					o.hatchWeights0.y = 1.0 - o.hatchWeights0.x;  // 计算第二张TAM的权重
				}
				else if (hatchFactor > 3.0) {
					// (3.0, 4.0]
					o.hatchWeights0.y = hatchFactor - 3.0;  // 计算第二张TAM的权重
					o.hatchWeights0.z = 1.0 - o.hatchWeights0.y;  // 计算第三张TAM的权重
				}
				else if (hatchFactor > 2.0) {
					// (2.0, 3.0]
					o.hatchWeights0.z = hatchFactor - 2.0;  // 计算第三张TAM的权重
					o.hatchWeights1.x = 1.0 - o.hatchWeights0.z;  // 计算第四张TAM的权重
				}
				else if (hatchFactor > 1.0) {
					// (1.0, 2.0]
					o.hatchWeights1.x = hatchFactor - 1.0;  // 计算第四张TAM的权重
					o.hatchWeights1.y = 1.0 - o.hatchWeights1.x;  // 计算第五张TAM的权重
				}
				else {
					// [0.0, 1.0]
					o.hatchWeights1.y = hatchFactor;  // 计算第五章TAM的权重
					o.hatchWeights1.z = 1.0 - o.hatchWeights1.y;  // 计算第六张TAM的权重
				}

				// 计算顶点的世界坐标
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				// 根据顶点世界坐标计算阴影纹理采样坐标
				TRANSFER_SHADOW(o);

				return o;
			}

			// 定义片段着色器
			fixed4 frag(v2f i) : SV_Target{
				// 对每张纹理采样并乘上权重值得到当前片段每张纹理的采样颜色
				fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeights0.x;
				fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeights0.y;
				fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeights0.z;
				fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeights1.x;
				fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeights1.y;
				fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeights1.z;

				// 通过纯白的权重计算留白部分
				fixed4 whiteColor = fixed4(1, 1, 1, 1) * (1 - i.hatchWeights0.x - i.hatchWeights0.y - i.hatchWeights0.z -
					i.hatchWeights1.x - i.hatchWeights1.y - i.hatchWeights1.z);

				// 混合各个颜色值
				fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;

				// 计算光照衰减和阴影
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				// 返回最终渲染结果
				return fixed4(hatchColor.rgb * _Color.rgb * atten, 1.0);
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
