using UnityEngine;
using System.Collections;

/*
 * Todo: VR support
 * Todo: mirror distance field definition on cpu, for physics, gameplay scripting
 */
 [ExecuteInEditMode]
public class RaymarchPostEffect : MonoBehaviour {
    [SerializeField] private Material _material;

    private readonly Vector4[] _frustumCorners = new Vector4[4];

    private void OnRenderImage(RenderTexture src, RenderTexture dst) {
        // setup frustum corners for world position reconstruction
        // bottom left
        _frustumCorners[0] = Camera.current.ViewportToWorldPoint(new Vector3(0, 0, Camera.current.farClipPlane));
        // top left
        _frustumCorners[1] = Camera.current.ViewportToWorldPoint(new Vector3(0, 1, Camera.current.farClipPlane));
        // top right
        _frustumCorners[2] = Camera.current.ViewportToWorldPoint(new Vector3(1, 1, Camera.current.farClipPlane));
        // bottom right
        _frustumCorners[3] = Camera.current.ViewportToWorldPoint(new Vector3(1, 0, Camera.current.farClipPlane));

        _material.SetVectorArray("_FrustumCorners", _frustumCorners);

        Graphics.Blit(src,dst,_material);
    }
}
