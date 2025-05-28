<?php
include_once("dbconnect.php");

// get parameters (fall back to 0 if relay not provided)
$temp  = isset($_GET['temp'])  ? $_GET['temp']  : '';
$hum   = isset($_GET['hum'])   ? $_GET['hum']   : '';
$relay = isset($_GET['relay']) ? $_GET['relay'] : 0;

// make sure you have a `relay_status` column in your table
$sql = "
  INSERT INTO `tbl_dht`
    (`temperature`, `humidity`, `relay_status`)
  VALUES
    ('$temp', '$hum', '$relay')
";

if ($conn->query($sql) === TRUE) {
    echo "success";
} else {
    echo "failed: " . $conn->error;
}

$conn->close();
?>
