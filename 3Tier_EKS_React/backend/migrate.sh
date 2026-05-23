#!/bin/bash
# Migration script for database setup
# Author: Pushparaj Naik
# This script handles database migrations and initial data seeding

set -e

echo "Starting database migration..."

# Wait for database to be ready
echo "Waiting for database..."
while ! pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER 2>/dev/null; do
    echo "Database is not ready yet. Retrying..."
    sleep 2
done

echo "Database is ready!"

# Run Flask database migrations
echo "Running Flask DB upgrade..."
flask db upgrade

# Seed initial data
echo "Seeding initial data..."
python seed_data.py

echo "Migration completed successfully!"
