## Implementation of an AVL tree in Nim, based on
## https://en.wikipedia.org/wiki/Splay_tree.
## Recursive iterators aren't allowed in nim, so iterative tree traversals were
## needed, found on wikipedia as well.
##
## Elements are compared via the `cmp` function, so the `<` and `==` operators
## should be defined for the key type of the tree. Duplicate keys are not
## allowed in the tree.
##
## Splay trees are binary search trees that don't apply balance operations
## on each insert/remove, and as such are unbalanced and don't provide a
## O(lg(n)) worst case insert/remove. Instead, splay trees rotate newly added
## and searched for data to the top of the tree so commonly accessed data and
## newly inserted items are very fast to find, as you don't have to go through
## a large part of the tree to find them. Splay tree double rotations are
## slightly different than normal double tree rotations, so data ascends the
## tree quickly, but descends much slower. This is good enough to offer
## amortized lg(n) time for insert, remove and find.

type
  Node[K, V] = ref object
    parent: Node[K, V]
    left: Node[K, V]
    right: Node[K, V]
    key: K
    value: V
  SplayTree*[K, V] = ref object
    root: Node[K, V]
    size: int

proc newNode[K, V](parent: Node[K, V], key: K, value: V): Node[K, V] =
  return Node[K, V](parent: parent, key: key, value: value)

proc newSplayTree*[K, V](): SplayTree[K, V] =
  ## Returns a new AVL tree
  return SplayTree[K, V]()

proc successor[K, V](tree: SplayTree[K, V], node: Node[K, V]): Node[K, V] =
  ## Returns the successor of the given node, of nil if one doesn't exist
  if node.right == nil:
    return nil
  var curr = node.right
  while curr.right != nil:
    curr = curr.right
  return curr

proc rotateLeft[K, V](tree: SplayTree[K, V], parent: Node[K, V]) =
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

proc rotateRight[K, V](tree: SplayTree[K, V], parent: Node[K, V]) =
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

proc splay[K, V](tree: SplayTree[K, V], node: Node[K, V]) =
  while node.parent != nil:
    # While it's not the root, keep going
    if node.parent.parent == nil:
      # One level away from root
      if node == node.parent.left:
        tree.rotateRight(node.parent)
      else:
        tree.rotateLeft(node.parent)
    # zig-zig cases. Doing these this way provides a much better tree structure
    # than simple single rotations performed independtly in a loop
    elif node == node.parent.left and node.parent == node.parent.parent.left:
      tree.rotateRight(node.parent.parent)
      tree.rotateRight(node.parent)
    elif node == node.parent.right and node.parent == node.parent.parent.right:
      tree.rotateLeft(node.parent.parent)
      tree.rotateLeft(node.parent)
    # zig-zag cases
    elif node == node.parent.right and node.parent == node.parent.parent.left:
      tree.rotateLeft(node.parent)
      tree.rotateRight(node.parent)
    else:
      tree.rotateRight(node.parent)
      tree.rotateLeft(node.parent)

proc findNode[K, V](tree: SplayTree[K, V], key: K): (Node[K, V], Node[K, V]) =
  ## Finds a node with the given key and it's parent, or nil if it doesn't exist
  var parent: Node[K, V] = nil
  var curr = tree.root
  while curr != nil:
    let comp = cmp(key, curr.key)
    if comp == 0:
      return (parent, curr)
    elif comp < 0:
      parent = curr
      curr = curr.left
    else:
      parent = curr
      curr = curr.right
  return (parent, nil)

proc find*[K, V](tree: SplayTree[K, V], key: K): (V, bool) =
  var default: V
  if tree.root == nil:
    return (default, false)

  let (parent, child) = tree.findNode(key)
  if child != nil:
    # Found it, splay it
    tree.splay(child)
    return (child.value, true)
  else:
    # Didn't find the key, splay the last node we found
    if parent != nil:
      tree.splay(parent)
    return (default, false)

proc insert*[K, V](tree: SplayTree[K, V], key: K, value: V): bool {.discardable} =
  if tree.root == nil:
    tree.root = newNode[K, V](nil, key, value)
    tree.size += 1
    return true

  var curr = tree.root
  while curr != nil:
    let comp = cmp(key, curr.key)
    if comp == 0:
      # If it's already there, set the data, splay,  and return
      curr.value = value
      tree.splay(curr)
      return false
    elif comp < 0:
      # Go to the left
      if curr.left == nil:
        # It's not there, insert and fix tree
        curr.left = newNode[K, V](curr, key, value)
        tree.size += 1
        tree.splay(curr.left)
        return true
      curr = curr.left
    else:
      # Go to the right
      if curr.right == nil:
        # It's not there, insert and fix tree
        curr.right = newNode[K, V](curr, key, value)
        tree.size += 1
        tree.splay(curr.right)
        return true
      curr = curr.right

