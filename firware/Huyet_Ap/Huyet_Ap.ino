#include <avr/interrupt.h>
#include <Wire.h>

#define on HIGH
#define off LOW
//define states for motor control
#define startState 0
#define inflate1State 1
#define inflate2State 2
#define deflateState 3
#define displayState 4
#define resetState 5
//define states for Measure control
#define Sys_Measure 6
#define Sys_Cal 7
#define Rate_Measure 8
#define dias_Measure 9 
#define dias_Cal 10
#define stopState 11


#define DOUT_PIN 2   // Chân DT kết nối với D2
#define SCLK_PIN 3  // Chân SCK kết nối với D3

#define VALVE_PIN 4 // khai bao chan valve khi
#define MOTOR_PIN 8 // khai bao chan motor
#define START_PIN 7 // nut nhan start
#define ADC0 A0

unsigned char currentState;
unsigned int timepress0, timepress1, timepress2, timelcd;      
//declare variable for measuring and calculating value
float DC_gain;
unsigned char meas_state;
unsigned int timing, timerate, timerun_dias, timecount, timedeflate, timedisplay; 
float  maxpressure, pressure,accum_data, press_data; 
unsigned char count, stop_count;

//ADC data variabls
float Vref;
long data;
float adc_data, former; 

//define counter
unsigned char sys_count,count_average, countpulse;

//declare rate measure variable
float time_pulse,pulse_period, total_pulse_period, pulse_per_min;

//declare systolic and diastolic variable
float systolic, diastolic;
float lastSentSystolic = -1.0;   // Giá trị ban đầu không hợp lệ để buộc gửi lần đầu
float lastSentDiastolic = -1.0;
bool bpMeasured = false;  // Đánh dấu khi huyết áp đã đo xong

//declare all the threshold values
float TH_sys, TH_rate, TH_dias, TH_sys2, TH_rate2, TH_dias2;

unsigned long lastPressureSendTime = 0;
unsigned long pressureSendInterval = 1000; // 1 giây
unsigned long lastBpSendTime = 0; // Thời điểm gửi huyết áp lần cuối
unsigned long bpSendInterval = 1000; // Khoảng thời gian gửi huyết áp: 1 giây

//LiquidCrystal lcd(12, 11, 10, 9, 8, 7);
void start_state(void);
void read_adc(int Channel);
void inflate1_state(void);
void inflate2_state(void);
void deflatestate(void);
void display_state(void);
void reset_state(void);
void pressuremeasure(void);

void setup() {
  //khai bao serial
  Serial.begin(115200);
  // Khai báo chân SCLK_PIN là OUTPUT và đặt mức LOW
  pinMode(SCLK_PIN, OUTPUT);
  digitalWrite(SCLK_PIN, LOW); // Đảm bảo SCLK_PIN ở mức LOW khi khởi động

  // Khai báo chân DOUT_PIN là INPUT
  pinMode(DOUT_PIN, INPUT);
  pinMode(START_PIN, INPUT);
  //khai bao motor valve
  pinMode(MOTOR_PIN,OUTPUT);
  pinMode(VALVE_PIN,OUTPUT);
  //Cai dat LCD
  //set up timer0
  cli();              // tắt ngắt toàn cục
  /* Reset Timer/Counter1 */
  TCCR1A = 0;
  TCCR1B = 0;
  TIMSK1 = 0;
  
  /* Setup Timer/Counter1 */
  TCCR1B |= (1 << WGM12) | (1 << CS11) | (1 << CS10); // prescale = 64 and CTC mode 4
  OCR1A = 249;              // initialize OCR1A
  TIMSK1 = (1 << OCIE1A);     // Output Compare Interrupt Enable Timer/Counter1 channel A
  sei();                      // cho phép ngắt toàn cục   
  //ket thuc khai bao ngat          
                                
  maxpressure = 210; // max huyet ap
  meas_state = Sys_Measure; 

  TH_sys = 4.2; //nguong dao dong huyet ap tam thu
  //TH_rate = 4.328; //nguong dao dong  
  TH_rate = 4.0; //nguong dao dong  
  //TH_rate = 2.5; //nguong dao dong  
  TH_dias = 3.5; // huyet ap tam truong

  TH_sys2 = 3.8; //nguong dao dong huyet ap tam thu
  TH_dias2 = 3.3; // huyet ap tam truong
  TH_rate2 = 3.5; //nguong dao dong  

  former = TH_sys - 0.01;

  timerun_dias=0; 
  time_pulse=0;
  timerate=0;

  timing=40;
  timedisplay=0;

  total_pulse_period=0;
  systolic=0;
  diastolic=0;
  pulse_per_min=0;        
  
  sys_count=0;
  count_average=0;
  countpulse=0;
  // Vref = 5.0;                  
  // DC_gain=105;
  
  accum_data=0; 
  press_data=0; 
  count=0;

  // Khởi tạo trạng thái ban đầu cho motor và van
  digitalWrite(VALVE_PIN, off);  // Van đóng
  digitalWrite(MOTOR_PIN, off);  // Motor tắt

}

