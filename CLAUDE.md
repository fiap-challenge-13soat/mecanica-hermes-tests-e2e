# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Ecosystem Context

This repository is **one of five** in the Mecânica Hermes ecosystem. They live as siblings under
`C:\git\mecanica-hermes\` (or equivalent). When working here, keep in mind:

| Repo | Role | Key tech |
|---|---|---|
| `mecanica-hermes-tests-e2e` | **This repo** — suíte E2E Robot Framework BDD cobrindo as 3 APIs em Docker Compose | Python 3.11, Robot Framework 7.2, Allure |
| `mecanica-hermes-api-ordem-servico` | Orquestra ordens de serviço (state machine, SAGA principal) | .NET 10, PostgreSQL, RabbitMQ |
| `mecanica-hermes-api-cadastros` | Cadastros de Clientes e Produtos; recebe webhook de aprovação/rejeição | .NET 10, PostgreSQL |
| `mecanica-hermes-api-pagamentos` | Integração Mercado Pago, gera link, recebe webhook MP | .NET 10, MongoDB |
| `mecanica-hermes-api-sdk` | SDK compartilhado em GitHub Packages (6 pacotes NuGet) | .NET 10 |

### Diferença frente aos outros 4 repos

- **Não é .NET**: este é um projeto Python. Não tente buildar com `dotnet`.
- **Consumidor das 3 APIs**: depende de imagens Docker `mechermes/*` no Docker Hub. Tags
  parametrizadas via `OS_IMAGE_TAG`, `CADASTROS_IMAGE_TAG`, `PAGAMENTOS_IMAGE_TAG` (default `latest`).
- **Não tem PR de SDK pendente**: o `api-sdk` é só para os 3 repos .NET de API. Aqui não muda.
- **Mocking de Mercado Pago**: feito via imagem oficial `wiremock/wiremock` no compose E2E
  (porta host 8090, container 8080). Mappings versionados em
  `tests/resources/fixtures/wiremock/mappings/` (montados como bind mount). A suíte nunca
  toca o sandbox real do MP.

## Commands

```bash
# Instalar dependências Python
pip install -r requirements.txt

# Subir toda a infraestrutura + 3 APIs (uma vez por sessão)
docker compose \
  -f docker-compose/docker-compose.yaml \
  -f docker-compose/docker-compose.e2e.yaml \
  up -d --wait

# Verificar healthchecks
curl http://localhost:8081/health   # OS
curl http://localhost:8082/health   # Cadastros
curl http://localhost:8083/health   # Pagamentos
curl http://localhost:8090/__admin/health  # WireMock

# Rodar todos os testes
robot --outputdir results tests/suites/

# Apenas smoke (caminho feliz)
robot --include smoke --outputdir results tests/suites/

# Uma suíte específica
robot --outputdir results tests/suites/01__caminho_feliz.robot

# Rodar com Allure (gera resultados em allure-results/)
robot --listener allure_robotframework --outputdir results tests/suites/
allure serve allure-results

# Derrubar tudo
docker compose \
  -f docker-compose/docker-compose.yaml \
  -f docker-compose/docker-compose.e2e.yaml \
  down -v
```

> `--wait` no `docker compose up` aguarda **todos** os healthchecks passarem antes de retornar.
> Útil em CI; localmente também evita executar Robot antes do banco estar pronto.

## Estrutura

```text
tests/
├── suites/                    # 8 arquivos .robot (BDD Gherkin)
│   ├── 01__caminho_feliz.robot
│   ├── 02__pagamento_cancelado_recriado.robot
│   ├── 03__orcamento_rejeitado.robot
│   ├── 04__cancelamento_em_execucao.robot
│   ├── 05__pagamento_expirado.robot
│   ├── 06__webhook_idempotencia.robot
│   ├── 07__saga_timeout_protection.robot
│   └── 08__cancelamento_em_aguardando_pagamento.robot
├── resources/
│   ├── variables/env.yaml     # variáveis comuns (URLs, timeouts)
│   ├── keywords/              # 1 .resource por API + common + wiremock
│   │   ├── common.resource
│   │   ├── os_api.resource
│   │   ├── cadastros_api.resource
│   │   ├── pagamentos_api.resource
│   │   └── wiremock.resource
│   └── fixtures/
│       └── wiremock/mappings/ # mappings WireMock (Mercado Pago mock — bind mount no compose)
docker-compose/
├── docker-compose.yaml        # infra base (Postgres, MongoDB, RabbitMQ)
├── docker-compose.e2e.yaml    # overrides E2E (WireMock + 3 APIs com tags)
└── services/
    ├── postgres/              # postgres.yaml (extends) + initdb scripts
    ├── mongodb/               # mongo.yaml (extends) — replica set single-node
    └── rabbitmq/              # rabbitmq.yaml + Dockerfile (com plugin delayed-message-exchange)
```

### Suítes (cobertura)

| Suíte | Fluxo testado | Tags |
|---|---|---|
| `01__caminho_feliz` | Recebida → ... → Entregue (pagamento aprovado) | `caminho-feliz` `smoke` |
| `02__pagamento_cancelado_recriado` | Pagamento recusado → reversão da OS → segundo pagamento aprovado | `pagamento-recusado` `resiliencia` |
| `03__orcamento_rejeitado` | Cliente rejeita pelo webhook → OS → `Rejeitada` | `orcamento-rejeitado` |
| `04__cancelamento_em_execucao` | Operador cancela durante `EmExecucao` → `Cancelada` | `cancelamento` |

### Padrão BDD (Gherkin) em Robot

Cada suíte usa `Given`/`When`/`Then`/`And` como prefixo de keywords:

```robot
*** Test Cases ***
Caminho feliz da ordem de servico
    [Tags]    caminho-feliz    smoke
    Given que existe um cliente cadastrado
    When uma OS é criada
    And o orcamento é aprovado pelo cliente via webhook
    And o pagamento é confirmado via Mercado Pago
    Then a OS deve estar no estado "Entregue"
```

As keywords resolvem em `tests/resources/keywords/*.resource`. Mantenha **sintaxe Gherkin
sempre em português** — alinhada ao domínio.

## CI

Workflow `.github/workflows/e2e-tests.yml`:

- Trigger: `workflow_dispatch` (manual), push em `main`/`feature/**`, e `pull_request` em `main`.
- Lê tags das imagens das APIs de `vars.OS_IMAGE_TAG`, `vars.CADASTROS_IMAGE_TAG`,
  `vars.PAGAMENTOS_IMAGE_TAG` (org-level), com fallback `latest`.
- Sobe Docker Compose, roda **todas as 8 suítes** (`robot tests/suites/`), gera report Allure
  via CLI direta (Java 21 + allure 2.30.0), e publica em GitHub Pages **apenas em push para `main`**.
- Robot roda com `continue-on-error: true` para garantir geração do Allure mesmo em falha;
  o job é marcado como failure ao final via step explícito que lê `steps.robot.outcome`.

GitHub Pages precisa estar **ativado manualmente** (Settings → Pages → Source: GitHub Actions)
para o passo de publish funcionar.

## Cross-service Integration Events (referência)

A suíte E2E valida indiretamente os 7 eventos cross-service versionados em `.v1`:

| Evento | Validado em |
|---|---|
| `ordem-de-servico.aguardando-aprovacao.v1` | `01`, `02`, `03` (verifica que webhook link foi gerado) |
| `orcamento-aprovado-pelo-cliente.v1` | `01`, `02`, `04` |
| `orcamento-rejeitado-pelo-cliente.v1` | `03` |
| `ordem-de-servico.aguardando-pagamento.v1` | `01`, `02` |
| `link-pagamento-gerado.v1` | `01`, `02` |
| `pagamento.confirmado.v1` | `01`, `02` (segunda tentativa) |
| `pagamento.recusado.v1` | `02` |

Os eventos não são inspecionados diretamente nas filas — a suíte valida o **efeito observável**
nos endpoints REST (estado da OS, link do webhook, status do pagamento).

## Convenções

- Sintaxe Robot 7.2 (Gherkin habilitado).
- Keywords sempre **em português** quando descrevem domínio; **em inglês** apenas para
  primitivas técnicas (`Create Session`, `Set To Dictionary` etc.).
- IDs gerados aleatoriamente em cada teste para evitar colisão (sufixo timestamp ou UUID).
- Cleanup via `Suite Teardown` derrubando os recursos criados no setup.
- WireMock mappings dinâmicos (`POST /__admin/mappings`) em vez de fixtures estáticos quando o
  teste precisar customizar resposta MP.

## Troubleshooting

- **`docker compose up` trava em healthcheck**: provável que algum migration script falhou.
  Inspecione `docker compose logs <serviço>`.
- **Robot diz "Connection refused"**: aguarde mais — startup das APIs leva ~30s no primeiro
  build. Se persistir, valide que `--wait` realmente foi passado.
- **Webhook do MP não dispara**: `WireMock` deve estar em `http://wiremock:8080` na rede docker
  (não `localhost:8090`). A configuração da API Pagamentos aponta para o nome do serviço.
- **Allure não gera report**: verifique que `allure-robotframework` está instalado e que o
  `--listener allure_robotframework` foi passado.
