*** Settings ***
Documentation     Idempotência do webhook de aprovação de orçamento.
...               O Cadastros tem um WebhookEventRepository com unique index em
...               (scope, externalId) para deduplicar redeliveries (cliente clica 2x
...               no link, MP redelivera, etc.). Esta suíte valida que o segundo clique
...               retorna sucesso (HTML "já aprovado") mas NÃO dispara segundo evento
...               de domínio: a OS não deve regredir nem se duplicar.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Webhook Idempotencia


*** Variables ***
${CLIENTE_ID}    ${EMPTY}
${VEICULO_ID}    ${EMPTY}


*** Test Cases ***
Webhook Aprovacao Duplicado - OS Avanca Apenas Uma Vez
    [Documentation]    O cliente clica em "Aprovar" duas vezes (rede flaky / duplo-clique).
    ...                Validações: ambos os HTTP retornam 200, OS transiciona para EmExecucao
    ...                exatamente uma vez, e a OS continua avançando normalmente após o duplo-clique
    ...                (i.e., o handler idempotente não corrompe o estado).
    [Tags]    webhook    idempotencia    e2e

    Given uma OS está em AguardandoAprovacao
    When o cliente aprova o orçamento via webhook
    Then a OS avança automaticamente para EmExecucao

    When o cliente clica novamente no link de aprovação (redelivery)
    Then o segundo webhook retorna sucesso sem regredir a OS
    And a OS continua progredindo normalmente quando o operador avança


*** Keywords ***
Preparar Suite Webhook Idempotencia
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Roberto Teste Idempotencia    email=roberto.idemp@e2e.test
    ${vid}=    Adicionar Veiculo    ${cid}    placa=IDP2B34
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}

uma OS está em AguardandoAprovacao
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Webhook idempotencia E2E
    Set Test Variable    ${OS_ID}    ${os_id}
    Esperar OS Atingir Status    ${OS_ID}    Recebida
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmDiagnostico
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoAprovacao

o cliente aprova o orçamento via webhook
    Simular Aprovacao Webhook    ${OS_ID}

a OS avança automaticamente para EmExecucao
    Esperar OS Atingir Status    ${OS_ID}    EmExecucao

o cliente clica novamente no link de aprovação (redelivery)
    Simular Aprovacao Webhook    ${OS_ID}

o segundo webhook retorna sucesso sem regredir a OS
    [Documentation]    Damos uma janela curta para qualquer evento espúrio se propagar via
    ...                outbox/saga, e validamos que a OS continua em EmExecucao (não regrediu
    ...                para AguardandoAprovacao nem foi corrompida por evento duplicado).
    Sleep    ${POLL_INTERVAL}s
    ${os}=    Buscar OS    ${OS_ID}
    ${status}=    Get From Dictionary    ${os}    statusAtual
    Should Be Equal As Strings    ${status}    EmExecucao
    ...    msg=Após o segundo webhook, OS deveria continuar em EmExecucao. Encontrado: ${status}

a OS continua progredindo normalmente quando o operador avança
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    ManutencaoFinalizada
