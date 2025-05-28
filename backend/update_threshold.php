<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include_once("dbconnect.php");

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $sensor_id = intval($_POST['sensor_id'] ?? 1);
        $threshold_temp = floatval($_POST['threshold_temp'] ?? 26.0);
        $threshold_humidity = floatval($_POST['threshold_humidity'] ?? 70.0);
        
        // Validate input ranges
        if ($threshold_temp < 0 || $threshold_temp > 100) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Temperature threshold must be between 0°C and 100°C'
            ]);
            exit;
        }
        
        if ($threshold_humidity < 0 || $threshold_humidity > 100) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Humidity threshold must be between 0% and 100%'
            ]);
            exit;
        }
        
        // Check if threshold exists for this sensor
        $checkStmt = $conn->prepare("SELECT sensor_id FROM tbl_threshold_relay WHERE sensor_id = ?");
        $checkStmt->bind_param("i", $sensor_id);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows > 0) {
            // Update existing threshold
            $updateStmt = $conn->prepare("UPDATE tbl_threshold_relay SET threshold_temp = ?, threshold_humidity = ?, timestamp = NOW() WHERE sensor_id = ?");
            $updateStmt->bind_param("ddi", $threshold_temp, $threshold_humidity, $sensor_id);
            
            if ($updateStmt->execute()) {
                echo json_encode([
                    'status' => 'success',
                    'message' => 'Threshold updated successfully',
                    'sensor_id' => $sensor_id,
                    'threshold_temp' => $threshold_temp,
                    'threshold_humidity' => $threshold_humidity
                ]);
            } else {
                echo json_encode([
                    'status' => 'error',
                    'message' => 'Failed to update threshold'
                ]);
            }
            $updateStmt->close();
        } else {
            // Insert new threshold
            $insertStmt = $conn->prepare("INSERT INTO tbl_threshold_relay (sensor_id, sensor_name, threshold_temp, threshold_humidity) VALUES (?, 'dht11', ?, ?)");
            $insertStmt->bind_param("idd", $sensor_id, $threshold_temp, $threshold_humidity);
            
            if ($insertStmt->execute()) {
                echo json_encode([
                    'status' => 'success',
                    'message' => 'Threshold created successfully',
                    'sensor_id' => $sensor_id,
                    'threshold_temp' => $threshold_temp,
                    'threshold_humidity' => $threshold_humidity
                ]);
            } else {
                echo json_encode([
                    'status' => 'error',
                    'message' => 'Failed to create threshold'
                ]);
            }
            $insertStmt->close();
        }
        $checkStmt->close();
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Database error: ' . $e->getMessage()
        ]);
    }
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid request method'
    ]);
}

$conn->close();
?> 