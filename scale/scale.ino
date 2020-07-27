/* Code for Smart Scale by Colton Williams
  Requires HX711, SD, SSD1306 OLED, Energy Shield, and RTC libraries pre installed

  Recipes are stored as followed:
  ~ Each recipe has its own .txt file, starting with 1.txt, with a max of 8 recipes
  ~ Each file starts with TITLE_my title
  ~ Instructions or non-weight amounts can use INST_my instruction
  ~ Weighted amounts can be written as WEIGHT_integer_my food, where integer is in grams
  ~ A '#' marks the end of the recipe
  ~ Use '/' to separate steps
  ~ Eample:

          TITLE_cookies/INST_get cookie dough/WEIGHT_200_cookie dough/INST_bake and enjoy/#
*/




// importing libraries and defining constants for the OLED
#include "HX711.h"
#include <SPI.h>
#include <Wire.h>
#include "SdFat.h"
#include "SSD1306Ascii.h"
#include "SSD1306AsciiWire.h"
#include <SoftwareSerial.h>
#include <NS_energyShield.h>
#include <RTClib.h>
#define I2C_ADDRESS 0x3C
#define RST_PIN -1
#define DOUT  6
#define CLK  2

// instantiating classes for OLED, sd card, etc
SSD1306AsciiWire oled;
SdFat SD;
File myFile;
HX711 scale;
SoftwareSerial bleSerial(8, 7);
NS_energyShield eS;
RTC_DS1307 rtc;

// defining global variables, including an array for recipe titles, file paths, and button states
char recipeArray[10][20];
char file[7] = "";
String line = "";
float calibration_factor = -184000;
const int button1 = 5;
const int button2 = 3;
const int button3 = 9;
int numRecipes;
int fileNum = 1;
int button1State = 0;
int button2State = 0;
int button3State = 0;
int weight = 0;
int weight2 = 0;
int bat;


// function to reset the arduino via software
void(* resetFunc) (void) = 0;

void setup() {
  // serial for debugging
  Serial.begin(115200);

  // button inputs
  pinMode(button1, INPUT);
  pinMode(button2, INPUT);
  pinMode(button3, INPUT);
  Wire.begin();
  Wire.setClock(400000L);
  rtc.begin();
  oled.begin(&Adafruit128x64, I2C_ADDRESS);
  oled.setFont(System5x7);

  // start the scale and power it down until use
  scale.begin(DOUT, CLK);
  scale.set_scale(calibration_factor);
  scale.tare();
  scale.power_down();

  // declare the SD at pin 10
  if (!SD.begin(10)) {
    oled.clear();
    oled.setRow(1);
    oled.setCol(1);
    oled.print(F("SD card failed"));
    while (1);
  }

  // get the current titles on the SD card
  getTitles();
  delay(500);
}


void loop() {
  // show menu for choosing recipes
  chooseRecipe();

  // play the chosen recipe
  playRecipe();
}

void chooseRecipe() {
  // add a scale and edit option to the array to chose from
  strcpy(recipeArray[numRecipes], "scale");
  strcpy(recipeArray[numRecipes + 1], "edit recipes");
  fileNum = 1;
  int minute;

  // only 5 recipes can be shown at a time, so chose the minimum
  int recipesToDisplay = min(5, numRecipes + 2);

  // get the current time
  DateTime now = rtc.now();
  hour = now.hour();
  minute = now.minute();
  oled.clear();

  // rotate the OLED
  oled.displayRemap(true);
choose:
  Serial.println(fileNum);
  delay(500);

  // print the time
  oled.clear();
  oled.setRow(0);
  oled.setCol(50);
  if (hour > 12) {
    hour -= 12;
  }
  oled.print(hour);
  oled.print(":");
  if (minute < 10) {
    oled.print("0");
  }
  oled.print(minute);

  // print battery percent
  bat = (int) eS.percent() / 2;
  oled.setCol(110);
  oled.print(bat);
  oled.print(F("%"));

  // print the options from the array, with an offset of the variable fileNum
  for (int i = 0; i < recipesToDisplay; i++) {
    oled.setRow(i + 1);
    oled.setCol(0);
    if (i == 0) {
      oled.print(F("* "));
      oled.print(recipeArray[(fileNum - 1)]);
    } else {
      oled.print(F("  "));
      if (((fileNum - 1) + i) >= (numRecipes + 2)) {
        oled.print(recipeArray[((fileNum - 1) + i) - (numRecipes + 2)]);
      } else {
        oled.print(recipeArray[(fileNum - 1) + i]);
      }
    }
  }

  // print labels for buttons
  oled.setRow(7);
  oled.setCol(5);
  oled.print(F("back"));
  oled.setCol(45);
  oled.print(F("select"));
  oled.setCol(100);
  oled.print(F("next"));

  while (1) {
    button1State = digitalRead(button1);
    button2State = digitalRead(button2);
    button3State = digitalRead(button3);

    // next chosen, advance by one
    if (button3State == HIGH) {
      if (recipeArray[fileNum][0] != 0) {
        fileNum++;
      } else {
        fileNum = 1;
      }
      goto choose;
    }

    // back chosen, go back by one
    if (button1State == HIGH) {
      if (fileNum > 1) {
        fileNum--;
      } else {
        fileNum = numRecipes + 2;
      }
      goto choose;
    }

    // current option selected, break and play recipe
    if (button2State == HIGH) {
      break;
    }
    delay(1);
  }
}

