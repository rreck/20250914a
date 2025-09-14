# CrewAI Agents - Working Solution Quick Reference

## 🚀 Quick Start (Proven Working)

### 1. Setup Persistence
```bash
./setup-persistence.sh
```

### 2. Start Agents
```bash
cd /home/rreck/crewai-data
docker-compose -f docker-persistence.yaml up -d
```

### 3. Verify Working
```bash
# Check Prometheus agent health
curl http://localhost:8080/health

# Check registered targets
curl http://localhost:8080/status | jq '.targets'

# Access Prometheus UI
open http://localhost:9091
```

## 📋 Working Ports & Endpoints

| Service | Port | Endpoint | Purpose |
|---------|------|----------|---------|
| Prometheus Agent API | 8080 | `/health`, `/status`, `/job` | A2A communication |
| Prometheus Metrics | 9090 | `/metrics` | Agent metrics |
| Prometheus UI | 9091 | `/graph`, `/targets` | Web interface |
| Test Server | 8087 | `/health`, `/metrics` | Integration testing |

## 🔗 Agent Registration Example

```bash
curl -X POST http://localhost:8080/job \
  -H "Content-Type: application/json" \
  -d '{
    "type": "add_target",
    "target_data": {
      "target_id": "my-agent",
      "target": "localhost:9099",
      "job_name": "my-agent-metrics",
      "scrape_interval": "30s"
    }
  }'
```

## 💾 Data Persistence Locations

- **Target Registry**: `/home/rreck/crewai-data/shared/registries/targets_registry.json`
- **Prometheus Data**: `/home/rreck/crewai-data/prometheus/data/`
- **Backups**: `/home/rreck/crewai-backups/YYYYMMDD_HHMMSS/`

## 🛠️ Management Commands

```bash
# Backup all data
/home/rreck/crewai-data/backup-crewai-data.sh

# Restore from backup
/home/rreck/crewai-data/restore-crewai-data.sh /path/to/backup

# Check container status
docker-compose -f docker-persistence.yaml ps

# View logs
docker-compose -f docker-persistence.yaml logs -f

# Restart services
docker-compose -f docker-persistence.yaml restart
```

## 🎯 Verified Working Features

- ✅ Agent builds (`make build`, `./run-*-watch.sh build`)
- ✅ Container deployment with persistent volumes
- ✅ Agent-to-agent (A2A) API communication
- ✅ Target registration and discovery
- ✅ Prometheus metrics collection
- ✅ Data persistence through reboots
- ✅ Backup and restore functionality
- ✅ Health monitoring endpoints

## 🔧 Build Commands (Tested Working)

### Prometheus Agent
```bash
cd /path/to/agent/crewai-prometheus
make build
./run-prometheus-watch.sh daemon
```

### Grafana Agent
```bash
cd /path/to/agent/crewai-grafana
./run-grafana-agent-watch.sh build
./run-grafana-agent-watch.sh daemon
```

## 📊 Current Status

**Last Verified**: 2025-09-14 12:36 UTC
- **Active Targets**: 5 registered
- **Health Status**: All endpoints responding
- **Data Persistence**: Functional and tested
- **Integration**: Agent-to-agent communication working

This solution is **production-ready** and has been tested with container restarts and data persistence verification.