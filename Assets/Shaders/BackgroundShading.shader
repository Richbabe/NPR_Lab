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

		}
	}
}
