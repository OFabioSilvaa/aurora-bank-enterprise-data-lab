-- Dimensão de tempo inicial.
-- Será usada para Power BI, Excel e análises por safra.

CREATE OR REPLACE TABLE gold.dim_tempo AS
SELECT
    data::DATE AS data,
    EXTRACT(YEAR FROM data)::INTEGER AS ano,
    EXTRACT(MONTH FROM data)::INTEGER AS mes,
    STRFTIME(data, '%Y-%m') AS ano_mes,
    EXTRACT(DAY FROM data)::INTEGER AS dia,
    EXTRACT(DOW FROM data)::INTEGER AS dia_semana,
    CASE
        WHEN EXTRACT(DOW FROM data) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS flag_fim_de_semana,
    DATE_TRUNC('month', data)::DATE AS primeiro_dia_mes,
    LAST_DAY(data)::DATE AS ultimo_dia_mes,
    STRFTIME(data, '%Y-%m') AS safra_mes
FROM GENERATE_SERIES(DATE '2020-01-01', DATE '2026-12-31', INTERVAL 1 DAY) AS t(data);
