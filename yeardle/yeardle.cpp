#include <stdint.h>
#include <assert.h>
#include <algorithm>
#include <map>
#include <string>
#include <vector>

/* This program computes and prints a decision table for solving
 * Yeardle (https://histordle.com/yeardle/).
 *
 * The correct year can always be identified from a range of 726
 * consecutive years in 7 guesses, which suffices to win the game
 * (the 8th guess is used to input the answer).
 */

namespace {

/* Data structure representing a subset of ints as list of from-to pairs. */
class RangeSet {
    std::vector<std::pair<int, int>> ranges;

public:
    /** Construct the empty set. */
    RangeSet() = default;
    /** Construct a single range ([l,u]). */
    RangeSet(int l, int u) : ranges{{l, u}} {}
    /** Construct a double range ([l1,u1] union [l2,u2]). u1 < l2. */
    RangeSet(int l1, int u1, int l2, int u2) : ranges{{l1, u1}, {l2, u2}} {}
    /** Construct a set from a list of ranges. They must be disjunct and ordered. */
    RangeSet(std::vector<std::pair<int, int>> v) : ranges(std::move(v)) {}

    /** Copy constructor. */
    RangeSet(const RangeSet&) = default;
    /** Copy assignment. */
    RangeSet& operator=(const RangeSet& o) = default;

    /** Check whether a set is empty. */
    explicit operator bool() const { return !ranges.empty(); }

    /** Get the lowest value in the set (only if not empty). */
    int min() const { return ranges.front().first; }
    /** Get the largest value in the set (only if not empty). */
    int max() const { return ranges.back().second; }

    /** Compute a hash of the set, and of its negation. If the negation has
     *  a lower hash, actually perform the negation on the set and return true.
     *  This lets us halve the size of the cache, as sets and their negations
     *  have identical (but negated) solving strategies. */
    bool canon() {
        if (ranges.size() <= 1) return false;
        uint64_t h1 = 1337, h2 = 1337;
        size_t d = ranges.size() - 1;
        for (size_t i = 0; i < ranges.size(); ++i) {
            if (i) {
                h1 += ranges[i].first - ranges[i-1].second;
                h1 *= 9260031227486221669ull;
                h1 ^= (h1 >> 32);

                h2 += ranges[d-i+1].first - ranges[d-i].second;
                h2 *= 9260031227486221669ull;
                h2 ^= (h2 >> 32);
            }

            h1 += ranges[i].second - ranges[i].first;
            h1 *= 2990871297014242113ull;
            h1 ^= (h1 >> 32);

            h2 += ranges[d-i].second - ranges[d-i].first;
            h2 *= 2990871297014242113ull;
            h2 ^= (h2 >> 32);
        }
        if (h2 < h1) {
            std::reverse(ranges.begin(), ranges.end());
            for (auto& [l, u] : ranges) {
                int t = l;
                l = -u;
                u = -t;
            }
            return true;
        }
        return false;
    }

    /** Shift all elements in the set by offset p. */
    RangeSet& operator+=(int p) {
        for (auto& [l, u] : ranges) {
            l += p;
            u += p;
        }
        return *this;
    }

    /** Shift all elements in the set by offset -p. */
    RangeSet& operator-=(int p) {
        for (auto& [l, u] : ranges) {
            l -= p;
            u -= p;
        }
        return *this;
    }

    /** Compute the intersection of two sets.. */
    friend RangeSet operator&(const RangeSet& a, const RangeSet& b) {
        std::vector<std::pair<int, int>> r;
        auto ait = a.ranges.begin(), bit = b.ranges.begin();
        while (ait != a.ranges.end() && bit != b.ranges.end()) {
            if (ait->second < bit->first) {
                ++ait;
                continue;
            }
            if (bit->second < ait->first) {
                ++bit;
                continue;
            }
            int l = std::max(ait->first, bit->first);
            int u = std::min(ait->second, bit->second);
            assert(u >= l);
            r.emplace_back(l, u);
            if (ait->second < bit->second) {
                ++ait;
            } else {
                ++bit;
            }
        }
        return RangeSet(std::move(r));
    }

    // Comparison operators.
    friend bool operator<(const RangeSet& a, const RangeSet& b) { return a.ranges < b.ranges; }
    friend bool operator==(const RangeSet& a, const RangeSet& b) { return a.ranges == b.ranges; }
    friend bool operator!=(const RangeSet& a, const RangeSet& b) { return a.ranges != b.ranges; }

