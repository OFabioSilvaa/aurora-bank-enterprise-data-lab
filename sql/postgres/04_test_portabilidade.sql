-- ============================================================
-- Testes do domínio Portabilidade
-- ============================================================

SELECT *
FROM meta.quality_portabilidade
ORDER BY check_name;

SELECT *
FROM gold.dw_portabilidade
LIMIT 20;

-- Funil por banco origem
SELECT
    nome_banco_origem,
    segmento_concorrente,
    COUNT(*) AS qtd_solicitacoes,
    SUM(flg_portabilidade_paga) AS qtd_pagas,
    ROUND(SUM(valor_saldo_devedor)::NUMERIC, 2) AS saldo_solicitado,
    ROUND(SUM(CASE WHEN flg_portabilidade_paga = 1 THEN valor_saldo_devedor ELSE 0 END)::NUMERIC, 2) AS saldo_pago,
    ROUND(
        SUM(flg_portabilidade_paga)::NUMERIC / NULLIF(COUNT(*), 0),
        4
    ) AS taxa_conversao
FROM gold.dw_portabilidade
GROUP BY
    nome_banco_origem,
    segmento_concorrente
ORDER BY saldo_solicitado DESC;

-- Taxa origem x taxa ofertada por canal
SELECT
    canal,
    origem,
    COUNT(*) AS qtd_solicitacoes,
    ROUND(AVG(taxa_origem)::NUMERIC, 4) AS taxa_origem_media,
    ROUND(AVG(taxa_ofertada)::NUMERIC, 4) AS taxa_ofertada_media,
    ROUND(AVG(ganho_taxa)::NUMERIC, 4) AS ganho_taxa_medio,
    SUM(flg_portabilidade_paga) AS qtd_pagas
FROM gold.dw_portabilidade
GROUP BY
    canal,
    origem
ORDER BY qtd_solicitacoes DESC;

-- Clientes com maior valor portado
SELECT
    num_pes,
    produto,
    subproduto,
    nome_banco_origem,
    canal,
    origem,
    valor_saldo_devedor,
    taxa_origem,
    taxa_ofertada,
    ganho_taxa,
    valor_troco_liberado,
    status_portabilidade
FROM gold.dw_portabilidade
WHERE flg_portabilidade_paga = 1
ORDER BY valor_saldo_devedor DESC
LIMIT 100;

-- Motivos de perda
SELECT
    motivo_perda,
    COUNT(*) AS qtd,
    ROUND(SUM(valor_saldo_devedor)::NUMERIC, 2) AS saldo_envolvido
FROM gold.dw_portabilidade
WHERE flg_portabilidade_paga = 0
GROUP BY motivo_perda
ORDER BY qtd DESC;

-- Cliente 360 V4 com portabilidade
SELECT
    cliente_id,
    nome,
    segmento,
    rating_cliente,
    qtd_solicitacoes_portabilidade,
    qtd_portabilidades_pagas,
    saldo_solicitado_portabilidade,
    saldo_pago_portabilidade,
    troco_liberado_portabilidade,
    cluster_portabilidade
FROM sdx.cliente_360_v4
WHERE qtd_solicitacoes_portabilidade > 0
ORDER BY saldo_solicitado_portabilidade DESC
LIMIT 100;
