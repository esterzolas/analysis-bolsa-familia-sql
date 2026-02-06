-- Criação da tabela para armazenar os dados únicos dos municípios
CREATE TABLE municipios (
    codigo_siafi INTEGER PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    uf CHAR(2) NOT NULL
);

-- Criação da tabela para armazenar os dados únicos dos beneficiários
CREATE TABLE pessoa (
    nis BIGINT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    cpf VARCHAR(14)
);

-- Criação da tabela de fatos para registrar cada pagamento individual
CREATE TABLE pagamentos (
    id_pagamento SERIAL PRIMARY KEY,
    mes_competencia DATE NOT NULL,
    mes_referencia DATE NOT NULL,
    municipio_siafi INTEGER NOT NULL,
    pessoa_nis BIGINT NOT NULL,
    valor_parcela DECIMAL(10, 2) NOT NULL,
    
    -- Definição da chave estrangeira para a tabela 'pessoa'
    CONSTRAINT fk_pessoa 
        FOREIGN KEY(pessoa_nis) 
        REFERENCES pessoa(nis) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Definição da chave estrangeira para a tabela 'municipios'
    CONSTRAINT fk_municipio 
        FOREIGN KEY(municipio_siafi) 
        REFERENCES municipios(codigo_siafi) 
        ON DELETE RESTRICT ON UPDATE CASCADE
);