proc remove*[K, V](tree: SplayTree[K, V], key: K): bool {.discardable.} =
  ## Remove a key value pair from the tree. Returns true if something was
  ## removed, false if the key wasn't found, so nothing was removed.
  var (parent, node) = tree.findNode(key)
  # If a node with that data doesn't exist, nothing to do
  if node == nil:
    return false
  if parent != nil:
    tree.splay(parent)

  tree.size -= 1
  if node.left != nil and node.right != nil:
    # Internal node, the successor's data can be placed here without violating
    # bst properties. Now we need to delete the successor.
    let succ = tree.successor(node)
    node.key = succ.key
    node.value = succ.value
    node = succ

  # Now the node we are trying to delete has at most one child
  let child = if node.left != nil: node.left else: node.right
  if child != nil:
    # Set parent if it exists
    child.parent = node.parent
  if node.parent == nil:
    # Node was the root, reset it
    tree.root = child
  # If the parent exists, we need to set the child appropriately
  elif node == node.parent.left:
    node.parent.left = child
  else:
    node.parent.right = child

  return true

proc len*[K, V](tree: SplayTree[K, V]): int =
  ## Returns the number of items the in tree
  return tree.size

iterator inOrderTraversal*[K, V](tree: SplayTree[K, V]): (K, V) =
  ## Iterates over the elements of the tree in order.
  var node = tree.root
  var stack: seq[Node[K, V]] = @[]
  while stack.len() != 0 or node != nil:
    if node != nil:
      stack.add(node)
      node = node.left
    else:
      node = stack.pop()
      yield (node.key, node.value)
      node = node.right


when defined(TESTING):
  import unittest

  suite("splay tree"):
    test("splay initialization"):
      check(newSplayTree[int, char]() != nil)

    test("splay insert"):
      let tree = newSplayTree[int, char]()
      check(tree.insert(1, 'a'))
      check(tree.insert(10, 'c'))
      check(tree.root.key == 10 and tree.root.value == 'c')
      check(tree.root.left.key == 1 and tree.root.left.value == 'a')
      check(tree.insert(5, 'b'))
      check(tree.root.key == 5 and tree.root.value == 'b')
      check(tree.root.left.key == 1 and tree.root.left.value == 'a')
      check(tree.root.right.key == 10 and tree.root.right.value == 'c')
      check(not tree.insert(1, 'd'))
      check(tree.root.key == 1 and tree.root.value == 'd')
      check(tree.len() == 3)

    test("splay find"):
      let tree = newSplayTree[int, char]()
      check(tree.insert(1, 'a'))
      check(tree.insert(10, 'c'))
      check(tree.insert(5, 'b'))
      check(tree.insert(20, 'e'))
      check(tree.find(5) == ('b', true))
      check(tree.root.key == 5 and tree.root.value == 'b')
      check(tree.find(20) == ('e', true))
      check(tree.root.key == 20 and tree.root.value == 'e')
      check(tree.find(1) == ('a', true))
      check(tree.root.key == 1 and tree.root.value == 'a')
      check(tree.find(10) == ('c', true))
      check(tree.root.key == 10 and tree.root.value == 'c')
      check(tree.find(7) == ('\0', false))
      check(tree.root.key == 5 and tree.root.value == 'b')
      check(tree.len() == 4)

    test("splay remove"):
      let tree = newSplayTree[int, char]()
      check(tree.insert(1, 'a'))
      check(tree.insert(5, 'b'))
      check(tree.insert(15, 'd'))
      check(tree.insert(10, 'c'))
      check(tree.remove(10))
      check(tree.root.key == 15 and tree.root.value == 'd')
      check(tree.len() == 3)
      check(tree.insert(-5, 'z'))
      check(tree.remove(1))
      check(tree.root.key == 15 and tree.root.value == 'd')
      check(tree.len() == 3)
      check(tree.find(-5) == ('z', true))
      check(tree.find(5) == ('b', true))
      check(tree.find(15) == ('d', true))

    test("splay inorder"):
      let tree = newSplayTree[int, char]()
      for i in 1..10:
        tree.insert(i, 'a')
      var i = 1
      for key, value in tree.inOrderTraversal():
        check(i == key)
        i += 1
      check(i == 11)
