SELECT
    produto_credito,
    COUNT(*) AS qtd_contratos,
    ROUND(SUM(valor_contratado)::numeric, 2) AS valor_contratado,
    ROUND(SUM(saldo_devedor_tratado)::numeric, 2) AS saldo_devedor
FROM silver.contratos_credito
GROUP BY produto_credito
ORDER BY saldo_devedor DESC;


SELECT *
FROM SDX.cliente_360_v3
LIMIT 10;
