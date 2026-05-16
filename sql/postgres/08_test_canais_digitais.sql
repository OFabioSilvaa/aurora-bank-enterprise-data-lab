-- ============================================================
-- Testes do domínio Canais Digitais
-- ============================================================

SELECT *
FROM meta.quality_canais_digitais
ORDER BY check_name;

SELECT *
FROM gold.dw_canais_digitais
LIMIT 20;

-- KPIs mensais digitais
SELECT
    safra_sessao,
    canal_digital,
    jornada,
    qtd_sessoes,
    qtd_clientes,
    qtd_sessoes_concluidas,
    qtd_sessoes_abandonadas,
    qtd_sessoes_erro,
    taxa_conclusao,
    taxa_abandono,
    taxa_erro
FROM gold.kpi_canais_digitais_mensal
ORDER BY safra_sessao, qtd_sessoes DESC;

-- Funil digital
SELECT
    safra_sessao,
    canal_digital,
    jornada,
    qtd_sessoes,
    qtd_login,
    qtd_inicio_jornada,
    qtd_visualizou_oferta,
    qtd_simulou_produto,
    qtd_enviou_dados,
    qtd_concluiu_jornada,
    qtd_abandonou_jornada,
    qtd_erros,
    taxa_conclusao,
    taxa_abandono,
    taxa_erro
FROM sdx.funil_digital
ORDER BY safra_sessao, qtd_sessoes DESC;

-- Clientes com maior fricção digital
SELECT
    cliente_id,
    nome,
    segmento,
    rating_cliente,
    qtd_sessoes_digitais,
    qtd_sessoes_abandonadas,
    qtd_sessoes_com_erro,
    qtd_erros_app,
    qtd_erros_alta_severidade,
    cluster_digital
FROM sdx.cliente_360_v6
WHERE cluster_digital IN ('FRICCAO_DIGITAL', 'ABANDONO_RECORRENTE')
ORDER BY
    qtd_sessoes_com_erro DESC,
    qtd_sessoes_abandonadas DESC
LIMIT 100;

-- Erros por tipo e severidade
SELECT
    tipo_erro,
    severidade,
    COUNT(*) AS qtd_erros,
    SUM(flg_erro_resolvido) AS qtd_resolvidos
FROM silver.erros_app
GROUP BY
    tipo_erro,
    severidade
ORDER BY qtd_erros DESC;

-- Eventos por jornada
SELECT
    jornada,
    evento,
    COUNT(*) AS qtd_eventos
FROM gold.dw_canais_digitais
GROUP BY
    jornada,
    evento
ORDER BY
    jornada,
    qtd_eventos DESC;
