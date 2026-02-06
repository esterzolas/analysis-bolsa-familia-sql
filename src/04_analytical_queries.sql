-- ==================================================================
-- 📊 CONSULTAS ANALÍTICAS - PROJETO BOLSA FAMÍLIA
-- ==================================================================

-- 1) Histórico de Pagamentos de um Beneficiário Específico
SELECT
    p.nome AS "Nome do Beneficiário",
    pg.valor_parcela AS "Valor da Parcela",
    CASE
        WHEN EXTRACT(YEAR FROM pg.mes_referencia) = 2024 THEN 'Sim'
        ELSE 'Não'
    END AS "Pagamento de 2024",
    TO_CHAR(pg.mes_referencia, 'MM-YYYY') AS "Mês de Referência",
    CASE
        WHEN EXTRACT(YEAR FROM pg.mes_referencia) = 2023 AND EXTRACT(YEAR FROM pg.mes_competencia) = 2024 THEN 'Sim'
        ELSE 'Não'
    END AS "Recebeu Retroativo",
    CASE
        WHEN EXTRACT(YEAR FROM pg.mes_referencia) = 2023 AND EXTRACT(YEAR FROM pg.mes_competencia) = 2024 THEN TO_CHAR(pg.mes_referencia, 'MM-YYYY')
        ELSE NULL
    END AS "Mês do Retroativo"
FROM
    pagamentos pg
JOIN
    pessoa p ON pg.pessoa_nis = p.nis
JOIN
    municipios m ON pg.municipio_siafi = m.codigo_siafi
WHERE
    p.nis = 16142837799 AND m.codigo_siafi = 5403
ORDER BY
    pg.mes_referencia ASC;

-- 2) Princípio de Pareto (Curva ABC) por Estado
WITH StatsPorUF AS (
    SELECT
        m.uf,
        SUM(p.valor_parcela) AS valor_total_uf,
        COUNT(DISTINCT p.pessoa_nis) AS qtd_beneficiarios_uf,
        COUNT(DISTINCT m.codigo_siafi) AS qtd_municipios_uf
    FROM
        pagamentos AS p
    JOIN
        municipios AS m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        EXTRACT(YEAR FROM p.mes_referencia) = 2024
    GROUP BY
        m.uf
),
CalculosGerais AS (
    SELECT
        uf,
        valor_total_uf,
        qtd_beneficiarios_uf,
        qtd_municipios_uf,
        (valor_total_uf / SUM(valor_total_uf) OVER ()) * 100 AS percentual_do_total,
        valor_total_uf / qtd_beneficiarios_uf AS valor_medio_por_beneficiario,
        valor_total_uf / qtd_municipios_uf AS valor_medio_por_municipio
    FROM
        StatsPorUF
)
SELECT
    uf,
    valor_total_uf,
    percentual_do_total,
    SUM(percentual_do_total) OVER (ORDER BY percentual_do_total DESC) AS percentual_acumulado,
    valor_medio_por_beneficiario,
    valor_medio_por_municipio
FROM
    CalculosGerais
ORDER BY
    percentual_do_total DESC;

-- 3) Comparativo Uberlândia vs Média de Minas Gerais (Time Series)
WITH UdiData AS (
    SELECT
        TO_CHAR(mes_referencia, 'YYYY-MM') AS mes,
        SUM(valor_parcela) AS valor_total_udi,
        COUNT(DISTINCT pessoa_nis) AS qtd_pessoas_udi
    FROM pagamentos p
    JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE m.nome = 'UBERLANDIA' AND m.uf = 'MG' AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
    GROUP BY mes
),
MGData AS (
    SELECT
        mes,
        AVG(valor_total_por_cidade) AS media_valor_total_mg,
        AVG(qtd_pessoas_por_cidade) AS media_qtd_pessoas_mg
    FROM (
        SELECT
            p.municipio_siafi,
            TO_CHAR(p.mes_referencia, 'YYYY-MM') AS mes,
            SUM(p.valor_parcela) as valor_total_por_cidade,
            COUNT(DISTINCT p.pessoa_nis) as qtd_pessoas_por_cidade
        FROM pagamentos p
        JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
        WHERE m.uf = 'MG' AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
        GROUP BY p.municipio_siafi, mes
    ) AS stats_cidades_mg
    GROUP BY mes
)
SELECT
    u.mes,
    u.qtd_pessoas_udi,
    ROUND(m.media_qtd_pessoas_mg, 0) AS media_pessoas_cidades_mg,
    ROUND(
        ( (u.qtd_pessoas_udi - LAG(u.qtd_pessoas_udi, 1, u.qtd_pessoas_udi) OVER (ORDER BY u.mes)) * 100.0 )
        / LAG(u.qtd_pessoas_udi, 1, u.qtd_pessoas_udi) OVER (ORDER BY u.mes), 2
    ) AS variacao_pct_udi,
    ROUND(
        ( (m.media_qtd_pessoas_mg - LAG(m.media_qtd_pessoas_mg, 1, m.media_qtd_pessoas_mg) OVER (ORDER BY u.mes)) * 100.0 )
        / LAG(m.media_qtd_pessoas_mg, 1, m.media_qtd_pessoas_mg) OVER (ORDER BY u.mes), 2
    ) AS variacao_pct_media_mg
