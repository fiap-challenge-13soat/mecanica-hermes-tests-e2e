*** Settings ***
Library     RequestsLibrary
Library     Collections
Variables   ../variables/env.yaml


*** Keywords ***
Buscar Pagamento
    [Arguments]    ${pagamento_id}
    ${response}=    GET    ${PAGAMENTOS_URL}/${pagamento_id}    expected_status=200
    RETURN    ${response.json()}

Buscar Pagamento Por Ordem De Servico
    [Documentation]    Busca pagamento pelo OrdemDeServicoId via listagem (se disponível).
    ...    Retorna None se não encontrado.
    [Arguments]    ${os_id}
    ${response}=    GET    ${PAGAMENTOS_URL}    expected_status=any
    IF    ${response.status_code} == 200
        ${pagamentos}=    Get From Dictionary    ${response.json()}    items
        FOR    ${pag}    IN    @{pagamentos}
            ${ordem_id}=    Get From Dictionary    ${pag}    ordemDeServicoId
            IF    '${ordem_id}' == '${os_id}'
                RETURN    ${pag}
            END
        END
    END
    RETURN    ${None}
