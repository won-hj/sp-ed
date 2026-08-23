# SP!ED Morning

Android-only Flutter prototype for an AI-coordinated morning routine.

## Current demo flow

1. The front camera runs MoveNet Lightning every 600 ms.
2. Three consecutive `AWAKE` results trigger the routine. `RUN DEMO NOW` can also trigger it manually.
3. Android TTS says `GOOD MORNING MASTER`.
4. The app gets the phone's current location and requests today's weather from Open-Meteo.
5. TTS briefs the current temperature, humidity, and today's maximum precipitation probability.
6. The app sends `MICROWAVE_ON` to `SPIED_ESP32` and waits for `MICROWAVE_ON_OK`.
7. One second later, it sends `LIGHT_ON` and waits for `LIGHT_ON_OK`.

If location permission or GPS is unavailable, weather falls back to Seoul coordinates. Open-Meteo does not require an API key.

## Android setup

```bash
flutter pub get
flutter run
```

Grant Camera, Nearby devices, and Location permissions when Android asks. Turn on Bluetooth and flash `firmware/spied_ble.ino` to the ESP32 before starting the full hardware demo.

## ESP32 demo wiring

| Demo output | Default GPIO |
| --- | ---: |
| Room light LED | 4 |
| Microwave indicator LED | 5 |

Change `LIGHT_LED_PIN` and `MICROWAVE_LED_PIN` in the firmware if your board uses different pins. Use a resistor with each external LED.

## Wake detection

MoveNet estimates shoulder and hip keypoints. The app treats the upper body as awake when its shoulder-to-hip line is sufficiently vertical. It requires three consecutive awake frames to reduce one-frame false triggers.

This is a prototype heuristic, not a medical or production-grade sleep detector.

## Future GPT briefing

`WeatherService` currently returns structured values and a deterministic English briefing. A future GPT integration should send only the required weather and schedule fields to a backend, receive a short script, then pass that script to `TtsService.speak()`. Do not embed an OpenAI API key directly in the Android app.

## Main files

- `lib/screens/morning_routine_page.dart`: wake monitoring, UI, and routine orchestration
- `lib/services/wake_detector.dart`: MoveNet inference and posture heuristic
- `lib/services/weather_service.dart`: location and Open-Meteo request
- `lib/services/ble_service.dart`: BLE scan, connection, commands, and ACK handling
- `lib/services/tts_service.dart`: sequential Android TTS
- `firmware/spied_ble.ino`: ESP32 BLE server and GPIO outputs
