-- ============================================================
-- Teste da correção valor_total_em_atraso_acionado
-- ============================================================

SELECT
    num_pes,
    nome,
    segmento,
    classe_risco_relacionamento,
    faixa_risco_churn,
    valor_total_em_atraso_acionado,
    valor_recuperado_cobranca
FROM gold.visao_executiva_cliente
ORDER BY valor_total_em_atraso_acionado DESC
LIMIT 50;
