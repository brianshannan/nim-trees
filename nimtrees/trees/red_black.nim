## Implementation of a Red-Black tree in Nim, based on
## http://staff.ustc.edu.cn/~csli/graduate/algorithms/book6/chap14.htm.
## Recursive iterators aren't allowed in nim, so iterative tree traversals were
## needed, found on wikipedia.
##
## Elements are compared via the `cmp` function, so the `<` and `==` operators
## should be defined for the key type of the tree. Duplicate keys are not
## allowed in the tree.
##
## Red-Black trees are balanced binary search trees with the following worst
## case time complexities for common operations:
## space: O(n)
## insert: O(lg(n))
## remove: O(lg(n))
## find: O(lg(n))
## in-order iteration: O(n)
##
## A sentinel leaf node is used to simplify algorithms without taking up
## too much space.

type
  Color = enum
    red, black
  Node[K, V] = ref object
    parent: Node[K, V]
    left: Node[K, V]
    right: Node[K, V]
    key: K
    value: V
    color: Color
  RedBlackTree*[K, V] = ref object
    ## Object representing a red black tree
    root: Node[K, V]
    leaf: Node[K, V]
    size: int

proc newNode[K, V](tree: RedBlackTree[K, V], parent: Node[K, V], key: K, value: V): Node[K, V] =
  return Node[K, V](parent: parent, left: tree.leaf, right: tree.leaf, key: key, value: value, color: Color.red)

proc newRedBlackTree*[K, V](): RedBlackTree[K, V] =
  ## Construct a new Red-Black binary search tree
  let leaf = Node[K, V](color: Color.black)
  leaf.left = leaf
  leaf.right = leaf
  return RedBlackTree[K, V](leaf: leaf)

proc successor[K, V](tree: RedBlackTree[K, V], node: Node[K, V]): Node[K, V] =
  ## Returns the successor of the given node, of nil if one doesn't exist
  if node.right == nil:
    return nil
  var curr = node.right
  while curr.right != nil:
    curr = curr.right
  return curr

proc rotateLeft[K, V](tree: RedBlackTree[K, V], parent: Node[K, V]) =
  ## Rotates a tree left around the given node
  if parent == nil:
    return
  var right = parent.right
  parent.right = right.left
  if right.left != nil:
    right.left.parent = parent
  right.parent = parent.parent
  if parent.parent == nil:
    tree.root = right
  elif parent.parent.left == parent:
    parent.parent.left = right
  else:
    parent.parent.right = right
  right.left = parent
  parent.parent = right

proc rotateRight[K, V](tree: RedBlackTree[K, V], parent: Node[K, V]) =
  ## Rotates a tree right around the given node
  if parent == nil:
    return
  var left = parent.left
  parent.left = left.right
  if left.right != nil:
    left.right.parent = parent
  left.parent = parent.parent
  if parent.parent == nil:
    tree.root = left
  elif parent.parent.right == parent:
    parent.parent.right = left
  else:
    parent.parent.left = left
  left.right = parent
  parent.parent = left

proc findNode[K, V](tree: RedBlackTree[K, V], key: K): Node[K, V] =
  ## Finds a node with the given key, or nil if it doesn't exist
  var curr = tree.root
  while curr != tree.leaf:
    let comp = cmp(key, curr.key)
    if comp == 0:
      return curr
    elif comp < 0:
      curr = curr.left
    else:
      curr = curr.right
  return nil

proc fixInsert[K, V](tree: RedBlackTree[K, V], node: Node[K, V]) =
  ## Rebalances a tree after an insertion
  var curr = node
  while curr != tree.root and curr.parent.color == Color.red:
    if curr.parent.parent != nil and curr.parent == curr.parent.parent.left:
      var uncle = curr.parent.parent.right
      if uncle.color == Color.red:
        curr.parent.color = Color.black
        uncle.color = Color.black
        curr.parent.parent.color = Color.red
        curr = curr.parent.parent
      else:
        if curr == curr.parent.right:
          curr = curr.parent
          tree.rotateLeft(curr)
        curr.parent.color = Color.black
        if curr.parent.parent != nil:
          curr.parent.parent.color = Color.red
          tree.rotateRight(curr.parent.parent)
    elif curr.parent.parent != nil:
      var uncle = curr.parent.parent.left
      if uncle.color == Color.red:
        curr.parent.color = Color.black
        uncle.color = Color.black
        curr.parent.parent.color = Color.red
        curr = curr.parent.parent
      else:
        if curr == curr.parent.left:
          curr = curr.parent
          tree.rotateRight(curr)
        curr.parent.color = Color.black
        if curr.parent.parent != nil:
          curr.parent.parent.color = Color.red
          tree.rotateLeft(curr.parent.parent)
  tree.root.color = Color.black

