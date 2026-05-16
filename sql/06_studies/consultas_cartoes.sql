-- Estudos iniciais — Cartões

-- 1. Cartões por produto
SELECT
    produto_cartao,
    COUNT(*) AS qtd_cartoes,
    ROUND(SUM(limite_concedido_tratado), 2) AS limite_total,
    ROUND(AVG(limite_concedido_tratado), 2) AS limite_medio
FROM silver.cartoes
WHERE flag_cliente_orfao = FALSE
GROUP BY produto_cartao
ORDER BY qtd_cartoes DESC;

-- 2. Faturamento mensal
SELECT
    ano_mes,
    COUNT(*) AS qtd_faturas,
    ROUND(SUM(valor_fatura_tratado), 2) AS valor_faturado,
    ROUND(SUM(valor_pago), 2) AS valor_pago,
    SUM(CASE WHEN dias_atraso_fatura > 0 THEN 1 ELSE 0 END) AS qtd_faturas_atrasadas
FROM silver.faturas_cartao
WHERE flag_cartao_orfao = FALSE
GROUP BY ano_mes
ORDER BY ano_mes;

-- 3. Clientes com maior uso de cartão
SELECT
    cliente_id,
    qtd_cartoes,
    qtd_cartoes_ativos,
    limite_total_cartao,
    valor_total_compras,
    ticket_medio_compra,
    maior_atraso_fatura,
    cluster_cartao
FROM sdx.comportamento_cartao
ORDER BY valor_total_compras DESC
LIMIT 100;

-- 4. Risco de cartão no Cliente 360
SELECT
    cliente_id,
    nome,
    segmento,
    rating_cliente,
    qtd_cartoes_ativos,
    limite_total_cartao,
    maior_atraso_fatura,
    qtd_uso_rotativo,
    qtd_pagamento_minimo,
    flag_risco_cartao
FROM sdx.cliente_360_v2
WHERE flag_risco_cartao = TRUE
LIMIT 100;

-- 5. Compras por categoria
SELECT
    categoria_compra,
    COUNT(*) AS qtd_compras,
    ROUND(SUM(valor_compra_tratado), 2) AS valor_compras,
    ROUND(AVG(valor_compra_tratado), 2) AS ticket_medio
FROM silver.compras_cartao
WHERE flag_compra_valida_financeira = TRUE
GROUP BY categoria_compra
ORDER BY valor_compras DESC;
