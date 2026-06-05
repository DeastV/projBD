CREATE INDEX IF NOT EXISTS idx_bilhete_venda ON bilhete(no_venda);
CREATE INDEX IF NOT EXISTS idx_acesso_bid ON acesso(bid);

BEGIN;

CREATE TEMP TABLE tmp_combos (
    cid SERIAL,
    zonas INT[]
) ON COMMIT DROP;

INSERT INTO tmp_combos (zonas)
SELECT ARRAY_REMOVE(ARRAY[z1,z2,z3,z4,z5,z6,z7], NULL) AS zonas
FROM (VALUES (1),(NULL)) v1(z1), (VALUES (2),(NULL)) v2(z2), (VALUES (3),(NULL)) v3(z3),
     (VALUES (4),(NULL)) v4(z4), (VALUES (5),(NULL)) v5(z5), (VALUES (6),(NULL)) v6(z6), (VALUES (7),(NULL)) v7(z7)
WHERE num_nonnulls(z1,z2,z3,z4,z5,z6,z7) >= 3;

CREATE TEMP TABLE tmp_base (
    nv SERIAL,
    data_hora TIMESTAMP,
    desconto NUMERIC,
    votou BOOLEAN
) ON COMMIT DROP;

INSERT INTO tmp_base (data_hora, desconto, votou)
SELECT
    d.data_venda + (random() * interval '23h') AS data_hora,
    CASE WHEN random() < 0.5 THEN 0.50 ELSE 0.00 END AS desconto,
    random() < 0.76 AS votou
FROM (
    SELECT d::date AS data_venda,
           CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN 4000 ELSE 1000 END AS num_vendas
    FROM generate_series('2026-01-01'::date, '2026-06-11'::date, '1 day'::interval) d
) d
JOIN generate_series(1, 4000) g(n) ON g.n <= d.num_vendas;

INSERT INTO venda (no_venda, data_hora, nif_cliente)
SELECT nv, data_hora, NULL FROM tmp_base;

INSERT INTO bilhete (bid, desconto, votou, no_venda)
SELECT nv, desconto, votou, nv FROM tmp_base;

INSERT INTO acesso (bid, id_zona)
SELECT b.nv, unnest(
    CASE WHEN random() < 0.02 THEN ARRAY[1,2,3,4,5,6,7] ELSE c.zonas END
)
FROM tmp_base b
JOIN tmp_combos c ON (b.nv % 99) + 1 = c.cid;

WITH totais AS (
    SELECT (SELECT count(*) FROM bilhete WHERE votou = TRUE) as total_votos
),
pesos AS (
    SELECT id_recinto, random() as peso FROM recinto
),
tot_pesos AS (
    SELECT sum(peso) as total_peso FROM pesos
),
calc_base AS (
    SELECT p.id_recinto,
           floor((p.peso / tp.total_peso) * t.total_votos)::int as votos_base
    FROM pesos p CROSS JOIN tot_pesos tp CROSS JOIN totais t
)
UPDATE recinto r
SET votos = c.votos_base
FROM calc_base c
WHERE r.id_recinto = c.id_recinto;

UPDATE recinto r
SET votos = votos + 1
WHERE id_recinto IN (
    SELECT id_recinto 
    FROM recinto 
    ORDER BY random() 
    LIMIT (
        SELECT (SELECT count(*) FROM bilhete WHERE votou = TRUE) - SUM(votos) FROM recinto
    )
);

SELECT setval('venda_no_venda_seq', (SELECT MAX(no_venda) FROM venda));
SELECT setval('bilhete_bid_seq', (SELECT MAX(bid) FROM bilhete));

COMMIT;