using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EdgeDetectNormalsAndDepths : PostEffectsBase {
    //声明该效果需要的Shader，并据此创建相应的材质
    public Shader edgeDetectShader;
    private Material edgeDetectMaterial = null;
    public Material material
    {
        get
        {
            edgeDetectMaterial = CheckShaderAndCreateMaterial(edgeDetectShader, edgeDetectMaterial);
            return edgeDetectMaterial;
        }
    }
    //设置可调参数
    [Range(0.0f, 1.0f)]
    public float edgesOnly = 0.0f;//边缘线强度,当值为0边缘将会叠加在原渲染图像上；当值为1时，则会只显示边缘，不显示原渲染图像。

    public Color edgeColor = Color.black;//描边颜色

    public Color backgroundColor = Color.white;//背景颜色

    public float sampleDistance = 1.0f;//用于控制对深度+法线纹理采样时，采用的采样距离。从视觉上来看，sampleDistance值越大，描边越宽

    //深度灵敏度和法线灵敏度，决定了当领域的深度值或法线值相差多少时，会被认为存在一条边界。
    public float sensitivityDepth = 1.0f;//深度灵敏度
    public float sensitivityNormals = 1.0f;//法线灵敏度

    //设置摄像机获取深度+法线纹理
    private void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
    }

    [ImageEffectOpaque] //只对不透明物体进行描边，不对透明物体描边
    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            material.SetFloat("_EdgeOnly", edgesOnly);
            material.SetColor("_EdgeColor", edgeColor);
            material.SetColor("_BackgroundColor", backgroundColor);
            material.SetFloat("_SampleDistance", sampleDistance);
            material.SetVector("_Sensitivity", new Vector4(sensitivityNormals, sensitivityDepth, 0.0f, 0.0f));

            Graphics.Blit(src, dest, material);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
