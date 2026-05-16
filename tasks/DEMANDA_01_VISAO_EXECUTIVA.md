# Demanda 01 — Visão Executiva de Risco e Relacionamento

## Solicitante fictícia

Mariana Torres  
Gerente de Analytics e Estratégia

## Pedido

> Preciso de uma visão executiva da base de clientes, mostrando risco, relacionamento, produtos, churn e oportunidades de ação. Quero entender quais segmentos merecem atenção e quais clientes devem ser priorizados.

## Entregáveis esperados

1. Resumo executivo do banco
2. Segmentos com maior risco
3. Clientes prioritários para ação
4. Produtos com maior exposição
5. Ações recomendadas de retenção
6. Base exportável para Excel

## Arquivo SQL

```text
sql/postgres/16_demanda_01_visao_executiva.sql
```

## Tabelas usadas

```text
gold.kpi_executivo_banco
gold.visao_executiva_cliente
gold.kpi_produtos_executivo
```

## O que observar

- Clientes em alto risco
- Clientes com churn crítico
- Saldo NPL 90+
- Segmentos com score de churn elevado
- Ações recomendadas de retenção
- Produtos com maior valor operado
