LOG_FILE="rate_test_$(date '+%Y%m%d_%H%M%S').txt"
LOG_ID="TEST_$(date '+%Y%m%d%H%M%S')"

{
    echo "=== Rate Limiting Test - ID: $LOG_ID ==="
    echo "Time: $(date)"
    echo ""
    
    for i in {1..12}; do
        echo "Request $i: [$(date '+%H:%M:%S')]"
        curl -s -w "HTTP Code: %{http_code}\n" http://192.168.122.93:30002/api/students
        echo "---"
        sleep 2
    done
    
    echo ""
    echo "Test completed: $(date)"
} | tee $LOG_FILE

echo "Log saved to: $LOG_FILE"