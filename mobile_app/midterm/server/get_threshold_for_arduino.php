<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

include_once("dbconnect.php");

try {
    // Get the threshold values for sensor_id = 1 (default DHT11)
    $stmt = $conn->prepare("SELECT threshold_temp, threshold_humidity FROM tbl_threshold_relay WHERE sensor_id = 1");
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        // Return thresholds in a simple format for Arduino
        echo json_encode([
            'temp_threshold' => floatval($row['threshold_temp']),
            'humidity_threshold' => floatval($row['threshold_humidity']),
            'status' => 'success'
        ]);
    } else {
        // Return default values if no thresholds found
        echo json_encode([
            'temp_threshold' => 26.0,
            'humidity_threshold' => 70.0,
            'status' => 'default'
        ]);
    }
    
} catch (Exception $e) {
    // Return default values on error
    echo json_encode([
        'temp_threshold' => 26.0,
        'humidity_threshold' => 70.0,
        'status' => 'error'
    ]);
}

$conn->close();
?> 