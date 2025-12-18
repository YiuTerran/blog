---
title: AI学习入门(1)
date: 2025-11-01T07:37:16+08:00
slug: c54e7f6
draft: true
author:
  name: tryao
tags: ["AI"]
collections: ["机器学习"]
toc: true
math: true
lightgallery: false
---

首先学习《深度学习基础与概念》一书。

<!--more-->

## 基础知识

1. 机器学习的目标是在**有限的训练集中发现隐藏的规律**，其核心是**从数据中学习概率**；
1. 拟合函数。举例多项式拟合：$y(x,w)=w_0+w_1x+w_2x^2+...+w_Mx^M=\sum_{j=0}^{M}w_jx^j$，w是一个向量[w0, w1,...wm]，函数y相对于系数w是一个线性函数（如果视x为常量），因此这是一个线性模型；
3. 误差函数：
   * 评估误差函数：$E(w)=\frac{1}{2}\sum_{n=1}^{N}\{y(x_n, w)-t_n\}$
   * 均方根误差：$E_{RMS}=\sqrt{\frac{1}{N}\sum_{n=1}^N\{y(x_n,w)-t_n\}^2}$

4. 训练的目标并非是训练集的均方根误差最小，这很容易过拟合。一般使用测试集来测试训练出来的模型；

5. 正则化，在误差函数里面增加一个惩罚项来抑制过拟合，如：$\tilde{E}(w)=\frac{1}{2}\sum_{n=1}^{N}\{y(x_n,w)-t_n\}^2+\frac{\lambda}{2}||w||^2$，其中$||w||^2\equiv w^Tw=w_0^2+w_1^2+...+w_m^2$。在神经网络领域，这种方法被称为**权重衰减**，所谓权重其实就是多项式系数；

6. 交叉验证：如果训练集数据量较小，可以使用(S-1)/S的数据用来训练，全部数据用来验证。S是子集的数量，极端情况下S=总数（留一法）。训练S次，每次将其中一个作为保留集。

7. 参数的数量决定了模型的规模，所谓大模型，参数数量能达到上千亿。此时误差函数必然是复杂非线性函数，只能逐步逼近最优解；

8. 神经网络，模拟人类大脑的神经元机制：
   \[
   a=\sum_{i=1}^{M}w_ix_i \\
   y=f(a)
   \]

$x_i$表示连接当前神经元的其他神经元，$w_i$则表示突触的强度（权重），a表示预激活；函数f是激活函数，y是激活。

9. 上面是单层神经网络的数学抽象，如果

\[
f(a)=\begin{cases}
0 & a\le0 \\
1 & a>0
\end{cases}
\]

这个数据模型被称为感知机，现代神经网络一般被称为多层感知机(MLP)。

10. 多层网络主要改进：
    * 将(2)的阶跃式激活函数改为具有非零梯度的连续可微激活函数；
    * 引入可微的误差函数，这个函数可以计算网络模型中每一个参数的偏导数；
11. 两层模型：在输入值和输出值中增加一层隐藏单元，然后对每个隐藏单元计算(1)中的函数，此类模型被称为前馈神经网络。

![image-20251111140704981](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/image-20251111140704981.png)

训练方式：

* 使用随机数生成器初始化参数
* 使用基于梯度的优化技术进行迭代更新
* 使用误差反向传播计算偏导

12. 两层以上网络被称为深度网络，相关的技术是2010年之后才开始逐渐兴起的，这就是所谓**深度学习**的由来，这也是大模型的技术根源。

## pytorch知识

1. 张量：标量是0维张量，向量是1维张量，矩阵是2维张量，更高维的一般称为ND张量；
2. `torch.tensor`函数创建张量；
3. 梯度：一个向量，包含了一个多变量函数（输入变量超过一个的函数）的所有偏导数；梯度可以视为误差函数的代理；
4. pytorch提供了`backward`方法自动计算图中所有叶子结点的梯度，开发者可以跳过复杂的微积分计算；
5. 使用pytorch构建多层神经网络：

