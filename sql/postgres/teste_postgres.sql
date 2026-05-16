-- Teste PostgreSQL — Aurora Bank

SELECT 
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema IN ('silver', 'sdx', 'gold', 'meta')
ORDER BY table_schema, table_name;

SELECT COUNT(*) AS qtd_clientes
FROM silver.clientes;

SELECT *
FROM sdx.cliente_360_v3
LIMIT 10;

SELECT
    produto_credito,
    COUNT(*) AS qtd_contratos,
    ROUND(SUM(valor_contratado)::numeric, 2) AS valor_contratado,
    ROUND(SUM(saldo_devedor_tratado)::numeric, 2) AS saldo_devedor
FROM silver.contratos_credito
GROUP BY produto_credito
ORDER BY saldo_devedor DESC;
