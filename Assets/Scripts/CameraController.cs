using UnityEngine;
using System.Collections;

public class CameraController : MonoBehaviour {
    [SerializeField] private float _translationSpeed = 2f;
    [SerializeField] private float _rotationSpeed = 90f;

    private Transform _transform;

    private void Awake() {
        _transform = gameObject.GetComponent<Transform>();
    }
    
    void Update () {
        float lookVertical = -Input.GetAxis("Mouse Y") * _rotationSpeed * Time.deltaTime;
        float lookHorizontal = Input.GetAxis("Mouse X") * _rotationSpeed * Time.deltaTime;
        float forward = Input.GetAxis("Vertical") * _translationSpeed * Time.deltaTime;
        float strafe = Input.GetAxis("Horizontal") * _translationSpeed * Time.deltaTime;

        _transform.Rotate(0f, lookHorizontal, 0f, Space.World);
        _transform.Rotate(lookVertical, 0f, 0f, Space.Self);

        _transform.Translate(strafe, 0f, forward);
    }
}
