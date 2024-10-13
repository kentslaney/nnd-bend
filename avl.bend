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
      return Avl.sign(x.key, y)

def Avl.close(approx0, approx1):
  return approx0 - approx1 < 0.00001

def Avl.sign(key, y):
  open Dual: key
  match y:
    case Avl/Leaf:
      return -1
    case Avl/Node:
      open Dual: y.key
      if Avl.close(key.approx, y.key.approx):
        if key.exact == y.key.exact:
          return 0
        elif key.exact > y.key.exact:
          return 1
        else:
          return -1
      else:
        if key.approx > y.key.approx:
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

def Avl.branchless(x):
  match x:
    case Avl/Leaf:
      return 1
    case Avl/Node:
      match x.left:
        case Avl/Leaf:
          return 1
        case Avl/Node:
          match x.right:
            case Avl/Leaf:
              return 1
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

def Avl.pre_balance(x, balance):
  match x:
    case Avl/Leaf:
      return x
    case Avl/Node:
      if balance == 1:
        return Avl.create(x.key, Avl.rotate_left(x.left), x.right)
      elif balance == -1:
        return Avl.create(x.key, x.left, Avl.rotate_right(x.right))
      else:
        return x

def Avl.re_balance(x, balance):
  if balance == -1:
    return Avl.rotate_left(x)
  elif balance == 1:
    return Avl.rotate_right(x)
  else:
    return x

def Avl.l1ge2(x):
  if x >= 2:
    return 1
  elif x <= -2:
    return -1
  else:
    return 0

def Avl.insert(node, key):
  match node:
    case Avl/Leaf:
      return Avl/Leaf.create(key)
    case Avl/Node:
      sign = Avl.sign(key, node)
      if sign == 0:
        return node
      else:
        if sign == 1:
          node = Avl.create(node.key, node.left, Avl.insert(node.right, key))
        else:
          node = Avl.create(node.key, Avl.insert(node.left, key), node.right)

        balance = Avl.l1ge2(Avl.balance(node))
        if balance == 0:
          side = 1
        else:
          if balance == 1:
            vs = node.left
          else:
            vs = node.right
          side = Avl.sign(node, vs)
        if balance == side:
          node = Avl.pre_balance(node, balance)
        else:
          node = node
        return Avl.re_balance(node, balance)

def Avl.successor(root, prev):
  match root:
    case Avl/Leaf:
      return prev
    case Avl/Node:
      return Avl.successor(root.left, root.key)

def Avl.remove(root, key):
  match root:
    case Avl/Leaf:
      return root
    case Avl/Node:
      side = Avl.sign(key, root)
      if side == -1:
        root = Avl.create(root.key, Avl.remove(root.left, key), root.right)
      elif side == 1:
        root = Avl.create(root.key, root.left, Avl.remove(root.right, key))
      elif Avl.branchless(root):
        match root.left:
          case Avl/Leaf:
            root = root.right
          case Avl/Node:
            root = root.left
      else:
        nxt = Avl.successor(root.right, root.key)
        root = Avl.create(nxt, root.left, Avl.remove(root.right, nxt))
      match root:
        case Avl/Leaf:
          return root
        case Avl/Node:
          balance = Avl.l1ge2(Avl.balance(root))
          if balance == 0:
            double = 0
          else:
            if balance == 1:
              side = Avl.balance(root.left)
            else:
              side = Avl.balance(root.right)
            double = Avl.l1ge2(balance - side)
          if double:
            root = Avl.pre_balance(root, balance)
          else:
            root = root
          return Avl.re_balance(root, balance)

def main():
  root = Avl/Leaf()
  root = Avl.insert(root, Dual(0.0, 10))
  root = Avl.insert(root, Dual(0.0, 20))
  root = Avl.insert(root, Dual(0.0, 30))
  root = Avl.insert(root, Dual(0.0, 40))
  root = Avl.insert(root, Dual(0.0, 50))
  #root = Avl.insert(root, Dual(0.0, 25))
  with IO:
    * <- IO/print(Avl.repr(root))
    return *
