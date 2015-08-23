## Implementation of an AVL tree in Nim, based on
## https://en.wikipedia.org/wiki/AVL_tree.
## Recursive iterators aren't allowed in nim, so iterative tree traversals were
## needed, found on wikipedia as well.
##
## Elements are compared via the `cmp` function, so the `<` and `==` operators
## should be defined for the key type of the tree. Duplicate keys are not
## allowed in the tree.
##
## AVL trees are balanced binary search trees with the following worst case time
## complexities for common operations:
## space: O(n)
## insert: O(lg(n))
## remove: O(lg(n))
## find: O(lg(n))
## in-order iteration: O(n)

type
  Node[K, V] = ref object
    parent: Node[K, V]
    left: Node[K, V]
    right: Node[K, V]
    key: K
    value: V
    balance: int
  AVLTree*[K, V] = ref object
    ## Object representing an AVL tree
    root: Node[K, V]
    size: int

proc newNode[K, V](parent: Node[K, V], key: K, value: V): Node[K, V] =
  return Node[K, V](parent: parent, key: key, value: value)

proc newAVLTree*[K, V](): AVLTree[K, V] =
  ## Returns a new AVL tree
  return AVLTree[K, V]()

proc successor[K, V](tree: AVLTree[K, V], node: Node[K, V]): Node[K, V] =
  ## Returns the successor of the given node, of nil if one doesn't exist
  if node.right == nil:
    return nil
  var curr = node.right
  while curr.right != nil:
    curr = curr.right
  return curr

proc rotateLeft[K, V](tree: AVLTree[K, V], parent: Node[K, V]) =
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

proc rotateRight[K, V](tree: AVLTree[K, V], parent: Node[K, V]) =
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

proc findNode[K, V](tree: AVLTree[K, V], key: K): Node[K, V] =
  ## Finds a node with the given key, or nil if it doesn't exist
  var curr = tree.root
  while curr != nil:
    let comp = cmp(key, curr.key)
    if comp == 0:
      return curr
    elif comp < 0:
      curr = curr.left
    else:
      curr = curr.right
  return nil

proc fixInsert[K, V](tree: AVLTree[K, V], node: Node[K, V]) =
  ## Rebalances a tree after an insertion
  var curr = node
  var parent = curr.parent
  while parent != nil:
    # Worst case scenario we have to go to the root
    if curr == parent.left:
      # Left child, deal with those rotations
      if parent.balance == 1:
        # Old balance factor was 1, and we increased the height of the left
        # subtree, so now it's 2, rebalance needed
        if curr.balance == -1:
          # left right case, reduce to left left case
          tree.rotateLeft(curr)
        # Has to be left left case now
        tree.rotateRight(parent)
        return
      elif parent.balance == -1:
        # Increasing the height of the left subtree balanced this
        parent.balance = 0
        return
      # The old balance has to be 0 at this point, tree could need rebalancing
      # farther up
      parent.balance = 1
    else:
      # Right child, mirror of above case
      if parent.balance == -1:
        # Old balance factor was -1, and we increased the height of the right
        # subtree, so now it's -2, rebalance needed
        if curr.balance == 1:
          # right left case, reduce to right right case
          tree.rotateRight(curr)
        # Has to be right right case now
        tree.rotateLeft(parent)
        return
      elif parent.balance == 1:
        # Increasing the height of the right subtree balanced this
        parent.balance = 0
        return
      # The old balance has to be 0 at this point, tree could need rebalancing
      # farther up
      parent.balance = -1
    curr = parent
    parent = curr.parent

proc insert*[K, V](tree: AVLTree[K, V], key: K, value: V): bool {.discardable.} =
  ## Insert a key value pair into the tree. Returns true if the key didn't
  ## already exist in the tree. If the key already existed, the old value
  ## is updated and false is returned.
  if tree.root == nil:
    tree.root = newNode[K, V](nil, key, value)
    tree.size += 1
    return true

  var curr = tree.root
  while curr != nil:
    let comp = cmp(key, curr.key)
    if comp == 0:
      # If it's already there, set the data and return
      curr.value = value
      return false
    elif comp < 0:
      # Go to the left
      if curr.left == nil:
        # It's not there, insert and fix tree
        curr.left = newNode[K, V](curr, key, value)
        tree.size += 1
        tree.fixInsert(curr.left)
        return true
      curr = curr.left
    else:
      # Go to the right
      if curr.right == nil:
        # It's not there, insert and fix tree
        curr.right = newNode[K, V](curr, key, value)
        tree.size += 1
        tree.fixInsert(curr.right)
        return true
      curr = curr.right
  return false

proc find*[K, V](tree: AVLTree[K, V], key: K): (V, bool) =
  ## Find the value associated with a given key. Returns the value and true
  ## if the key was found, and a default value and false if not.
  let node = tree.findNode(key)
  if node != nil:
    return (node.value, true)
  var default: V
  return (default, false)