```python
import torch
class NeuralNetwork(torch.nn.Module):
  def __init__(self, num_inputs, num_outputs):
    super().__init__()
    self.layers = torch.nn.Sequential(
      # 1st layer
    	torch.nn.Linear(num_inputs, 30),
      torch.nn.ReLU(),
      # 2nd layer
      torch.nn.Linear(30, 20),
      torch.nn.ReLU(),
      # output layer
      torch.nn.Linear(20, num_outputs),
    )
  def forward(self, x):
    logits = self.layers(x)
    return logits
model = NeuralNetwork(50, 3)

```

6. Dataset类用于实例化定义如何**加载**每条数据记录的对象，DataLoader类负责处理数据的打乱和组装成批次。训练和验证的数据集需要分开。这里是一个例子，输入张量，每一维是一个长度为2的向量（特征），输出是一个标签：

```python
from torch.utils.data import DataLoader, Dataset
import torch.nn.functional as F

# 示例训练数据集，输入为两个特征，5个样本
X_train = torch.tensor([
    [-1.2, 3.1],
    [-0.9, 2.9],
    [-0.5, 2.6],
    [2.3, -1.1],
    [2.7, -1.5]
])
# 标签
y_train = torch.tensor([0, 0, 0, 1, 1])
# 测试数据集，输入为两个特征，2个样本
X_test = torch.tensor([
    [-0.8, 2.8],
    [2.6, -1.6],
])
# 标签
y_test = torch.tensor([0, 1])


# 数据集类
class MyDataset(Dataset):
    def __init__(self, X, y):
        self.features = X
        self.labels = y

    def __len__(self):
        # 特征数量（样本数量）
        return self.labels.shape[0]

    def __getitem__(self, idx):
        # 指定索引的特征和标签
        return self.features[idx], self.labels[idx]


# 训练集
train_ds = MyDataset(X_train, y_train)
# 测试集
test_ds = MyDataset(X_test, y_test)
# 随机数种子
torch.manual_seed(123)
# num_workers=0表示不用额外的进程来加速数据加载, drop_last=True表示最后一个batch可能小于batch_size，所以丢弃掉
train_loader = DataLoader(train_ds, batch_size=2, shuffle=True, num_workers=0, drop_last=True)
test_loader = DataLoader(test_ds, batch_size=2, shuffle=False, num_workers=0)

model = NeuralNetwork(2, 2)
optimizer = torch.optim.SGD(model.parameters(), lr=0.5)

num_epochs = 3
for epoch in range(num_epochs):
    model.train()
    for batch_idx, (features, labels) in enumerate(train_loader):
        logits = model(features)
        # 损失函数
        loss = F.cross_entropy(logits, labels)
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
    model.eval()
with torch.no_grad():
    outputs = model(X_train)
    print(outputs)
torch.set_printoptions(sci_mode=False)
probas = torch.softmax(outputs, dim=1)
print(probas)
predictions = torch.argmax(probas, dim=1)
print(predictions)

def compute_accuracy(model, dataloader):
    model = model.eval()
    correct = 0.0
    total_examples = 0
    for idx, (features, labels) in enumerate(dataloader):
        with torch.no_grad():
             logits = model(features)
        predictions = torch.argmax(logits, dim=1)
        comparator = predictions == labels
        correct += torch.sum(comparator)
        total_examples += len(comparator)
    return (correct / total_examples).item()

print(compute_accuracy(model, test_loader))
```

上面展示了建模、训练、测试、计算准确率的流程。

7. 从CPU迁移到GPU，其实很简单，将模型和数据都转移过去就行：

```python
device = 'cpu'
if torch.cuda.is_available():
  device = 'cuda'
elif torch.backends.mps.is_available():
  device = 'mps'
model = model.to(device)
```

8. 多GPU训练，使用DDP框架。

