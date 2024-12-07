# https://github.com/jax-ml/jax/blob/main/jax/_src/prng.py
from ./util import (zip, sided, select, erf_inv, reshape, shape_size)

# big endian
nbits = 16
mask16 = 0x00FFFF
carry16 = 0x010000

nmant = 15
significand_prefix = 0x8000

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
  first = (x0 << d) | (x0 >> (2 * nbits - d))
  second = (x1 >> (nbits - d)) | (x1 << (d - nbits))
  return mask16 & (first | second)

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

def threefry_(x0, x1, r, i, j, n):
  (x0, x1) = apply_rounds((x0, x1), r)
  return add(x0, i), add(add(x1, j), (0, n))

def threefry2x32(k0, k1, x0, x1):
  (r0, r1) = ((13, 15, 26, 6), (17, 29, 16, 24))
  k2 = xor(xor(k0, k1), (0x1BD1, 0x1BDA))

  x0 = add(x0, k0)
  x1 = add(x1, k1)

  x0, x1 = threefry_(x0, x1, r0, k1, k2, 1)
  x0, x1 = threefry_(x0, x1, r1, k2, k0, 2)
  x0, x1 = threefry_(x0, x1, r0, k0, k1, 3)
  x0, x1 = threefry_(x0, x1, r1, k1, k2, 4)
  x0, x1 = threefry_(x0, x1, r0, k2, k0, 5)

  return (x0, x1)

def key(seed):
  return ((0, 0), (0, mask16 & seed))

def repr_hex(rtl, keys):
  remainder = keys % 16
  if remainder >= 10:
    remainder = remainder + 55
  else:
    remainder = remainder + 48
  rtl = String/Cons(remainder, rtl)
  if keys >= 16:
    return repr_hex(rtl, keys / 16)
  else:
    return rtl

def pad_word(rtl, size):
  (length, *) = List/length(rtl)
  if length < size:
    return pad_word(String/Cons('0', rtl), size)
  else:
    return rtl

def repr_hex_32(rtl, keys):
  (k0, k1) = keys
  (length, *) = List/length(rtl)
  word = pad_word(repr_hex(rtl, k1), length + 4)
  return pad_word(repr_hex(word, k0), length + 8)

def repr_hex_64(rtl, keys):
  (k0, k1, k2, k3) = keys
  return repr_hex_32(String/Cons(' ', repr_hex_32(rtl, (k2, k3))), (k0, k1))

def random_bits_(k0, k1, total, aliased, val, offset):
  if val > 1:
    pivot = val / 2
    (a0, a1) = random_bits_(k0, k1, total, aliased, pivot, offset)
    (b0, b1) = random_bits_(k0, k1, total, aliased, val - pivot, offset + pivot)
    return (List/concat(a0, b0), List/concat(a1, b1))
  else:
    odd_pad = aliased & (offset == total - 1)
    if odd_pad:
      lo = 0
    else:
      lo = total + offset
    (x0, x1) = threefry2x32(k0, k1, (0, offset), (0, lo))
    if odd_pad:
      return ([x0], [])
    else:
      return ([x0], [x1])

def random_bits(keys, shape):
  (k0, k1) = keys
  num = shape_size(shape)
  is_odd = num % 2
  total = num / 2 + is_odd
  (x0, x1) = random_bits_(k0, k1, total, is_odd, total, 0)
  return reshape(List/concat(x0, x1), shape)

def split_(out):
  match out:
    case List/Cons:
      match row = out.head:
        case List/Cons:
          match end = row.tail:
            case List/Cons:
              row = (row.head, end.head)
            case _:
              row = List/Nil
        case _:
          row = List/Nil
      return List/Cons(row, split_(out.tail))
    case List/Nil:
      return List/Nil

def split(keys, num):
  return split_(random_bits(keys, [num, 2]))

def split_2(keys):
  match out = split(keys, 2):
    case List/Cons:
      match end = out.tail:
        case List/Cons:
          return (out.head, end.head)
        case _:
          return List/Nil
    case _:
      return List/Nil

def bitcast_mantissa(x: u24) -> f24:
  cast = u24/to_f24(x) / u24/to_f24(significand_prefix)
  return cast

def bitcast_32(x):
  (hi, *) = x
  return bitcast_mantissa(hi >> (nbits - nmant))

def uniform_(keys, num):
  return [bitcast_32(i) for i in random_bits(keys, [num])]

def uniform(keys, shape, lo: f24, hi: f24):
  scaled = [i * (hi - lo) + lo for i in uniform_(keys, shape_size(shape))]
  return reshape(scaled, shape)

def flatten_64(it):
  match it:
    case List/Cons:
      ((x0, x1), (x2, x3)) = it.head
      return List/Cons([x0, x1, x2, x3], flatten_64(it.tail))
    case _:
      return List/Nil

def mod_(carry, dividend, divisor, mul):
  match dividend:
    case List/Cons:
      x = ((carry * mul) % divisor + dividend.head) % divisor
      return mod_(x, dividend.tail, divisor, mul)
    case List/Nil:
      return carry

def big_mod(it, span):
  match it:
    case List/Cons:
      el = mod_(0, it.head, span, carry16 % span)
      return List/Cons(el, big_mod(it.tail, span))
    case _:
      return List/Nil

def randint_(keys, num, lo, hi):
  k1, k2 = split_2(keys)
  hi_bits = random_bits(k1, [num])
  lo_bits = random_bits(k2, [num])
  return [lo + i for i in big_mod(flatten_64(zip(hi_bits, lo_bits)), hi - lo)]

