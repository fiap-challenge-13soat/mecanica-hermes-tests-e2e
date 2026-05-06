# Mecânica Hermes — Testes E2E

Suíte de testes end-to-end das APIs Mecânica Hermes usando **Robot Framework** com sintaxe **BDD (Gherkin)** e ambiente Docker Compose completo.

## Cobertura

| Suíte | Fluxo | Tag |
|---|---|---|
| `01__caminho_feliz` | Recebida → EmDiagnostico → AguardandoAprovacao → EmExecucao → ManutencaoFinalizada → AguardandoPagamento → PagamentoConfirmado → Entregue | `caminho-feliz` `smoke` |
| `02__pagamento_cancelado_recriado` | Primeiro pagamento recusado → OS reverte → segundo pagamento aprovado → Entregue | `pagamento-recusado` `resiliencia` |
| `03__orcamento_rejeitado` | AguardandoAprovacao → cliente rejeita webhook → Rejeitada (terminal) | `orcamento-rejeitado` |
| `04__cancelamento_em_execucao` | EmExecucao → operador cancela → Cancelada (terminal) | `cancelamento` |

## Pré-requisitos

- Docker 24+ com Docker Compose v2
- Python 3.11+
- Imagens Docker das 3 APIs publicadas no Docker Hub (`mechermes/*`)

## Início rápido

### 1. Instalar dependências Python

```bash
pip install -r requirements.txt
```

### 2. Subir toda a infraestrutura + APIs

```bash
docker compose \
  -f docker-compose/docker-compose.yaml \
  -f docker-compose/docker-compose.e2e.yaml \
  up -d --wait
```

> `--wait` aguarda todos os healthchecks passarem antes de retornar.

### 3. Verificar que tudo subiu

```bash
curl http://localhost:8081/health   # OS
curl http://localhost:8082/health   # Cadastros
curl http://localhost:8083/health   # Pagamentos
curl http://localhost:8090/__admin/health  # WireMock
```

### 4. Executar os testes

```bash
# Todos os testes
robot --outputdir results tests/suites/

# Apenas smoke (caminho feliz)
robot --include smoke --outputdir results tests/suites/

# Uma suíte específica
robot --outputdir results tests/suites/01__caminho_feliz.robot
```

O relatório HTML fica em `results/report.html`.

### 5. Derrubar o ambiente

```bash
docker compose \
  -f docker-compose/docker-compose.yaml \
  -f docker-compose/docker-compose.e2e.yaml \
  down -v
```

## Relatórios

A suíte gera dois conjuntos de relatórios em cada execução: o padrão do Robot Framework (rápido, local) e o **Allure** (rico, com histórico, anexos, drill-down). Em CI o Allure é publicado em **GitHub Pages** com histórico das últimas 20 execuções.

### Robot Framework (padrão)

Após `robot ... tests/suites/`, abra `results/report.html` no navegador. Esse é o relatório nativo, gerado sempre.

### Allure (relatório rico, local)

Pré-requisito: **Allure CLI** instalado (Java 8+). No Windows: `scoop install allure` ou via Chocolatey/npm. No macOS: `brew install allure`. No Linux: baixar do [GitHub Releases](https://github.com/allure-framework/allure2/releases).

```bash
# Executar com listener Allure
robot --listener allure_robotframework:allure-results \
      --outputdir results \
      tests/suites/

# Visualizar (sobe um servidor local e abre o browser)
allure serve allure-results

# Ou gerar HTML estático
allure generate allure-results -o allure-report --clean
allure open allure-report
```

### CI / Histórico online

Cada push em `main` dispara o workflow `.github/workflows/e2e-tests.yml`, que:

- Executa as 4 suítes contra todo o ambiente Docker (3 APIs + WireMock + infra)
- Publica o relatório Allure em **GitHub Pages** com histórico das 20 últimas execuções
- Faz upload de `allure-report` e `robot-results` como **artefatos** do GitHub Actions (retenção 30 dias)

URL do relatório online (após habilitar GitHub Pages com source `gh-pages`):

> **https://fiap-challenge-13soat.github.io/mecanica-hermes-tests-e2e/**

Para baixar relatórios de uma execução específica (ex.: PR), abra a Action correspondente no GitHub → seção **Artifacts**.

## Estrutura

```
tests/
├── resources/
│   ├── keywords/
│   │   ├── common.resource         # polling, HMAC, utilitários
│   │   ├── os_api.resource         # wrappers da API de OS
│   │   ├── cadastros_api.resource  # wrappers da API de Cadastros + webhook
│   │   ├── pagamentos_api.resource # wrappers da API de Pagamentos
│   │   └── wiremock.resource       # controle de cenários WireMock
│   ├── variables/
│   │   └── env.yaml               # URLs, timeouts, secrets
│   └── fixtures/
│       └── wiremock/mappings/     # mapeamentos WireMock (Mercado Pago mock)
└── suites/                        # 4 suítes .robot
```

## Serviços no Docker Compose E2E

| Serviço | Porta local | Descrição |
|---|---|---|
| `api-os` | 8081 | API de Ordem de Serviço |
| `api-cadastros` | 8082 | API de Cadastros |
| `api-pagamentos` | 8083 | API de Pagamentos |
| `wiremock` | 8090 | Mock do Mercado Pago |
| `postgres` | 5432 | PostgreSQL (OS + Cadastros) |
| `mongo` | 27017 | MongoDB (Pagamentos SAGA + Outbox) |
| `rabbitmq` | 5672 / 15672 | RabbitMQ + Management UI |

## Notas de design

- **Autenticação**: `ASPNETCORE_ENVIRONMENT=Testing` ativa o `DevelopmentAuthenticationMiddleware` que bypassa JWT em todas as APIs
- **WireMock**: emula `POST /checkout/preferences` e `GET /v1/payments/search` do Mercado Pago
- **HMAC webhook**: o keyword `Calcular HMAC SHA256` computa o token com o secret fixo configurado no Compose
- **Polling assíncrono**: `Wait Until Keyword Succeeds` faz polling a cada 3s com timeout de 60s por espera de status
- **Cenários WireMock**: o suite 02 alterna entre "recusado" e "aprovado" via WireMock Scenarios API
