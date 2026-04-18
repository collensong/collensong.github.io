---
title: "Graph RAG 实战：用 Neo4j 构建企业供应链问答系统"
date: 2026-04-12T14:00:00+08:00
draft: false
tags: ["rag", "neo4j", "kimi", "知识图谱", "llm"]
categories: ["技术实战"]
description: "对比传统向量 RAG 与 Graph RAG，用 Neo4j + Kimi API 实现可解释的知识图谱问答"
---

> 本文记录了我学习 Graph RAG 的完整过程，从 Neo4j 环境搭建到最终问答系统上线。

## 什么是 Graph RAG

传统 RAG（检索增强生成）通常使用**向量数据库**：把文档切成块、转成向量，用户提问时做语义相似度搜索。这有个致命问题——**它很难表达精确的关系**。

比如问："宁德时代的主要供应商是谁？"

- 向量检索可能找到提到"宁德时代"和"供应商"的段落，但不一定能精确定位"供应"这个关系
- 图谱检索直接在图数据库里查 `(supplier)-[:供应]->(宁德时代)`，结果精确且可解释

## 系统架构

```
用户问题
    ↓
实体识别（关键词匹配）
    ↓
Neo4j 图谱检索（Cypher 查询）
    ↓
上下文组装（关系文本化）
    ↓
Kimi AI 生成回答
    ↓
返回结果 + 引用来源
```

## 数据建模

### 节点：Company

```cypher
(:Company {
    name: "宁德时代",
    industry: "电池制造",
    employees: 10000
})
```

### 关系：RELATION

```cypher
(:Company)-[:RELATION {
    type: "供应",        // 供应 / 竞争 / 合作
    product: "动力电池"
}]->(:Company)
```

初始数据包含 5 家公司：宁德时代、比亚迪、特斯拉、天齐锂业、江西铜业，涵盖了供应、竞争、合作三种关系。

## 核心代码

### 1. 实体识别（简单但有效）

```python
companies = ["宁德时代", "比亚迪", "特斯拉", "小鹏", "蔚来", "蜂巢能源"]

# 从问题中提取提到的公司
mentioned = [c for c in companies if c in question]
```

目前用关键词匹配，后续可以升级为 NER 模型。

### 2. 图谱查询

```python
from neo4j import GraphDatabase

driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

with driver.session() as session:
    result = session.run("""
        MATCH (c:Company {name: $name})-[r:RELATION]-(other)
        RETURN other.name, r.type, r.product
    """, name="宁德时代")
    
    for record in result:
        print(f"{record['other.name']} --[{record['r.type']}]-> {record['r.product']}")
```

### 3. 上下文组装 + Kimi 生成

把查询到的关系数据格式化成自然语言文本，作为 System Prompt 的一部分传给 Kimi：

```
以下是知识图谱中的相关信息：
- 江西铜业向宁德时代供应铜箔材料
- 天齐锂业向宁德时代供应电池级碳酸锂

请根据以上信息回答用户问题。
```

## 运行效果

```
❓ 宁德时代的主要供应商是谁？
💡 宁德时代的主要供应商包括江西铜业和天齐锂业。
   江西铜业为宁德时代提供铜箔材料，而天齐锂业则供应电池级碳酸锂。
📊 使用上下文: 4 条

❓ 比亚迪和宁德时代有什么关系？
💡 比亚迪与宁德时代在动力电池市场上存在竞争关系。
📊 使用上下文: 4 条
```

## Graph RAG vs 传统 RAG

| 特性 | 传统 RAG（向量） | Graph RAG（图谱） |
|------|-----------------|------------------|
| 检索方式 | 语义相似度 | 结构化查询 |
| 关系表达 | 弱（隐式） | 强（显式关系） |
| 可解释性 | 低（黑盒相似度） | 高（可追溯来源） |
| 适合场景 | 文档问答 | 关系推理、知识问答 |
| 维护成本 | 低 | 高（需维护图谱 Schema） |

## 踩坑记录

1. **Neo4j 连接失败**：默认 Bolt 端口是 7687，不是 HTTP 的 7474。检查 `NEO4J_URI=bolt://...`。
2. **Kimi API 401**：`.env` 文件里的 Key 不要带引号，直接写 `KIMI_API_KEY=sk-xxx`。
3. **实体识别漏匹配**：用户可能用简称（如"宁德"），需要维护别名映射表。

## 下一步优化

- [ ] 用 LLM 做实体识别和关系抽取，自动扩展图谱
- [ ] 实现多跳推理（A 的供应商的供应商）
- [ ] 结合向量检索做混合 RAG

---

完整代码已开源在 [ai-learning/Day03_Graph_RAG](https://github.com/collensong/ai-learning/tree/main/Day03_Graph_RAG)。
