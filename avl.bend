from ./util import (max,)
from ./map import (DirectAccess,)

type Avl:
  Node { key, height, ~left, ~right }
  Leaf

# leaves are always largest if compared
type AvlKey:
  Single { key, data }
  Double { key0, key1, data }
  Dual { approx, exact, data }

type AvlData:
  Nil
  Inert { data }
  Max { value, data }
  MinQueue { size, values }

type QueueData:
  Key { key }
  Dual { key, uniq }
  Kv { key, data }

# https://www.geeksforgeeks.org/insertion-in-an-avl-tree/
#
#      y                               x
#     / \     Right Rotation          /  \
#    x   T3   - - - - - - - >        T1   y
#   / \       < - - - - - - -            / \
#  T1  T2     Left Rotation            T2  T3

def abs(x):
  if x < +0:
    return -1 * x
  else:
    return x

def Avl.depth(x):
  match x:
    case Avl/Node:
      return x.height
    case Avl/Leaf:
      return +0

def Avl.balance(x):
  match x:
    case Avl/Node:
      return Avl.depth(x.left) - Avl.depth(x.right)
    case Avl/Leaf:
      return +0

def Avl.create(key, l, r):
  return Avl/Node(key, +1 + max(Avl.depth(l), Avl.depth(r)), l, r)

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
          return +0
        case Avl/Node:
          return +1
    case Avl/Node:
      return Avl.sign(x.key, y)

def Avl.close(approx0, approx1):
  return abs(approx0 - approx1) / max(0.00001, abs(approx0 + approx1)) < 0.00001

def Avl.sign(key, y):
  match y:
    case Avl/Leaf:
      return -1
    case Avl/Node:
      match key:
        case AvlKey/Single:
          match y.key:
            case AvlKey/Single:
              if key.key == y.key.key:
                return +0
              elif key.key > y.key.key:
                return +1
              else:
                return -1
            case _:
              return -1
        case AvlKey/Double:
          match y.key:
            case AvlKey/Double:
              if key.key0 == y.key.key0:
                if key.key1 == y.key.key1:
                  return +0
                elif key.key1 > y.key.key1:
                  return +1
                else:
                  return -1
              else:
                if key.key0 > y.key.key0:
                  return +1
                else:
                  return -1
            case AvlKey/Single:
              return +1
            case AvlKey/Dual:
              return -1
        case AvlKey/Dual:
          match y.key:
            case AvlKey/Dual:
              if Avl.close(key.approx, y.key.approx):
                if key.exact == y.key.exact:
                  return +0
                elif key.exact > y.key.exact:
                  return +1
                else:
                  return -1
              else:
                if key.approx > y.key.approx:
                  return +1
                else:
                  return -1
            case _:
              return +1

def QueueData.map(arr):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      match arr.head:
        case QueueData/Key:
          res = arr.head.key
        case _:
          res = arr.head.key
      return List/Cons(res, QueueData.map(arr.tail))

def QueueData.values(arr):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      match arr.head:
        case QueueData/Kv:
          res = arr.head.data
        case QueueData/Dual:
          res = arr.head.uniq
        case _:
          res = arr.head.key
      return List/Cons(res, QueueData.values(arr.tail))

def Avl.repr_key(rtl, key, height):
  match key:
    case AvlKey/Single:
      data = key.data
    case _:
      data = key.data
  match data:
    case AvlData/Max:
      rtl = Avl.repr_int(rtl, data.value)
    case AvlData/MinQueue:
      rtl = Avl.repr_int(rtl, data.size)
      # as of writing there's no builtin String/concat and this was easier
      rtl = String/Cons(':', String/Cons(' ', rtl))
      rtl = String/Cons('m', String/Cons('i', String/Cons('t', rtl)))
      rtl = String/Cons(' ', String/Cons('l', String/Cons('i', rtl)))
      rtl = Avl.repr_floats(rtl, QueueData.map(data.values))
      rtl = String/Cons(' ', rtl)
      rtl = Avl.repr_ints(rtl, QueueData.values(data.values))
    case _:
      rtl = String/Cons('*', rtl)
  rtl = String/Cons(' ', String/Cons('|', String/Cons(' ', rtl)))
  match key:
    case AvlKey/Single:
      rtl = String/Cons(' ', Avl.repr_int(rtl, key.key))
    case AvlKey/Double:
      rtl = String/Cons(' ', Avl.repr_int(rtl, key.key1))
      rtl = String/Cons(' ', Avl.repr_int(rtl, key.key0))
    case AvlKey/Dual:
      rtl = String/Cons(' ', Avl.repr_int(rtl, key.exact))
      rtl = String/Cons(' ', Avl.repr_float(rtl, key.approx))
  #(
  rtl = String/Cons(')', rtl)
  rtl = Avl.repr_int(rtl, height)
  rtl = String/Cons('(', rtl)
  #)
  return rtl

