Advanced Monitoring
###################

In addition to standard monitoring via Prometheus and Grafana, SuperSONIC
supports advanced monitoring capabilities through
`OpenTelemetry Collector <https://opentelemetry.io/docs/collector/>`_
and `Grafana Tempo <https://grafana.com/docs/tempo/latest/>`_ integration.
This enables collection and analysis of *tracing data* from both Envoy Proxy
and Triton Inference Server, allowing to study the "lifetime" of individual
requests in detail and identify performance bottlenecks.

The tracing data also allows to build a "map" of the server, showing how
requests propagate between Envoy Proxy pod(s) and Triton Inference Server pod(s),
as well as the latency at each step.



Enabling OpenTelemetry and Tempo
================================

To enable OpenTelemetry Collector and Tempo, set the following parameters
in your ``values.yaml``:

.. code-block:: yaml

    envoy:
      tracing_sampling_rate: 0.01

    opentelemetry-collector:
      enabled: true
      config:
        exporters:
          otlp:
            endpoint: http://supersonic-tempo:4317
          otlphttp:
            endpoint: http://supersonic-tempo:4318
          prometheusremotewrite:
            endpoint: http://supersonic-prometheus-server:9090/api/v1/write

    tempo:
      enabled: true
      tempo:
        metricsGenerator:
          enabled: true
          remoteWriteUrl: http://supersonic-prometheus-server:9090/api/v1/write

.. note::

    In the example above, endpoints and remote write URLs are configured to point to
    the Prometheus server and Grafana Tempo services, which will most likely
    have names like ``<release-name>-prometheus-server`` and ``<release-name>-tempo``.

The ``tracing_sampling_rate`` parameter controls how frequently requests are
traced. A value of ``0.01`` means that one in 100 requests will be traced.

Additionally, you will need to enable tracing in Triton Inference Server, which is
done by passing additional flags to ``tritonserver`` command. The following example
shows how tracing is configured for CMS SuperSONIC instance:

.. code-block:: bash

      /opt/tritonserver/bin/tritonserver \
      --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoBTag/Combined/data/models/ \
      --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoTauTag/TrainingFiles/data/DeepTauIdSONIC/ \
      --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoMET/METPUSubtraction/data/models/ \
      --trace-config mode=opentelemetry \
      --trace-config=opentelemetry,resource=pod_name=$(hostname) \
      --trace-config opentelemetry,url=supersonic-opentelemetry-collector:4318/v1/traces \
      --trace-config rate=100 \
      --trace-config level=TIMESTAMPS \
      --trace-config count=-1 \
      --allow-gpu-metrics=true \
      --log-verbose=0 \
      --strict-model-config=false \
      --exit-timeout-secs=60

.. note::

    In the example above, the url should point to the OpenTelemetry Collector service,
    which will most likely have a name ``<release-name>-opentelemetry-collector``.

For tracing in Triton, the rate is the inverse of the ``tracing_sampling_rate``
parameter in the Envoy Proxy configuration: rate=100 means 1% of requests will be traced.

.. warning::

    Triton Inference Server supports OpenTelemetry tracing only in versions 24.x or later.

Displaying Tracing Data in Grafana
===================================

If Grafana is enabled in your ``values.yaml``, you can display the tracing data
in the Grafana dashboard. In order to achieve this, Grafana needs to have a
Tempo datasource configured:

.. code-block:: yaml

    grafana:
      enabled: true
      datasources:
        datasources.yaml:
          datasources:
            - name: prometheus
              type: prometheus
              access: proxy
              isDefault: true
              url: http://supersonic-prometheus-server:9090
              jsonData:
                timeInterval: "5s"
                tlsSkipVerify: true
            - name: tempo
              type: tempo
              url: http://supersonic-tempo:3100
              access: proxy
              isDefault: false
              basicAuth: false
              jsonData:
                timeInterval: "5s"
                tlsSkipVerify: true
                serviceMap:
                  datasourceUid: "prometheus"
                nodeGraph:
                  enabled: true

If OpenTelemetry Collector and Tempo are enabled, the default Grafana dashboard
will include an interactive server map, where you can study tracing data in detail
by clicking on graph nodes.

You can also browse and display tracing data in Grafana as follows:

1. Create a new panel
2. Select "Tempo" as the data source
3. Select "Search" or "TraceQL" as the query type and switch panel to "Table view".
4. You will see clickable traces; selecting a trace opens a detailed view (see first screenshot below).
5. If you select "Service Graph" as the query type, you can also display the
   server map as a node graph (see second screenshot below), but customizing it
   requires careful configuration of OpenTelemetry Collector and Tempo.

.. image:: https://raw.githubusercontent.com/fastmachinelearning/SuperSONIC/main/docs/img/grafana_tracing_1.png
    :align: center
    :width: 80%
    :alt: Grafana Tracing 1

|

.. image:: https://raw.githubusercontent.com/fastmachinelearning/SuperSONIC/main/docs/img/grafana_tracing_2.png
    :align: center
    :width: 80%
    :alt: Grafana Tracing 2

