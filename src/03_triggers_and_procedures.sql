-- 1. Preparação da Tabela para Performance (Materialização de contagem)
ALTER TABLE municipios ADD COLUMN qtd_beneficiarios INTEGER DEFAULT 0;

-- 2. Função da Trigger
CREATE OR REPLACE FUNCTION atualizar_contagem_beneficiarios()
RETURNS TRIGGER AS $$
DECLARE
    v_municipio_siafi INTEGER;
BEGIN
    -- Descobre o município do primeiro pagamento da nova pessoa
    SELECT municipio_siafi INTO v_municipio_siafi 
    FROM pagamentos 
    WHERE pessoa_nis = NEW.nis 
    LIMIT 1;

    -- Se encontrou um município, atualiza a contagem automaticamente
    IF v_municipio_siafi IS NOT NULL THEN
        UPDATE municipios
        SET qtd_beneficiarios = qtd_beneficiarios + 1
        WHERE codigo_siafi = v_municipio_siafi;
    END IF;

    RETURN NULL; 
END;
$$ LANGUAGE plpgsql;

-- 3. Criação do Gatilho (Trigger)
CREATE TRIGGER trg_atualiza_contagem_beneficiarios
AFTER INSERT ON pessoa
FOR EACH ROW
EXECUTE FUNCTION atualizar_contagem_beneficiarios();