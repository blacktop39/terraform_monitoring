"""
Kafka 메트릭을 Prometheus 형식으로 노출하는 HTTP 서버
"""
import time
import json
import threading
from datetime import datetime
from collections import defaultdict, deque
from http.server import HTTPServer, BaseHTTPRequestHandler
from kafka import KafkaConsumer, KafkaAdminClient, KafkaProducer
from kafka.admin import NewTopic
from kafka.errors import KafkaError
import logging

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class KafkaMetrics:
    def __init__(self):
        self.message_counts = defaultdict(int)
        self.message_rates = defaultdict(deque)  # 시간별 메시지 수
        self.consumer_lag = defaultdict(int)
        self.topic_partitions = {}
        self.last_update = time.time()
        self.error_count = 0
        self.connection_status = 1  # 1: 연결됨, 0: 연결 안됨
        
    def update_message_count(self, topic, count=1):
        """메시지 수 업데이트"""
        self.message_counts[topic] += count
        now = time.time()
        
        # 1분 단위로 rate 계산을 위한 데이터 저장
        minute_key = int(now // 60)
        if not self.message_rates[topic]:
            self.message_rates[topic] = deque(maxlen=60)  # 최근 60분
        
        # 같은 분에 대해서는 누적
        if self.message_rates[topic] and self.message_rates[topic][-1][0] == minute_key:
            prev_count = self.message_rates[topic][-1][1]
            self.message_rates[topic][-1] = (minute_key, prev_count + count)
        else:
            self.message_rates[topic].append((minute_key, count))
        
        self.last_update = now
        
    def get_message_rate(self, topic, window_minutes=5):
        """최근 N분간 메시지 전송률 계산"""
        if topic not in self.message_rates:
            return 0
            
        now = time.time()
        window_start = int(now // 60) - window_minutes
        
        total_messages = 0
        for minute_key, count in self.message_rates[topic]:
            if minute_key >= window_start:
                total_messages += count
                
        return total_messages / window_minutes if window_minutes > 0 else 0
    
    def update_error_count(self):
        """에러 수 증가"""
        self.error_count += 1
        
    def set_connection_status(self, status):
        """연결 상태 업데이트"""
        self.connection_status = status
    
    def to_prometheus_format(self):
        """Prometheus 메트릭 형식으로 변환"""
        metrics = []
        
        # 기본 메트릭들
        metrics.append("# HELP kafka_messages_total Total number of messages per topic")
        metrics.append("# TYPE kafka_messages_total counter")
        
        for topic, count in self.message_counts.items():
            metrics.append(f'kafka_messages_total{{topic="{topic}"}} {count}')
        
        # 메시지 전송률
        metrics.append("# HELP kafka_message_rate_per_minute Messages per minute by topic")
        metrics.append("# TYPE kafka_message_rate_per_minute gauge")
        
        for topic in self.message_counts.keys():
            rate = self.get_message_rate(topic)
            metrics.append(f'kafka_message_rate_per_minute{{topic="{topic}"}} {rate}')
        
        # 토픽별 파티션 수
        metrics.append("# HELP kafka_topic_partitions Number of partitions per topic")
        metrics.append("# TYPE kafka_topic_partitions gauge")
        
        for topic, partitions in self.topic_partitions.items():
            metrics.append(f'kafka_topic_partitions{{topic="{topic}"}} {partitions}')
        
        # 에러 수
        metrics.append("# HELP kafka_exporter_errors_total Total number of errors")
        metrics.append("# TYPE kafka_exporter_errors_total counter")
        metrics.append(f"kafka_exporter_errors_total {self.error_count}")
        
        # 연결 상태
        metrics.append("# HELP kafka_exporter_connection_status Connection status to Kafka")
        metrics.append("# TYPE kafka_exporter_connection_status gauge")
        metrics.append(f"kafka_exporter_connection_status {self.connection_status}")
        
        # 시스템 상태
        metrics.append("# HELP kafka_exporter_up Kafka exporter status")
        metrics.append("# TYPE kafka_exporter_up gauge")
        metrics.append("kafka_exporter_up 1")
        
        # 마지막 업데이트 시간
        metrics.append("# HELP kafka_last_update_timestamp Last metrics update timestamp")
        metrics.append("# TYPE kafka_last_update_timestamp gauge")
        metrics.append(f"kafka_last_update_timestamp {int(self.last_update)}")
        
        # 현재 시간
        metrics.append("# HELP kafka_scrape_timestamp Current scrape timestamp")
        metrics.append("# TYPE kafka_scrape_timestamp gauge")
        metrics.append(f"kafka_scrape_timestamp {int(time.time())}")
        
        return "\n".join(metrics)

class KafkaMonitor:
    def __init__(self, bootstrap_servers='kafka:9092'):
        self.bootstrap_servers = bootstrap_servers
        self.metrics = KafkaMetrics()
        self.admin_client = None
        self.running = False
        self.topics_to_monitor = [
            'events-user-login', 
            'events-order', 
            'events-page-view', 
            'events-error'
        ]
        
    def connect_to_kafka(self):
        """Kafka 클러스터에 연결"""
        try:
            self.admin_client = KafkaAdminClient(
                bootstrap_servers=self.bootstrap_servers,
                request_timeout_ms=5000
            )
            self.metrics.set_connection_status(1)
            logger.info(f"Connected to Kafka cluster at {self.bootstrap_servers}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to Kafka: {e}")
            self.metrics.set_connection_status(0)
            self.metrics.update_error_count()
            return False
    
    def create_topics_if_not_exist(self):
        """토픽이 존재하지 않으면 생성"""
        try:
            if not self.admin_client:
                return
                
            existing_topics = self.admin_client.list_topics()
            topics_to_create = []
            
            for topic in self.topics_to_monitor:
                if topic not in existing_topics:
                    topics_to_create.append(NewTopic(
                        name=topic,
                        num_partitions=3,
                        replication_factor=1
                    ))
            
            if topics_to_create:
                self.admin_client.create_topics(topics_to_create)
                logger.info(f"Created topics: {[t.name for t in topics_to_create]}")
                
        except Exception as e:
            logger.error(f"Error creating topics: {e}")
            self.metrics.update_error_count()
    
    def get_topic_info(self):
        """토픽 정보 수집"""
        try:
            if not self.admin_client:
                return
                
            # 토픽 메타데이터 가져오기
            metadata = self.admin_client.describe_topics(self.topics_to_monitor)
            
            for topic_name, topic_info in metadata.items():
                partition_count = len(topic_info.partitions)
                self.metrics.topic_partitions[topic_name] = partition_count
                logger.debug(f"Topic {topic_name}: {partition_count} partitions")
                    
        except Exception as e:
            logger.error(f"Error getting topic info: {e}")
            self.metrics.update_error_count()
    
    def monitor_topic(self, topic):
        """특정 토픽 모니터링"""
        try:
            consumer = KafkaConsumer(
                topic,
                bootstrap_servers=self.bootstrap_servers,
                auto_offset_reset='latest',
                group_id=f'metrics-monitor-{topic}',
                value_deserializer=lambda m: json.loads(m.decode('utf-8')) if m else None,
                consumer_timeout_ms=1000  # 1초 타임아웃
            )
            
            logger.info(f"Started monitoring topic: {topic}")
            
            while self.running:
                try:
                    message_batch = consumer.poll(timeout_ms=1000)
                    
                    if message_batch:
                        for topic_partition, messages in message_batch.items():
                            message_count = len(messages)
                            if message_count > 0:
                                self.metrics.update_message_count(topic_partition.topic, message_count)
                                
                                # 주기적으로 로그 출력
                                if self.metrics.message_counts[topic_partition.topic] % 50 == 0:
                                    rate = self.metrics.get_message_rate(topic_partition.topic)
                                    logger.info(f"[{topic_partition.topic}] Total: {self.metrics.message_counts[topic_partition.topic]}, Rate: {rate:.1f}/min")
                                
                except Exception as e:
                    logger.error(f"Error consuming from {topic}: {e}")
                    self.metrics.update_error_count()
                    time.sleep(5)  # 에러 발생 시 잠시 대기
                    
        except Exception as e:
            logger.error(f"Error setting up consumer for {topic}: {e}")
            self.metrics.update_error_count()
    
    def start_monitoring(self):
        """모니터링 시작"""
        self.running = True
        
        # Kafka 연결
        if not self.connect_to_kafka():
            logger.error("Failed to connect to Kafka, continuing without connection...")
            return
        
        # 토픽 생성 (필요한 경우)
        self.create_topics_if_not_exist()
        
        # 토픽 정보 수집
        self.get_topic_info()
        
        # 각 토픽별 모니터링 스레드 시작
        for topic in self.topics_to_monitor:
            thread = threading.Thread(target=self.monitor_topic, args=(topic,))
            thread.daemon = True
            thread.start()
            
        # 주기적으로 토픽 정보 업데이트
        def update_topic_info():
            while self.running:
                time.sleep(30)  # 30초마다 업데이트
                self.get_topic_info()
        
        info_thread = threading.Thread(target=update_topic_info)
        info_thread.daemon = True
        info_thread.start()
    
    def stop_monitoring(self):
        """모니터링 중지"""
        self.running = False
        if self.admin_client:
            self.admin_client.close()

class MetricsHandler(BaseHTTPRequestHandler):
    def __init__(self, kafka_monitor, *args, **kwargs):
        self.kafka_monitor = kafka_monitor
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        if self.path == '/metrics':
            # Prometheus 메트릭 반환
            try:
                metrics = self.kafka_monitor.metrics.to_prometheus_format()
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.end_headers()
                self.wfile.write(metrics.encode('utf-8'))
            except Exception as e:
                logger.error(f"Error generating metrics: {e}")
                self.send_error(500, f"Internal Server Error: {e}")
                
        elif self.path == '/health':
            # 헬스체크 엔드포인트
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            health_data = {
                "status": "healthy",
                "connection_status": self.kafka_monitor.metrics.connection_status,
                "error_count": self.kafka_monitor.metrics.error_count,
                "last_update": self.kafka_monitor.metrics.last_update
            }
            self.wfile.write(json.dumps(health_data).encode('utf-8'))
            
        else:
            # 간단한 상태 페이지
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            
            html = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Kafka Metrics Exporter</title>
                <style>
                    body {{ font-family: Arial, sans-serif; margin: 40px; }}
                    .status {{ color: {'green' if self.kafka_monitor.metrics.connection_status else 'red'}; }}
                    pre {{ background-color: #f5f5f5; padding: 10px; border-radius: 5px; }}
                </style>
            </head>
            <body>
                <h1>Kafka Metrics Exporter</h1>
                <p><strong>Status:</strong> <span class="status">{'Connected' if self.kafka_monitor.metrics.connection_status else 'Disconnected'}</span></p>
                <p><strong>Error Count:</strong> {self.kafka_monitor.metrics.error_count}</p>
                <p><strong>Last Update:</strong> {datetime.fromtimestamp(self.kafka_monitor.metrics.last_update)}</p>
                
                <h2>Links</h2>
                <ul>
                    <li><a href="/metrics">Prometheus Metrics</a></li>
                    <li><a href="/health">Health Check</a></li>
                </ul>
                
                <h2>Current Message Counts</h2>
                <pre>{json.dumps(dict(self.kafka_monitor.metrics.message_counts), indent=2)}</pre>
                
                <h2>Topic Partitions</h2>
                <pre>{json.dumps(dict(self.kafka_monitor.metrics.topic_partitions), indent=2)}</pre>
                
                <h2>Message Rates (per minute)</h2>
                <pre>{json.dumps({topic: self.kafka_monitor.metrics.get_message_rate(topic) for topic in self.kafka_monitor.metrics.message_counts.keys()}, indent=2)}</pre>
            </body>
            </html>
            """
            self.wfile.write(html.encode('utf-8'))
    
    def log_message(self, format, *args):
        # HTTP 로그 레벨 조정
        logger.debug(f"HTTP: {format % args}")

def run_exporter(port=8081):
    """메트릭 Exporter HTTP 서버 실행"""
    kafka_monitor = KafkaMonitor()
    
    # Kafka 모니터링 시작
    kafka_monitor.start_monitoring()
    
    # HTTP 서버 설정
    def handler(*args, **kwargs):
        MetricsHandler(kafka_monitor, *args, **kwargs)
    
    server = HTTPServer(('0.0.0.0', port), handler)
    
    logger.info(f"Kafka Metrics Exporter started on port {port}")
    logger.info(f"Metrics URL: http://localhost:{port}/metrics")
    logger.info(f"Health Check URL: http://localhost:{port}/health")
    logger.info("Press Ctrl+C to stop")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        kafka_monitor.stop_monitoring()
        server.shutdown()
        server.server_close()

if __name__ == "__main__":
    run_exporter()