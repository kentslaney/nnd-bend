from avl import (Avl, Avl.insert, AvlKey, AvlData)
from rng import (split, graph)
from rpt import (forest,)
from nnd import (apply, bipartite, build, reset_flag)
from util import (split_out, min, l2sq, zip)
from map import *

def map_arr_avl(arr, data, n):
  match arr:
    case List/Nil:
      return Avl/Leaf()
    case List/Cons:
      self = DirectAccess.get(data, n)
      d = l2sq(zip(self, DirectAccess.get(data, arr.head)))
      key = AvlKey/Dual(d, arr.head, AvlData/Inert(arr.head % 2))
      return Avl.insert(map_arr_avl(arr.tail, data, n), key)

def map_mat_avl(arr, data, n):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      rem = map_mat_avl(arr.tail, data, n + 1)
      return List/Cons(map_arr_avl(arr.head, data, n), rem)

def mt_(points, index):
  if points == 1:
    return DirectAccess/Leaf(Avl/Leaf())
  else:
    r = mt_((points + 1) / 2, index + points / 2)
    return DirectAccess/Node(index + points / 2, mt_(points / 2, index), r)

def mt(points):
  return mt_(points, 0)

def ann_(rng, data, points, k, candidates, delta, knn):
  match rng:
    case List/Nil:
      return knn
    case List/Cons:
      lo, hi = build(rng.head, knn, k)
      knn, count = reset_flag(knn)
      if count <= delta * k * points:
        return knn
      else:
        knn = apply(k, data, knn, hi)
        knn = bipartite(k, data, knn, lo, hi)
        knn = bipartite(k, data, knn, hi, lo)
        return ann_(rng.tail, data, points, k, candidates, delta, knn)

def ann_retype_(tree):
  match tree:
    case Avl/Leaf:
      return []
    case Avl/Node:
      l, r = ann_retype_(tree.left), ann_retype_(tree.right)
      match tree.key:
        case AvlKey/Dual:
          k = tree.key.exact
        case _:
          k = *
      return List/concat(l, List/Cons(k, r))

def ann_retype(tree):
  match tree:
    case DirectAccess/Node:
      l, r = ann_retype(tree.left), ann_retype(tree.right)
      return DirectAccess/Node(tree.index, l, r)
    case DirectAccess/Leaf:
      return DirectAccess/Leaf(ann_retype_(tree.value))

def ann_custom(rng, data, k, candidates, n_iter, delta, n_trees):
  (points, data) = List/length(data)
  data = DirectAccess.create(data)
  rng, subkeys = split_out(split(rng, n_iter + 1))
  if n_trees == 0:
    knn = map_mat_avl(graph(rng, points, k), data, 0)
  else:
    init = forest(rng, data, n_trees, 30, 0.75)
    knn = apply(k, data, mt(points), DirectAccess.create(init))
  knn = ann_(subkeys, data, points, k, candidates, delta, knn)
  return DirectAccess.to_list(ann_retype(knn))

def ann(rng, data, k):
  (points, data) = List/length(data)
  n_trees = 5 + f24/to_u24(u24/to_f24(points) ** 0.25)
  return ann_custom(rng, data, k, min(k, 64), 10, 0.0001, n_trees)
