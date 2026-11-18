import 'dart:convert';
import 'dart:io';

void main() {
  final List<Map<String, dynamic>> allTopics = [];

  // Month 1: Complete Python - 95 Topics
  final month1Parts = [
    {
      'part': 'Part 1: Python Basics & Syntax Setup',
      'topics': [
        'Introduction to Python, History & Python Philosophy (Zen of Python)',
        'Installing Python 3, IDEs (VS Code, PyCharm), & Setting Up Virtual Environments (venv)',
        'Python Interactive Shell (REPL) & Running Python Scripts',
        'Variables, Dynamic Typing & Memory References (id(), type())',
        'Python Naming Conventions & PEP 8 Style Guide',
        'Primitive Data Types: int, float, complex, bool, str',
        'Type Casting & Type Conversion (Explicit vs Implicit)',
        'Arithmetic Operators & Operator Precedence (PEMDAS)',
        'Assignment & Augmented Assignment Operators',
        'Comparison & Relational Operators',
        'Logical Operators (and, or, not) & Short-Circuit Evaluation',
        'Bitwise Operators (&, |, ^, ~, <<, >>)',
        'Identity Operators (is, is not) vs Equality (==, !=)',
        'Membership Operators (in, not in)',
        'User Input with input() & String Sanitization',
        'String Fundamentals: Indexing, Slicing, & Immutability',
        'String Methods: upper, lower, title, strip, replace, split, join',
        'String Formatting: % formatting, str.format(), and f-strings',
        'Escape Sequences, Raw Strings (r"") & Multi-line Strings',
        'String Encoding, ASCII, Unicode & UTF-8 Basics',
        'Conditional Statements: if, elif, else Branches',
        'Nested Conditionals & Ternary Operator (Conditional Expressions)',
        'Match-Case Statements (Pattern Matching in Python 3.10+)',
        'Truthy and Falsy Values in Python',
        'Practical Mini-Project: Interactive Command-Line Calculator',
      ]
    },
    {
      'part': 'Part 2: Control Flow & Loops',
      'topics': [
        'The while Loop: Syntax, Condition Evaluation & Infinite Loops',
        'The for Loop: Iterating over Ranges, Sequences, and Strings',
        'The range() Function: Start, Stop, and Step Parameters',
        'Loop Control Statements: break and continue',
        'The loop-else Clause (for-else and while-else Constructs)',
        'The pass Statement & Placeholder Code',
        'Nested Loops & Multidimensional Iteration',
        'The enumerate() Function for Index-Tracking Loops',
        'The zip() and zip_longest() Functions for Parallel Iteration',
        'The reversed() and sorted() Built-in Functions',
        'Loop Performance: Iteration Overhead & Best Practices',
        'Simulating Do-While Loops in Python',
        'Accumulator Pattern & Running Totals in Loops',
        'Searching & Sentinel Values in Loops',
        'Loop Unrolling Concepts & Vectorization Differences',
        'Iteration Protocols: iter() and next() Deep Dive',
        'Handling StopIteration Exception Manually',
        'Creating Custom Iterator Classes (__iter__, __next__)',
        'Infinite Iterators with itertools (count, cycle, repeat)',
        'Practical Mini-Project: Number Guessing Game with Scoring & History',
      ]
    },
    {
      'part': 'Part 3: Data Structures (Lists, Tuples, Dictionaries, Sets)',
      'topics': [
        'Lists: Creation, Indexing, Slicing, and Modifiability',
        'List Operations: append, extend, insert, pop, remove, clear',
        'List Indexing Tricks: Negative Indices, Step Slicing & Slice Assignment',
        'List Sorting: list.sort() in-place vs sorted() built-in (key and reverse)',
        'Shallow Copy vs Deep Copy in Lists (copy module, copy() vs deepcopy())',
        'List Comprehensions: Syntax, Filtering, and Conditional Expressions',
        'Nested List Comprehensions & Flattening 2D Matrices',
        'Memory Allocation in Lists: Over-allocation & Dynamic Resizing',
        'Tuples: Creation, Immutability, Single-element Tuples & Tuple Packing',
        'Tuple Unpacking: Star Expressions (*args unpacking), Swapping Variables',
        'NamedTuples: collections.namedtuple & typing.NamedTuple',
        'Tuples as Dictionary Keys & Hashability Requirements',
        'Dictionaries: Key-Value Pairs, Hash Tables & Dict Initialization',
        'Dict Methods: get, keys, values, items, pop, popitem, setdefault, update',
        'Dictionary Comprehensions: Filtering and Transforming Dicts',
        'Merging Dictionaries: update(), pipe operator (| and |= in 3.9+)',
        'collections.defaultdict: Handling Missing Keys Elegantly',
        'collections.Counter: Frequency Counting, most_common() & Math on Counters',
        'collections.OrderedDict: Insertion-order Semantics & move_to_end()',
        'Sets: Uniqueness, Mutable Sets vs frozenset',
        'Set Operations: Union, Intersection, Difference, Symmetric Difference',
        'Set Methods: add, remove, discard, pop, issubset, issuperset',
        'Set Comprehensions & Filtering Duplicates efficiently',
        'Benchmarking Performance: Lists vs Sets vs Dicts Lookup Time (O(1) vs O(N))',
        'Practical Mini-Project: Contact Book & CRM with Search and Deduplication',
      ]
    },
    {
      'part': 'Part 4: Functions, Modules & Functional Tools',
      'topics': [
        'Function Definitions (def), Calling, and Execution Flow',
        'Positional Arguments vs Keyword Arguments',
        'Default Arguments & The Mutable Default Argument Trap',
        'Arbitrary Arguments: *args for Variadic Positional Arguments',
        'Arbitrary Keyword Arguments: **kwargs for Variadic Dict Arguments',
        'Keyword-Only Arguments (*, arg) & Positional-Only Arguments (arg, /)',
        'Return Values: Returning Single Values, Tuples, and Early Returns',
        'Docstrings & PEP 257 (Google, Sphinx, NumPy Docstring Formats)',
        'Scope Rules: LEGB (Local, Enclosing, Global, Built-in)',
        'Modifying Scopes: global and nonlocal Keywords',
        'First-Class Functions: Passing Functions as Arguments & Variables',
        'Higher-Order Functions: map(), filter(), reduce() (functools.reduce)',
        'Anonymous Functions: lambda Expressions and Use Cases',
        'Closures: Inner Functions, Retaining Enclosing State & Factory Functions',
        'Recursion: Base Cases, Recursive Step, Call Stack & Recursion Limit',
        'Memoization Techniques & functools.lru_cache / functools.cache',
        'Python Modules: Creating, Importing (import, from x import y, as alias)',
        'Module Search Path (sys.path) & Environment Variable PYTHONPATH',
        'Python Packages: __init__.py, Relative vs Absolute Imports',
        'The Special Name __name__ and `if __name__ == "__main__":` Guard',
        'Standard Library Tour: math, random, datetime, time, calendar',
        'Operating System Interface: os, sys, shutil, pathlib.Path',
        'Type Hints & Annotations: typing module (List, Dict, Optional, Union, Any)',
        'Static Type Checking with Mypy Concepts',
        'Month 1 Capstone Project: Comprehensive Student Management & Grading System',
      ]
    }
  ];

  // Month 2: Advanced Python + DSA - 60 Topics
  final month2Parts = [
    {
      'part': 'Part 1: Object-Oriented Programming (OOP)',
      'topics': [
        'OOP Concepts: Classes, Objects, Instances & State',
        'The __init__ Constructor Method and self Parameter',
        'Instance Attributes vs Class Attributes',
        'Instance Methods, Class Methods (@classmethod) & Static Methods (@staticmethod)',
        'Encapsulation: Public, Protected (_var), and Private (__var) Name Mangling',
        'Properties and Getters/Setters with @property, @prop.setter, @prop.deleter',
        'Inheritance: Single Inheritance & Code Reusability',
        'The super() Function & Calling Parent Class Methods',
        'Multiple Inheritance & The Diamond Problem',
        'Method Resolution Order (MRO) & C3 Linearization Algorithm',
        'Polymorphism & Duck Typing ("If it walks like a duck...")',
        'Abstract Base Classes (ABCs) with abc module (@abstractmethod)',
        'Operator Overloading & Special Magic Methods (__str__, __repr__, __len__, __getitem__)',
        'Arithmetic Dunder Methods (__add__, __sub__, __mul__, __eq__, __lt__)',
        'The __call__ Method: Making Class Instances Callable Like Functions',
        'Object Lifecycle: __new__ vs __init__ and __del__ Finalizer',
        'Composition over Inheritance: Has-a vs Is-a Relationships',
        'Data Classes (@dataclasses.dataclass, frozen=True, field defaults)',
        'Slots in Python: __slots__ for Memory Optimization and Attribute Restriction',
        'Mini-Project: Object-Oriented Banking System with Transactions & Audit Logs',
      ]
    },
    {
      'part': 'Part 2: Advanced Python Features & Metaprogramming',
      'topics': [
        'Function Decorators: Decorator Syntax (@dec), Wrapper Functions & functools.wraps',
        'Decorators with Arguments (3-tier decorator factories)',
        'Class Decorators & Decorating Class Methods',
        'Common Built-in Decorators & Practical Use Cases (Timer, Logger, Authenticator)',
        'Generators: The yield Statement, Generator Functions vs Regular Functions',
        'Generator Expressions: Memory Efficient Streams vs List Comprehensions',
        'Advanced Generator Methods: send(), throw(), and close()',
        'The yield from Expression for Delegating Sub-Generators',
        'Context Managers: The with Statement & Resource Management',
        'Creating Context Managers: __enter__ and __exit__ Methods',
        'contextlib Module: @contextmanager Decorator & closing()',
        'Exception Handling Hierarchy: try, except, else, finally Clauses',
        'Raising Custom Exceptions & Exception Chaining (raise ... from ...)',
        'Introspection & Reflection: getattr, setattr, hasattr, isinstance, issubclass, dir',
        'Metaclasses Basics: type as Class Creator, Custom Metaclasses (__init_subclass__)',
      ]
    },
    {
      'part': 'Part 3: Data Structures & Algorithms (Foundations)',
      'topics': [
        'Algorithmic Complexity: Big-O, Big-Omega, Big-Theta Notations',
        'Analyzing Time Complexity: O(1), O(log N), O(N), O(N log N), O(N^2), O(2^N)',
        'Analyzing Space Complexity: Auxiliary Memory & In-Place Algorithms',
        'Dynamic Arrays Implementation & Amortized Time Complexity',
        'Singly Linked List: Node Class, Insertion, Deletion, Traversal',
        'Doubly Linked List: Bidirectional Pointers & Deletion Efficiency',
        'Circular Linked List: Fast Forward & Cycle Detection',
        'Fast and Slow Pointers Technique (Floyd\'s Cycle Finding Algorithm)',
        'Stack Data Structure: LIFO Principle, Implementation via Lists & collections.deque',
        'Stack Applications: Parentheses Matching, Expression Parsing & Call Stack',
        'Queue Data Structure: FIFO Principle, collections.deque vs list Performance',
        'Circular Queue & Double-Ended Queue (Deque) Implementation',
        'Priority Queue & Binary Heaps: heapify, heappush, heappop (heapq module)',
        'Linear Search: Implementation, Best, Average, and Worst-Case Analysis',
        'Binary Search: Iterative & Recursive Approaches on Sorted Arrays (bisect module)',
        'Binary Search Variations: Lower Bound, Upper Bound, Search in Rotated Array',
        'Bubble Sort & Optimized Bubble Sort with Early Termination',
        'Selection Sort: Finding Minima & In-Place Swapping',
        'Insertion Sort: Online Sorting & Performance on Nearly-Sorted Data',
        'Merge Sort: Divide and Conquer, Recursive Splitting, Merging Subarrays (O(N log N))',
        'Quick Sort: Partitioning Schemes (Lomuto vs Hoare), Pivot Selection, Worst-Case Mitigation',
        'Counting Sort & Radix Sort: Non-Comparison Sorting Algorithms',
        'Two Pointer Technique: Reversing, Palindromes, Pair Sum in Sorted Arrays',
        'Sliding Window Technique: Fixed Size vs Dynamic Window Minimum/Maximum',
        'Month 2 Capstone: Custom High-Performance Collections & Algorithms Library',
      ]
    }
  ];

  // Month 3: DSA + SQL + Backend - 70 Topics
  final month3Parts = [
    {
      'part': 'Part 1: Intermediate & Advanced DSA',
      'topics': [
        'Hash Tables Internals: Hash Functions, Collisions, Chaining vs Open Addressing',
        'Binary Trees: Tree Terminology, Node Representation, Depth vs Height',
        'Binary Tree Traversals: In-Order, Pre-Order, Post-Order (DFS)',
        'Level-Order Traversal (BFS) using Queues',
        'Binary Search Trees (BST): Insertion, Search, Deletion, In-Order Successor',
        'Validating BST & Lowest Common Ancestor (LCA)',
        'Balanced BST Concepts: AVL Trees & Red-Black Trees Rotation Mechanics',
        'Trie (Prefix Tree): Insertion, Search, StartsWith & Autocomplete Implementation',
        'Graph Representations: Adjacency Matrix vs Adjacency List',
        'Graph Traversal: Breadth-First Search (BFS) for Shortest Path in Unweighted Graphs',
        'Graph Traversal: Depth-First Search (DFS) Iterative and Recursive',
        'Cycle Detection in Directed Graphs (Topological Sort / Kahn\'s Algorithm / DFS Coloring)',
        'Cycle Detection in Undirected Graphs using Disjoint Set Union (DSU / Union-Find)',
        'Union-Find: Path Compression & Union by Rank Optimization',
        'Dijkstra\'s Algorithm: Single-Source Shortest Paths with Min-Heap',
        'Bellman-Ford Algorithm: Handling Negative Weight Edges & Detecting Negative Cycles',
        'Minimum Spanning Tree: Prim\'s Algorithm vs Kruskal\'s Algorithm',
        'Backtracking Paradigm: State Space Trees & Pruning',
        'N-Queens Problem & Sudoku Solver using Backtracking',
        'Dynamic Programming (DP) Philosophy: Optimal Substructure & Overlapping Subproblems',
        'DP Approaches: Top-Down with Memoization vs Bottom-Up Tabulation',
        '1D DP Classic Problems: Climbing Stairs, House Robber, Coin Change',
        '2D DP Classic Problems: Longest Common Subsequence (LCS) & Edit Distance',
        '0/1 Knapsack Problem & Unbounded Knapsack',
        'Greedy Algorithms: Fractional Knapsack, Activity Selection & Huffman Coding',
      ]
    },
    {
      'part': 'Part 2: Relational Databases & SQL Mastery',
      'topics': [
        'Database Fundamentals: RDBMS vs NoSQL, ACID Properties & Relational Model',
        'Installing PostgreSQL / SQLite & Database Client Tools (DBeaver, pgAdmin)',
        'SQL Data Definition Language (DDL): CREATE, ALTER, DROP, TRUNCATE TABLE',
        'SQL Data Types: INTEGER, VARCHAR, TEXT, BOOLEAN, TIMESTAMP, UUID, JSONB',
        'Constraints: PRIMARY KEY, FOREIGN KEY, NOT NULL, UNIQUE, CHECK, DEFAULT',
        'SQL Data Manipulation Language (DML): INSERT, UPDATE, DELETE with WHERE Clause',
        'Querying Data: SELECT, DISTINCT, Alias (AS), LIMIT, OFFSET, ORDER BY (ASC/DESC)',
        'Filtering Operators: BETWEEN, IN, LIKE, ILIKE, IS NULL, Logical AND/OR/NOT',
        'Aggregate Functions: COUNT, SUM, AVG, MIN, MAX',
        'Grouping Data: GROUP BY and HAVING Filtering Clause',
        'SQL Joins: INNER JOIN, LEFT OUTER JOIN, RIGHT OUTER JOIN, FULL OUTER JOIN',
        'Self Joins & Cross Joins (Cartesian Products)',
        'Subqueries: Scalar Subqueries, Correlated Subqueries, IN and EXISTS Operators',
        'Common Table Expressions (CTEs): WITH Clause & Recursive CTEs for Hierarchies',
        'Window Functions: ROW_NUMBER(), RANK(), DENSE_RANK(), NTILE(), OVER(PARTITION BY ...)',
        'Window Value Functions: LAG(), LEAD(), FIRST_VALUE(), LAST_VALUE()',
        'Database Indexing: B-Tree Indexes, Hash Indexes, Composite Indexes & Covering Indexes',
        'Query Optimization: EXPLAIN and EXPLAIN ANALYZE, Index Scans vs Seq Scans',
        'Database Transactions: BEGIN, COMMIT, ROLLBACK & Savepoints',
        'Transaction Isolation Levels: Read Uncommitted, Read Committed, Repeatable Read, Serializable',
        'Concurrency Anomalies: Dirty Reads, Non-repeatable Reads, Phantom Reads & Write Skew',
        'Database Normalization: 1NF, 2NF, 3NF, BCNF & When to Denormalize',
        'Database Views, Materialized Views & Refresh Strategies',
        'Database Triggers & Stored Procedures / Functions',
        'Connecting Python to SQL: sqlite3 Module, psycopg2 & Connection Pooling',
      ]
    },
    {
      'part': 'Part 3: Python Backend Architecture & Networking',
      'topics': [
        'Networking Essentials: TCP/IP Stack, Sockets, DNS, Ports, and Loopback Address',
        'Python socket Programming: Low-level TCP Server and Client Communication',
        'The HTTP Protocol: HTTP/1.1 vs HTTP/2 vs HTTP/3, Requests, Responses & Status Codes',
        'HTTP Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD (Idempotency)',
        'HTTP Headers: Content-Type, Accept, Authorization, Cookies, User-Agent, CORS',
        'Python http.server Module & Writing a Native HTTP Server from Scratch',
        'The Python requests Library: GET/POST, Custom Headers, Timeout, Session Objects',
        'Parsing JSON, Query Parameters, Form Data & Multipart File Uploads',
        'RESTful API Architectural Constraints: Statelessness, Resource Identification, HATEOAS',
        'API Authentication Mechanisms: Basic Auth, Session Cookies, API Keys, Bearer Tokens',
        'JWT (JSON Web Tokens): Header, Payload, Signature, Access vs Refresh Tokens',
        'Password Security & Hashing: Salt, Hash, bcrypt, argon2 & Rainbow Table Defense',
        'Python WSGI (Web Server Gateway Interface) Specification (PEP 3333)',
        'Python ASGI (Asynchronous Server Gateway Interface) Specification',
        'Introduction to SQLAlchemy ORM: Engine, Session, Declarative Base, Models',
        'SQLAlchemy Queries: Filtering, Joins, Aggregations, and Eager vs Lazy Loading',
        'Database Migrations with Alembic: Configuration, Revision Generation, Upgrade/Downgrade',
        'Web Security Fundamentals: SQL Injection, XSS, CSRF, CORS & Protection Mechanisms',
        'Rate Limiting, Request Throttling, and Input Validation Principles',
        'Month 3 Capstone: Full-Featured REST API with Raw SQL & SQLAlchemy Database Backend',
      ]
    }
  ];

  // Month 4: Backend + Django + FastAPI + Git - 60 Topics
  final month4Parts = [
    {
      'part': 'Part 1: Django Full-Stack & REST Framework',
      'topics': [
        'Django Architecture: MVT (Model-View-Template) Pattern & Project Structure',
        'Django Settings, django-admin CLI, manage.py & Environment Configurations',
        'Django Models: Fields, Constraints, Meta Options, and __str__ Representations',
        'Django Model Relationships: OneToOne, ForeignKey (OneToMany), ManyToManyField',
        'Django Migrations: makemigrations, migrate, sqlmigrate, Migration Dependencies',
        'Django ORM QuerySets: Lazy Evaluation, filter, exclude, get, annotate, aggregate',
        'Optimizing Django Queries: select_related (OneToOne/FK) vs prefetch_related (M2M)',
        'Django Admin Interface: ModelAdmin Customization, Search Fields, Filters, Inlines',
        'Django URLs & URL Routing: Path Converters, Regex URLs, Namespaces & Reverse Resolution',
        'Django Function-Based Views (FBVs) vs Class-Based Views (CBVs)',
        'Django Generic CBVs: ListView, DetailView, CreateView, UpdateView, DeleteView',
        'Django Forms & ModelForms: Validation, Clean Methods, CSRF Token Protection',
        'Django Templates: Template Tags, Filters, Template Inheritance (extends, block)',
        'Django Static Files & Media Handling: Development vs Production Serving',
        'Django User Authentication System: AbstractUser vs AbstractBaseUser Custom Models',
        'Django Signals: post_save, pre_delete, receiver Decorator & Dispatching',
        'Django Middleware: Request-Response Lifecycle, Writing Custom Middleware',
        'Introduction to Django REST Framework (DRF): Installation and Settings',
        'DRF Serializers & ModelSerializers: Validation, SerializerMethodField, Nested Serialization',
        'DRF APIViews vs Generic APIViews (ListCreateAPIView, RetrieveUpdateDestroyAPIView)',
        'DRF ViewSets & ModelViewSets with DefaultRouter',
        'DRF Authentication: SessionAuth, TokenAuth, and JWT (SimpleJWT integration)',
        'DRF Permissions: IsAuthenticated, IsAdminUser, and Custom BasePermission',
        'DRF Filtering, Searching, Ordering (django-filter) & Pagination Schemes',
        'Mini-Project: E-Commerce REST API with Cart, Checkout, and Order Management',
      ]
    },
    {
      'part': 'Part 2: FastAPI, Asynchronous Python & Microservices',
      'topics': [
        'Asynchronous Python: Event Loop, Coroutines, async/await Syntax',
        'asyncio Module: asyncio.run(), asyncio.gather(), asyncio.create_task(), Timeouts',
        'Asynchronous I/O vs CPU-Bound Multiprocessing: GIL (Global Interpreter Lock) Deep Dive',
        'Introduction to FastAPI: High Performance, Automatic Interactive Docs (Swagger UI/ReDoc)',
        'Uvicorn & ASGI Application Serving with Hot Reload',
        'Pydantic v2: BaseModel, Field, Data Validation, Type Parsing, Custom Validators',
        'Path Parameters, Query Parameters & Request Body in FastAPI',
        'Request Validation, Error Handling & HTTPException Custom Responses',
        'FastAPI Dependency Injection System: Depends(), Sub-dependencies, Yield Dependencies',
        'Database Integration in FastAPI: Async SQLAlchemy with asyncpg / aiosqlite',
        'Database Sessions in FastAPI: Dependency-injected Async Session Lifecycle',
        'FastAPI Authentication: OAuth2 with Password (and Hashing), Bearer JWT Flow',
        'Background Tasks in FastAPI: BackgroundTasks Class for Deferred Work',
        'File Uploads in FastAPI: UploadFile vs File, Streaming File Responses',
        'WebSockets in FastAPI: Real-Time Bidirectional Communication & Connection Manager',
        'CORS (Cross-Origin Resource Sharing) Configuration in FastAPI',
        'Middleware in FastAPI: Timing, Logging, and Request Modification',
        'Caching with Redis in Python: redis-py, Async Redis, Cache Invalidation Strategies',
        'Background Job Processing with Celery: Workers, Broker (Redis/RabbitMQ), Beat Scheduler',
        'Testing APIs: pytest, pytest-asyncio, httpx.AsyncClient & Mocking Fixtures',
      ]
    },
    {
      'part': 'Part 3: Git, Version Control & DevOps Foundations',
      'topics': [
        'Version Control Concepts: Centralized vs Distributed VCS',
        'Git Configuration: git config, user identity, default editor, credential helper',
        'Git Architecture: Working Directory, Staging Area (Index), Repository (HEAD)',
        'Essential Git Commands: git init, clone, add, commit, status, diff, log',
        'Branching Strategies: git branch, checkout, switch, Git Flow vs GitHub Flow vs Trunk-Based',
        'Merging: Fast-forward vs Three-way Merge, Resolving Merge Conflicts Confidently',
        'Git Rebasing: git rebase, Interactive Rebasing (rebase -i, squash, edit, reword)',
        'Undoing Changes: git restore, git reset (--soft, --mixed, --hard), git revert',
        'Stashing Work: git stash, pop, apply, list, and stash drop',
        'Remote Repositories: git remote, fetch, pull, push, tracking branches',
        'Git Tags & Releases: Annotated vs Lightweight Tags, Semantic Versioning (SemVer)',
        'Advanced Git: git cherry-pick, git reflog (Recovering Lost Commits), git bisect',
        '.gitignore Rules, Best Practices, and Cleaning Tracked Ignored Files (git rm --cached)',
        'GitHub Collaborations: Forking, Pull Requests (PRs), Code Reviews, Protected Branches',
        'Month 4 Capstone: Production-Grade Async Microservice with FastAPI, Redis & GitHub CI',
      ]
    }
  ];

  // Month 5: AI + ML + Generative AI + Docker + AWS - 65 Topics
  final month5Parts = [
    {
      'part': 'Part 1: Scientific Python, Data Analysis & Machine Learning',
      'topics': [
        'Scientific Python Stack Overview: NumPy, SciPy, Pandas, Matplotlib, Seaborn',
        'NumPy Arrays: ndarray Creation, Data Types, Shapes, Reshaping, Transposing',
        'NumPy Indexing, Slicing, Boolean Masking & Fancy Indexing',
        'NumPy Vectorization & Broadcasting Rules for Element-Wise Operations',
        'NumPy Linear Algebra: Dot Products, Matrix Multiplication (np.matmul / @), Inverses, SVD',
        'NumPy Statistics & Random Module: Distributions, Seeds, Sampling, Aggregations',
        'Pandas Series and DataFrames: Creation, Structure, Indexing (.loc, .iloc)',
        'Data Ingestion: Reading and Writing CSV, JSON, Parquet, Excel, SQL with Pandas',
        'Data Cleaning: Handling Missing Values (dropna, fillna, interpolate), Duplicates',
        'Data Transformations: apply(), map(), applymap(), string and datetime operations',
        'Grouping and Aggregation: groupby(), agg(), transform(), Pivot Tables, melt()',
        'Merging Data: merge() (inner, left, right, outer), concat(), join()',
        'Time Series Data: DatetimeIndex, Resampling, Rolling Windows, Shifting, Lagging',
        'Data Visualization: Matplotlib Figure/Axes hierarchy, Line, Scatter, Bar, Histogram',
        'Advanced Visualization: Seaborn Heatmaps, Pairplots, Boxplots, Violin Plots',
        'Machine Learning Fundamentals: Supervised vs Unsupervised vs Reinforcement Learning',
        'ML Workflow: Problem Formulation, Train/Validation/Test Splits, Data Leakage',
        'Feature Engineering: Scaling (StandardScaler, MinMaxScaler), One-Hot Encoding, Ordinal Encoding',
        'Handling Class Imbalance: SMOTE, Undersampling, Oversampling, Class Weights',
        'Scikit-Learn Estimator API: fit(), transform(), predict(), predict_proba()',
        'Linear Regression: Ordinary Least Squares (OLS), Cost Function (MSE), Gradient Descent',
        'Regularized Linear Models: Ridge (L2), Lasso (L1), ElasticNet',
        'Logistic Regression for Classification: Sigmoid, Log-Loss, Decision Boundaries',
        'Classification Metrics: Confusion Matrix, Precision, Recall, F1-Score, ROC-AUC Curve',
        'Decision Trees: CART Algorithm, Gini Impurity, Entropy, Information Gain, Pruning',
        'Ensemble Learning: Bagging vs Boosting, Random Forests Classifier/Regressor',
        'Gradient Boosting Machines: XGBoost, LightGBM, CatBoost Architectures & Tuning',
        'Unsupervised Learning: K-Means Clustering, Elbow Method, Silhouette Score',
        'Dimensionality Reduction: Principal Component Analysis (PCA) & Variance Explained',
        'ML Pipelines & Hyperparameter Tuning: GridSearchCV, RandomizedSearchCV, Cross-Validation',
      ]
    },
    {
      'part': 'Part 2: Deep Learning, Neural Networks & Generative AI',
      'topics': [
        'Deep Learning Foundations: Biological vs Artificial Neurons, Perceptrons',
        'Neural Network Architecture: Layers, Weights, Biases, Feedforward Process',
        'Activation Functions: ReLU, Leaky ReLU, Sigmoid, Tanh, Softmax, GELU',
        'Loss Functions: Binary Cross-Entropy, Categorical Cross-Entropy, MSE, MAE',
        'Backpropagation: Chain Rule, Computational Graphs, Automatic Differentiation',
        'Optimization Algorithms: SGD, Momentum, RMSprop, Adam, AdamW, Learning Rate Schedules',
        'PyTorch Basics: Tensors, CUDA/GPU Acceleration, Tensor Operations, Autograd',
        'Building Models in PyTorch: nn.Module, nn.Linear, nn.Sequential, Forward Pass',
        'PyTorch Training Loop: Dataset, DataLoader, Zero Grad, Backward, Optimizer Step',
        'Regularization in Deep Learning: Dropout, Weight Decay, Early Stopping, Batch Normalization',
        'Convolutional Neural Networks (CNN): Convolution, Stride, Padding, Pooling, Image Processing',
        'Recurrent Neural Networks (RNN), LSTM, and GRU for Sequential/Text Data',
        'The Transformer Revolution: Attention Is All You Need, Self-Attention Mechanism',
        'Transformer Architecture: Multi-Head Attention, Positional Encoding, Encoder-Decoder Stacks',
        'Large Language Models (LLMs): Pre-training, Fine-Tuning, RLHF, Direct Preference Optimization',
        'Generative AI APIs: OpenAI API, Gemini API, Anthropic API Integration in Python',
        'Prompt Engineering: Zero-Shot, Few-Shot, Chain-of-Thought (CoT), ReAct Framework',
        'Embeddings: Text-to-Vector Representations, Cosine Similarity, Vector Databases (Pinecone, Chroma, Qdrant)',
        'Retrieval-Augmented Generation (RAG): Document Ingestion, Chunking, Indexing, Retrieval, Generation',
        'AI Agents & Orchestration Frameworks: LangChain, LlamaIndex, Function Calling, Tool Use',
      ]
    },
    {
      'part': 'Part 3: Containerization (Docker) & Cloud Deployment (AWS)',
      'topics': [
        'Containerization Concepts: Virtual Machines vs Containers, Linux Namespaces & cgroups',
        'Installing Docker: Docker Engine, Docker Desktop, Docker Architecture (Client-Server)',
        'Docker CLI Essentials: docker run, ps, stop, rm, images, rmi, logs, exec',
        'Writing Dockerfiles: FROM, WORKDIR, COPY, RUN, ENV, EXPOSE, CMD, ENTRYPOINT',
        'Docker Image Optimization: Layer Caching, Minimizing Image Size, .dockerignore',
        'Multi-Stage Docker Builds for Python Applications',
        'Docker Storage: Volumes (Named Volumes) vs Bind Mounts for Data Persistence',
        'Docker Networking: Bridge, Host, None, and Custom Networks',
        'Multi-Container Orchestration with Docker Compose: docker-compose.yml Syntax, Services, Networks',
        'Cloud Computing Fundamentals: IaaS, PaaS, SaaS, AWS Global Infrastructure (Regions, AZs)',
        'AWS IAM: Users, Groups, Roles, Policies, Principle of Least Privilege',
        'AWS EC2: Instance Types, Security Groups, Key Pairs, Launching Ubuntu Python Servers',
        'AWS S3: Buckets, Objects, Permissions, Hosting Static Assets & Storing Media',
        'AWS RDS: Managed PostgreSQL/MySQL Instances, Automated Backups, Multi-AZ',
        'Month 5 Capstone: Dockerized AI RAG Application Deployed on AWS with Vector Search',
      ]
    }
  ];

  // Month 6: Real-World Projects + Interview Preparation - 55 Topics
  final month6Parts = [
    {
      'part': 'Part 1: Production Software Engineering & CI/CD',
      'topics': [
        'Software Architecture Patterns: Monolith, Microservices, Clean Architecture, Hexagonal',
        'Domain-Driven Design (DDD) Principles: Entities, Value Objects, Repositories, Services',
        '12-Factor App Methodology for Cloud-Native Applications',
        'Code Quality & Linters: Black, Flake8, Ruff, Isort, Pre-commit Hooks',
        'Comprehensive Testing Strategies: Unit Tests, Integration Tests, End-to-End (E2E) Tests',
        'Advanced pytest: Fixtures, Parameterize, Markers, Coverage Reports (pytest-cov)',
        'Continuous Integration (CI) with GitHub Actions: Workflows, Jobs, Steps, Action Marketplace',
        'Continuous Deployment (CD): Automated Testing, Building Docker Images, Pushing to ECR',
        'Web Application Security: OWASP Top 10 Vulnerabilities and Python Mitigations',
        'Secrets Management: Environment Variables, HashiCorp Vault, AWS Secrets Manager',
        'Logging, Monitoring & Observability: Structured Logging (structlog), ELK Stack, Prometheus & Grafana',
        'Distributed Tracing: OpenTelemetry, Sentry for Error Tracking and Performance APM',
        'Performance Profiling: cProfile, line_profiler, memory_profiler, Py-Spy',
        'Concurrency Patterns in Python: Threading, Multiprocessing, concurrent.futures.ThreadPoolExecutor',
        'C-Extensions, Cython & PyO3 (Rust bindings) for Extreme Python Performance',
      ]
    },
    {
      'part': 'Part 2: Real-World Industry Projects',
      'topics': [
        'Project 1: High-Concurrency Real-Time Financial Market Tracker (Architecture & Sockets)',
        'Project 1: Data Streaming Pipeline with Apache Kafka / Redis Streams',
        'Project 1: Real-Time Alerts, Candlestick Aggregations & Database Archival',
        'Project 2: Enterprise SaaS Multi-Tenant Platform (Tenant Isolation & Routing)',
        'Project 2: Dynamic Schema vs Shared Database Architecture',
        'Project 2: Subscription Billing Integration with Stripe API & Webhooks',
        'Project 2: Role-Based Access Control (RBAC) & Organization Hierarchies',
        'Project 3: AI Autonomous Customer Support Agent (System Architecture)',
        'Project 3: Conversation Memory & Context Management with Redis',
        'Project 3: Semantic Routing, Query Classification & Tool Execution',
        'Project 3: Human-in-the-Loop Approval Workflow & Fallback Strategies',
        'Project 4: Scalable Video Transcoding & Processing Worker System',
        'Project 4: Asynchronous Task Distribution with Celery & SQS',
        'Project 4: FFmpeg Python Wrapper, Chunk Processing & S3 Upload',
        'Project 5: Distributed Web Crawler & Scraping Engine (Scrapy + Playwright)',
        'Project 5: Proxy Rotation, User-Agent Spoofing, CAPTCHA Handling',
        'Project 5: Clean Data Pipeline, Deduplication & PostgreSQL Storage',
        'End-to-End Project Deployment: Infrastructure as Code (Terraform)',
        'End-to-End Project Deployment: Zero-Downtime Blue/Green Deployments',
        'Code Auditing, Production Hardening & Disaster Recovery Drill',
      ]
    },
    {
      'part': 'Part 3: Python & AI Technical Interview Preparation',
      'topics': [
        'Technical Interview Strategies: Whiteboard Coding, System Design & Behavioral Rounds',
        'Python Core Mastery Interview Questions: Internals, Memory Management, GC & Ref Counting',
        'Python Dunder Methods, Iterators, Generators & Metaclass Interview Challenges',
        'Top LeetCode Patterns: Two Pointers, Sliding Window, Fast & Slow Pointers',
        'Top LeetCode Patterns: In-place Reversal of a LinkedList, Monotonic Stack',
        'Top LeetCode Patterns: Two Heaps, K-way Merge, Top K Frequent Elements',
        'Top LeetCode Patterns: Subsets, Permutations, Combination Sum (Backtracking)',
        'Top LeetCode Patterns: 0/1 Knapsack, Longest Increasing Subsequence (Dynamic Programming)',
        'Top LeetCode Patterns: Graph Traversal, Topological Sort, Shortest Path Problems',
        'System Design Fundamentals: Scalability, Horizontal vs Vertical Scaling, Load Balancing',
        'System Design: Database Sharding, Replication, Consistency Models (CAP Theorem)',
        'System Design: Caching Strategies (Write-Through, Write-Back, Cache-Aside), CDN',
        'System Design Case Study: Design a URL Shortener (TinyURL)',
        'System Design Case Study: Design a Real-Time Chat System (WhatsApp / Slack)',
        'System Design Case Study: Design a Scalable Newsfeed System (Twitter / Instagram)',
        'AI / ML Interview Questions: Overfitting vs Underfitting, Bias-Variance Tradeoff, Regularization',
        'AI / ML Interview Questions: Transformers, Attention Mechanisms, Fine-Tuning LLMs',
        'Resume Optimization for Senior Python & AI Engineer Roles',
        'Open-Source Contributions & High-Impact GitHub Portfolio Presentation',
        'Behavioral Interview Mastery (STAR Method) & Salary Negotiation Tactics',
      ]
    }
  ];

  final allMonths = [
    {'monthNumber': 1, 'monthName': 'Month 1: Complete Python', 'expectedCount': 95, 'parts': month1Parts},
    {'monthNumber': 2, 'monthName': 'Month 2: Advanced Python + DSA', 'expectedCount': 60, 'parts': month2Parts},
    {'monthNumber': 3, 'monthName': 'Month 3: DSA + SQL + Backend', 'expectedCount': 70, 'parts': month3Parts},
    {'monthNumber': 4, 'monthName': 'Month 4: Backend + Django + FastAPI + Git', 'expectedCount': 60, 'parts': month4Parts},
    {'monthNumber': 5, 'monthName': 'Month 5: AI + ML + Generative AI + Docker + AWS', 'expectedCount': 65, 'parts': month5Parts},
    {'monthNumber': 6, 'monthName': 'Month 6: Real-World Projects + Interview Preparation', 'expectedCount': 55, 'parts': month6Parts},
  ];

  final textBuffer = StringBuffer();
  textBuffer.writeln('# PYTHON & AI DEVELOPER ROADMAP - 6 MONTHS COMPREHENSIVE CURRICULUM');
  textBuffer.writeln('# TOTAL TOPICS: 405 ORIGINAL MAIN TOPICS\n');

  int globalOrder = 1;

  for (final m in allMonths) {
    final mNum = m['monthNumber'] as int;
    final mName = m['monthName'] as String;
    final expectedCount = m['expectedCount'] as int;
    final parts = m['parts'] as List<Map<String, dynamic>>;

    textBuffer.writeln('========================================================');
    textBuffer.writeln('$mName ($expectedCount Topics)');
    textBuffer.writeln('========================================================\n');

    int monthCount = 0;
    for (final p in parts) {
      final pName = p['part'] as String;
      final topics = p['topics'] as List<String>;

      textBuffer.writeln('----------------------------------------');
      textBuffer.writeln(pName);
      textBuffer.writeln('----------------------------------------');

      for (int i = 0; i < topics.length; i++) {
        monthCount++;
        final topicTitle = topics[i];
        textBuffer.writeln('$globalOrder. $topicTitle');

        allTopics.add({
          'orderIndex': globalOrder,
          'month': mNum,
          'monthTitle': mName,
          'section': pName,
          'title': topicTitle,
          'status': 'incomplete',
          'priority': globalOrder % 3 == 0 ? 'High' : (globalOrder % 2 == 0 ? 'Medium' : 'Normal'),
          'difficulty': mNum <= 2 ? 'Beginner' : (mNum <= 4 ? 'Intermediate' : 'Advanced'),
          'estimatedMinutes': 90,
          'notes': 'Study notes for $topicTitle. Focus on practical implementation and hands-on coding exercises.',
          'subtasks': [
            {'title': 'Read core theory and concept documentation', 'isCompleted': false},
            {'title': 'Write code examples and verify execution', 'isCompleted': false},
            {'title': 'Build a mini-exercise or test problem', 'isCompleted': false},
          ],
          'resources': [
            {'title': 'Official Documentation', 'url': 'https://docs.python.org/3/'},
            {'title': 'Practical Code Examples', 'url': 'https://github.com'},
          ]
        });

        globalOrder++;
      }
      textBuffer.writeln();
    }

    if (monthCount != expectedCount) {
      print('ERROR: $mName count mismatch! Expected $expectedCount but got $monthCount');
      exit(1);
    }
  }

  if (allTopics.length != 405) {
    print('ERROR: Total topics count is ${allTopics.length}, expected 405!');
    exit(1);
  }

  print('SUCCESS: Verified exactly ${allTopics.length} topics across 6 months!');

  // Save JSON
  final jsonFile = File('assets/curriculum/python_ai_roadmap.json');
  jsonFile.parent.createSync(recursive: true);
  jsonFile.writeAsStringSync(jsonEncode({
    'version': 1,
    'groupName': 'Python & AI Developer Roadmap',
    'duration': '6 Months',
    'totalTopics': 405,
    'topics': allTopics,
  }));

  // Save text files
  File('assets/curriculum/pasted_text.txt').writeAsStringSync(textBuffer.toString());
  File('Pasted text.txt').writeAsStringSync(textBuffer.toString());

  print('Files written successfully:');
  print(' - assets/curriculum/python_ai_roadmap.json');
  print(' - assets/curriculum/pasted_text.txt');
  print(' - Pasted text.txt');
}
