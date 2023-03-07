// Javascript equivalent of the python code
// A utility function to create a new node
class Node {
  constructor(key) {
    this.key = key;
    this.left = null;
    this.right = null;
  }
}

// Function two print common elements in given two trees
function printCommon(root1, root2) {
  // Create two stacks for two inorder traversals
  let s1 = [],
    s2 = [];

  while (true) {
    // append the Nodes of first
    // tree in stack s1
    if (root1) {
      s1.push(root1);
      root1 = root1.left;
    }
    // append the Nodes of second tree
    // in stack s2
    else if (root2) {
      s2.push(root2);
      root2 = root2.left;
    }
    // Both root1 and root2 are NULL here
    else if (s1.length !== 0 && s2.length !== 0) {
      root1 = s1[s1.length - 1];
      root2 = s2[s2.length - 1];

      // If current keys in two trees are same
      if (root1.key === root2.key) {
        console.log(root1.key);
        s1.pop();
        s2.pop();

        // move to the inorder successor
        root1 = root1.right;
        root2 = root2.right;
      } else if (root1.key < root2.key) {
        // If Node of first tree is smaller, than
        // that of second tree, then its obvious
        // that the inorder successors of current
        // Node can have same value as that of the
        // second tree Node. Thus, we pop from s2
        s1.pop();
        root1 = root1.right;
        // root2 is set to NULL, because we need
        // new Nodes of tree 1
        root2 = null;
      } else if (root1.key > root2.key) {
        s2.pop();
        root2 = root2.right;
        root1 = null;
      }
    }
    // Both roots and both stacks are empty
    else {
      break;
    }
  }
}

// A utility function to do inorder traversal
function inorder(root) {
  if (root) {
    inorder(root.left);
    console.log(root.key);
    inorder(root.right);
  }
}

// A utility function to insert a new Node
// with given key in BST
function insert(node, key) {
  // If the tree is empty, return a new Node
  if (node === null) {
    return new Node(key);
  }
  // Otherwise, recur down the tree
  if (key < node.key) {
    node.left = insert(node.left, key);
  } else if (key > node.key) {
    node.right = insert(node.right, key);
  }
  // return the (unchanged) Node pointer
  return node;
}

// Driver Code
let root1 = null;
root1 = insert(root1, 5);
root1 = insert(root1, 1);
root1 = insert(root1, 10);
root1 = insert(root1, 0);
root1 = insert(root1, 4);
root1 = insert(root1, 7);
root1 = insert(root1, 9);

// Create second tree as shown in example
let root2 = null;
root2 = insert(root2, 10);
root2 = insert(root2, 7);
root2 = insert(root2, 20);
root2 = insert(root2, 4);
root2 = insert(root2, 9);

console.log("Tree 1 : ");
inorder(root1);
console.log();

console.log("Tree 2 : ");
inorder(root2);
console.log();

console.log("Common Nodes: ");
printCommon(root1, root2);
