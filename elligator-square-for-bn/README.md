# Elligator Squared for BN-like curves

This document explains how to efficiently implement the Elligator Squared
algorithm for BN curves and BN-like curves like `secp256k1`.

## 1 Introduction

### 1.1 Elligator

Sometimes it is desirable to be able to encode elliptic curve public keys as
uniform byte strings. In particular, a Diffie-Hellman key exchange requires
sending a group element in both directions, which for Elliptic Curve based
variants implies sending a curve point. As the coordinates of such points
satisfy the curve equation, this results in a detectable relation between
the sent bytes if those coordinates are sent naively. Even if just the X
coordinates of the points are sent, the knowledge that only around 50% of
X coordinates have corresponding points on the curve means that an attacker
who observes many connections can distinguish these from random: the probability
that 30 random observed transmission would always be valid X coordinates is less than
one in a billion.

Various approaches have been proposed for this solution, including
[Elligator](https://elligator.cr.yp.to/) and Elligator 2 by Bernstein et al., which both
define a mapping between a subset of points on the curve and byte
arrays, in such a way that the encoding of uniformly generated
curve points within that set is indistinguishable from random bytes.
This permits running ECDH more *covertly*: instead of permitting
any public key as ECDH ephemeral, restrict the choice to those which
have an Elligator mapping, and send the encoding. This requires on
average 2 ECDH ephemeral keys to be generated, but it results
in performing an ECDH negotiation with each party sending just 32
uniform bytes to each other (for *256*-bit curves).

Unfortunately, Elligator and Elligator 2 have requirements that make
them incompatible with curves of odd order like BN curves are.

### 1.2 Elligator Squared

In [this paper](https://eprint.iacr.org/2014/043.pdf), Tibouchi describes a more
generic solution that works for any elliptic curve
and for any point on it rather than a subset, called Elligator Squared. The downside is that
the encoding output is twice the size: for 256-bit curves, the encoding is 64 uniformly random bytes.
On the upside, it's generally also faster as it doesn't need generating multiple ECDH keys.

It relies on a function *f* that maps field elements to points, with the following
properties:
* Every field element is mapped to a single valid point on the curve by *f*.
* A significant fraction of points on the curve have to be reachable (but not all).
* The number of field elements that map to any given point must have small upper bound *d*.
* These preimages (the field elements that map to a given point) must be efficiently computable.

The Elligator and Elligator 2 mapping functions can be used as *f* for curves where they exist,
but due to being less restrictive, adequate mapping functions for all elliptic curves exist,
including ones with odd order.

The Elligator Squared encoding then consists of **two** field elements, and together they
represent the sum (elliptic curve group operation) of the points obtained by applying *f* to those two field elements.
To decode such a pair *(u,v)*, just compute *f(u) + f(v)*.

To find an encoding for a given point *P*, the following random sampling algorithm is used:
* Loop:
  * Generate a uniformly random field element *u*.
  * Compute the point *Q = P - f(u)*.
  * Compute the set of preimages *t* of *Q* (so for every *v* in *t* it holds that *f(v) = Q*). This set can have any size in *[0,d]*.
  * Generate a random number *j* in range *[0,d)*.
  * If *j < len(t)*: return *(u,t[j])*, otherwise start over.

Effectively, this algorithm uniformly randomly picks one pair of field elements from the set of
all of those that encode *P*. It can be shown that the number of preimage pairs points have
only differ negligibly from each other, and thus this sampling algorithm results
in uniformly random pair of field elements, given uniformly random points *P*.

### 1.3 Mapping function for BN-like curves

In [this paper](https://www.di.ens.fr/~fouque/pub/latincrypt12.pdf), Fouque and Tibouchi describe a so-called Shallue-van de Woestijne mapping function *f*
that meets all the requirements above, for BN-like curves.

Specifically, given a prime *p*, the field *F = GF(p)*, and the elliptic
curve *E* over it defined by *y<sup>2</sup> = g(x) = x<sup>3</sup> + b*, where *p mod 12 = 7* and *1+b is a nonzero square in F*, define
the following constants (in *F*):
* *c<sub>1</sub> = &radic;(-3)*
* *c<sub>2</sub> = (c<sub>1</sub> - 1) / 2*
* *c<sub>3</sub> = (-c<sub>1</sub> - 1) / 2*

And define the following 3 functions:
* *q<sub>1</sub>(s) = c<sub>2</sub> - c<sub>1</sub>s / (1+b+s)*
* *q<sub>2</sub>(s) = c<sub>3</sub> + c<sub>1</sub>s / (1+b+s)*
* *q<sub>3</sub>(s) = 1 - (1+b+s)<sup>2</sup> / (3s)*

Then the paper shows that given a nonzero square *s* in *F*, *g(q<sub>1</sub>(s))&times;g(q<sub>2</sub>(s))&times;g(q<sub>3</sub>(s))*
will also be square, or in other words, either exactly one of *{q<sub>1</sub>(s), q<sub>2</sub>(s), q<sub>3</sub>(s)}*, or
all three of them, are valid X coordinates on *E*. For *s=0*, *q<sub>1</sub>(0)* and *q<sub>2</sub>(0)* map to valid points
on the curve, while *q<sub>3</sub>(0)* is not defined (division by zero).

With that, the function *f(u)* can be defined as follows:
* Compute *x<sub>1</sub> = q<sub>1</sub>(u<sup>2</sup>)*, *x<sub>2</sub> = q<sub>2</sub>(u<sup>2</sup>)*, *x<sub>3</sub> = q<sub>3</sub>(u<sup>2</sup>)*
* Let *x* be the first of *{x<sub>1</sub>,x<sub>2</sub>,x<sub>3</sub>}* that's a valid X coordinate on *E* (i.e., *g(x)* is square).
* Let *y* be the square root of *g(x)* whose parity equals that of *u* (every nonzero square mod *P* has two distinct roots, negations of each other, of which one is even and one which is odd).
* Return *(x,y)*.

This function meets all our requirements. It maps every field element to a curve point, around *56.25%* of curve points are reached, no point has more
than *d=4* preimages, and those preimages can be efficiently computed. Furthermore, when implemented this way, divisions by zero are not
a concern. The *1+b+s* in *q<sub>1</sub>* and *q<sub>2</sub>* is never zero for square *s* (it would require *s = -1-b*, but *-1-b* is never square).
The *3s* in *q<sub>3</sub>* can be *0*, but this won't be reached as *q<sub>1</sub>(0)* lands on the curve.

## 2 Specializing Elligator Squared

### 2.1 Inverting *f*

Elligator Squared needs an efficient way to find the field elements *v* for which *f(v) = Q*, given *Q*.
We start by defining 4 partial inverse functions *r<sub>1..4</sub>* for *f*.
Given an *(x,y)* coordinate pair on the curve, each of these either returns *&perp;*, or returns a field element *t* such that *f(t) = (x,y)*.

***r<sub>i</sub>(x,y)***:
* Compute *s = q<sub>?</sub><sup>-1</sup>(x)*
  * If *i=1*: *q<sub>1</sub><sup>-1</sup>(x)*: *s = (1+b)(c<sub>1</sub>-z) / (c<sub>1</sub>+z)* where *z = 2x+1*
  * If *i=2*: *q<sub>2</sub><sup>-1</sup>(x)*: *s = (1+b)(c<sub>1</sub>+z) / (c<sub>1</sub>-z)* where *z = 2x+1*
  * If *i=3*: *q<sub>3</sub><sup>-1</sup>(x)*: *s = (z + &radic;(z<sup>2</sup> - 16(b+1)<sup>2</sup>))/4* where *z = 2-4B-6x*
  * If *i=4*: *q<sub>3</sub><sup>-1</sup>(x)*: *s = (z - &radic;(z<sup>2</sup> - 16(b+1)<sup>2</sup>))/4* where *z = 2-4B-6x*
* If *s* does not exist (because of division by zero, or non-existing square root), return *&perp;*.
* If *s* is not square: return *&perp;*
* For all *j* in *1..min(i-1,2)*:
  * If *g(q<sub>j</sub>(s))* is square: return *&perp;*; to guarantee that the constructed preimage roundtrips back through the corresponding forward *q<sub>i</sub>* and not through a lower one.
* Compute *u = &radic;s*
* If *is_odd(u) = is_odd(y)*:
  * Return *u*
* Else:
  * If *u=0*: return *&perp;* (would require an odd *0*, but negating doesn't change parity)
  * Return *-u*

The (multi-valued) *f<sup>-1</sup>(x,y)* function can be defined as the set of non-*&perp;*
values in *{r<sub>1</sub>(x,y),r<sub>2</sub>(x,y),r<sub>3</sub>(x,y),r<sub>4</sub>(x,y)}*, as every preimage of *(x,y)* under *f* is one of these four.

### 2.2 Avoiding computation of all inverses

It turns out that we don't actually need to evaluate *f<sup>-1</sup>(x,y)* in full.
Consider the following: the Elligator Squared sampling loop is effectively the following:
* Loop:
  * Generate a uniformly random field element *u*.
  * Compute the point *Q = P - f(u)*.
  * Compute the list of distinct preimages *t = f<sup>-1</sup>(Q)*.
  * Pad *t* with *&perp;* elements to size *4* (where *d=4* is the maximum number preimages for any given point).
  * Select a uniformly random *v* in *t*.
  * If *v* is not *&perp;*, return *(u,v)*; otherwise start over.

In this loop, an alternative list *t' = [r<sub>1</sub>(x,y),r<sub>2</sub>(x,y),r<sub>3</sub>(x,y),r<sub>4</sub>(x,y)]*
can be used. It has exactly the same elements as the padded *t* above, except potentially in a different order. This is a valid
alternative because if all we're going to do is select a uniformly random element from it, the order of this list is irrelevant.
To be precise, we do need to deal with the edge case here where multiple *r<sub>i</sub>(x,y)* for distinct *i* values are the same, as this would
introduce a bias. To do so, we add to the definition of *r<sub>i</sub>(x,y)* that *&perp;* is returned if *r<sub>j</sub>(x,y) = r<sub>i</sub>(x,y)* for *j < i*.

Selecting a uniformly random element from *t'* is easy: just select one of the four *r<sub>i</sub>* functions,
evaluate it in *Q*, and start over if it's *&perp;*:
* Loop:
  * Generate a uniformly random field element *u*.
  * Compute the point *Q = P - f(u)*.
  * Generate a uniformly random *j* in *1..4*.
  * Compute *v = r<sub>j</sub>(Q)*.
  * If *v* is not *&perp;*, return *(u,v)*; otherwise start over.

This avoids the need to compute *t* or *t'* in their entirety.

### 2.3 Simplifying the round-trip checks

As explained in Paragraph 2.1, the *r<sub>i&gt;1</sub>* partial reverse functions must check that the value obtained through the *q<sub>i</sub><sup>-1</sup>* formula
doesn't map to the curve through a lower-numbered forward *q<sub>i</sub>* function.

For *r<sub>2</sub>*, this means checking that *q<sub>1</sub>(q<sub>2</sub><sup>-1</sup>(x))* isn't on the curve.
Thankfully, *q<sub>1</sub>(q<sub>2</sub><sup>-1</sup>(x))* is just *-x-1*, which simplifies the check.

For *r<sub>3,4</sub>* it is actually unncessary to check forward mappings through both *q<sub>1</sub>* and *q<sub>2</sub>*.
The Shallue-van de Woestijne construction of *f* guarantees that either exactly one, or all three, of the *q<sub>i</sub>*
functions land on the curve. When computing an inverse through *q<sub>3</sub><sup>-1</sup>*, and that inverse exists,
then we know it certainly lands on the curve when forward mapping through *q<sub>3</sub>*. That implies that either
both *q<sub>1</sub>* and *q<sub>2</sub>* also land on the curve, or neither of them does. Thus for *r<sub>3,4</sub>* it
suffices to check that *q<sub>1</sub>* doesn't land on the curve.

### 2.4 Simplifying the duplicate preimage checks

As explained in Paragraph 2.2, we need to deal with the edge case where multiple *r<sub>i</sub>(x,y)* with distinct *i* map to the same value.

Most of these checks are actually unnecessary. For example, yes, it is possible that *q<sub>1</sub><sup>-1</sup>(x)* and *q<sub>2</sub><sup>-1</sup>(x)*
are equal (when *x = -1/2*), but when that is the case, it is obvious that *q<sub>1</sub>(q<sub>2</sub><sup>-1</sup>(x))* will be on the curve as
well (as it is equal to *x*), and thus the round-trip check will already cause *&perp;* to be returned.

There is only one case that isn't covered by the round-trip check already:
*r<sub>4</sub>(x,y)* may match *r<sub>3</sub>(x,y)*, which isn't covered because they both use the same forward *q<sub>3</sub>(x)*.
This happens when either *x = (1-8B)/6* or *x = 1*.

Note that failing to implement these checks will only introduce a negligible bias, as these cases are too rare to occur for cryptographically-sized curves
when only random inputs are used like in Elligator Squared.
They are mentioned here for completeness, as it helps writing small-curve tests where correctness can be verified exhaustively.

### 2.5 Dealing with infinity

The point at infinity is not a valid public key, but it is possible to construct field elements *u* and *v* such that
*f(u)+f(v)=&infin;*. To make sure every input *(u,v)* can be decoded, it is preferable to remap this special case
to another point on the curve. A good choice is mapping this case to *f(u)* instead: it's easy to implement,
not terribly non-uniform, and even easy to make the encoder target this case (though with actually randomly generated *u*,
the bias from not doing so is negligible).

On the decoder side, one simply needs to remember *f(u)*, and if *f(u)+f(v)* is the point at infinity, return that instead.

On the encoder side, one can detect the case in the loop where *Q=P-f(u)=&infin;*; this corresponds to the situation where
*P=f(u)*. No *v* exists for which *f(v)=Q* in that case, but due to the special rule on the decoder side, it is possible
to target *f(v)=-f(u)* in that case. As *-f(u)* is computed already in the process of finding *Q*, it suffices to try to
find preimages for that.

### 2.6 Putting it all together

The full algorithm can be written as follows in Python-like pseudocode. Note that the variables
(except *i*) represent field elements and are not normal Python integers (with some helper functions it is valid [Sage code](test.sage), though).

```python
def f(u):
    s = u**2 # Turn u into a square to be fed to the q_i functions
    x1 = c2 - c1*s / (1+b+s) # x1 = q_1(s)
    g1 = x1**3 + b # g1 = g(x1)
    if is_square(g1): # x1 is on the curve
        x, g = x1, g1
    else:
        x2 = -x1-1 # x2 = q_2(s)
        g2 = x2**3 + b
        if is_square(g2): # x2 is on the curve
            x, g = x2, g2
        else: # Neither x1 or x2 is on the curve, so x3 is
            x3 = 1 - (1+b+s)**2 / (3*s) # x3 = q3(s)
            g3 = x3**3 + b # g3 = g(x3)
            x, g = x3, g3
    y = sqrt(g)
    if is_odd(y) == is_odd(u):
        return (x, y)
    else:
        return (x, -y)
```

Note that the above forward-mapping function *f* differs from the one in the paper from Paragraph 1.3. That's because
the version there aims for constant-time operation. That matters for certain applications, but not for Elligator Squared
which is both inherently variable-time due to the sampling loop, and at least in the context of ECDH, does not operate
on secret data that must be protected from side-channel attacks.

```python
def r(Q,i):
    x, y = Q
    if i == 1 or i == 2:
        z = 2*x + 1
        t1 = c1 - z
        t2 = c1 + z
        if not is_square(t1*t2):
            # If t1*t2 is not square, then q1^-1(x)=(1+b)*t1/t2 or
            # q2^-1(x)=(1+b)*t2/t1 aren't either.
            return None
        if i == 1:
            if t2 == 0:
                return None # Would be division by 0.
            if t1 == 0 and is_odd(y):
                return None # Would require odd 0.
            u = sqrt((1+b)*t1/t2)
        else:
            x1 = -x-1 # q1(q2^-1(x)) = -x-1
            if is_square(x1**3 + b):
                return None # Would roundtrip through q1 instead of q2.
            # On the next line, t1 cannot be 0, because in that case z = c1, or
            # x = c2, or x1 == c3, and c3 is a valid X coordinate on the curve
            # (c3**3 + b == 1+b which is square), so the roundtrip check above
            # already catches this.
            u = sqrt((1+b)*t2/t1)
    else: # i == 3 or i == 4
        z = 2 - 4*b - 6*x
        if not is_square(z**2 - 16*(b+1)**2):
            return None # Inner square root in q3^-1 doesn't exist.
        if i == 3:
            s = (z + sqrt(z**2 - 16*(b+1)**2)) / 4 # s = q3^-1(x)
        else:
            if z**2 == 16*(b+1)**2:
                return None # r_3(x,y) == r_4(x,y)
            s = (z - sqrt(z**2 - 16*(b+1)**2)) / 4 # s = q3^-1(x)
        if not is_square(s):
            return None # q3^-1(x) is not square.
        # On the next line, (1+b+s) cannot be 0, because both (b+1) and
        # s are square, and 1+b is nonzero.
        x1 = c2 - c1*s / (1+b+s)
        if is_square(x1**3 + b):
            return None # Would roundtrip through q1 instead of q3.
        u = sqrt(s)
    if is_odd(y) == is_odd(u):
        return u
    else:
        return -u
```

```python
def encode(P):
    while True:
        u = field_random()
        T = curve_negate(f(u))
        Q = curve_add(T, P)
        if is_infinity(Q): Q = T
        j = secrets.choice([1,2,3,4])
        v = r(Q, j)
        if v is not Nothing: return (u, v)
```

```python
def decode(u, v):
    T = f(u)
    P = curve_add(T, f(v))
    if is_infinity(P): P = T
    return P
```

### 2.7 Encoding to bytes

The code above permits encoding group elements into uniform pairs of field elements, and back. However,
our actual goal is encoding and decoding to/from *bytes*. How to do that depends on how close the
field size *p* is to a power of *2*, and to a power of *256*.

First, in case *p* is close to a power of two (*(2<sup>⌈log<sub>2</sub>(p)⌉</sup>-p)/&radic;p* is close to *1*, or less), the
field elements can be encoded as bytes directly, and concatenated, possibly after padding with random bits. In this case,
directly encoding field elements as bits is indistinguishable from uniform.

Note that in this section, the variables represent integers again, and not field elements.

```python
P = ... # field size
FIELD_BITS = P.bit_length()
FIELD_BYTES = (FIELD_BITS + 7) // 8
PAD_BITS = FIELD_BYTES*8 - FIELD_BITS

def encode_bytes(P):
    u, v = encode(P)
    up = u + secrets.randbits(PAD_BITS) << FIELD_BITS
    vp = v + secrets.randbits(PAD_BITS) << FIELD_BITS
    return up.to_bytes(FIELD_BYTES, 'big') + vp.to_bytes(FIELD_BYTES, 'big')

def decode_bytes(enc):
    u = (int.from_bytes(enc[:FIELD_BYTES], 'big') & ((1 << FIELD_BITS) - 1)) % P
    v = (int.from_bytes(enc[FIELD_BYTES:], 'big') & ((1 << FIELD_BITS) - 1)) % P
    return decode(u, v)
```

Of course, in case `PAD_BITS` is *0*, the padding and masking can be left out. If `encode` is inlined
into `encode_bytes`, an additional optimization is possible where *u* is not generated as a random
field element, but as a random padded number directly.

```python
def encode_bytes(P):
    while True:
        up = secrets.randbits(FIELD_BYTES * 8)
        u = (ub & ((1 << FIELD_BITS) - 1)) % P
        T = curve_negate(f(u))
        Q = curve_add(T, P)
        if is_infinity(Q): Q = T
        j = secrets.choice([1,2,3,4])
        v = r(Q, j)
        if v is not Nothing:
            vp = v + secrets.randbits(PAD_BITS) << FIELD_BITS
            return up.to_bytes(FIELD_BITS, 'big') + vp.to_bytes(FIELD_BYTES, 'big')
```

In case *p* is **not** close to a power of two, a different approach is needed. The code below implements the
algorithm suggested in the Elligator Squared paper:

```python
P = ...   # field size
P2 = P**2 # field size squared
ENC_BYTES = (P2.bit_length() * 5 + 31) // 32
ADD_RANGE = (256**ENC_BYTES) // P2
THRESH    = (256**ENC_BYTES) % P2

def encode_bytes(P):
    u, v = encode(P)
    w = u*P + v
    w += secrets.randbelow(ADD_RANGE + (w < THRESH))*P2
    return w.to_bytes(ENC_BYTES, 'big')

def decode_bytes(enc):
    w = int.from_bytes(enc, 'big') % P2
    u, v = w >> P, w % P
    return decode(u, v)
```

## 3 Optimizations

Next we'll convert these algorithms to a shape that's more easily mapped to low-level implementations.

### 3.1 Delaying/avoiding inversions and square roots

Techniques:
* Delay inversions where possible by operating on fractions until the exact result is certainly required.
* Avoid inversions inside *is_square*: *is_square(n / d) = is_square(nd)* (multiplication with *d<sup>2</sup>*), and *is_square((n/d)<sup>3</sup> + b) = is_square(n<sup>3</sup>d + Bd<sup>4</sup>)* (multiplication with *d<sup>4</sup>*).
* Make arguments to *is_square* and *sqrt* identical if the latter follows the former. This means that implementations without fast Jacobi symbol can just compute and use the square root directly instead.
* Multiply with small constants to avoid divisions.
* Avoid common subexpressions.

```python
def f(u):
    s = u**2
    # Write x1 as fraction: x1 = n / d
    d = 1+b+s
    n = c2*d - c1*s
    # Compute h = g1*d**4, avoiding a division.
    h = d*n**3 + b*d**4
    if is_square(h):
        # If h is square, then so is g1.
        i = 1/d
        x = n*i # x = n/d
        y = sqrt(h)*i**2 # y = sqrt(g) = sqrt(h)/d**2
    else:
        # Update n so that x2 = n / d
        n = -n-d
        # And update h so that h = g2*d**4
        h = d*n**3 + b*d**4
        if is_square(h):
            # If h is square, then so is g2.
            i = 1/d
            x = n*i # x = n/d
            y = sqrt(h)*i**2 # y = sqrt(g) = sqrt(h)/d**2
        else:
            x = 1 - d**2 / (3*s)
            y = sqrt(x**3 + b)
    if is_odd(y) != is_odd(u):
        y = -y
    return (x, y)
```

```python
def r(x,y,i):
    if i == 1 or i == 2:
        z = 2*x + 1
        t1 = c1 - z
        t2 = c1 + z
        t3 = (1+b) * t1 * t2
        if not is_square(t3):
            return None
        if i == 1:
            if t2 == 0:
                return None
            if t1 == 0 and is_odd(y):
                return None
            u = sqrt(t3) / t2
        else:
            if is_square((-x-1)**3 + b):
                return None
            u = sqrt(t3) / t1
    else:
        z = 2 - 4*b - 6*x
        t1 = z**2 - 16*(b+1)**2
        if not is_square(t1):
            return None
        r = sqrt(t1)
        if i == 3:
            t2 = z + r
        else:
            if r == 0:
                return None
            t2 = z - r
        # t2 is now 4*s (delaying the divsion by 4)
        if not is_square(t2):
            return None
        # Write x1 as a fraction: x1 = d / n
        d = 4*(b+1) + t2
        n = (2*(b+1)*(c1-1)) + c3*t2
        # Compute h = g1*d**4
        h = n**3*d + b*d**4
        if is_square(h):
            # If h is square then so is g1.
            return None
        u = sqrt(t2) / 2
    if is_odd(y) != is_odd(u):
        u = -u
    return u
```

### 3.2 Broken down implementation

The [test.sage](test.sage) script contains both implementations above, plus a an additional
one with one individual field operation per line, reusing variables where possible.
This format can more directly be translated to a low-level implementation.

## 4 Performance

### 4.1 Operation counts

The implementation above requires the following average operation counts:
* For ***f()***: *1* inversion, *1.5* square tests, *1* square root
* For ***r()***: *0.1875* inversions, *1.5* square tests, *0.5* square roots
* For ***encode()***: *8.75* inversions, *12* square tests, *6* square roots
* For ***decode()***: *3* inversions, *3* square tests, *2* square roots

When no square test function is available, or one that takes more than half
the time of a square root, it is better to replace square tests with square roots.
As many square tests are followed by an actual square root of the same argument
if succesful, these don't need to be repeated anymore. The operation counts
for the resulting algorithm then become:
* For ***f()***: *1* inversion, *1.75* square roots
* For ***r()***: *0.1875* inversions, *1.5* square roots
* For ***encode()***: *8.75* inversions, *13* square roots
* For ***decode()***: *3* inversions, *3.5* square roots

### 4.2 Benchmarks

On a Ryzen 5950x system, an implementation following the procedure described in
this document using the [libsecp256k1](https://github.com/bitcoin-core/secp256k1/pull/982)
library, takes *47.8 &micro;s* for encoding and *14.3 &micro;s* for decoding.
For reference, the same system needs *0.86 &micro;s* for a (variable-time)
modular inverse, *1.1 &micro;s* for a (variable-time)quadratic character,
*3.8 &micro;s* for a square root, and *37.6 &micro;s* for an ECDH evaluation.

## 5 Alternatives

In the [draft RFC](https://datatracker.ietf.org/doc/draft-irtf-cfrg-hash-to-curve/)
on hashing to elliptic curves an alternative approach is discussed: transform points
on a *y<sup>2</sup> = x<sup>3</sup> + b* curve to an isogenic *y<sup>2</sup> = x<sup>3</sup> + a'x + b'*
curve, with *a'b' &ne; 0*, and then use the mapping function by [Brier et al.](https://eprint.iacr.org/2009/340.pdf),
on that curve. This has the advantage
of having a simpler (and computationally cheaper) forward mapping function *f*. However, the reverse mapping
function *r* in this case is computationally more expensive due to higher-degree equations. Overall, for
Elligator Squared encoding and decoding, these two roughly cancel out, while making the algorithm
significantly more complex. There is some ugliness too in that the conversion to the isogenic curve and
back does not roundtrip exactly, but maps points to a (fixed) multiple of themselves. This isn't
exactly a problem in the ECDH setting, but it means the Elligator Squared routines can't be treated as
a black box encoder and decoder.
