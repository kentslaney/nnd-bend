from ./util import (max_order)

object Candidate { distance, index, flag }

type Heap:
  Nil { ~left, ~right }
  Node { value, ~left, ~right }
  Leaf

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

def main:
  return Heap.sift_down(Heap.replace(Heap.create(6), Candidate(1.0, 1, 1)))
