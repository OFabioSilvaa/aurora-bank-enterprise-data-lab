-- Estudos iniciais com Clientes — Aurora Bank

-- 1. Quantos clientes existem por status?
SELECT
    status_cliente_core,
    COUNT(*) AS qtd_clientes
FROM silver.clientes
GROUP BY status_cliente_core
ORDER BY qtd_clientes DESC;

-- 2. Qual a renda média e score médio por segmento?
SELECT
    segmento,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(renda_mensal_tratada), 2) AS renda_media,
    ROUND(AVG(score_credito), 2) AS score_medio
FROM silver.clientes
GROUP BY segmento
ORDER BY renda_media DESC;

-- 3. Quais UFs concentram mais clientes?
SELECT
    uf,
    COUNT(*) AS qtd_clientes
FROM silver.clientes
GROUP BY uf
ORDER BY qtd_clientes DESC;

-- 4. Clientes com alto potencial de crédito
SELECT
    cliente_id,
    nome,
    uf,
    renda_mensal_tratada,
    score_credito,
    rating_cliente,
    segmento,
    cluster_potencial_credito
FROM sdx.cliente_360_base
WHERE cluster_potencial_credito = 'ALTO_POTENCIAL'
ORDER BY renda_mensal DESC
LIMIT 100;

-- 5. Clientes com baixa qualidade cadastral
SELECT
    cliente_id,
    nome,
    flag_renda_nula,
    flag_score_ausente,
    flag_data_nascimento_ausente,
    flag_uf_ausente
FROM silver.clientes
WHERE flag_renda_nula = TRUE
   OR flag_score_ausente = TRUE
   OR flag_data_nascimento_ausente = TRUE
   OR flag_uf_ausente = TRUE
LIMIT 100;
