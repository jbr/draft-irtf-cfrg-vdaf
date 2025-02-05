# Definitions of finite fields used in this spec.

from __future__ import annotations
from sage.all import GF
from sagelib.common import ERR_DECODE, I2OSP, OS2IP, Bytes, Error, Unsigned, \
                           Vec


# The base class for finite fields.
class Field:

    # The prime modulus that defines arithmetic in the field.
    MODULUS: Unsigned

    # Number of bytes used to encode each field element.
    ENCODED_SIZE: Unsigned

    # ORder of the multiplicative group generated by `Field.gen()`.
    GEN_ORDER: Unsigned

    def __init__(self, val):
        assert int(val) < self.MODULUS
        self.val = self.gf(val)

    @classmethod
    def gen(cls) -> Field:
        raise Error("gen() not implemented")

    @classmethod
    def zeros(cls, length: Unsigned) -> Vec[Field]:
        vec = [cls(cls.gf.zero()) for _ in range(length)]
        return vec

    @classmethod
    def rand_vec(cls, length: Unsigned) -> Vec[Field]:
        vec = [cls(cls.gf.random_element()) for _ in range(length)]
        return vec

    @classmethod
    def encode_vec(cls, data: Vec[Field]) -> Bytes:
        encoded = Bytes()
        for x in data:
            encoded += I2OSP(x.as_unsigned(), cls.ENCODED_SIZE)
        return encoded

    @classmethod
    def decode_vec(cls, encoded: Bytes) -> Vec[Field]:
        L = cls.ENCODED_SIZE
        if len(encoded) % L != 0:
            raise ERR_DECODE

        vec = []
        for i in range(0, len(encoded), L):
            encoded_x = encoded[i:i+L]
            x = cls(OS2IP(encoded_x))
            vec.append(x)
        return vec

    def __add__(self, other: Field) -> Field:
        return self.__class__(self.val + other.val)

    def __neg__(self) -> Field:
        return self.__class__(-self.val)

    def __mul__(self, other: Field) -> Field:
        return self.__class__(self.val * other.val)

    def inv(self) -> Field:
        return self.__class__(self.val^-1)

    def __eq__(self, other: Field) -> Field:
        return self.val == other.val

    def __sub__(self, other: Field) -> Field:
        return self + (-other)

    def __div__(self, other: Field) -> Field:
        return self * other.inv()

    def __pow__(self, n: Unsigned) -> Field:
        return self.__class__(self.val ^ n)

    def __str__(self):
        return str(self.val)

    def __repr__(self):
        return str(self.val)

    def as_unsigned(self) -> Unsigned:
        return int(self.gf(self.val))


# The finite field GF(2^32 * 4294967295 + 1).
class Field64(Field):
    MODULUS = 2^32 * 4294967295 + 1
    GEN_ORDER = 2^32
    ENCODED_SIZE = 8

    # Operational parameters
    gf = GF(MODULUS)

    @classmethod
    def gen(cls):
        return cls(7)^4294967295


# The finite field GF(2^64 * 4294966555 + 1).
class Field96(Field):
    MODULUS = 2^64 * 4294966555 + 1
    GEN_ORDER = 2^64
    ENCODED_SIZE = 12

    # Operational parameters
    gf = GF(MODULUS)

    @classmethod
    def gen(cls):
        return cls(3)^4294966555


# The finite field GF(2^66 * 4611686018427387897 + 1).
class Field128(Field):
    MODULUS = 2^66 * 4611686018427387897 + 1
    GEN_ORDER = 2^66
    ENCODED_SIZE = 16

    # Operational parameters
    gf = GF(MODULUS)

    @classmethod
    def gen(cls):
        return cls(7)^4611686018427387897


##
# POLYNOMIAL ARITHMETIC
#


# Remove leading zeros from the input polynomial.
def poly_strip(Field, p):
    for i in reversed(range(len(p))):
        if p[i] != Field(0):
            return p[:i+1]
    return []


# Multiply two polynomials.
def poly_mul(Field, p, q):
    r = [Field(0) for _ in range(len(p) + len(q))]
    for i in range(len(p)):
        for j in range(len(q)):
            r[i + j] += p[i] * q[j]
    return poly_strip(Field, r)


# Evaluate a polynomial at a point.
def poly_eval(Field, p, eval_at):
    if len(p) == 0:
        return Field(0)

    p = poly_strip(Field, p)
    result = p[-1]
    for c in reversed(p[:-1]):
        result *= eval_at
        result += c

    return result


# Compute the Lagrange interpolation polynomial for the given points.
def poly_interp(Field, xs, ys):
    R = PolynomialRing(Field.gf, "x")
    p = R.lagrange_polynomial([(x.val, y.val) for (x, y) in zip(xs, ys)])
    return poly_strip(Field, list(map(lambda x: Field(x), p.coefficients())))


##
# TESTS
#

def test_field(cls):
    # Test constructing a field element from an integer.
    assert cls(1337) == cls(cls.gf(1337))

    # Test generating a zero-vector.
    vec = cls.zeros(23)
    assert len(vec) == 23
    for x in vec:
        assert x == cls(cls.gf.zero())

    # Test generating a random vector.
    vec = cls.rand_vec(23)
    assert len(vec) == 23

    # Test arithmetic.
    x = cls(cls.gf.random_element())
    y = cls(cls.gf.random_element())
    assert x + y == cls(x.val + y.val)
    assert x - y == cls(x.val - y.val)
    assert -x == cls(-x.val)
    assert x * y == cls(x.val * y.val)
    assert x.inv() == cls(x.val^-1)

    # Test serialization.
    want = cls.rand_vec(10)
    got = cls.decode_vec(cls.encode_vec(want))
    assert got == want

    # Test generator.
    assert cls.gen()^cls.GEN_ORDER == cls(1)


if __name__ == "__main__":
    test_field(Field64)
    test_field(Field96)
    test_field(Field128)

    # Test polynomial interpolation.
    cls = Field64
    p = cls.rand_vec(10)
    xs = [cls(x) for x in range(10)]
    ys = [poly_eval(cls, p, x) for x in xs]
    q = poly_interp(cls, xs, ys)
    for x in xs:
        a = poly_eval(cls, p, x)
        b = poly_eval(cls, q, x)
        assert a == b
