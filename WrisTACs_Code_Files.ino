#include <SoftwareSerial.h>

SoftwareSerial bt(2, 3); //RX, TX
int count = 0;
int sent = 0;
String toBT;
String fromBT;

const int analogInpin=A0;//analog input pin
int sensorValue=0; //Value read from the pin

void setup() {
  // open serial port
  Serial.begin(9600);
  Serial.println("LABEL,Time, Registered Value");
  // begin bluetooth serial port communication
  bt.begin(9600);
  delay(100);
}

void loop() {
  //Serial.println("Sending Bluetooth Message..."); //Print to monitor
  bt.print(sensorValue); //Use for variables
  delay(1000); 
  //read the analog value;
  sensorValue=analogRead(analogInpin);
  //print the results to the serial monitor:
  Serial.print("DATA, TIME, ");
  Serial.println(sensorValue);
  delay(100);  
}
