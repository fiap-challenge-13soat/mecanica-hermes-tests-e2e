# Docker Compose — Stack E2E Mecânica Hermes

Configuração canônica do stack completo do ecossistema Mecânica Hermes para
execução local e CI: 3 APIs (.NET) + WireMock + infraestrutura (Postgres, MongoDB
com replica set, RabbitMQ com plugin de delayed exchange).

![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.1-336791?logo=postgresql&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-7-47A248?logo=mongodb&logoColor=white)
![RabbitMQ](https://img.shields.io/badge/RabbitMQ-4.1-FF6600?logo=rabbitmq&logoColor=white)

## Pré-requisitos

- Docker 24+ com Docker Compose v2
- Acesso ao Docker Hub (puxa `mechermes/*:latest` automaticamente)

## Configuração

### 1. Copiar variáveis de ambiente

```bash
cp .env.example .env
```

O `.env` é **gitignored** — não comita credenciais. O `.env.example` lista as
chaves esperadas com valores dummy.

### 2. (Opcional) Editar tags de imagens

Para fixar uma versão específica das APIs em vez de `latest`, edite no `.env`:

```env
OS_IMAGE_TAG=sha-abcd1234
CADASTROS_IMAGE_TAG=sha-abcd1234
PAGAMENTOS_IMAGE_TAG=sha-abcd1234
```

## Subir o stack

A partir da raiz do repositório:

```bash
docker compose \
  -f docker-compose/docker-compose.yaml \
  -f docker-compose/docker-compose.e2e.yaml \
  up -d --wait --build --pull always
```

Flags importantes:

- `--wait`: aguarda **todos** os healthchecks passarem antes de retornar (~30-60s).
- `--build`: força build da imagem custom do RabbitMQ (com plugin
  `rabbitmq_delayed_message_exchange`).
- `--pull always`: garante `:latest` atualizado das 3 APIs no Docker Hub.

## Serviços e portas

| Serviço | Porta host | Porta container | Descrição |
|---|---|---|---|
| `api-os` | 8081 | 8080 | API de Ordem de Serviço |
| `api-cadastros` | 8082 | 8080 | API de Cadastros |
| `api-pagamentos` | 8083 | 8080 | API de Pagamentos (Mercado Pago via WireMock) |
| `wiremock` | 8090 | 8080 | Mock do Mercado Pago (mappings em `tests/resources/fixtures/wiremock/mappings/`) |
| `postgres` | 5432 | 5432 | OS + Cadastros (DBs criados via `services/postgres/initdb/`) |
| `mongo` | 27017 | 27017 | Pagamentos (SAGA + Outbox) — replica set `rs0` |
| `rabbitmq` | 5672 / 15672 | 5672 / 15672 | Bus + Management UI (`guest`/`guest`) |

## Verificar saúde

```bash
curl -fs http://localhost:8081/health   # OS
curl -fs http://localhost:8082/health   # Cadastros
curl -fs http://localhost:8083/health   # Pagamentos
curl -fs http://localhost:8090/__admin/health   # WireMock
```

## Comandos úteis

```bash
# Ver status
docker compose -f docker-compose/docker-compose.yaml -f docker-compose/docker-compose.e2e.yaml ps

# Logs (todos os serviços)
docker compose -f docker-compose/docker-compose.yaml -f docker-compose/docker-compose.e2e.yaml logs -f

# Logs de um serviço específico
docker compose -f docker-compose/docker-compose.yaml -f docker-compose/docker-compose.e2e.yaml logs -f api-pagamentos

# Derrubar (com volumes — limpa databases)
docker compose -f docker-compose/docker-compose.yaml -f docker-compose/docker-compose.e2e.yaml down -v
```

## Estrutura

```text
docker-compose/
├── docker-compose.yaml         # Infra base (postgres, mongo, rabbitmq via extends)
├── docker-compose.e2e.yaml     # Overrides E2E: WireMock + 3 APIs (mechermes/*)
├── .env.example                # Template (versionado, sem segredos)
├── .env                        # Local, gitignored (cópia editável)
└── services/
    ├── postgres/
    │   ├── postgres.yaml       # Service definition (extends)
    │   ├── initdb/             # Scripts de criação de DBs
    │   └── postgres_data/      # Volume persistente (gitignored)
    ├── mongodb/
    │   ├── mongo.yaml          # Service definition (replica set)
    │   └── mongo_data/         # Volume (gitignored)
    └── rabbitmq/
        ├── rabbitmq.yaml       # Service definition (refere o Dockerfile)
        ├── Dockerfile          # rabbitmq:4.1-management + plugin delayed-message-exchange
        └── rabbitmq_data/      # Volume (gitignored)
```

## Troubleshooting

### Stack não sobe healthy

1. Verifique logs do serviço que travou: `docker compose ... logs <serviço>`
2. Postgres precisa de migrations das APIs — se `api-os` falha primeiro start, é porque
   `RUN_MIGRATIONS_ON_STARTUP` não rodou. Tente `down -v` e `up` novo.
3. RabbitMQ custom build falha se a versão do plugin não pareia com o broker — não
   altere `rabbitmq:4.1-management` sem alinhar `PLUGIN_VERSION` no `Dockerfile`.

### Webhook do Mercado Pago não dispara

A configuração da API Pagamentos aponta para `http://wiremock:8080` (DNS interno
da rede docker, **não** `localhost:8090`).

### Port já em uso (`bind: address already in use`)

Outro container/serviço local está ocupando a porta. Pare ou edite a coluna
"Porta host" no compose.

## Referências

- Suíte E2E (Robot Framework): pasta raiz do repo (`tests/suites/`).
- Workflow CI: `.github/workflows/e2e-tests.yml`.
- Documentação principal e cobertura: [`README.md`](../README.md) na raiz.
