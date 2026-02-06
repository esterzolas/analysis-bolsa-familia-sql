-- Popula a tabela municipios a partir dos dados brutos (staging)
INSERT INTO municipios (codigo_siafi, nome, uf) 
SELECT DISTINCT CAST(codigo_municipio_siafi AS INTEGER), nome_municipio, uf 
FROM staging_pagamentos 
ON CONFLICT (codigo_siafi) DO NOTHING;

-- Popula a tabela pessoa
INSERT INTO pessoa (nis, nome, cpf) 
SELECT DISTINCT CAST(nis_favorecido AS BIGINT), nome_favorecido, cpf_favorecido 
FROM staging_pagamentos 
WHERE nis_favorecido IS NOT NULL AND nis_favorecido <> '' 
ON CONFLICT (nis) DO NOTHING;

-- Popula a tabela fatos (pagamentos) com conversão de tipos
INSERT INTO pagamentos (mes_competencia, mes_referencia, municipio_siafi, pessoa_nis, valor_parcela) 
SELECT 
    TO_DATE(mes_competencia, 'YYYY-MM-DD'), 
    TO_DATE(mes_referencia, 'YYYY-MM-DD'), 
    CAST(codigo_municipio_siafi AS INTEGER), 
    CAST(nis_favorecido AS BIGINT), 
    CAST(REPLACE(valor_parcela, ',', '.') AS DECIMAL(10, 2)) 
FROM staging_pagamentos 
WHERE nis_favorecido IS NOT NULL AND nis_favorecido <> '';

-- Limpeza: remove a tabela temporária
DROP TABLE staging_pagamentos;