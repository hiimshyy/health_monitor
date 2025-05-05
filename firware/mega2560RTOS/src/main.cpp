#include <Wire.h>
#include <OneWire.h>
#include <RTClib.h>
#include <SPI.h>
#include <ArduinoJson.h>
#include <Arduino_FreeRTOS.h>
#include <semphr.h>
#include <queue.h>
#include <task.h>
#include "TFT_Screen.h"
#include "config.h"
#include "model.h"

Data healthData = {-1};
Wifi_Status wifiStatus = DISCONNECTED;
TFT_Screen screen;
RTC_DS3231 rtc;
DateTime time;
Eloquent::ML::Port::OneClassSVM svm;

void displayIntro() {
  // Serial.println("Displaying intro screen");
  // screen.displayFromSD("cce.bmp");
  // screen.displayFromSD("DDT.bmp");
  screen.displayFromSD("logo.bmp");
  screen.displayInformation();
  screen.disableSDCard();
  screen.clearScreen();
  screen.drawHorizontalLine();
  screen.drawBatteryIcon(280, 10);
}

void serialEvent() {
  while (Serial.available()) {
    digitalWrite(LED_DATA_PIN, HIGH);
    String msg = Serial.readStringUntil('\n');
    Serial.println("Serial: " + msg);
    if( msg.startsWith("<SYS:") || 
        ((msg.indexOf(",") != -1) && (msg.indexOf("DIA:") != -1))) {
      healthData.sys = msg.substring(5, msg.length() - 1).toInt();
      healthData.dia = msg.substring(msg.indexOf("DIA:") + 4).toInt();
    }
    digitalWrite(LED_DATA_PIN, LOW);
  }
}

void serialEvent1() {
  while (Serial1.available()) {
    digitalWrite(LED_DATA_PIN, HIGH);
    String tempMsg = Serial1.readStringUntil('\n');
    tempMsg.trim();
    // Serial.println("Temp: " + tempMsg);
    if (tempMsg.startsWith("<TEMP:")) {
      healthData.temp = tempMsg.substring(6).toFloat();
      healthData.temp = round(healthData.temp * 10) / 10.0;
    } 
    digitalWrite(LED_DATA_PIN, LOW);
  }
}

void serialEvent2() {
  while (Serial2.available()) {
    digitalWrite(LED_DATA_PIN, HIGH);
    String max30100Msg = Serial2.readStringUntil('\n');
    max30100Msg.trim();
    Serial.println("Spo2 & HR: " + max30100Msg);
    if (max30100Msg.startsWith("<SpO2:")) {
      healthData.spo2 = max30100Msg.substring(6, max30100Msg.indexOf(",")).toInt();
      healthData.hr = max30100Msg.substring(max30100Msg.indexOf("HR:")+3).toInt();
    }
    digitalWrite(LED_DATA_PIN, LOW);
  }
}

void serialEvent3() {
  while (Serial3.available()) {
    digitalWrite(LED_DATA_PIN, HIGH);
    String esp8266Msg = Serial3.readStringUntil('\n');
    esp8266Msg.trim();
    Serial.println("ESP8266: " + esp8266Msg);
    if (esp8266Msg == "OKWIFI" /*|| esp8266Msg == "mqtt connected"*/) {
      wifiStatus = CONNECTED;
    } else if (esp8266Msg == "START") {
      is_remote = true;
    } else if (esp8266Msg == "STOP") {
      is_remote = false;
    } else if (esp8266Msg == "SILENT") {
      is_silent = true;
      digitalWrite(11, LOW);
      noTone(BUZZER_PIN);
    }

    if(esp8266Msg.startsWith("{\"topic\":")){
      JsonDocument doc;
      deserializeJson(doc, esp8266Msg);
      String chatbotMsg = doc["msg"];
      Serial.println("Chatbot: " + chatbotMsg);
    }
    // Serial.println("Wifi status: " + String(wifiStatus));
    digitalWrite(LED_DATA_PIN, LOW);
  }
}

