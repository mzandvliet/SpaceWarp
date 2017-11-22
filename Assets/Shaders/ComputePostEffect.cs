using UnityEngine;
using System.Collections;

/*
 * Todo: VR support
 * Todo: mirror distance field definition on cpu, for physics, gameplay scripting
 * Todo: SpaceWarp, like space compression and expansion as you as the observer move.
 * 
 * When you stand perfectly still, you see in regular 3D carthesian space. As you start to
 * move, space starts warping. Like, I don't know, a twirl effect. The faster you move,
 * the more you see and move through warped space. So movement speed becomes a complex
 * mechanic.
 * 
 * When you start to understand the nature of the warp, you can start using it.
 */
 [ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class ComputePostEffect : MonoBehaviour {
    [SerializeField] private Material _material;

    public ComputeShader _shader;
     private float stuff;
    private RenderTexture _tex;

    private void Awake() {
    }

    private void OnPreRender() {
     
           
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dst) {
        Graphics.Blit(src,dst,_material);
    }
}
