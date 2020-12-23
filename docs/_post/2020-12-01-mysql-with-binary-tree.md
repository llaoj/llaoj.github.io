## 图说mysql 与 二叉树 binary tree

二叉树作为索引的话:

![binary tree](/pic/mysql/binary-tree.png)

### 看图说明

- 1 [Data Structure Visualizations](https://www.cs.usfca.edu/~galles/visualization/Algorithms.html) 这是美国人做的一个数据结构可视化网站
- 2 二叉树不适合自增索引, 会扫描全部的索引,效率低, 如下图:

    ![auto increment](/pic/mysql/binary-tree-auto-increment.png)

- 3 二叉树: 左边是小数, 右边是大数, 从根节点开始查找