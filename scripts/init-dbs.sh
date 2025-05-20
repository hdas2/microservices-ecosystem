#!/bin/bash

# Initialize MySQL
echo "Initializing MySQL database..."
kubectl run mysql-init --rm -it --restart=Never \
  --image=mysql:8.0 \
  --namespace shared-dbs \
  --env="MYSQL_PWD=mysql_password_123" \
  --command -- bash -c \
  "mysql -h mysql.shared-dbs -u shared_user -p'mysql_password_123' shared_db -e '
    CREATE TABLE IF NOT EXISTS products (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      price DECIMAL(10,2) NOT NULL
    );
    CREATE TABLE IF NOT EXISTS orders (
      id INT AUTO_INCREMENT PRIMARY KEY,
      product_id INT,
      quantity INT,
      FOREIGN KEY (product_id) REFERENCES products(id)
    );'"

# Initialize MongoDB
echo "Initializing MongoDB collections..."
kubectl run mongo-init --rm -it --restart=Never \
  --image=mongosh:1.8 \
  --namespace shared-dbs \
  --command -- mongosh \
  "mongodb://shared_user:mongo_password_123@mongodb.shared-dbs:27017/shared_db?authSource=admin" \
  --eval "
    db.createCollection('carts');
    db.createCollection('catalog');
    db.carts.createIndex({ userId: 1 }, { unique: true });
    db.catalog.createIndex({ productId: 1 }, { unique: true });"

echo "Database initialization complete!"