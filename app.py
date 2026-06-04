import logging
from flask import Flask, jsonify, request
from psycopg_pool import ConnectionPool

# 1. Configuração de Logs (para podermos fazer log.debug)
logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger(__name__)

# 2. Inicialização do Flask
app = Flask(__name__)

# 3. Configuração da Pool de Ligações ao PostgreSQL (Docker)
db_url = "postgresql://app:app@postgres/app"
pool = ConnectionPool(db_url)


@app.route("/zona/<id_zona>/", methods=("GET",))
def zona_index(id_zona):
    """Mostra a lista de recintos de uma zona e as espécies/animais neles contidos."""

    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 
                    r.id_recinto,
                    e.nome_cientifico,
                    e.nome_comum,
                    COUNT(a.id_animal) AS num_animais
                FROM recinto r
                LEFT JOIN animal a ON r.id_recinto = a.id_recinto
                LEFT JOIN especie e ON a.nome_cientifico = e.nome_cientifico
                WHERE r.id_zona = %(id_zona)s
                GROUP BY r.id_recinto, e.nome_cientifico, e.nome_comum
                ORDER BY r.id_recinto;
                """,
                {"id_zona": id_zona},
            )
            rows = cur.fetchall()
            log.debug(f"Recuperadas {cur.rowcount} linhas para a zona {id_zona}.")

    recintos_dict = {}
    for row in rows:
        id_recinto = row[0]
        nome_cientifico = row[1]
        nome_comum = row[2]
        num_animais = row[3]

        if id_recinto not in recintos_dict:
            recintos_dict[id_recinto] = {
                "id_recinto": id_recinto,
                "especies": []
            }

        if nome_cientifico:
            recintos_dict[id_recinto]["especies"].append({
                "nome_cientifico": nome_cientifico,
                "nome_comum": nome_comum,
                "num_animais": num_animais
            })

    return jsonify(list(recintos_dict.values())), 200



@app.route("/recinto/<id_recinto>/voto/<bid>/", methods=("POST", "PUT"))
def recinto_voto_save(id_recinto, bid):
    """Regista o voto de um bilhete num determinado recinto."""

    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT votou FROM bilhete WHERE bid = %(bid)s;",
                {"bid": bid}
            )
            bilhete = cur.fetchone()
            if not bilhete:
                return jsonify({"message": "Bilhete não encontrado.", "status": "error"}), 404
            
            if bilhete[0]: 
                return jsonify({"message": "Este bilhete já foi utilizado para votar.", "status": "error"}), 400

            cur.execute(
                "SELECT id_zona FROM recinto WHERE id_recinto = %(id_recinto)s;",
                {"id_recinto": id_recinto}
            )
            recinto = cur.fetchone()
            if not recinto:
                return jsonify({"message": "Recinto não encontrado.", "status": "error"}), 404
            
            id_zona_recinto = recinto[0]

            cur.execute(
                "SELECT 1 FROM acesso WHERE bid = %(bid)s AND id_zona = %(id_zona)s;",
                {"bid": bid, "id_zona": id_zona_recinto}
            )
            tem_acesso = cur.fetchone()
            if not tem_acesso:
                return jsonify({"message": "O bilhete não tem acesso à zona deste recinto.", "status": "error"}), 400

            try:
                with conn.transaction():
                    cur.execute(
                        "UPDATE bilhete SET votou = TRUE WHERE bid = %(bid)s;",
                        {"bid": bid}
                    )
                    cur.execute(
                        "UPDATE recinto SET votos = COALESCE(votos, 0) + 1 WHERE id_recinto = %(id_recinto)s;",
                        {"id_recinto": id_recinto}
                    )
                log.debug(f"Voto registado com sucesso. Bilhete {bid} -> Recinto {id_recinto}.")
            except Exception as e:
                return jsonify({"message": f"Erro interno ao processar transação: {str(e)}", "status": "error"}), 500

    return jsonify({"message": "Voto assinalado com sucesso.", "status": "success"}), 200


    
@app.route("/venda/", methods=("POST",))
def venda_save():
    """Executa a transação de venda de um ou mais bilhetes com os respetivos acessos."""
    
    payload = request.get_json()
    if not payload:
        return jsonify({"message": "Dados da requisição em falta.", "status": "error"}), 400

    nif_cliente = payload.get("nif_cliente")
    bilhetes_input = payload.get("bilhetes")

    if not bilhetes_input or not isinstance(bilhetes_input, list):
        return jsonify({"message": "A lista de bilhetes é obrigatória.", "status": "error"}), 400

    preco_total_venda = 0.0
    bilhetes_emitidos = []

    with pool.connection() as conn:
        with conn.cursor() as cur:
            try:
                with conn.transaction():
                    cur.execute(
                        """
                        INSERT INTO venda (data_hora, nif_cliente)
                        VALUES (NOW(), %(nif_cliente)s)
                        RETURNING no_venda;
                        """,
                        {"nif_cliente": nif_cliente}
                    )
                    no_venda = cur.fetchone()[0]

                    for idx, b_data in enumerate(bilhetes_input):
                        desconto = float(b_data.get("desconto", 0.00))
                        zonas = b_data.get("zonas", [])

                        if not zonas:
                            raise Exception(f"O bilhete no índice {idx} necessita de pelo menos uma zona de acesso.")

                        cur.execute(
                            """
                            INSERT INTO bilhete (desconto, votou, no_venda)
                            VALUES (%(desconto)s, FALSE, %(no_venda)s)
                            RETURNING bid;
                            """,
                            {"desconto": desconto, "no_venda": no_venda}
                        )
                        bid = cur.fetchone()[0]

                        preco_bilhete = 0.0
                        for id_zona in zonas:
                            cur.execute(
                                """
                                INSERT INTO acesso (bid, id_zona)
                                VALUES (%(bid)s, %(id_zona)s);
                                """,
                                {"bid": bid, "id_zona": id_zona}
                            )

                            cur.execute("SELECT preco FROM zona WHERE id_zona = %(id_zona)s;", {"id_zona": id_zona})
                            zona_res = cur.fetchone()
                            if not zona_res:
                                raise Exception(f"A zona com ID {id_zona} introduzida não existe.")

                            preco_base_zona = float(zona_res[0])
                            preco_bilhete += preco_base_zona * (1.0 - desconto)

                        preco_total_venda += preco_bilhete
                        bilhetes_emitidos.append({
                            "bilhete": bid,
                            "preco": round(preco_bilhete, 2)
                        })

                log.debug(f"Venda {no_venda} concluída com sucesso.")
            except Exception as e:
                return jsonify({"message": f"Falha na venda (Rollback executado): {str(e)}", "status": "error"}), 400

    output_venda = {
        "preco_total": round(preco_total_venda, 2),
        "bilhetes": bilhetes_emitidos
    }
    return jsonify(output_venda), 201


if __name__ == "__main__":
    # Corre a app na porta 5000 com o modo Debug ativo (faz restart automático ao mudar o código)
    app.run(host="0.0.0.0", port=5000, debug=True)