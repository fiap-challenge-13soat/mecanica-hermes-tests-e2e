*** Settings ***
Documentation     Fluxo de resiliência no pagamento: primeiro pagamento é recusado pelo Mercado Pago,
...               a OS reverte para ManutencaoFinalizada, um segundo pagamento é criado e aprovado,
...               completando o ciclo até Entregue.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/pagamentos_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Pagamento Cancelado
Suite Teardown  Resetar Cenarios WireMock


*** Variables ***
${CLIENTE_ID}    ${EMPTY}
${VEICULO_ID}    ${EMPTY}
${PRODUTO_ID}    ${EMPTY}
${SERVICO_ID}    ${EMPTY}


*** Test Cases ***
Pagamento Recusado - Segundo Pagamento Aprovado - Entrega
    [Documentation]    O primeiro pagamento é recusado pelo MP. A OS reverte para ManutencaoFinalizada.
    ...                Configura WireMock para aprovar o segundo pagamento e verifica entrega final.
    [Tags]    pagamento-recusado    resiliencia    e2e

    Given uma OS está aprovada e em ManutencaoFinalizada
    And o WireMock está configurado para recusar o pagamento

    When a OS avança para AguardandoPagamento pela primeira vez
    Then Pagamentos cria o link mas o MP recusa o pagamento
    And a OS reverte automaticamente para ManutencaoFinalizada

    When o WireMock é configurado para aprovar o próximo pagamento
    And a OS avança para AguardandoPagamento pela segunda vez
    Then o MP aprova o segundo pagamento
    And a OS avança automaticamente para PagamentoConfirmado

    When a OS avança para Entregue
    Then o status final da OS é Entregue


*** Keywords ***
Preparar Suite Pagamento Cancelado
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Carlos Teste Recusado    email=carlos.recusado@e2e.test    cpf=11144477735
    ${vid}=    Adicionar Veiculo    ${cid}    placa=DEF2G34
    ${pid}=    Criar Produto    descricao=Filtro E2E Recusado    valor=75.00
    ${sid}=    Criar Servico    descricao=Revisão E2E Recusado    valor=150.00
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}
    Set Suite Variable    ${PRODUTO_ID}    ${pid}
    Set Suite Variable    ${SERVICO_ID}    ${sid}

uma OS está aprovada e em ManutencaoFinalizada
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Teste pagamento recusado E2E
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

o WireMock está configurado para recusar o pagamento
    Configurar MP Status Recusado

a OS avança para AguardandoPagamento pela primeira vez
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoPagamento

Pagamentos cria o link mas o MP recusa o pagamento
    Log    WireMock retornará 'rejected' no polling de status do pagamento

a OS reverte automaticamente para ManutencaoFinalizada
    Esperar OS Atingir Status    ${OS_ID}    ManutencaoFinalizada

o WireMock é configurado para aprovar o próximo pagamento
    Configurar MP Status Aprovado

a OS avança para AguardandoPagamento pela segunda vez
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoPagamento

o MP aprova o segundo pagamento
    Log    WireMock retornará 'approved' no polling de status do segundo pagamento

a OS avança automaticamente para PagamentoConfirmado
    Esperar OS Atingir Status    ${OS_ID}    PagamentoConfirmado

a OS avança para Entregue
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    Entregue

o status final da OS é Entregue
    ${os}=    Buscar OS    ${OS_ID}
    ${status}=    Get From Dictionary    ${os}    statusAtual
    Should Be Equal As Strings    ${status}    Entregue
