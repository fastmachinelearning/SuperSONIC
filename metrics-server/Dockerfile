FROM python:3.8-slim
COPY saturation_metric.py /etc/
WORKDIR /etc/
RUN pip install flask prometheus_client requests ping3
CMD ["python", "saturation_metric.py"]
