using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumetricPlanarFog : ScriptableRendererFeature
{
    class VolumetricPlanarFogPass : ScriptableRenderPass
    {
        #region Set on creation
        private readonly string profilerTag;
        private readonly Material blitMaterial;
        #endregion

        #region SetOnCustomSetup
        private RenderTargetIdentifier colorTargetId;
        #endregion
        
        private RenderTargetHandle tempRtex;
        private Matrix4x4 projectionMatrix;
        public VolumetricPlanarFogPass(string profilerTag, Material blitMaterial, RenderPassEvent renderPassEvent)
        {
            this.profilerTag = profilerTag;
            this.blitMaterial = blitMaterial;
            this.renderPassEvent = renderPassEvent;
        }

        public void Setup(RenderTargetIdentifier colorTargetIdentifier)
        {
            colorTargetId = colorTargetIdentifier;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            cmd.GetTemporaryRT(tempRtex.id, cameraTextureDescriptor);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            blitMaterial.SetMatrix("_InverseViewMatrix", renderingData.cameraData.camera.transform.localToWorldMatrix);
            blitMaterial.SetMatrix("_InverseProjectionMatrix", GL.GetGPUProjectionMatrix(renderingData.cameraData.GetProjectionMatrix().inverse, false));
            blitMaterial.SetVector("_WorldSpaceCameraPosition", renderingData.cameraData.camera.transform.position);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            cmd.Clear();
            cmd.Blit(colorTargetId, tempRtex.Identifier(), blitMaterial, 0);
            cmd.Blit(tempRtex.Identifier(), colorTargetId);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempRtex.id);
        }
    }

    [Serializable]
    public struct VolumetricLowFogFeatureSettings
    {
        public Material rayMarchingMaterial;
    }

    public VolumetricLowFogFeatureSettings settings;
    VolumetricPlanarFogPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        this.name = "Volumetric Planar Fog";
        m_ScriptablePass = new VolumetricPlanarFogPass("Volumetric Planar Fog", settings.rayMarchingMaterial, RenderPassEvent.AfterRendering);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