proc insert*[K, V](tree: RedBlackTree[K, V], key: K, value: V): bool {.discardable.} =
  ## Insert a key value pair into the tree. Returns true if the key didn't
  ## already exist in the tree. If the key already existed, the old value
  ## is updated and false is returned.
  # If the tree root is nil, there are no entries, put it at the root
  if tree.root == nil:
    tree.root = newNode[K, V](tree, nil, key, value)
    tree.size += 1
    tree.fixInsert(tree.root)
    return true

  # Otherwise find the insertion point
  var curr = tree.root
  while curr != tree.leaf:
    let comp = cmp(key, curr.key)
    if comp == 0:
      # If it's already there, set the data and return
      curr.value = value
      return false
    elif comp < 0:
      # Goes to the left
      if curr.left == tree.leaf:
        # Nothing there, insert here
        curr.left = newNode[K, V](tree, curr, key, value)
        tree.size += 1
        tree.fixInsert(curr.left)
        return true
      curr = curr.left
    else:
      # Goes to the right
      if curr.right == tree.leaf:
        # Nothing there, insert here
        curr.right = newNode[K, V](tree, curr, key, value)
        tree.size += 1
        tree.fixInsert(curr.right)
        return true
      curr = curr.right
  return false

proc find*[K, V](tree: RedBlackTree[K, V], key: K): (V, bool) =
  ## Find the value associated with a given key. Returns the value and true
  ## if the key was found, and a default value and false if not.
  let node = tree.findNode(key)
  if node != nil:
    return (node.value, true)
  var default: V
  return (default, false)

proc fixRemove[K, V](tree: RedBlackTree[K, V], node: Node[K, V]) =
  ## Rebalaces a tree after a removal
  var curr = node
  while curr != tree.root and curr.color == Color.black:
    if curr == curr.parent.left:
      var sib = curr.parent.right
      if sib.color == Color.red:
        sib.color = Color.black
        curr.parent.color = Color.red
        tree.rotateLeft(curr.parent)
        sib = curr.parent.right

      if sib.left.color == Color.black and sib.right.color == Color.black:
        sib.color = Color.red
        curr = curr.parent
      else:
        if sib.right.color == Color.black:
          sib.left.color = Color.black
          sib.color = Color.red
          tree.rotateRight(sib)
          sib = curr.parent.right
        sib.color = curr.parent.color
        curr.parent.color = Color.black
        sib.right.color = Color.black
        tree.rotateLeft(curr.parent)
        curr = tree.root
    else:
      var sib = curr.parent.left
      if sib.color == Color.red:
        sib.color = Color.black
        curr.parent.color = Color.red
        tree.rotateRight(curr.parent)
        sib = curr.parent.left

      if sib.right.color == Color.black and sib.left.color == Color.black:
        sib.color = Color.red
        curr = curr.parent
      else:
        if sib.left.color == Color.black:
          sib.right.color = Color.black
          sib.color = Color.red
          tree.rotateLeft(sib)
          sib = curr.parent.left
        sib.color = curr.parent.color
        curr.parent.color = Color.black
        sib.left.color = Color.black
        tree.rotateRight(curr.parent)
        curr = tree.root
  curr.color = Color.black


proc remove*[K, V](tree: RedBlackTree[K, V], key: K): bool {.discardable.} =
  ## Remove a key value pair from the tree. Returns true if something was
  ## removed, false if the key wasn't found, so nothing was removed.
  var node = tree.findNode(key)
  if node == nil:
    return false

  tree.size -= 1
  # Reduce the problem to removing a node with at most one child
  if node.left != tree.leaf and node.right != tree.leaf:
    # Internal node, the successor's data can be placed here without violating
    # bst properties. No we need to delete the successor
    let succ = tree.successor(node)
    node.key = succ.key
    node.value = succ.value
    node = succ

  # Get a non leaf child, if there is one and fix pointers
  let child = if node.left != tree.leaf: node.left else: node.right
  child.parent = node.parent
  if node.parent == nil:
    tree.root = child
  elif node == node.parent.left:
    node.parent.left = child
  else:
    node.parent.right = child
  # We only need to fix the red-black ness of the tree if the removed node
  # was black, as removing a red node doesn't violate the same length
  # black path property
  if node.color == Color.black:
    tree.fixRemove(child)
  return true

proc len*[K, V](tree: RedBlackTree[K, V]): int =
  ## Returns the number of items the in tree
  return tree.size

iterator iterOrder*[K, V](tree: RedBlackTree[K, V]): (K, V) =
  ## Iterates over the elements of the tree in order.
  var node = tree.root
  var stack: seq[Node[K, V]] = @[]
  while stack.len() != 0 or node != tree.leaf:
    if node != tree.leaf:
      stack.add(node)
      node = node.left
    else:
      node = stack.pop()
      yield (node.key, node.value)
      node = node.right


