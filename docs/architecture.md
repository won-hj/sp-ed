# Architecture

```text
Android camera
  -> CameraService
  -> WakeDetector (MoveNet Lightning)
  -> three consecutive AWAKE results
  -> MorningRoutinePage
       1. TtsService: GOOD MORNING MASTER
       2. WeatherService: location -> Open-Meteo -> TTS briefing
       3. BleService: MICROWAVE_ON -> wait for ACK
       4. BleService: LIGHT_ON -> wait for ACK
  -> ESP32 firmware
  -> GPIO 5 microwave indicator / GPIO 4 room light
```

The current app intentionally keeps orchestration in one page so the prototype is easy to follow and debug. Service classes isolate camera, inference, weather, speech, and BLE details.

The future GPT API should be inserted between `WeatherService` and `TtsService`. The model should compose a short script from structured context; it should not directly control GPIO commands.