def Avl.repr(x):
  return Avl.walk(x, String/Nil, +0, String/Nil)

def Avl.list_repr(x):
  match x:
    case List/Nil:
      return String/Nil
    case List/Cons:
      rem = Avl.list_repr(x.tail)
      return Avl.walk(x.head, rem, +0, String/Nil)

def Avl.map_repr(x):
  return Avl.map_repr_(x, String/Nil)

def Avl.map_repr_(x, rtl):
  match x:
    case DirectAccess/Leaf:
      return Avl.walk(x.value, rtl, +0, String/Nil)
    case DirectAccess/Node:
      return Avl.map_repr_(x.left, Avl.map_repr_(x.right, rtl))

def Avl.repr_int(rtl, key):
  if key < +0:
    return String/Cons('-', Avl.repr_int(rtl, -1 * key))
  elif key >= +10:
    return Avl.repr_int(String/Cons((key % 10) + '0', rtl), key / 10)
  else:
    return String/Cons(key + '0', rtl)

def Avl.repr_ints_(rtl, keys):
  match keys:
    case List/Nil:
      return rtl
    case List/Cons:
      rtl = Avl.repr_ints_(rtl, keys.tail)
      return List/Cons(' ', Avl.repr_int(rtl, keys.head))

def Avl.repr_ints(rtl, keys):
  rtl = Avl.repr_ints_(String/Cons(']', rtl), keys)
  match rtl:
    case String/Cons:
      if rtl.head == ' ':
        return String/Cons('[', rtl.tail)
      else:
        return String/Cons('[', rtl)
    case String/Nil:
      return String/Cons('[', rtl)

def Avl.repr_floats_(rtl, keys):
  match keys:
    case List/Nil:
      return rtl
    case List/Cons:
      rtl = Avl.repr_floats_(rtl, keys.tail)
      return List/Cons(' ', Avl.repr_float(rtl, keys.head))

def Avl.repr_floats(rtl, keys):
  rtl = Avl.repr_floats_(String/Cons(']', rtl), keys)
  match rtl:
    case String/Cons:
      if rtl.head == ' ':
        return String/Cons('[', rtl.tail)
      else:
        return String/Cons('[', rtl)
    case String/Nil:
      return String/Cons('[', rtl)

def Avl.repr_float_(rtl, key, n):
  lo = +10.0 ** (u24/to_f24(n))
  rem = f24/to_u24((key / lo) % 10.0) + '0'
  if n == 0:
    rtl = String/Cons('.', rtl)
  else:
    rtl = rtl
  if n < 0 | lo * 10.0 < key:
    return Avl.repr_float_(String/Cons(rem, rtl), key, n + 1)
  else:
    return String/Cons(rem, rtl)

def Avl.repr_float(rtl, key):
  if key < 0.0:
    return String/Cons('-', Avl.repr_float_(rtl, key * -1.0, -3))
  else:
    return Avl.repr_float_(rtl, key, -3)

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
        rtl = Avl.repr_key(rtl, x.key, x.height)
        rtl = String/Cons('\u{2500}', rtl)
      else:
        rtl = Avl.walk(x.right, rtl, '\u{2514}', String/Cons(' ', ltr))
        rtl = Avl.walk(x.left, rtl, '\u{251C}', String/Cons('\u{2502}', ltr))
        rtl = String/Cons('\n', rtl)
        rtl = Avl.repr_key(rtl, x.key, x.height)
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
      if balance == +1:
        return Avl.create(x.key, Avl.rotate_left(x.left), x.right)
      elif balance == -1:
        return Avl.create(x.key, x.left, Avl.rotate_right(x.right))
      else:
        return x

def Avl.re_balance(x, balance):
  if balance == -1:
    return Avl.rotate_left(x)
  elif balance == +1:
    return Avl.rotate_right(x)
  else:
    return x