when defined(TESTING):
  import unittest

  proc checkTree(tree: RedBlackTree[int, char]) =
    check(tree.len() == 3)
    check(tree.find(10) == ('c', true))
    check(tree.find(5) == ('b', true))
    check(tree.find(1) == ('a', true))
    check(tree.find(2) == ('\0', false))

    check(tree.root.key == 5)
    check(tree.root.right.key == 10)
    check(tree.root.left.key == 1)

  suite("red black tree"):
    test("red black initialization"):
      check(newRedBlackTree[int, char]() != nil)

    test("red black simple insert"):
      let tree = newRedBlackTree[int, char]()
      check(tree.insert(5, 'b'))
      check(tree.insert(10, 'c'))
      check(not tree.insert(5, 'd'))
      check(tree.len() == 2)
      check(tree.find(5) == ('d', true))
      check(tree.find(10) == ('c', true))
      check(tree.find(15) == ('\0', false))

    test("red black insert balanced"):
      let tree = newRedBlackTree[int, char]()
      check(tree.insert(5, 'b'))
      check(tree.insert(1, 'a'))
      check(tree.insert(10, 'c'))
      checkTree(tree)

    test("red black insert right leaning"):
      let tree = newRedBlackTree[int, char]()
      check(tree.insert(1, 'a'))
      check(tree.insert(5, 'b'))
      check(tree.insert(10, 'c'))
      checkTree(tree)

    test("red black insert right leaning double rotation"):
      let tree = newRedBlackTree[int, char]()
      check(tree.insert(1, 'a'))
      check(tree.insert(10, 'c'))
      check(tree.insert(5, 'b'))
      checkTree(tree)

    test("red black insert left leaning"):
      let tree = newRedBlackTree[int, char]()
      check(tree.insert(10, 'c'))
      check(tree.insert(5, 'b'))
      check(tree.insert(1, 'a'))
      checkTree(tree)

    test("red black insert left leaning double rotation"):
      let tree = newRedBlackTree[int, char]()
      check(tree.insert(10, 'c'))
      check(tree.insert(1, 'a'))
      check(tree.insert(5, 'b'))
      checkTree(tree)

    test("red black inorder"):
      let tree = newRedBlackTree[int, char]()
      for i in 1..10:
        tree.insert(i, 'a')
      var i = 1
      for key, value in tree.iterOrder():
        check(i == key)
        i += 1
      check(i == 11)

    test("red black remove simple"):
      let tree = newRedBlackTree[int, char]()
      tree.insert(10, 'a')
      tree.insert(15, 'b')
      tree.insert(20, 'c')

      tree.remove(20)
      check(tree.len() == 2)
      check(tree.find(10) == ('a', true))
      check(tree.find(15) == ('b', true))
      check(tree.find(20) == ('\0', false))

      tree.remove(15)
      check(tree.len() == 1)
      check(tree.find(10) == ('a', true))
      check(tree.find(15) == ('\0', false))
      check(tree.find(20) == ('\0', false))

      tree.remove(10)
      check(tree.len() == 0)
      check(tree.find(10) == ('\0', false))
      check(tree.find(15) == ('\0', false))
      check(tree.find(20) == ('\0', false))

    test("red black remove rotation"):
      let tree = newRedBlackTree[int, char]()
      tree.insert(1, 'a')
      tree.insert(5, 'b')
      tree.insert(10, 'c')
      tree.insert(15, 'd')
      tree.insert(20, 'e')

      tree.remove(1)
      check(tree.len() == 4)
      check(tree.find(1) == ('\0', false))
      check(tree.find(5) == ('b', true))
      check(tree.find(10) == ('c', true))
      check(tree.find(15) == ('d', true))
      check(tree.find(20) == ('e', true))

    test("red black remove double rotation"):
      let tree = newRedBlackTree[int, char]()
      tree.insert(5, 'b')
      tree.insert(1, 'a')
      tree.insert(10, 'c')
      tree.insert(15, 'd')

      tree.remove(1)
      check(tree.len() == 3)
      check(tree.find(1) == ('\0', false))
      check(tree.find(5) == ('b', true))
      check(tree.find(10) == ('c', true))
      check(tree.find(15) == ('d', true))

    test("red black remove non leaf"):
      let tree = newRedBlackTree[int, char]()
      tree.insert(5, 'b')
      tree.insert(1, 'a')
      tree.insert(10, 'c')
      tree.insert(15, 'd')

      tree.remove(10)
      check(tree.len() == 3)
      check(tree.find(1) == ('a', true))
      check(tree.find(5) == ('b', true))
      check(tree.find(10) == ('\0', false))
      check(tree.find(15) == ('d', true))

    test("red black remove nonexistant"):
      let tree = newRedBlackTree[int, char]()
      tree.insert(1, 'a')
      tree.insert(5, 'b')
      check(tree.len() == 2)
      tree.remove(10)
      check(tree.len() == 2)