def randint(keys, shape, lo, hi):
  return reshape(randint_(keys, shape_size(shape), lo, hi), shape)

def bernoulli(keys, shape, p):
  flat = [i < p for i in uniform_(keys, shape_size(shape))]
  return reshape(flat, shape)

sqrt2 = 1.4142135623

def normal_(flat):
  match flat:
    case List/Cons:
      return List/Cons(sqrt2 * erf_inv(flat.head), normal_(flat.tail))
    case _:
      return List/Nil

def normal(keys, shape):
  return reshape(normal_(uniform(keys, [shape_size(shape)], -1.0, 1.0)), shape)

def partition_cutoffs(arr, splits, len, extra, i):
  if i >= splits:
    return List/Nil
  else:
    if i < extra:
      size = i
    else:
      size = extra
    cutoff = select(arr, size + len * i)
    return List/Cons(cutoff, partition_cutoffs(arr, splits, len, extra, i + 1))

def partition_mask(arr, cutoff):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      return List/Cons(arr.head >= cutoff, partition_mask(arr.tail, cutoff))

def partition_(arr, order, cutoffs):
  match cutoffs:
    case List/Nil:
      return List/Cons(arr, List/Nil)
    case List/Cons:
      mask = partition_mask(order, cutoffs.head)
      (res, nxt) = sided(zip(mask, arr))
      (*, hi) = sided(zip(mask, order))
      return List/Cons(res, partition_(nxt, hi, cutoffs.tail))

def partition(rng, arr, limit):
  (len, arr) = List/length(arr)
  splits = len / limit + (len % limit > 0)
  order = uniform_(rng, len)
  extra = len % splits
  cutoffs = partition_cutoffs(order, splits, len / splits, extra, 1)
  return partition_(arr, order, cutoffs)

def choice_init(rng, n, samples):
  match rng:
    case List/Nil:
      return List/Nil
    case List/Cons:
      res = randint_(rng.head, samples, 0, n)
      return List/Cons(res, choice_init(rng.tail, n - 1, samples))

def choice_t(data):
  match data:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      match data.head:
        case List/Nil:
          return (List/Nil, List/Nil)
        case List/Cons:
          (res, rem) = choice_t(data.tail)
          return List/Cons(data.head.head, res), List/Cons(data.head.tail, rem)

def choice_offset_(data, pfx):
  match pfx:
    case List/Nil:
      return [data]
    case List/Cons:
      if data >= pfx.head:
        return List/Cons(pfx.head, choice_offset_(data + 1, pfx.tail))
      else:
        return List/Cons(data, pfx)

def choice_offset(data, pfx):
  match data:
    case List/Nil:
      return pfx
    case List/Cons:
      return choice_offset(data.tail, choice_offset_(data.head, pfx))

def choice_(data):
  match data:
    case List/Nil:
      return List/Nil
    case List/Cons:
      (res, rem) = choice_t(data)
      match rem:
        case List/Cons:
          return List/Cons(choice_offset(res, List/Nil), choice_(rem))
        case List/Nil:
          return List/Nil

def choice(rng, n, k, samples):
  return choice_(choice_init(split(rng, k), n, samples))

def graph_offset(data, n):
  match data:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      match data.head:
        case List/Nil:
          (res, rem) = graph_offset(data.tail, n + 1)
          match res:
            case List/Nil:
              return (List/Nil, rem)
            case List/Cons:
              return (List/Nil, List/Cons(res, rem))
        case List/Cons:
          rem = List/Cons(data.head.tail, data.tail)
          (res, rem) = graph_offset(rem, n)
          if data.head.head >= n:
            off = data.head.head + 1
          else:
            off = data.head.head
          return (List/Cons(off, res), rem)

# choice without self-reference
def graph(rng, n, k):
  samples = choice(rng, n - 1, k, n)
  (res, rem) = graph_offset(samples, 0)
  return List/Cons(res, rem)

def test_shift():
  (a0, a1) = rotate_left((0xDEAD, 0xBEEF), 4)
  (b0, b1) = rotate_left((0xDEAD, 0xBEEF), 24)
  return repr_hex_64("\n", (a0, a1, b0, b1))

# import jax; print(hex(int(jax.random.bits(jax.random.key(42)))))
def test_hash():
  (hi, *) = threefry2x32((0, 0), (0, 42), (0, 0), (0, 0))
  return repr_hex_32("\n", hi)

# import jax; print('\n'.join(map(hex, jax.random.bits(jax.random.key(42), 5))))
def test_bits():
  return repr_hex_32_seq(random_bits(key(42), [5]))

# import jax; print(jax.random.uniform(jax.random.key(42), (3,)))
def test_uniform():
  return uniform(key(42), [3], 0.0, 1.0)

# import jax; print(jax.random.randint(jax.random.key(42), (3, 2), 0, 100))
def test_randint():
  return randint(key(42), [3, 2], 0, 100)

def repr_hex_32_seq(res):
  fold res:
    case List/Cons:
      return repr_hex_32(String/Cons('\n', res.tail), res.head)
    case List/Nil:
      return String/Nil

def repr_split(res):
  fold res:
    case List/Cons:
      ((x0, x1), (x2, x3)) = res.head
      return repr_hex_64(String/Cons('\n', res.tail), (x0, x1, x2, x3))
    case List/Nil:
      return String/Nil
