# Private authentication protocols

* [Introduction](#introduction)
* [Definition](#definition)
* [Discussion](#discussion)
  + [Selective interception attack](#selective-interception-attack)
  + [Reducing surveillance](#reducing-surveillance)
* [Example protocols](#example-protocols)
  + [Assumptions and notation](#assumptions-and-notation)
  + [Partial solutions](#partial-solutions)
    - [Example 1: no responder privacy](#example-1-no-responder-privacy)
    - [Example 2: only responder privacy when failing, no challenger privacy](#example-2-only-responder-privacy-when-failing--no-challenger-privacy)
    - [Example 3: single key, no challenger privacy](#example-3-single-key-no-challenger-privacy)
  + [Private authentication protocols](#private-authentication-protocols-1)
    - [Example 4: simple multi-key PAP](#example-4-simple-multi-key-pap)
    - [Example 5: Countersign](#example-5-countersign)
    - [Example 6: constructing a PAP from private set intersection](#example-6-constructing-a-pap-from-private-set-intersection)
  + [Comparison of applicability](#comparison-of-applicability)
* [Acknowledgments](#acknowledgments)

## Introduction

Authentication protocols are used to verify that network connections are
not being monitored through a man-in-the-middle attack (MitM). But the
commonly used constructions for authentication&mdash;often some framework
surrounding a digital signature or key exchange protocol&mdash;reveal considerable amounts of
identifying information to the participants (and MitMs). This information can
potentially be used to track otherwise anonymous users around the network
and correlate users across multiple services, if keys are reused.

Ultimately, key-based authentication protocols are trying to answer the
question, "Does the remote party know the corresponding private key for
an identity key we accept?" A protocol which answers this question and
*nothing* else would naturally provide for
authentication that is undetectable by MitMs: just make its usage mandatory and use random keys
when no identity is expected. Such a protocol would also provide no
avenue for leaking any identifying information beyond the absolute
minimum needed to achieve authentication.

This is a work in progress to explore the possibilities and properties
such protocols have. It lacks formal definitions and security
proofs for the example protocols we have in mind, but these are being
worked on.

## Definition

We define a **private authentication protocol** (PAP) as a protocol that allows a
challenger to establish whether their peer
possesses a private key corresponding to one of (potentially) several acceptable public keys.
It is intended to be used over an encrypted but unauthenticated connection.

There are two parties: the challenger and the responder. The challenger has a set of acceptable
public keys $\bf Q$, with a publicly-known upper bound $n$. $\bf Q$ can be empty if no authentication is desired.
The responder has a set of private keys $\bf p$ (possibly with a known upper bound $m$), with corresponding
set of public keys $\bf P$. These sets may be empty if the responder has no key material. The challenger at
the end outputs a Boolean: success or failure.

A PAP must have the following properties:
* **Correctness** When the intersection between $\bf P$ and $\bf Q$ is non-empty, the challenger returns true. This is obviously
  necessary for the scheme to work at all.
* **Security against impersonation** When the intersection between $\bf P$ and $\bf Q$ is empty, the challenger
  returns false. This means it must be impossible for someone without access to an acceptable private key
  to spoof authentication, even if they know the acceptable public key(s).
* **Challenger privacy** Responders learn nothing about the keys in $\bf Q$ except possibly the intersection
  with its $\bf P$. Specifically, responders which have a database of public keys (without corresponding private keys) cannot know
  which of these, or how many of them, are in ***Q***. Responders can also not determine whether multiple
  PAP sessions have overlapping ***Q*** sets (excluding public keys the responder has private keys for).
  This prevents unsuccessful responders (including MitMs) from knowing whether authentication is desired at all or for whom,
  or following challengers around.
* **Responder privacy** Challengers learn nothing about ***P*** apart from whether its intersection with ***Q*** is non-empty.
  Specifically, a challenger with a set of public keys (without corresponding private keys) trying to learn ***P*** cannot do
  better than what the correctness property permits when choosing ***Q*** equal to that set. Furthermore, challengers
  cannot determine whether there is overlap between the ***P*** sets in multiple failing PAP sessions, or even overlap
  between the non-winning keys in ***P*** in successful PAP sessions.
  This property prevents a MitM from identifying failing responders or following them around. In addition, it rate-limits the
  ability for challengers
  to learn information about the responder across multiple protocol runs to one guess per protocol. Note that
  if *n>1*, this property implies an inability for challengers to know which acceptable key(s) a successful responder used.

Two additional properties may be provided:
* **Forward challenger privacy**: challenger privacy is maintained even against responders who have access to
  a database with private keys. This prevents responders (including MitMs) that record network traffic from correlating
  protocol runs with the keys used, even after the private keys are leaked. As this definition includes
  honest responders, forward challenger privacy is equivalent to stating that responders do not learn anything at all.
* **Forward responder privacy**: responder privacy is maintained even against challengers who have a database
  of private keys.

Note that while a PAP does not require the responder to output whether they are successful, doing so
is also not in conflict with any of the required properties above. When a PAP has forward challenger privacy however,
it is actually impossible for a responder to know whether they are successful.

A PAP as defined here is unidirectional. If the responder also wants to authenticate the challenger,
it can be run a second time with the roles reversed. If done sequentially, the outcome of the protocol
in one direction can be used as input for the next one, i.e. if the first run fails the first challenger
can act as second responder with empty ***p*** (no private keys).

## Discussion

These properties are primarily useful in the context of *optional authentication*.
Imagine a setting where ephemeral encryption is automatic and mandatory but authentication is
opportunistic: if an end-point expects a known identity
it will authenticate, otherwise it won't and only get resistance against
passive observation.

### Selective interception attack

In this configuration, when the attempt at authentication is observable
to an active attacker, a **selective interception** attack is possible
that evades detection:
* When no authentication is requested on a connection, the MitM maintains
  the connection and intercepts it.
* When authentication is requested, the MitM innocuously terminates the
  connection, and blacklists the network address involved so it will
  discontinue intercepting retried connections.

Challenger privacy allows mitigating this vulnerability: due to it,
MitMs cannot distinguish PAP runs which do and don't desire authentication.
Thus if all connections (even those that don't seek authentication) use a PAP, the MitM
is forced to either drop all connections (becoming powerless while causing collateral damage) or
risk being detected on every connection (as every PAP-employing connection could be an attempt to authenticate).

### Reducing surveillance

As unauthenticated connections are an explicit use case, private
authentication protocols assure the responder's privacy in the unauthenticated case.
Responder privacy implies that the challenger cannot learn whether two separate
protocol runs (in separate connections) were with peers that possess the
same private key, effectively preventing the challenger from surveiling its
unauthenticated peers and following them around.

Responder privacy also implies that the challenger does not learn which of its
acceptable public keys the responder's private key corresponded to, in case there
are multiple. To see why this
may be useful, note that the anti-surveillance property from the previous
paragraph breaks down whenever the challenger can run many instances of the protocol
with separate acceptable keys, for a large set of (e.g. leaked) keys that
may include the responder's public key. In order to combat this, the responder can limit the
number of independent protocol runs it is willing to participate in. If the challenger
could learn which acceptable public key the responder's private key corresponded to,
this would need to be a limit on the total number of keys in all protocol
runs combined, rather than the total number of protocol runs. If the challenger has
hundreds of acceptable public keys, and the responder is one of them, the responder must support
participating in a protocol with hundreds of acceptable keys&mdash;but
doesn't have to accept participating in more than one protocol run.

## Example protocols

### Common notation and assumptions

We assume an encrypted but unauthenticated connection already exists
between the two participants. We also assume a unique session id $s$ exists, only
known to the participants. Both could for example be set up per a Diffie-Hellman
negotiation.

$G$ and $M$ are two generators of an additively-denoted cyclic group in which
the discrete logarithm problem is hard, and $M$'s discrete logarithm w.r.t. *G*
is not known to anyone. The *⋅* symbol denotes scalar multiplication (repeated
application of the group operation).
Lowercase variables refer to integers modulo the
group order, and uppercase variables refer to group elements. *h* refers to a hash function
onto the integers modulo the group order, modeled as a random oracle.
Sets are denoted in **bold**, and considered serialized by concatenating their elements in sorted order.

The set of acceptable public keys ***Q*** consists of group elements *Q<sub>0</sub>*, *Q<sub>1</sub>*, ..., *Q<sub>n-1</sub>*.
The set of the responder's private keys is ***p***, consisting of integers *p<sub>0</sub>*, *p<sub>1</sub>*, ..., *p<sub>m-1</sub>*.
The corresponding set of public keys is ***P***, consisting of *P<sub>0</sub> = p<sub>0</sub>⋅G*,
*P<sub>1</sub> = p<sub>1</sub>⋅G*, ..., *P<sub>m-1</sub> = p<sub>m-1</sub>⋅G*.

In case fewer than *n* acceptable public keys exist, the *Q<sub>i</sub>* values
are padded with randomly generated ones. In case no authentication is desired,
all of them are randomly generated. Similarly, if a protocol has an upper bound
on the number of private keys *m*, and fewer keys than that are present, it is
padded with randomly generated ones.

Terms used in the security properties:
* Unconditionally: the stated property holds against adversaries with unbounded computation.
* ROM (random oracle model): *h* is indistinguisable from a random function.
* The DL (discrete logarithm) assumption: given group elements *(P, a⋅P)*, it is hard to compute *a*.
* The CDH (computational Diffie-Hellman) assumption: given group elements *(P, a⋅P, b⋅P)*, it is hard to compute *ab⋅P*.
* The DDH (decisional Diffie-Hellman) assumption: group element tuples *(P, a⋅P, b⋅P, ab⋅P)* are hard to distinguish from random tuples.

### Partial solutions

Here we give a few examples of near solutions which don't provide all desired properties simultaneously.
This demonstrates how easy some of the properties are in isolation, while being nontrivial to combine them.

#### Example 1: no responder privacy

If we do not care about responder privacy, it is very simple. The responder just reports their
public key and a signature with it. For a single private key version (*m=1*) that is:

* The responder:
  * Computes a digital signature *d* on *s* using key *p<sub>0</sub>*.
  * Sends *(P<sub>0</sub>, d)*.
* The challenger:
  * Returns whether *P<sub>0</sub>* is in ***Q***, and whether *d* is a valid signature on *s* using *P<sub>0</sub>*.

This clearly provides challenger privacy, as the challenger does not send anything at all.
It however does not provide responder privacy, as the responder unconditionally reveals their public key.

#### Example 2: only responder privacy when failing, no challenger privacy

It seems worthwhile to try to only have the responder reveal their key in case of success.
In order to do that, it must know whether its key is acceptable. In this first attempt,
we compromise by giving up challenger privacy.

* The challenger:
  * Sends ***Q***.
* The responder:
  * If any *P<sub>i</sub>* is in ***Q***:
    * Computes a digital signature *d* on *s* using key *p<sub>i</sub>*.
    * Sends *(P<sub>i</sub>, d)*.
  * Otherwise, if there is no overlap between ***P*** and ***Q***:
    * Sends a zero message with the same size as a public key and a signature.
* The challenger:
  * Returns whether *P<sub>i</sub>* is in ***Q***, and whether *d* is a valid signature on *s* using *P<sub>i</sub>*.

Now there is obviously no challenger privacy as ***Q*** is revealed directly. Yet, we have not recovered
responder privacy either, as the matching public key is revealed in case of success.


#### Example 3: single key, no challenger privacy

In case there is at most a single acceptable public key *Q<sub>0</sub>* (*n=1*), responder
privacy can be recovered:

* The challenger:
  * Sends *Q<sub>0</sub>*.
* The responder:
  * If *Q<sub>0</sub>* equals any *P<sub>i</sub>*:
    * Computes a digital signature *d* on *s* using key *p<sub>i</sub>*.
    * Sends *d*.
  * Otherwise, if *Q<sub>0</sub>* is not in ***P***:
    * Sends a zero message with the same size as a digital signature.
* The challenger:
  * Returns whether *d* is a valid signature on *s* using *Q<sub>0</sub>*.

Yet, challenger privacy is still obviously lacking. It is possible to improve upon this somewhat
by e.g. sending *h(Q<sub>0</sub> || s)* instead of *Q<sub>0</sub>* directly. While that indeed
means the key is not revealed directly anymore, an attacker who has a list of candidate
keys can still test for matches, and challenger privacy requires that no information
about the key can be inferred at all.


### Private authentication protocols

We conjecture that the following protocols do provide all the properties needed for a PAP
under reasonable assumptions.

#### Example 4: simple multi-key PAP

To achieve responder privacy in the multi-key case, while simultaneously retaining
challenger privacy, we need a different approach. The idea is to perform a Diffie-Hellman
key exchange between an ephemeral key (*d* below) and the acceptable public keys,
and use the results to blind a secret value *y*, whose hash is revealed to the responder.
If the responder can recover *y*, they must have one of the corresponding private keys.

The result is a multi-acceptable-key (*n&geq;1*), unbounded-private-keys (*m* need not be publicly known), single-roundtrip PAP
with *O(n)* communication cost. Scalar and hash operations scale with *O(mn)*, but group operations only with *O(n)*.

* The challenger:
  * Generates random integers *d* and *y*.
  * Computes *D = d⋅G*.
  * Computes *w = h(y)*.
  * Constructs the set ***c***, consisting of the values of *y - h(d⋅Q<sub>i</sub> || s)* for each *Q<sub>i</sub>* in ***Q***.
  * Sends *(D, w, **c**)*.
  * Remembers *w* (or *y*).
* The responder:
  * Constructs the set ***f***, consisting of the values of *h(p<sub>j</sub>⋅D || s)* for each *p<sub>j</sub>* in ***p***.
  * If for any *c<sub>i</sub>* in ***c*** and any *f<sub>j</sub>* in ***f*** it holds that *h(c<sub>i</sub> + f<sub>j</sub>) = w*:
    * Sets *z = c<sub>i</sub> + f<sub>j</sub>*.
  * Otherwise, if this does not hold for any *i,j*:
    * Sets *z = 0*.
  * Sends *z*.
* The challenger:
  * Returns whether or not *h(z) = w* (or equivalently, *z = y*).

Conjectured properties:
* Correctness: unconditionally
* Security against impersonation: under ROM+CDH
* Challenger privacy: under ROM+CDH, or under DDH
* (Forward) responder privacy: unconditionally

It has no forward challenger privacy, as responders learn which of their private key(s) was acceptable.

#### Example 5: Countersign

If we want forward challenger privacy, we must go even further. we again perform a Diffie-Hellman exchange
between an ephemeral key and the acceptable public key (now restricted to just a single one),
but then use a (unidirectional) variant of the [socialist millionaire](https://en.wikipedia.org/wiki/Socialist_millionaire_problem)
protocol to verify both sides reached the same shared secret. This is similar to the technique used in
the [Off-the-Record](https://en.wikipedia.org/wiki/Off-the-Record_Messaging) protocol for authentication, as well
as in [SPAKE2](https://tools.ietf.org/id/draft-irtf-cfrg-spake2-10.html) for verifying passwords.

The result is a protocol we call Countersign: a single-acceptable-key (*n=1*), multi-private-key (*m&geq;1*),
single-roundtrip PAP with both forward challenger privacy and forward responder privacy.
It has *O(m)* communication and computational cost.

* The challenger:
  * Generates random integers *d* and *y*.
  * Computes *D = d⋅G*.
  * Computes *C = y⋅G - h(d⋅Q<sub>0</sub>|| s)⋅M*.
  * Sends *(D, C)*.
  * Remembers *y*.
* The responder:
  * Generates random integer *k*.
  * Computes *R = k⋅G*.
  * Constructs the set ***w***, consisting of the values *h(k⋅(C + h(p<sub>j</sub>⋅D || s)⋅M))* for each *p<sub>j</sub>* in ***p***.
  * Sends *(R, **w**)*.
* The challenger:
  * Returns whether or not *w<sub>j</sub> = h(y⋅R)* for any *w<sub>j</sub>* in ***w***.

Conjectured properties:
* Correctness: unconditionally
* Security against impersonation: under CDH
* (Forward) challenger privacy: unconditionally
* (Forward) responder privacy: under ROM+CDH, or under DDH

Because of forward challenger privacy, this protocol does not let the responder learn whether they
are successful themselves.

Note that one cannot simply run this protocol multiple times with different acceptable keys to obtain
an *n>1* PAP, because the challenger would learn which acceptable key succeeded, violating
responder privacy.

Also interesting is that there appears to be an inherent trade-off between unconditional challenger
privacy and unconditional responder privacy, and both cannot exist simultaneously. Responder privacy
seems to imply that the messages sent by the challenger must form a secure commitment to the set
***Q***. If this wasn't the case and challengers could "open" it to other keys, then nothing would
prevent them from learning about intersections between ***P*** and these other keys as well. Thus
responder privacy seems to imply that the challenger must bind to their keys, while challenger
privacy requires hiding the keys. Binding to and hiding the same data cannot both be achieved unconditionally.

#### Example 6: constructing a PAP from private set intersection

There is a striking similarity between PAPs and [private set intersection](https://en.wikipedia.org/wiki/Private_set_intersection)
protocols (PSIs); both are related to finding properties of the intersection between two sets of elements in a private way. The differences
are:
* In PAPs, the elements being compared are asymmetric (private and public keys),
  while PSIs is about finding the intersection of identical elements on both sides.
* In PAPs, the challenger only learns whether the intersection is non-empty, whereas
  in PSIs the intersection itself is revealed.
* In PAPs, it is unnecessary for the responder to learn anything, and with forward
  challenger privacy it is even forbidden.

With certain restrictions, it is possible to exploit this similarity and build PAPs
out of (variations of) PSIs. We first need to convert the private keys
***p*** and public keys ***Q*** to sets of symmetric elements that can be compared.
To do so, we repeat the Diffie-Hellman trick from the previous protocols:
* The challenger:
  * Generates a random integer *d*.
  * Computes *D = d⋅G*.
  * Constructs the set ***e***, consisting of values *h(d⋅Q<sub>i</sub> || s)* for each *Q<sub>i</sub>* in ***Q***.
  * Sends *D*.
* The responder:
  * Constructs the set ***f***, consisting of values *h(p<sub>i</sub>⋅D || s)* for each *p<sub>i</sub>* in ***p***.

The PAP problem is now reduced to the challenger learning whether the intersection between ***e*** and ***f*** is
non-empty. Depending on the conditions there are various ways to accomplish this with PSIs. In all cases,
the PAP properties for correctness, security against impersonation, challenger privacy, and (forward)
responder privacy then follow from CDH plus the PSI's security and privacy properties.
* If *n=1*, a one-to-many PSI can be used directly. As in this case ***e*** is a singleton, learning its intersection with ***f***
  is equivalent to learning whether the intersection is non-empty.
* Also for *n=1*, such a one-to-many PSI may be constructed from a single-round one-to-one PSI. The challenger sends their
  PSI message first, and the responder sends the union of PSI responses (one for each private key in ***p***). This is not the
  same as running multiple independent one-to-one PSIs, as the shared challenger message prevents the challenger from changing
  the choice of ***Q*** between runs, which would permit the challenger to break responder privacy. This approach is effectively
  what Countersign is using, with the socialist millionaire problem taking the role of a one-to-one PSI.
* If *n>1*, a PSI algorithm cannot be used in a black-box fashion, and it needs to be modified to not reveal which element
  of ***Q*** matched. If *m>1* in addition to *n>1*, the size of the intersection would need to be hidden as well.
* To achieve forward challenger privacy, a one-sided PSI that does not reveal anything to the responder needs to be used.

### Comparison of applicability

Countersign is the most private protocol in the single-acceptable-key setting. It appears most useful
in situations where a connection initiator knows who they are trying to connect to (implicitly
limiting to *n=1*).

The multi-key protocol is significantly more flexible, but lacks forward challenger privacy, and
thus more strongly relies on keeping private key material private, even after decommissioning.

A potentially useful composition of the two is using Countersign for the connection initiator
trying to authenticate the connection acceptor, but then using the multi-key protocol for the
other direction. In case the first protocol fails, the second direction can run without
private keys.

## Acknowledgments

Thanks to Greg Maxwell for the idea behind Countersign, and the rationale for private
authentication protocols and optional authentication.
Thanks to Tim Ruffing for the simple multi-key PAP, discussions, and feedback.
Thanks to Mark Erhardt for proofreading.
