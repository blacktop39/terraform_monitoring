# 포트 설정 변수들
variable "prometheus_port" {
  description = "Prometheus external port"
  type        = number
  default     = 9090
}

variable "grafana_port" {
  description = "Grafana external port"
  type        = number
  default     = 3000
}

variable "kafka_port" {
  description = "Kafka external port"
  type        = number
  default     = 9092
}

variable "zookeeper_port" {
  description = "Zookeeper external port"
  type        = number
  default     = 2181
}

variable "mariadb_port" {
  description = "MariaDB external port"
  type        = number
  default     = 3306
}

variable "kafka_exporter_port" {
  description = "Kafka Exporter external port"
  type        = number
  default     = 8081
}

# 서비스 버전 변수들
variable "kafka_version" {
  description = "Kafka version"
  type        = string
  default     = "3.4.0"
}

variable "mariadb_version" {
  description = "MariaDB version"
  type        = string
  default     = "11.3"
}

variable "python_version" {
  description = "Python version for Kafka exporter"
  type        = string
  default     = "3.9-slim"
}

# 보안 관련 변수들
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  default     = "example_root_pw"
  sensitive   = true
}

variable "mysql_password" {
  description = "MySQL user password"
  type        = string
  default     = "example_pw"
  sensitive   = true
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
  default     = "example_db"
}

variable "mysql_user" {
  description = "MySQL user name"
  type        = string
  default     = "example_user"
}

# 리소스 설정 변수들
variable "kafka_memory_mb" {
  description = "Kafka memory allocation in MB"
  type        = number
  default     = 512
  
  validation {
    condition     = var.kafka_memory_mb >= 256 && var.kafka_memory_mb <= 4096
    error_message = "Kafka memory must be between 256MB and 4096MB."
  }
}

# 외부 서비스 설정
variable "fastapi_host" {
  description = "FastAPI host for monitoring"
  type        = string
  default     = "ec2-43-201-38-187.ap-northeast-2.compute.amazonaws.com"
}

variable "fastapi_port" {
  description = "FastAPI port for monitoring"
  type        = number
  default     = 8000
}

# 환경 설정
variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "enable_debug" {
  description = "Enable debug mode"
  type        = bool
  default     = true
}

# 태그 설정
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    project     = "monitoring"
    environment = "dev"
    managed_by  = "terraform"
    owner       = "sangho.jeon"
  }
}