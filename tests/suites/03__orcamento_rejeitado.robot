*** Settings ***
Documentation     Fluxo de rejeição de orçamento: cliente recebe o e-mail, clica em "Rejeitar"
...               e a OS vai para o estado terminal Rejeitada.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Orcamento Rejeitado


*** Variables ***
${CLIENTE_ID}    ${EMPTY}
${VEICULO_ID}    ${EMPTY}


*** Test Cases ***
Cliente Rejeita Orcamento - OS Vai Para Rejeitada
    [Documentation]    Após o orçamento ser enviado, o cliente clica em "Rejeitar".
    ...                Valida que a OS transiciona para o estado terminal Rejeitada
    ...                e não pode mais avançar.
    [Tags]    orcamento-rejeitado    e2e

    Given uma OS está em AguardandoAprovacao aguardando decisão do cliente
    When o cliente rejeita o orçamento com motivo "Preço elevado demais"
    Then a OS transiciona automaticamente para Rejeitada
    And o estado Rejeitada é terminal e não aceita mais avanços


*** Keywords ***
Preparar Suite Orcamento Rejeitado
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Ana Teste Rejeição    email=ana.rejeicao@e2e.test
    ${vid}=    Adicionar Veiculo    ${cid}    placa=GHI3J45
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}

uma OS está em AguardandoAprovacao aguardando decisão do cliente
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Suspensão com barulho E2E
    Set Test Variable    ${OS_ID}    ${os_id}
    Esperar OS Atingir Status    ${OS_ID}    Recebida
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmDiagnostico
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoAprovacao

o cliente rejeita o orçamento com motivo "Preço elevado demais"
    Simular Rejeicao Webhook    ${OS_ID}    Preço elevado demais

a OS transiciona automaticamente para Rejeitada
    Esperar OS Atingir Status    ${OS_ID}    Rejeitada

o estado Rejeitada é terminal e não aceita mais avanços
    OS Deve Ser Terminal    ${OS_ID}