void playRecipe() {
  Serial.println("playing");
  Serial.println(fileNum);

  // scale option chosen
  if (fileNum == numRecipes + 1) {
    generalScale();
  }
  // edit recipes option chosen
  else if (fileNum == numRecipes + 2) {
    editRecipes();
  }

  // regular recipe chosen
  else {
    String Step = "";
    String targetWeight = "";
    int count = 0;

    // # marks end of a recipe
    while (Step.indexOf(F("#")) == -1) {

      // get the step based on the number and recipe
      Step = openRecipe(fileNum, count);

      // show title
      if (count == 0) {
        Step.remove(0, 6);
        oled.clear();
        oled.setRow(2);
        oled.setCol(10);
        oled.print(Step);
        oled.setRow(7);
        oled.setCol(100);
        oled.print(F("next"));
        delay(1000);

        // wait till next pressed
        while (1) {
          button3State = digitalRead(button3);
          if (button3State == HIGH) {
            count++;
            break;
          }
          delay(1);
        }
      }

      // if the step is an instruction step
      if (Step.indexOf(F("INST_")) == 0) {
        Step.remove(0, 5);
        oled.clear();
        oled.setRow(0);
        oled.setCol(10);

        // if the instruction is too long split it up and print
        if (Step.length() > 19) {
          String Step2 = Step.substring(Step.lastIndexOf(F(" "), 18) + 1, Step.length());
          Step.remove(Step.lastIndexOf(F(" "), 18), Step.length());
          oled.print(Step);
          oled.setRow(1);
          oled.setCol(10);
          oled.print(Step2);
        } else {
          oled.print(Step);
        }

        // print the step number and button labels
        oled.setRow(5);
        oled.setCol(10);
        oled.print(F("step "));
        oled.print(count);
        oled.setRow(7);
        oled.setCol(5);
        oled.print(F("back"));
        oled.setCol(100);
        oled.print(F("next"));
        delay(1000);

        // wait until back or next pressed
        while (1) {
          button1State = digitalRead(button1);
          button3State = digitalRead(button3);
          if (button1State == HIGH) {
            count--;
            break;
          }
          if (button3State == HIGH) {
            count++;
            break;
          }
          delay(1);
        }
      }

      // if the step is a weight step
      if (Step.indexOf(F("WEIGHT_")) == 0) {
        // turn on the scale
        scale.power_up();
        scale.tare();
        int weight = 0;
        int weight2 = 0;
        int equal = 0;
        Step.remove(0, 7);
        targetWeight = Step.substring(0, Step.indexOf('_'));
        Step.remove(0, Step.indexOf('_') + 1);

        // print the step, step number, and expected weight
        oled.clear();
        oled.setRow(0);
        oled.setCol(10);
        oled.print(Step);
        oled.setRow(2);
        oled.setCol(10);
        oled.print(targetWeight + F("g"));
        oled.setRow(5);
        oled.setCol(10);
        oled.print(F("step "));
        oled.print(count);

        // print the current weight and button labels
        oled.set2X();
        oled.setRow(3);
        oled.setCol(72);
        oled.print(weight);
        oled.set1X();
        oled.setRow(7);
        oled.setCol(5);
        oled.print(F("back"));
        oled.setCol(50);
        oled.print(F("zero"));
        oled.setCol(100);
        oled.print(F("next"));
        oled.set2X();
        delay(1000);
        while (1) {
          button1State = digitalRead(button1);
          button2State = digitalRead(button2);
          button3State = digitalRead(button3);

          // back pressed, go back one step
          if (button1State == HIGH) {
            if (count > 0) {
              count--;
            }
            oled.set1X();
            scale.power_down();
            break;
          }

          // zero pressed, tare scale
          if (button2State == HIGH) {
            scale.tare();
          }

          // next pressed, advance
          if (button3State == HIGH) {
            count++;
            oled.set1X();
            scale.power_down();
            break;
          }

          // keep updating weight
          printWeight();

          // if the current weight is the target, advance to next step
          if (abs(weight - targetWeight.toInt()) < 3) {
            equal++;
          }
          if (equal > 15) {
            oled.setRow(7);
            oled.set1X();
            for (int i = 1; i < 3; i++) {
              oled.setCol(100);
              oled.print(F("    "));
              delay(300);
              oled.setCol(100);
              oled.print(F("next"));
              delay(300);
            }
            count++;
            scale.power_down();
            break;
          }
          delay(50);
        }
      }
    }

    // recipe finished, print done and return to selection
    oled.clear();
    oled.setRow(0);
    oled.setCol(10);
    oled.print(F("done!"));
    delay(1500);
  }
  Serial.println(F("done!"));
}

