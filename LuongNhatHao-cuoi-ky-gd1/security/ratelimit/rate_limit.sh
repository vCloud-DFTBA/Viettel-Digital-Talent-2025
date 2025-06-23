#!/bin/bash

# Base config
# BASE_URL="http://localhost:8081/api"
BASE_URL="https://fullstack-app.com:31582/backend/api"
AUTH="-u admin:adminpass"
HEADER="Content-Type: application/json"
TODO_ENDPOINT="/todos"

# Counter
REQ_COUNT=0

# POST: Add a random todo
do_post() {
  ((REQ_COUNT++))
  TITLE="Task $RANDOM"
  TIME=$(date +"%T")
  echo "[$TIME] (#$REQ_COUNT) POST $TODO_ENDPOINT - Title: $TITLE"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $AUTH -X POST "$BASE_URL$TODO_ENDPOINT" \
    -H "$HEADER" \
    -d "{\"title\": \"$TITLE\", \"done\": false}" -k)
  echo "[$TIME] (#$REQ_COUNT) → Status: $STATUS"
}

# GET: List all todos
do_get() {
  ((REQ_COUNT++))
  TIME=$(date +"%T")
  echo "[$TIME] (#$REQ_COUNT) GET $TODO_ENDPOINT"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $AUTH -X GET "$BASE_URL$TODO_ENDPOINT" -k)
  echo "[$TIME] (#$REQ_COUNT) → Status: $STATUS"
}

# --- 5 guaranteed POST requests ---
echo "== [$(date +"%T")] Seeding with 5 POST requests =="
for i in {1..5}; do
  do_post
  sleep 0.2
done

# --- Random 10 requests (GET or POST) ---
echo "== [$(date +"%T")] Randomized Requests =="
for i in {1..10}; do
  if (( RANDOM % 2 )); then
    do_post
  else
    do_get
  fi
  sleep 0.3
done

echo "== Done. Total requests sent: $REQ_COUNT =="


