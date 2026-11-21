# Downstream host module: ACB out-of-band notifications. The topic lives in
# agenix; modules.acb only generates [notifications] when this path is set.
{ config, ... }:
{
  modules.acb.notifications.topicSecret = config.age.secrets."ntfy-acb-topic.env".path;
}
