global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 15s

  - job_name: 'fastapi'
    static_configs:
      - targets: ['${fastapi_host}:${fastapi_port}']
    scrape_interval: 30s
    scrape_timeout: 10s

  - job_name: 'kafka-exporter'
    static_configs:
      - targets: ['host.docker.internal:${kafka_exporter_port}']
    scrape_interval: 15s
    metrics_path: /metrics
    scrape_timeout: 10s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['host.docker.internal:9100']
    scrape_interval: 30s
    # 노드 익스포터가 설치된 경우에만 활성화

  # Docker 컨테이너 메트릭 (cAdvisor가 설치된 경우)
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['host.docker.internal:8080']
    scrape_interval: 30s

  # 추가 메트릭 수집 대상들
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
    scrape_interval: 30s
    metrics_path: /metrics

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# 알림 규칙 설정 (옵션)
# rule_files:
#   - "alert_rules.yml"