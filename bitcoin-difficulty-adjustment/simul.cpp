#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <cstdio>

namespace {

inline uint64_t RdRand() noexcept
{
    uint8_t ok;
    uint64_t r;
    while (true) {
        __asm__ volatile (".byte 0x48, 0x0f, 0xc7, 0xf0; setc %1" : "=a"(r), "=q"(ok) :: "cc"); // rdrand %rax
        if (ok) break;
        __asm__ volatile ("pause" :);
    }
    return r;
}

static inline uint64_t Rotl(const uint64_t x, int k) {
    return (x << k) | (x >> (64 - k));
}

/** Xoshiro256++ 1.0 */
class RNG {
    uint64_t s0, s1, s2, s3;

public:
    RNG() : s0(RdRand()), s1(RdRand()), s2(RdRand()), s3(RdRand()) {}

    uint64_t operator()() {
        uint64_t t0 = s0, t1 = s1, t2 = s2, t3 = s3;
        const uint64_t result = Rotl(t0 + t3, 23) + t0;
        const uint64_t t = t1 << 17;
        t2 ^= t0;
        t3 ^= t1;
        t1 ^= t2;
        t0 ^= t3;
        t2 ^= t;
        t3 = Rotl(t3, 45);
        s0 = t0;
        s1 = t1;
        s2 = t2;
        s3 = t3;
        return result;
    }
};

class StatRNG {
    RNG rng;

public:
    long double Exp() {
        return -::logl((static_cast<long double>(rng()) + 0.5L) * 0.0000000000000000000542101086242752217L);
    }

    long double Erlang(int k) {
        long double ret = 0.0L;
        for (int i = 0; i < k; ++i) {
            ret += Exp();
        }
        return ret;
    }
};

template<typename F>
void Simul(F f, int retarget) {
    long double diff = 1.0L;
    StatRNG rng;
    while (true) {
        long double most = rng.Erlang(retarget - 1) * diff;
        long double last = rng.Exp() * diff;
        diff /= most;
        f(most + last);
    }
}

static constexpr int RETARGET = 10;

#ifndef KVAL
static constexpr int K = 1;
#else
static constexpr int K = (KVAL);
#endif

static constexpr int SLACK = 3;
static constexpr int PRINTFREQ = 40000000 / (RETARGET * (K + SLACK));

} // namespace

int main(void) {
    int iter = 0;
    uint64_t cnt = 0;
    long double acc = 0.0L;
    long double sum = 0.0L;
    long double sum2 = 0.0L;
    long double sum3 = 0.0L;
    long double sum4 = 0.0L;
    constexpr long double CR = RETARGET;
    constexpr long double CEx = K * CR / (CR - 2.0L);
    constexpr long double CVar = 2.0L * CR * (CR + (2*K - 3)) / ((CR - 3.0L)*(CR - 2.0L)*(CR - 2.0L));
    auto proc = [&](long double winlen) {
        iter += 1;
        if (iter >= SLACK) {
            acc += winlen;
            if (iter == K + SLACK - 1) {
                cnt += 1;
                long double acc2 = acc*acc;
                sum += acc;
                sum2 += acc2;
                sum3 += acc*acc2;
                sum4 += acc2*acc2;
                acc = 0.0L;
                iter = 0;
                if ((cnt % PRINTFREQ) == 0) {
                    long double mu = sum / cnt;
                    long double mu2p = sum2 / cnt;
                    long double mu3p = sum3 / cnt;
                    long double mu4p = sum4 / cnt;
                    long double mu2 = mu2p - mu*mu;
                    long double mu4 = mu4p + mu*(-4.0L*mu3p + mu*(6.0L*mu2p + -3.0L*mu*mu));
                    long double var = (mu2 * cnt) / (cnt - 1);
                    long double smu = sqrtl(CVar/cnt);
                    long double svar = sqrtl((mu4 - (cnt - 3)*CVar*CVar/(cnt - 1))/cnt);
                    printf("%lu: avg=%.15Lf(+-%Lf; E%Lf) var=%.15Lf(+-%Lf, E%Lf)\n", (unsigned long)cnt, mu, smu, (mu - CEx) / smu, var, svar, (var - CVar) / svar);
                }
            }
        }
    };
    Simul(proc, RETARGET);
}
