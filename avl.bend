object Dual { approx, exact }

type Avl:
  Node { key, height, ~left, ~right }
  Leaf

# https://www.geeksforgeeks.org/insertion-in-an-avl-tree/
#
#      y                               x
#     / \     Right Rotation          /  \
#    x   T3   - - - - - - - >        T1   y
#   / \       < - - - - - - -            / \
#  T1  T2     Left Rotation            T2  T3

def max(x, y):
  if x > y:
    return x
  else:
    return y

def Avl.depth(x):
  match x:
    case Avl/Node:
      return x.height
    case Avl/Leaf:
      return 0

def Avl.balance(x):
  match x:
    case Avl/Node:
      return Avl.depth(x.left) - Avl.depth(x.right)
    case Avl/Leaf:
      return 0

def Avl.create(key, l, r):
  return Avl/Node(key, 1 + max(Avl.depth(l), Avl.depth(r)), l, r)

def Avl/Leaf.create(key):
  return Avl.create(key, Avl/Leaf, Avl/Leaf)

def Avl.rotate_right(y):
  match y:
    case Avl/Leaf:
      return y
    case Avl/Node:
      x = y.left
      match x:
        case Avl/Leaf:
          return y
        case Avl/Node:
          return Avl.create(x.key, x.left, Avl.create(y.key, x.right, y.right))

def Avl.rotate_left(x):
  match x:
    case Avl/Leaf:
      return x
    case Avl/Node:
      y = x.right
      match y:
        case Avl/Leaf:
          return x
        case Avl/Node:
          return Avl.create(y.key, Avl.create(x.key, x.left, y.left), y.right)

def Avl.cmp(x, y):
  match x:
    case Avl/Leaf:
      match y:
        case Avl/Leaf:
          return 0
        case Avl/Node:
          return 1
    case Avl/Node:
      open Dual: x.key
      return Avl.sign(x.key.approx, x.key.exact, y)

def Avl.close(approx0, approx1):
  return approx0 - approx1 < 0.00001

def Avl.sign(approx, exact, y):
  match y:
    case Avl/Leaf:
      return -1
    case Avl/Node:
      open Dual: y.key
      if Avl.close(approx, y.key.approx):
        if exact == y.key.exact:
          return 0
        elif exact > y.key.exact:
          return 1
        else:
          return -1
      else:
        if approx > y.key.approx:
          return 1
        else:
          return -1

def Avl.sum(x):
  match x:
    case Avl/Leaf:
      return 0
    case Avl/Node:
      return x.key + Avl.sum(x.left) + Avl.sum(x.right)

def Avl.repr(x):
  return Avl.walk(x, String/Nil, 0, String/Nil)

def Avl.repr_int(rtl, key):
  if key >= 10:
    return Avl.repr_int(String/Cons((key % 10) + 48, rtl), key / 10)
  else:
    return String/Cons(key + 48, rtl)

def Avl.repr_key(rtl, key):
  open Dual: key
  return Avl.repr_int(rtl, key.exact)

def Avl.empty(x):
  match x:
    case Avl/Leaf:
      return 1
    case Avl/Node:
      match x.left:
        case Avl/Leaf:
          match x.right:
            case Avl/Leaf:
              return 1
            case Avl/Node:
              return 0
        case Avl/Node:
          return 0

def Avl.concat(rtl, ltr):
  match ltr:
    case String/Nil:
      return rtl
    case _:
      return Avl.concat(String/Cons(ltr.head, rtl), ltr.tail)

def Avl.walk(x, rtl, prefix, ltr):
  match x:
    case Avl/Leaf:
      return rtl
    case Avl/Node:
      if Avl.empty(x):
        rtl = String/Cons('\n', rtl)
        rtl = Avl.repr_key(rtl, x.key)
        rtl = String/Cons('\u{2500}', rtl)
      else:
        rtl = Avl.walk(x.right, rtl, '\u{2514}', String/Cons(' ', ltr))
        rtl = Avl.walk(x.left, rtl, '\u{251C}', String/Cons('\u{2502}', ltr))
        rtl = String/Cons('\n', rtl)
        rtl = Avl.repr_key(rtl, x.key)
        rtl = String/Cons('\u{252C}', rtl)
      switch prefix:
        case 0:
          rtl = rtl
        case _:
          rtl = String/Cons(prefix, rtl)
      match ltr:
        case String/Cons:
          return Avl.concat(rtl, ltr.tail)
        case _:
          return rtl

def Avl.pre_balance(x, cond, balance):
  match x:
    case Avl/Leaf:
      return x
    case Avl/Node:
      if cond:
        if balance == 1:
          return Avl.create(x.key, Avl.rotate_left(x.left), x.right)
        else:
          return Avl.create(x.key, x.left, Avl.rotate_right(x.right))
      else:
        return x

def Avl.re_balance(x, balance):
  if balance == 0:
    return x
  elif balance == 1:
    return Avl.rotate_right(x)
  else:
    return Avl.rotate_left(x)

def main():
  x = Avl.create(Dual(0.0, 1), Avl.create(Dual(0.0, 2), Avl/Leaf.create(Dual(0.0, 3)), Avl/Leaf.create(Dual(0.0, 4))),
      Avl.create(Dual(0.0, 5), Avl/Leaf.create(Dual(0.0, 6)), Avl/Leaf.create(Dual(0.0, 7))))
  with IO:
    * <- IO/print(Avl.repr(x))
    return *
