def is_odd(n):
    return (int(n) & 1) != 0

def f1(u):
    """Forward mapping function, naively."""
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

def r1(x,y,i):
    """Reverse mapping function, naively."""
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
            # (c1**3 + b == 1+b which is square), so the roundtrip check above
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

def f2(u):
    """Forward mapping function, optimized."""
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

def r2(x,y,i):
    """Reverse mapping function, optimized."""
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

def f3(u):
    """Forward mapping function, broken down."""
    t0 = u**2              # t0 = s = u**2
    t1 = (1+b) + t0        # t1 = d = 1+b+s
    t3 = (-c1) * t0        # t3 = -c1*s
    t2 = c2 * t1           # t2 = c2*d
    t2 = t2 + t3           # t2 = n = c2*d - c1*s
    t4 = t1**2             # t4 = d**2
    t4 = t4**2             # t4 = d**4
    t4 = b * t4            # t4 = b*d**4
    t3 = t2**2             # t3 = n**2
    t3 = t2 * t3           # t3 = n**3
    t3 = t1 * t3           # t3 = d*n**3
    t3 = t3 + t4           # t3 = h = d*n**3 + b*d**4
    if is_square(t3):
        t3 = sqrt(t3)      # t3 = sqrt(h)
        t1 = 1/t1          # t1 = i = 1/d
        x = t2 * t1        # x = n*i
        t1 = t1**2         # t1 = i**2
        y = t3 * t1        # y = sqrt(h)*i**2
    else:
        t2 = t1 + t2       # t2 = n+d
        t2 = -t2           # t2 = n = -n-d
        t3 = t2**2         # t3 = n**2
        t3 = t2 * t3       # t3 = n**3
        t3 = t1 * t3       # t3 = d*n**3
        t3 = t3 + t4       # t3 = h = d*n**3 + b*d**4
        if is_square(t3):
            t3 = sqrt(t3)  # t3 = sqrt(h)
            t1 = 1/t1      # t1 = i = 1/d
            x = t2*t1      # x = n*i
            t1 = t1**2     # t1 = i**2
            y = t3*t1      # y = sqrt(g)*i**2
        else:
            t0 = 3*t0      # t0 = 3*s
            t0 = 1/t0      # t0 = 1/(3*s)
            t1 = t1**2     # t1 = d**2
            t0 = t1 * t0   # t0 = d**2 / (3*s)
            t0 = -t0       # t0 = -d**2 / (3*s)
            x = 1 + t0     # x = 1 - d**2 / (3*s)
            t0 = x**2      # t0 = x**2
            t0 = t0*x      # t0 = x**3
            t0 = t0 + b    # t0 = x**3 + b
            y = sqrt(t0)   # y = sqrt(x**3 + b)
    if is_odd(y) != is_odd(u):
        y = -y
    return (x, y)

def r3(x,y,i):
    """Reverse mapping function, broken down."""
    if i == 1 or i == 2:
        t0 = 2*x                     # t0 = 2x
        t0 = t0 + 1                  # t0 = z = 2x+1
        t1 = t0 + (-c1)              # t1 = z-c1
        t1 = -t1                     # t1 = c1-z
        t0 = c1 + t0                 # t0 = c1+z
        t2 = t0 * t1                 # t2 = (c1-z)*(c1+z)
        t2 = (1+b) * t2              # t2 = (1+b)*(c1-z)*(c1+z)
        if not is_square(t2):
            return None
        if i == 1:
            if t0 == 0:
                return None
            if t1 == 0 and is_odd(y):
                return None
            t2 = sqrt(t2)            # t2 = sqrt((1+b)*(c1-z)*(c1+z))
            t0 = 1/t0                # t0 = 1/(c1+z)
            u = t0 * t2              # u = sqrt((1+b)*(c1-z)/(c1+z))
        else:
            t0 = x + 1               # t0 = x+1
            t0 = -t0                 # t0 = -x-1
            t3 = t0**2               # t3 = (-x-1)**2
            t0 = t0 * t3             # t0 = (-x-1)**3
            t0 = t0 + b              # t0 = (-x-1)**3 + b
            if is_square(t0):
                return None
            t2 = sqrt(t2)            # t2 = sqrt((1+b)*(c1-z)*(c1+z))
            t1 = 1/t1                # t1 = 1/(c1-z)
            u = t1 * t2              # u = sqrt((1+b)*(c1+z)/(c1-z))
    else:
        t0 = 6*x                     # t0 = 6x
        t0 = t0 + (4*b - 2)          # t0 = -z = 6x + 4B - 2
        t1 = t0**2                   # t1 = z**2
        t1 = t1 + (-16*(b+1)**2)     # t1 = z**2 - 16*(b+1)**2
        if not is_square(t1):
            return None
        t1 = sqrt(t1)                # t1 = r = sqrt(z**2 - 16*(b+1)**2)
        if i == 4:
            if t1 == 0:
                return None
            t1 = -t1                 # t1 = -r
        t0 = -t0                     # t0 = 2-4B-6x
        t0 = t0 + t1                 # t0 = 4s = 2-4B-6x +- r
        if not is_square(t0):
            return None
        t1 = t0 + (4*(b+1))          # t1 = d = 4s + 4(b+1)
        t2 = c3 * t0                 # t2 = c3*(2-4B-6x +- r)
        t2 = t2 + (2*(b+1)*(c1-1))   # t2 = n = c3(2-4B-6x +- r) + 2(b+1)(c1-1)
        t3 = t2**2                   # t3 = n**2
        t3 = t2 * t3                 # t3 = n**3
        t3 = t1 * t3                 # t3 = d*n**3
        t1 = t1**2                   # t1 = d**2
        t1 = t1**2                   # t1 = d**4
        t1 = b * t1                  # t1 = b*d**4
        t3 = t3 + t1                 # t3 = h = d*n**3 + b*d**4
        if is_square(t3):
            return None
        t0 = sqrt(t0)                # t0 = sqrt(4s)
        u = t0 / 2                   # u = sqrt(s)
    if is_odd(y) != is_odd(u):
        u = -u
    return u