void generalScale() {
  // turn on the scale, print weight and button labels
  scale.power_up();
  scale.tare();
  oled.clear();
  oled.set2X();
  oled.setRow(3);
  oled.setCol(72);
  oled.print(weight);
  oled.set1X();
  oled.setRow(7);
  oled.setCol(5);
  oled.print(F("back"));
  oled.setCol(50);
  oled.print(F("zero"));
  oled.set2X();
  while (1) {
    button1State = digitalRead(button1);
    button2State = digitalRead(button2);
    button3State = digitalRead(button3);

    // back pressed, reset arduino to go back to selection
    if (button1State == HIGH) {
      resetFunc();
    }

    // zero pressed, tare scale
    if (button2State == HIGH) {
      scale.tare();
    }

    // keep updating weight
    printWeight();
  }
}

void editRecipes() {
  // begin software serial
  bleSerial.begin(9600);

  // print for user to pair and add button labels
  oled.clear();
  oled.setRow(2);
  oled.setCol(30);
  oled.print(F("pair on app"));
  oled.setRow(7);
  oled.setCol(5);
  oled.print(F("back"));
  String msg;

  // ask app if already connected
  bleSerial.println(F("CONN?"));
  while (1) {
    if (bleSerial.available()) {
      msg = bleSerial.readString();
    }

    // connected to app
    if (msg == "CONN") {
      bleSerial.println(F("CONN"));
      break;
    }

    // back pressed, go back to selection
    button1State = digitalRead(button1);
    if (button1State == HIGH) {
      getTitles();
      goto Exit;
    }
  }
  oled.clear();
  oled.setRow(2);
  oled.setCol(40);
  oled.print(F("connected"));
  oled.setRow(7);
  oled.setCol(5);
  oled.print(F("back"));

  // print the array of recipes to the app
  bleSerial.print(F("TITLES_"));
  for (int i = 0; i < numRecipes; i++) {
    bleSerial.print(recipeArray[i]);
    bleSerial.print("_");
  }
  bleSerial.print("#");
  while (1) {
    if (bleSerial.available()) {
      msg = bleSerial.readString();

      // app reconnected, re-print recipes
      if (msg.indexOf("CONN") > -1) {
        bleSerial.print(F("TITLES_"));
        for (int i = 0; i < numRecipes; i++) {
          bleSerial.print(recipeArray[i]);
          bleSerial.print(F("_"));
        }
        bleSerial.print(F("#"));

        // app sending recipe to add
      } else if (msg.indexOf("ADD") > -1) {
        addRecipe();
      }

      // app sending recipe number to delete
      else if (msg.indexOf("DELETE") > -1) {
        deleteRecipe(msg);
      }
    }
    button1State = digitalRead(button1);

    // back pressed, go back to selection and tell app
    if (button1State == HIGH) {
      bleSerial.print(F("EXIT"));
      delay(100);
      getTitles();
      break;
    }
  }
Exit:
  delay(50);
}


// get current weight and print it if it is different than the previous
void printWeight() {
  weight2 = scale.get_units() * 453.592;
  if (abs(weight - weight2) > 1) {
    weight = scale.get_units() * 453.592;
    oled.setRow(3);
    oled.setCol(71);
    oled.print(F("     "));
    oled.setRow(3);
    oled.setCol(72);
    oled.print(weight);
  }
}

