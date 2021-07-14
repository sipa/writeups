# Minimizing the redundancy in Golomb Coded Sets

A Golomb Coded Set (GCS) is a set of *N* distinct integers within the range *[0..MN-1]*, whose order does not matter, and stored by applying a Golomb-Rice coder with parameter *B* to the differences between subsequent elements after sorting. When the integers are hashes of elements from a set, this is an efficient encoding of a probabilistic data structure with false positive rate *1/M*. It is asymptotically *1 / log(2)* (around 1.44) times more compact than Bloom filters, but harder to update or query.

The question we try to answer in this document is what combinations of *B* and *M* minimize the resulting size of the filter, and find that the common suggestion *B = log<sub>2</sub>(M)* is not optimal.

## Size of a Golomb Coded Set

To determine the size of a Golomb coding of a set, we model the differences between subsequent elements after sorting as a geometric distribution with *p = 1 / M*. This is a good approximation if the size of the set is large enough.

The Golomb-Rice encoding of a single difference *d* consists of:
* A unary encoding of *l = floor(d / 2<sup>B</sup>)*, so *l* 1 bits plus a 0 bit.
* The lower *B* bits of *d*.

In other words, its total length is *B + 1 + floor(d / 2<sup>B</sup>)*. To compute the expected value of this expression, we start with *B + 1*, and add *1* for each *k* for which *d &ge; 2<sup>B</sup>k*. In a geometric distribution with *p = 1 / M*, *P(d &ge; 2<sup>B</sup>k) = (1 - 1/M)<sup>2<sup>B</sup>k</sup>*. Thus, the total expected size becomes *B + 1 + &sum;((1 - 1/M)<sup>2<sup>B</sup>k</sup> for k=1...&infin;)*. This sum is a geometric series, and its limit is *B + 1 / (1 - (1 - 1/M)<sup>2<sup>B</sup></sup>)*. It can be further approximated by *B + 1 / (1 - e<sup>-2<sup>B</sup>/M</sup>)*.

For *M = 2<sup>20</sub>* and *B = 20*, it is ***21.58197*** while a simulation of a GCS with *N=10000* gives us ***21.58187***. Most of the inaccuracy is due to the fact that the differences between subsequent elements in a sorted set are not exactly independent samples from a single distribution.

## Minimizing the GCS size

For a given value *M* (so a given false positive rate), we want to minimize the size of the GCS.

In other words, we need to see where the derivative of the expression above is 0. That derivative is *1 - log(2)e<sup>2<sup>B</sup>/M</sup>2<sup>B</sup> / (M(e<sup>2<sup>B</sup>/M</sup>-1)<sup>2</sup>)*, and it is zero when *log(2)e<sup>2<sup>B</sup>/M</sup>2<sup>B</sup> = M(e<sup>2<sup>B</sup>/M</sup>-1)<sup>2</sup>*. If we substitute *r = 2<sup>B</sup>/M*, we find that *log(2)e<sup>r</sup>r = (e<sup>r</sup>-1)<sup>2</sup>* must hold, or *1 + log(&radic;2)r = cosh(r)*, leading to the solution *r = 2<sup>B</sup>/M = 0.6679416*.

In other words, we find that the set size is minimized when *B = log<sub>2</sub>(M) - 0.5822061*, or *M = 1.497137 2<sup>B<sup>*. These numbers are only exact for the approximation made above, but simulating the size for actual random sets confirms that these are close to optimal.
  
Of course, *B* can only be chosen to be an integer. To find the range of *M* values for which a given *B* value is optimal, we need to find the switchover point. At this switchover point, for a given *M*, *B* and *B+1* result in the same set size. If we solve *B + 1 + 1 / (1 - exp(-2<sup>B</sup>/M)) = B + 1 + 1 / (1 - exp(-2<sup>B+1</sup>/M))*, we find *M = 2<sup>B</sup> / log((1 + &radic;5)/2)*. This means a given *B* value is optimal in the range *M = 1.039043 2<sup>B</sup> ... 2.078087 2<sup>B</sub>*.

Surprisingly *2<sup>B</sup>* itself is outside that range. This means that if *M* is chosen as *2<sup>Q</sup>* with integer *Q*, the optimal value for *B* is **not** *Q* but *Q-1*.

## Compared with entropy

A next question is how close we are to optimal.

To answer this, we must find out how much entropy is there in a set of *N* uniformly randomly integers in range *[0..MN-1]*.

The total number of such possible sets, taking into account that the order does not matter, is simply *(MN choose N)*. This can be written as *((MN-N+1)(MN-N+2)...(MN)) / N!*. When *M* is large enough, this can be approximated by *(MN)<sup>N</sup> / N!*. Using Stirling's approximation for  *N!* gives us *(eM)<sup>N</sup> / &radic;(2&pi;N)*.

As each of these sets is equally likely, information theory tells us an encoding for a randomly selected set must use at least *log<sub>2</sub>((eM)<sup>N</sup> / &radic;(2&pi;N))* bits of data, or at least *log<sub>2</sub>((eM)<sup>N</sup> / &radic;(2&pi;N))/N* per element. This equals *log<sub>2</sub>(eM) - log<sub>2</sub>(2&pi;N)/(2N)*. For large *N*, this expression approaches *log<sub>2</sub>(eM)*.

For practical numbers, this approximation is pretty good. When picking *M = 2<sup>20</sup>*, this gives us ***21.44270*** bits per element, while the exact value of *log<sub>2</sub>(MN choose N)/N* for *N = 10000* is ***21.44190***.

If we look at the ratio between our size formula *B + 1 / (1 - e<sup>-2<sup>B</sup>/M</sup>)* and the entropy *log<sub>2</sub>(eM)*, evaluated for *M = 1.497137 2<sup>B</sub>*, we get *(B + 2.052389)/(B + 2.024901)*. For *B = 20* that value is *1.001248*, which means the approximate GCS size is less than 0.125% larger than theoretically possible. To contrast, if *M = 2<sup>M</sup>*, the redundancy is around 0.65%.

## Conclusion

When you have freedom to vary the false positive rate for your GCS, picking *M = 1.497137 2<sup>Q</sup>* for an integer *Q* will give you the best bang for the buck. In this case, use *B = Q* and you end up with a set only slightly larger than theoretically possible for that false positive rate. 

When you don't have that freedom, use *B = floor(log<sub>2</sub>(M) - 0.055256)*.