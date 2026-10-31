#include <Arduino.h>
#include <ESP32Servo.h>

// Servo pin as connected in the smart home system
#define PIN_SERVO 13

Servo myServo;

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n========================================");
  Serial.println("       ESP32 SERVO MOTOR TEST           ");
  Serial.println("========================================");
  Serial.printf("Signal Pin: GPIO %d\n", PIN_SERVO);
  Serial.println("Standard 50Hz PWM, 544us - 2400us pulse width.");
  Serial.println("Type an angle (0-180) in Serial Monitor to set position.");
  Serial.println("========================================\n");

  // Allocate all 4 PWM timers for ESP32Servo
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  myServo.setPeriodHertz(50); // Standard 50Hz servo
  myServo.attach(PIN_SERVO, 544, 2400); // Standard micro-servo range (SG90 / MG90S / MG996R)

  Serial.println("[TEST] Step 1: Moving to 0° (Closed/Locked position)...");
  myServo.write(0);
  delay(2000);

  Serial.println("[TEST] Step 2: Moving to 90° (Door Open position)...");
  myServo.write(90);
  delay(2000);

  Serial.println("[TEST] Step 3: Moving back to 0° (Door Closed position)...");
  myServo.write(0);
  delay(2000);

  Serial.println("\n[TEST] Beginning continuous sweep test (0° <-> 90° <-> 180°)...");
}

int currentAngle = 0;
int sweepDirection = 1;
unsigned long lastSweepStepMs = 0;
const int SWEEP_SPEED_MS = 15; // lower = faster, higher = slower & smoother

void loop() {
  // Check for serial input for manual angle commands
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.length() > 0) {
      int targetAngle = input.toInt();
      targetAngle = constrain(targetAngle, 0, 180);
      Serial.printf("[MANUAL] Moving servo to %d°...\n", targetAngle);
      myServo.write(targetAngle);
      currentAngle = targetAngle;
      delay(500);
    }
  }

  // Smooth back-and-forth sweep test
  if (millis() - lastSweepStepMs >= SWEEP_SPEED_MS) {
    lastSweepStepMs = millis();

    currentAngle += sweepDirection;
    if (currentAngle >= 90) { // sweeping up to 90° (door travel range)
      sweepDirection = -1;
      Serial.printf("[SWEEP] Reached 90° (OPEN). Reversing to 0°...\n");
      delay(1000); // pause at open
    } else if (currentAngle <= 0) {
      sweepDirection = 1;
      Serial.printf("[SWEEP] Reached 0° (CLOSED). Reversing to 90°...\n");
      delay(1000); // pause at closed
    }

    myServo.write(currentAngle);
  }
}
