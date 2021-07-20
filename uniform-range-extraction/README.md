# Extracting multiple uniform numbers from a hash

This document introduces a technique for extracting multiple numbers
in any range from a single hash function result, while optimizing for various
uniformity properties.

* [Introduction](#introduction)
  + [The fast range reduction](#the-fast-range-reduction)
  + [Maximally uniform distributions](#maximally-uniform-distributions)
* [Generalizing to multiple outputs](#generalizing-to-multiple-outputs)
  + [Splitting the hash in two](#splitting-the-hash-in-two)
  + [Transforming the hash](#transforming-the-hash)
  + [Extracting and updating the state](#extracting-and-updating-the-state)
  + [Fixing individual uniformity](#fixing-individual-uniformity)
  + [Avoiding the need to decompose *n*](#avoiding-the-need-to-decompose--n-)
  + [C version](#c-version)
* [Use as a random number generator?](#use-as-a-random-number-generator-)
* [Conclusion](#conclusion)
* [Acknowledgement](#acknowledgement)

## Introduction

### The fast range reduction

In [this post](https://lemire.me/blog/2016/06/27/a-fast-alternative-to-the-modulo-reduction/)
by Daniel Lemire, a fast method is described to map a *B*-bits hash *x* to a number in range *[0,n)*.
Such an operation is needed for example to convert the output of a hash function to a hash table index.
The technique is primarily aimed at low-level languages where the cost of this operation may already matter,
but for presentation purposes I'm going to use Python here.

```python
B = 32
MASK = 2**B - 1

def extract(x, n):
    """Map x in [0,2**B) to output in [0,n)."""
    assert 0 <= x <= MASK
    assert 0 < n
    return (x * n) >> B
```

This function has an interesting property: if *x* is uniformly distributed in
*[0,2<sup>B</sup>)*, then *extract(x,n)* (for any non-zero *n*) will be as close to
uniform as *(x mod n)* is. The latter is often used in hash table implementations, but
relatively slow on modern CPUs. As *extract(x,n)* is just as uniform, it's a great
drop-in replacement for the modulo reduction. Note that it doesn't behave **identically** to that; it
just has a similar distribution, and that's all we need.

### Maximally uniform distributions

We can state this property a bit more formally. When starting from an input that is
uniformly distributed over *2<sup>B</sup>* possible values, and obtaining our
output by applying a deterministic function to *n* outputs, the probability of every
output must be a multiple of *2<sup>-B</sup>*. With that constraint, the distribution
closest to uniform is one that has *2<sup>B</sup> mod n* values with probability
*&LeftCeil;2<sup>B</sup>/n&RightCeil;/2<sup>B</sup>* each, and
*n - (2<sup>B</sup> mod n)* values with probability
*&LeftFloor;2<sup>B</sup>/n&RightFloor;/2<sup>B</sup>* each. We will call such
distributions **maximally uniform**, with the parameters *B* and *n* implicit
from context. If *n* is a power of two not larger than *2<sup>B</sup>*, only the
uniform distribution itself is maximally uniform.

To reach such a maximally uniform distribution, it suffices that the function from the hash has the property
that every output can be reached from either exactly *&LeftFloor;2<sup>B</sup>/n&RightFloor;*
inputs, or exactly *&LeftCeil;2<sup>B</sup>/n&RightCeil;*. This is the case for both *x mod n* and *extract(x,n)*.

## Generalizing to multiple outputs

But what if we want multiple independent outputs, say both a number in range *[0,n<sub>1</sub>)*
and a number in range *[0,n<sub>2</sub>)*? This problem appears in certain hash table
variations (such as [Cuckoo Filters](https://en.wikipedia.org/wiki/Cuckoo_filter) and
[Ribbon Filters](https://arxiv.org/abs/2103.02515)), where both a table position and another
hash of each data element are needed.

It's of course possible to compute multiple hashes,
for example using prefixes like *x<sub>i</sub> = H(i || input)*, and using *extract* on each.
Increasing the number of hash function invocations comes with computational cost, however, and
furthermore **feels** unnecessary, especially when *n<sub>1</sub>n<sub>2</sub> &leq; 2<sup>B</sup>*.
Can we avoid it?

### Splitting the hash in two

Another possibility is simply splitting the hash into two smaller hashes, and applying *extract*
on each. Here is the resulting distribution you'd get, starting from a (for demonstration
purposes very small) *8*-bit hash, extracting numbers in ranges *n<sub>1</sub> = 6* and
*n<sub>2</sub> = 10* from the bottom and top *4* bits using *extract*:

```python
x = hash(...)
B = 4
out1 = extract(x & 15, 6)
out2 = extract(x >> 4, 10)
```

<table>
  <tr>
    <th rowspan="2">Variable</th>
    <th colspan="10"><center>Probability / 2<sup>8</sup> for value ...</center></th>
  </tr>
  <tr>
    <th>0</th>
    <th>1</th>
    <th>2</th>
    <th>3</th>
    <th>4</th>
    <th>5</th>
    <th>6</th>
    <th>7</th>
    <th>8</th>
    <th>9</th>
  </tr>
  <tr>
    <th><em>out<sub>1</sub></em></th>
    <td>48</td>
    <td>48</td>
    <td>32</td>
    <td>48</td>
    <td>48</td>
    <td>32</td>
    <td>-</td>
    <td>-</td>
    <td>-</td>
    <td>-</td>
  </tr>
  <tr>
    <th><em>out<sub>2</sub></em></th>
    <td>32</td>
    <td>32</td>
    <td>16</td>
    <td>32</td>
    <td>16</td>
    <td>32</td>
    <td>32</td>
    <td>16</td>
    <td>32</td>
    <td>16</td>
  </tr>
</table>

It is no surprise that all probabilities are a multiple of *16 (/ 2<sup>8</sup>)*, as they're based
on just *4*-bit hash (fragments) each. It does however show that with respect to the original
*8*-bit hash, these results are very far from maximally uniform: for that, the table values
in each row can only differ by one.

### Transforming the hash

Alternatively, it is possible to apply a transformation to the output of the hash function, and then to feed
both the transformed and untransformed hash to *extract*. The Knuth multiplicative hash (multiplying
by a large randomish odd constant modulo *2<sup>B</sup>*) is a popular choice. Redoing our example, we get:

```python
x = hash(...)
out1 = extract(x, 6)
out2 = extract((x * 173) & 0xFF, 10)
```

<table>
  <tr>
    <th rowspan="2">Variable</td>
    <th colspan="10">Probability / 2<sup>8</sup> for value ...</th>
  </tr>
  <tr>
    <th>0</th>
    <th>1</th>
    <th>2</th>
    <th>3</th>
    <th>4</th>
    <th>5</th>
    <th>6</th>
    <th>7</th>
    <th>8</th>
    <th>9</th>
  </tr>
  <tr>
    <th><em>out<sub>1</sub></em></th>
    <td>43</td>
    <td>43</td>
    <td>42</td>
    <td>43</td>
    <td>43</td>
    <td>42</td>
    <td>-</td>
    <td>-</td>
    <td>-</td>
    <td>-</td>
  </tr>
  <tr>
    <th><em>out<sub>2</sub></em></th>
    <td>26</td>
    <td>26</td>
    <td>25</td>
    <td>26</td>
    <td>25</td>
    <td>26</td>
    <td>26</td>
    <td>25</td>
    <td>26</td>
    <td>25</td>
  </tr>
</table>

This gives decent results, as now both *out<sub>1</sub>* and *out<sub>2</sub>* are maximally uniform. This in
fact holds with this approach regardless of what values of *n<sub>1</sub>* and *n<sub>2</sub>*
are used. If we look at the **joint** distribution, however, the result is suboptimal:

<table>
  <tr>
     <th rowspan="2" colspan="2"></th>
     <th colspan="10">Value of <em>out<sub>2</sub></em></th>
     <th rowspan="2">Total</th>
  </tr>
  <tr>
    <th>0</th>
    <th>1</th>
    <th>2</th>
    <th>3</th>
    <th>4</th>
    <th>5</th>
    <th>6</th>
    <th>7</th>
    <th>8</th>
    <th>9</th>
  </tr>
  <tr>
    <th rowspan="6"><em>out<sub>1</sub></em></th>
    <th>0</th>
    <td>6</td><td>4</td><td>3</td><td>6</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>3</td><td>43</td>
  <tr>
    <th>1</th>
    <td>6</td><td>4</td><td>3</td><td>4</td><td>6</td><td>3</td><td>4</td><td>6</td><td>4</td><td>3</td><td>43</td>
  <tr>
    <th>2</th>
    <td>4</td><td>6</td><td>3</td><td>4</td><td>5</td><td>3</td><td>4</td><td>5</td><td>4</td><td>4</td><td>42</td>
  <tr>
    <th>3</th>
    <td>4</td><td>4</td><td>5</td><td>4</td><td>3</td><td>6</td><td>4</td><td>3</td><td>6</td><td>4</td><td>43</td>
  <tr>
    <th>4</th>
    <td>3</td><td>4</td><td>6</td><td>4</td><td>3</td><td>6</td><td>4</td><td>3</td><td>4</td><td>6</td><td>43</td>
  <tr>
    <th>5</th>
    <td>3</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>6</td><td>3</td><td>4</td><td>5</td><td>42</td>
  <tr>
     <th colspan="2">Total</th>
    <td>26</td><td>26</td><td>25</td><td>26</td><td>25</td><td>26</td><td>26</td><td>25</td><td>26</td><td>25</td><td>256</td>
  </tr>
</table>

While *out<sub>1</sub>* and *out<sub>2</sub>* are now individually maximally uniform, the distribution of the combination
of their values is **not**. This matters, because for example in a Cuckoo Filter, one doesn't just care about
the uniformity of the data hashes, but the uniformity of data hashes **in each individual cell** in the table.
If we'd use *out<sub>1</sub>* as table index, and *out<sub>2</sub>* as hash to place in that table cell, this
joint distribution shows that the per-cell hash distribution isn't maximally uniform.

### Extracting and updating the state

Turns out, it is easy to make the joint distribution maximally uniform. It is possible to create a variant
of *extract* that doesn't just return a number in the desired range, but also returns an updated
"hash" (which I'll call **state** in what follows) which is ready to be used for further extractions. The idea is that this updating should
move the unused portion of the entropy in that hash to the top bits, so that the next extraction
will primarily use those. And we effectively already have that: the bottom bits of `tmp`, which
aren't returned as output, are exactly that.

```python
def extract2(x, n):
    """Given x in [0,2**B), return out in [0,n) and new x."""
    assert 0 <= x <= MASK
    assert 0 < n
    tmp = x * n
    new_x = tmp & MASK
    out = tmp >> B
    return out, new_x

# Usage
x1 = hash(...)
out1, x2 = extract2(x1, n1)
out2, _  = extract2(x2, n2)
```

I don't have a proof, but it can be verified exhaustively for small values of *B*, *n1*, and *n2*
that the resulting joint distribution of *(out<sub>1</sub>,out<sub>2</sub>)* is maximally uniform.
In fact, this property remains true regardless of how many values are extracted.

Repeating the earlier experiment to extract a range *n<sub>1</sub> = 6* and range *n<sub>2</sub> = 10*
value from a *B=8*-bit hash, we get:

<table>
  <tr>
     <th rowspan="2" colspan="2"></th>
     <th colspan="10">Value of <em>out<sub>2</sub></em></th>
     <th rowspan="2">Total</th>
  </tr>
  <tr>
    <th>0</th>
    <th>1</th>
    <th>2</th>
    <th>3</th>
    <th>4</th>
    <th>5</th>
    <th>6</th>
    <th>7</th>
    <th>8</th>
    <th>9</th>
  </tr>
  <tr>
    <th rowspan="6"><em>out<sub>1</sub></em></th>
    <th>0</th>
    <td>5</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>43</td>
  <tr>
    <th>1</th>
    <td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>5</td><td>4</td><td>43</td>
  <tr>
    <th>2</th>
    <td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>42</td>
  <tr>
    <th>3</th>
    <td>5</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>43</td>
  <tr>
    <th>4</th>
    <td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>5</td><td>4</td><td>43</td>
  <tr>
    <th>5</th>
    <td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>42</td>
  <tr>
     <th colspan="2">Total</th>
    <td>26</td><td>26</td><td>26</td><td>26</td><td>24</td><td>26</td><td>26</td><td>26</td><td>26</td><td>24</td><td>256</td>
  </tr>
</table>

Indeed, both *out<sub>1</sub>* individually, and *(out<sub>1</sub>,out<sub>2</sub>)* jointly now look maximally uniform.
However, *out<sub>2</sub>* individually **lost** its maximal uniformity: *out<sub>2</sub> = 4* (and *9*) have
probability *24/256*, while the others have probability *26/256*. Can we fix that?

### Fixing individual uniformity

The cause is simple: given an input state *x<sub>i</sub>*, the next state *x<sub>i+1</sub> = x<sub>i</sub>n<sub>i</sub> mod 2<sup>B</sup>*.
When *n<sub>i</sub>* is even, it will increment the number of consecutive bottom zero bits in the *x<sub>i</sub>* state variable by at least
one. When *n<sub>i</sub>* is divisible by a large power of two, multiple zeroes will get introduced. Those zeroes mean the *x<sub>2</sub>*
variable has less entropy than *x<sub>1</sub>*, which in turn results in non-maximal uniformity in *out<sub>2</sub>*.

To address that, we must prevent the degeneration of the quality of the state variables (each *x<sub>i</sub>*).
We already know that even ranges cause a loss of entropy in the state, and that is in fact the only cause.
Whenever the range *n<sub>i</sub>* is odd, the operation *x<sub>i+1</sub> = x<sub>i</sub>n<sub>i</sub> mod 2<sup>B</sup>* is
a bijection. Because the [gcd](https://en.wikipedia.org/wiki/Greatest_common_divisor) of an odd number and
*2<sup>B</sup>* is *1*, every odd number has a [modular inverse](https://en.wikipedia.org/wiki/Modular_multiplicative_inverse) modulo *2<sup>B</sup>*, and thus this
multiplication operation can be undone by multiplying with this inverse. That implies no entropy can be lost by this operation.

Let's restrict the problem to **just** powers of two: what if *n<sub>i</sub> = 2<sup>r<sub>i</sub></sup>*? In this case,
*extract<sub>2</sub>* is equivalent to returning the top *r<sub>i</sub>* bits of *x<sub>i</sub>* as output, and the bottom *(B-r<sub>i</sub>)* bits of it
(left shifted by *r<sub>i</sub>* positions) as new state. This left shift destroys information, but we can simply replace it
by a left rotation: that brings the same identical bits to the top and thus maintains the maximal joint uniformity
property, but also leaves all the entropy in the state intact.

Now we need to combine this rotation with something that supports non-powers-of-2, while retaining all the
uniformity properties we desire. Every non-zero integer *n* can be written as *2<sup>r</sup>k*, where *k* is odd.
Multiplication by odd numbers preserves entropy. Multiplication by powers of 2 (that aren't 1) does not, but those
can be replaced by bitwise rotations. Composing these two operations yields a solution:

```python
def rotl(x, n):
    """Bitwise left rotate x by n positions."""
    return ((x << n) | (x >> (B - n))) & MASK

def extract3(x, k, r):
    """Given x in [0,2**B), return output in [0,k*2**r) and new x."""
    assert 0 <= x <= MASK
    assert k & 1
    assert k > 0
    assert r >= 0
    out = (x * k << r) >> B
    new_x = rotl((x * k) & MASK, r)
    return out, new_x
```

The output is the same as *extract* and *extract<sub>2</sub>*, but the new state differs: instead of having *r* 0-bits
in the bottom, those bits are now obtained by rotating *kx*. The top bits are unchanged.

This is clearly a bijection, as both multiplying with *k* (mod *2<sup>B</sup>*), and rotations are bijections.
So when repeating the earlier example, we get:

<table>
  <tr>
     <th rowspan="2" colspan="2"></th>
     <th colspan="10">Value of <em>out<sub>2</sub></em></th>
     <th rowspan="2">Total</th>
  </tr>
  <tr>
    <th>0</th>
    <th>1</th>
    <th>2</th>
    <th>3</th>
    <th>4</th>
    <th>5</th>
    <th>6</th>
    <th>7</th>
    <th>8</th>
    <th>9</th>
  </tr>
  <tr>
    <th rowspan="6"><em>out<sub>1</sub></em></th>
    <th>0</th>
    <td>5</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>43</td>
  <tr>
    <th>1</th>
    <td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>43</td>
  <tr>
    <th>2</th>
    <td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>42</td>
  <tr>
    <th>3</th>
    <td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>43</td>
  <tr>
    <th>4</th>
    <td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>5</td><td>4</td><td>43</td>
  <tr>
    <th>5</th>
    <td>4</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>5</td><td>4</td><td>4</td><td>4</td><td>42</td>
  <tr>
     <th colspan="2">Total</th>
    <td>26</td><td>26</td><td>25</td><td>26</td><td>25</td><td>26</td><td>26</td><td>25</td><td>26</td><td>25</td><td>256</td>
  </tr>
</table>

This is great. We now get that each individual *out<sub>i</sub>* is maximally uniform, and so is the joint distribution.
Again, only experimentally verified, but it appears that this property even generalizes rather strongly to arbitrary
numbers of extractions: the individual distribution of any extracted value, as well as the the joint distributions of
any **consecutively** extracted values appear to be maximally uniform.

### Avoiding the need to decompose *n*

The above *extract<sub>3</sub>* function works great, but it requires passing in the desired range of outputs in decomposed *2<sup>r</sup>k*
form. This is slightly annoying, and it can be avoided.

Consider what is happening. *extract<sub>3</sub>* behaves the same as *extract<sub>2</sub>* (with *n = 2<sup>r</sup>k*), except that the bottom *r*
bits of the new state are filled in, and not (necessarily) 0. Those bits are the result of rotating *xk* by *r* positions,
or put otherwise, the top *r* bits of *xk mod 2<sup>B</sup>*, and thus bits *B...(B+r-1)* of *x2<sup>r</sup>k = xn*, or,
the bottom *r* bits of *&LeftFloor;xn / 2<sup>B</sup>&RightFloor; = out*.
In other words, the bottom *r* bits of the output are copied into the new state. So we could write an identical *extract<sub>3</sub>* as:

```python3
def extract3(x, k, r):
    """Given x in [0,2**B), return output in [0,k*2**r) and new x."""
    assert 0 <= x <= MASK
    assert k & 1
    assert k > 0
    assert r >= 0
    n = k << r
    tmp = x * n
    out = tmp >> B
    new_x = (tmp & MASK) | (out & ((1 << r) - 1))
    return out, new_x
```

This almost avoids the need to know *r*, except for the need to construct the bitmask `(1 << r) - 1` = *2<sup>r</sup> - 1*.
This can be done very efficiently using a bit fiddling hack: `(n-1) & ~n`; that's identical to *(1 << r) - 1*, where *r* is
the number of consecutive zero bits in *n*, starting at the bottom. Put all together we can write a new *extract<sub>4</sub>* function
that behaves exactly like *extract<sub>3</sub>*, but just takes *n* as input directly:

```python
def extract4(x, n):
    """Given x in [0,2**B), return output in [0,n) and new x."""
    assert 0 <= x < MASK
    assert 0 < n <= MASK
    tmp = x * n
    out = tmp >> B
    new_x = (tmp & MASK) | (out & (n-1) & ~n)
    return out, new_x
```

### C version

I've used Python above for demonstration purposes, but this is of course easily translated to C or similar low-level languages:

```c
uint32_t extract4(uint32_t *x, uint32_t n) {
    uint64_t tmp = (uint64_t)*x * (uint64_t)n;
    uint32_t out = tmp >> 32;
    *x = tmp | (out & (n-1) & ~n);
    return out;
}
```

for *B=32*. A version supporting *B=64* hashes but restricted to 32-bit ranges can be written as:

```c
uint32_t extract4(uint64_t *x, uint32_t n) {
#if defined(UINT128_MAX) || defined(__SIZEOF_INT128__)
    unsigned __int128 tmp = (unsigned __int128)(*x) * n;
    uint32_t out = tmp >> 64;
    *x = tmp | (out & (n-1) & ~n);
    return out;
#else
    uint64_t x_val = *x;
    uint64_t t_hi = (x_val >> 32) * (uint64_t)n;
    uint64_t t_lo = (x_val & 0xffffffff) * (uint64_t)n;
    uint64_t mid33 = (t_lo >> 32) + (t_hi & 0xffffffff);
    uint32_t upper32 = (t_hi >> 32) + (mid33 >> 32);
    uint64_t lower64 = (mid33 << 32) | (t_lo & 0xffffffff);
    *x = lower64 | (upper32 & (n-1) & ~n);
    return upper32;
#endif
}
```

which makes use of a 64×64→128 multiplication if the platform supports `__int128`. If 64-bit ranges are
needed, a full double-limb multiplication is needed. The code is based on [this snippet](https://stackoverflow.com/a/26855440):

```c
uint64_t extract4(uint64_t *x, uint64_t n) {
#if defined(UINT128_MAX) || defined(__SIZEOF_INT128__)
    unsigned __int128 tmp = (unsigned __int128)(*x) * n;
    uint64_t out = tmp >> 64;
    *x = tmp | (out & (n-1) & ~n);
    return out;
#else
    uint64_t x_val = *x;
    uint64_t x_hi = x_val >> 32, x_lo = x_val & 0xffffffff;
    uint64_t n_hi = y >> 32, n_lo = y & 0xffffffff;
    uint64_t hh = x_hi * n_hi;
    uint64_t hl = x_hi * n_lo;
    uint64_t lh = x_lo * n_hi;
    uint64_t ll = x_lo * n_lo;
    uint64_t mid34 = (ll >> 32) + (lh & 0xffffffff) + (hl & 0xffffffff);
    uint64_t upper64 = hh + (lh >> 32) + (hl >> 32) + (mid34 >> 32);
    uint64_t lower64 = (mid34 << 32) | (ll & 0xffffffff);
    *x = lower64 | (upper64 & (n-1) & ~n);
    return upper64;
#endif
}
```

Note that for the final extraction it is unnecessary to update the state further, and the normal fast range
reduction *extract* function can be used instead. It is identical to the above routines, but with the `*x =` line
and (if present) the `uint64_t lower64 =` line removed.

## Use as a random number generator?

It is appealing to use this as the basis for a random number generator like interface, to produce extremely fast numbers in any range:

```python
class FastRangeExtractor:
    __init__(self, x):
        assert 0 <= x <= MASK
        self.x = x
    def randrange(self, n):
        assert 0 < n <= MASK
        tmp = self.x * n
        out = tmp >> B
        self.x = (tmp & MASK) | (out & (n-1) & ~n)
        return out
```

However, a word of caution: the extraction scheme(s) presented here only **extracts** information efficiently
and uniformly from the provided entropy, and doesn't introduce any unpredictability by itself. The simple
structure implies that if someone observes a number of consecutive ranges and their corresponding outputs, where the
product of those ranges exceeds *2<sup>B</sup>*, they can easily compute the state. This is easy to see, as
the maximal uniformity property in this case implies no outputs can be reached by more than one input (every
output must be reached by exactly 0 or exactly 1 input, if *&LeftFloor;2<sup>B</sup>/n&RightFloor; = 0*).
It also means that in this case, structure will remain in the produced numbers, as it can be seen as an
attempt to extract more entropy than was originally present. This is similar to the
[hyperplane structure](https://stats.stackexchange.com/questions/38328/hyperplane-problem-in-linear-congruent-generator)
present in the output of [linear congruential generators](https://en.wikipedia.org/wiki/Linear_congruential_generator).

Because of this, it is inadvisable to do extractions whose ranges multiply to a number larger than *2<sup>B</sup>*.

## Conclusion

We've constructed a simple and efficient generalization to multiple outputs of the fast range reduction method,
in a way that maximizes uniformity properties both for the indivdually extracted numbers and their joint distribution.

## Acknowledgement

Thanks for Greg Maxwell for several discussions that lead to this idea, as well as proofreading and suggesting
improvements to the text.
