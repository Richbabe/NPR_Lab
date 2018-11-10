Shader "NPR_Lab/Chapter12-EdgeDection" {
	Properties {
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_EdgeOnly ("Edge Only", Float) = 1.0
		_EdgeColor ("Edge Color", Color) = (0,0,0,1)
		_BackgroundColor ("Backgroud Color", Color) = (1,1,1,1)
	}
	SubShader {
		Pass{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM

			#include "UnityCG.cginc"

			#pragma vertex vert  
			#pragma fragment fragSobel

			sampler2D _MainTex;
			uniform half4 _MainTex_TexelSize;//主纹理纹素大小
			fixed _EdgeOnly;
			fixed4 _EdgeColor;
			fixed4 _BackgroundColor;

			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv[9] : TEXCOORD0;
			};

			//顶点着色器
			v2f vert(appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);

				half2 uv = v.texcoord;

				//计算周围9个像素点的纹理坐标
				o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
				o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
				o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
				o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
				o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
				o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
				o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
				o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
				o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);

				return o;
			}

			//计算灰度值
			fixed luminance(fixed4 color) {
				return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
			}

			//Sobel函数
			half Sobel(v2f i) {
				//Sobel算子
				const half Gx[9] = { -1,  0,  1,
					-2,  0,  2,
					-1,  0,  1 };
				const half Gy[9] = { -1, -2, -1,
					0,  0,  0,
					1,  2,  1 };

				half texColor;
				half edgeX = 0;
				half edgeY = 0;
				for (int it = 0; it < 9; it++) {
					texColor = luminance(tex2D(_MainTex, i.uv[it]));//使用灰度值进行计算
					edgeX += texColor * Gx[it];
					edgeY += texColor * Gy[it];
				}

				half edge = 1 - abs(edgeX) - abs(edgeY);

				return edge;
			}

			//片段着色器
			fixed4 fragSobel(v2f i) : SV_Target{
				half edge = Sobel(i);//计算梯度值，edge越小该片段越有可能是个边缘点

				fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge);//用edge进行原图颜色插值，edge为0时渲染边
				fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);//用edge进行只显示边图颜色插值
				return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);//由_EdgeOnly决定用带边原图还是只显示边图
			}

			ENDCG
		}
	}
	FallBack Off
}