FROM
    UdiData u
JOIN
    MGData m ON u.mes = m.mes
ORDER BY
    u.mes;

-- 4) Análise de Dependência Contínua (6 meses consecutivos)
WITH BeneficiariosContinuos AS (
    SELECT
        p.pessoa_nis
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.nome = 'UBERLANDIA' AND m.uf = 'MG'
        AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
    GROUP BY
        p.pessoa_nis
    HAVING
        COUNT(DISTINCT DATE_TRUNC('month', p.mes_referencia)) = 6
),
TotalBeneficiarios AS (
    SELECT
        COUNT(DISTINCT p.pessoa_nis) as total
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.nome = 'UBERLANDIA' AND m.uf = 'MG'
        AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
)
SELECT
    (SELECT total FROM TotalBeneficiarios) AS total_beneficiarios_uberlandia,
    (SELECT COUNT(*) FROM BeneficiariosContinuos) AS beneficiarios_dependentes_6_meses,
    ROUND(
        ( (SELECT COUNT(*) FROM BeneficiariosContinuos)::DECIMAL / (SELECT total FROM TotalBeneficiarios)::DECIMAL ) * 100
    , 2) AS porcentagem_dependencia_continua;

-- 5) Detecção de Outliers (Pagamentos muito acima da média municipal)
WITH MediaPorMunicipio AS ( 
    SELECT 
        municipio_siafi, 
        AVG(valor_parcela) AS valor_medio_municipal 
    FROM pagamentos 
    WHERE EXTRACT(YEAR FROM mes_referencia) = 2024 
    GROUP BY municipio_siafi 
) 
SELECT 
    pe.nome AS nome_pessoa, 
    m.nome AS municipio, 
    m.uf, 
    p.valor_parcela, 
    mpm.valor_medio_municipal 
FROM 
    pagamentos p 
JOIN 
    pessoa pe ON p.pessoa_nis = pe.nis 
JOIN 
    municipios m ON p.municipio_siafi = m.codigo_siafi 
JOIN 
    MediaPorMunicipio mpm ON p.municipio_siafi = mpm.municipio_siafi 
WHERE 
    p.valor_parcela > (mpm.valor_medio_municipal * 2) 
    AND EXTRACT(YEAR FROM p.mes_referencia) = 2024 
ORDER BY 
    p.valor_parcela DESC;

-- 6) Municípios com Volume Total de Pagamentos Superior a 50 Milhões
SELECT
    m.nome AS nome_municipio,
    m.uf,
    SUM(p.valor_parcela) AS valor_total_pago,
    COUNT(DISTINCT p.pessoa_nis) AS quantidade_beneficiarios
FROM
    pagamentos AS p
JOIN
    municipios AS m ON p.municipio_siafi = m.codigo_siafi
GROUP BY
    m.codigo_siafi, m.nome, m.uf
HAVING
    SUM(p.valor_parcela) > 50000000
ORDER BY
    valor_total_pago DESC;

-- 7) Comparativo Capital vs Interior (Minas Gerais)
SELECT 
    CASE 
        WHEN m.nome = 'BELO HORIZONTE' THEN 'Capital (Belo Horizonte)' 
        ELSE 'Interior' 
    END AS localizacao, 
    SUM(p.valor_parcela) AS valor_total, 
    COUNT(DISTINCT p.pessoa_nis) AS total_beneficiarios 
