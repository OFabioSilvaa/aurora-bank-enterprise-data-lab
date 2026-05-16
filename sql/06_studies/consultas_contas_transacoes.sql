-- Estudos iniciais — Contas e Transações

-- 1. Quantidade de contas por status
SELECT
    status_conta,
    COUNT(*) AS qtd_contas
FROM silver.contas
GROUP BY status_conta
ORDER BY qtd_contas DESC;

-- 2. Saldo médio por tipo de conta
SELECT
    tipo_conta,
    COUNT(*) AS qtd_contas,
    ROUND(AVG(saldo_atual_tratado), 2) AS saldo_medio,
    ROUND(SUM(saldo_atual_tratado), 2) AS saldo_total
FROM silver.contas
WHERE flag_cliente_orfao = FALSE
GROUP BY tipo_conta
ORDER BY saldo_total DESC;

-- 3. Volume transacionado por mês
SELECT
    ano_mes,
    COUNT(*) AS qtd_transacoes,
    ROUND(SUM(valor_tratado), 2) AS valor_transacionado
FROM silver.transacoes
WHERE flag_transacao_valida_financeira = TRUE
GROUP BY ano_mes
ORDER BY ano_mes;

-- 4. Top canais por valor transacionado
SELECT
    canal,
    COUNT(*) AS qtd_transacoes,
    ROUND(SUM(valor_tratado), 2) AS valor_transacionado,
    ROUND(AVG(valor_tratado), 2) AS ticket_medio
FROM silver.transacoes
WHERE flag_transacao_valida_financeira = TRUE
GROUP BY canal
ORDER BY valor_transacionado DESC;

-- 5. Cliente 360 com movimentação
SELECT
    cliente_id,
    nome,
    segmento,
    qtd_contas,
    qtd_transacoes_validas,
    valor_transacionado,
    ticket_medio,
    dias_desde_ultima_transacao,
    cluster_atividade_financeira,
    flag_risco_churn_inicial
FROM sdx.cliente_360
ORDER BY valor_transacionado DESC
LIMIT 100;

-- 6. Potenciais clientes em churn
SELECT
    cliente_id,
    nome,
    segmento,
    dias_desde_ultimo_login,
    dias_desde_ultima_transacao,
    qtd_transacoes_validas,
    cluster_atividade_financeira
FROM sdx.cliente_360
WHERE flag_risco_churn_inicial = TRUE
LIMIT 100;
