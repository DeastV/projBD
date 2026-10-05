# ZooDB — Relational Database System & REST API

[![Database](https://img.shields.io/badge/Database-PostgreSQL-blue.svg)](https://www.postgresql.org/)
[![Backend](https://img.shields.io/badge/Backend-Flask%20%7C%20Python-green.svg)](https://flask.palletsprojects.com/)
[![Driver](https://img.shields.io/badge/Driver-psycopg3%20Connection%20Pool-brightgreen.svg)]()
[![Container](https://img.shields.io/badge/Container-Docker-2496ED.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A complete relational database engineering project and backend web service designed for managing a modern zoological park. The system encompasses relational domain modeling, SQL schema design, advanced analytical queries, performance indexing, ACID transactions, and a REST API with PostgreSQL connection pooling.

Developed as part of the **Databases (Bases de Dados)** course at **Instituto Superior Técnico (IST), Universidade de Lisboa**.

---

## Architecture Overview

```
 +--------------------+       HTTP Requests       +-----------------------+
 |  Client / Browser  | <=======================> |  Flask REST API       |
 +--------------------+                           |  (app.py)             |
                                                  +-----------+-----------+
                                                              |
                                             psycopg_pool     | Connection Pool
                                                              v
                                                  +-----------------------+
                                                  |  PostgreSQL Database  |
                                                  |  (Docker Container)   |
                                                  +-----------------------+
```

---

## Core Features & Technical Highlights

### 1. Relational Modeling & Schema Design
* **Conceptual & Logical Design:** Normalized schema (3NF/BCNF) modeling zones, enclosures (*recintos*), biological species, individual animals, medical checkups, ticketing, and sales.
* **Integrity Constraints:** Strict domain rules enforced via Primary Keys, Composite Foreign Keys with referential actions (`CASCADE`, `SET NULL`), and `CHECK` constraints (e.g., enclosure capacities, date validations).

### 2. Analytical SQL & Performance Tuning
* **Advanced Queries:** Aggregations with `GROUP BY`, multi-table joins, subqueries, and window functions to extract business intelligence (e.g. popular exhibits, revenue statistics).
* **Indexing Strategy:** B-Tree indexes created on high-cardinality foreign keys and search filters to optimize query execution times verified via `EXPLAIN ANALYZE`.

### 3. ACID Transactions & Concurrency Control
* Multi-statement transactional workflows ensuring atomicity and consistency during concurrent ticket purchasing and stock decrements.
* Proper isolation levels avoiding race conditions (lost updates, dirty reads).

### 4. RESTful API with Connection Pooling
* Python Flask backend implementing clean REST endpoints.
* High-performance connection management using `psycopg_pool.ConnectionPool` for connection reuse across concurrent HTTP worker requests.

---

## Project Structure

```
.
├── app.py                     # Flask REST API implementation with psycopg pool
├── entrega-bd-02-30.ipynb     # Jupyter Notebook containing ER model, DDL, queries & transactions
├── povoar_vendas.sql          # Bulk transactional data population script
├── LICENSE                    # MIT License
├── .gitignore                 # Exclusion rules for python and checkpoints
└── README.md                  # Project documentation
```

---

## API Endpoints Overview

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/zona/<id_zona>/` | Lists all enclosures, species, and animal counts within a zone. |
| `POST` | `/animal/novo/` | Registers a new animal inside a specified enclosure. |
| `POST` | `/bilhete/comprar/` | Executes an atomic transaction to issue tickets and register sales. |
| `GET` | `/estatisticas/` | Returns aggregated metrics on visitor attendance and revenue. |

---

## Running Locally

### 1. Prerequisites
* Python 3.9+
* Docker & Docker Compose (or local PostgreSQL instance)

### 2. Setup PostgreSQL
Start the PostgreSQL container:
```bash
docker run --name zoo-postgres -e POSTGRES_USER=app -e POSTGRES_PASSWORD=app -e POSTGRES_DB=app -p 5432:5432 -d postgres
```

### 3. Initialize & Populate Database
Execute the notebook `entrega-bd-02-30.ipynb` or run the population script:
```bash
psql -h localhost -U app -d app -f povoar_vendas.sql
```

### 4. Run the Flask API
```bash
pip install flask psycopg[binary,pool]
python3 app.py
```
The server will start at `http://localhost:5000`.

---

## Authors

* **David Vasques** ([@DeastV](https://github.com/DeastV))
* **Leonor Machado** ([@leonormm](https://github.com/leonormm))
* **João Costa** ([@JCostaJ](https://github.com/JCostaJ))

*Instituto Superior Técnico — Universidade de Lisboa (2025/2026)*
