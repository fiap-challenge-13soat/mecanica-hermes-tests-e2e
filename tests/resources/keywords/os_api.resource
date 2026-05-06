*** Settings ***
Library     RequestsLibrary
Library     Collections
Variables   ../variables/env.yaml


*** Keywords ***
Criar OS
    [Documentation]    Cria uma nova Ordem de Serviço. Retorna o OrdemDeServicoId gerado.
    [Arguments]    ${cliente_id}    ${veiculo_id}    ${problema}=Revisão geral E2E
    ${body}=    Create Dictionary
    ...    clienteId=${cliente_id}
    ...    veiculoId=${veiculo_id}
    ...    problemaRelatado=${problema}
    ${response}=    POST    ${OS_URL}    json=${body}    expected_status=202
    ${os_id}=    Get From Dictionary    ${response.json()}    id
    Log    OS criada: ${os_id}
    RETURN    ${os_id}

Avancar OS
    [Documentation]    Avança a OS para a próxima etapa.
    [Arguments]    ${os_id}
    PATCH    ${OS_URL}/${os_id}/avancar    expected_status=202

Reverter OS
    [Arguments]    ${os_id}
    PATCH    ${OS_URL}/${os_id}/reverter    expected_status=202

Cancelar OS
    [Arguments]    ${os_id}
    PATCH    ${OS_URL}/${os_id}/cancelar    expected_status=202

Buscar OS
    [Arguments]    ${os_id}
    ${response}=    GET    ${OS_URL}/${os_id}    expected_status=200
    RETURN    ${response.json()}

Adicionar Produto A OS
    [Documentation]    Adiciona um produto à OS com valor e quantidade informados.
    [Arguments]    ${os_id}    ${produto_id}    ${valor}=150.00    ${quantidade}=1
    ${body}=    Create Dictionary
    ...    produtoId=${produto_id}
    ...    valorVenda=${valor}
    ...    quantidade=${quantidade}
    POST    ${OS_URL}/${os_id}/produtos    json=${body}    expected_status=202

Adicionar Servico A OS
    [Documentation]    Adiciona um serviço à OS com valor informado.
    [Arguments]    ${os_id}    ${servico_id}    ${valor}=200.00
    ${body}=    Create Dictionary
    ...    servicoId=${servico_id}
    ...    valorVenda=${valor}
    POST    ${OS_URL}/${os_id}/servicos    json=${body}    expected_status=202

OS Deve Ser Terminal
    [Documentation]    Verifica que não é possível avançar uma OS em estado terminal.
    [Arguments]    ${os_id}
    ${response}=    PATCH    ${OS_URL}/${os_id}/avancar    expected_status=any
    Should Be True    ${response.status_code} >= 400
    ...    msg=OS em estado terminal deveria rejeitar avanço (código ${response.status_code})