    /** Get a string representation. */
    std::string ToString() const {
        std::string ret = "";
        for (const auto& [l, u] : ranges) {
            if (ret.size()) ret += ',';
            ret += std::to_string(l);
            if (u == l + 1) {
                ret += ",";
                ret += std::to_string(u);
            } else if (u > l + 1) {
                ret += "-";
                ret += std::to_string(u);
            }
        }
        return ret;
    }
};

/** Possible responses that can come out of Yeardle. */
const std::pair<RangeSet, std::string> CLASSES[6] = {
   {{0, 0}, "0"},
   {{-2, -1, 1, 2}, "1-2"},
   {{-10, -3, 3, 10}, "3-10"},
   {{-40, -11, 11, 40}, "11-40"},
   {{-200, -41, 41, 200}, "41-200"},
   {{-10000, -201, 201, 10000}, "200+"}
};

/** Data type for representing a cache. For every set of candidate
 *  solutions left, a pair (number of guesses left, what to guess first). */
using Cache = std::map<RangeSet, std::pair<int, int>>;

/** Analyze a set of candidates, and return (guesses left, what to guess first). */
std::pair<int, int> Analyze(RangeSet x, Cache& cache);

/** Same as Analyze, but only invoked if not found in cache. */
std::pair<int, int> AnalyzeInner(const RangeSet& x, Cache& cache) {
    assert(x.min() == 0);
    int max = x.max();
    assert(max >= 0);
    // If the set is [0], no more guesses are needed.
    if (max == 0) return {0, 0};
    int bestworst = 100001;
    int bestguess = 0;
    // Loop over the possible values in [0,n], from the middle out.
    // (dev = distance from mid, sgn = right or left).
    int mid = max / 2;
    for (int dev = 0; dev <= max - mid; ++dev) {
        for (int sgn = 0; sgn < 2; ++sgn) {
            // Skip uninteresting values.
            if (dev == 0 && sgn) continue;
            int guess = mid + (sgn ? -dev : dev);
            if (guess < 0 || guess > max) continue;

            // Parition the input set x according to the potential Yeardle
            // responses (CLASSES), and figure out which one has the most
            // guesses left.
            int worst = -1;
            for (const auto& [cls, _] : CLASSES) {
                RangeSet res = cls;
                res += guess;
                RangeSet com = x & res;
                if (com) {
                    if (com == x) {
                        worst = 100000;
                    } else {
                        auto [sub, _] = Analyze(com, cache);
                        if (sub > worst) worst = sub;
                    }
                }
                if (worst == 100000) break;
            }
            // Remember which guess results in the smallest most-guesses-left partition.
            if (worst < bestworst) {
                bestworst = worst;
                bestguess = guess;
            }
        }
    }
    return {bestworst + 1, bestguess};
}

/** Analyze a set of candidates, and return (guesses left, what to guess first). */
std::pair<int, int> Analyze(RangeSet x, Cache& cache) {
    // Normalize the input.
    const bool neg = x.canon();
    const int shift = x.min();
    x -= shift;
    // Look up in cache, and return if found.
    auto it = cache.find(x);
    if (it != cache.end()) return {it->second.first, neg ? -(it->second.second + shift) : (it->second.second + shift)};
    // Invoke AnalyzeInner to actually compute result.
    auto ret = AnalyzeInner(x, cache);
    // Store in cache.
    cache[x] = ret;
    // Return (after undoing normalization on the guess).
    ret.second += shift;
    if (neg) ret.second = -ret.second;
    return ret;
}

/** Print out a decision tree for x. */
void Print(const RangeSet& x, Cache& cache, std::string desc, int rec = 0) {
    for (int i = 0; i < rec; ++i) printf("  ");
    printf("* ");
    if (desc.size() != 0) printf("%s: ", desc.c_str());
    auto [moves, guess] = Analyze(x, cache);
    if (moves == 0) {
        printf("%s\n", x.ToString().c_str());
        return;
    } else {
        printf("[%s] (%i steps)\n", x.ToString().c_str(), moves);
    }
    for (const auto& [cls, str] : CLASSES) {
        RangeSet res = cls;
        res += guess;
        RangeSet com = x & res;
        if (com) {
            Print(com, cache, "g(" + std::to_string(guess) + ")=" + str, rec + 1);
        }
    }
}

};

int main(void) {
    Cache cache;
    setlinebuf(stdout);

    // Print decision trees for every-increasing ranges ([0,n]).
    int n = 0;
    while (true) {
        Print({0, n++}, cache, "", 0);
        printf("# Cache size: %lu\n\n", (unsigned long)cache.size());
    }

    return 0;
}
