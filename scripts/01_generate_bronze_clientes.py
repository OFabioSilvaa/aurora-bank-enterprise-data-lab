"""
Aurora Bank Enterprise Data Lab
Gerador Bronze — Clientes, Endereços, Contatos, Scores e Segmentos

Como executar no PowerShell, dentro da pasta do projeto:

    python .\scripts\01_generate_bronze_clientes.py --mode dev --overwrite

Modos disponíveis:
    dev     -> 10.000 clientes
    lab     -> 100.000 clientes
    growth  -> 7.000.000 clientes

Também é possível informar uma quantidade manual:

    python .\scripts\01_generate_bronze_clientes.py --customers 50000 --overwrite

Saídas em Parquet:
    data/bronze/raw_clientes_core/
    data/bronze/raw_clientes_app/
    data/bronze/raw_enderecos/
    data/bronze/raw_contatos/
    data/bronze/raw_scores_cliente/
    data/bronze/raw_segmentos_cliente/

Observação:
    Este script cria dados fictícios/sintéticos.
    Não use dados reais de clientes.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd


MODES = {
    "dev": 10_000,
    "lab": 100_000,
    "growth": 7_000_000,
}

DEFAULT_CHUNK_SIZE = {
    "dev": 10_000,
    "lab": 50_000,
    "growth": 250_000,
}

BRONZE_BASE = Path("data/bronze")

TABLE_DIRS = {
    "clientes_core": BRONZE_BASE / "raw_clientes_core",
    "clientes_app": BRONZE_BASE / "raw_clientes_app",
    "enderecos": BRONZE_BASE / "raw_enderecos",
    "contatos": BRONZE_BASE / "raw_contatos",
    "scores": BRONZE_BASE / "raw_scores_cliente",
    "segmentos": BRONZE_BASE / "raw_segmentos_cliente",
}


PRIMEIROS_NOMES = np.array([
    "Ana", "Bruno", "Carlos", "Daniela", "Eduardo", "Fernanda", "Gabriel", "Helena",
    "Igor", "Juliana", "Lucas", "Mariana", "Nicolas", "Olivia", "Pedro", "Rafaela",
    "Samuel", "Tatiane", "Vinicius", "Yasmin", "Joao", "Laura", "Marcos", "Beatriz",
    "Caio", "Isabela", "Thiago", "Renata", "Felipe", "Larissa"
])

SOBRENOMES = np.array([
    "Silva", "Santos", "Oliveira", "Souza", "Pereira", "Costa", "Rodrigues", "Almeida",
    "Nascimento", "Lima", "Araujo", "Fernandes", "Carvalho", "Gomes", "Martins",
    "Ribeiro", "Barbosa", "Moura", "Dias", "Teixeira"
])

GENEROS = np.array(["F", "M", "NAO_INFORMADO"])
ESTADOS_CIVIS = np.array(["SOLTEIRO", "CASADO", "DIVORCIADO", "VIUVO", "UNIAO_ESTAVEL", None], dtype=object)

CIDADES_UF_REGIAO = np.array([
    ("Belo Horizonte", "MG", "Sudeste"),
    ("Contagem", "MG", "Sudeste"),
    ("Betim", "MG", "Sudeste"),
    ("Sao Paulo", "SP", "Sudeste"),
    ("Campinas", "SP", "Sudeste"),
    ("Rio de Janeiro", "RJ", "Sudeste"),
    ("Curitiba", "PR", "Sul"),
    ("Porto Alegre", "RS", "Sul"),
    ("Florianopolis", "SC", "Sul"),
    ("Salvador", "BA", "Nordeste"),
    ("Recife", "PE", "Nordeste"),
    ("Fortaleza", "CE", "Nordeste"),
    ("Goiania", "GO", "Centro-Oeste"),
    ("Brasilia", "DF", "Centro-Oeste"),
    ("Manaus", "AM", "Norte"),
    ("Belem", "PA", "Norte"),
], dtype=object)

PROFISSOES = np.array([
    "Analista", "Professor", "Motorista", "Enfermeiro", "Tecnico", "Vendedor",
    "Autonomo", "Comerciante", "Empresario", "Servidor Publico", "Aposentado",
    "Estudante", "Desenvolvedor", "Assistente Administrativo", "Operador"
])

TIPOS_OCUPACAO = np.array([
    "CLT", "AUTONOMO", "SERVIDOR_PUBLICO", "APOSENTADO", "PENSIONISTA",
    "EMPREENDEDOR", "ESTUDANTE", "DESEMPREGADO"
])

ESCOLARIDADES = np.array([
    "FUNDAMENTAL", "MEDIO", "SUPERIOR_INCOMPLETO", "SUPERIOR_COMPLETO",
    "POS_GRADUACAO", None
], dtype=object)

SEGMENTOS = np.array([
    "VAREJO", "RENDA_MEDIA", "ALTA_RENDA", "DIGITAL", "CONSIGNADO",
    "UNIVERSITARIO", "EMPREENDEDOR", "INVESTIDOR"
])

CANAIS_AQUISICAO = np.array([
    "APP", "SITE", "INDICACAO", "MIDIA_PAGA", "ORGANICO", "CORRESPONDENTE",
    "PARCEIRO", "AGENCIA", "OPEN_FINANCE"
])

STATUS_CLIENTE = np.array(["ATIVO", "INATIVO", "BLOQUEADO", "ENCERRADO", "EM_ANALISE"])
DEVICES = np.array(["ANDROID", "IOS", "WEB", "TABLET", None], dtype=object)
CANAIS_PREFERIDOS = np.array(["APP", "WHATSAPP", "EMAIL", "SMS", "CALL_CENTER", None], dtype=object)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera dados Bronze de clientes para o Aurora Bank.")
    parser.add_argument("--mode", choices=list(MODES.keys()), default="dev", help="Modo de geração.")
    parser.add_argument("--customers", type=int, default=None, help="Quantidade manual de clientes.")
    parser.add_argument("--chunk-size", type=int, default=None, help="Tamanho do lote.")
    parser.add_argument("--seed", type=int, default=42, help="Seed para reprodutibilidade.")
    parser.add_argument("--overwrite", action="store_true", help="Limpa as pastas de saída antes de gerar.")
    return parser.parse_args()


def prepare_dirs(overwrite: bool) -> None:
    for path in TABLE_DIRS.values():
        if overwrite and path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True, exist_ok=True)


def random_dates(rng: np.random.Generator, start: str, end: str, n: int) -> pd.Series:
    start_ts = pd.Timestamp(start).value // 10**9
    end_ts = pd.Timestamp(end).value // 10**9
    values = rng.integers(start_ts, end_ts, size=n)
    return pd.to_datetime(values, unit="s").date


def build_faixa_etaria(idades: np.ndarray) -> np.ndarray:
    bins = [0, 24, 34, 44, 54, 64, 200]
    labels = ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    return pd.Series(pd.cut(idades, bins=bins, labels=labels, include_lowest=True)).astype(str).to_numpy()


def build_faixa_renda(rendas: np.ndarray) -> np.ndarray:
    clean = pd.Series(rendas)
    return pd.cut(
        clean,
        bins=[-1, 0, 1412, 3000, 6000, 10000, 20000, 999999999],
        labels=["SEM_RENDA", "ATE_1_SM", "1_A_3K", "3K_A_6K", "6K_A_10K", "10K_A_20K", "20K_PLUS"],
        include_lowest=True,
    ).astype("object").fillna("NAO_INFORMADO").to_numpy()


def generate_clientes_chunk(start_id: int, end_id: int, rng: np.random.Generator, part: int) -> dict[str, pd.DataFrame]:
    ids = np.arange(start_id, end_id + 1, dtype=np.int64)
    n = len(ids)
    now = pd.Timestamp.now()

    nome = (
        rng.choice(PRIMEIROS_NOMES, n)
        + " "
        + rng.choice(SOBRENOMES, n)
        + " "
        + rng.choice(SOBRENOMES, n)
    )

    idades = rng.integers(18, 82, size=n)
    dias_extra = rng.integers(0, 365, size=n)
    data_nascimento = pd.Timestamp("2026-01-01") - pd.to_timedelta((idades * 365 + dias_extra), unit="D")
    data_nascimento = pd.Series(data_nascimento.dt.date if hasattr(data_nascimento, "dt") else pd.to_datetime(data_nascimento).date)

    # Injeta data_nascimento nula em parte da base
    mask_nascimento_null = rng.random(n) < 0.008
    data_nascimento = pd.Series(data_nascimento, dtype="object")
    data_nascimento.loc[mask_nascimento_null] = None

    cidade_idx = rng.integers(0, len(CIDADES_UF_REGIAO), size=n)
    cidade = CIDADES_UF_REGIAO[cidade_idx, 0].astype(object)
    uf = CIDADES_UF_REGIAO[cidade_idx, 1].astype(object)
    regiao = CIDADES_UF_REGIAO[cidade_idx, 2].astype(object)

    # Injeta inconsistências de cidade/UF
    mask_uf_null = rng.random(n) < 0.006
    uf[mask_uf_null] = None
    mask_cidade_variacao = rng.random(n) < 0.01
    cidade[mask_cidade_variacao] = np.char.lower(cidade[mask_cidade_variacao].astype(str))

    tipo_ocupacao = rng.choice(TIPOS_OCUPACAO, n, p=[0.43, 0.13, 0.09, 0.12, 0.04, 0.08, 0.07, 0.04])
    segmento = rng.choice(SEGMENTOS, n, p=[0.30, 0.23, 0.06, 0.18, 0.10, 0.05, 0.05, 0.03])

    renda_base = rng.lognormal(mean=8.25, sigma=0.65, size=n)
    renda_base = np.clip(renda_base, 0, 80000).round(2)

    # Ajustes por segmento/ocupação
    renda_base = np.where(segmento == "ALTA_RENDA", renda_base * rng.uniform(2.2, 4.5, size=n), renda_base)
    renda_base = np.where(segmento == "UNIVERSITARIO", renda_base * rng.uniform(0.35, 0.8, size=n), renda_base)
    renda_base = np.where(tipo_ocupacao == "APOSENTADO", rng.uniform(1412, 8500, size=n), renda_base)
    renda_base = np.round(np.clip(renda_base, 0, 250000), 2)

    # Injeta renda nula/zerada/outlier
    renda = renda_base.astype(object)
    mask_renda_null = rng.random(n) < 0.035
    mask_renda_zero = rng.random(n) < 0.008
    mask_renda_outlier = rng.random(n) < 0.002
    renda[mask_renda_null] = None
    renda[mask_renda_zero] = 0
    renda[mask_renda_outlier] = rng.uniform(250000, 900000, size=mask_renda_outlier.sum()).round(2)

    score = rng.normal(loc=640, scale=150, size=n).round().astype(float)
    score = np.clip(score, 1, 1000)
    score = np.where(segmento == "ALTA_RENDA", np.clip(score + rng.integers(60, 160, size=n), 1, 1000), score)
    score = np.where(segmento == "UNIVERSITARIO", np.clip(score - rng.integers(20, 120, size=n), 1, 1000), score)
    mask_score_null = rng.random(n) < 0.025
    score = score.astype(object)
    score[mask_score_null] = None

    def rating_from_score(x):
        if pd.isna(x):
            return "SEM_SCORE"
        if x >= 760:
            return "A"
        if x >= 650:
            return "B"
        if x >= 520:
            return "C"
        return "D"

    rating = pd.Series(score).map(rating_from_score).to_numpy()

    data_cadastro = pd.Series(random_dates(rng, "2020-01-01", "2026-12-31", n), dtype="object")
    data_inicio_rel = data_cadastro.copy()
    # Alguns clientes têm data de relacionamento posterior ao cadastro
    data_inicio_rel = pd.to_datetime(data_inicio_rel) + pd.to_timedelta(rng.integers(0, 90, size=n), unit="D")
    data_inicio_rel = pd.Series(data_inicio_rel.dt.date, dtype="object")

    status = rng.choice(STATUS_CLIENTE, n, p=[0.76, 0.12, 0.04, 0.05, 0.03])
    flag_ativo = np.isin(status, ["ATIVO", "EM_ANALISE"])

    cpf_hash = np.array([f"AUR{cliente_id:010d}" for cliente_id in ids], dtype=object)
    # Injeta CPF duplicado copiando hash de cliente anterior dentro do chunk
    dup_mask = (rng.random(n) < 0.002) & (ids > start_id)
    cpf_hash[dup_mask] = np.array([f"AUR{cliente_id-1:010d}" for cliente_id in ids[dup_mask]], dtype=object)

    core = pd.DataFrame({
        "cliente_id": ids,
        "cpf_hash": cpf_hash,
        "nome": nome,
        "data_nascimento": data_nascimento,
        "idade_aproximada": idades,
        "faixa_etaria": build_faixa_etaria(idades),
        "genero": rng.choice(GENEROS, n, p=[0.49, 0.49, 0.02]),
        "estado_civil": rng.choice(ESTADOS_CIVIS, n, p=[0.38, 0.36, 0.09, 0.04, 0.08, 0.05]),
        "cidade": cidade,
        "uf": uf,
        "regiao": regiao,
        "renda_mensal": renda,
        "faixa_renda": build_faixa_renda(pd.to_numeric(pd.Series(renda), errors="coerce").fillna(-1).to_numpy()),
        "profissao": rng.choice(PROFISSOES, n),
        "tipo_ocupacao": tipo_ocupacao,
        "escolaridade": rng.choice(ESCOLARIDADES, n, p=[0.09, 0.36, 0.17, 0.26, 0.08, 0.04]),
        "score_credito": score,
        "rating_cliente": rating,
        "segmento_core": segmento,
        "canal_aquisicao": rng.choice(CANAIS_AQUISICAO, n, p=[0.35, 0.14, 0.08, 0.12, 0.10, 0.08, 0.06, 0.04, 0.03]),
        "data_cadastro": data_cadastro,
        "data_inicio_relacionamento": data_inicio_rel,
        "data_ultima_atualizacao_cadastral": random_dates(rng, "2022-01-01", "2026-12-31", n),
        "status_cliente_core": status,
        "flag_cliente_ativo_core": flag_ativo,
        "dt_ingestao": now,
        "origem_sistema": "CORE_BANKING",
        "arquivo_origem": f"clientes_core_part_{part:05d}.parquet",
    })

    # App: nem todo cliente tem app. Também cria divergência de status.
    app_mask = rng.random(n) < 0.82
    app_ids = ids[app_mask]
    app_n = len(app_ids)

    data_primeiro_login = pd.to_datetime(core.loc[app_mask, "data_cadastro"]) + pd.to_timedelta(rng.integers(0, 180, size=app_n), unit="D")
    data_ultimo_login = pd.to_datetime(data_primeiro_login) + pd.to_timedelta(rng.integers(0, 1200, size=app_n), unit="D")
    data_ultimo_login = pd.Series(np.minimum(data_ultimo_login.values.astype("datetime64[ns]"), np.datetime64("2026-12-31"))).dt.date

    app = pd.DataFrame({
        "app_user_id": np.array([f"APP{cliente_id:010d}" for cliente_id in app_ids], dtype=object),
        "cliente_id": app_ids,
        "status_app": rng.choice(["ATIVO", "INATIVO", "BLOQUEADO", "DESINSTALADO"], app_n, p=[0.72, 0.14, 0.03, 0.11]),
        "data_primeiro_login": pd.Series(data_primeiro_login).dt.date.to_numpy(),
        "data_ultimo_login": data_ultimo_login,
        "canal_preferido": rng.choice(CANAIS_PREFERIDOS, app_n, p=[0.55, 0.17, 0.11, 0.06, 0.06, 0.05]),
        "flag_push_ativo": rng.random(app_n) < 0.61,
        "device_principal": rng.choice(DEVICES, app_n, p=[0.55, 0.31, 0.08, 0.03, 0.03]),
        "app_version": rng.choice(["5.8.1", "5.9.0", "6.0.0", "6.1.2", "6.2.0", None], app_n, p=[0.12, 0.18, 0.27, 0.25, 0.14, 0.04]),
        "dt_ingestao": now,
        "origem_sistema": "APP_ANALYTICS",
        "arquivo_origem": f"clientes_app_part_{part:05d}.parquet",
    })

    # Endereços
    enderecos = pd.DataFrame({
        "endereco_id": ids,
        "cliente_id": ids,
        "tipo_endereco": rng.choice(["RESIDENCIAL", "COMERCIAL", "CORRESPONDENCIA"], n, p=[0.86, 0.07, 0.07]),
        "cidade": cidade,
        "uf": uf,
        "regiao": regiao,
        "cep_prefixo": rng.integers(10000, 99999, size=n).astype(str),
        "flag_endereco_principal": True,
        "data_atualizacao": random_dates(rng, "2021-01-01", "2026-12-31", n),
        "dt_ingestao": now,
        "origem_sistema": "CADASTRO_ENDERECOS",
    })

    # Contatos: email/telefone com nulos propositais
    email = np.array([f"cliente{cliente_id}@emailfake.com" for cliente_id in ids], dtype=object)
    telefone = np.array([f"319{rng.integers(10000000, 99999999)}" for _ in range(n)], dtype=object)
    email[rng.random(n) < 0.045] = None
    telefone[rng.random(n) < 0.035] = None

    contatos = pd.DataFrame({
        "contato_id": ids,
        "cliente_id": ids,
        "email": email,
        "telefone_celular": telefone,
        "flag_email_validado": rng.random(n) < 0.78,
        "flag_telefone_validado": rng.random(n) < 0.81,
        "aceita_marketing": rng.random(n) < 0.64,
        "data_atualizacao": random_dates(rng, "2021-01-01", "2026-12-31", n),
        "dt_ingestao": now,
        "origem_sistema": "CADASTRO_CONTATOS",
    })

    # Histórico de score: 3 registros por cliente na V1 inicial
    hist_periodos = pd.to_datetime(["2024-12-31", "2025-12-31", "2026-12-31"])
    scores_parts = []
    base_score_series = pd.to_numeric(pd.Series(score), errors="coerce")
    base_score_fallback = pd.Series(rng.normal(620, 160, size=n))
    base_score_num = base_score_series.fillna(base_score_fallback).to_numpy()
    for i, dt_ref in enumerate(hist_periodos, start=1):
        score_hist = np.clip(base_score_num + rng.normal(0, 60, size=n), 1, 1000).round()
        score_hist = score_hist.astype(object)
        score_hist[rng.random(n) < 0.015] = None
        scores_parts.append(pd.DataFrame({
            "score_hist_id": ids * 10 + i,
            "cliente_id": ids,
            "data_referencia": dt_ref.date(),
            "score_credito": score_hist,
            "fonte_score": rng.choice(["MOTOR_INTERNO", "BUREAU", "OPEN_FINANCE"], n, p=[0.63, 0.31, 0.06]),
            "dt_ingestao": now,
            "origem_sistema": "MOTOR_RISCO",
        }))
    scores = pd.concat(scores_parts, ignore_index=True)

    # Histórico de segmentos: 2 registros por cliente
    segmentos_parts = []
    for i, dt_ref in enumerate(pd.to_datetime(["2025-01-01", "2026-01-01"]), start=1):
        seg_hist = segmento.copy()
        # Alguns clientes mudam de segmento
        change_mask = rng.random(n) < 0.08
        seg_hist[change_mask] = rng.choice(SEGMENTOS, change_mask.sum())
        segmentos_parts.append(pd.DataFrame({
            "segmento_hist_id": ids * 10 + i,
            "cliente_id": ids,
            "data_inicio_vigencia": dt_ref.date(),
            "data_fim_vigencia": None if i == 2 else pd.Timestamp("2025-12-31").date(),
            "segmento": seg_hist,
            "motivo_segmentacao": rng.choice(["RENDA", "COMPORTAMENTO", "PRODUTO", "RISCO", "CAMPANHA"], n),
            "dt_ingestao": now,
            "origem_sistema": "CRM_SEGMENTACAO",
        }))
    segmentos_df = pd.concat(segmentos_parts, ignore_index=True)

    return {
        "clientes_core": core,
        "clientes_app": app,
        "enderecos": enderecos,
        "contatos": contatos,
        "scores": scores,
        "segmentos": segmentos_df,
    }


def write_partitions(dfs: dict[str, pd.DataFrame], part: int) -> None:
    for name, df in dfs.items():
        out = TABLE_DIRS[name] / f"part_{part:05d}.parquet"
        df.to_parquet(out, index=False)


def main() -> None:
    args = parse_args()

    total_customers = args.customers if args.customers is not None else MODES[args.mode]
    chunk_size = args.chunk_size if args.chunk_size is not None else DEFAULT_CHUNK_SIZE[args.mode]

    if total_customers <= 0:
        raise ValueError("A quantidade de clientes deve ser maior que zero.")

    prepare_dirs(args.overwrite)

    print("Aurora Bank — Gerador Bronze Clientes")
    print("=" * 70)
    print(f"Modo: {args.mode}")
    print(f"Clientes: {total_customers:,}".replace(",", "."))
    print(f"Chunk size: {chunk_size:,}".replace(",", "."))
    print(f"Saída: {BRONZE_BASE}")
    print("=" * 70)

    rng = np.random.default_rng(args.seed)

    part = 1
    for start_id in range(1, total_customers + 1, chunk_size):
        end_id = min(start_id + chunk_size - 1, total_customers)
        print(f"Gerando partição {part:05d}: clientes {start_id:,} a {end_id:,}".replace(",", "."))

        dfs = generate_clientes_chunk(start_id, end_id, rng, part)
        write_partitions(dfs, part)

        print(
            "  Linhas gravadas: "
            f"core={len(dfs['clientes_core']):,}, "
            f"app={len(dfs['clientes_app']):,}, "
            f"enderecos={len(dfs['enderecos']):,}, "
            f"contatos={len(dfs['contatos']):,}, "
            f"scores={len(dfs['scores']):,}, "
            f"segmentos={len(dfs['segmentos']):,}"
        .replace(",", "."))

        part += 1

    print("\nGeração concluída.")
    print("Próximo passo: criar tabelas externas/consultas DuckDB apontando para os Parquets.")


if __name__ == "__main__":
    main()
