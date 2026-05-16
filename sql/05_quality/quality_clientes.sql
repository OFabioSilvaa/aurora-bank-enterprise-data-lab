-- Consultas de qualidade para clientes

SELECT *
FROM meta.quality_clientes
ORDER BY check_name;

SELECT *
FROM meta.contagem_tabelas_clientes
ORDER BY tabela;

-- Clientes com dados incompletos
SELECT
    cliente_id,
    nome,
    renda_mensal_original,
    renda_mensal_tratada,
    score_credito,
    uf,
    flag_renda_nula,
    flag_score_ausente,
    flag_uf_ausente
FROM silver.clientes
WHERE flag_renda_nula = TRUE
   OR flag_score_ausente = TRUE
   OR flag_uf_ausente = TRUE
LIMIT 100;

-- Distribuição por segmento
SELECT
    segmento,
    COUNT(*) AS qtd_clientes,
    AVG(renda_mensal_tratada) AS renda_media,
    AVG(score_credito) AS score_medio
FROM silver.clientes
GROUP BY segmento
ORDER BY qtd_clientes DESC;

-- Distribuição por faixa etária
SELECT
    faixa_etaria,
    COUNT(*) AS qtd_clientes,
    AVG(renda_mensal_tratada) AS renda_media,
    AVG(score_credito) AS score_medio
FROM silver.clientes
GROUP BY faixa_etaria
ORDER BY faixa_etaria;

-- Cliente 360 base por engajamento
SELECT
    cluster_engajamento_digital,
    COUNT(*) AS qtd_clientes
FROM sdx.cliente_360_base
GROUP BY cluster_engajamento_digital
ORDER BY qtd_clientes DESC;
