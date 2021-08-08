function Decode(fPort, bytes) {
  
  var decoded = {};
  
  if (fPort === 3) {
    // Temperature on bytes 0 and 1
    var celciusInt = (bytes[0] & 0x80 ? 0xFFFF<<16 : 0) | bytes[0]<<8 | bytes[1];
    decoded.Temperature = celciusInt / 100;
    // Humidity on bytes 2 and 3
    var humiInt = (bytes[2] & 0x80 ? 0xFFFF<<16 : 0) | bytes[2]<<8 | bytes[3];
    decoded.Humidity = humiInt / 100;
    // Pressure on bytes 4, 5, 6 and 7
    var pressInt = (bytes[4] & 0x80 ? 0xFFFF<<32 : 0) | bytes[4]<<24 | bytes[5]<<16 | bytes[6]<<8 | bytes[7];
    decoded.Pressure = pressInt / 100;
    // Epoch on bytes 8, 9, 10 and 11
    var Epoch = (bytes[8] & 0x80 ? 0xFFFF<<32 : 0) | bytes[8]<<24 | bytes[9]<<16 | bytes[10]<<8 | bytes[11];
    decoded.Timestamp = Epoch;
    // distance on bytes 12 and 13
    decoded.Distance = (bytes[12] & 0x80 ? 0xFFFF<<16 : 0) | bytes[12]<<8 | bytes[13];    
    // Battery Level on byte 14
    decoded.BatteryLevelA = bytes[14];
  }
  
  // Return the array
  return decoded;
}