proc fixRemove[K, V](tree: AVLTree[K, V], node: Node[K, V]) =
  ## Rebalaces a tree after a removal
  if node == nil:
    return
  var curr = node
  var parent = node.parent
  while parent != nil:
    # Worst case scenario we have to go to the root
    if curr == parent.right:
      # Right child was removed, deal with those rotations
      if parent.balance == 1:
        # Old balance factor was 1, and we decreased the height of the right
        # subtree, so now it's 2, rebalance needed
        let sib = parent.left
        let sibBalance = if sib != nil: sib.balance else: 0
        if sibBalance == -1:
          # left right case, reduce to left left case
          tree.rotateLeft(sib)
        # Has to be left left case now
        tree.rotateRight(parent)
        if sibBalance == 0:
          return
      elif parent.balance == 0:
        # Decreasing the height of the right subtree balanced this
        parent.balance = 1
        return
      parent.balance = 0
    else:
      # Left child was removed, mirror of above case
      if parent.balance == -1:
        # Old balance factor was -1, and we decreased the height of the left
        # subtree, now now it's -2, rebalance needed
        let sib = parent.right
        let sibBalance = if sib != nil: sib.balance else: 0
        if sibBalance == 1:
          # right left case, reduce to right right case
          tree.rotateRight(sib)
        # Has to be right right case now
        tree.rotateLeft(parent)
        if sibBalance == 0:
          # Decreasing the height of the left subtree balanced this
          return
      elif parent.balance == 0:
        # Decreasing the height of the left subtree balanced this
        parent.balance = -1
        return
      parent.balance = 0
    curr = parent
    parent = curr.parent

proc remove*[K, V](tree: AVLTree[K, V], key: K): bool {.discardable.} =
  ## Remove a key value pair from the tree. Returns true if something was
  ## removed, false if the key wasn't found, so nothing was removed.
  var node = tree.findNode(key)
  # If a node with that data doesn't exist, nothing to do
  if node == nil:
    return false

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
  tree.fixRemove(child)
  return true

proc len*[K, V](tree: AVLTree[K, V]): int =
  ## Returns the number of items the in tree
  return tree.size

iterator inOrderTraversal*[K, V](tree: AVLTree[K, V]): (K, V) =
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

  proc checkTree(tree: AVLTree[int, char]) =
    check(tree.len() == 3)
    check(tree.find(10) == ('c', true))
    check(tree.find(5) == ('b', true))
    check(tree.find(1) == ('a', true))
    check(tree.find(2) == ('\0', false))

    check(tree.root.key == 5)
    check(tree.root.right.key == 10)
    check(tree.root.left.key == 1)

  suite("avl tree"):
    test("avl initialization"):
      check(newAVLTree[int, char]() != nil)

    test("avl simple insert"):
      let tree = newAVLTree[int, char]()
      check(tree.insert(5, 'b'))
      check(tree.insert(10, 'c'))
      check(not tree.insert(5, 'd'))
      check(tree.len() == 2)
      check(tree.find(5) == ('d', true))
      check(tree.find(10) == ('c', true))
      check(tree.find(15) == ('\0', false))

    test("avl insert balanced"):
      let tree = newAVLTree[int, char]()
      check(tree.insert(5, 'b'))
      check(tree.insert(1, 'a'))
      check(tree.insert(10, 'c'))
      checkTree(tree)

    test("avl insert right leaning"):
      let tree = newAVLTree[int, char]()
      check(tree.insert(1, 'a'))
      check(tree.insert(5, 'b'))
      check(tree.insert(10, 'c'))
      checkTree(tree)

    test("avl insert right leaning double rotation"):
      let tree = newAVLTree[int, char]()
      check(tree.insert(1, 'a'))
      check(tree.insert(10, 'c'))
      check(tree.insert(5, 'b'))
      checkTree(tree)

    test("avl insert left leaning"):
      let tree = newAVLTree[int, char]()
      check(tree.insert(10, 'c'))
      check(tree.insert(5, 'b'))
      check(tree.insert(1, 'a'))
      checkTree(tree)

    test("avl insert left leaning double rotation"):
      let tree = newAVLTree[int, char]()
      check(tree.insert(10, 'c'))
      check(tree.insert(1, 'a'))
      check(tree.insert(5, 'b'))
      checkTree(tree)

    test("avl inorder"):
      let tree = newAVLTree[int, char]()
      for i in 1..10:
        tree.insert(i, 'a')
      var i = 1
      for key, value in tree.inOrderTraversal():
        check(i == key)
        i += 1
      check(i == 11)

    test("avl remove simple"):
      let tree = newAVLTree[int, char]()
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

    test("avl remove rotation"):
      let tree = newAVLTree[int, char]()
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

    test("avl remove double rotation"):
      let tree = newAVLTree[int, char]()
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

    test("avl remove non leaf"):
      let tree = newAVLTree[int, char]()
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

    test("avl remove nonexistant"):
      let tree = newAVLTree[int, char]()
      tree.insert(1, 'a')
      tree.insert(5, 'b')
      check(tree.len() == 2)
      tree.remove(10)
      check(tree.len() == 2)
