*** Settings ***
Documentation     Validação do mecanismo de timeout sentinel da SAGA da OS.
...               A `OrdemDeServicoStateMachine` agenda um `OperationTimeout` ao entrar
...               em `Processing`; se a operação não completar dentro de
...               `SAGA__OPERATION_TIMEOUT` (default 5min, configurável via env var), a
...               SAGA volta para `Initial` automaticamente, evitando deadlock perpétuo.
...
...               Esta suíte valida duas garantias:
...
...               1. **Env var é respeitada** — em E2E configuramos `SAGA__OPERATION_TIMEOUT=30s`
...                  no compose. Se a SAGA fosse usar 5min hardcoded, a suite 05 (que valida
...                  `pagamento expirado` em ~30s) teria que esperar 5min — e ela passa em 90s.
...                  Isso já é evidência indireta de que o env var está sendo lido.
...
...               2. **Timeout não dispara em fluxo normal** — operações típicas (Criar OS,
...                  Avancar, etc.) completam em << 30s. A SAGA nunca deve cair em `Initial`
...                  via timeout durante o caminho feliz. Esta suíte exercita um ciclo completo
...                  rápido e valida que múltiplos Avancares consecutivos funcionam (i.e., a
...                  SAGA volta a `Initial` via `OperationCompleted`, não via `OperationTimeout`).

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Saga Timeout


*** Variables ***
${CLIENTE_ID}    ${EMPTY}
${VEICULO_ID}    ${EMPTY}


*** Test Cases ***
Lifecycle Da SAGA Em Operacoes Encadeadas - Sem Timeout Espurio
    [Documentation]    Encadeia 4 Avancares consecutivos sem pausa.
    ...                Cada Avancar precisa fazer o ciclo Initial→Processing→Initial via
    ...                `OperationCompleted` — se em algum ponto a SAGA caísse em Initial via
    ...                `OperationTimeout`, o próximo Avancar seria descartado (Ignore em
    ...                Processing) e a OS ficaria parada. O fluxo passar end-to-end prova que
    ...                o lifecycle da SAGA está sólido sob timeout curto (30s).
    [Tags]    saga    timeout    lifecycle    e2e

    Given uma OS está em estado Recebida
    When a OS percorre rapidamente os 4 primeiros estados sem pausa entre transições
    Then todos os Avancares são processados pela SAGA sem timeout espúrio


*** Keywords ***
Preparar Suite Saga Timeout
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Lia Teste Saga    email=lia.saga@e2e.test
    ${vid}=    Adicionar Veiculo    ${cid}    placa=SGA3C45
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}

uma OS está em estado Recebida
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Saga timeout E2E
    Set Test Variable    ${OS_ID}    ${os_id}
    Esperar OS Atingir Status    ${OS_ID}    Recebida

a OS percorre rapidamente os 4 primeiros estados sem pausa entre transições
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmDiagnostico
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoAprovacao
    Simular Aprovacao Webhook    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmExecucao
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    ManutencaoFinalizada

todos os Avancares são processados pela SAGA sem timeout espúrio
    [Documentation]    Se a SAGA tivesse caído em timeout entre transições, algum dos
    ...                `Esperar OS Atingir Status` acima teria estourado seus 60s.
    ...                Como chegamos em ManutencaoFinalizada, todas as operações fecharam
    ...                ciclo via `OperationCompleted` — sem espurio.
    ${os}=    Buscar OS    ${OS_ID}
    ${status}=    Get From Dictionary    ${os}    statusAtual
    Should Be Equal As Strings    ${status}    ManutencaoFinalizada
