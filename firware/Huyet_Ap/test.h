#include "HX710B.h"
#define DATA_ARRAY_SIZE 35
#define UPPER_THRESHOLD 170
#define LOWER_THRESHOLD 60
byte NO_TIMES = 10;
const int DOUT_Pin = 3;   //sensor data pin
const int SCK_Pin  = 4;   //sensor clock pin
const int pump_pin = 9;
const int valve_pin = 8;


float average;
float pressure_pascal;
float pressure_mmHg;
long READ_TIMES = 10;
long OFFSET = -540000;; // used for tare weight
float SCALE = 1;  // used to return weight in grams, kg, ounces, whatever
float RES = 2.98023e-7;

float pressure_data[DATA_ARRAY_SIZE];
float average_pressure(float pres[],  size_t size){
    int max_wave = 0;
    float avg_pres = 0;
    for(int counter=0; counter < size; counter++){
        if(pres[counter]>avg_pres){
//            max_wave = wave[counter];
            avg_pres = pres[counter];
        }
    }
    Serial.print("THE average_pressure IS ------------%f");
    Serial.println(avg_pres);
    return avg_pres;
}

HX710B pressure_sensor; 

void setup() {
  Serial.begin(9600);
  pressure_sensor.begin(DOUT_Pin, SCK_Pin,64);
  pinMode(pump_pin,OUTPUT);
  pinMode(valve_pin,OUTPUT);
}

void loop() {
  digitalWrite(valve_pin,HIGH);
  delay(500);
  unsigned long currentMillis = millis();
  if (pressure_sensor.is_ready()) {
    pressure_mmHg = ((pressure_sensor.read() - OFFSET)*RES) * 20 - 7.78 * 3.5;
    digitalWrite(pump_pin,HIGH);
    while(pressure_mmHg < UPPER_THRESHOLD ){
      pressure_mmHg = ((pressure_sensor.read() - OFFSET)*RES) * 20 - 7.78 * 3.5;
      Serial.println(pressure_mmHg);
      delay(10);
    }
    digitalWrite(pump_pin,LOW);
    delay(1000);
    for(int i = 0; i < DATA_ARRAY_SIZE; i++){
      pressure_mmHg =  ((pressure_sensor.read() - OFFSET)*RES) * 20 - 7.78 * 3.5;
      if(pressure_mmHg < UPPER_THRESHOLD && pressure_mmHg > LOWER_THRESHOLD){
        pressure_data[i] = pressure_mmHg;
        //Serial.print("Pressure data in mmHg: ");
        Serial.println(pressure_data[i]);
         
      }
      delay(10);
    }
    digitalWrite(valve_pin,LOW);
    Serial.println("Done pumping.....");
 
    delay(50000);
  } 
}