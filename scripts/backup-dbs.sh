#!/bin/bash

# Configuration
BACKUP_DIR="./db-backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
NAMESPACE="shared-dbs"

# Create backup directory
mkdir -p $BACKUP_DIR

# MySQL Backup
echo "Backing up MySQL database..."
kubectl exec -n $NAMESPACE $(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}') \
  -- mysqldump -u shared_user -pmysql_password_123 shared_db > $BACKUP_DIR/mysql-backup-$DATE.sql

# MongoDB Backup
echo "Backing up MongoDB collections..."
kubectl exec -n $NAMESPACE $(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}') \
  -- mongodump --uri="mongodb://shared_user:mongo_password_123@localhost:27017/shared_db" --out=$BACKUP_DIR/mongodb-backup-$DATE

# Redis Backup (Requires redis-cli in the pod)
echo "Backing up Redis data..."
kubectl exec -n $NAMESPACE $(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}') \
  -- redis-cli -a redis_password_123 --rdb /data/dump.rdb
kubectl cp $NAMESPACE/$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}'):/data/dump.rdb $BACKUP_DIR/redis-backup-$DATE.rdb

# Compress backups
tar -czvf $BACKUP_DIR/db-backup-$DATE.tar.gz $BACKUP_DIR/*-$DATE*

echo -e "\n\e[1mBackup completed!\e[0m"
echo "Backup files stored in: $BACKUP_DIR/db-backup-$DATE.tar.gz"