void updateDisplayTask(void *pvParameters) {
  while (1) {
    static uint8_t updateTime = 0;
    DateTime now = rtc.now();
    if (now.minute() != time.minute()) {
      time = now;
      screen.drawTime(time.hour(), time.minute());
    }

    static Wifi_Status lastWifiStatus = IDLE;
    if (lastWifiStatus != wifiStatus) {
      if (wifiStatus) {
        screen.drawWifiIcon(260, 20, 15, WHITE);
      } else {
        screen.drawWifiIcon(260, 20, 15, WHITE);
        screen.drawSlashes(260, 10, 15, WHITE);
      }
      lastWifiStatus = wifiStatus;
    }
    static Data lastHealthData = {-1};
    if (lastHealthData.temp != healthData.temp) {
      screen.updateTempValue(healthData.temp);
      // screen.drawLastTemp(healthData.temp);
      lastHealthData.temp = healthData.temp;
    }
    if (lastHealthData.spo2 != healthData.spo2) {
      screen.updateSpO2Value(healthData.spo2);
      // screen.drawLastSpO2(healthData.spo2);
      lastHealthData.spo2 = healthData.spo2;
    }
    if (lastHealthData.hr != healthData.hr) {
      screen.updateHRValue(healthData.hr);
      // screen.drawLastHR(healthData.hr);
      lastHealthData.hr = healthData.hr;
    }
    if (lastHealthData.sys != healthData.sys || lastHealthData.dia != healthData.dia) {
      screen.updatePressureValue(healthData.sys, healthData.dia);
      // screen.drawLastPressure(healthData.sys, healthData.dia);
      lastHealthData.sys = healthData.sys;
      lastHealthData.dia = healthData.dia;
      float features[5] = {(float)healthData.spo2, (float)healthData.hr, healthData.temp, (float)healthData.sys, (float)healthData.dia};
      result = svm.predict(features);
      Serial.println("Result: " + String(result));
      if (updateTime == 0) updateTime = 1;
      else screen.displayLastData(healthData.temp, healthData.spo2, healthData.hr, healthData.sys, healthData.dia);
    }
    
    vTaskDelay(pdMS_TO_TICKS(100)); 
  }
}

void sendMsgTask(void *pvParameters) {
  static Data lastSentData = {-1};  
  JsonDocument doc;
  while (1) {
    if (lastSentData.temp != healthData.temp && lastSentData.spo2 != healthData.spo2 &&
        lastSentData.hr != healthData.hr && lastSentData.sys != healthData.sys &&
        lastSentData.dia != healthData.dia) {
      doc["temp"] = healthData.temp;
      doc["spo2"] = healthData.spo2;
      doc["hr"] = healthData.hr;
      doc["sys"] = healthData.sys;
      doc["dia"] = healthData.dia;
      serializeJson(doc, Serial3);
      // Serial3.println(msg);
      lastSentData = healthData;
    }
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

void alertTask(void *pvParameters) {
  uint8_t lastButtonState = HIGH;
  uint32_t lastDebounceTime = 0;

  while (1) {
    uint8_t currentState = digitalRead(SILENT_PIN);

    if (currentState != lastButtonState) {
      lastDebounceTime = xTaskGetTickCount();
      // Serial.println("Button state: " + String(currentState));
    }

    if ((xTaskGetTickCount() - lastDebounceTime) > pdMS_TO_TICKS(DEBOUNCE_DELAY)) {
      if (currentState == LOW) {
        digitalWrite(BUZZER_PIN, LOW);
        is_silent = true;
      }
    }
    lastButtonState = currentState;
    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

void setup() {
  // Init serial ports
  Serial.begin(115200);   // HUYETAP
  Serial1.begin(9600);    // ATmega328P 1
  Serial2.begin(115200);  // ATmega328P 2
  Serial3.begin(9600);  // ESP8266

  pinMode(LED_ERR_PIN, OUTPUT);
  digitalWrite(LED_ERR_PIN, LOW);
  pinMode(SILENT_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);    
  // digitalWrite(SILENT_PIN, LOW);  
  pinMode(LED_DATA_PIN, OUTPUT);       
  digitalWrite(LED_DATA_PIN, LOW);
  screen.init();

  if (!rtc.begin()) {
    Serial.println("Couldn't find RTC");
  }
  displayIntro();

  xTaskCreate(updateDisplayTask, "DisplayTask", 1024, NULL, 1, NULL);
  xTaskCreate(alertTask, "AlertTask", 128, NULL, 1, NULL);
  xTaskCreate(sendMsgTask, "SendMsgTask", 256, NULL, 1, NULL);
}
void loop() {
}

