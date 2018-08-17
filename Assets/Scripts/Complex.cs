
using UnityEngine;

public static class Complex {
    public static Vector2 Real(float r) {
        return new Vector2(r, 0f);
    }

    public static Vector2 Imaginary(float i) {
        return new Vector2(0f, i);
    }

    public static Vector2 Mul(Vector2 a, Vector2 b) {
        return new Vector2(
            a.x * b.y - a.y * b.y,
            a.y * b.y + a.x * b.y);
    }

    public static Vector2 Pow(Vector2 a, float p) {
        return new Vector2(
            a.x * a.x - a.y * a.y,
            p * a.x * a.y);
    }
}