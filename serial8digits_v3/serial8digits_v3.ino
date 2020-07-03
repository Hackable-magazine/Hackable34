#include <SPI.h>
/*
  gnd  |o o|  data
       |o o   latch
  vcc  |o o|  clock
 */

#define PLAT  10  // latch pin (ST_CP) of 74HC595
#define PCLK  13  // clock pin (SH_CP) of 74HC595
#define PDATA 11  // Data in (DS) of 74HC595

//                            "0"  "1"  "2"  "3"  "4"  "5"  "6"  "7"  "8"  "9"
//                             c0   f9   a4   b0   99   92   82   f8   80   90
unsigned char chiffres[10] = {192, 249, 164, 176, 153, 146, 130, 248, 128, 144};

void sendsingle(unsigned char data) {
  digitalWrite(PLAT, LOW);
  //SPI.transfer(data);
  //shiftOut(PDATA, PCLK, MSBFIRST, data);
  digitalWrite(PLAT, HIGH);  
}

void sendnsym(unsigned char *data, int len) {
  digitalWrite(PLAT, LOW);
  for(int i=0; i<len; i++) {
    SPI.transfer(data[i]);
  }
  digitalWrite(PLAT, HIGH);  
}

// obligé implémenter notre 10^x car pow() retourne du double et ne fonctionne pas avec du int
long pow10(int expo) {
  unsigned long ret = 1;
  for(int i=1; i<=expo; i++) {
    ret = ret * 10;
  }
  return(ret);
}

void sendnum(unsigned long val, int len) {
  unsigned char *data = NULL;
  
  if(len<=0)
    return;

  if((data = malloc(len)) == NULL) {
    Serial.println("Erreur malloc!");
    return;
  }

  for(int i=0;i<len;i++)
    data[i]=chiffres[(val%pow10(i+1))/pow10(i)];

  sendnsym(data,len);
  free(data);
}

void sendnum(long val, int len, unsigned char pref) {
  unsigned char *data = NULL;
  int nbr = 0;

  if(len<=0)
    return;
  if((data = malloc(len)) == NULL) {
    Serial.println("Erreur malloc!");
    return;
  }

  while(val-pow10(nbr) > 0)
    nbr++;

  for(int i=0;i<len;i++) {
    if(i<nbr)
      data[i]=chiffres[(val%pow10(i+1))/pow10(i)];
    else
      data[i]=pref;
  }
  sendnsym(data,len);
  free(data);
}

void setup() {
  digitalWrite(PLAT, HIGH);
  pinMode(PLAT, OUTPUT);
  pinMode(PDATA, OUTPUT);
  pinMode(PCLK, OUTPUT);

  SPI.beginTransaction(SPISettings(20000000, MSBFIRST, SPI_MODE0));
  
  Serial.begin(115200);
  Serial.println("reset");

  randomSeed(analogRead(0));
  
  sendnum(543,8,247);
  //sendnum(1234,8);
}

void loop() {
  //sendnum(random(100000000),8);
  delay(75);
}
