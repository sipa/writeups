# Building an optimal decision tree for Yeardle

This document explains how to construct an optimal decision tree for the
game [Yeardle](https://histordle.com/yeardle/). It appears possible to
always solve the game within 8 guesses when a range of no more than
726 consecutive years is known in which the solution lies.

## 1 Yeardle

In the game [Yeardle](https://histordle.com/yeardle/), one is presented
with 3 historical facts that all happened within the same year. The goal
is to guess what that year is with no more than 8 guesses. After every
guess, the game responds with one of these results:
* Nailed it (you guessed correctly)
* 1-2 years off
* 3-10 years off
* 11-40 years off
* 41-200 years off
* over 200 years off

Interestingly, the game does not tell the player whether they are below or
above the correct solution. This makes the problem significantly more interesting.

## 2 Decision trees

Generally, I assume a player will be able to guess a range of consecutive
years in which the solution must lie based on the presented historical facts.

Then we can ask ourselves how large that range can be while guaranteeing that
7 guesses yields enough information to pinpoint the solution in it (plus an
8th guess to actually enter the solution).

For small ranges, we can construct a decision tree by hand:
