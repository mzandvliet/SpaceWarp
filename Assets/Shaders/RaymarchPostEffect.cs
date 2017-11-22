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
public class RaymarchPostEffect : MonoBehaviour {
    [SerializeField] private Material _material;

    private readonly Vector4[] _frustumCorners = new Vector4[4];
    private Texture2D _primitiveBuffer;

    private void Awake() {
        
    }

    private void OnPreRender() {
        if (_primitiveBuffer == null) {
            _primitiveBuffer = new Texture2D(16, 16, TextureFormat.ARGB32, false);
            _primitiveBuffer.filterMode = FilterMode.Point;
        }

        const int numPrims = 8;
        const int primSize = 2;
        for (int i = 0; i < numPrims; i++) {
            int buffStart = i*primSize;
            int x = buffStart%numPrims;
            int y = buffStart/numPrims;
            _primitiveBuffer.SetPixel(x, y, new Color(1f, 0f, 0f, 0f));
            _primitiveBuffer.SetPixel(x + 1, y, new Color(i / (float)numPrims, 0f, 0f, 0.5f));
        }
        _primitiveBuffer.Apply(false);
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dst) {
        // setup frustum corners for world position reconstruction
        // Todo: with custom blit we can pack this into the draw geometry instead of using a matrix constant
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