long readHX710B() {
  long count2 = 0;
  digitalWrite(SCLK_PIN, LOW);
  delayMicroseconds(1);

  while (digitalRead(DOUT_PIN)); // Chờ cho DT xuống mức LOW (sẵn sàng để đọc)

  for (int i = 0; i < 24; i++) { // Đọc 24 bit dữ liệu
    digitalWrite(SCLK_PIN, HIGH);
    delayMicroseconds(1);
    count2 = count2 << 1;
    digitalWrite(SCLK_PIN, LOW);
    delayMicroseconds(1);
    if (digitalRead(DOUT_PIN))
      count2++;
  }

  // Đọc bit điều khiển (nếu cần thiết)
  digitalWrite(SCLK_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(SCLK_PIN, LOW);
  delayMicroseconds(1);

  // Xử lý số âm cho giá trị 24 bit
  if (count2 & 0x800000)
    count2 |= ~0xFFFFFF;

  return count2;
}

// Khai bao cac bien cho debounce
bool buttonState = LOW;
bool lastButtonState = LOW;
unsigned long lastDebounceTime = 0;
unsigned long debounceDelay = 50;

bool isSystemRunning = false;

String lastCommand = "NO";
bool controlSource = false; // Mặc định sử dụng nút nhấn
bool controlFromESP = false; // Biến để xác định nguồn điều khiển (false: nút nhấn, true: ESP)

bool isPhysicalRunning = false; // Trạng thái motor khi điều khiển bằng nút nhấn vật lý
bool isRemoteRunning = false;   // Trạng thái motor khi điều khiển từ điện thoại

void loop() {
     // Nhận lệnh từ ESP8266
    receiveCommandFromESP();
    // Đọc trạng thái nút nhấn vật lý
    int reading = digitalRead(START_PIN);
    // Chống dội nút nhấn
    if (reading != lastButtonState) {
      lastDebounceTime = millis();
    }
    if ((millis() - lastDebounceTime) > debounceDelay) {
      if (reading != buttonState) {
        buttonState = reading;
        // Nếu nút nhấn được nhấn (mức HIGH)
        if (buttonState == HIGH) {
            togglePhysicalMotor(); // Bật/tắt motor và van từ nút nhấn vật lý
        }
      }
    }
    lastButtonState = reading;
    // toggleRemoteMotor();
    // Kiểm tra trạng thái hệ thống và chuyển đổi
    if (isPhysicalRunning || isRemoteRunning) {
      switch (currentState) {
        case startState:
          start_state();
          break;
        case inflate2State:
          inflate2_state();
          break;
        case deflateState:
          deflatestate();
          break;
        case displayState:
          display_state();
          break;
        case resetState:
          reset_state();
          break;
      }
    }
    // Gửi giá trị pressure mỗi 1 giây
    unsigned long currentMillis = millis();

    // Nếu phép đo đã hoàn thành, gửi SYS và DIA mỗi giây
    if (bpMeasured && (currentMillis - lastBpSendTime >= bpSendInterval)) {
      lastBpSendTime = currentMillis;
      sendBloodPressureData();
    }
}
//chuong trinh phuc vu ngat 
ISR (TIMER1_COMPA_vect) { 
  if (digitalRead(START_PIN)) timepress0++;
  else timepress0 = 0;
  timecount++;                      
  timedeflate++;
  //timing for sampling data at every 40 msec
  if (timing > 0) --timing; 
  //-----------------------------------------------------
  if (timerate < 6000) ++timerate;
  if (timerun_dias < 2000) ++timerun_dias;  
  //run time for the display
  if (timedisplay < 2000) ++timedisplay;   
}
void start_state(void) {   //Serial.println("start_state");
    sys_count=0;              
    pressure = 0;
    accum_data=0; 
    press_data=0; 
    count=0;
    stop_count=0; 
     
    maxpressure = 215; 
    meas_state = Sys_Measure; 
    former=TH_sys-0.01;

    timerun_dias=0;
    time_pulse=0;
    timerate=0;

    timing=40;

    total_pulse_period=0;
    systolic=0;
    diastolic=0;
    pulse_per_min=0;

    sys_count=0;
    count_average=0;
    countpulse=0;

  if((digitalRead(START_PIN)) && (timepress0 > 30)) {
    currentState = inflate2State;
    timepress0 = 0;  
    timecount = 0;
    bpMeasured = false;
    //turn on motor and close the valve
    digitalWrite(VALVE_PIN,off);
    digitalWrite(MOTOR_PIN,on);
  } 
}
void inflate2_state(void) {  
  pressure = readPressure(); 
  long data1 ;
  float adc_data11;
  data1 = readHX710B();
  adc_data11 = (((float)data1) / 8388607.0) * (5.0 );
  float adc_data1;
  adc_data1 = adc_data11 - 0.41 ; 
  pressure = ((adc_data1/128)/0.05*300);  
  
  if(pressure>=maxpressure) 
    stop_count++;   
  else 
    stop_count = 0;
    
  if(stop_count>=5){
    digitalWrite(MOTOR_PIN, off);
    delay(1000);
    currentState = deflateState;   
    timedeflate = 0;    
  }
}
void deflatestate(void) {                                         
  pressuremeasure();
}
void display_state(void) {   
  //if(timedisplay<=1000)
  if(timedisplay<=3000) {
    if(timecount>=200) {
      timecount=0;
      bpMeasured = true;
      // display_measurements();  // Gọi hàm hiển thị dữ liệu đo được
    } 
  }
  else if (timedisplay>1000 && timedisplay<3000) { 
    if(timecount>=200) 
      timecount=0;  
    else {
      timedisplay = 0;
      currentState = startState; // Thay vì dừng hẳn, chuyển lại để bắt đầu đo lại
    }   
  }
  else {
    timedisplay=0;
    currentState = stopState; // Chuyển sang trạng thái dừng
  } 
}
void reset_state(void) {   
  if(timedisplay<=1000)
  {
    if(timecount>=200)  
      timecount=0;
  }
  else if (timedisplay>1000 && timedisplay<2000) { 
    if(timecount>=200) { 
      //lcd.clear();
      timecount=0;      
    }  
  }
  else
    timedisplay=0;          
}
void pressuremeasure(void) {
  switch (meas_state) {
    case Sys_Measure:
      if (timing == 0) {
        sysmeasure(); // sampling signal at 40 msec
        //Serial.println("Sys_Measure executed");
      }
      break;
    case Sys_Cal:
      if (timing == 0) {
        syscal();
        //Serial.println("Sys_Cal executed");
      }
      break;
    case Rate_Measure:
      if (timing == 0) {
        ratemeasure();
        // Serial.println("Rate_Measure executed");
      }
      break;
    case dias_Measure:
      diasmeasure();
      //Serial.println("dias_Measure executed");
      break;
    case dias_Cal:
      diascal();
      //Serial.println("dias_Cal executed");
      break;
  }
}
void sysmeasure(void) {
  pressure = readPressure();
  pressure = pressure - 90;
  long data1;
  float adc_data11;
  data1 = readHX710B();
  delay(10);
  adc_data11 = (((float)data1) / 8388607.0) * (5.0);
  float adc_data1 ;
  adc_data1 = adc_data11 - 0.41;
  pressure = ((adc_data1/128)/0.05*300)-90; 
  // Serial.println(pressure);
  if(timing==0)
    read_adc(0);     
  if(sys_count>=2) { 
    meas_state = Sys_Cal;
    timecount=0;
  }  
  if(timecount>=200)
    timecount=0;
}
//***********************************************************
//this function is to calculate systolic pressure
void syscal(void)
{
  read_adc(1);
  if(timecount>=200)
    timecount=0; 
}//syscal
//************************************************************
void ratemeasure(void)
{
  read_adc(0);
    //calculate the mean of pulse rate
  if(count_average==2) {
    pulse_period = total_pulse_period/5000;
    pulse_per_min= 60/pulse_period;  
    meas_state = dias_Measure;
    //then set timerun_dias=0
    //also reset count_average for the next operation
    count_average=0;
    timerun_dias=0;
  }  
}
//************************************************************
void diasmeasure(void) {   
  pressure = readPressure();
  long data1;
  float adc_data11;
  read_adc(0); 
  data1 = readHX710B();
  adc_data11 = (((float)data1) / 8388607.0) * (5.0 );
  float adc_data1;
  adc_data1 =  adc_data11 - 0.41;
  pressure = ((adc_data1/128)/0.05*300);  
  if(timecount >= 200) timecount = 0;        
}//dias measure
//*************************************************************
void diascal(void) {
  //choose ADC1 for reading DC 
  read_adc(1);        
  if(timecount >= 200) timecount=0; 
}
void read_adc(int Channel) {
  switch (Channel) {
    case 0:
      data = readHX710B();
      break;
    case 1:
      data = readHX710B();
      break;
  }
  adc_data = (float)((((float)data)/8388607 * 5)-0.41);
 
 //if signal is above threshold, go to calculate systolic pressure
  if(meas_state == Sys_Measure) {   
    if( (former <= TH_sys && adc_data > TH_sys) || (former <= TH_sys2 && adc_data > TH_sys2) )
      sys_count++;             
    former = adc_data;            
  }
 //-----------------------------------------------------------
  else if(meas_state==Sys_Cal) {
    if(count<4) { 
      accum_data=accum_data+adc_data;
      count++;
    }
    if(count==4) {
      press_data=accum_data/4;
      systolic = (press_data/256)*6000 ;//calculate from adc_data
      meas_state = Rate_Measure; 
      //meas_state = dias_Measure;
      countpulse=0;
      former = 1.9; //set the initial point for rate measuring
      count_average=0;
    }
  }
  //----------------------------------------------------------
  else if (meas_state == Rate_Measure) {
    if (count_average <2 ) {
      if ((former < TH_rate && adc_data > TH_rate) 
        || (former < TH_rate2 && adc_data > TH_rate2)) {
        timerate=0;
        countpulse=1;
        former=adc_data;
        count_average++;
      }
    }//count_average 
    former=adc_data;
  }
  //-------------------------------------------------------------
  else if(meas_state==dias_Measure){    
    if(timerun_dias<2000) 
      if(adc_data>TH_dias) 
        timerun_dias=0; //reset time if the signal 
      
    if(timerun_dias>=2000) 
      meas_state = dias_Cal;
  }
  //------------------------------------------------------------- 
  else if(meas_state==dias_Cal) {     
    diastolic = (adc_data/256)*6000 ;//calculate from adc_data
    meas_state = Sys_Measure; 
    currentState = displayState;  
    //open valve
    digitalWrite(VALVE_PIN,on);
  }
  timing = 40;//set time for another conversion
}// end of read ADC

void sendBloodPressureData() {
  if (lastSentSystolic != systolic || lastSentDiastolic != diastolic){
    Serial.print("<SYS:");
    Serial.print(systolic, 2);
    Serial.print(",DIA:");
    Serial.print(diastolic, 2);
    Serial.println(">");
    lastSentSystolic = systolic;
    lastSentDiastolic = diastolic;
  }
}
float readPressure() {
    // Đọc giá trị từ cảm biến
    long data1 = readHX710B();
    float adc_data1 = (((float)data1) / 8388607.0) * (5.0) - 0.41;
    return ((adc_data1 / 128) / 0.05 * 300);
}

void receiveCommandFromESP() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    command.trim();

    if (command != lastCommand) {
      lastCommand = command; 

      if (command == "START_ATMEGA328P") {
        if (!isRemoteRunning) {
          toggleRemoteMotor();
          bpMeasured = false; 
        }
      } else if (command == "STOP_ATMEGA328P") {
        if (isRemoteRunning) {
          toggleRemoteMotor();
        }
      }
    }
  }
}

void togglePhysicalMotor() {
  if (isPhysicalRunning) {
    // Dừng hệ thống điều khiển từ nút nhấn vật lý
    isPhysicalRunning = false;
    currentState = resetState;
    digitalWrite(MOTOR_PIN, off);
    digitalWrite(VALVE_PIN, on); // Xả khí
  } else {
    // Bắt đầu hệ thống điều khiển từ nút nhấn vật lý
    isPhysicalRunning = true;
    currentState = startState;
    digitalWrite(VALVE_PIN, off);
    digitalWrite(MOTOR_PIN, on);
  }
}

void toggleRemoteMotor() {
  if (isRemoteRunning) {
    // Dừng hệ thống điều khiển từ điện thoại
    isRemoteRunning = false;
    currentState = resetState;
    digitalWrite(MOTOR_PIN, off);
    digitalWrite(VALVE_PIN, on); // Xả khí
  } else {
    // Bắt đầu hệ thống điều khiển từ điện thoại
    isRemoteRunning = true;
    digitalWrite(VALVE_PIN, off);
    digitalWrite(MOTOR_PIN, on);
    currentState = inflate2State; 
  }
}