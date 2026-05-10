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
    ...    Payload: "{os_id}|{acao}|{ts}" — formato espelhando HmacWebhookTokenSigner do Cadastros.
    [Arguments]    ${os_id}    ${acao}    ${ts}
    ${payload}=    Set Variable    ${os_id}|${acao}|${ts}
    ${token}=      Evaluate    __import__('hmac').new(b'${WEBHOOK_SIGNING_SECRET}', '${payload}'.encode(), __import__('hashlib').sha256).hexdigest()
    RETURN    ${token}

Timestamp Unix Atual
    ${ts}=    Evaluate    int(__import__('time').time())
    RETURN    ${ts}

Gerar CPF Valido
    [Documentation]    Gera um CPF aleatório com dígitos verificadores válidos.
    ...                Necessário porque a API de Cadastros valida o CPF (algoritmo módulo 11).
    ${base}=     Evaluate    [__import__('random').randint(0, 9) for _ in range(9)]
    ${s1}=       Evaluate    sum((10 - i) * d for i, d in enumerate($base))
    ${d1_raw}=   Evaluate    ($s1 * 10) % 11
    ${d1}=       Evaluate    0 if $d1_raw == 10 else $d1_raw
    ${nine}=     Evaluate    $base + [$d1]
    ${s2}=       Evaluate    sum((11 - i) * d for i, d in enumerate($nine))
    ${d2_raw}=   Evaluate    ($s2 * 10) % 11
    ${d2}=       Evaluate    0 if $d2_raw == 10 else $d2_raw
    ${digits}=   Evaluate    $nine + [$d2]
    ${cpf}=      Evaluate    ''.join(str(d) for d in $digits)
    RETURN    ${cpf}
