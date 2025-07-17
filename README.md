# Terraform Monitoring Stack

현재 Docker Compose 기반 모니터링 시스템을 Terraform으로 관리하는 프로젝트입니다.

## 📋 개요

이 프로젝트는 다음 서비스들을 포함합니다:
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 대시보드 시각화
- **Kafka + Zookeeper**: 메시지 브로커
- **MariaDB**: 데이터베이스
- **Kafka Exporter**: 커스텀 메트릭 수집기

## 🚀 빠른 시작

### 1. 사전 준비사항
- [Terraform](https://www.terraform.io/downloads) 설치
- [Docker Desktop](https://www.docker.com/products/docker-desktop) 설치 및 실행
- Git (선택사항)

### 2. 프로젝트 클론 및 설정
```bash
# 프로젝트 디렉토리로 이동
cd C:\Users\sangho.jeon\Documents\workspaces\terraform-monitoring

# 설정 파일 생성
copy terraform.tfvars.example terraform.tfvars

# terraform.tfvars 파일을 편집하여 본인 환경에 맞게 설정
```

### 3. 테라폼 초기화 및 실행
```bash
# 테라폼 초기화
terraform init

# 실행 계획 확인
terraform plan

# 인프라 배포
terraform apply
```

### 4. 서비스 접속
배포가 완료되면 다음 URL로 접속할 수 있습니다:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Kafka Exporter**: http://localhost:8081/metrics

## 📁 프로젝트 구조

```
terraform-monitoring/
├── main.tf                    # 메인 테라폼 설정
├── variables.tf               # 변수 정의
├── outputs.tf                 # 출력 값 정의
├── terraform.tfvars.example   # 설정 예시 파일
├── README.md                  # 이 파일
├── templates/                 # 템플릿 파일들
│   ├── prometheus.yml.tpl
│   └── Dockerfile.tpl
├── scripts/                   # 스크립트 파일들
│   └── kafka_prometheus_exporter.py
└── 생성되는 폴더들/
    ├── prometheus/           # Prometheus 설정
    ├── grafana-data/        # Grafana 데이터
    ├── mariadb-data/        # MariaDB 데이터
    └── kafka/               # Kafka Exporter 관련
```

## ⚙️ 주요 설정

### 포트 설정
- **Prometheus**: 9090
- **Grafana**: 3000
- **Kafka**: 9092
- **MariaDB**: 3306
- **Zookeeper**: 2181
- **Kafka Exporter**: 8081

### 환경 변수
`terraform.tfvars` 파일에서 다음 값들을 설정할 수 있습니다:

```hcl
# 보안 설정
grafana_admin_password = "your_secure_password"
mysql_root_password    = "your_root_password"
mysql_password         = "your_user_password"

# 리소스 설정
kafka_memory_mb = 512

# 환경 설정
environment = "dev"  # dev, staging, prod
enable_debug = true
```

## 🔧 자주 사용하는 명령어

### 테라폼 명령어
```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply

# 특정 리소스만 배포
terraform apply -target=docker_container.prometheus

# 인프라 삭제
terraform destroy

# 상태 확인
terraform show

# 출력 값 확인
terraform output
```

### Docker 명령어
```bash
# 모든 컨테이너 상태 확인
docker ps

# 특정 컨테이너 로그 확인
docker logs prometheus
docker logs grafana
docker logs kafka

# 컨테이너 재시작
docker restart prometheus

# 컨테이너 접속
docker exec -it prometheus /bin/sh
```

### 서비스 상태 확인
```bash
# Prometheus 상태 확인
curl -f http://localhost:9090/-/healthy

# Grafana 상태 확인  
curl -f http://localhost:3000/api/health

# Kafka Exporter 메트릭 확인
curl -f http://localhost:8081/metrics
```

## 📊 모니터링 대시보드

### Grafana 설정
1. http://localhost:3000 접속
2. admin/admin (또는 설정한 비밀번호)로 로그인
3. Data Sources에서 Prometheus 추가:
   - URL: http://prometheus:9090
4. 대시보드 임포트 또는 직접 생성

### Prometheus 타겟 확인
1. http://localhost:9090 접속
2. Status → Targets에서 수집 대상 확인

## 🔍 문제 해결

### 일반적인 문제들

**1. 포트 충돌**
```bash
# 포트 사용 중인 프로세스 확인
netstat -an | findstr :3000

# terraform.tfvars에서 포트 변경
grafana_port = 3001
```

**2. 컨테이너 시작 실패**
```bash
# 로그 확인
docker logs <container_name>

# 컨테이너 재시작
terraform apply -replace=docker_container.<container_name>
```

**3. 볼륨 권한 문제**
```bash
# Windows에서 Docker 볼륨 권한 확인
# Docker Desktop 설정에서 파일 공유 확인
```

**4. 메모리 부족**
```bash
# terraform.tfvars에서 메모리 설정 조정
kafka_memory_mb = 256
```

### 로그 위치
- **Terraform 로그**: `TF_LOG=DEBUG terraform apply`
- **Docker 로그**: `docker logs <container_name>`
- **Grafana 로그**: `docker logs grafana`
- **Prometheus 로그**: `docker logs prometheus`

## 🛠️ 커스터마이징

### 새로운 서비스 추가
1. `main.tf`에 새로운 Docker 컨테이너 리소스 추가
2. `variables.tf`에 필요한 변수 정의
3. `outputs.tf`에 접속 정보 추가

### 환경별 설정
```bash
# 개발 환경
terraform workspace new dev
terraform workspace select dev

# 스테이징 환경  
terraform workspace new staging
terraform workspace select staging
```

### 설정 파일 템플릿화
`templates/` 디렉토리에서 설정 파일 템플릿을 관리하고 변수로 동적 생성

## 🔐 보안 고려사항

### 비밀번호 관리
```bash
# 환경 변수 사용
export TF_VAR_grafana_admin_password="secure_password"
export TF_VAR_mysql_root_password="secure_password"

# 또는 .tfvars 파일 사용 (Git에 포함하지 않음)
echo "*.tfvars" >> .gitignore
```

### 네트워크 보안
- 기본적으로 localhost에서만 접근 가능
- 외부 접근 필요시 방화벽 설정 고려

## 🚀 고급 사용법

### 백업 및 복원
```bash
# 테라폼 상태 백업
terraform state pull > backup/terraform.tfstate.backup

# 데이터베이스 백업
docker exec mariadb mysqldump -u root -p your_database > backup/db_backup.sql

# 볼륨 백업
docker cp grafana:/var/lib/grafana ./backup/grafana-backup/
```

### 성능 튜닝
```bash
# 메모리 사용량 모니터링
docker stats

# 리소스 제한 설정
# main.tf의 Docker 컨테이너 리소스 제한 추가
```

### 확장성 고려
- 여러 Kafka 브로커 설정
- 프로메테우스 클러스터링
- 로드밸런서 추가

## 📝 변경 로그

### v1.0.0 (2025-01-XX)
- 초기 버전 릴리즈
- Docker Compose에서 Terraform 전환
- 기본 모니터링 스택 구성

## 🤝 기여하기

1. 이슈 리포트 또는 개선사항 제안
2. 브랜치 생성 및 변경사항 구현
3. 테스트 및 문서 업데이트
4. PR 생성

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🆘 지원

문제가 발생하면:
1. 이 README의 문제 해결 섹션 확인
2. GitHub Issues 검색
3. 새로운 이슈 생성

---

**Happy Monitoring! 🎉**