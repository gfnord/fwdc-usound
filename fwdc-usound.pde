#include <WaspSensorAgr_v30.h>
#include <WaspLoRaWAN.h>
#include <WaspGPS.h>

// Lorawan Keys
// ultrasound01
char DEVICE_EUI[]  = "6b5c3b1e0f055a15";
char DEVICE_ADDR[] = "036d26da";
char NWK_SESSION_KEY[] = "22eb465f3becbfea9f1a7e4ac9b2b562";
char APP_SESSION_KEY[] = "c0777299d72c605e83bcdeda8452f9ff";
char moteID[] = "usound01";
char testing_dev[] = "NO";
char unit_with_gps[] = "YES";

// ultrasound02
//char DEVICE_EUI[]  = "b8ad19b6854abcc2";
//char DEVICE_ADDR[] = "023a53d8";
//char NWK_SESSION_KEY[] = "a65381ad6dcd11d55c209e2c5e06f2de";
//char APP_SESSION_KEY[] = "da1129fb92f30478b1d725ce86dff8db";
//char moteID[] = "usound02";
//char testing_dev[] = "NO";
//char unit_with_gps[] = "NO";

// Variable to store the distance value
uint16_t dist = 0;
// error variable
uint8_t error, error2, error3;
// define folder and file to store data
char path_conf[]="/conf";
char path_data[]="/data";
char filename_conf_sleep[]="/conf/sleeptm";
char filename_data[]="/data/data.txt";
// GPS update RTC counter
int gps_counter = 0;
// Variable to store BME280 values
float temp, humd, pres;
// define variable to check sdcard commands
uint8_t sd_answer;
char toWrite[64];
char _deepsleeptime[11]; // loaded from config file
char __deepsleeptime[11];
// define GPS timeout when connecting to satellites
// this time is defined in seconds (240sec = 4minutes)
#define TIMEOUT 240
// define status variable for GPS connection
bool status;
// Define variable to store Epoch time
uint32_t epoch;
//Lora socket
uint8_t socket = SOCKET0; 
int Battery_Level = 0;


void setup()
{
  GPS.ON();
  RTC.ON();
  USB.ON();

  USB.println(F("Astra Smart Systems - Ultrasound Sensor - v1.3 - 2021/Sep/24"));
  USB.print(F("Deep Sleep time (dd:hh:mm:ss) loaded from config file: "));
  strncpy(_deepsleeptime, _loadConfig_sleeptime(), 11);
  _deepsleeptime[11] = 0;
  USB.println(_deepsleeptime);
  if (strcmp(testing_dev, "YES") == 0) 
  {
    USB.println(F("Testing device mode. Sleep time will be 1 minute."));
  }
  USB.println();
  _setup_datafile();

  if (strcmp(unit_with_gps, "YES") == 0)
  {
    USB.print(F("-- Getting GPS data... "));
    status = GPS.waitForSignal(TIMEOUT);
    if( status == true )
    {    
      // set time in RTC from GPS time (GMT time)
      GPS.setTimeFromGPS();
      Utils.blinkLEDs(1000);
      USB.println(F("done."));
      GPS.OFF();
    }
  }

  // Call _lorasetup function
  USB.print(F("-- Setting up Lorawan connection... "));
  _lorasetup();
  USB.println(F("done."));
  
  USB.print(F("-- Current Time: "));
  USB.println(RTC.getTime());  
  USB.OFF();
}
 
