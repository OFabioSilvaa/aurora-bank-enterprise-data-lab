-- ============================================================
-- Testes da gold.dw_contratacao
-- ============================================================

SELECT *
FROM meta.quality_dw_contratacao
ORDER BY check_name;

SELECT *
FROM gold.dw_contratacao
LIMIT 20;

-- Visão resumida por produto / subproduto / origem
SELECT
    produto,
    subproduto,
    origem,
    COUNT(*) AS qtd_contratos,
    ROUND(SUM(valor_contratado)::numeric, 2) AS valor_contratado,
    ROUND(SUM(saldo_devedor)::numeric, 2) AS saldo_devedor,
    SUM(flg_apto_renovacao) AS qtd_apto_renovacao,
    SUM(flg_renovacao) AS qtd_renovacao,
    SUM(flg_inadimplente) AS qtd_inadimplente,
    SUM(flg_npl_90) AS qtd_npl_90
FROM gold.dw_contratacao
GROUP BY
    produto,
    subproduto,
    origem
ORDER BY valor_contratado DESC;

-- Top clientes aptos à renovação
SELECT
    num_pes,
    nome,
    produto,
    subproduto,
    canal,
    origem,
    valor_contratado,
    saldo_devedor,
    taxa_mensal,
    prazo_meses,
    dias_atraso_atual,
    score_credito,
    rating_cliente,
    segmento,
    flg_apto_renovacao,
    flg_renovacao,
    flg_inadimplente
FROM gold.dw_contratacao
WHERE flg_apto_renovacao = 1
ORDER BY
    saldo_devedor DESC,
    score_credito DESC
LIMIT 100;

-- Contratos com maior risco
SELECT
    num_pes,
    nome,
    produto,
    subproduto,
    origem,
    valor_contratado,
    saldo_devedor,
    dias_atraso_atual,
    bucket_atraso,
    maior_atraso_parcela,
    valor_parcelas_em_atraso,
    flg_inadimplente,
    flg_npl_90
FROM gold.dw_contratacao
WHERE flg_inadimplente = 1
   OR flg_npl_90 = 1
ORDER BY
    flg_npl_90 DESC,
    dias_atraso_atual DESC,
    saldo_devedor DESC
LIMIT 100;
