from ./map import *
from ./rng import (choice,)
from ./util import (max_order, range, zip)

object Candidate { distance, index, flag }

type Heap:
  Nil { ~left, ~right }
  Node { value, ~left, ~right }
  Leaf

object Heaps { data, points, k, dist }

def Heap.create(n):
  if n == 0:
    return Heap/Leaf
  else:
    hi = 1 << max_order(n)
    return Heap/Nil(Heap.create(hi - 1), Heap.create(n - hi))

def Heap.replace(self, i):
  match self:
    case Heap/Leaf:
      return self
    case _:
      return Heap/Node(i, self.left, self.right)

def Heap.sift_down(self):
  match self:
    case Heap/Node:
      (l, r) = (self.left, self.right)
      match l:
        case Heap/Nil:
          nxt = Heap.sift_down(Heap/Node(self.value, l.left, l.right))
          return Heap/Nil(nxt, r)
        case Heap/Node:
          match r:
            case Heap/Nil:
              nxt = Heap.sift_down(Heap/Node(self.value, r.left, r.right))
              return Heap/Nil(l, nxt)
            case Heap/Node:
              open Candidate: l.value
              open Candidate: r.value
              open Candidate: self.value
              if l.value.distance < r.value.distance:
                if self.value.distance < r.value.distance:
                  nxt = Heap.sift_down(Heap/Node(self.value, r.left, r.right))
                  return Heap/Node(r.value, l, nxt)
                else:
                  return self
              else:
                if self.value.distance < l.value.distance:
                  nxt = Heap.sift_down(Heap/Node(self.value, l.left, l.right))
                  return Heap/Node(l.value, nxt, r)
                else:
                  return self
            case Heap/Leaf:
              open Candidate: l.value
              open Candidate: self.value
              if self.value.distance < l.value.distance:
                nxt = Heap.sift_down(Heap/Node(self.value, l.left, l.right))
                return Heap/Node(l.value, nxt, r)
              else:
                return self
        case Heap/Leaf:
          return self
    case _:
      return self

def Heap.check(self, i):
  match self:
    case Heap/Node:
      open Candidate: i
      open Candidate: self.value
      if (i.distance == self.value.distance) & (i.index == self.value.index):
        return 1
      else:
        return Heap.check(self.left) | Heap.check(self.right)
    case Heap/Nil:
      return Heap.check(self.left) | Heap.check(self.right)
    case Heap/Leaf:
      return 0

def euclidean_(a, b):
  match a:
    case List/Nil:
      return 0.0
    case List/Cons:
      match b:
        case List/Nil:
          return 0.0
        case List/Cons:
          return (a.head - b.head) ** 2.0 + euclidean_(a.tail, b.tail)

def euclidean(a, b):
  return Math/sqrt(euclidean_(a, b))

def Heaps.create_(points, k):
  if points == 0:
    return List/Nil
  else:
    rem = Heaps.create_(points - 1, k)
    return List/Cons(Heap.create(k), rem)

def Heaps.create(points, k):
  res = Heaps.create_(points, k)
  return Heaps(res, points, k, euclidean)

def Heaps.randomize_offset(data, n):
  match data:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      match data.head:
        case List/Nil:
          (res, rem) = Heaps.randomize_offset(data.tail, n + 1)
          match res:
            case List/Nil:
              return (List/Nil, rem)
            case List/Cons:
              return (List/Nil, List/Cons(res, rem))
        case List/Cons:
          rem = List/Cons(data.head.tail, data.tail)
          (res, rem) = Heaps.randomize_offset(rem, n)
          if data.head.head >= n:
            off = data.head.head + 1
          else:
            off = data.head.head
          return (List/Cons(off, res), rem)

def Heap.candidate(data, i, j, dist):
  d = dist(DirectAccess.get(data, i), DirectAccess.get(data, j))
  return Candidate(d, j, 1)

def Heaps.randomize_(heaps, candidates, data, n, dist):
  match candidates:
    case List/Nil:
      return List/Nil
    case List/Cons:
      match heaps:
        case List/Nil:
          return List/Nil
        case List/Cons:
          match candidates.head:
            case List/Nil:
              rem = candidates.tail
              rem = Heaps.randomize_(heaps.tail, rem, data, n + 1, dist)
              return List/Cons(heaps.head, rem)
            case List/Cons:
              res = Heap.candidate(data, n, candidates.head.head, dist)
              res = Heap.sift_down(Heap.replace(heaps.head, res))
              res = List/Cons(res, heaps.tail)
              rem = List/Cons(candidates.head.tail, candidates.tail)
              return Heaps.randomize_(res, rem, data, n, dist)

def Heaps.randomize(rng, data, k):
  (points, data) = DirectAccess.length(data)
  samples = choice(rng, points - 1, k, points)
  (res, rem) = Heaps.randomize_offset(samples, 0)
  samples = List/Cons(res, rem)
  res = Heaps.create(points, k)
  open Heaps: res
  out = Heaps.randomize_(res.data, samples, data, 0, res.dist)
  return Heaps(out, points, k, res.dist)
