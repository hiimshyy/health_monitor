#include <LiquidCrystal_I2C.h>
#include <SoftwareSerial.h>

SoftwareSerial BP(2,3);  //rx tx

LiquidCrystal_I2C lcd(0x27,20,4);  // set the LCD address to 0x3F for a 16 chars and 2 line display

void setup() {
  BP.begin(9600);
  Serial.begin(9600);
  lcd.init();
  lcd.clear();         
  lcd.backlight();      // Make sure backlight is on
  
  // Print a message on both lines of the LCD.
  lcd.setCursor(2,0);   //Set cursor to character 2 on line 0
  lcd.print("Blood Pressure!");
  
  lcd.setCursor(2,1);   //Move cursor to character 2 on line 1
  lcd.print("Measurement Using");

   lcd.setCursor(2,2);   //Move cursor to character 2 on line 1
  lcd.print("Arduino");
}

void loop() {

  boolean BPavailable=false;
  char data[32]; byte i=0;
  while(BP.available())
  {
    char c=BP.read();
    data[i]=c;
    i++;
    BPavailable=true;
  }
  if(BPavailable)
  {
      char *strings[3]; 
      char *ptr = NULL;    
       byte index = 0;
       ptr = strtok(data, ",");  // delimiter
       while (ptr != NULL)
       {
          strings[index] = ptr;
          index++;
          ptr = strtok(NULL, ",");
       }
    
       int systolic = atoi(strings[0]);  // devices
       int diastolic = atoi(strings[1]);  // temperature
       int bpm = atoi(strings[2]);  // humidity
       
       
    lcd.clear();
    Serial.println(data);
    lcd.setCursor(0,0);   
    lcd.print("Systolic: ");
    lcd.setCursor(11,0);   
    lcd.print(systolic);

    lcd.setCursor(0,1);   
    lcd.print("Diastolic: ");
    lcd.setCursor(11,1);   
    lcd.print(diastolic);

    lcd.setCursor(0,2);   
    lcd.print("Heart Rate: ");
    lcd.setCursor(12,2);   
    lcd.print(bpm);

  }
}
