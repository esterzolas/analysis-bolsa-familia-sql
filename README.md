# 📊 Análise de Dados: Novo Bolsa Família (SQL & Performance Tuning)

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Data Analysis](https://img.shields.io/badge/Data_Analysis-SQL-orange?style=for-the-badge)
![Optimization](https://img.shields.io/badge/Focus-Performance-green?style=for-the-badge)

## 📌 Sobre o Projeto
Este projeto foi desenvolvido para processar, normalizar e analisar dados reais do programa governamental **Novo Bolsa Família**. O desafio principal foi estruturar um banco de dados relacional eficiente a partir de dados brutos e massivos, garantindo performance em consultas analíticas complexas.

> **Destaque:** O dataset contém milhões de registros de pagamentos, exigindo técnicas avançadas de otimização de banco de dados.

## 🎯 Desafios Técnicos Resolvidos

### 1. Modelagem e Normalização
Os dados públicos vêm desnormalizados (arquivos flat). Realizamos a modelagem relacional (DER) para garantir a integridade dos dados, criando tabelas separadas para `Beneficiários`, `Pagamentos` e `Municípios`, com chaves estrangeiras adequadas.

### 2. Otimização de Performance (Case Real)
Um dos maiores gargalos era a consulta de **"Mediana de Beneficiários por Município"**, que exigia contagens em tempo real na tabela de pagamentos (milhões de linhas).

**A Solução:**
Implementamos um **Gatilho (Trigger)** (`atualizar_contagem_beneficiarios`) que pré-calcula e armazena o total de beneficiários na tabela de municípios sempre que uma inserção ocorre.

**Resultados de Performance:**
| Métrica | Sem Otimização | Com Trigger/Índice |
| :--- | :--- | :--- |
| **Custo da Query** | Alto (Full Scan) | Baixo (Index Scan) |
| **Tempo de Resposta** | Lento | **Instantâneo** |

### 3. Consultas Analíticas Avançadas
O projeto inclui 10 consultas complexas para extração de insights, utilizando:
- **Window Functions:** Para cálculos de percentil e rankings.
- **Subqueries & Joins:** Para cruzar dados geográficos e financeiros.
- **Views:** Para abstrair a complexidade de relatórios recorrentes.

## 🛠️ Tecnologias Utilizadas
- **SQL (PostgreSQL):** Linguagem principal.
- **Stored Procedures & Triggers:** Automação de lógica de negócio.
- **Window Functions:** `PERCENTILE_CONT`, `RANK`, `OVER`.

## 📂 Como Reproduzir
1. Baixe os dados brutos no [Portal de Dados Abertos](https://dados.gov.br/).
2. Execute o script `src/01_create_tables.sql` para criar a estrutura.
3. Importe os dados.
4. Execute as consultas em `src/04_analytical_queries.sql`.

---
*Projeto desenvolvido como parte da disciplina de Sistemas de Banco de Dados (UFU).*
