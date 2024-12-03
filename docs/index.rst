
.. toctree::
    :maxdepth: 3
    :hidden:
    
    Home <self>
    installation
    configuration-reference


SuperSONIC
========================================

The SuperSONIC project implements server infrastructure for inference-as-a-service
computing paradigm at large high energy physics (HEP) and multimissenger astrophysics
(MMA) experiments. The server infrastructure is designed for deployment at
`Kubernetes <kubernetes.io>`_ clusters equipped with GPUs.

Why "inference-as-a-service"?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The computing demands of modern scientific experiments are growing at a faster rate than the performance improvements
of traditional processors (CPUs). This trend is driven by increasing data collection rates and the rising
complexity of algorithms, particularly those based on machine learning. 
Such a computing landscape strongly motivates the adoption of specialized co-processors, such as FPGAs, GPUs, and TPUs.

.. image:: https://a3d3.ai/wp-content/uploads/2023/07/hdr_latency_throughput.png
   :align: center
   :height: 200
   :alt: A3D3


In "inference-as-a-service" model, the data processing workflows ("clients") off-load computationally intensive steps,
such as neural network inference, to a remote "server" equipped with co-processors. This design allows to optimize both
data processing throughput and co-processor utilization by dynamically balancing the ratio of CPUs to co-processors.
Numerous R&D efforts implementing this paradigm in HEP and MMA experiments are grouped under the name
**SONIC** - Services for Optimized Network Inference on Coprocessors.

.. image:: https://www.frontiersin.org/files/Articles/604083/fdata-03-604083-HTML-r1/image_m/fdata-03-604083-g004.jpg
   :align: center
   :height: 120
   :alt: IaaS


The goal of SuperSONIC
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A key feature of the SONIC approach is the decoupling of clients from servers and the standardization
of communication between them.
While client-side implementations may vary across applications, the server-side infrastructure can remain
largely the same, since the server functionality requirements (load balancing, autoscaling, etc.) are not
workflow-specific. 

The purpose of SuperSONIC project is to develop server infrastructure that could be reused by scientific
experiments with only small differences in configuration.


Experiments that use SuperSONIC
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The experiments listed below are developing workflows with inference-as-a-service implementations compatible with SuperSONIC.

- `CMS Experiment <https://home.cern/science/experiments/cms>`_ at the Large Hadron Collider (CERN).

  .. image:: https://cmsexperiment.web.cern.ch/sites/default/files/field/image/cds-record-1275108-hoch-20071215_721-nice.jpg
     :width: 300
     :alt: CMS Detector

- `ATLAS Experiment <https://home.cern/science/experiments/atlas>`_ at the Large Hadron Collider (CERN).

  .. image:: https://cds.cern.ch/images/CERN-PHOTO-202107-094-112/file?size=large
     :width: 300
     :alt: ATLAS Detector

- `IceCube Neutrino Observatory <https://icecube.wisc.edu/>`_ at the South Pole.

  .. image:: https://www.hpcwire.com/wp-content/uploads/2018/07/IceCube_1200x.jpg
     :width: 300
     :alt: IceCube


Deployment sites
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SuperSONIC has been successfully tested at the computing clusters listed below. 

- Purdue University: `Geddes cluster <https://www.rcac.purdue.edu/compute/geddes>`_.
- National Research Platform (NRP): `Nautilus cluster <https://docs.nationalresearchplatform.org/>`_.
