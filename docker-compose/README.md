# Mecânica Hermes — Docker Compose

Este diretório contém a configuração Docker Compose para execução local da aplicação Mecânica Hermes com todas as suas dependências.

![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)

## Pré-requisitos

- Docker 20.10+
- Docker Compose 2.0+

## Configuração

### 1. Copiar arquivo de variáveis

```bash
cp .env.example .env
```

### 2. Editar configurações

Edite o arquivo `.env` com suas configurações (opcional, os valores padrão já funcionam):

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=teste123A!
POSTGRES_DB=OficinaDB
ASPNETCORE_ENVIRONMENT=Production
JWT_KEY=sua-chave-jwt-aqui
JWT_ISSUER=MecanicaHermes
```

## Executar a aplicação

### Opção 1: Docker Compose (recomendado)

```bash
# Iniciar os serviços
docker-compose up -d

# Ver logs
docker-compose logs -f

# Ver logs apenas da aplicação
docker-compose logs -f app

# Parar os serviços
docker-compose down

# Parar e remover volumes (limpa o banco de dados)
docker-compose down -v
```

### Opção 2: Apenas PostgreSQL

Se você quiser rodar apenas o PostgreSQL e executar a aplicação localmente:

```bash
docker-compose up -d postgres
```

## Verificar se está funcionando

- **API**: <http://localhost:8080>
- **Health Check**: <http://localhost:8080/health>
- **OpenAPI** (apenas em Development): <http://localhost:8080/scalar/v1>

## Conexão ao banco de dados

- **Host**: localhost
- **Porta**: 5432
- **Database**: OficinaDB
- **User**: postgres (ou conforme configurado no .env)
- **Password**: teste123A! (ou conforme configurado no .env)

## Estrutura

```text
docker-compose/
├── docker-compose.yaml   # Configuração do Docker Compose
└── .env.example          # Exemplo de variáveis de ambiente

../
├── Dockerfile            # Dockerfile multi-stage para build da aplicação
└── .dockerignore        # Arquivos ignorados no build do Docker
```

## Comandos úteis

```bash
# Rebuild da aplicação
docker-compose build app

# Rebuild sem cache
docker-compose build --no-cache app

# Ver status dos containers
docker-compose ps

# Executar comando no container da aplicação
docker-compose exec app bash

# Ver logs de um serviço específico
docker-compose logs -f postgres
docker-compose logs -f app

# Reiniciar apenas a aplicação
docker-compose restart app

# Remover tudo (containers, volumes, networks)
docker-compose down -v --remove-orphans
```

## Troubleshooting

### A aplicação não inicia

1. Verifique os logs: `docker-compose logs -f app`
2. Verifique se o PostgreSQL está saudável: `docker-compose ps`
3. Verifique a conexão: `docker-compose exec app curl -f http://localhost:8080/health`

### Banco de dados não conecta

1. Verifique se o PostgreSQL está rodando: `docker-compose ps postgres`
2. Verifique os logs do PostgreSQL: `docker-compose logs -f postgres`
3. Teste a conexão: `docker-compose exec postgres pg_isready -U postgres`

### Porta já está em uso

Se a porta 8080 ou 5432 já estiver em uso, edite o docker-compose.yaml:

```yaml
ports:
  - "8081:8080"  # Mudar porta externa para 8081
```

## Segurança

**IMPORTANTE**:

- Não use as senhas padrão em produção!
- Altere a chave JWT para um valor seguro e único
- Use secrets do Docker ou variáveis de ambiente seguras em produção
- Não commite o arquivo `.env` no repositório

## Notas

- As migrations são aplicadas automaticamente na inicialização da aplicação
- O banco de dados persiste em um volume Docker (`postgres_data`)
- A aplicação aguarda o PostgreSQL estar saudável antes de iniciar
- Logs são exibidos no formato JSON em produção
- Rodar simultaneamente o app no Docker Compose e na sua IDE irá gerar conflitos nas migrations do banco de dados.
