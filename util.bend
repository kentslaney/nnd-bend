def max(x, y):
  if x > y:
    return x
  else:
    return y

def zip(i0, i1):
  match i0:
    case List/Cons:
      match i1:
        case List/Cons:
          return List/Cons((i0.head, i1.head), zip(i0.tail, i1.tail))
        case _:
          return List/Nil
    case _:
      return List/Nil

def sided(it):
  match it:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      l, r = sided(it.tail)
      mask, data = it.head
      if mask:
        return (l, List/Cons(data, r))
      else:
        return (List/Cons(data, l), r)

hvm inf -> (f24 -> f24):
  ($([*7f8000] ret) ret)

def median(arr):
  (len, arr) = List/length(arr)
  return select(arr, len / 2)

def select_fifth(arr):
  match arr:
    case List/Cons:
      (out, nxt) = select5(arr, 2)
      return List/Cons(out, select_fifth(nxt))
    case List/Nil:
      return List/Nil

# arr is a list of unique f24s
def select(arr, k):
  (len, arr) = List/length(arr)
  if len <= 5:
    (out, *) = select5(arr, k)
    return out
  else:
    pivot = select(select_fifth(arr), len / 10)
    lo = List/filter(arr, lambda x: x < pivot)
    (size, lo) = List/length(lo)
    if size > k:
      return select(lo, k)
    elif size == k:
      return pivot
    else:
      return select(List/filter(arr, lambda x: x > pivot), k - size - 1)

def select5_inner(arr, s, k, i, n):
  match arr:
    case List/Nil:
      return (s, n)
    case List/Cons:
      match s:
        case List/Nil:
          return (List/Cons(arr.head, List/Nil), 1)
        case List/Cons:
          if s.head <= arr.head:
            if n > k:
              return (s, n)
            else:
              return (List/Cons(arr.head, s), n + 1)
          else:
            (r, n) = select5_inner(arr, s.tail, k, i, n - 1)
            if n <= k:
              return (List/Cons(s.head, r), n + 1)
            else:
              return (r, n)

def select5_(arr, s, k, i, n):
  (s, n) = select5_inner(arr, s, k, i, n)
  if i == 0:
    match s:
      case List/Cons:
        match arr:
          case List/Cons:
            return s.head, arr.tail
          case _:
            return s.head, arr
      case _:
        return *
  else:
    match arr:
      case List/Cons:
        return select5_(arr.tail, s, k, i - 1, n)
      case List/Nil:
        return *

def select5(arr, k):
  (i, arr) = List/length(arr)
  if i > 5:
    return select5_(arr, List/Nil, k, 4, 0)
  else:
    return select5_(arr, List/Nil, k, i - 1, 0)

# via pyerf
def polevl_(x, coefs, n):
  match coefs:
    case List/Cons:
      return coefs.head * x ** n + polevl_(x, coefs.tail, n - 1.0)
    case _:
      return 0.0

def polevl(x, coefs):
  (len, coefs) = List/length(coefs)
  return polevl_(x, coefs, u24/to_f24(len - 1))

def p1evl(x, coefs):
  return polevl(x, List/Cons(1.0, coefs))

exp_neg2 = (Math/E ** -2)
root_2pi = (Math/sqrt(2 * Math/PI))

# approximation for 0 <= abs(z - 0.5) <= 3/8
p0 = [
  -59.963350101,
  +98.001075418,
  -56.676285746,
  +13.931260938,
  -1.2391658386
]

q0 = [
  +1.954488583,
  +4.676279128,
  +86.360242139,
  -225.46268785,
  +200.26021238,
  -82.037225616,
  +15.905622512,
  -1.1833162112
]

# Approximation for interval z = sqrt(-2 log y ) between 2 and 8
# i.e., y between exp(-2) = .135 and exp(-32) = 1.27e-14.
p1 = [
  +4.0554489230,
  +31.525109459,
  +57.162819224,
  +44.080507389,
  +14.684956192,
  +2.1866330685,
  -0.1402560791,
  -0.03504246268,
  -0.000857456785
]

q1 = [
  +15.779988325,
  +45.390763512,
  +41.317203825,
  +15.042538569,
  +2.504649462,
  -0.1421829228,
  -0.03808064076,
  -0.000933259480
]

# Approximation for interval z = sqrt(-2 log y ) between 8 and 64
# i.e., y between exp(-32) = 1.27e-14 and exp(-2048) = 3.67e-890.
p2 = [
  3.2377489177,
  6.91522889,
  3.938810252,
  1.3330346081,
  0.2014853895,
  0.01237166348,
  0.0003015815535,
  0.000002658069746,
  0.00000000623974539
]

q2 = [
  6.02427039364,
  3.679835638,
  1.3770209948,
  0.2162369935,
  0.0134204006,
  0.0003280144646,
  0.000002892478647,
  0.00000000679019408
]

def ndtri(y: f24):
  if y > (1.0 - exp_neg2):
    y = 1.0 - y
    sign_flag = 0
  else:
    sign_flag = 1

  # Shortcut case where we don't need high precision
  # between -0.135 and 0.135
  if y > exp_neg2:
    y -= 0.5
    y2 = y ** 2.0
    x = y + y * (y2 * polevl(y2, p0) / p1evl(y2, q0))
    x = x * root_2pi
    return x
  else:
    x = Math/sqrt(-2.0 * Math/log(y, Math/E))
    x0 = x - Math/log(x, Math/E) / x

    z = 1.0 / x
    if x < 8.0:  # y > exp(-32) = 1.2664165549e-14
      x1 = z * polevl(z, p1) / p1evl(z, q1)
    else:
      x1 = z * polevl(z, p2) / p1evl(z, q2)

    x = x0 - x1
    if sign_flag == 0:
      return -1.0 * x
    else:
      return x

def erf_inv(z):
  return ndtri((z + 1.0) / 2.0) / Math/sqrt(2.0)
