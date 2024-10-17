# https://github.com/jax-ml/jax/blob/main/jax/_src/prng.py

# low index low order
nbits = 16
mask16 = 0x00FFFF
carry16 = 0x010000

def add(a, b):
  (a0, a1) = a
  (b0, b1) = b
  c = a0 + b0
  return (mask16 & c, mask16 & (((c & carry16) >> nbits) + a1 + b1))

def xor(a, b):
  (a0, a1) = a
  (b0, b1) = b
  return (a0 ^ b0, a1 ^ b1)

def rotate_left(x, d):
  (x0, x1) = x
  return (
      mask16 & ((x0 << d) | (x1 >> (nbits - d)) | (x0 >> (2 * nbits - d))),
      mask16 & ((x1 << d) | (x0 >> (nbits - d)) | (x1 >> (2 * nbits - d))))

def apply_round(v, rot):
  (v0, v1) = v
  v0 = add(v0, v1)
  v1 = rotate_left(v1, rot)
  v1 = xor(v0, v1)
  return v

def apply_rounds(v, r):
  (r0, r1, r2, r3) = r
  v = apply_round(v, r0)
  v = apply_round(v, r1)
  v = apply_round(v, r2)
  return apply_round(v, r3)

def threefry2x32(k0, k1, x0, x1):
  (r0, r1) = ((13, 15, 26, 6), (17, 29, 16, 24))
  k2 = xor(xor(k0, k1), (0x1BDA, 0x1BD1))

  x0 = add(x0, k0)
  x1 = add(x1, k1)

  (x0, x1) = apply_rounds((x0, x1), r0)
  x0 = add(x0, k1)
  x1 = add(add(x1, k2), 1)

  (x0, x1) = apply_rounds((x0, x1), r1)
  x0 = add(x0, k2)
  x1 = add(add(x1, k0), 2)

  (x0, x1) = apply_rounds((x0, x1), r0)
  x0 = add(x0, k0)
  x1 = add(add(x1, k1), 3)

  (x0, x1) = apply_rounds((x0, x1), r1)
  x0 = add(x0, k1)
  x1 = add(add(x1, k2), 4)

  (x0, x1) = apply_rounds((x0, x1), r0)
  x0 = add(x0, k2)
  x1 = add(add(x1, k0), 5)

  return (x0, x1)

def main():
  return add((0xDEAD, 0xBEEF), (0x8BAD, 0xF00D))