FROM 
    pagamentos AS p 
JOIN 
    municipios AS m ON p.municipio_siafi = m.codigo_siafi 
WHERE 
    m.uf = 'MG' AND EXTRACT(YEAR FROM p.mes_referencia) = 2024 
GROUP BY 
    localizacao; 

-- 8) Variação de Beneficiários (Janeiro vs Junho)
SELECT
    m.uf,
    COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-01-01' THEN p.pessoa_nis END) AS beneficiarios_jan,
    COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-06-01' THEN p.pessoa_nis END) AS beneficiarios_jun,
    (COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-06-01' THEN p.pessoa_nis END) -
     COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-01-01' THEN p.pessoa_nis END)) AS variacao_absoluta
FROM
    pagamentos p
JOIN
    municipios m ON p.municipio_siafi = m.codigo_siafi
WHERE
    p.mes_referencia IN ('2024-01-01', '2024-06-01')
GROUP BY
    m.uf
ORDER BY
    variacao_absoluta DESC;

-- 9) Mediana de Beneficiários Únicos por Município (Otimizada)
-- Nota: Esta consulta se beneficia do Gatilho criado no script 03
WITH BeneficiariosPorMunicipio AS (
    SELECT
        m.uf,
        COUNT(DISTINCT p.pessoa_nis) AS total_beneficiarios
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.uf != 'DF'
    GROUP BY
        m.uf, m.nome
)
SELECT
    uf,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_beneficiarios) AS mediana_beneficiarios_por_municipio
FROM
    BeneficiariosPorMunicipio
GROUP BY
    uf
ORDER BY
    mediana_beneficiarios_por_municipio DESC;

-- 10) Ranking de Valor Médio: Foco Demográfico vs Nacional
WITH FocoDemografico AS (
    SELECT
        'Foco Demográfico' AS categoria,
        m.nome AS municipio,
        m.uf,
        AVG(p.valor_parcela) AS valor_medio_parcela,
        RANK() OVER (ORDER BY AVG(p.valor_parcela) DESC) AS ranking
    FROM pagamentos p
    JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.uf IN ('BA', 'PI', 'MA', 'PA', 'SE')
        AND TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
    GROUP BY m.nome, m.uf
    LIMIT 10
),
Nacional AS (
    SELECT
        'Nacional' AS categoria,
        m.nome AS municipio,
        m.uf,
        AVG(p.valor_parcela) AS valor_medio_parcela,
        RANK() OVER (ORDER BY AVG(p.valor_parcela) DESC) AS ranking
    FROM pagamentos p
    JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
    GROUP BY m.nome, m.uf
    LIMIT 10
)
SELECT categoria, ranking, municipio, uf, valor_medio_parcela
FROM FocoDemografico
UNION ALL
SELECT categoria, ranking, municipio, uf, valor_medio_parcela
FROM Nacional
ORDER BY ranking, categoria;

-- 11) Categorização de Pagamentos por Faixa de Valor
WITH PagamentosCategorizados AS (
    SELECT
        p.valor_parcela,
        CASE
            WHEN m.uf IN ('BA', 'PI', 'MA', 'PA', 'SE') THEN 'Foco Demográfico'
            ELSE 'Outros Estados'
        END AS grupo_demografico
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
)
SELECT
    grupo_demografico,
    COUNT(*) AS total_de_pagamentos,
    COUNT(*) FILTER (WHERE valor_parcela <= 700) AS pagamentos_baixo_valor,
    COUNT(*) FILTER (WHERE valor_parcela > 700) AS pagamentos_alto_valor,
    (COUNT(*) FILTER (WHERE valor_parcela > 700)::numeric / COUNT(*)) * 100 AS percentual_alto_valor
FROM
    PagamentosCategorizados
GROUP BY
    grupo_demografico;

-- 12) Estatísticas Descritivas por Estado
SELECT
    m.uf,
    MIN(p.valor_parcela) AS valor_minimo,
    MAX(p.valor_parcela) AS valor_maximo,
    AVG(p.valor_parcela) AS valor_medio,
    STDDEV(p.valor_parcela) AS desvio_padrao
FROM
    pagamentos p
JOIN
    municipios m ON p.municipio_siafi = m.codigo_siafi
WHERE
    TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
GROUP BY
    m.uf
ORDER BY
    desvio_padrao DESC;