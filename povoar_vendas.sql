-- 0. OS ÍNDICES VITAIS (Garantem a validação instantânea no final)
CREATE INDEX IF NOT EXISTS idx_bilhete_venda ON bilhete(no_venda);
CREATE INDEX IF NOT EXISTS idx_acesso_bid ON acesso(bid);

BEGIN;

-- 1. Gerar as 99 combinações possíveis de 3 ou mais zonas
CREATE TEMP TABLE tmp_combos ON COMMIT DROP AS
SELECT row_number() OVER () - 1 AS cid, zonas
FROM (
    SELECT ARRAY_REMOVE(ARRAY[z1,z2,z3,z4,z5,z6,z7], NULL) AS zonas
    FROM (VALUES (1),(NULL)) v1(z1), (VALUES (2),(NULL)) v2(z2), (VALUES (3),(NULL)) v3(z3),
         (VALUES (4),(NULL)) v4(z4), (VALUES (5),(NULL)) v5(z5), (VALUES (6),(NULL)) v6(z6), (VALUES (7),(NULL)) v7(z7)
) sub
WHERE array_length(zonas, 1) >= 3;

-- 2. Tabela Base: Calcular os 300.000 bilhetes na RAM
CREATE TEMP TABLE tmp_base ON COMMIT DROP AS
SELECT
    row_number() OVER () AS nv,
    d.data_venda + (random() * interval '23h') AS data_hora,
    CASE WHEN random() < 0.5 THEN 0.50 ELSE 0.00 END AS desconto,
    random() < 0.76 AS votou
FROM (
    SELECT d::date AS data_venda,
           CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN 4000 ELSE 1000 END AS num_vendas
    FROM generate_series('2026-01-01'::date, '2026-06-11'::date, '1 day'::interval) d
) d
JOIN generate_series(1, 4000) g(n) ON g.n <= d.num_vendas;

-- 3. DESPEJAR DADOS DIRETAMENTE NAS TABELAS
INSERT INTO venda (no_venda, data_hora, nif_cliente)
SELECT nv, data_hora, NULL FROM tmp_base;

INSERT INTO bilhete (bid, desconto, votou, no_venda)
SELECT nv, desconto, votou, nv FROM tmp_base;

INSERT INTO acesso (bid, id_zona)
SELECT b.nv, unnest(
    CASE WHEN random() < 0.02 THEN ARRAY[1,2,3,4,5,6,7] ELSE c.zonas END
)
FROM tmp_base b
JOIN tmp_combos c ON (b.nv % 99) = c.cid;

-- 4. ATUALIZAR VOTOS (Estrutura matematicamente perfeita e limpa)
WITH totais AS (
    SELECT (SELECT count(*) FROM bilhete WHERE votou = TRUE) AS total_votos,
           (SELECT count(*) FROM recinto) AS total_recintos
),
distribuicao AS (
    SELECT (total_votos / total_recintos) AS base_votos,
           (total_votos % total_recintos) AS resto_votos
    FROM totais
),
recintos_ordenados AS (
    SELECT id_recinto, ROW_NUMBER() OVER (ORDER BY id_recinto) AS rn
    FROM recinto
)
UPDATE recinto r
SET votos = d.base_votos + CASE WHEN ro.rn <= d.resto_votos THEN 1 ELSE 0 END
FROM distribuicao d, recintos_ordenados ro
WHERE r.id_recinto = ro.id_recinto;

-- 5. Acertar as sequências para a tua API Python não falhar
SELECT setval('venda_no_venda_seq', (SELECT MAX(no_venda) FROM venda));
SELECT setval('bilhete_bid_seq', (SELECT MAX(bid) FROM bilhete));

COMMIT;