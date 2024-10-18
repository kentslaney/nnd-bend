# https://github.com/jax-ml/jax/blob/main/jax/_src/prng.py

# big endian
nbits = 16
mask16 = 0x00FFFF
carry16 = 0x010000

def add(a, b):
  (a0, a1) = a
  (b0, b1) = b
  c = a1 + b1
  return (mask16 & (((c & carry16) >> nbits) + a0 + b0), mask16 & c)

def xor(a, b):
  (a0, a1) = a
  (b0, b1) = b
  return (a0 ^ b0, a1 ^ b1)

def rotate_el_left(x0, x1, d):
  return mask16 & (
    (x0 << d) | (x0 >> (2 * nbits - d) |
    (x1 >> (nbits - d)) | (x1 << (d - nbits))))

def rotate_left(x, d):
  (x0, x1) = x
  return (rotate_el_left(x0, x1, d), rotate_el_left(x1, x0, d))

def apply_round(v, rot):
  (v0, v1) = v
  v0 = add(v0, v1)
  v1 = rotate_left(v1, rot)
  v1 = xor(v0, v1)
  return (v0, v1)

def apply_rounds(v, r):
  (r0, r1, r2, r3) = r
  v = apply_round(v, r0)
  v = apply_round(v, r1)
  v = apply_round(v, r2)
  return apply_round(v, r3)

def threefry2x32(k0, k1, x0, x1):
  (r0, r1) = ((13, 15, 26, 6), (17, 29, 16, 24))
  k2 = xor(xor(k0, k1), (0x1BD1, 0x1BDA))

  x0 = add(x0, k0)
  x1 = add(x1, k1)

  (x0, x1) = apply_rounds((x0, x1), r0)
  x0 = add(x0, k1)
  x1 = add(add(x1, k2), (0, 1))

  (x0, x1) = apply_rounds((x0, x1), r1)
  x0 = add(x0, k2)
  x1 = add(add(x1, k0), (0, 2))

  (x0, x1) = apply_rounds((x0, x1), r0)
  x0 = add(x0, k0)
  x1 = add(add(x1, k1), (0, 3))

  (x0, x1) = apply_rounds((x0, x1), r1)
  x0 = add(x0, k1)
  x1 = add(add(x1, k2), (0, 4))

  (x0, x1) = apply_rounds((x0, x1), r0)
  x0 = add(x0, k2)
  x1 = add(add(x1, k0), (0, 5))

  return (x0, x1)

def key(seed):
  return ((0, 0), (0, mask16 & seed))

def random_bits(key, width, iota):
  (k0, k1) = key
  (i0, i1) = iota
  (b0, b1) = threefry2x32(k0, k1, (0, i0), (0, i1))
  if width == 64:
    (b00, b01) = b0
    (b10, b11) = b1
    return (b00, b01, b10, b11)
  else:
    bits = b0 # partitionable: xor(b0, b1)
    if width == 32:
      return bits
    else:
      (hi, lo) = bits
      bits = (hi << nbits) | lo
      if width == 24:
        return bits
      elif width == 16:
        return mask16 & bits
      else: # width == 8
        return 0xFF & bits

def repr_hex(rtl, key):
  remainder = key % 16
  if remainder >= 10:
    remainder = remainder + 55
  else:
    remainder = remainder + 48
  rtl = String/Cons(remainder, rtl)
  if key >= 16:
    return repr_hex(rtl, key / 16)
  else:
    return rtl

def pad_word(rtl, size):
  (length, *) = List/length(rtl)
  if length < size:
    return pad_word(String/Cons('0', rtl), size)
  else:
    return rtl

def repr_hex_32(rtl, key):
  (k0, k1) = key
  (length, *) = List/length(rtl)
  word = pad_word(repr_hex(rtl, k1), length + 4)
  return pad_word(repr_hex(word, k0), length + 8)

def repr_hex_64(rtl, key):
  (k0, k1, k2, k3) = key
  return repr_hex_32(String/Cons(' ', repr_hex_32(rtl, (k2, k3))), (k0, k1))

def pairs(keys):
  match keys:
    case List/Cons:
      pair = keys.tail
      match pair:
        case List/Cons:
          return List/Cons((keys.head, pair.head), pairs(pair.tail))
        case _:
          return keys
    case _:
      return keys

def split(key, num):
  bend val = num, offset = 0:
    when val > 1:
      floordiv = val / 2
      (a0, a1) = fork(floordiv, offset)
      (b0, b1) = fork(val - floordiv, offset + floordiv)
      x = (List/concat(a0, b0), List/concat(a1, b1))
    else:
      (x0, x1, x2, x3) = random_bits(key, 64, (offset, num + offset))
      x = ([(x0, x1)], [(x2, x3)])
  (x0, x1) = x
  return pairs(List/concat(x0, x1))

def test_shift():
  (a0, a1) = rotate_left((0xDEAD, 0xBEEF), 4)
  (b0, b1) = rotate_left((0xDEAD, 0xBEEF), 24)
  return repr_hex_64("\n", (a0, a1, b0, b1))

# python -c "import jax; print('{:08X}'.format(int("\
#   "jax.random.bits(jax.random.key(42), dtype=jax.numpy.uint32))))"
def test_hash():
  return repr_hex_32("\n", random_bits(key(42), 32, (0, 0)))

# python -c "import jax; print(jax.random.split(jax.random.key(42), 4))" |
#   sed 's/.*:\|\[\|\]//g' | tr -s ' ' |
#   xargs -I % python -c "print(' '.join('{:08X}'.format(int(i)) for i in '''%'''.strip().split()))"
def test_split():
  return repr_split(split(key(42), 4))

def repr_split(res):
  fold res:
    case List/Cons:
      ((x0, x1), (x2, x3)) = res.head
      return repr_hex_64(String/Cons('\n', res.tail), (x0, x1, x2, x3))
    case List/Nil:
      return String/Nil

def main:
  with IO:
    * <- IO/print(test_split())
    return 0
