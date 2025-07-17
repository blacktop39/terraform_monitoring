FROM python:${python_version}

WORKDIR /app

# 시스템 패키지 업데이트 및 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Python 패키지 설치
RUN pip install --no-cache-dir \
    kafka-python==2.0.2 \
    prometheus-client==0.20.0

# 애플리케이션 파일 복사
COPY kafka_prometheus_exporter.py .

# 포트 노출
EXPOSE 8081

# 헬스체크 추가
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8081/metrics || exit 1

# 애플리케이션 실행
CMD ["python", "kafka_prometheus_exporter.py"]