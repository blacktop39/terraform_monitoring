# 서비스 URL 출력
output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://localhost:${var.grafana_port}"
}

output "prometheus_url" {
  description = "Prometheus dashboard URL"
  value       = "http://localhost:${var.prometheus_port}"
}

output "kafka_exporter_url" {
  description = "Kafka Exporter metrics URL"
  value       = "http://localhost:${var.kafka_exporter_port}"
}

output "kafka_exporter_metrics_url" {
  description = "Kafka Exporter metrics endpoint"
  value       = "http://localhost:${var.kafka_exporter_port}/metrics"
}

# 서비스 엔드포인트 출력
output "kafka_endpoint" {
  description = "Kafka broker endpoint"
  value       = "localhost:${var.kafka_port}"
}

output "mariadb_endpoint" {
  description = "MariaDB database endpoint"
  value       = "localhost:${var.mariadb_port}"
}

output "zookeeper_endpoint" {
  description = "Zookeeper endpoint"
  value       = "localhost:${var.zookeeper_port}"
}

# 컨테이너 정보 출력
output "container_info" {
  description = "Container information"
  value = {
    prometheus = {
      name  = docker_container.prometheus.name
      id    = docker_container.prometheus.id
      ports = docker_container.prometheus.ports
    }
    grafana = {
      name  = docker_container.grafana.name
      id    = docker_container.grafana.id
      ports = docker_container.grafana.ports
    }
    kafka = {
      name  = docker_container.kafka.name
      id    = docker_container.kafka.id
      ports = docker_container.kafka.ports
    }
    mariadb = {
      name  = docker_container.mariadb.name
      id    = docker_container.mariadb.id
      ports = docker_container.mariadb.ports
    }
    zookeeper = {
      name  = docker_container.zookeeper.name
      id    = docker_container.zookeeper.id
      ports = docker_container.zookeeper.ports
    }
  }
}

# 네트워크 정보 출력
output "network_info" {
  description = "Docker network information"
  value = {
    name = docker_network.monitoring.name
    id   = docker_network.monitoring.id
  }
}

# 로그인 정보 출력
output "login_info" {
  description = "Service login information"
  value = {
    grafana = {
      url      = "http://localhost:${var.grafana_port}"
      username = "admin"
      password = var.grafana_admin_password
    }
    mariadb = {
      host     = "localhost"
      port     = var.mariadb_port
      database = var.mysql_database
      username = var.mysql_user
      password = var.mysql_password
    }
  }
  sensitive = true
}

# 환경 정보 출력
output "environment_info" {
  description = "Environment configuration"
  value = {
    environment = var.environment
    debug_mode  = var.enable_debug
    tags        = var.tags
    kafka_version = var.kafka_version
    mariadb_version = var.mariadb_version
    python_version = var.python_version
  }
}

# 서비스 상태 체크 명령어
output "health_check_commands" {
  description = "Commands to check service health"
  sensitive   = true
  value = {
    prometheus     = "curl -f http://localhost:${var.prometheus_port}/-/healthy"
    grafana        = "curl -f http://localhost:${var.grafana_port}/api/health"
    kafka_exporter = "curl -f http://localhost:${var.kafka_exporter_port}/metrics"
    mariadb        = "docker exec mariadb mysqladmin ping -h localhost -u root -p${var.mysql_root_password}"
  }
}

# 유용한 Docker 명령어
output "useful_commands" {
  description = "Useful Docker commands for troubleshooting"
  value = {
    view_logs = {
      prometheus     = "docker logs prometheus"
      grafana        = "docker logs grafana"
      kafka          = "docker logs kafka"
      mariadb        = "docker logs mariadb"
      zookeeper      = "docker logs zookeeper"
    }
    restart_container = {
      prometheus     = "docker restart prometheus"
      grafana        = "docker restart grafana"
      kafka          = "docker restart kafka"
      mariadb        = "docker restart mariadb"
      zookeeper      = "docker restart zookeeper"
    }
    exec_into_container = {
      prometheus     = "docker exec -it prometheus /bin/sh"
      grafana        = "docker exec -it grafana /bin/bash"
      kafka          = "docker exec -it kafka /bin/bash"
      mariadb        = "docker exec -it mariadb /bin/bash"
      zookeeper      = "docker exec -it zookeeper /bin/bash"
    }
  }
}