// go through all recipes on the SD card, add the titles to recipeArray
void getTitles() {
  int i = 1;
  file[0] = '\0';
  // start with '1.txt'
  strcat(file, "1.txt");
  Serial.println(file);
  line = "";
  char line1[20] = "";
  line1[0] = '\0';

  // do until there are no more recipe files
  while (SD.exists(file)) {
    Serial.println("test2");
    myFile = SD.open(file);
    if (file) {
      while (myFile.available()) {
        char ltr = myFile.read();

        // read until first '/'
        if (ltr == '/') {
          break;
        }
        line += ltr;
      }
      myFile.close();
    } else {
      Serial.println(F("error opening file"));
    }
    line.replace(F("TITLE_"), "");
    line.toCharArray(line1, 20);

    // add the title to the array
    strcpy(recipeArray[i - 1], line1);

    // change the file path to the next file
    i++;
    line = "";
    file[0] = '\0';
    itoa(i, line1, 10);
    strcat(file, line1);
    strcat(file, ".txt");
    line1[0] = '\0';
  }

  // remember the number of recipes
  numRecipes = i - 1;
  Serial.println(numRecipes);
}

// open a recipe based on file and step numbers
String openRecipe(int recipeNum, int Step) {
  // set the file path and open
  file[0] = '\0';
  itoa(recipeNum, file, 10);
  strcat(file, ".txt");
  Serial.println(file);
  myFile = SD.open(file);
  line = "";
  int count = 0;
  if (myFile) {
    while (myFile.available()) {
      char ltr = myFile.read();

      // go through recipe until step found, add it to line
      if (ltr == '/' && count < Step) {
        count++;
      } else if (ltr == '/' && count >= Step) {
        break;
      } else if (count >= Step) {
        line += ltr;
      } else if (ltr == '#') {
        line = F("#");
        break;
      }
    }
    myFile.close();
  } else {
    Serial.println(F("error opening file"));
  }
  return line;
}


// add a recipe to the SD card
void addRecipe() {
  // increase number of recipes and get file path
  numRecipes += 1;
  file[0] = '\0';
  itoa(numRecipes, file, 10);
  strcat(file, ".txt");
  SD.remove(file);
  
  // tell app ready to receive recipe
  bleSerial.println(F("READY"));
  String recipe = "";

  // add received steps to file
  while (recipe.indexOf(F("#")) == -1) {
    recipe = "";
    if (bleSerial.available()) {
      recipe = "";
      recipe = bleSerial.readStringUntil('\n');
      myFile = SD.open(file, FILE_WRITE);
      if (myFile) {
        myFile.print(recipe);
        myFile.close();
      } else {
        bleSerial.println(F("FAILED"));
        numRecipes -= 1;
      }
    }
    bleSerial.flush();
  }

  // finish with '#' to card
  myFile = SD.open(file, FILE_WRITE);
  if (myFile) {
    myFile.print(F("#"));
    myFile.close();
  } else {
    bleSerial.println(F("FAILED"));
    numRecipes -= 1;
  }

  // tell app adding was successful
  bleSerial.println(F("SUCCESS"));
}

// delete recipe from SD card
void deleteRecipe(String recipe) {

  // get file path of recipe
  recipe.remove(0, 7);
  fileNum = recipe.toInt();
  file[0] = '\0';
  int file2;
  line = "";

  // delete the recipe
  // if recipe is not the most recently added, shift the following recipes to keep them in order
  for (int j = fileNum; j <= numRecipes; j++) {
    file2 = j + 1;
    itoa(j, file, 10);
    strcat(file, ".txt");
    SD.remove(file);
    if (fileNum == numRecipes) {
      break;
    }
    int count = 0;
    while (line.indexOf(F("#")) == -1) {
      line = openRecipe(file2, count);
      myFile = SD.open(file, FILE_WRITE);
      if (myFile) {
        myFile.print(line);
        myFile.print(F("/"));
        myFile.close();
      } else {
        Serial.println(F("delete error"));
      }
      if (count > 20) {
        break;
      }
      myFile.close();
      count++;
    }
    myFile = SD.open(file, FILE_WRITE);
    if (myFile) {
      myFile.print(F("#"));
      myFile.close();
    } else {
      Serial.println(F("delete error"));
    }
    line = "";
  }

  // adjust the number of recipes and tell the app it was successful
  numRecipes--;
  bleSerial.println(F("SUCCESS"));
}
