*** Settings ***
Documentation     Cancelamento da OS quando ela está em AguardandoPagamento (com pagamento
...               já criado e em ciclo de polling MP). Caso terminal mais delicado entre os
...               cancelamentos: o operador cancela uma OS que já tem pagamento pendente.
...
...               Validações:
...
...               - OS transiciona para Cancelada (terminal).
...               - Cross-service: a API de Pagamentos consome `ordem-de-servico.cancelada.v1`
...                 e recusa o pagamento ativo imediatamente — não esperamos o timeout do polling
...                 MP. Validamos consultando o pagamento via `GET /api/pagamentos?ordemDeServicoId=...`
...                 (ou equivalente, ver helper). Antes desta cobertura, o pagamento ficava órfão
...                 polling até expirar (~30s).

Library     Process

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
Cancelamento Em AguardandoPagamento - OS Vai Para Cancelada E Pagamento É Recusado
    [Documentation]    O operador cancela uma OS em AguardandoPagamento (link de MP já gerado,
    ...                pagamento em ciclo de polling). Espera-se que (a) a OS transicione para
    ...                Cancelada (terminal); (b) o `OrdemDeServicoCanceladaConsumer` da Pagamentos
    ...                consuma o evento `ordem-de-servico.cancelada.v1` e recuse o pagamento
    ...                ativo, evitando que o polling MP siga consumindo recursos; (c) o estado
    ...                Cancelada da OS rejeite avanços subsequentes.
    [Tags]    cancelamento    pagamento-pendente    cross-service    e2e

    Given uma OS está em AguardandoPagamento com pagamento pendente
    When o operador cancela a OS
    Then a OS vai para o estado terminal Cancelada
    And o pagamento associado é recusado pela Pagamentos via evento de cancelamento
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

o pagamento associado é recusado pela Pagamentos via evento de cancelamento
    [Documentation]    Aguarda o `OrdemDeServicoCanceladaConsumer` da Pagamentos processar o
    ...                evento e marcar o pagamento como Recusado. A janela é folgada (30s) para
    ...                tolerar latência de outbox + bus + dispatch + persist.
    Wait Until Keyword Succeeds    30s    2s    Pagamento Da OS Deve Estar Recusado    ${OS_ID}

o estado Cancelada não aceita mais operações de estado
    OS Deve Ser Terminal    ${OS_ID}

Pagamento Da OS Deve Estar Recusado
    [Arguments]    ${os_id}
    ${result}=    Run Process    docker    exec    mongo    mongosh    mechermes_pagamento_e2e
    ...    --quiet    --eval    db.pagamentos.findOne({"ordemDeServicoId": UUID("${os_id}")}, {"statusAtual": 1, "_id": 0})
    Should Contain    ${result.stdout}    Recusado
    ...    msg=Pagamento da OS ${os_id} deveria estar Recusado pelo consumer cross-service. Saída do mongo: ${result.stdout}
