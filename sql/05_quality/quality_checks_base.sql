-- Checks de qualidade base

-- Clientes sem ID
SELECT COUNT(*) AS qtd_clientes_sem_id
FROM silver.clientes
WHERE cliente_id IS NULL;

-- Clientes sem data de nascimento
SELECT COUNT(*) AS qtd_clientes_sem_data_nascimento
FROM silver.clientes
WHERE data_nascimento IS NULL;

-- Clientes com renda nula
SELECT COUNT(*) AS qtd_clientes_sem_renda
FROM silver.clientes
WHERE renda_mensal IS NULL;

-- Contratos sem cliente
SELECT COUNT(*) AS qtd_contratos_sem_cliente
FROM silver.contratos_credito c
LEFT JOIN silver.clientes cli
    ON c.cliente_id = cli.cliente_id
WHERE cli.cliente_id IS NULL;

-- Parcelas sem contrato
SELECT COUNT(*) AS qtd_parcelas_sem_contrato
FROM silver.parcelas_credito p
LEFT JOIN silver.contratos_credito c
    ON p.contrato_id = c.contrato_id
WHERE c.contrato_id IS NULL;
