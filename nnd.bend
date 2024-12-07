from ./avl import *
from ./map import *
from ./rng import (uniform, uniform_, split, split_2)
from ./util import (select, split_out, unwrap_singleton, zip, l2sq)

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

def build_vk(tree, values, limit, index):
  match values:
    case List/Cons:
      d, key = values.head
      d = AvlData/MinQueue(limit, [QueueData/Dual(d, index)])
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

def split_avl_by_flag(tree):
  match tree:
    case Avl/Leaf:
      return (Avl/Leaf, Avl/Leaf)
    case Avl/Node:
      (l0, l1) = split_avl_by_flag(tree.left)
      (r0, r1) = split_avl_by_flag(tree.right)
      match tree.key:
        case AvlKey/Dual:
          match tree.key.data:
            case AvlData/Inert:
              if tree.key.data.data:
                return (Avl.union(l0, r0), Avl.join(tree.key, l1, r1))
              else:
                return (Avl.join(tree.key, l0, r0), Avl.union(l1, r1))
            case _:
              return *
        case _:
          return *

def build_unwrap(rev, val):
  match rev:
    case Avl/Leaf:
      return *
    case Avl/Node:
      match rev.key:
        case AvlKey/Single:
          if rev.key.key != val:
            return *
          else:
            match rev.key.data:
              case AvlData/MinQueue:
                return (rev.key.data.size, rev.key.data.values)
              case _:
                return *
        case _:
          return *

def build_index(rng, tree):
  match tree:
    case Avl/Leaf:
      return Avl/Leaf
    case Avl/Node:
      rng0, rng1 = split_2(rng)
      others = build_index(rng0, tree.left)
      others = Avl.union(others, build_index(rng1, tree.right))
      d = AvlData/Inert(unwrap_singleton(uniform_(rng, 1)))
      match tree.key:
        case AvlKey/Dual:
          return Avl.insert(others, AvlKey/Single(tree.key.exact, d))
        case _:
          return *

def build_dups(rev, tree):
  match rev:
    case List/Nil:
      return (tree, List/Nil, List/Nil)
    case List/Cons:
      match rev.head:
        case QueueData/Dual:
          k, d = rev.head.key, rev.head.uniq
        case _:
          k, d = rev.head.key, *
      tree, rem0, rem1 = build_dups(rev.tail, tree)
      (tree, v) = Avl.cas(tree, AvlKey/Single(d, AvlData/Nil), k)
      match v:
        case AvlData/Nil:
          return tree, rem0, List/Cons(rev.head, rem1)
        case AvlData/Inert:
          if v.data == k:
            return tree, rem0, rem1
          else:
            return tree, List/Cons(QueueData/Dual(k, d), rem0), rem1
        case _:
          return *

def build_merged(size, tree, lo):
  match tree:
    case Avl/Leaf:
      return lo
    case Avl/Node:
      match tree.key:
        case AvlKey/Single:
          k, d = tree.key.key, tree.key.data
        case _:
          k, d = *, tree.key.data
      match d:
        case AvlData/Inert:
          d = d.data
        case _:
          d = *
      lo = Avl.merge_queue(lo, [QueueData/Dual(d, k)], size)
      return build_merged(size, tree.right, build_merged(size, tree.left, lo))

def build_stripped(arr):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      match arr.head:
        case QueueData/Dual:
          return List/Cons(arr.head.uniq, build_stripped(arr.tail))
        case _:
          return *

def build_backfill(rng, tree, rev0, rev1, index):
  match tree:
    case DirectAccess/Node:
      match rng:
        case DirectAccess/Leaf:
          return *
        case DirectAccess/Node:
          k = AvlKey/Single(tree.index, AvlData/Nil)
          (lo0, lo1) = Avl.split_left_of(rev0, k)
          (hi0, hi1) = Avl.split_left_of(rev1, k)
          l = build_backfill(rng.left, tree.left, lo0, hi0, tree.index - 1)
          r = build_backfill(rng.right, tree.right, lo1, hi1, tree.index)
          (l0, l1), (r0, r1) = l, r
          res0 = DirectAccess/Node(tree.index, l0, r0)
          res1 = DirectAccess/Node(tree.index, l1, r1)
          return res0, res1
    case DirectAccess/Leaf:
      match rng:
        case DirectAccess/Node:
          return *
        case DirectAccess/Leaf:
          (size, d0) = build_unwrap(rev0, index)
          (*, d1) = build_unwrap(rev1, index)
          lo, hi = split_avl_by_flag(tree.value)
          rng0, rng1 = split_2(rng.value)
          lo, hi = build_index(rng0, lo), build_index(rng1, hi)
          (lo, d00, d01) = build_dups(d0, lo)
          (hi, d10, d11) = build_dups(d1, hi)
          d0, d1 = build_merged(size, lo, d00), build_merged(size, hi, d10)
          d0 = Avl.merge_queue(d0, d01, size)
          d1 = Avl.merge_queue(d1, d11, size)
          d0, d1 = build_stripped(d0), build_stripped(d1)
          return DirectAccess/Leaf(d0), DirectAccess/Leaf(d1)

