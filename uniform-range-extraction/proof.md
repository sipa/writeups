# Proof of joint maximal uniformity

## Problem

Given a uniformly random *x<sub>0</sub>* in *[0,2<sup>B</sup>)*, and *m*
ranges *n<sub>1</sub>*, *n<sub>2</sub>*, *...*, *n<sub>m</sub>*, each in
*[1,2<sup>B</sup>)*, prove that the joint distribution of
*(o<sub>1</sub>,o<sub>2</sub>,...,o<sub>m</sub>)* is maximally uniform,
where for *i in [1,m]*:
* *o<sub>i</sub> = &LeftFloor;x<sub>i-1</sub>n<sub>1</sub> / 2<sup>B</sup>&RightFloor*
* *x<sub>i</sub> = (x<sub>i-1</sub>n<sub>i</sub> mod 2<sup>B</sup>) + (&LeftFloor;x<sub>i-1</sub>n<sub>i</sub> / 2<sup>B</sup>&RightFloor; mod 2<sup>r<sub>i</sub></sup>)*, where *2<sup>r<sub>i</sub></sup>* is the largest power of *2* that divides *n<sub>i</sub>*.

This describes the behavior of *m* repeated extractions using *extract<sub>4</sub>*.

## Proof

***Theorem 1*** When *x<sub>0</sub> = 0*, all *o<sub>i</sub>* and *x<sub>i</sub>* are *0*.

Trivial.

***Theorem 2*** Increasing *x<sub>0</sub>* will either leave the *(o<sub>1</sub>,o<sub>2</sub>,...,o<sub>m</sub>)* vector
unchanged, or increase it (when using lexicographic order).

Every individual step from *x<sub>i-1</sub>* to *(o<sub>i</sub>,x<sub>i</sub>)* maintains order, so repeated application does too.

## Acknowledgement

Thanks to Timothy B. Terriberry for suggesting this proof strategy.