# Iterate over field sizes.
for p in range(7, 32768, 12):
    if not is_prime(p):
        continue
    # Set of curve orders encountered so far for field size p.
    orders = set()
    # Compute field F and c_i constants.
    F = GF(p)
    c1 = F(-3).sqrt()
    c2 = (c1 - 1) / 2
    c3 = (-c1 - 1) / 2
    # Randomly try b constants in y^2 = x^3 + b equations.
    while True:
        b = F.random_element()
        if 27*b**2 == 0:
            # Not an elliptic curve
            continue
        # There can only be 6 distinct (up to isomorphism) curves y^2 = x^3 + b for a given field size.
        if len(orders) == (2 if p == 7 else 5 if p == 19 else 6):
            break
        # b+1 must be a square in the field.
        if jacobi_symbol(b+1, p) != 1:
            continue
        # Define elliptic curve E and compute its order.
        E = EllipticCurve(F,[0,b])
        order = E.order()
        # Skip orders we've seen so far.
        if order in orders:
            continue
        orders.add(order)
        # Only operate on prime-ordered curves.
        if not order.is_prime():
            continue
        # Compute forward mapping tables according to f1, f2, f3, and compare them.
        FM = [f1(F(uval)) for uval in range(0, p)]
        assert FM == [f2(F(uval)) for uval in range(0, p)]
        assert FM == [f3(F(uval)) for uval in range(0, p)]
        # Verify that all resulting points are on the curve.
        for x, y in FM:
            assert y**2 == x**3 + b
        cnt = 0
        reached = 0
        G = E.gen(0)
        # The number of preimages every multiple of G has
        PC = [0 for _ in range(order)]
        # Iterate over all points on the curve.
        for m in range(1,order):
            A = m*G
            x, y, _ = A
            # Compute the list of all preimages of the point.
            preimages = []
            for i in range(1,5):
                # Compute preimages using r_i (3 different implementation).
                u1, u2, u3 = r1(x, y, i), r2(x, y, i), r3(x, y, i)
                # Compare the results of the 3 implementations.
                if u1 is not None:
                    assert u1 == u2
                    assert u1 == u3
                    preimages.append(u1)
                else:
                    assert u2 is None
                    assert u3 is None
            # Verify all preimages are distinct
            assert len(set(preimages)) == len(preimages)
            # Verify all preimages round-trip correctly.
            for u in preimages:
                assert FM[int(u)] == (x, y)
            cnt += len(preimages)
            PC[m] = len(preimages)
            reached += (len(preimages) > 0)
        # Verify that all preimages are reached.
        assert cnt == len(FM)
        # Verify that the point at infinity cannot be reached.
        assert PC[0] == 0
        # Compute number of preimages for each multiple of G (except 0), under Elligator Squared
        PC2 = [0 for _ in range(order-1)]
        for i in range(1,order):
            if PC[i] == 0: continue
            for j in range(1, order - i): PC2[i + j - 1] += PC[i] * PC[j]
            PC2[i - 1] += PC[i] * PC[order - i]
            for j in range(order - i + 1, order): PC2[i + j - order - 1] += PC[i] * PC[j]
        mn, mx, s = min(PC2), max(PC2), sum(PC2)
        d1 = sum(abs(x / s - 1 / (order - 1)) for x in PC2)
        d2 = sqrt(sum((x / s - 1 / (order - 1))**2 for x in PC2))
        print("y^2 = x^3 + (b=%i) mod (p=%i): order %i, %.2f%% reached, range=%i..%i, Delta1 = %.4f/sqrt(p), Delta2 = %.4f/p" % (b, p, order, reached * 100 / (order-1), mn, mx, d1 * sqrt(p), d2 * p))
