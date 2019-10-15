{
  all(params):: [
    $.parts(params.namespace).fluentdservice(),
    $.parts(params.namespace).fluentdLoggerConfigmap(),
    $.parts(params.namespace).fluentdMetricCollectorConfigmap(),
  ],

  parts(namespace):: {
    fluentdservice():: {
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": {
            "annotations": {
                "prometheus.io/port": "24231",
                "prometheus.io/scrape": "true"
            },
            "labels": {
                "app": "dkube-log-processor"
            },
            "name": "dkube-log-processor",
            "namespace": "dkube"
        },
        "spec": {
            "ports": [
                {
                    "name": "dkube-log-metrics",
                    "port": 24231,
                    "protocol": "TCP",
                    "targetPort": 24231
                }
            ],
            "selector": {
                "k8s-app": "dkube-metric-collector"
            },
            "type": "ClusterIP"
        }
    },
    fluentdLoggerConfigmap():: {
        "apiVersion": "v1",
        "data": {
            "fluent.conf": "\u003csource\u003e\n  @type tail\n  path /var/log/containers/*.log\n  pos_file /var/log/fluentd-containers-jobs.log.pos\n  time_key time\n  time_format %Y-%m-%dT%H:%M:%S\n  tag kubernetes_jobs.*\n  @label @JOBS\n  format json\n  read_from_head true\n\u003c/source\u003e\n\n\u003csource\u003e\n  @type tail\n  path /var/log/containers/*.log\n  pos_file /var/log/fluentd-containers-pl.log.pos\n  time_key time\n  time_format %Y-%m-%dT%H:%M:%S\n  tag kubernetes_pl.*\n  @label @PIPELINE\n  format json\n  read_from_head true\n\u003c/source\u003e\n\n\u003csource\u003e\n  @type tail\n  path /var/log/containers/*_dkube-d3api-*.log\n  pos_file /var/log/fluentd-containers-api.log.pos\n  time_key time\n  time_format %Y-%m-%dT%H:%M:%S\n  tag kubernetes_apis.*\n  @label @MASTER\n  format json\n  read_from_head true\n\u003c/source\u003e\n\n\n\u003clabel @JOBS\u003e\n    #adding kubernetes metadata for accessing labels\n     \u003cfilter kubernetes_jobs.**\u003e\n        @type kubernetes_metadata\n    \u003c/filter\u003e\n\n     #collect logs of pod which has label(logger: dkube)\n    \u003cfilter kubernetes_jobs.**\u003e\n        @type grep\n        \u003cregexp\u003e\n            key $.kubernetes.labels.logger\n            pattern dkube\n        \u003c/regexp\u003e\n    \u003c/filter\u003e\n\n    # framing new records\n    \u003cfilter kubernetes_jobs.**\u003e\n       @type record_modifier\n       enable_ruby\n       \u003crecord\u003e\n           jobname ${record.dig(\"kubernetes\", \"labels\", \"jobname\")}\n           username ${record.dig(\"kubernetes\", \"labels\", \"username\")}\n           container ${record.dig(\"kubernetes\", \"container_name\")}\n           message ${record.dig(\"kubernetes\", \"labels\", \"tf-replica-type\")}-${record.dig(\"kubernetes\", \"labels\", \"tf-replica-index\")}:  ${record.dig(\"log\")}\n       \u003c/record\u003e\n       remove_keys log, stream, docker,kubernetes\n    \u003c/filter\u003e\n\n    #ouput to s3\n    \u003cmatch kubernetes_jobs.**\u003e\n      @type copy\n      \u003cstore\u003e\n        @type http\n        endpoint http://dkube-splunk.dkube:8088/services/collector/raw\n        open_timeout 2\n        \u003cauth\u003e\n          method basic\n          username admin\n          password $HECTOKEN\n        \u003c/auth\u003e\n        \u003cformat\u003e\n          @type single_value\n          message_key message\n          add_newline false\n        \u003c/format\u003e\n        \u003cbuffer username,time, jobname, container\u003e\n          @type file\n          path /var/log/td-agent/s3/${username}/${jobname}/${container}\n          timekey 1m            # Flush the accumulated chunks every hour\n          timekey_wait 1m        # Wait for 60 seconds before flushing\n          timekey_use_utc true   # Use this option if you prefer UTC timestamps\n          chunk_limit_size 256m  # The maximum size of each chunk\n        \u003c/buffer\u003e\n      \u003c/store\u003e\n      \u003cstore\u003e\n        @type s3\n        aws_key_id dkube\n        aws_sec_key l06dands19s\n        s3_endpoint http://dkube-storage.dkube:9000/\n        s3_bucket dkube\n        path system/logs/jobs/${username}/${jobname}/${container}\n        s3_object_key_format %{path}/job-log-%{index}.%{file_extension}\n        store_as text\n        force_path_style true\n        \u003cformat\u003e\n          @type single_value\n          message_key message\n          add_newline false\n        \u003c/format\u003e\n        \u003cbuffer username,time, jobname, container\u003e\n          @type file\n          path /var/log/td-agent/s3/${username}/${jobname}/${container}\n          timekey 1m            # Flush the accumulated chunks every hour\n          timekey_wait 1m        # Wait for 60 seconds before flushing\n          timekey_use_utc true   # Use this option if you prefer UTC timestamps\n          chunk_limit_size 256m  # The maximum size of each chunk\n        \u003c/buffer\u003e\n      \u003c/store\u003e\n    \u003c/match\u003e\n\u003c/label\u003e\n\n\n\u003clabel @PIPELINE\u003e\n    #adding kubernetes metadata for accessing labels\n     \u003cfilter kubernetes_pl.**\u003e\n        @type kubernetes_metadata\n    \u003c/filter\u003e\n\n     #collect logs of pod which has label(logger: dkube)\n    \u003cfilter kubernetes_pl.**\u003e\n        @type grep\n        \u003cregexp\u003e\n            key $.kubernetes.labels.executor\n            pattern pipeline\n        \u003c/regexp\u003e\n    \u003c/filter\u003e\n\n    # framing new records\n    \u003cfilter kubernetes_pl.**\u003e\n       @type record_modifier\n       enable_ruby\n       \u003crecord\u003e\n           #in pipeline jobname , podname, jobuuid all will be same\n           podname ${record.dig(\"kubernetes\", \"labels\", \"runid\")}\n           wfname ${record.dig(\"kubernetes\", \"labels\", \"workflows_argoproj_io/workflow\")}\n           container ${record.dig(\"kubernetes\", \"container_name\")}\n           message ${record.dig(\"log\")}\n       \u003c/record\u003e\n    \u003c/filter\u003e\n\n    #ouput to s3\n    \u003cmatch kubernetes_pl.**\u003e\n      \u003cstore\u003e\n        @type http\n        endpoint http://dkube-splunk.dkube:8088/services/collector/raw\n        open_timeout 2\n        \u003cauth\u003e\n          method basic\n          username admin\n          password $HECTOKEN\n        \u003c/auth\u003e\n        \u003cformat\u003e\n          @type single_value\n          message_key message\n          add_newline false\n        \u003c/format\u003e\n        \u003cbuffer wfname,time, podname, container\u003e\n          @type file\n          path /var/log/td-agent/s3/${wfname}/${podname}/${container}\n          timekey 1m            # Flush the accumulated chunks every hour\n          timekey_wait 1m        # Wait for 60 seconds before flushing\n          timekey_use_utc true   # Use this option if you prefer UTC timestamps\n          chunk_limit_size 256m  # The maximum size of each chunk\n        \u003c/buffer\u003e\n      \u003c/store\u003e\n      \u003cstore\u003e\n        @type s3\n        aws_key_id dkube\n        aws_sec_key l06dands19s\n        s3_endpoint http://dkube-storage.dkube:9000/\n        s3_bucket dkube\n        path system/logs/pllauncher/${wfname}/${podname}/${container}\n        s3_object_key_format %{path}/job-log-%{index}.%{file_extension}\n        store_as text\n        force_path_style true\n        \u003cformat\u003e\n          @type single_value\n          message_key message\n          add_newline false\n        \u003c/format\u003e\n        \u003cbuffer wfname,time, podname, container\u003e\n          @type file\n          path /var/log/td-agent/s3/${wfname}/${podname}/${container}\n          timekey 1m            # Flush the accumulated chunks every hour\n          timekey_wait 1m        # Wait for 60 seconds before flushing\n          timekey_use_utc true   # Use this option if you prefer UTC timestamps\n          chunk_limit_size 256m  # The maximum size of each chunk\n        \u003c/buffer\u003e\n      \u003c/store\u003e\n    \u003c/match\u003e\n\u003c/label\u003e\n\n\u003clabel @MASTER\u003e\n    #adding kubernetes metadata for accessing labels\n     \u003cfilter kubernetes_apis.**\u003e\n        @type kubernetes_metadata\n    \u003c/filter\u003e\n\n     #collect logs of pod which has label(logger: dkube)\n    \u003cfilter kubernetes_apis.**\u003e\n        @type grep\n        \u003cregexp\u003e\n            key $.kubernetes.labels.app\n            pattern dkube-controller-master\n        \u003c/regexp\u003e\n    \u003c/filter\u003e\n\n    #ouput to s3\n    \u003cmatch kubernetes_apis.**\u003e\n      \u003cstore\u003e\n        @type http\n        endpoint http://dkube-splunk.dkube:8088/services/collector/raw\n        open_timeout 2\n        \u003cauth\u003e\n          method basic\n          username admin\n          password $HECTOKEN\n        \u003c/auth\u003e\n        \u003cformat\u003e\n          @type single_value\n          message_key log\n          add_newline false\n        \u003c/format\u003e\n        \u003cbuffer time\u003e\n          @type file\n          path /var/log/td-agent/master\n          timekey 15m            # Flush the accumulated chunks every hour\n          timekey_wait 1m        # Wait for 60 seconds before flushing\n          timekey_use_utc true   # Use this option if you prefer UTC timestamps\n          chunk_limit_size 256m  # The maximum size of each chunk\n        \u003c/buffer\u003e\n      \u003c/store\u003e\n      \u003cstore\u003e\n        @type s3\n        aws_key_id dkube\n        aws_sec_key l06dands19s\n        s3_endpoint http://dkube-storage.dkube:9000/\n        s3_bucket dkube\n        path system/logs/system\n        s3_object_key_format %{path}/log-%{index}.%{file_extension}\n        store_as text\n        force_path_style true\n        \u003cformat\u003e\n          @type single_value\n          message_key log\n          add_newline false\n        \u003c/format\u003e\n        \u003cbuffer time\u003e\n          @type file\n          path /var/log/td-agent/master\n          timekey 15m            # Flush the accumulated chunks every hour\n          timekey_wait 1m        # Wait for 60 seconds before flushing\n          timekey_use_utc true   # Use this option if you prefer UTC timestamps\n          chunk_limit_size 256m  # The maximum size of each chunk\n        \u003c/buffer\u003e\n      \u003c/store\u003e\n    \u003c/match\u003e\n\u003c/label\u003e\n"
        },
        "kind": "ConfigMap",
        "metadata": {
            "name": "dkube-log-collector",
            "namespace": "dkube"
        }
    },
    fluentdMetricCollectorConfigmap():: {
        "apiVersion": "v1",
        "data": {
            "accuracy.conf": "\u003cfilter kubernetes_accuracy.**\u003e\n    @type kubernetes_metadata\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_accuracy.**\u003e\n    @type grep\n    \u003cregexp\u003e\n        key $.kubernetes.labels.logger\n        pattern dkube\n    \u003c/regexp\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_accuracy.**\u003e\n    @type grep\n    \u003cregexp\u003e\n        key log\n        pattern /accuracy/\n    \u003c/regexp\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_accuracy.**\u003e\n  @type parser\n  key_name $.log\n  reserve_data true\n  remove_key_name_field true\n  suppress_parse_error_log true\n  \u003cparse\u003e\n    @type regexp\n    expression /^(.*):(.*):((.*)])?((.*):)?(?\u003cmessage\u003e(.*))$/\n  \u003c/parse\u003e\n\u003c/filter\u003e\n\n \u003cfilter kubernetes_accuracy.**\u003e\n   @type record_modifier\n   enable_ruby\n   \u003crecord\u003e\n       escaped_tag ${record[\"message\"].gsub(' ', '')}\n   \u003c/record\u003e\n \u003c/filter\u003e\n\n\u003cfilter kubernetes_accuracy.**\u003e\n    @type grep\n    \u003cregexp\u003e\n        key escaped_tag\n        pattern /accuracy=/\n    \u003c/regexp\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_accuracy.**\u003e\n  @type parser\n  key_name $.escaped_tag\n  reserve_data true\n  remove_key_name_field true\n  suppress_parse_error_log true\n  \u003cparse\u003e\n    @type ltsv\n    delimiter_pattern /,/\n    label_delimiter  =\n  \u003c/parse\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_accuracy.**\u003e\n   @type record_modifier\n   enable_ruby\n   \u003crecord\u003e\n       jobname ${record.dig(\"kubernetes\", \"labels\", \"jobname\")}\n       username ${record.dig(\"kubernetes\", \"labels\", \"username\")}\n       jobid ${record.dig(\"kubernetes\", \"labels\", \"jobid\")}\n       mode ${record.dig(\"mode\").to_s}\n       step ${record.dig(\"step\").to_i}\n       epoch ${record.dig(\"epoch\").to_i}\n       accuracy ${record.dig(\"accuracy\").to_f} \n   \u003c/record\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_accuracy.**\u003e\n  @type prometheus\n  \u003cmetric\u003e\n    name accuracy\n    type gauge\n    desc accuracy metric\n    key $.accuracy\n    \u003clabels\u003e\n      jobname ${jobname}\n      username ${username}\n      jobid ${jobid}\n      step ${step}\n      mode ${mode}\n      epoch ${epoch}\n    \u003c/labels\u003e\n  \u003c/metric\u003e\n\u003c/filter\u003e\n\n\u003cmatch kubernetes_accuracy.**\u003e\n    @type relabel\n    @label @PROMETHEUS\n\u003c/match\u003e\n",
            "fluent.conf": "\u003csource\u003e\n  @type prometheus\n\u003c/source\u003e\n\n\u003csource\u003e\n  @type monitor_agent\n\u003c/source\u003e\n\n\u003csource\u003e\n  @type forward\n\u003c/source\u003e\n\n# input plugin that collects metrics from MonitorAgent\n\u003csource\u003e\n  @type prometheus_monitor\n  \u003clabels\u003e\n    host ${hostname}\n  \u003c/labels\u003e\n\u003c/source\u003e\n\n# input plugin that collects metrics for output plugin\n\u003csource\u003e\n  @type prometheus_output_monitor\n  \u003clabels\u003e\n    host ${hostname}\n  \u003c/labels\u003e\n\u003c/source\u003e\n\n# input plugin that collects metrics for in_tail plugin\n\u003csource\u003e\n  @type prometheus_tail_monitor\n  \u003clabels\u003e\n    host ${hostname}\n  \u003c/labels\u003e\n\u003c/source\u003e\n\n\u003csource\u003e\n  @type tail\n  path /var/log/containers/*_tensorflow-*.log\n  pos_file /var/log/fluentd-containers-accuracy.log.pos\n  time_format %Y-%m-%dT%H:%M:%S\n  tag kubernetes_accuracy.*\n  @label @ACCURACY\n  format json\n  read_from_head true\n\u003c/source\u003e\n\n\u003csource\u003e\n  @type tail\n  path /var/log/containers/*_tensorflow-*.log\n  pos_file /var/log/fluentd-containers-loss.log.pos\n  time_format %Y-%m-%dT%H:%M:%S\n  tag kubernetes_loss.*\n  @label @LOSS\n  format json\n  read_from_head true\n\u003c/source\u003e\n\n\u003csource\u003e\n  @type tail\n  path /var/log/containers/*_tensorflow-*.log\n  pos_file /var/log/fluentd-containers-step.log.pos\n  time_format %Y-%m-%dT%H:%M:%S\n  tag kubernetes_step.*\n  @label @STEP\n  format json\n  read_from_head true\n\u003c/source\u003e\n\n\u003clabel @STEP\u003e\n    @include step.conf\n\u003c/label\u003e\n\n\u003clabel @ACCURACY\u003e\n    @include accuracy.conf\n\u003c/label\u003e\n\n\u003clabel @LOSS\u003e\n    @include loss.conf\n\u003c/label\u003e\n\n\u003clabel @PROMETHEUS\u003e\n    @include prometheus.conf\n\u003c/label\u003e\n",
            "loss.conf": "\u003cfilter kubernetes_loss.**\u003e\n     @type kubernetes_metadata\n \u003c/filter\u003e\n\n \u003cfilter kubernetes_loss.**\u003e\n     @type grep\n     \u003cregexp\u003e\n         key $.kubernetes.labels.logger\n         pattern dkube\n     \u003c/regexp\u003e\n \u003c/filter\u003e\n\n \u003cfilter kubernetes_loss.**\u003e\n     @type grep\n     \u003cregexp\u003e\n         key log\n         pattern /loss/\n     \u003c/regexp\u003e\n \u003c/filter\u003e\n\n \u003cfilter kubernetes_loss.**\u003e\n   @type parser\n   key_name $.log\n   reserve_data true\n   remove_key_name_field true\n   suppress_parse_error_log true\n   \u003cparse\u003e\n     @type regexp\n     expression /^(.*):(.*):((.*)])?((.*):)?(?\u003cmessage\u003e(.*))$/\n   \u003c/parse\u003e\n \u003c/filter\u003e\n\n  \u003cfilter kubernetes_loss.**\u003e\n    @type record_modifier\n    enable_ruby\n    \u003crecord\u003e\n        escaped_tag ${record[\"message\"].gsub(' ', '')}\n    \u003c/record\u003e\n  \u003c/filter\u003e\n\n \u003cfilter kubernetes_loss.**\u003e\n     @type grep\n     \u003cregexp\u003e\n         key escaped_tag\n         pattern /loss=/\n     \u003c/regexp\u003e\n \u003c/filter\u003e\n\n \u003cfilter kubernetes_loss.**\u003e\n   @type parser\n   key_name $.escaped_tag\n   reserve_data true\n   remove_key_name_field true\n   suppress_parse_error_log true\n   \u003cparse\u003e\n     @type ltsv\n     delimiter_pattern /,/\n     label_delimiter  =\n   \u003c/parse\u003e\n \u003c/filter\u003e\n\n \u003cfilter kubernetes_loss.**\u003e\n    @type record_modifier\n    enable_ruby\n    \u003crecord\u003e\n        jobname ${record.dig(\"kubernetes\", \"labels\", \"jobname\")}\n        username ${record.dig(\"kubernetes\", \"labels\", \"username\")}\n        jobuuid ${record.dig(\"kubernetes\", \"labels\", \"jobuuid\")}\n        jobid ${record.dig(\"kubernetes\", \"labels\", \"jobid\")}\n        step ${record.dig(\"step\").to_i}\n        loss ${record.dig(\"loss\").to_f}\n        mode ${record.dig(\"mode\").to_s}\n        epoch ${record.dig(\"epoch\").to_i} \n    \u003c/record\u003e\n \u003c/filter\u003e\n\n \u003cfilter kubernetes_loss.**\u003e\n   @type prometheus\n   \u003cmetric\u003e\n     name loss\n     type gauge\n     desc loss metric\n     key $.loss\n     \u003clabels\u003e\n       jobuuid ${jobuuid}\n       jobname ${jobname}\n       username ${username}\n       jobid ${jobid}\n       step ${step}\n       mode ${mode}\n       epoch ${epoch}\n     \u003c/labels\u003e\n   \u003c/metric\u003e\n \u003c/filter\u003e\n\n \u003cmatch kubernetes_loss.**\u003e\n     @type relabel\n     @label @PROMETHEUS\n \u003c/match\u003e\n",
            "prometheus.conf": "\u003cmatch {kubernetes_accuracy.**, kubernetes_loss.**, kubernetes_step.**}\u003e\n  @type copy\n  # for MonitorAgent sample\n  \u003cstore\u003e\n    @id test_forward\n    @type forward\n    buffer_type memory\n    flush_interval 1s\n    max_retry_wait 2s\n    send_timeout 60s\n    recover_wait 60s\n    hard_timeout 60s\n    \u003cbuffer\u003e\n      # max_retry_wait 10s\n      flush_interval 1s\n      # retry_type periodic\n      disable_retry_limit\n   \u003c/buffer\u003e\n   # retry_limit 3\n   disable_retry_limit\n   \u003cserver\u003e\n     host 0.0.0.0\n     port 24224\n   \u003c/server\u003e\n  \u003c/store\u003e\n\u003c/match\u003e\n",
            "step.conf": "\u003cfilter kubernetes_step.**\u003e\n    @type kubernetes_metadata\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_step.**\u003e\n    @type grep\n    \u003cregexp\u003e\n        key $.kubernetes.labels.logger\n        pattern dkube\n    \u003c/regexp\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_step.**\u003e\n    @type grep\n    \u003cregexp\u003e\n        key log\n        pattern /step/\n    \u003c/regexp\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_step.**\u003e\n  @type parser\n  key_name $.log\n  reserve_data true\n  remove_key_name_field true\n  suppress_parse_error_log true\n  \u003cparse\u003e\n    @type regexp\n    expression /^(.*):(.*):((.*)])?((.*):)?(?\u003cmessage\u003e(.*))$/\n  \u003c/parse\u003e\n\u003c/filter\u003e\n\n \u003cfilter kubernetes_step.**\u003e\n   @type record_modifier\n   enable_ruby\n   \u003crecord\u003e\n       escaped_tag ${record[\"message\"].gsub(' ', '')}\n   \u003c/record\u003e\n \u003c/filter\u003e\n\n\u003cfilter kubernetes_step.**\u003e\n    @type grep\n    \u003cregexp\u003e\n        key escaped_tag\n        pattern /,step=/\n    \u003c/regexp\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_step.**\u003e\n  @type parser\n  key_name $.escaped_tag\n  reserve_data true\n  remove_key_name_field true\n  suppress_parse_error_log true\n  \u003cparse\u003e\n    @type ltsv\n    delimiter_pattern /,/\n    label_delimiter  =\n  \u003c/parse\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_step.**\u003e\n   @type record_modifier\n   enable_ruby\n   \u003crecord\u003e\n       jobname ${record.dig(\"kubernetes\", \"labels\", \"jobname\")}\n       username ${record.dig(\"kubernetes\", \"labels\", \"username\")}\n       jobid ${record.dig(\"kubernetes\", \"labels\", \"jobid\")}\n       step ${record.dig(\"step\").to_i}\n       accuracy ${record.dig(\"accuracy\").to_f}\n       loss ${record.dig(\"loss\").to_f}\n       mode ${record.dig(\"mode\").to_s}\n   \u003c/record\u003e\n\u003c/filter\u003e\n\n\u003cfilter kubernetes_step.**\u003e\n  @type prometheus\n  \u003cmetric\u003e\n    name step\n    type gauge\n    desc step metric\n    key $.step\n    \u003clabels\u003e\n      jobname ${jobname}\n      username ${username}\n      jobid ${jobid}\n      accuracy ${accuracy}\n      loss ${loss}\n      mode ${mode}\n    \u003c/labels\u003e\n  \u003c/metric\u003e\n\u003c/filter\u003e\n\n\u003cmatch kubernetes_step.**\u003e\n    @type relabel\n    @label @PROMETHEUS\n\u003c/match\u003e\n"
        },
        "kind": "ConfigMap",
        "metadata": {
            "name": "dkube-metric-collector",
            "namespace": "dkube"
        }
     }
  },
}