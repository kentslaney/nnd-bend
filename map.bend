# TODO: index doesn't need to be stored if the size is stored in a container
# TODO: the Map builtin might mesh with Avl better
type DirectAccess: # < index goes left
  Node { index, ~left, ~right }
  Leaf { value }

def DirectAccess.create_(arr, len, el):
  if len == 1:
    match arr:
      case List/Nil:
        return (DirectAccess/Leaf(List/Nil), List/Nil)
      case List/Cons:
        return (DirectAccess/Leaf(arr.head), arr.tail)
  else:
    (tree0, arr) = DirectAccess.create_(arr, len / 2, el)
    (tree1, arr) = DirectAccess.create_(arr, len / 2 + (len % 2), el + len / 2)
    return (DirectAccess/Node(el + len / 2, tree0, tree1), arr)

def DirectAccess.create(arr):
  (len, arr) = List/length(arr)
  (res, *) = DirectAccess.create_(arr, len, 0)
  return res

def DirectAccess.get(self, el):
  match self:
    case DirectAccess/Node:
      if el < self.index:
        return DirectAccess.get(self.left, el)
      else:
        return DirectAccess.get(self.right, el)
    case DirectAccess/Leaf:
      return self.value

def DirectAccess.length(self):
  match self:
    case DirectAccess/Node:
      (res, *) = DirectAccess.length(self.right)
      if res == 1:
        return self.index + 1, self
      else:
        return res, self
    case DirectAccess/Leaf:
      return 1, self

def DirectAccess.to_list(self):
  match self:
    case DirectAccess/Leaf:
      return [self.value]
    case DirectAccess/Node:
      l = DirectAccess.to_list(self.left)
      r = DirectAccess.to_list(self.right)
      return List/concat(l, r)
