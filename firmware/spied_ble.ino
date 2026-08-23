#include <Arduino.h>

#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

#define DEVICE_NAME "SPIED_ESP32"

#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define RX_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define TX_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// Change these two values if your LEDs are wired to different GPIO pins.
#define LIGHT_LED_PIN 4
#define MICROWAVE_LED_PIN 5

BLECharacteristic* txCharacteristic = nullptr;
bool deviceConnected = false;

void sendResponse(const String& message) {
  if (!deviceConnected || txCharacteristic == nullptr) {
    return;
  }

  txCharacteristic->setValue(message.c_str());
  txCharacteristic->notify();

  Serial.print("ESP32 -> Flutter: ");
  Serial.println(message);
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) override {
    deviceConnected = true;
    Serial.println("BLE client connected.");
  }

  void onDisconnect(BLEServer* server) override {
    deviceConnected = false;
    Serial.println("BLE client disconnected.");
    server->startAdvertising();
  }
};

class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    String command = characteristic->getValue();
    command.trim();

    Serial.print("Flutter -> ESP32: ");
    Serial.println(command);

    if (command == "PING") {
      sendResponse("PONG");
    } else if (command == "LIGHT_ON") {
      digitalWrite(LIGHT_LED_PIN, HIGH);
      sendResponse("LIGHT_ON_OK");
    } else if (command == "LIGHT_OFF") {
      digitalWrite(LIGHT_LED_PIN, LOW);
      sendResponse("LIGHT_OFF_OK");
    } else if (command == "MICROWAVE_ON") {
      digitalWrite(MICROWAVE_LED_PIN, HIGH);
      sendResponse("MICROWAVE_ON_OK");
    } else if (command == "MICROWAVE_OFF") {
      digitalWrite(MICROWAVE_LED_PIN, LOW);
      sendResponse("MICROWAVE_OFF_OK");
    } else {
      sendResponse("ERROR");
    }
  }
};

void setup() {
  Serial.begin(115200);

  pinMode(LIGHT_LED_PIN, OUTPUT);
  pinMode(MICROWAVE_LED_PIN, OUTPUT);
  digitalWrite(LIGHT_LED_PIN, LOW);
  digitalWrite(MICROWAVE_LED_PIN, LOW);

  BLEDevice::init(DEVICE_NAME);

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(SERVICE_UUID);

  txCharacteristic = service->createCharacteristic(
    TX_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  txCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic* rxCharacteristic = service->createCharacteristic(
    RX_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  rxCharacteristic->setCallbacks(new RxCallbacks());

  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();

  Serial.println("SPIED ESP32 BLE started.");
}

void loop() {
  delay(100);
}
