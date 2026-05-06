*** Settings ***
Library     RequestsLibrary
Library     Collections
Library     DateTime
Library     String
Library     OperatingSystem
Variables   ../variables/env.yaml


*** Keywords ***
Esperar OS Atingir Status
    [Documentation]    Faz polling no endpoint de OS até o statusAtual coincidir com o esperado.
    [Arguments]    ${os_id}    ${status_esperado}
    Wait Until Keyword Succeeds    ${ASYNC_TIMEOUT}s    ${POLL_INTERVAL}s
    ...    OS Deve Estar Em Status    ${os_id}    ${status_esperado}

OS Deve Estar Em Status
    [Arguments]    ${os_id}    ${status_esperado}
    ${response}=    GET    ${OS_URL}/${os_id}    expected_status=200
    ${status}=      Get From Dictionary    ${response.json()}    statusAtual
    Should Be Equal As Strings    ${status}    ${status_esperado}
    ...    msg=OS ${os_id} está em '${status}', esperado '${status_esperado}'

Esperar Pagamento Atingir Status
    [Documentation]    Faz polling no endpoint de Pagamento até o statusAtual coincidir.
    [Arguments]    ${pagamento_id}    ${status_esperado}
    Wait Until Keyword Succeeds    ${ASYNC_TIMEOUT}s    ${POLL_INTERVAL}s
    ...    Pagamento Deve Estar Em Status    ${pagamento_id}    ${status_esperado}

Pagamento Deve Estar Em Status
    [Arguments]    ${pagamento_id}    ${status_esperado}
    ${response}=    GET    ${PAGAMENTOS_URL}/${pagamento_id}    expected_status=200
    ${status}=      Get From Dictionary    ${response.json()}    statusAtual
    Should Be Equal As Strings    ${status}    ${status_esperado}
    ...    msg=Pagamento ${pagamento_id} está em '${status}', esperado '${status_esperado}'

Calcular HMAC SHA256
    [Documentation]    Calcula token HMAC-SHA256 para o webhook de aprovação/rejeição de orçamento.
    ...    Payload: "{os_id}:{acao}:{ts}" onde ts é Unix timestamp em segundos.
    [Arguments]    ${os_id}    ${acao}    ${ts}
    ${payload}=    Set Variable    ${os_id}:${acao}:${ts}
    ${token}=      Evaluate
    ...    __import__('hmac').new(
    ...        b'${WEBHOOK_SIGNING_SECRET}',
    ...        '${payload}'.encode(),
    ...        __import__('hashlib').sha256
    ...    ).hexdigest()
    RETURN    ${token}

Timestamp Unix Atual
    ${ts}=    Evaluate    int(__import__('time').time())
    RETURN    ${ts}
