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
    [Documentation]    Reseta o cenário para o estado Started (default), fazendo a próxima consulta
    ...                cair no mapping de aprovado (sem requiredScenarioState).
    ...                Usa o endpoint global porque WireMock 3.x rejeita PUT state=Started com 422
    ...                quando o scenario só declara um possibleState, e não há reset por nome.
    POST    ${WIREMOCK_ADMIN_URL}/scenarios/reset    expected_status=200
    Log    WireMock cenários resetados para Started (aprovado é o padrão)

Verificar WireMock Disponivel
    ${response}=    GET    ${WIREMOCK_ADMIN_URL}/health    expected_status=200
    Log    WireMock disponível: ${response.json()}
