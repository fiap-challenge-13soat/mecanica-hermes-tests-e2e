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

ADD --chown=rabbitmq:rabbitmq --chmod=644 \
    https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v${PLUGIN_VERSION}/rabbitmq_delayed_message_exchange-${PLUGIN_VERSION}.ez \
    /opt/rabbitmq/plugins/

RUN rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange
