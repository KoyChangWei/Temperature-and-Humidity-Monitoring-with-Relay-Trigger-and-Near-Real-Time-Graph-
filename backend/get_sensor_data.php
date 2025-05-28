<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include_once("dbconnect.php");

try {
    // Get the limit parameter from query string, default to 50
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
    
    // Validate limit (between 1 and 500)
    if ($limit < 1) {
        $limit = 50;
    } elseif ($limit > 500) {
        $limit = 500;
    }
    
    // Get the total count of all records in the table
    $countStmt = $conn->prepare("SELECT COUNT(*) as total_count FROM tbl_dht");
    $countStmt->execute();
    $countResult = $countStmt->get_result();
    $totalCount = $countResult->fetch_assoc()['total_count'];
    
    // Get the records with the specified limit ordered by timestamp
    $stmt = $conn->prepare("SELECT id, temperature, humidity, timestamp, relay_status FROM tbl_dht ORDER BY timestamp DESC LIMIT ?");
    $stmt->bind_param("i", $limit);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $sensorData = [];
    while ($row = $result->fetch_assoc()) {
        $sensorData[] = [
            'id' => $row['id'],
            'temperature' => floatval($row['temperature']),
            'humidity' => floatval($row['humidity']),
            'timestamp' => $row['timestamp'],
            'relay_status' => $row['relay_status']
        ];
    }
    
    // Reverse the array to show chronological order (oldest first)
    $sensorData = array_reverse($sensorData);
    
    echo json_encode([
        'status' => 'success',
        'data' => $sensorData,
        'count' => count($sensorData),
        'total_records' => intval($totalCount),
        'limit' => $limit
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}

$conn->close();
?> 