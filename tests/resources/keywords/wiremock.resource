*** Settings ***
Library     RequestsLibrary
Library     Collections
Variables   ../variables/env.yaml


*** Keywords ***
Resetar Cenarios WireMock
    [Documentation]    Reseta todos os cenários WireMock para o estado inicial.
    POST    ${WIREMOCK_ADMIN_URL}/scenarios/reset    expected_status=200
    Log    WireMock cenários resetados

Configurar MP Status Recusado
    [Documentation]    Ativa o cenário WireMock que retorna pagamento recusado.
    ${body}=    Create Dictionary    state=pagamento_recusado
    PUT    ${WIREMOCK_ADMIN_URL}/scenarios/pagamento-recusado/state
    ...    json=${body}    expected_status=200
    Log    WireMock configurado para retornar pagamento recusado

Configurar MP Status Aprovado
    [Documentation]    Reseta o cenário WireMock para retornar pagamento aprovado (padrão).
    ${body}=    Create Dictionary    state=Started
    PUT    ${WIREMOCK_ADMIN_URL}/scenarios/pagamento-recusado/state
    ...    json=${body}    expected_status=200
    Log    WireMock configurado para retornar pagamento aprovado

Verificar WireMock Disponivel
    ${response}=    GET    ${WIREMOCK_ADMIN_URL}/health    expected_status=200
    Log    WireMock disponível: ${response.json()}
