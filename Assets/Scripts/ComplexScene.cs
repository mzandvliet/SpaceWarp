using UnityEngine;
using System.Collections;

/* c <= .25 Does not diverge outside of the mandelbrot set
 * c > .25 has a nebulous range where the particle accelerates outward.
 * But this all changes when c has a non-zero imaginary value.
 * 
 * If you have a healthy balance of real to imaginary, you rarely ever diverge, you stay stable, reliable, useless.
 * 
 * But sometimes you want to get real (whichever direction you take that to mean), but not with that annoying divergence
 * thing happening. So you're looking to transform to another space which lets you keep going.
 * 
 * And so finding that space is a problem.
 * And then finding a space that preserves derivatives well might be even harder.
 * 
 * But that again is a thing that the picture of the mandelbrot set should just tell you. So you use IQ's trick
 * to figure out what the state range is for something that traverses that boundary.
 * 
 * It's telling you... can your dynamical system X take energy Y?
 * 
 * An automatic energy/information diffusing network.
 * 
 * You hook it up to real inputs with real energy metrics and such, and you tell it to diffuse based on mandelbrot
 * relationships.
 * 
 * You can set this loose on real world data to find mandelbrot transformations that minimize energy and promote local determinism.
 * 
 * Fix your timestep.
 * Locally.
 * Globally, anything goes.
 * 
 * Timestep is implicit in this. Could that work? Instead of always doing
 * 
 * something * Time.deltaTime
 * 
 * we do something else? Because that's starting to feel really stupid! That's destroying precious precision!
 * 
 * If we want to do physics with numbers inside the mandelbrot set, we can't have an explicit timestep.
 * 
 * But that's fine. In fact, that's kinda what we want anyway. We just have to know we'll be correct
 * about the context.
 * 
 * Ok so how about this, whatever thing I care about in the Unity editor and in rendering on the screen,
 * that's my real space. That's where for now I still like living, because I grew up thinking that way.
 * 
 * But all our derivatives we model exclusively using complex numbers.
 * 
 * And out of that you get a derivative graph. And you could decide to feed into that on the other end, and
 * the internal state wouldn't know. Like pushing.
 * 
 * Anyway, a physics engine with cool stability guarantees and small-large scale contrast and prediction
 * and all those things built in. That sounds cool.
 * 
 * Is there a kind of chirality to the Mandelbulb shape that we can exploit?
 * 
 * At any point you get to choose about the rigour of noise to signal ratio. Noise to signal is where
 * mandelbrot guides you.
 * 
 * 
 * You can do completely natural motionblur for objects bouncing around at near-lightspeed.
 * 
 * Spherical harmonics.
 * 
 * Ok, let's start thinking about how we traditionally model things like collisions and ray bounces, and
 * now let's try modeling those in complex domains. And, no matter really what we do, mandelbrot
 * will let us know whether we can be confident, where we can relax some value range to do more with less,
 * and conversely, where things need to be tightened down.
 * 
 * Deterministic low-res guarantees, with locally more detailed, flexible, but slightly less stable effects. Why?
 * Because local non-determinism balances out just fine, most of the case. And where noise is flipping bits?
 * Why do you care so much?
 * 
 * Ok, now it's showing me how a function entering the function will end up. I am doing coordinate transforms, too.
 * 
 * In fact, there is no difference whatsoever between doing coordinate space transforms and doing simulation work.
 * 
 * Complex number sets to do fluid-like motion vector spaces.
 * 
 * This thing has a finite distance, which you can give a falloff, and then you can compose with them.
 * 
 * The big question is, what does the in-between space look like, and how do you do boundary interaction and such?
 * 
 * Draw particles into existence at the lagrange points, yet at low probability. Then fade them in or something.
 * 
 * We have matter particles. And we have vortex particles. Or... Bosons? I suppose?
 * 
 * And those bosons and particles affect each other directly and indirectly, but in a way that's... also just particles.
 * 
 * The bosons have charge, so do the particles.
 * 
 * 
 * With historical data compression, we could do things like Steep's footsteps in snow. But better.
 * 
 * This basic complex analysis stuff will help us reason about: will this snow hold us up?
 * 
 * These things just WANT to be used for interference pattern modeling!
 * 
 */

public class ComplexScene : MonoBehaviour {
    [SerializeField] private float _pow = 2.0f;
    [SerializeField] private float _maxDist = 99999f;
    [SerializeField] private Vector2 _c;
    [SerializeField] private Vector2 _zStart;



    private Vector2 _z;

    void FixedUpdate() {
        //        if (Input.GetKeyDown(KeyCode.Space)) {
        //            _z = _zStart;
        //        }

        _z = Tick(_z, _c, _pow, _maxDist);
        transform.position = new Vector3(_z.x, _z.y, 0f);
    }

    private static Vector2 Tick(Vector2 z, Vector2 c, float pow, float max) {
        z = Complex.Pow(z, pow) + c;
        if (z.sqrMagnitude > max) {
            z = Vector2.zero;
        }
        return z;
    }

    private void OnDrawGizmos() {

        Vector2 z = _zStart;
        for (int i = 0; i < 128; i++) {
            Gizmos.color = Color.Lerp(Color.red, Color.blue, i / 128f);
            Vector3 zPrev = z;
            z = Tick(z, _c, _pow, _maxDist);
            Gizmos.DrawLine(zPrev, z);
        }
    }
}