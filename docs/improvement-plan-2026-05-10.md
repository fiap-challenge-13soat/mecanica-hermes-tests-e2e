# Plano de melhorias — 2026-05-10

Oportunidades identificadas durante o ciclo de **bump do SDK para v1.1.0 + integração
cross-service de cancelamento + validação E2E completa**. Não foram aplicadas; ficam
como itens para o time priorizar.

## Severidade: ALTA

### 1. Vulnerabilidades transitivas não tratadas em OS API e Cadastros

OS API e Cadastros restauram com warnings:

- `SharpCompress 0.30.1` — **moderate** (GHSA-6c8g-7p36-r338) — transitiva via Testcontainers
- `Snappier 1.0.0` — **high** (GHSA-pggp-6c3x-2xmx) — transitiva via MongoDB.Driver

Pagamentos já trata ambas com pin de versão:

```xml
<!-- Override transitive: MongoDB.Driver 3.7.1 puxa Snappier 1.0.0 vulnerável -->
<PackageVersion Include="Snappier" Version="1.3.1" />
<!-- Override transitive: Testcontainers puxa SharpCompress 0.30.1 vulnerável -->
<PackageVersion Include="SharpCompress" Version="0.48.0" />
```

Sugestão: replicar essas duas linhas em `Directory.Packages.props` de OS API e Cadastros.
Risco: zero (são overrides de transitivas, não mudam nada do código de aplicação).

## Severidade: MÉDIA

### 2. NuGet sem `packageSourceMapping`

Todas as 3 APIs emitem `NU1507` (warning) por terem `nuget.org` + `github-mechermes`
sem mapping explícito. Cada restore consulta os 2 feeds para todo pacote, atrasando.
Solução padrão é adicionar em cada `nuget.config`:

```xml
<packageSourceMapping>
  <packageSource key="github-mechermes">
    <package pattern="Mecanica.Hermes.*" />
  </packageSource>
  <packageSource key="nuget.org">
    <package pattern="*" />
  </packageSource>
</packageSourceMapping>
```

Benefícios: silencia o warning, restore mais rápido, defesa contra dependency confusion.

### 3. CLAUDE.md do E2E tem nomes de repos desatualizados

O `CLAUDE.md` deste repositório lista os irmãos como:

| Citado em CLAUDE.md | Real |
|---|---|
| `mecanica-hermes-cadastros` | `mecanica-hermes-api-cadastros` |
| `mecanica-hermes-shared-sdk` | `mecanica-hermes-api-sdk` |

Causa retrabalho a cada sessão (descobri isso só rodando `ls`). Atualizar a tabela
"Ecosystem Context" para refletir os diretórios reais.

### 4. Branch `feature/docker-compose-e2e` carregou mais de uma intenção

Nas 3 APIs, essa branch acumulou: bug fixes E2E + saga timeout config (OS) + SDK bump
+ event publisher (OS) / consumer (Pagamentos). 4 concerns numa branch só. Em revisão
de código, é discutível se é broad demais. Sugestão a partir de agora:

- Branch por concern (`fix/<bug>`, `feat/<capability>`, `chore/<infra>`)
- Não reusar uma branch antiga "que ainda está aberta" para fazer novo escopo

## Severidade: BAIXA (Não Executar)

### 5. Versionamento monolítico do SDK

> Nota do Desenvolvedor: Não Executar!
> 
> Justificativa: Os pacotes são pequenos e é mais fácil para um humano entender potenciais problemas de dessincronização de pacotes.

`v1.1.0` versionou os 6 pacotes do SDK juntos (Build.props com `<Version>` único)
mesmo que só `Contracts` tenha mudado nesta release. Resultado:

- 5 pacotes (`Shared.Core`, `Shared.Application`, `Shared.AspNetCore`,
  `Shared.Observability`, `Cli`) tiveram a versão bumped sem mudança real
- Consumidores precisam atualizar todos juntos para evitar drift
- Changelogs poluídos

Alternativas:

1. **Versionamento independente** (recomendado para SDKs maduros): `Mecanica.Hermes.Contracts` em 1.1.0, demais permanecem em 1.0.0. Requer reorganizar `Directory.Build.props` para ler versão por projeto.
2. **Manter monolítico mas documentar** — mais simples; ok enquanto o SDK ainda tem poucos consumidores.

### 6. NU1510 em `Mecanica.Hermes.Infrastructure.Tests` (OS API)

```
warning NU1510: PackageReference Microsoft.Extensions.Logging.Abstractions
will not be pruned. Consider removing this package from your dependencies.
```

Trivial: remover a referência do `csproj` de testes — o pacote vem transitivamente.

### 7. Falta de teste arquitetural para campo Mongo em camelCase

A suíte E2E 08 falhou inicialmente porque o helper Robot fazia query com
`OrdemDeServicoId` (PascalCase) enquanto o Mongo persiste em `ordemDeServicoId`
(camelCase, configurado pela convenção do `MongoDB.Driver` na Pagamentos).

Risco: se um novo campo for introduzido na Pagamentos com convenção diferente, ou se
alguém escrever uma query externa, vai dar bug silencioso (consulta retornando null
sem erro).

Sugestão: ArchitectureTest ou contract test que serializa um `Pagamento` para Bson e
afirma que todas as keys começam com letra minúscula.

### 8. Suíte E2E pode rodar contra consumer ainda inexistente — bug do helper passa

O `Pagamento Da OS Deve Estar Recusado` tinha o bug do PascalCase, mas como o consumer
não existia até hoje, o teste 08 nunca passou — então o bug nunca foi exposto. Quando
o consumer foi adicionado, **bateu primeiro no bug do helper, não no consumer**.

Padrão para evitar: ao escrever um teste que depende de feature futura, rodá-lo contra
um stub que retorne valor esperado (ex: inserir manualmente no Mongo antes do teste).
Se o teste passar com o stub, o helper está correto e o teste isola realmente o
comportamento da feature.

### 9. Auto-descoberta vs registro explícito de consumers MassTransit

`OrdemDeServicoCanceladaConsumer` foi adicionado em Pagamentos sem alteração explícita
em nenhum DI. A suíte E2E 08 confirmou que o consumer roda — então a infraestrutura
faz auto-discovery (provavelmente via `AddConsumers(typeof(SomeAssemblyMarker).Assembly)`).

Não é bug, mas merece ser **documentado** em `docs/messaging.md` da Pagamentos:
"adicionar nova classe `IConsumer<>` no projeto Application é suficiente para
registrá-la — não é necessário tocar em DI".

## Não-melhorias (apenas observações)

- **READMEs das 3 APIs** ganharam seção "Stack completa via Docker Compose" apontando
  para este repositório E2E como local canônico do compose. Mudanças ficaram
  uncommitted no working tree de cada repo — operador deve revisar e fazer PR
  manualmente (não criei PR pois user só autorizou PR para SDK).
- **Suíte 08** foi corrigida e commitada nesta branch (`feature/e2e-suite`).
- **Tags Docker** das imagens `mechermes/*:latest` foram republicadas com sucesso após
  os merges; suíte completa rodou **8/8 PASS** contra elas.
