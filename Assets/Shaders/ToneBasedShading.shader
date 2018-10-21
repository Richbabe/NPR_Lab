///
///  Reference: 	Gooch A, Gooch B, Shirley P, et al. A non-photorealistic lighting model for automatic technical illustration[C]
///						Proceedings of the 25th annual conference on Computer graphics and interactive techniques. ACM, 1998: 447-452.
/// 

Shader "NPR_Lab/ToneBasedShading" {
	Properties {
		_Color("Diffuse Color", Color) = (1, 1, 1, 1)
		_MainTex("Base (RGB)", 2D) = "white" {}
		_Outline("Outline", Range(0,1)) = 0.1 //用于控制轮廓线的宽度
		_OutlineColor("Outline Color", Color) = (0, 0, 0, 1) //轮廓线的颜色
		_Specular("Specular", Color) = (1, 1, 1, 1) //高光反射的颜色
		_Gloss("Gloss", Range(1.0, 500)) = 20 //光滑度
		_Blue("Blue", Range(0, 1)) = 0.5  //纯饱和蓝色B通道分量值
		_Alpha("Alpha", Range(0, 1)) = 0.5 
		_Yellow("Yellow", Range(0, 1)) = 0.5 //纯饱和黄色R、G通道分量值
		_Beta("Beta", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		//渲染轮廓线的Pass,该Pass只渲染背面的三角面片（过程式几何轮廓线渲染）
		Pass{
			NAME "OUTLINE" //该Pass的名称，后面只需调用名字即可绘制轮廓不用重写该Pass

			Cull Front //剔除正面，只渲染背面

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			//定义Properties属性
			float _Outline;
			fixed4 _OutlineColor;

			//顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			//顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
			};

			//定义顶点着色器
			v2f vert(a2v v) {
				v2f o;

				float4 pos = mul(UNITY_MATRIX_MV, v.vertex);//将坐标从模型空间转换到视角空间
				float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);//将法线从模型空间转换到视角空间

				normal.z = -0.5;//让法线的z分量等于一个定值，避免背面扩张后的顶点挡住正面的面片

				pos = pos + float4(normalize(normal), 0) * _Outline;//将顶点沿法线方向扩张

				o.pos = mul(UNITY_MATRIX_P, pos);//将顶点从视角空间转换到裁剪空间

				return o;
			}

			//定义片段着色器
			float4 frag(v2f i) : SV_Target{
				return float4(_OutlineColor.rgb,1);//使用轮廓线颜色渲染整个背面
			}

			ENDCG
		}

		//渲染模型正面的Pass
		Pass{
			Tags {"LightMode" = "ForwardBase"}

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdbase

			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			//定义Properties中声明的变量
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Specular;
			float _Gloss;
			fixed _Blue;
			fixed _Alpha;
			fixed _Yellow;
			fixed _Beta;

			//顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};

			//顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
			};

			//顶点着色器
			v2f vert(a2v v) {
				v2f o;

				//将顶点坐标从模型空间转换到裁剪空间
				o.pos = UnityObjectToClipPos(v.vertex);

				//计算世界空间下的法向量
				o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);

				//计算世界空间下的顶点坐标
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				//计算平移缩放后的纹理坐标
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				return o;
			}

			//片段着色器
			fixed4 frag(v2f i) : SV_Target{
				//计算光照模型所需的世界空间下的方向向量
				fixed3 worldNormal = normalize(i.worldNormal);//计算法线方向向量
				fixed3 worldLightDir = UnityWorldSpaceLightDir(i.worldPos);//计算光线方向向量
				fixed3 worldViewDir = UnityWorldSpaceViewDir(i.worldPos);//计算视线方向向量
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);//计算半角向量

				fixed4 c = tex2D(_MainTex, i.uv);//片段对应的纹理颜色（默认为白色）

				//计算环境光强度
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

				fixed diff = dot(worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5);//计算漫反射分量

				fixed3 k_d = c.rgb * _Color.rgb;//计算物体漫反射系数

				//计算基于色调的光照模型的自由变量
				fixed3 k_blue = fixed3(0, 0, _Blue);
				fixed3 k_yellow = fixed3(_Yellow, _Yellow, 0);
				fixed3 k_cool = k_blue + _Alpha * k_d;
				fixed3 k_warm = k_yellow + _Beta * k_d;

				//计算漫反射光照强度
				//fixed3 diffuse = _LightColor0.rgb * (diff * k_cool + (1 - diff) * k_warm);
				fixed3 diffuse = _LightColor0.rgb * (diff * k_warm + (1 - diff) * k_cool);

				//计算镜面反射光照强度
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, worldHalfDir)), _Gloss);

				fixed3 color = ambient + diffuse + specular;

				return fixed4(color, 1.0);
			}

			ENDCG
		}
		
		//增加多一个Pass接收更多光源
		Pass{
			Tags {"LightMode" = "ForwardAdd"}

			Blend One One

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdAdd

			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			//定义Properties中声明的变量
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Specular;
			float _Gloss;
			fixed _Blue;
			fixed _Alpha;
			fixed _Yellow;
			fixed _Beta;

			//顶点着色器输入
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};

			//顶点着色器输出
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
			};

			//顶点着色器
			v2f vert(a2v v) {
				v2f o;

				//将顶点坐标从模型空间转换到裁剪空间
				o.pos = UnityObjectToClipPos(v.vertex);

				//计算世界空间下的法向量
				o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);

				//计算世界空间下的顶点坐标
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				//计算平移缩放后的纹理坐标
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				return o;
			}

			//片段着色器
			fixed4 frag(v2f i) : SV_Target{
				//计算光照模型所需的世界空间下的方向向量
				fixed3 worldNormal = normalize(i.worldNormal);//计算法线方向向量
				fixed3 worldLightDir = UnityWorldSpaceLightDir(i.worldPos);//计算光线方向向量
				fixed3 worldViewDir = UnityWorldSpaceViewDir(i.worldPos);//计算视线方向向量
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);//计算半角向量

				fixed4 c = tex2D(_MainTex, i.uv);//片段对应的纹理颜色（默认为白色）

				fixed diff = dot(worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5);//计算漫反射分量

				fixed3 k_d = c.rgb * _Color.rgb;//计算物体漫反射系数

				//计算基于色调的光照模型的自由变量
				fixed3 k_blue = fixed3(0, 0, _Blue);
				fixed3 k_yellow = fixed3(_Yellow, _Yellow, 0);
				fixed3 k_cool = k_blue + _Alpha * k_d;
				fixed3 k_warm = k_yellow + _Beta * k_d;

				//计算漫反射光照强度
				//fixed3 diffuse = _LightColor0.rgb * (diff * k_cool + (1 - diff) * k_warm);
				fixed3 diffuse = _LightColor0.rgb * (diff * k_warm + (1 - diff) * k_cool);

				//计算镜面反射光照强度
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, worldHalfDir)), _Gloss);

				fixed3 color = diffuse + specular;

				return fixed4(color, 1.0);
			}

			ENDCG
		}
		
	}
	FallBack "Diffuse"
}
