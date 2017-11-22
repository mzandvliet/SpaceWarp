

using UnityEngine;

public class RayDistribution : MonoBehaviour {

    void OnDrawGizmos() {
        Vector3 l = Quaternion.Euler(0f, -60f, 0f) * Vector3.forward;
        Vector3 r = Quaternion.Euler(0f,  60f, 0f) * Vector3.forward;

        int xRes = 64;
        for (int x = 0; x < xRes; x++) {
            float lerp = x / (float) (xRes-1);
            Gizmos.DrawRay(Vector3.zero, Vector3.Lerp(l, r, lerp) * 32f);
        }
    }
}