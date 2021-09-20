using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraRotor : MonoBehaviour
{
    [SerializeField] private float speed;
    void Update()
    {
        transform.Rotate(Vector3.up * speed, Space.Self);
    }
}
