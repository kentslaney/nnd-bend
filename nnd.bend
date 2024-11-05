from ./avl import *
from ./map import *
from ./rng import (uniform, uniform_, split, split_2)
from ./util import (select, split_out, unwrap_singleton, zip)

def split_dual_by_flag(tree):
  match tree:
    case Avl/Leaf:
      return ([], [])
    case Avl/Node:
      (l0, l1) = split_dual_by_flag(tree.left)
      (r0, r1) = split_dual_by_flag(tree.right)
      (lo, hi) = (List/concat(l0, r0), List/concat(l1, r1))
      match tree.key:
        case AvlKey/Dual:
          match tree.key.data:
            case AvlData/Inert:
              if tree.key.data.data:
                return (lo, List/Cons(tree.key.exact, hi))
              else:
                return (List/Cons(tree.key.exact, lo), hi)
            case _:
              return *
        case _:
          return *

def cutoff_mask(args, cutoff):
  match args:
    case List/Nil:
      return List/Nil
    case List/Cons:
      (d, val) = args.head
      if d < cutoff:
        return List/Cons(val, cutoff_mask(args.tail, cutoff))
      else:
        return cutoff_mask(args.tail, cutoff)

def resize(rng, arr, limit):
  (len, arr) = List/length(arr)
  if len > limit:
    d = uniform_(rng, len)
    cutoff = select(d, limit)
    return (limit, cutoff_mask(zip(d, arr), cutoff))
  else:
    return (len, arr)

def build_kv_map(arr):
  match arr:
    case List/Cons:
      (k, v) = arr.head
      return List/Cons(QueueData/Kv(k, v), build_kv_map(arr.tail))
    case List/Nil:
      return List/Nil

def build_vk(tree, values, limit, index):
  match values:
    case List/Cons:
      d, key = values.head
      d = AvlData/MinQueue(limit, [QueueData/Kv(d, index)])
      key = AvlKey/Single(key, d)
      return build_vk(Avl.insert(tree, key), values.tail, limit, index)
    case List/Nil:
      return tree

def build_(rng, d, tree, limit, index):
  match tree:
    case DirectAccess/Node:
      match rng:
        case DirectAccess/Leaf:
          return *
        case DirectAccess/Node:
          match d:
            case DirectAccess/Leaf:
              return *
            case DirectAccess/Node:
              l = build_(rng.left, d.left, tree.left, limit, tree.index - 1)
              r = build_(rng.right, d.right, tree.right, limit, tree.index)
              (l0, l1), (r0, r1) = l, r
              return Avl.union(l0, r0), Avl.union(l1, r1)
    case DirectAccess/Leaf:
      lo, hi = split_dual_by_flag(tree.value)
      match d:
        case DirectAccess/Node:
          return *
        case DirectAccess/Leaf:
          match rng:
            case DirectAccess/Node:
              return *
            case DirectAccess/Leaf:
              d0, d1 = split_out(d.value)
              d1 = unwrap_singleton(d1)
              subkey0, subkey1 = split_2(rng.value)
              (*, lo) = resize(subkey0, lo, limit)
              (*, hi) = resize(subkey1, hi, limit)
              lo, hi = zip(d0, lo), zip(d1, hi)
              t0 = AvlKey/Single(index, AvlData/MinQueue(limit, []))
              t1 = AvlKey/Single(index, AvlData/MinQueue(limit, []))
              t0, t1 = Avl/Leaf.create(t0), Avl/Leaf.create(t1)
              t0 = build_vk(t0, lo, limit, index)
              t1 = build_vk(t1, hi, limit, index)
              return t0, t1

def build(rng, tree, limit):
  rng, subkey = split_2(rng)
  points, tree = DirectAccess.length(tree)
  d = DirectAccess.create(uniform(rng, [points, 2, limit], 0.0, 1.0))
  rng = DirectAccess.create(split(subkey, points))
  return build_(rng, d, tree, limit, 0)