void loop()
{  
  // If testing mode, print the data
  if (strcmp(testing_dev, "YES") == 0 && strcmp(unit_with_gps, "YES") == 0)
  {
    USB.ON();
    USB.print(F("GPS Cycle: "));
    USB.println(gps_counter);  
    USB.OFF();    
  }

  if (strcmp(unit_with_gps, "YES") == 0)
  {
    // GPS to update RTC clock every 14 days in case 60 minutes per cycle
    gps_counter++;
    if (gps_counter > 1344) { // Update RTC Clock
      GPS.ON();
      status = GPS.waitForSignal(TIMEOUT);
      if( status == true )
      {    
        // set time in RTC from GPS time (GMT time)
        GPS.setTimeFromGPS();
        GPS.OFF();
        gps_counter = 0;
      }
    }
  }

  // Goign to sleep with sensors off
  USB.ON();
  USB.print(F("-- Going in Deep Sleep... "));
  USB.OFF();
  if (strcmp(testing_dev, "YES") == 0) 
  {
    Agriculture.sleepAgr("00:00:01:00", RTC_OFFSET, RTC_ALM1_MODE4, ALL_OFF);
  } else {
    Agriculture.sleepAgr("00:00:15:00", RTC_OFFSET, RTC_ALM1_MODE4, ALL_OFF); // deep sleep time fixed
  } 
  USB.ON();
  USB.println(F("Done, woke up."));
  USB.OFF();

  // Turn on the sensor board
  Agriculture.ON(); 
  
  // Take the readings and send the lora payload
  measureSensors();

  // Turn off the sensor board
  Agriculture.OFF(); 
}

