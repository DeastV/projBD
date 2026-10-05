# ZooDB — Relational Database System & REST API

[![Database](https://img.shields.io/badge/Database-PostgreSQL-blue.svg)](https://www.postgresql.org/)
[![Backend](https://img.shields.io/badge/Backend-Flask%20%7C%20Python-green.svg)](https://flask.palletsprojects.com/)
[![Driver](https://img.shields.io/badge/Driver-psycopg3%20Connection%20Pool-brightgreen.svg)]()
[![Container](https://img.shields.io/badge/Container-Docker-2496ED.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A relational database engineering project and backend web service designed for managing zoological park operations, ticket sales, enclosure access, and visitor voting campaigns. The project covers relational schema design, integrity constraints, multi-dimensional OLAP analytics with `GROUPING SETS` and `CUBE`, database indexing, and a Flask REST API with PostgreSQL connection pooling.

Developed as part of the **Databases (Bases de Dados)** course at **Instituto Superior Técnico (IST), Universidade de Lisboa**.

---

## Architecture Overview

```text
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
* **Conceptual & Logical Design:** Normalized schema modeling zones, enclosures (*recintos*), biological species, individual animals, medical checkups, ticketing, access rights, and sales transactions.
* **Integrity Constraints:** Enforced via Primary Keys, Composite Foreign Keys with referential triggers/cascades, and check constraints (e.g., enclosure capacities, date validations).

### 2. Multi-Dimensional Analytics (OLAP)
* **Advanced Aggregations:** Complex queries leveraging SQL OLAP operators:
  * `GROUPING SETS ((), (dia_da_semana), (mes))` to compute overall, monthly, and day-of-week attendance percentages.
  * `CUBE (id_zona, mes)` to evaluate daily ticket averages across zones and time dimensions simultaneously.

### 3. ACID Transactions
* Atomic transaction management using `with conn.transaction():`:
  * Multi-table ticket sale workflow (`venda` + `bilhete` + `acesso`).
  * Enclosure popularity voting verifying ticket validity and zone access before updating vote counts and ticket state.

### 4. RESTful API with Connection Pooling
* Python Flask backend implementing clean REST endpoints.
* Connection reuse managed via `psycopg_pool.ConnectionPool` for concurrent request handling.

---

## Project Structure

```text
zoo-management-database/
├── app.py                     # Flask REST API implementation with psycopg connection pool
├── zoo-database-design.ipynb  # Interactive notebook with ER model, DDL, queries & schema design
├── povoar_vendas.sql          # Bulk transactional data population script
├── LICENSE                    # MIT License
├── .gitignore                 # Exclusion rules for python and checkpoints
└── README.md                  # Project documentation
```

---

## API Endpoints Reference

The Flask application (`app.py`) exposes the following endpoints:

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/zona/<id_zona>/` | Lists all enclosures within a zone along with resident species and animal counts. |
| `POST` / `PUT` | `/recinto/<id_recinto>/voto/<bid>/` | Casts a visitor vote for an enclosure using a valid ticket (`bid`), validating zone access permissions in a transaction. |
| `POST` | `/venda/` | Executes an atomic purchase transaction for one or more tickets with specified zone accesses and client NIF. |

---

## Running Locally

### 1. Prerequisites
* Python 3.9+
* Docker & Docker Compose (or local PostgreSQL instance)

### 2. Setup PostgreSQL Container
```bash
docker run --name zoo-postgres \
  -e POSTGRES_USER=app \
  -e POSTGRES_PASSWORD=app \
  -e POSTGRES_DB=app \
  -p 5432:5432 -d postgres
```

### 3. Initialize & Populate Database
Populate database tables and sales records:
```bash
psql -h localhost -U app -d app -f povoar_vendas.sql
```

### 4. Run the Flask API
```bash
pip install flask psycopg[binary,pool]
python3 app.py
```
*Note: `app.py` connects by default to `postgresql://app:app@postgres/app`. When running outside a Docker network, ensure `postgres` resolves to `localhost` in `/etc/hosts` or set your connection string accordingly.*

---

## Authors & Acknowledgments

* **David Vasques** ([@DeastV](https://github.com/DeastV))
* **Leonor Machado** ([@leonormm](https://github.com/leonormm))
* **João Costa** ([@JCostaJ](https://github.com/JCostaJ))

Collaborative group project developed for Bases de Dados at Instituto Superior Técnico, Universidade de Lisboa.

---

## License

This project is licensed under the [MIT License](LICENSE).
