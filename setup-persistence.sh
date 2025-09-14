#!/bin/bash
# CrewAI Agents Persistence Setup
# Ensures data survives container restarts and system reboots

set -e

AGENT_DIR="/home/rreck/Desktop/20250914a/agent"
DATA_ROOT="/home/rreck/crewai-data"

echo "🔄 Setting up persistent data storage for CrewAI agents..."

# Create persistent data directories
echo "📁 Creating persistent data directories..."
mkdir -p "$DATA_ROOT"/{prometheus,grafana}/{data,config,logs}
mkdir -p "$DATA_ROOT"/shared/{registries,backups}

# Setup Prometheus persistence
echo "⚡ Configuring Prometheus persistence..."
PROMETHEUS_DIR="$AGENT_DIR/crewai-prometheus"
if [ -f "$PROMETHEUS_DIR/output/targets_registry.json" ]; then
    cp "$PROMETHEUS_DIR/output/targets_registry.json" "$DATA_ROOT/shared/registries/"
    echo "  ✓ Backed up targets registry"
fi

if [ -d "$PROMETHEUS_DIR/output/prometheus_data" ]; then
    cp -r "$PROMETHEUS_DIR/output/prometheus_data"/* "$DATA_ROOT/prometheus/data/" 2>/dev/null || true
    echo "  ✓ Backed up Prometheus data"
fi

# Setup Grafana persistence
echo "📊 Configuring Grafana persistence..."
GRAFANA_DIR="$AGENT_DIR/crewai-grafana"
mkdir -p "$DATA_ROOT/grafana"/{data,logs,plugins,provisioning/{dashboards,datasources,notifiers}}

# Create persistence volumes configuration
cat > "$DATA_ROOT/docker-persistence.yaml" << 'EOF'
# Docker Compose persistence configuration for CrewAI agents
version: '3.8'

volumes:
  prometheus-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rreck/crewai-data/prometheus/data

  prometheus-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rreck/crewai-data/prometheus/config

  grafana-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rreck/crewai-data/grafana/data

  grafana-logs:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rreck/crewai-data/grafana/logs

  shared-registries:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rreck/crewai-data/shared/registries

services:
  crewai-prometheus:
    image: rrecktek/crewai-prometheus:1.0.0
    container_name: crewai-prometheus-persistent
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "9090:9090"
      - "9091:9091"
    volumes:
      - prometheus-data:/work/output/prometheus_data
      - prometheus-config:/work/app
      - shared-registries:/work/output/registries
    environment:
      - PROMETHEUS_STORAGE_TSDB_RETENTION_TIME=90d
      - PROMETHEUS_STORAGE_TSDB_PATH=/work/output/prometheus_data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  crewai-grafana:
    image: rrecktek/crewai-grafana:1.0.0
    container_name: crewai-grafana-persistent
    restart: unless-stopped
    ports:
      - "8085:8085"
      - "9095:9095"
      - "3000:3000"
    volumes:
      - grafana-data:/work/grafana-data
      - grafana-logs:/work/output/logs
      - shared-registries:/work/shared/registries:ro
    environment:
      - GF_PATHS_DATA=/work/grafana-data
      - GF_PATHS_LOGS=/work/output/logs
      - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8085/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      - crewai-prometheus
EOF

# Create systemd service for automatic startup
echo "🚀 Creating systemd service for automatic startup..."
sudo tee /etc/systemd/system/crewai-agents.service > /dev/null << EOF
[Unit]
Description=CrewAI Agents (Prometheus & Grafana)
Requires=docker.service
After=docker.service
StartLimitIntervalSec=0

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DATA_ROOT
ExecStart=/usr/bin/docker-compose -f docker-persistence.yaml up -d
ExecStop=/usr/bin/docker-compose -f docker-persistence.yaml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Create backup script
cat > "$DATA_ROOT/backup-crewai-data.sh" << 'EOF'
#!/bin/bash
# CrewAI Data Backup Script
BACKUP_DIR="/home/rreck/crewai-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔄 Backing up CrewAI data to $BACKUP_DIR..."
tar -czf "$BACKUP_DIR/prometheus-data.tar.gz" /home/rreck/crewai-data/prometheus/
tar -czf "$BACKUP_DIR/grafana-data.tar.gz" /home/rreck/crewai-data/grafana/
tar -czf "$BACKUP_DIR/shared-data.tar.gz" /home/rreck/crewai-data/shared/

echo "✅ Backup completed: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
EOF

chmod +x "$DATA_ROOT/backup-crewai-data.sh"

# Create restore script
cat > "$DATA_ROOT/restore-crewai-data.sh" << 'EOF'
#!/bin/bash
# CrewAI Data Restore Script
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_directory>"
    echo "Available backups:"
    ls -la /home/rreck/crewai-backups/
    exit 1
fi

BACKUP_DIR="$1"
echo "🔄 Restoring CrewAI data from $BACKUP_DIR..."

docker-compose -f /home/rreck/crewai-data/docker-persistence.yaml down

tar -xzf "$BACKUP_DIR/prometheus-data.tar.gz" -C /
tar -xzf "$BACKUP_DIR/grafana-data.tar.gz" -C /
tar -xzf "$BACKUP_DIR/shared-data.tar.gz" -C /

docker-compose -f /home/rreck/crewai-data/docker-persistence.yaml up -d

echo "✅ Restore completed from $BACKUP_DIR"
EOF

chmod +x "$DATA_ROOT/restore-crewai-data.sh"

# Set proper permissions
chown -R $USER:$USER "$DATA_ROOT"
chmod -R 755 "$DATA_ROOT"

echo ""
echo "✅ Persistence setup completed!"
echo ""
echo "📋 Summary:"
echo "  • Data directory: $DATA_ROOT"
echo "  • Prometheus data: $DATA_ROOT/prometheus/"
echo "  • Grafana data: $DATA_ROOT/grafana/"
echo "  • Shared registries: $DATA_ROOT/shared/registries/"
echo "  • Docker Compose config: $DATA_ROOT/docker-persistence.yaml"
echo "  • Systemd service: /etc/systemd/system/crewai-agents.service"
echo "  • Backup script: $DATA_ROOT/backup-crewai-data.sh"
echo "  • Restore script: $DATA_ROOT/restore-crewai-data.sh"
echo ""
echo "🔧 Next steps:"
echo "  1. Enable auto-start: sudo systemctl enable crewai-agents"
echo "  2. Start services: sudo systemctl start crewai-agents"
echo "  3. Check status: sudo systemctl status crewai-agents"
echo "  4. Create backup: $DATA_ROOT/backup-crewai-data.sh"
echo ""
echo "🔄 To migrate current data:"
echo "  cd $DATA_ROOT && docker-compose -f docker-persistence.yaml up -d"