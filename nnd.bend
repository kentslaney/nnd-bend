from ./avl import *
from ./rng import (uniform_,)
from ./utils import (select, split_after)

def split_by_flag(tree):
  match tree:
    case Avl/Leaf:
      return ([], [])
    case Avl/Node:
      (l0, l1) = split_by_flag(tree.left)
      (r0, r1) = split_by_flag(tree.right)
      (lo, hi) = (List/concat(l0, r0), List/concat(l1, r1))
      if tree.key.flag:
        return (lo, List/concat(hi, tree.key.exact))
      else:
        return (List/concat(lo, tree.key.exact), hi)

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
    d = uniform_(rng, total)
    cutoff = select(d, limit)
    return (limit, cutoff_mask(zip(d, arr), cutoff))
  elif len < limit:
    return (len, List/concat(arr, repeat(-1, limit - len)))
  else:
    return (len, arr)

def build(rng, tree, limit):
  return *
