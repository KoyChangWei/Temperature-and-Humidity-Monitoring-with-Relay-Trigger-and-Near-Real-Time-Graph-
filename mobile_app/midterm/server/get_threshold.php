<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include_once("dbconnect.php");

try {
    // Get the threshold values from the database
    $stmt = $conn->prepare("SELECT sensor_id, sensor_name, threshold_temp, threshold_humidity, timestamp FROM tbl_threshold_relay ORDER BY sensor_id");
    $stmt->execute();
    $result = $stmt->get_result();
    
    $thresholds = [];
    while ($row = $result->fetch_assoc()) {
        $thresholds[] = [
            'sensor_id' => intval($row['sensor_id']),
            'sensor_name' => $row['sensor_name'],
            'threshold_temp' => floatval($row['threshold_temp']),
            'threshold_humidity' => floatval($row['threshold_humidity']),
            'timestamp' => $row['timestamp']
        ];
    }
    
    // If no thresholds exist, create default ones
    if (empty($thresholds)) {
        $defaultThresholds = [
            [
                'sensor_id' => 1,
                'sensor_name' => 'dht11',
                'threshold_temp' => 26.0,
                'threshold_humidity' => 70.0
            ]
        ];
        
        foreach ($defaultThresholds as $threshold) {
            $insertStmt = $conn->prepare("INSERT INTO tbl_threshold_relay (sensor_id, sensor_name, threshold_temp, threshold_humidity) VALUES (?, ?, ?, ?)");
            $insertStmt->bind_param("isdd", $threshold['sensor_id'], $threshold['sensor_name'], $threshold['threshold_temp'], $threshold['threshold_humidity']);
            $insertStmt->execute();
            $insertStmt->close();
        }
        
        // Fetch the newly created thresholds
        $stmt = $conn->prepare("SELECT sensor_id, sensor_name, threshold_temp, threshold_humidity, timestamp FROM tbl_threshold_relay ORDER BY sensor_id");
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $thresholds[] = [
                'sensor_id' => intval($row['sensor_id']),
                'sensor_name' => $row['sensor_name'],
                'threshold_temp' => floatval($row['threshold_temp']),
                'threshold_humidity' => floatval($row['threshold_humidity']),
                'timestamp' => $row['timestamp']
            ];
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'data' => $thresholds
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}

$conn->close();
?> 