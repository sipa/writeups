import secrets

BITS = 8
MASK = (1 << BITS) - 1

def extract2(x, n):
    assert 0 <= x <= MASK
    assert 0 < n
    assert n <= MASK
    tmp = x * n
    return (tmp >> BITS, tmp & MASK)

def extract4(x, n):
    assert 0 <= x <= MASK
    assert 0 < n
    assert n <= MASK
    low_mask = (n - 1) & ~n
    tmp = x * n
    out = tmp >> BITS
    return (out, (tmp | (out & low_mask)) & MASK)

for BITS in range(0, 32):
    print("%i BITS" % BITS)
    MASK = (1 << BITS) - 1
    # Iterate over various products of N1*N2*N3*N4.
    for P in range(16, 1<<(2*BITS)):
        # Iterate over individual N1,N2,N3,N4 values whose product is P.
        for N1 in range(2, min(1<<BITS,P>>3 + 1)):
            for N2 in range(2, min(1<<BITS,(P//N1)>>2 + 1)):
                N12 = N1*N2
                for N3 in range(2, min(1<<BITS,(P//N12)>>1 + 1)):
                    N123 = N12*N3
                    N4 = P // N123
                    if N4 > 1 and N4 < 1<<BITS and N123*N4 == P:
                        # Initialize frequency counters for all (joint) distributions of
                        # subsequent outputs (1,1-2,1-3,1-4,2,2-3,2-4,3,3-4,4) of extract4.
                        d1 = [0 for _ in range(N1)]
                        d2 = [0 for _ in range(N12)]
                        d3 = [0 for _ in range(N123)]
                        d4 = [0 for _ in range(P)]
                        d5 = [0 for _ in range(N2)]
                        d6 = [0 for _ in range(N2*N3)]
                        d7 = [0 for _ in range(N2*N3*N4)]
                        d8 = [0 for _ in range(N3)]
                        d9 = [0 for _ in range(N3*N4)]
                        d0 = [0 for _ in range(N4)]
                        # Initialize frequency counters for extract4 intermediate states.
                        da = [0 for _ in range(1 << BITS)]
                        db = [0 for _ in range(1 << BITS)]
                        dc = [0 for _ in range(1 << BITS)]
                        # Initialize frequency counters for all (joint) distributions of
                        # subsequent outputs that include the first (1,1-2,1-3,1-4) of extract2.
                        e1 = [0 for _ in range(N1)]
                        e2 = [0 for _ in range(N12)]
                        e3 = [0 for _ in range(N123)]
                        e4 = [0 for _ in range(P)]
                        # Loop over all possible hash function outputs.
                        for x1 in range(1 << BITS):
                            # Compute extract4 outputs.
                            o1,x2 = extract4(x1, N1)
                            o2,x3 = extract4(x2, N2)
                            o3,x4 = extract4(x3, N3)
                            o4,_  = extract4(x4, N4)
                            # Compute extract2 outputs.
                            q1,y2 = extract2(x1, N1)
                            q2,y3 = extract2(y2, N2)
                            q3,y4 = extract2(y3, N3)
                            q4,_  = extract2(y4, N4)
                            # Assert ranges.
                            assert 0 <= o1 < N1
                            assert 0 <= o2 < N2
                            assert 0 <= o3 < N3
                            assert 0 <= o4 < N4
                            assert 0 <= q1 < N1
                            assert 0 <= q2 < N2
                            assert 0 <= q3 < N3
                            assert 0 <= q4 < N4
                            # Update frequency counters.
                            e1[q1] += 1
                            e2[q1 + N1*q2] += 1
                            e3[q1 + N1*q2 + N12*q3] += 1
                            e4[q1 + N1*q2 + N12*q3 + N123*q4] += 1
                            d1[o1] += 1
                            d2[o1 + N1*o2] += 1
                            d3[o1 + N1*o2 + N12*o3] += 1
                            d4[o1 + N1*o2 + N12*o3 + N123*o4] += 1
                            d5[o2] += 1
                            d6[o2 + N2*o3] += 1
                            d7[o2 + N2*o3 + N2*N3*o4] += 1
                            d8[o3] += 1
                            d9[o3 + N3*o4] += 1
                            d0[o4] += 1
                            da[x2] += 1
                            db[x3] += 1
                            dc[x4] += 1
                        # Verify all tracked output distribution are near-uniform.
                        assert min(e1) + 1 >= max(e1)
                        assert min(e2) + 1 >= max(e2)
                        assert min(e3) + 1 >= max(e3)
                        assert min(e4) + 1 >= max(e4)
                        assert min(d1) + 1 >= max(d1)
                        assert min(d2) + 1 >= max(d2)
                        assert min(d3) + 1 >= max(d3)
                        assert min(d4) + 1 >= max(d4)
                        assert min(d5) + 1 >= max(d5)
                        assert min(d6) + 1 >= max(d6)
                        assert min(d7) + 1 >= max(d7)
                        assert min(d8) + 1 >= max(d8)
                        assert min(d9) + 1 >= max(d9)
                        assert min(d0) + 1 >= max(d0)
                        # Verify that all intermediary states are reached exactly once.
                        assert all(v == 1 for v in da)
                        assert all(v == 1 for v in db)
                        assert all(v == 1 for v in dc)
