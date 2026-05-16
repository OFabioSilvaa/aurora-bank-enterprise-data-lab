-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 13B — Correção coluna valor_total_em_atraso_acionado
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Problema:
-- Alguns testes/demandas usam a coluna:
-- gold.visao_executiva_cliente.valor_total_em_atraso_acionado
--
-- Porém ela não foi adicionada na criação original da visão executiva.
--
-- Solução:
-- Adicionar a coluna e preenchê-la a partir de sdx.cliente_360_v8.
-- ============================================================

ALTER TABLE gold.visao_executiva_cliente
ADD COLUMN IF NOT EXISTS valor_total_em_atraso_acionado NUMERIC(18, 2);

UPDATE gold.visao_executiva_cliente v
SET valor_total_em_atraso_acionado = COALESCE(c.valor_total_em_atraso_acionado, 0)
FROM sdx.cliente_360_v8 c
WHERE v.num_pes = c.cliente_id;

UPDATE gold.visao_executiva_cliente
SET valor_total_em_atraso_acionado = 0
WHERE valor_total_em_atraso_acionado IS NULL;

ANALYZE gold.visao_executiva_cliente;

-- Validação rápida
SELECT
    COUNT(*) AS qtd_linhas,
    COUNT(valor_total_em_atraso_acionado) AS qtd_com_coluna_preenchida,
    ROUND(SUM(valor_total_em_atraso_acionado)::NUMERIC, 2) AS total_em_atraso_acionado
FROM gold.visao_executiva_cliente;
