*** Settings ***
Documentation     Cancelamento de uma OS durante a execução da manutenção.
...               Valida que o cancelamento é permitido em EmExecucao e resulta
...               em estado terminal Cancelada.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Cancelamento


*** Variables ***
${CLIENTE_ID}    ${EMPTY}
${VEICULO_ID}    ${EMPTY}


*** Test Cases ***
Cancelamento Durante Execucao
    [Documentation]    Valida que uma OS em EmExecucao pode ser cancelada pelo operador
    ...                e o estado Cancelada é terminal (sem retorno).
    [Tags]    cancelamento    e2e

    Given uma OS está em EmExecucao com orçamento aprovado
    When o operador cancela a OS
    Then a OS vai para o estado terminal Cancelada
    And o estado Cancelada não aceita mais operações de estado


*** Keywords ***
Preparar Suite Cancelamento
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Pedro Teste Cancel    email=pedro.cancel@e2e.test    cpf=35453285878
    ${vid}=    Adicionar Veiculo    ${cid}    placa=JKL4M56
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}

uma OS está em EmExecucao com orçamento aprovado
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Freios com problema E2E
    Set Test Variable    ${OS_ID}    ${os_id}
    Esperar OS Atingir Status    ${OS_ID}    Recebida
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmDiagnostico
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoAprovacao
    Simular Aprovacao Webhook    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmExecucao

o operador cancela a OS
    Cancelar OS    ${OS_ID}

a OS vai para o estado terminal Cancelada
    Esperar OS Atingir Status    ${OS_ID}    Cancelada

o estado Cancelada não aceita mais operações de estado
    OS Deve Ser Terminal    ${OS_ID}