def build(rng, tree, limit):
  rng = split(rng, 3)
  subkey0, rng = split_out(rng)
  subkey1, rng = split_out(rng)
  rng, * = split_out(rng)

  points, tree = DirectAccess.length(tree)
  d = DirectAccess.create(uniform(rng, [points, 2, limit], 0.0, 1.0))
  rng0 = DirectAccess.create(split(subkey0, points))
  rng1 = DirectAccess.create(split(subkey1, points))
  rev0, rev1 = build_(rng0, d, tree, limit, 0)
  return build_backfill(rng1, tree, rev0, rev1, 0)

def apply_dist(arr):
  return l2sq(arr)

def apply_conv(self, others):
  match others:
    case List/Nil:
      return List/Nil
    case List/Cons:
      match others.head:
        case AvlKey/Single:
          match others.head.data:
            case AvlData/Inert:
              out = apply_dist(zip(self, others.head.data.data))
            case _:
              out = *
          out = QueueData/Dual(out, others.head.key)
          return List/Cons(out, apply_conv(self, others.tail))
        case _:
          return *

def apply_cross(k, pre, post):
  match pre:
    case List/Nil:
      return Avl/Leaf()
    case List/Cons:
      rem = apply_cross(k, pre.tail, List/Cons(pre.head, post))
      match pre.head:
        case AvlKey/Single:
          match pre.head.data:
            case AvlData/Inert:
              self = apply_conv(pre.head.data.data, List/concat(pre.tail, post))
            case _:
              self = *
          self = AvlData/MinQueue(k, QueueData.limited_sort(k, self))
          return Avl.insert(rem, AvlKey/Single(pre.head.key, self))
        case _:
          return *

def apply_(k, candidates):
  match candidates:
    case DirectAccess/Node:
      l, r = apply_(k, candidates.left), apply_(k, candidates.right)
      return Avl.union(l, r)
    case DirectAccess/Leaf:
      return apply_cross(k, candidates.value, [])

def apply_merge(k, tree, updates, index):
  # tree: DA of AVLs holding AvlKey/Dual
  # updates: AVL of MinQueues holding QueueData/Dual
  # index: node index that the updates are for
  match tree:
    case DirectAccess/Node:
      pivot = AvlKey/Single(tree.index, AvlData/Nil)
      l, r = Avl.split_left_of(updates, pivot)
      l = apply_merge(k, tree.left, l, tree.index - 1)
      r = apply_merge(k, tree.right, r, tree.index)
      return DirectAccess/Node(tree.index, l, r)
    case DirectAccess/Leaf:
      (size, updates) = build_unwrap(updates, index)
      # set flag
      ins = Avl.from_sorted(AvlKey/Dual.from_q(updates, AvlData/Inert(1)))
      return DirectAccess/Leaf(Avl.prune(Avl.union(tree.value, ins), k))

def apply(k, tree, candidates):
  return apply_merge(k, tree, apply_(k, candidates), 0)

def bipartite_conv(self, others, except):
  match others:
    case List/Nil:
      return List/Nil
    case List/Cons:
      match others.head:
        case AvlKey/Single:
          rem = bipartite_conv(self, others.tail, except)
          if others.head.key == except:
            return rem
          else:
            match others.head.data:
              case AvlData/Inert:
                out = apply_dist(zip(self, others.head.data.data))
              case _:
                out = *
            return List/Cons(QueueData/Dual(out, others.head.key), rem)
        case _:
          return *

def bipartite_cross(k, set0, set1):
  match set0:
    case List/Nil:
      return Avl/Leaf()
    case List/Cons:
      match set0.head:
        case AvlKey/Single:
          rem = bipartite_cross(k, set0.tail, set1)
          match set0.head.data:
            case AvlData/Inert:
              self = bipartite_conv(set0.head.data.data, set1, set0.head.key)
            case _:
              self = *
          self = AvlData/MinQueue(k, QueueData.limited_sort(k, self))
          return Avl.insert(rem, AvlKey/Single(set0.head.key, self))
        case _:
          return *

def bipartite_(k, set0, set1):
  match set0:
    case DirectAccess/Node:
      match set1:
        case DirectAccess/Leaf:
          return Avl/Leaf()
        case DirectAccess/Node:
          l = bipartite_(k, set0.left, set1.left)
          r = bipartite_(k, set0.right, set1.right)
          return Avl.union(l, r)
    case DirectAccess/Leaf:
      match set1:
        case DirectAccess/Node:
          return Avl/Leaf()
        case DirectAccess/Leaf:
          return bipartite_cross(k, set0.value, set1.value)

def bipartite(k, tree, set0, set1):
  return apply_merge(k, tree, bipartite_(k, set0, set1), 0)

def reset_flag_(tree):
  match tree:
    case Avl/Node:
      (l, t0), (r, t1) = reset_flag_(tree.left), reset_flag_(tree.right)
      total = t0 + t1 + AvlData/Inert.unwrap(tree.key, 0)
      self = Avl.merge_key(tree.key, AvlData/Inert(0))
      return Avl/Node(self, tree.height, l, r), total
    case Avl/Leaf:
      return Avl/Leaf(), 0

def reset_flag(tree):
  match tree:
    case DirectAccess/Node:
      (l, t0), (r, t1) = reset_flag(tree.left), reset_flag(tree.right)
      return DirectAccess/Node(tree.index, l, r), t0 + t1
    case DirectAccess/Leaf:
      self, total = reset_flag_(tree.value)
      return DirectAccess/Leaf(self), total