def Avl.l1ge2(x):
  if x >= +2:
    return +1
  elif x <= -2:
    return -1
  else:
    return +0

def Avl.insert(node, key):
  match node:
    case Avl/Leaf:
      return Avl/Leaf.create(key)
    case Avl/Node:
      sign = Avl.sign(key, node)
      if sign == +0:
        return Avl.create(Avl.merge(node.key, key), node.left, node.right)
      else:
        if sign == +1:
          node = Avl.create(node.key, node.left, Avl.insert(node.right, key))
        else:
          node = Avl.create(node.key, Avl.insert(node.left, key), node.right)

        balance = Avl.l1ge2(Avl.balance(node))
        if balance == +0:
          side = +1
        else:
          if balance == +1:
            vs = node.left
          else:
            vs = node.right
          side = Avl.cmp(node, vs)
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
      elif side == +1:
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
          if balance == +0:
            double = +0
          else:
            if balance == +1:
              side = Avl.balance(root.left)
            else:
              side = Avl.balance(root.right)
            double = Avl.l1ge2(balance - side)
          if double:
            root = Avl.pre_balance(root, balance)
          else:
            root = root
          return Avl.re_balance(root, balance)

# https://en.wikipedia.org/w/index.php?title=AVL_tree&oldid=1252999213#Set_operations_and_bulk_operations
def Avl.joinRight(k, l, r):
  match l:
    case Avl/Leaf:
      return Avl.insert(r, k)
    case Avl/Node:
      if Avl.depth(l.right) <= Avl.depth(r) + 1:
        t = Avl.create(k, l.right, r)
        if Avl.depth(t) <= Avl.depth(l.left) + 1:
          return Avl.create(l.key, l.left, t)
        else:
          rot = Avl.rotate_right(t)
          return Avl.rotate_left(Avl.create(l.key, l.left, rot))
      else:
        t = Avl.joinRight(k, l.right, r)
        t_ = Avl.create(l.key, l.left, t)
        if Avl.depth(t) <= Avl.depth(l.left) + 1:
          return t_
        else:
          return Avl.rotate_left(t_)

def Avl.joinLeft(k, l, r):
  match r:
    case Avl/Leaf:
      return Avl.insert(l, k)
    case Avl/Node:
      if Avl.depth(r.left) <= Avl.depth(l) + 1:
        t = Avl.create(k, l, r.left)
        if Avl.depth(t) <= Avl.depth(r.right) + 1:
          return Avl.create(r.key, t, r.right)
        else:
          rot = Avl.rotate_left(t)
          return Avl.rotate_right(Avl.create(r.key, rot, r.right))
      else:
        t = Avl.joinLeft(k, l, r.left)
        t_ = Avl.create(r.key, t, r.right)
        if Avl.depth(t) <= Avl.depth(r.right) + 1:
          return t_
        else:
          return Avl.rotate_right(t_)

def Avl.join(k, l, r):
  if Avl.depth(l) > Avl.depth(r) + 1:
    return Avl.joinRight(k, l, r)
  elif Avl.depth(r) > Avl.depth(l) + 1:
    return Avl.joinLeft(k, l, r)
  else:
    return Avl.create(k, l, r)

def Avl.split(t, k):
  match t:
    case Avl/Leaf:
      return (0, k, Avl/Leaf, Avl/Leaf)
    case Avl/Node:
      sign = Avl.sign(k, t)
      if sign == +0:
        return (1, t.key, t.left, t.right)
      elif sign == -1:
        (b, m, l, r) = Avl.split(t.left, k)
        return (b, m, l, Avl.join(t.key, r, t.right))
      else:
        (b, m, l, r) = Avl.split(t.right, k)
        return (b, m, Avl.join(t.key, t.left, l), r)

def Avl.split_left_of(t, k):
  match t:
    case Avl/Leaf:
      return (Avl/Leaf, Avl/Leaf)
    case Avl/Node:
      sign = Avl.sign(k, t)
      if sign == +1:
        (l, r) = Avl.split_left_of(t.right, k)
        return (Avl.join(t.key, t.left, l), r)
      else:
        (l, r) = Avl.split_left_of(t.left, k)
        return (l, Avl.join(t.key, r, t.right))

