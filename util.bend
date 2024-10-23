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

# via pyerf
def polevl(x, coefs):
  (len, coefs) = List/length(coefs)
  match x:
    case List/Cons:
      match coefs:
        case List/Cons:
          return x.head * coefs.head + polevl(x.tail, coefs.tail)
        case _:
          return 0.0
    case _:
      return 0.0

def p1evl(x, coefs):
  return polevl(x, List/Cons(1.0, coefs))

exp_neg2 = (Math/E ** -2)
root_2pi = (Math/sqrt(2 * Math/PI))

def ndtri(y):
  # approximation for 0 <= abs(z - 0.5) <= 3/8
  P0 = [
    -59.963350101,
    +98.001075418,
    -56.676285746,
    +13.931260938,
    -1.2391658386
  ]

  Q0 = [
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
  P1 = [
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

  Q1 = [
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
  P2 = [
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

  Q2 = [
    6.02427039364,
    3.679835638,
    1.3770209948,
    0.2162369935,
    0.0134204006,
    0.0003280144646,
    0.000002892478647,
    0.00000000679019408
  ]

  if y > (1.0 - exp_neg2):
    y = 1.0 - y
    sign_flag = 0
  else:
    sign_flag = 1

  # Shortcut case where we don't need high precision
  # between -0.135 and 0.135
  if y > exp_neg2:
    y -= 0.5
    y2 = y ** 2
    x = y + y * (y2 * polevl(y2, P0) / p1evl(y2, Q0))
    x = x * root_2pi
    return x
  else:
    x = Math/sqrt(-2.0 * Math/log(y))
    x0 = x - Math/log(x) / x

    z = 1.0 / x
    if x < 8.0:  # y > exp(-32) = 1.2664165549e-14
      x1 = z * polevl(z, P1) / p1evl(z, Q1)
    else:
      x1 = z * polevl(z, P2) / p1evl(z, Q2)

    x = x0 - x1
    if sign_flag != 0:
      return -1.0 * x
    else:
      return x

def erfinv(z):
  return ndtri((z + 1.0) / 2.0) / Math/sqrt(2.0)

def main:
  return ndtri(0.3)
