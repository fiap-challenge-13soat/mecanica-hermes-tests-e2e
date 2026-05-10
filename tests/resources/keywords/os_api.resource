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
    [Documentation]    Adiciona um produto à OS e aguarda a SAGA refletir a inclusão antes de retornar.
    ...    Necessário porque a SAGA de OS é serializada por OrdemDeServicoId e descarta (Ignore)
    ...    novas requisições enquanto está em Processing — sem este wait, operações subsequentes
    ...    enviadas em sucessão rápida (ex.: outro Adicionar ou Avancar) seriam silenciosamente
    ...    descartadas pela SAGA.
    [Arguments]    ${os_id}    ${produto_id}    ${valor}=150.00    ${quantidade}=1
    ${body}=    Create Dictionary
    ...    produtoId=${produto_id}
    ...    valorUnitario=${valor}
    ...    quantidade=${quantidade}
    POST    ${OS_URL}/${os_id}/produtos    json=${body}    expected_status=202
    Wait Until Keyword Succeeds    30s    1s    Produto Deve Estar Em OS    ${os_id}    ${produto_id}

Produto Deve Estar Em OS
    [Arguments]    ${os_id}    ${produto_id}
    ${os}=        Buscar OS    ${os_id}
    ${produtos}=  Get From Dictionary    ${os}    produtos
    ${ids}=       Evaluate    [p['produtoId'] for p in $produtos]
    Should Contain    ${ids}    ${produto_id}    msg=Produto ${produto_id} ainda não consta na OS ${os_id}

Adicionar Servico A OS
    [Documentation]    Adiciona um serviço à OS e aguarda a SAGA refletir a inclusão. Mesmo motivo
    ...    de `Adicionar Produto A OS`.
    [Arguments]    ${os_id}    ${servico_id}    ${valor}=200.00
    ${body}=    Create Dictionary
    ...    servicoId=${servico_id}
    ...    valor=${valor}
    POST    ${OS_URL}/${os_id}/servicos    json=${body}    expected_status=202
    Wait Until Keyword Succeeds    30s    1s    Servico Deve Estar Em OS    ${os_id}    ${servico_id}

Servico Deve Estar Em OS
    [Arguments]    ${os_id}    ${servico_id}
    ${os}=        Buscar OS    ${os_id}
    ${servicos}=  Get From Dictionary    ${os}    servicos
    ${ids}=       Evaluate    [s['servicoId'] for s in $servicos]
    Should Contain    ${ids}    ${servico_id}    msg=Serviço ${servico_id} ainda não consta na OS ${os_id}

OS Deve Ser Terminal
    [Documentation]    Valida que uma OS em estado terminal não transiciona em resposta a um Avancar.
    ...                Como a API agora é assíncrona (SAGA), o endpoint sempre retorna 202 — quem
    ...                rejeita a transição é o consumer interno. Aqui guardamos o status atual,
    ...                disparamos o avanço e confirmamos que o status permanece o mesmo após
    ...                tempo suficiente para o consumer processar.
    [Arguments]    ${os_id}
    ${os_antes}=    Buscar OS    ${os_id}
    ${status_terminal}=    Get From Dictionary    ${os_antes}    statusAtual
    ${response}=    PATCH    ${OS_URL}/${os_id}/avancar    expected_status=any
    Sleep    ${POLL_INTERVAL}s
    Wait Until Keyword Succeeds    10s    1s
    ...    OS Deve Estar Em Status    ${os_id}    ${status_terminal}
