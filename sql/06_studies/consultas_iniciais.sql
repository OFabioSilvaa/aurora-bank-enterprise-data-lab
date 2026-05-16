-- Consultas iniciais do Aurora Bank

-- 1. Clientes por segmento
SELECT
    segmento,
    COUNT(*) AS qtd_clientes
FROM silver.clientes
GROUP BY segmento
ORDER BY qtd_clientes DESC;

-- 2. Clientes por faixa etária
SELECT
    faixa_etaria,
    COUNT(*) AS qtd_clientes,
    AVG(renda_mensal) AS renda_media,
    AVG(score_credito) AS score_medio
FROM silver.clientes
GROUP BY faixa_etaria
ORDER BY faixa_etaria;

-- 3. Carteira de crédito por produto
SELECT
    produto_credito,
    COUNT(DISTINCT contrato_id) AS qtd_contratos,
    SUM(valor_contratado) AS valor_contratado,
    SUM(saldo_devedor) AS saldo_devedor,
    AVG(taxa_mensal) AS taxa_media
FROM silver.contratos_credito
GROUP BY produto_credito
ORDER BY saldo_devedor DESC;

-- 4. Inadimplência por bucket
SELECT
    bucket_atraso,
    COUNT(*) AS qtd_contratos,
    SUM(saldo_devedor) AS saldo_devedor
FROM silver.contratos_credito
GROUP BY bucket_atraso
ORDER BY saldo_devedor DESC;

-- 5. Clientes com risco de churn
SELECT
    cliente_id,
    dias_sem_movimentacao,
    dias_sem_login,
    flag_churn
FROM sdx.churn_features
WHERE flag_churn = TRUE
LIMIT 100;
