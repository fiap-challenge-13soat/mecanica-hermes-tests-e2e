*** Settings ***
Library     RequestsLibrary
Library     Collections
Resource    common.resource
Variables   ../variables/env.yaml


*** Keywords ***
Criar Cliente
    [Documentation]    Cria um cliente no Cadastros. Retorna o clienteId.
    ...                Quando ${cpf} é vazio, gera um CPF válido aleatório.
    ...                O ${email} é desambiguado com timestamp+random pra evitar colisão entre runs
    ...                (Cadastros enforce email unique).
    [Arguments]    ${nome}=João Silva    ${email}=joao.e2e@mecanica.test    ${cpf}=${EMPTY}
    IF    '${cpf}' == '${EMPTY}'
        ${cpf}=    Gerar CPF Valido
    END
    ${suffix}=     Evaluate    f"{int(__import__('time').time())}{__import__('random').randint(100,999)}"
    ${user}=       Evaluate    "${email}".split("@")[0]
    ${domain}=     Evaluate    "${email}".split("@")[1]
    ${email}=      Set Variable    ${user}+${suffix}@${domain}
    ${body}=    Create Dictionary
    ...    nomeCivil=${nome}
    ...    email=${email}
    ...    identificacaoFiscal=${cpf}
    ...    telefone=11987654321
    ${response}=    POST    ${CADASTROS_URL}/clientes    json=${body}    expected_status=201
    ${id}=    Get From Dictionary    ${response.json()}    id
    Log    Cliente criado: ${id} (CPF=${cpf}, email=${email})
    RETURN    ${id}

Adicionar Veiculo
    [Documentation]    Adiciona um veículo a um cliente. Retorna o veiculoId.
    [Arguments]    ${cliente_id}    ${modelo}=Onix    ${marca}=Chevrolet    ${placa}=ABC1D23    ${ano}=2022
    ${body}=    Create Dictionary
    ...    modelo=${modelo}
    ...    marca=${marca}
    ...    placa=${placa}
    ...    ano=${ano}
    ${response}=    POST    ${CADASTROS_URL}/clientes/${cliente_id}/veiculos
    ...    json=${body}    expected_status=201
    ${id}=    Get From Dictionary    ${response.json()}    id
    Log    Veículo criado: ${id}
    RETURN    ${id}

Criar Produto
    [Documentation]    Cria um produto no catálogo. Retorna o produtoId.
    ...                Sufixo timestamp+random na descrição para evitar 409 entre runs.
    [Arguments]    ${descricao}=Filtro de Óleo E2E    ${valor}=85.00    ${quantidade}=100
    ${suffix}=    Evaluate    f"{int(__import__('time').time())}{__import__('random').randint(100,999)}"
    ${descricao}=    Set Variable    ${descricao} ${suffix}
    ${body}=    Create Dictionary
    ...    descricao=${descricao}
    ...    valor=${valor}
    ...    quantidade=${quantidade}
    ...    tipo=Peca
    ${response}=    POST    ${CADASTROS_URL}/produtos    json=${body}    expected_status=201
    ${id}=    Get From Dictionary    ${response.json()}    id
    Log    Produto criado: ${id} (descricao=${descricao})
    RETURN    ${id}

Criar Servico
    [Documentation]    Cria um serviço no catálogo. Retorna o servicoId.
    ...                Sufixo timestamp+random na descrição para evitar 409 entre runs.
    [Arguments]    ${descricao}=Troca de Óleo E2E    ${valor}=120.00
    ${suffix}=    Evaluate    f"{int(__import__('time').time())}{__import__('random').randint(100,999)}"
    ${descricao}=    Set Variable    ${descricao} ${suffix}
    ${body}=    Create Dictionary
    ...    descricao=${descricao}
    ...    valor=${valor}
    ${response}=    POST    ${CADASTROS_URL}/servicos    json=${body}    expected_status=201
    ${id}=    Get From Dictionary    ${response.json()}    id
    Log    Serviço criado: ${id} (descricao=${descricao})
    RETURN    ${id}

Simular Aprovacao Webhook
    [Documentation]    Simula o cliente clicando no link de aprovação do orçamento.
    ...    Calcula o token HMAC e chama o endpoint de webhook diretamente.
    [Arguments]    ${os_id}
    ${ts}=      Timestamp Unix Atual
    ${token}=   Calcular HMAC SHA256    ${os_id}    aprovar    ${ts}
    ${response}=    GET
    ...    ${CADASTROS_URL}/webhooks/orcamentos/${os_id}/aprovar
    ...    params=token=${token}&ts=${ts}
    ...    expected_status=200
    Log    Webhook aprovação executado para OS ${os_id}

Simular Rejeicao Webhook
    [Documentation]    Simula o cliente clicando no link de rejeição do orçamento.
    [Arguments]    ${os_id}    ${motivo}=Preço elevado
    ${ts}=      Timestamp Unix Atual
    ${token}=   Calcular HMAC SHA256    ${os_id}    rejeitar    ${ts}
    ${response}=    GET
    ...    ${CADASTROS_URL}/webhooks/orcamentos/${os_id}/rejeitar
    ...    params=token=${token}&ts=${ts}&motivo=${motivo}
    ...    expected_status=200
    Log    Webhook rejeição executado para OS ${os_id}