def Avl.get(t, k):
  match t:
    case Avl/Leaf:
      return AvlData/Nil
    case Avl/Node:
      sign = Avl.sign(k, t)
      if sign == +0:
        match t.key:
          case AvlKey/Single:
            return t.key.data
          case _:
            return t.key.data
      elif sign == -1:
        return Avl.get(t.left, k)
      else:
        return Avl.get(t.right, k)

def Avl.cas(t, k, v):
  match t:
    case Avl/Leaf:
      return (Avl/Leaf, AvlData/Nil)
    case Avl/Node:
      sign = Avl.sign(k, t)
      if sign == +0:
        match t.key:
          case AvlKey/Single:
            d = t.key.data
          case _:
            d = t.key.data
        match d:
          case AvlData/Inert:
            d = d.data
          case _:
            d = *
        if d < v:
          return t, AvlData/Inert(v)
        else:
          v = Avl.merge_key(t.key, AvlData/Inert(v))
          return Avl.create(v, t.left, t.right), AvlData/Inert(d)
      elif sign == -1:
        rem, res = Avl.cas(t.left, k, v)
        return Avl.create(t.key, rem, t.right), res
      else:
        rem, res = Avl.cas(t.right, k, v)
        return Avl.create(t.key, t.left, rem), res

def Avl.merge_queue(q0, q1, size):
  if size == 0:
    return List/Nil
  else:
    match q0:
      case List/Nil:
        match q1:
          case List/Nil:
            return List/Nil
          case List/Cons:
            return List/Cons(q1.head, Avl.merge_queue(q0, q1.tail, size - 1))
      case List/Cons:
        match q1:
          case List/Nil:
            return List/Cons(q0.head, Avl.merge_queue(q0.tail, q1, size - 1))
          case List/Cons:
            match q0.head:
              case QueueData/Key:
                k0, u0 = q0.head.key, 0
              case QueueData/Dual:
                k0, u0 = q0.head.key, q0.head.uniq
              case _:
                k0, u0 = q0.head.key, 0
            match q1.head:
              case QueueData/Key:
                k1, q0, q1 = q1.head.key, q0, q1
              case QueueData/Dual:
                if u0 == q1.head.uniq:
                  if k0 < q1.head.key:
                    k1, q0, q1 = q1.head.key, q0, q1.tail
                  else:
                    k1, q0, q1 = q1.head.key, q0.tail, q1
                else:
                  k1, q0, q1 = q1.head.key, q0, q1
              case _:
                k1, q0, q1 = q1.head.key, q0, q1
            if k0 < k1:
              return List/Cons(q0.head, Avl.merge_queue(q0.tail, q1, size - 1))
            else:
              return List/Cons(q1.head, Avl.merge_queue(q0, q1.tail, size - 1))

def Avl.merge_key(template, data):
  match template:
    case AvlKey/Single:
      return AvlKey/Single(template.key, data)
    case AvlKey/Double:
      return AvlKey/Double(template.key0, template.key1, data)
    case AvlKey/Dual:
      return AvlKey/Dual(template.approx, template.exact, data)

def Avl.merge(k0, k1):
  match k0:
    case AvlKey/Single:
      d0 = k0.data
    case _:
      d0 = k0.data
  match k1:
    case AvlKey/Single:
      d1 = k1.data
    case _:
      d1 = k1.data
  match d0:
    case AvlData/Max:
      match d1:
        case AvlData/Max:
          if d0.value > d1.value:
            return k0
          else:
            return k1
        case _:
          return k0
    case AvlData/MinQueue:
      match d1:
        case AvlData/MinQueue:
          data = Avl.merge_queue(d0.values, d1.values, d0.size)
          return Avl.merge_key(k0, AvlData/MinQueue(d0.size, data))
        case _:
          return k0
    case _:
      return k1

def Avl.union(t0, t1):
  match t0:
    case Avl/Leaf:
      return t1
    case Avl/Node:
      match t1:
        case Avl/Leaf:
          return t0
        case Avl/Node:
          (b, m, l, r) = Avl.split(t1, t0.key)
          if b:
            m = Avl.merge(t0.key, m)
          else:
            m = t0.key
          return Avl.join(m, Avl.union(t0.left, l), Avl.union(t0.right, r))

def AvlData.placeholder:
  return AvlData/Nil

def QueueData/Key.map(arr):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      return List/Cons(QueueData/Key(arr.head), QueueData/Key.map(arr.tail))
