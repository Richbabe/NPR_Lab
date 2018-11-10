using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent (typeof(Camera))]
public class PostEffectsBase : MonoBehaviour {
    //检查各种资源和条件是否满足
    protected void CheckResource()
    {
        bool isSupported = CheckSupport();

        if(isSupported == false)
        {
            NotSupported();
        }
    }

    protected bool CheckSupport()
    {
        if(SystemInfo.supportsImageEffects == false || SystemInfo.supportsRenderTextures == false)
        {
            Debug.LogWarning("This platform does not support image effect or render textures!");
            return false;
        }
        return true;
    }

    protected void NotSupported()
    {
        this.enabled = false;//令当前脚本失效
    }

    protected void start()
    {
        CheckResource();
    }

    //创建用于处理渲染纹理的材质
    protected Material CheckShaderAndCreateMaterial(Shader shader,Material material)
    {
        if(shader == null)
        {
            return null;
        }

        if(shader.isSupported && material && material.shader == shader)
        {
            return material;
        }

        if (!shader.isSupported)
        {
            return null;
        }
        else
        {
            material = new Material(shader);
            material.hideFlags = HideFlags.DontSave;
            if (material)
            {
                return material;
            }
            else
            {
                return null;
            }
        }
    }
}
