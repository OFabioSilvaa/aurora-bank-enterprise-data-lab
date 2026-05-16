SELECT 
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema IN ('bronze', 'silver', 'sdx', 'gold', 'meta')
ORDER BY table_schema, table_name;

SELECT *
FROM meta.quality_clientes
ORDER BY check_name;

SELECT *
FROM meta.quality_contas_transacoes
ORDER BY check_name;

SELECT *
FROM sdx.cliente_360
LIMIT 10;
