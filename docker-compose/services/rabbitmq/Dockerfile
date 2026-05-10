# Imagem custom do RabbitMQ com o plugin community `rabbitmq_delayed_message_exchange`
# pre-instalado e habilitado.
#
# Necessario porque o OS API usa MassTransit `UseDelayedMessageScheduler()` para o
# timeout sentinel da SAGA de OrdemDeServico, que publica via exchange tipo
# `x-delayed-message`. A imagem oficial do RabbitMQ nao traz esse plugin.
#
# Versao do RabbitMQ pareada com a do plugin (vendor exige range estrito):
# plugin v4.2.x suporta apenas RabbitMQ 4.2.x, plugin v4.1.x apenas 4.1.x, etc.
#
# Plugin oficial mantido pelo time RabbitMQ:
# https://github.com/rabbitmq/rabbitmq-delayed-message-exchange
FROM rabbitmq:4.1-management

ARG PLUGIN_VERSION=4.1.0
# SHA256 do asset oficial do release v4.1.0. Atualizar ao bumpar PLUGIN_VERSION.
# Validado contra: https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v4.1.0/rabbitmq_delayed_message_exchange-4.1.0.ez
ARG PLUGIN_SHA256=567f876378e70af9d949de4066bbb2fc30162b46bcbc9efe2430076b172e4a87

# Download via ADD (a imagem base não tem curl/wget). A verificação de integridade
# é feita logo em seguida via `sha256sum -c` — qualquer mismatch aborta o build.
# Sem esse check o build poderia ingerir um asset adulterado em caso de
# comprometimento da release ou MITM.
ADD --chown=rabbitmq:rabbitmq --chmod=644 \
    https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v${PLUGIN_VERSION}/rabbitmq_delayed_message_exchange-${PLUGIN_VERSION}.ez \
    /opt/rabbitmq/plugins/

RUN set -eux; \
    cd /opt/rabbitmq/plugins; \
    echo "${PLUGIN_SHA256}  rabbitmq_delayed_message_exchange-${PLUGIN_VERSION}.ez" \
        | sha256sum -c -; \
    rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange
