from ./avl import *
from ./map import *

def drt_leaf(arr, index):
  match arr:
    case List/Cons:
      value = AvlKey/Double(arr.head, index, AvlData/Nil)
      return Avl.insert(drt_leaf(arr.tail, index), value)
    case List/Nil:
      return Avl/Leaf

def drt_merge(tree, index):
  match tree:
    case DirectAccess/Node:
      l = drt_merge(tree.left, tree.index - 1)
      r = drt_merge(tree.right, tree.index)
      return Avl.union(l, r)
    case DirectAccess/Leaf:
      return drt_leaf(tree.value, index)

def drt_direct(tree, data):
  match tree:
    case Avl/Leaf:
      return Avl/Leaf
    case Avl/Node:
      rem = Avl.union(drt_direct(tree.left, data), drt_direct(tree.right, data))
      match tree.key:
        case AvlKey/Double:
          res = AvlKey/Double(tree.key.key1, tree.key.key0, AvlData/Inert(data))
        case _:
          res = *
      return Avl.insert(rem, res)

def drt_fetch(tree, data):
  match data:
    case DirectAccess/Node:
      pivot = AvlKey/Double(data.index, 0, AvlData/Nil)
      l, r = Avl.split_left_of(tree, pivot)
      return Avl.union(drt_fetch(l, data.left), drt_fetch(r, data.right))
    case DirectAccess/Leaf:
      return drt_direct(tree, data.value)

def drt_format(tree):
  match tree:
    case Avl/Leaf:
      return []
    case Avl/Node:
      match tree.key:
        case AvlKey/Double:
          res = AvlKey/Single(tree.key.key1, tree.key.data)
        case _:
          res = *
      rem = List/Cons(res, drt_format(tree.right))
      return List/concat(drt_format(tree.left), rem)

def drt_split(tree, lo, hi):
  if lo >= hi - 1:
    return DirectAccess/Leaf(drt_format(tree))
  else:
    mid = (lo + hi) / 2
    pivot = AvlKey/Double(mid, 0, AvlData/Nil)
    l, r = Avl.split_left_of(tree, pivot)
    l, r = drt_split(l, lo, mid), drt_split(r, mid, hi)
    return DirectAccess/Node(mid, l, r)

def drt(tree, data):
  (points, tree) = DirectAccess.length(tree)
  return drt_split(drt_fetch(drt_merge(tree, 0), data), 0, points)
