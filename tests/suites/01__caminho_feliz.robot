*** Settings ***
Documentation     Fluxo completo da Ordem de Serviço: do recebimento à entrega sem desvios.
...               Cobre o caminho feliz end-to-end através das 3 APIs.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/pagamentos_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Caminho Feliz
Suite Teardown  Resetar Cenarios WireMock


*** Variables ***
${CLIENTE_ID}       ${EMPTY}
${VEICULO_ID}       ${EMPTY}
${PRODUTO_ID}       ${EMPTY}
${SERVICO_ID}       ${EMPTY}


*** Test Cases ***
Ciclo Completo - Recebida Ate Entregue
    [Documentation]    Valida que uma OS percorre todos os estados do ciclo de vida feliz:
    ...                Recebida → EmDiagnostico → AguardandoAprovacao → EmExecucao
    ...                → ManutencaoFinalizada → AguardandoPagamento → PagamentoConfirmado → Entregue
    [Tags]    caminho-feliz    smoke    e2e

    Given o WireMock retorna pagamento aprovado
    And uma nova OS é criada para o cliente e veículo cadastrados
    And produto e serviço são adicionados à OS em diagnóstico
    When a OS avança para AguardandoAprovacao
    Then a OS aguarda a aprovação do cliente

    When o cliente aprova o orçamento via webhook
    Then a OS avança automaticamente para EmExecucao

    When a OS avança para ManutencaoFinalizada
    And a OS avança para AguardandoPagamento
    Then Pagamentos processa o evento e cria o link de pagamento
    And a OS avança automaticamente para PagamentoConfirmado

    When a OS avança para Entregue
    Then o status final da OS é Entregue


*** Keywords ***
Preparar Suite Caminho Feliz
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Maria Teste Feliz    email=maria.feliz@e2e.test    cpf=52998224725
    ${vid}=    Adicionar Veiculo    ${cid}
    ${pid}=    Criar Produto    descricao=Filtro E2E Feliz    valor=90.00
    ${sid}=    Criar Servico    descricao=Revisão E2E Feliz    valor=180.00
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}
    Set Suite Variable    ${PRODUTO_ID}    ${pid}
    Set Suite Variable    ${SERVICO_ID}    ${sid}

o WireMock retorna pagamento aprovado
    Resetar Cenarios WireMock

uma nova OS é criada para o cliente e veículo cadastrados
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Revisão completa E2E caminho feliz
    Set Test Variable    ${OS_ID}    ${os_id}
    Esperar OS Atingir Status    ${OS_ID}    Recebida
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    EmDiagnostico

produto e serviço são adicionados à OS em diagnóstico
    Adicionar Produto A OS    ${OS_ID}    ${PRODUTO_ID}
    Adicionar Servico A OS    ${OS_ID}    ${SERVICO_ID}

a OS avança para AguardandoAprovacao
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoAprovacao

a OS aguarda a aprovação do cliente
    ${os}=    Buscar OS    ${OS_ID}
    ${status}=    Get From Dictionary    ${os}    statusAtual
    Should Be Equal As Strings    ${status}    AguardandoAprovacao

o cliente aprova o orçamento via webhook
    Simular Aprovacao Webhook    ${OS_ID}

a OS avança automaticamente para EmExecucao
    Esperar OS Atingir Status    ${OS_ID}    EmExecucao

a OS avança para ManutencaoFinalizada
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    ManutencaoFinalizada

a OS avança para AguardandoPagamento
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoPagamento

Pagamentos processa o evento e cria o link de pagamento
    # OrdemDeServicoAguardandoPagamentoEvent → Pagamentos → WireMock (preference) → LinkPagamentoGeradoEvent → OS
    Log    Aguardando Pagamentos processar o evento e polling MP aprovar via WireMock...

a OS avança automaticamente para PagamentoConfirmado
    Esperar OS Atingir Status    ${OS_ID}    PagamentoConfirmado

a OS avança para Entregue
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    Entregue

o status final da OS é Entregue
    ${os}=    Buscar OS    ${OS_ID}
    ${status}=    Get From Dictionary    ${os}    statusAtual
    Should Be Equal As Strings    ${status}    Entregue
