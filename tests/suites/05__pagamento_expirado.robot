*** Settings ***
Documentation     Pagamento expirado por timeout: Mercado Pago retorna pending por todo o ciclo
...               de polling de Pagamentos. Após esgotar PAGAMENTO__POLLING_MAX_ATTEMPTS, o
...               Pagamento é marcado Expirado, Pagamentos publica `pagamento.recusado.v1`
...               (com motivo "Pagamento expirado.") e a OS reverte para ManutencaoFinalizada.
...
...               Cobre o pathway de timeout do polling — feature em produção mas sem teste
...               E2E até este momento.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/os_api.resource
Resource    ../resources/keywords/cadastros_api.resource
Resource    ../resources/keywords/wiremock.resource

Suite Setup     Preparar Suite Pagamento Expirado
Suite Teardown  Resetar Cenarios WireMock


*** Variables ***
${CLIENTE_ID}     ${EMPTY}
${VEICULO_ID}     ${EMPTY}
${PRODUTO_ID}    ${EMPTY}
${SERVICO_ID}    ${EMPTY}


*** Test Cases ***
Pagamento Expira Por Timeout - OS Reverte Para ManutencaoFinalizada
    [Documentation]    O polling do Mercado Pago recebe `pending` ad infinitum.
    ...                Após esgotar as tentativas, o Pagamento expira e a OS reverte
    ...                para ManutencaoFinalizada para que o operador possa retentar.
    [Tags]    pagamento-expirado    resiliencia    e2e    timeout

    Given uma OS está aprovada e em ManutencaoFinalizada
    And o WireMock está configurado para retornar pending no polling
    When a OS avança para AguardandoPagamento
    Then a OS reverte automaticamente para ManutencaoFinalizada após o timeout do polling


*** Keywords ***
Preparar Suite Pagamento Expirado
    Verificar WireMock Disponivel
    ${cid}=    Criar Cliente    nome=Sofia Teste Expirado    email=sofia.expirado@e2e.test
    ${vid}=    Adicionar Veiculo    ${cid}    placa=EXP1A23
    ${pid}=    Criar Produto    descricao=Filtro E2E Expirado    valor=80.00
    ${sid}=    Criar Servico    descricao=Revisão E2E Expirado    valor=160.00
    Set Suite Variable    ${CLIENTE_ID}    ${cid}
    Set Suite Variable    ${VEICULO_ID}    ${vid}
    Set Suite Variable    ${PRODUTO_ID}    ${pid}
    Set Suite Variable    ${SERVICO_ID}    ${sid}

uma OS está aprovada e em ManutencaoFinalizada
    ${os_id}=    Criar OS    ${CLIENTE_ID}    ${VEICULO_ID}    Pagamento expira por timeout E2E
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

o WireMock está configurado para retornar pending no polling
    Configurar MP Status Pending

a OS avança para AguardandoPagamento
    Avancar OS    ${OS_ID}
    Esperar OS Atingir Status    ${OS_ID}    AguardandoPagamento

a OS reverte automaticamente para ManutencaoFinalizada após o timeout do polling
    [Documentation]    PAGAMENTO__POLLING_INTERVAL=5s × MAX_ATTEMPTS=6 = 30s mínimo de polling
    ...                + processing de saga + redelivery + eventos cross-service.
    ...                Damos uma janela folgada (90s) para tolerar variações de scheduling do
    ...                DelayedMessageScheduler e do outbox processor (poll 2s).
    Wait Until Keyword Succeeds    90s    ${POLL_INTERVAL}s
    ...    OS Deve Estar Em Status    ${OS_ID}    ManutencaoFinalizada