void measureSensors()
{
  if (strcmp(unit_with_gps, "YES") == 0)
  {
    epoch = RTC.getEpochTime();
  }
  
  // Read data from sensor BME280
  temp = Agriculture.getTemperature();
  humd  = Agriculture.getHumidity();
  pres = Agriculture.getPressure();  
  // Read data from Ultrasound sensor 
  dist = Agriculture.getDistance();

  // Prepare the lorawan payload
  uint8_t _battery_level = PWR.getBatteryLevel(); //1 byte
  uint16_t _temp = temp * 100; // 2 bytes
  uint16_t _humd = humd * 100;
  uint32_t _pres = pres * 100; // 4 bytes
  // We don' need to convert epoch (4 bytes) and dist (2 bytes)

    uint8_t PORT = 3; // for units with GPS
    uint8_t payload[15];
    uint8_t PORT_NO_GPS = 4; // for units without GPS
    uint8_t payload_no_gps[11];
 
  if (strcmp(testing_dev, "YES") == 0)
  {
    Battery_Level = PWR.getBatteryLevel();
    USB.ON();
    USB.println();
    USB.println(F("Sensor's data: "));
    USB.print(F("  Battery: "));
    USB.print(Battery_Level);
    USB.println(F(" %"));
    USB.print(F("  Temperature: "));
    USB.print(temp);
    USB.println(F(" Celsius"));
    USB.print(F("  Humidity: "));
    USB.print(humd);
    USB.println(F(" %"));  
    USB.print(F("  Pressure: "));
    USB.print(pres);
    USB.println(F(" Pa"));  
    USB.print(F("  Distance: "));
    USB.print(dist);
    USB.println(F(" cm"));  
    USB.println();  
    USB.OFF();   
  }
  
  // THE payload
  if (strcmp(unit_with_gps, "YES") == 0)
  {
    memset(payload,0x00, sizeof(payload));
    payload[0]  = _temp >> 8;
    payload[1]  = _temp;
    payload[2]  = _humd >> 8;
    payload[3]  = _humd;
    payload[4]  = _pres >> 24;
    payload[5]  = _pres >> 16;
    payload[6]  = _pres >> 8;
    payload[7]  = _pres;
    payload[8]  = epoch >> 24;
    payload[9]  = epoch >> 16;
    payload[10] = epoch >> 8;
    payload[11] = epoch;
    payload[12] = dist >> 8;
    payload[13] = dist;
    payload[14] = _battery_level;
  } else {
    memset(payload_no_gps,0x00, sizeof(payload_no_gps));
    payload_no_gps[0]  = _temp >> 8;
    payload_no_gps[1]  = _temp;
    payload_no_gps[2]  = _humd >> 8;
    payload_no_gps[3]  = _humd;
    payload_no_gps[4]  = _pres >> 24;
    payload_no_gps[5]  = _pres >> 16;
    payload_no_gps[6]  = _pres >> 8;
    payload_no_gps[7]  = _pres;
    payload_no_gps[8] = dist >> 8;
    payload_no_gps[9] = dist;
    payload_no_gps[10] = _battery_level;
  }
  
  // Store the payload on SDCARD
  if (strcmp(testing_dev, "YES") == 0)
  {
    USB.ON(); 
    USB.println(F("-- Storing the data in the local SDCARD... "));
  }
  if (strcmp(unit_with_gps, "YES") == 0)
  {
    Utils.hex2str(payload, toWrite, sizeof(payload));
  } else
  {
    Utils.hex2str(payload_no_gps, toWrite, sizeof(payload_no_gps));
  }
  SD.ON();
  sd_answer = SD.appendln(filename_data, toWrite);
  
  if (strcmp(testing_dev, "YES") == 0)
  {
    if( sd_answer == 1 )
    {
      USB.println(F("-- Data added to file"));
    }
    else 
    {
      USB.println(F("** Data append error!"));
    }
  }
  SD.OFF();
  if (strcmp(testing_dev, "YES") == 0)
  {
    USB.OFF();
  }
  
  // Send the Lorawan Frame
  LoRaWAN.ON(socket);
  error = LoRaWAN.joinABP();
  if( error == 0 )
  {
    if (strcmp(unit_with_gps, "YES") == 0)
    {
      error = _send_message(PORT, payload, sizeof(payload));
      if( error != 0 )
      {
        // Try to send second time
        delay(20000);
        error2 = _send_message(PORT, payload, sizeof(payload));
        if ( error2 != 0 )
        {
          // Try to send third time
          delay(20000);
          error3 = _send_message(PORT, payload, sizeof(payload));
          if ( error3 != 0 )
          {
            USB.ON();
            USB.print(F("** Failed to send lora message, rebooting. "));
            USB.OFF();
            PWR.reboot();
          }
        }
      }
    } else {
      error = _send_message(PORT_NO_GPS, payload_no_gps, sizeof(payload_no_gps));
      if( error != 0 )
      {
        // Try to send second time
        delay(20000);
        error2 = _send_message(PORT_NO_GPS, payload_no_gps, sizeof(payload_no_gps));
        if ( error2 != 0 )
        {
          // Try to send third time
          delay(20000);
          error3 = _send_message(PORT_NO_GPS, payload_no_gps, sizeof(payload_no_gps));
          if ( error3 != 0 )
          {
            USB.ON();
            USB.print(F("** Failed to send lora message, rebooting. "));
            USB.OFF();
            // Sleep for 30 minutes then reboot.
            Agriculture.sleepAgr("00:00:30:00", RTC_OFFSET, RTC_ALM1_MODE4, ALL_OFF);
            PWR.reboot();
          }
        }
      }      
    }
  }
  LoRaWAN.OFF(socket);    
}

void _lorasetup()
{
  LoRaWAN.ON(socket);
  LoRaWAN.factoryReset();
  LoRaWAN.setDeviceEUI(DEVICE_EUI);
  LoRaWAN.setDeviceAddr(DEVICE_ADDR);
  LoRaWAN.setNwkSessionKey(NWK_SESSION_KEY);
  LoRaWAN.setAppSessionKey(APP_SESSION_KEY);
  LoRaWAN.setRetries(7);
  for (int ch = 0; ch <= 7; ch++)
  {
    LoRaWAN.setChannelStatus(ch, "off");
  }

  for (int ch = 16; ch <= 64; ch++)
  {
    LoRaWAN.setChannelStatus(ch, "off");
  }
  LoRaWAN.setDataRate(2);
  LoRaWAN.setADR("off");
  LoRaWAN.setAR("on");
  LoRaWAN.saveConfig();
  LoRaWAN.OFF(socket);
}

