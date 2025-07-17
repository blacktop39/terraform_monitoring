terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "npipe:////.//pipe//docker_engine"
}

# 네트워크 생성
resource "docker_network" "monitoring" {
  name = "monitoring-network"
}

# Prometheus 컨테이너
resource "docker_container" "prometheus" {
  image = "prom/prometheus:latest"
  name  = "prometheus"
  
  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--web.console.libraries=/etc/prometheus/console_libraries",
    "--web.console.templates=/etc/prometheus/consoles",
    "--storage.tsdb.retention.time=15d",
    "--web.enable-lifecycle"
  ]
  
  ports {
    internal = 9090
    external = var.prometheus_port
  }
  
  volumes {
    host_path      = "${path.cwd}/prometheus"
    container_path = "/etc/prometheus"
  }
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  
  restart = "unless-stopped"
}

# Grafana 컨테이너
resource "docker_container" "grafana" {
  image = "grafana/grafana:latest"
  name  = "grafana"
  
  ports {
    internal = 3000
    external = var.grafana_port
  }
  
  volumes {
    host_path      = "${path.cwd}/grafana-data"
    container_path = "/var/lib/grafana"
  }
  
  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}"
  ]
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  depends_on = [docker_container.prometheus]
  restart = "unless-stopped"
}

# Zookeeper 컨테이너
resource "docker_container" "zookeeper" {
  image = "bitnami/zookeeper:latest"
  name  = "zookeeper"
  
  ports {
    internal = 2181
    external = var.zookeeper_port
  }
  
  env = [
    "ALLOW_ANONYMOUS_LOGIN=yes"
  ]
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  restart = "unless-stopped"
}

# Kafka 컨테이너
resource "docker_container" "kafka" {
  image = "bitnami/kafka:${var.kafka_version}"
  name  = "kafka"
  
  ports {
    internal = 9092
    external = var.kafka_port
  }
  
  env = [
    "KAFKA_BROKER_ID=1",
    "KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181",
    "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:${var.kafka_port}",
    "ALLOW_PLAINTEXT_LISTENER=yes",
    "KAFKA_HEAP_OPTS=-Xmx${var.kafka_memory_mb}m -Xms${var.kafka_memory_mb}m"
  ]
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  depends_on = [docker_container.zookeeper]
  restart = "unless-stopped"
}

# MariaDB 컨테이너
resource "docker_container" "mariadb" {
  image = "mariadb:${var.mariadb_version}"
  name  = "mariadb"
  
  ports {
    internal = 3306
    external = var.mariadb_port
  }
  
  env = [
    "MYSQL_ROOT_PASSWORD=${var.mysql_root_password}",
    "MYSQL_DATABASE=${var.mysql_database}",
    "MYSQL_USER=${var.mysql_user}",
    "MYSQL_PASSWORD=${var.mysql_password}"
  ]
  
  volumes {
    host_path      = "${path.cwd}/mariadb-data"
    container_path = "/var/lib/mysql"
  }
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  restart = "unless-stopped"
}

# Prometheus 설정 파일 생성
resource "local_file" "prometheus_config" {
  content = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    kafka_exporter_port = var.kafka_exporter_port
    fastapi_host = var.fastapi_host
    fastapi_port = var.fastapi_port
  })
  
  filename = "${path.cwd}/prometheus/prometheus.yml"
}