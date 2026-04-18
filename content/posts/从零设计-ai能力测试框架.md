---
title: "从零设计一个 AI 综合能力测试框架"
date: 2026-04-16T18:00:00+08:00
draft: false
tags: ["python", "架构设计", "llm", "测试框架", "工程实践"]
categories: ["技术实战"]
description: "如何设计一套可扩展的 AI 模型评测系统？分享插件化架构、双机制评分与多格式报告的设计思路"
---

> Day 05 的项目是我目前最满意的工程实践。本文拆解一个 AI 测试框架的设计思路，从需求分析到架构落地。

## 需求分析

我想要一个工具，能够：

1. **统一评测不同模型**：本地 HuggingFace 模型、OpenAI API、Kimi、DeepSeek……接口各不相同，需要一个统一封装
2. **多维度评估**：不只是"对不对"，还要看推理深度、关键词覆盖、结构完整性
3. **可扩展**：容易添加新题目、新评分标准、新报告格式
4. **开箱即用**：内置一批高质量测试题，一行命令跑起来

## 架构设计

采用**插件化 + 依赖注入**的思路，核心模块完全解耦：

```
TestRunner (协调器)
    ├── ModelInterface (模型接口)
    │   ├── HuggingFaceModel
    │   ├── OpenAIModel
    │   └── DummyModel (测试用)
    ├── Evaluator (评分器)
    │   ├── RuleBasedEvaluator
    │   └── LLMBasedEvaluator
    ├── QuestionBank (题库)
    │   └── builtin.py (20道内置题)
    └── Reporter (报告)
        ├── ConsoleReporter
        ├── JSONReporter
        └── MarkdownReporter
```

## 模块详解

### 1. 统一模型接口

所有模型必须实现同一个基类：

```python
class ModelInterface(ABC):
    @abstractmethod
    def generate(self, prompt: str, system_prompt: str = "", 
                 temperature: float = 0.7, max_tokens: int = 500) -> str:
        pass
```

这样 `TestRunner` 完全不用关心底层是本地 PyTorch 模型还是远程 API。新增模型支持只需继承基类、实现 `generate` 方法。

### 2. 题目设计（20 道内置题）

题目不是随便找的，而是按**能力维度**系统设计的：

| 类别 | 数量 | 关键能力 | 示例 |
|------|------|----------|------|
| 逻辑与推理 | 5 | 模式识别、递推思维 | 序列推理：2,6,15,40,104,? |
| 语言理解 | 5 | 歧义消解、隐喻理解 | "心的孤岛"是什么意思？ |
| 数学思维 | 4 | 抽象代数、贝叶斯推理 | 条件蒙提霍尔问题 |
| 常识推理 | 3 | 物理直觉、逆向思维 | 深海塑料瓶会先沉到哪里？ |
| 创造性思维 | 1 | 类比推理 | 如何把区块链和光合作用结合？ |
| 伦理与价值观 | 1 | 道德推理 | 自动驾驶伦理困境 |
| 元认知 | 1 | 自我反思 | 请评价你刚才的回答 |

每道题都包含：题目内容、参考答案、评分关键词、难度等级、所属类别。

### 3. 双机制评分

单一评分方式不够可靠，所以设计了两套并行机制：

**规则评分（RuleBasedEvaluator）**

```python
def evaluate(self, answer: str, question: Question) -> EvaluationResult:
    score = 0
    # 关键词匹配
    for keyword in question.keywords:
        if keyword in answer:
            score += 10
    # 长度惩罚（过短可能敷衍）
    if len(answer) < 20:
        score -= 5
    return EvaluationResult(score=score, feedback="...")
```

优点：快速、确定性高、不消耗额外 Token
缺点：容易被"关键词堆砌"欺骗

**LLM 评判（LLMBasedEvaluator）**

用一个更强的模型（如 Kimi/GPT-4）作为裁判，让它按标准打分：

```
请评价以下回答，从 0-100 打分：
- 正确性：是否回答到核心要点
- 完整性：是否覆盖所有必要信息
- 深度：是否有深入分析而非泛泛而谈
```

优点：更接近人类判断、能识别胡说
缺点：慢、消耗 API Token、有随机性

实际使用中，可以先用规则评分快速初筛，再用 LLM 评判关键题目。

### 4. 报告生成

测试完要让人看懂结果，所以做了三种报告：

**控制台报告（彩色）**

```
======================================================================
🤖 AI 综合能力测试报告
======================================================================

模型名称: Qwen/Qwen2.5-0.5B-Instruct
总分: 156.5 / 200.0 (78.2%)  等级: ✅ 良好

logic        ████████████████░░░░ 78.5%
language     ███████████████░░░░░ 75.0%
math         ██████████░░░░░░░░░░ 52.5%
```

**Markdown 报告**

适合存档和分享，包含每道题的详细评分和建议。

**JSON 报告**

方便程序化分析和批量对比。

## 使用示例

### 多模型对比

```python
from ai_test_suite import TestRunner, HuggingFaceModel

models = [
    HuggingFaceModel("Qwen/Qwen2.5-0.5B-Instruct"),
    HuggingFaceModel("Qwen/Qwen2.5-1.5B-Instruct"),
]

runner = TestRunner(model=models[0])
results = runner.benchmark(models, limit=10)
```

### 自定义题目

```python
from ai_test_suite import Question, QuestionBank, QuestionCategory, DifficultyLevel

q = Question(
    id="custom_001",
    category=QuestionCategory.LOGIC,
    difficulty=DifficultyLevel.MEDIUM,
    title="自定义题目",
    content="题目内容...",
    answer="参考答案",
    keywords=["关键词1", "关键词2"],
)

bank = QuestionBank()
bank.add(q)
```

## 设计反思

1. **抽象层级要恰到好处**。`ModelInterface` 只暴露 `generate` 一个方法，没有过度设计（比如不需要抽象"流式输出"、"函数调用"等高级功能）。

2. **配置文件优于代码**。题目用 JSON/文件存储，而不是硬编码在 Python 里，方便非程序员贡献题目。

3. **默认即合理**。内置 20 道题 + DummyModel 演示，新用户 clone 下来 `python quickstart.py` 就能跑通。

## 下一步

- [ ] 支持并发评测（多模型并行跑）
- [ ] 添加可视化图表（雷达图展示能力分布）
- [ ] 支持增量评测（只测上次失败的题目）
- [ ] 社区题目库（接受 PR 贡献高质量题目）

---

完整代码和文档：[ai-learning/Day05_My_Gpu_Icrying](https://github.com/collensong/ai-learning/tree/main/Day05_My_Gpu_Icrying)

如果你也在做模型评测，欢迎交流！
