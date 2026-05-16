-- Estudos iniciais — Crédito

-- 1. Funil de crédito por produto
SELECT
    produto_credito,
    COUNT(*) AS qtd_propostas,
    SUM(CASE WHEN status_proposta = 'APROVADA' THEN 1 ELSE 0 END) AS qtd_aprovadas,
    SUM(CASE WHEN status_proposta = 'REPROVADA' THEN 1 ELSE 0 END) AS qtd_reprovadas,
    ROUND(SUM(CASE WHEN status_proposta = 'APROVADA' THEN 1 ELSE 0 END)::DOUBLE / COUNT(*), 4) AS taxa_aprovacao,
    ROUND(SUM(valor_solicitado), 2) AS valor_solicitado
FROM silver.propostas_credito
WHERE flag_cliente_orfao = FALSE
GROUP BY produto_credito
ORDER BY qtd_propostas DESC;

-- 2. Carteira por produto
SELECT
    produto_credito,
    COUNT(DISTINCT contrato_id) AS qtd_contratos,
    ROUND(SUM(valor_contratado), 2) AS valor_contratado,
    ROUND(SUM(saldo_devedor_tratado), 2) AS saldo_devedor,
    ROUND(AVG(taxa_mensal), 4) AS taxa_media,
    ROUND(SUM(CASE WHEN bucket_atraso = 'NPL_90_PLUS' THEN saldo_devedor_tratado ELSE 0 END), 2) AS saldo_npl_90
FROM silver.contratos_credito
WHERE flag_cliente_orfao = FALSE
GROUP BY produto_credito
ORDER BY saldo_devedor DESC;

-- 3. Inadimplência por bucket
SELECT
    bucket_atraso,
    COUNT(*) AS qtd_contratos,
    ROUND(SUM(saldo_devedor_tratado), 2) AS saldo_devedor
FROM silver.contratos_credito
GROUP BY bucket_atraso
ORDER BY saldo_devedor DESC;

-- 4. Safra de contratação
SELECT
    safra_contratacao,
    produto_credito,
    COUNT(*) AS qtd_contratos,
    ROUND(SUM(valor_contratado), 2) AS valor_contratado,
    ROUND(SUM(saldo_devedor_tratado), 2) AS saldo_devedor,
    ROUND(AVG(taxa_mensal), 4) AS taxa_media
FROM silver.contratos_credito
GROUP BY safra_contratacao, produto_credito
ORDER BY safra_contratacao, produto_credito;

-- 5. Aderência à precificação
SELECT
    aderencia_precificacao,
    COUNT(*) AS qtd_propostas,
    ROUND(AVG(taxa_ofertada), 4) AS taxa_media,
    ROUND(SUM(valor_solicitado), 2) AS valor_solicitado
FROM sdx.precificacao_credito
GROUP BY aderencia_precificacao
ORDER BY qtd_propostas DESC;

-- 6. Cliente 360 com crédito
SELECT
    cliente_id,
    nome,
    segmento,
    rating_cliente,
    qtd_contratos_credito,
    valor_total_contratado_credito,
    saldo_devedor_credito,
    maior_atraso_credito,
    saldo_npl_90,
    cluster_risco_credito,
    flag_risco_credito
FROM sdx.cliente_360_v3
ORDER BY saldo_devedor_credito DESC
LIMIT 100;

-- 7. Clientes com maior risco de crédito
SELECT
    cliente_id,
    nome,
    segmento,
    rating_cliente,
    saldo_devedor_credito,
    maior_atraso_credito,
    saldo_npl_90,
    qtd_parcelas_credito_com_atraso,
    valor_parcelas_credito_em_atraso
FROM sdx.cliente_360_v3
WHERE flag_risco_credito = TRUE
ORDER BY saldo_npl_90 DESC
LIMIT 100;
