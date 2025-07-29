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

    tracing_sampling_rate: 0.01

    opentelemetry-collector:
      enabled: true

    tempo:
      enabled: true

The ``tracing_sampling_rate`` parameter controls how frequently requests are
traced. A value of ``0.01`` means that one in 100 requests will be traced.

.. warning::

    Triton Inference Server supports OpenTelemetry tracing only in versions 24.x or later.

Displaying Tracing Data in Grafana
===================================

If Grafana is enabled in your ``values.yaml``, you can display the tracing data
in the Grafana dashboard. In order to achieve this, Grafana needs to have a
Tempo datasource configured. 

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

