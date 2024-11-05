from ./avl import *
from ./map import *
from ./rng import (uniform, uniform_, split, split_2)
from ./util import (select, split_out, unwrap_singleton, zip)

def split_dual_by_flag(tree):
  match tree:
    case Avl/Leaf:
      return ([], [])
    case Avl/Node:
      match tree.key:
        case AvlKey/Dual:
          (l0, l1) = split_dual_by_flag(tree.left)
          (r0, r1) = split_dual_by_flag(tree.right)
          (lo, hi) = (List/concat(l0, r0), List/concat(l1, r1))
          if tree.key.data:
            return (lo, List/concat(hi, tree.key.exact))
          else:
            return (List/concat(lo, tree.key.exact), hi)
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
      return build_vk(Avl.insert(tree, key), values.tail, index, limit)
    case List/Nil:
      return List/Nil

def build_(rng, d, tree, limit, index):
  match tree:
    case DirectAccess/Node:
      match rng:
        case DirectAccess/Node:
          match d:
            case DirectAccess/Node:
              l = build_(rng.left, d.left, tree.left, limit, tree.index - 1)
              r = build_(rng.right, d.right, tree.right, limit, tree.index)
              (l0, l1), (r0, r1) = l, r
              return Avl.merge(l0, r0), Avl.merge(l1, r1)
            case _:
              return *
        case _:
          return *
    case DirectAccess/Leaf:
      lo, hi = split_dual_by_flag(tree.value)
      d0, d1 = split_out(unwrap_singleton(d))
      d1 = unwrap_singleton(d1)
      subkey0, subkey1 = split_2(rng)
      (*, lo), (*, hi) = resize(subkey0, lo, limit), resize(subkey1, hi, limit)
      lo, hi = zip(d0, lo), zip(d1, hi)
      t0, t1 = build_kv_map(lo), build_kv_map(hi)
      t0 = Avl/Leaf.create(AvlKey/Single(index, AvlData/MinQueue(limit, t0)))
      t1 = Avl/Leaf.create(AvlKey/Single(index, AvlData/MinQueue(limit, t1)))
      return build_vk(t0, lo, limit, index), build_vk(t1, hi, limit, index)

def build(rng, tree, limit):
  rng, subkey = split_2(rng)
  points = DirectAccess.length(tree)
  d = DirectAccess.create(uniform(rng, [points, 2, limit], 0.0, 1.0))
  rng = DirectAccess.create(split(subkey, points))
  return build_(rng, d, tree, limit, 0)
