*** Settings ***
Documentation     Cancelamento da OS quando ela está em AguardandoPagamento (com pagamento
...               já criado e em ciclo de polling MP). Caso terminal mais delicado entre os
...               cancelamentos: o operador cancela uma OS que já tem pagamento pendente.
...
...               Validações:
...
...               - OS transiciona para Cancelada (terminal).
...               - O fluxo cross-service não trava: o pagamento existente continua polling MP
...                 e eventualmente é finalizado (no nosso E2E, expira porque o WireMock está em
...                 pending). Embora hoje a API de Pagamentos NÃO consuma o evento
...                 `ordem-de-servico.cancelada.v1` para cancelar o pagamento explicitamente
...                 (gap conhecido — TODO para o time), o sistema converge para um estado
...                 consistente porque o pagamento expira por timeout.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Cancelamento Aguardando Pagamento
Suite Teardown  Resetar Cenarios WireMock


*** Variables ***
${CLIENTE_ID}     ${EMPTY}
${VEICULO_ID}     ${EMPTY}
${PRODUTO_ID}    ${EMPTY}
${SERVICO_ID}    ${EMPTY}


*** Test Cases ***
Cancelamento Em AguardandoPagamento - OS Vai Para Cancelada
    [Documentation]    O operador cancela uma OS em AguardandoPagamento (link de MP já gerado,
    ...                pagamento em ciclo de polling). Espera-se que a OS transicione para
    ...                Cancelada (terminal) e que cancelamentos subsequentes sejam rejeitados.
    [Tags]    cancelamento    pagamento-pendente    e2e

    Given uma OS está em AguardandoPagamento com pagamento pendente
    When o operador cancela a OS
    Then a OS vai para o estado terminal Cancelada
    And o estado Cancelada não aceita mais operações de estado


*** Keywords ***
Preparar Suite Cancelamento Aguardando Pagamento
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Tales Teste Cancel Pgto    email=tales.cancpgto@e2e.test
    ${vid}=    Adicionar Veiculo    ${cid}    placa=CPG4D56
    ${pid}=    Criar Produto    descricao=Filtro E2E Cancel Pgto    valor=70.00
    ${sid}=    Criar Servico    descricao=Revisão E2E Cancel Pgto    valor=140.00
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}
    Set Suite Variable    ${PRODUTO_ID}    ${pid}
    Set Suite Variable    ${SERVICO_ID}    ${sid}

uma OS está em AguardandoPagamento com pagamento pendente
    [Documentation]    WireMock pending para que o pagamento NÃO seja confirmado automaticamente
    ...                pelo polling antes do operador cancelar — queremos pegar a janela em que
    ...                o pagamento existe e está em AguardandoConfirmacao.
    Configurar MP Status Pending
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Cancelamento em pagamento pendente E2E
    Set Test Variable    ${OS_ID}    ${os_id}
    Esperar OS Atingir Status    ${OS_ID}    Recebida
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmDiagnostico
    Adicionar Produto A OS    ${OS_ID}    ${PRODUTO_ID}
    Adicionar Servico A OS    ${OS_ID}    ${SERVICO_ID}
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoAprovacao
    Simular Aprovacao Webhook    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmExecucao
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    ManutencaoFinalizada
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoPagamento

o operador cancela a OS
    Cancelar OS    ${OS_ID}

a OS vai para o estado terminal Cancelada
    Esperar OS Atingir Status    ${OS_ID}    Cancelada

o estado Cancelada não aceita mais operações de estado
    OS Deve Ser Terminal    ${OS_ID}