//
// Load sleeptime configuration from SD
//
char *_loadConfig_sleeptime()
{
  SD.ON();
  delay(1000);
  SD.mkdir(path_conf);  
  sd_answer = SD.create(filename_conf_sleep);
  if( sd_answer == 1 ) // If new file, create with the normal sleeping time
  {    
    sd_answer = SD.writeSD(filename_conf_sleep,"00:00:15:00", 0);
    return("00:00:15:00");
  }
  else // if not, read the content
  {
    SD.catln(filename_conf_sleep,0,1);
    if (strcmp(SD.buffer, "00:00:15:00") == 0)
    {
      return("00:00:15:00");
    } else if (strcmp(SD.buffer, "00:01:00:00") == 0)
    {
      return("00:01:00:00");
    } else 
    {
      USB.ON();
      USB.println(F("** Failed to read sleeptime from sdcard. Assuming 00:00:15:00"));
      USB.OFF();
      return("00:00:15:00"); 
    }
  }     
  // Set SD OFF
  SD.OFF();
}

//
// Write sleeptime configuration from SD
//
void _writeConfig_sleeptime(uint16_t deepsleeptime)
{
  USB.ON();
  // Set SD ON
  SD.ON();
  // create path
  sd_answer = SD.mkdir(path_conf);  
     if( sd_answer == 1 )
     { 
       USB.println(F("-- SD CONF SLEEP: Path created"));
     }
     else
     {
       USB.println(F("-- SD CONF SLEEP: Path already exists."));
     }  
  // Delete file to store config sleep time
  sd_answer = SD.del(filename_conf_sleep);
  if( sd_answer == 1 )
  { 
    // File deleted
    USB.println(F("-- SD CONF SLEEP: Old file deleted. Creating a new one."));
    sd_answer = SD.create(filename_conf_sleep);
    if( sd_answer == 1 )
    {
      if (deepsleeptime == 5)
      {
        sd_answer = SD.writeSD(filename_conf_sleep,"00:00:15:00", 0); // Normal Mode
      }
      if (deepsleeptime == 15)
      {
        sd_answer = SD.writeSD(filename_conf_sleep,"00:01:00:00", 0); // Winter Mode
      }
    }
    else 
    {
      USB.println(F("** SD CONF SLEEP: file NOT created"));  
    }   
  }
  else
  {
    // File already exists, so read the value from it
    USB.println(F("** SD CONF SLEEP: Error deleting file."));
  }     
  // Set SD OFF
  SD.OFF();
  USB.OFF();
  // Reboot
  PWR.reboot();
}

// Function to send the lora message
int _send_message(int PORT, uint8_t PAYLOAD[], int SIZEPAYLOAD) 
{
  int response;
  LoRaWAN.setADR("off");
  LoRaWAN.setDataRate(2);

  if (strcmp(testing_dev, "YES") == 0)
  { 
    response = LoRaWAN.sendUnconfirmed(PORT, PAYLOAD, SIZEPAYLOAD);
  } else {
    response = LoRaWAN.sendConfirmed(PORT, PAYLOAD, SIZEPAYLOAD);
  }
  if( response == 0 )
  {
    if (strcmp(testing_dev, "YES") == 0)
    {
      USB.ON();
      USB.println(F("-- Sent lorawan message OK"));
      USB.OFF();
    }
    if (LoRaWAN._dataReceived == true)
    {
      if (LoRaWAN._port == 5)
      {
        if (strcmp(LoRaWAN._data, "4E6F726D616C") == 0 ) // Mormal mode
        {
          _writeConfig_sleeptime(5); 
        }
        if (strcmp(LoRaWAN._data, "57696E746572") == 0 ) // Winter mode
        {
          _writeConfig_sleeptime(15); 
        }
      }
    }
  } else {
    USB.ON();
    USB.print(F("** Failed to send lora message, error: "));
    USB.println(response);
    USB.OFF();
    return response;
  }
}

void _setup_datafile()
{
  SD.ON();
  SD.mkdir(path_data);
  SD.create(filename_data);
  SD.OFF();
}
