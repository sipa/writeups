# Bitcoin's steady-state difficulty adjustment

## Abstract

In this document, we analyze the probabilistic behavior of Bitcoin's difficulty adjustment
rules under the following assumptions:
* The hashrate does not change during the period of time we're studying.
* Blocks are produced by a pure [Poisson process](https://en.wikipedia.org/wiki/Poisson_point_process), and carry the exact timestamp
  they were mined at.
* All timestamps and difficulty are arbitrary precision (treating them as real numbers, without rounding).
* There is no restriction on the per-window difficulty adjustment (the real protocols restricts these to a factor 4× or 0.25×).

The real-world hashrate is of course not constant, but making this simplification
does give us some insights into how stable the difficulty adjustment process can get.
The other assumptions do not affect the outcome of our analysis much, as long as the
[timewarp bug](https://bitcointalk.org/index.php?topic=43692.msg521772#msg521772) is not exploited.

Specifically, we wonder what the mean and standard deviation is for the durations of (sequences of)
blocks and windows, for randomly picked windows in the future, taking into account that the
difficulties for those windows are also subject to randomness.

## Introduction

The exact process studied is this:
* There is a fixed hash rate of $h$ hashes per time unit.
* A window is a sequence of $n$ blocks
  (with $n>2$).
  Block number $i$ is
  part of window number $j = {\lfloor}i/n{\rfloor}$.
  In Bitcoin $n$ is *2016*.
* Every window $j$ (and every block in that window) has an associated difficulty
  $D_j$.
* Every block $i$ has a length
  $L_i$, which is how long it took to
  produce the block. $L_i$ follows an [exponential distribution](https://en.wikipedia.org/wiki/Exponential_distribution):
  $L_i \sim \mathit{Exp}(\lambda = h/D_{\lfloor i/n \rfloor})$, independent from the lengths
  of all other blocks. Since the mean of an exponential distribution is $λ^{-1}$,
  the expected length of a block is $D_{\lfloor i/n \rfloor}/h$, which means the
  expected number of hashes for a block is $D_{\lfloor i/n \rfloor}$.
  The notion of difficulty in actual
  Bitcoin has an additional constant factor (roughly $2^{32}$), but that factor is not relevant for this
  discussion, so we ignore it here.
* The total length of a window is defined as the sum of the lengths of the blocks in it,
  $$W_j = \sum_{i=nj}^{jn+j-1} L_i$$
  Because the length of a window excluding its last block is relevant as well, we also define
  $$W^\prime_j = W_j - L_{jn+j-1} = \sum_{i=nj}^{jn+j-2} L_i$$
* The difficulty adjusts every $n$ blocks, aiming for roughly one block every
  $t$ time units.
  Specifically, $D_{j+1} = D_j tn / W^\prime_j$, or the difficulty
  gets multiplied by $tn$ (the expected time a window takes) divided by
  $W^\prime_j$ (the time between the first and last block in the window, but not
  including the time until the first block of the next window).
  In Bitcoin $t$ is *600 seconds*, and thus
  $tn$ is *2 weeks*.
* The initial difficulty $D_0$ is a given constant value $d_0$. All future difficulties are
  necessarily random variables (as they depend on $W^\prime_j$, which depend on
  $L_i$, which are random).

## Probability distribution of difficulties *D<sub>i</sub>*

The description above uses a random variable ($D_{\lfloor i/n \rfloor}$) in the parameterization
of $L_i$'s probability distribution. This makes reasoning complicated. To address this,
we introduce simpler "base" random variables: $B_i = hL_i / D_i$, representing how
"stretched" the number of hashes needed was compared to the difficulty. Due to the fact that the
$\lambda$ parameter of the exponential distribution is an
inverse [scale parameter](https://en.wikipedia.org/wiki/Scale_parameter#Rate_parameter),
this means
$$B_i \sim \mathit{Exp}(\lambda = 1)$$
for all $i$. All these
$B_i$ variables, even across windows, are identically distributed. Furthermore, they are
all independent from one another. Analogous to the $W_j$
and $W^\prime_j$ variables, we also introduce variables to express how many hashes each window
required, relative to the number of hashes expected based on their difficulty:
$$A_j = hW_j/D_j = \sum_{i=nj}^{n(j+1)-1} B_i$$
$$A^\prime_j = hW^\prime_j/hD_j = \sum_{i=nj}^{n(j+1)-2} B_i$$
These variables are i.i.d. (independent and identically distributed)
within their sets, and more generally independent from one another
unless they are based on overlapping $B_i$ variables. Furthermore,
together, the $B_i$ variables are *all* the randomness in the system;
as we'll see later, all other random variables can be written as
deterministic functions of them.

Given $A^\prime_j = hW^\prime_j/D_j$ and
$D_{j+1} = D_j tn / W^\prime_j$, we learn
that $D_{j+1} = htn / A^\prime_j$.
Surprisingly, this means that the distribution of all $D_j$
(except for $j=0$) only depends on what happened in the window before it,
and not the windows before that (and thus by extension, also not on
previous difficulties). Despite the fact
that the difficulty of the next window is computed as the difficulty of the previous window
multiplied by a correction factor, the actual previous value does not matter. This is because
by whatever factor the previous difficulty might have been "off", the same factor will appear in the rate
of the next window, exactly undoing it for that next window's difficulty.

As all the $A^\prime_j$ are i.i.d.,
so are the $D_j$ variables. But what is that distribution?
We start with the distribution of $A^\prime_j$.
These variables are the sum of $n-1$
distinct $B_i$ variables, which are all i.i.d. exponentially distributed.
The result of that is an [Erlang distribution](https://en.wikipedia.org/wiki/Exponential_distribution), and
$$A^\prime_j \sim \mathit{Erlang}(k=n-1, \lambda=1)$$
$$A_j \sim \mathit{Erlang}(k=n, \lambda=1)$$

As the Erlang distribution is a special case of a [gamma distribution](https://en.wikipedia.org/wiki/Gamma_distribution), we can also say that
$$A^\prime_j \sim \Gamma(\alpha=n-1, \beta=1)$$
Again exploiting the fact that
$\beta$ is an inverse scale parameter, that means that
$$A^\prime_j/htn \sim \Gamma(\alpha=n-1, \beta=htn)$$
Since the inverse of a gamma distribution is an
[inverse-gamma distribution](https://en.wikipedia.org/wiki/Inverse-gamma_distribution),
we conclude
$$D_{j+1} = htn/A^\prime_j \sim \mathit{InvGamma}(\alpha=n-1, \beta=htn)$$

Note again that $t$ and
$n$ are protocol constants
($tn$ is *2 weeks* in Bitcoin), and we
we have assumed that the hashrate $h$ is a constant for the duration of our
analysis. The $\mathit{InvGamma}$ distribution has mean
$\beta/(\alpha-1)$, so
$$E[D_{j+1}] = \frac{htn}{n-2}$$
For Bitcoin, this means the
average difficulty corresponds to $2016/2014 \approx 1.000993$ times *600 seconds* per block at
the given hashrate. Does this translate to blocks longer on average than *600 seconds* as well?

## Probability distribution of block lengths $L_i$

Remember that $B_i = hL_i/D_{\lfloor i/n \rfloor}$, and thus
$L_i = {B_i}{D_{\lfloor i/n \rfloor}}/h$. We know that
$D_j = htn/A^\prime_{j-1}$ as well, and thus
$L_i = tn{B_i}/A^\prime_{\lfloor i/n \rfloor -1}$.
$B_i$ is exponentially distributed, which is also a special case of a gamma distribution,
like $A^\prime_j$. Or
$$B_i \sim \Gamma(\alpha=1, \beta=1)$$
$$A^\prime_{\lfloor i/n \rfloor -1} \sim \Gamma(\alpha=n-1, \beta=1)$$
Thus, $L_i/tn = B_i / A_{\lfloor i/n \rfloor - 1}$ is distributed as the ratio of two independent gamma distributions with the
same $\beta$. Such a ratio is a
[beta prime distribution](https://en.wikipedia.org/wiki/Beta_prime_distribution) and
$$L_i/tn = B_i/A_{\lfloor i/n \rfloor-1} \sim \mathit{Beta'}(\alpha=1, \beta=n-1)$$

This distribution has mean $\alpha/(\beta-1)$, and thus the expected time per block is
$$E[L_i] = \frac{tn}{n-2}$$
Surprisingly, this is not the $t$ we were aiming for, or even the
$tn/(n-1)$ we might have
expected given that the last block's length is ignored in every window, but a factor $n/(n-2)$ times
$t$. The implication for Bitcoin,
if the assumptions made here hold, is that
the expected time per block under constant hashrate is not 10 minutes, but the factor $1.000993$ predicted in the previous section more:
***10 minutes and 0.5958 seconds***.

The variance for this distribution is $\alpha(\alpha+\beta-1)/((\beta-2)(\beta-1)^2)$, and thus
the standard deviation for the time per block is
$$\mathit{StdDev}(L_i) = \frac{tn}{n-2}\sqrt{\frac{n-1}{n-3}} \approx t\sqrt{1+\frac{6}{n}}$$
For Bitcoin this is ***10 minutes and 0.8941 seconds***.

## Probability distribution of multiple blocks in a window

These block lengths $L_i$ are however **not independent** if they belong to the same
window. That is because they share a common, but random, scaling factor: that window's difficulty.
Blocks from subsequent windows are not independent either, because they are related through the
first window's duration. This means we cannot just multiply the variance with $n$ to
obtain the variance for multiple blocks. Instead, we need to determine its probability distribution.

Let's look at the length of $r$ consecutive blocks in the same window, where
$0 \leq r \leq n$. The distribution of any $r$ distinct blocks in any single window (excluding the first window)
is the same, so for determining its distribution, assume without loss of generality the range
$n \ldots n+r-1$. Call the sum of those lengths
$$Y_r = \sum_{i=n}^{n+r-1} L_i$$
Given that $L_i = {B_i}{D_{\lfloor i/n \rfloor}}/h$, we get
$$Y_r = \sum_{i=n}^{n+r-1} \frac{{B_i}{D_1}}{h} = \frac{D_1}{h} \sum_{i=n}^{n+r-1} B_i$$
Substituting $D_j = htn/A^\prime_{j-1}$ we get
$$Y_r = \frac{tn}{A^\prime_0} \sum_{i=n}^{n+r-1} B_i$$
The sum in this expression is again a sum of $r$ i.i.d. exponential distributions, for which
$$\sum_{i=n}^{n+r-1} B_i \sim Erlang(k=r, \lambda=1) \sim \Gamma(\alpha=r, \beta=1)$$
Thus $Y_r$ is again the ratio of two independent gamma distributions with the same
$\beta$, and we obtain
$$Y_r/tn \sim \mathit{Beta'}(\alpha=r, \beta=n-1)$$

Using the formula for mean of a beta prime distribution we get
$$E[Y_r] = tn\frac{\alpha}{\beta-1} = \frac{rtn}{n-2}$$
And using the formula for variance we get
$$\mathit{StdDev}(Y_r) = tn\sqrt{\frac{\alpha(\alpha+\beta-1)}{(\beta-2)(\beta-1)^2}} = \frac{nt}{n-2}\sqrt{\frac{r(n+r-2)}{n-3}} \approx t\sqrt{r\left(1 + \frac{r+5}{n} + \frac{7r}{n^2}\right)}$$

This standard deviation is the same as what we'd get for the sum of $r(n+r-2)/(n-3)$ independent exponentially
distributed block lengths, each with mean $tn/(n-2)$. This expression grows quadratically, ranging from
$(n-1)/(n-3) \approx 1$ at
$r=1$, to
$2n(n-1)/(n-3) \approx 2n$ at
$r=n$.
If the block lengths were independent, we'd expect this to grow linearly. But because of the fact that there is
a shared random contribution to all of them (the difficulty), it grows faster.

When looking at the length of the whole window $W_1 = Y_n$ (or any other window
$W_j$ except the first where
$j=0$),
these expressions simplify using $r=n$ to:
$$E[W_j] = \frac{tn^2}{n-2}$$
$$\mathit{StdDev}(W_j) = \frac{tn}{n-2}\sqrt{\frac{2n(n-1)}{n-3}} \approx t\sqrt{2n+12}$$
For sufficiently large $n$, this approximates the standard deviation we'd expect from a Poisson process for
$2n$ blocks, if they were all mined at "exact" difficulty (the difficulty corresponding to the hashrate).
Why is this?
* $n$ blocks' worth of standard deviation come from the difficulty
  $D_j$, contributed by the randomness in the
  durations of the blocks in the previous window ($A^\prime_{j-1}$).
* $n$ blocks' worth of standard deviation come from the duration of the blocks in the window
  $W_j$ itself
  ($A_j$).

For Bitcoin this yields an average window duration of ***2 weeks, 20 minutes, 1.19 seconds*** with a
standard deviation of ***10 hours, 35 minutes, 55.59 seconds***.

## Properties of the sum of consecutive windows

Next we investigate is properties of the probability distribution of the sum of multiple consecutive
windows. This cannot be expressed as a well-studied probability distribution anymore, but we can compute
its mean and standard deviation.

Let's look at the sum $X_c$ of the lengths of
$c$ consecutive windows, each consisting of $n$ blocks. The first window is special, as it has a
different difficulty distribution than the others, so let's exclude it and look at windows $1$
through $c$. As far as the distribution is concerned, this is without loss of generality:
the distributions of any $c$ consecutive windows starting at window
$1$ and later are identical.
$$X_c = \sum_{j=1}^c W_j = tn \cdot \sum_{j=1}^c \frac{A_j}{A^\prime_{j-1}} = tn \cdot \sum_{j=1}^c \frac{A^\prime_j + B_{jn+n-1}}{A^\prime_{j-1}}$$

The terms of this summation are not independent, because all the "inner" $A^\prime_j$ variables occur in two terms:
once in the numerator and once in the denominator of the next one. This does not matter for the mean
$E[X_c]$ however: the expected value of a sum is the sum of the expected values, even when
they are not independent. Thus we find that
$$E[X_c] = \sum_{j=1}^c E[W_j] = ctn\cdot E\left[\frac{A_1}{A^\prime_0}\right] = \frac{ctn^2}{n-2}$$
This is just $2016/2014$ times *2c weeks* in Bitcoin's case.

To analyze the variance and standard deviation, we first introduce a new variable $T_j = L_{jn+n-1}$, the terminal
block of window $j$. This simplifies the expression to:
$$X_c = tn \cdot \sum_{j=1}^c \frac{A^\prime_j + T_j}{A^\prime_{j-1}}$$
where all the $A^\prime_j$ and
$T_j$ variables are independent, as they do not derive from overlapping $B_i$ variables. Furthermore, we
know the distribution of all of them:
$$A^\prime_j \sim \Gamma(\alpha=n-1, \beta=h)$$
$$T_j \sim \Gamma(\alpha=1, \beta=h)$$
Let $\sigma_c^2$ be the variance of this expression:
$$\sigma_c^2 = Var(X_c) = E[X_c^2] - E^2[X_c] = (tn)^2 E\left[\left(\sum_{j=1}^c \frac{A^\prime_j + T_j}{A^\prime_{j-1}}\right)^2\right] - \left(\frac{ctn^2}{n-2}\right)^2$$
Working on the second moment $E[X_c^2]$ divided by the constant factor
$(tn)^2$, we get:
$$\frac{E[X_c^2]}{(tn)^2} = \sum_{j=1}^{c} \sum_{m=1}^c E\left[\left(\frac{A^\prime_j + T_j}{A^\prime_{j-1}}\right)\left(\frac{A^\prime_m + T_m}{A^\prime_{m-1}}\right)\right] $$
By grouping the products into sums where $|j-m|$ is either
$0$,
$1$,
or more than $1$, and reverting
$A^\prime_j + T_j$ to
$A_j$ again in several places,
we get
$$\frac{E[X_c^2]}{(tn)^2} = \sum_{j=1}^{c} E\left[\frac{A_j^2}{{A^\prime_{j-1}}^2}\right] + 2\sum_{j=1}^{c-1} E\left[\left(\frac{A^\prime_j + T_j}{A^\prime_{j-1}}\right)\frac{A_{j+1}}{A^\prime_j}\right] + 2\sum_{j=1}^{c-2} \sum_{m=j+2}^{c} E\left[\frac{A_j A_m}{A^\prime_{j-1} A^\prime_{m-1}}\right] $$
Expanding the middle term further, we get
$$\frac{E[X_c^2]}{(tn)^2} = \sum_{j=1}^{c} E\left[\frac{A_j^2}{{A^\prime_{j-1}}^2}\right] + 2\sum_{j=1}^{c-1} E\left[\frac{A_{j+1}}{A^\prime_{j-1}} + \frac{T_j A_{j+1}}{A^\prime_{j-1}A^\prime_j}\right] + 2\sum_{j=1}^{c-2} \sum_{m=j+2}^{c} E\left[\frac{A_j A_m}{A^\prime_{j-1} A^\prime_{m-1}}\right] $$
Using the fact that the expectation of the product of independent variables is the product of their expectations, we can drop the indices and write
everything as a sum of the products of powers of independent variables. 
$$\frac{E[X_c^2]}{(tn)^2} = c E[A^2] E[{A^\prime}^{-2}] + 2(c-1)\left(E[A]E[{A^\prime}^{-1}] + E[T]E[A]E^2[{A^\prime}^{-1}]\right) + (c-1)(c-2) E^2[A] E^2[{A^\prime}^{-1}] $$
Knowing the distribution of all $A_j$,
$A^\prime_j$, and
$T_j$, we can calculate that
$E[A] = n$,
$E[A^2] = n(n+1)$,
$E[{A^\prime}^{-1}] = (n-2)^{-1}$,
$E[{A^\prime}^{-2}] = ((n-2)(n-3))^{-1}$,
$E[T] = 1$. Using those we get
$$\frac{E[X_c^2]}{(tn)^2} = \frac{cn(n+1)}{(n-2)(n-3)} + 2(c-1)\left(\frac{n}{n-2} + \frac{n}{(n-2)^2}\right) + \frac{(c-1)(c-2)n^2}{(n-2)^2} = n\frac{c^2 n^2 - 3c^2 n + 4c + 2n - 6}{(n-3)(n-2)^2}$$
So, we get
$$\sigma_c^2 = (tn)^2 \left( \frac{E[X_c^2]}{(tn)^2} - \left(\frac{cn}{n-2}\right)^2\right) = (tn)^2 \frac{2n(2c+n-3)}{(n-3)(n-2)^2}$$
and the standard deviation we're looking for is
$$\mathit{StdDev}(X_c) = \sigma_c = \frac{tn}{n-2} \sqrt{\frac{2n(2c+n-3)}{n-3}} \approx t \sqrt{2n + 4c + 8} $$

In Bitcoin's case where $n=2016$, this value increases *extremely* slowly with
$c$. For
$c=1$ (2016 blocks, or roughly 2 weeks) that gives the same *10 hours, 35 minutes, 55.59 seconds* as we found in the previous
section, but for $c=104$ (209664 blocks, or just under 1 halvening period) it is barely more:
***11 hours, 7 minutes, 38.53 seconds***. The explanantion for this is that most randomness is compensated for:
when an overly-long block randomly occurs in any window but the last one, the difficulty of the next window
will be increased, resulting in a shorter next window, which mostly compensates for the increase.

Because of this cancellation, the standard deviation for the length of multiple consecutive windows
grows *slower* than what would be expected for independent events. This is in sharp contrast with
the evolution of the standard deviation for the length of multiple blocks within one window, where
the growth is *faster* than what would be expected for independent events.
For sufficiently large $n$, the standard deviation approaches
$t\sqrt{2n + 4c}$, which is the same as the standard deviation we'd expect from a Poisson process with
$2n + 4c$ blocks, all at exact difficulty. This can again be explained by looking at the sources of
randomness:
* The $2n$ blocks' worth are the result of the
  $n$ blocks of the window preceding the ones considered, by contributing to the initial difficulty, and
  $n$ blocks in the last window considered, as these are not compensated for.
  This is the same as in the previous section, where we talked about one full window.
* $3c$ blocks' worth of standard deviation come from the imperfection of the compensation through difficulty adjustment:
  random increases/decreases in one of the intermediary blocks aren't compensated perfectly. Interestingly,
  the extent of this imperfection does not scale with the number of blocks in a window, but is just roughly
  $3$ blocks per window worth.
* $c$ blocks' worth is due to the one last block in every window whose length does not affect the difficulty
  computation at all, so it just passes through into our final expression. A modified formula that did take
  all durations into account would only result in a standard deviation of approximately $t\sqrt{2n + 3c}$,
  as well as fixing the time-warp vulnerability.

All the formulas in this section have been verified using simulations.

## Conclusion

The main findings discussed above, under the assumption of constant hashrate and the chosen simplifications of the difficulty adjustment algorithm, are:
* The probability distribution for all future difficulties are all identically and independently distributed. Specifically,
  they all follow $\mathit{InvGamma}(\alpha=n-1, \beta=htn)$. Additionally, this independence implies that, surprisingly,
  the difficulty of one window does not affect the difficulty of future ones.
* The expected sum of the durations of $r$ distinct blocks is $rtn/(n-2)$. This holds regardless of whether these blocks belong to the same difficulty
  window or not.
* The standard deviation on the sum of the duration of consecutive blocks depends on whether they belong to the same window or not:
  * If they do, the duration is distributed as $tn \cdot \mathit{Beta'}(\alpha=r, \beta=n-1)$, whose standard deviation is $nt/(n-2)\cdot\sqrt{r(n+r-2)/(n-3)}$;
    growing faster with $r$ than what would be expected for independent events.
  * If they don't, but we're looking at $c = r/n$ consecutive full windows,
    the standard deviation is $nt/(n-2)\cdot\sqrt{2n(2c+n-3)/(n-3)}$;
    growing significantly slower with $c$ than what would be expected for independent events.
    Specifically, for large $n$, that is roughly the standard deviation we'd expect for
    $2n+4c$ independent blocks, despite being about the duration of
    $cn$ blocks.

For Bitcoin, with $n=2016$ and
$t$ *10 minutes*, this means:
* Blocks take on average *10 minutes, 0.5958 seconds*, which translates to
  windows taking *2 weeks, 20 minutes, 1.19 seconds*, a factor
  $2016/2014 \approx 1.000993$ more than what was targetted.
* The standard deviation of a block is close to its mean, as would be expected for
  Poisson processes, namely *10 minutes, 0.8941 seconds*.
* The standard deviation for a window is *10 hours, 35 minutes, 55.59 seconds*, approximately $\sqrt{2}$ times what would
  be expected for independent Poisson processes.
* The standard deviation for 104 windows (~4 years) is only barely larger: *11 hours, 7 minutes, 38.53 seconds*.
  If the window durations were independent, we'd expect this to roughly be $\sqrt{104} \approx 10.198$ times the standard deviation for one window.
  It is much less than that due to randomness in the intermediary windows being mostly compensated for by the difficulty of the successor window.

The mean and standard deviation formulas listed here were verified by [simulations](simul.cpp). In fact, the results
seem to mostly hold even when the hashrate is not a constant but exponentially growing one, in which
case mean and standard deviation roughly get divided by the growth rate per window.

## Acknowledgments

Thanks to Clara Shikhelman for the discussion and many comments that led to this writeup.
