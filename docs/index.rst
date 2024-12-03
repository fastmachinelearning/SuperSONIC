
.. toctree::
    :maxdepth: 3
    :hidden:
    
    Home <self>
    getting-started
    configuration-reference


SuperSONIC
========================================

The SuperSONIC project implements server infrastructure for **inference-as-a-service**
applications in large high energy physics (HEP) and multi-messenger astrophysics
(MMA) experiments. The server infrastructure is designed for deployment at
`Kubernetes <kubernetes.io>`_ clusters equipped with GPUs.

SuperSONIC GitHub repository: `fastmachinelearning/SuperSONIC <https://github.com/>`_.

-----

Why "inference-as-a-service"?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. container:: twocol

   .. container:: leftside

      The computing demands of modern scientific experiments are growing at a faster rate than the performance improvements
      of traditional processors (CPUs). This trend is driven by increasing data collection rates, tightening latency requirements,
      and rising complexity of algorithms, particularly those based on machine learning.
      Such a computing landscape strongly motivates the adoption of specialized coprocessors, such as FPGAs, GPUs, and TPUs.

   .. container:: rightside

      .. image:: https://a3d3.ai/wp-content/uploads/2023/07/hdr_latency_throughput.png
         :width: 220
         :alt: A3D3

      `Image source: A3D3 <https://a3d3.ai/about/>`_


In "inference-as-a-service" model, the data processing workflows ("clients") off-load computationally intensive steps,
such as neural network inference, to a remote "server" equipped with coprocessors. This design allows to optimize both
data processing throughput and coprocessor utilization by dynamically balancing the ratio of CPUs to coprocessors.
Numerous R&D efforts implementing this paradigm in HEP and MMA experiments are grouped under the name
**SONIC (Services for Optimized Network Inference on Coprocessors)**.

.. image:: https://www.frontiersin.org/files/Articles/604083/fdata-03-604083-HTML-r1/image_m/fdata-03-604083-g004.jpg
   :align: center
   :height: 160
   :alt: IaaS

-----

SuperSONIC: a case for shared server infrastructure
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A key feature of the SONIC approach is the decoupling of clients from servers and the standardization
of communication between them.
While client-side implementations may vary across applications, the server-side infrastructure can remain
largely the same, since the server functionality requirements (load balancing, autoscaling, etc.) are not
experiment-specific. 

The purpose of SuperSONIC project is to develop server infrastructure that could be reused by scientific
experiments with only small differences in configuration.

-----

Experiments that use SuperSONIC
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The experiments listed below are developing workflows with inference-as-a-service implementations compatible with SuperSONIC.

.. raw:: html

    <table style="width:100%; border-collapse: collapse;">
        <tr>
            <td style="width:65%; vertical-align: top;">
                <p><a href="https://home.cern/science/experiments/cms">CMS Experiment</a> at the Large Hadron Collider (CERN).</p>
                <p>
                    CMS is testing inference-as-a-service approach in Run 3 offline processing workflows, off-loading inferences to GPUs for
                    machine learning models such as <strong>ParticleNet</strong>, <strong>DeepMET</strong>, <strong>DeepTau</strong>, <strong>ParT</strong>.
                    In addition, non-ML tracking algorithms such as <strong>LST</strong> and <strong>Patatrack</strong> are being adapted for deployment
                    as-a-service.
                </p>
            </td>
            <td style="width:35%; vertical-align: top;">
                <img src="https://cmsexperiment.web.cern.ch/sites/default/files/field/image/cds-record-1275108-hoch-20071215_721-nice.jpg" alt="CMS Detector" width="200">
            </td>
        </tr>
    </table>

----

.. raw:: html

    <table style="width:100%; border-collapse: collapse;">
        <tr>
            <td style="width:65%; vertical-align: top;">
                <p><a href="https://home.cern/science/experiments/atlas">ATLAS Experiment</a> at the Large Hadron Collider (CERN).</p>
                <p>
                    ATLAS implements inference-as-a-service approach for tracking algorithms such as <strong>Exa.TrkX</strong> and <strong>Traccc</strong>.
                </p>
            </td>
            <td style="width:35%; vertical-align: top;">
                <img src="https://cds.cern.ch/images/CERN-PHOTO-202107-094-112/file?size=large" alt="ATLAS Detector" width="200">
            </td>
        </tr>
    </table>

----

.. raw:: html

    <table style="width:100%; border-collapse: collapse;">
        <tr>
            <td style="width:65%; vertical-align: top;">
                <p><a href="https://icecube.wisc.edu/">IceCube Neutrino Observatory</a> at the South Pole.</p>
                <p>
                    IceCube uses SONIC approach to accelerate event classifier algorithms based on convolutional neural networks (CNNs).
                </p>
            </td>
            <td style="width:35%; vertical-align: top;">
                <img src="https://www.hpcwire.com/wp-content/uploads/2018/07/IceCube_1200x.jpg" alt="IceCube" width="200">
            </td>
        </tr>
    </table>

Deployment sites
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SuperSONIC has been successfully tested at the computing clusters listed below. 

- Purdue University: `Geddes cluster <https://www.rcac.purdue.edu/compute/geddes>`_.
- National Research Platform (NRP): `Nautilus cluster <https://docs.nationalresearchplatform.org/>`_.
