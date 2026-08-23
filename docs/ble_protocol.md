# BLE protocol

Device name: `SPIED_ESP32`

| Direction | UUID |
| --- | --- |
| Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` |
| Android -> ESP32 (RX) | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` |
| ESP32 -> Android notify (TX) | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` |

| Command | Successful response | Firmware behavior |
| --- | --- | --- |
| `PING` | `PONG` | Communication check |
| `LIGHT_ON` | `LIGHT_ON_OK` | GPIO 4 HIGH |
| `LIGHT_OFF` | `LIGHT_OFF_OK` | GPIO 4 LOW |
| `MICROWAVE_ON` | `MICROWAVE_ON_OK` | GPIO 5 HIGH |
| `MICROWAVE_OFF` | `MICROWAVE_OFF_OK` | GPIO 5 LOW |

Unknown commands return `ERROR`. The Flutter app waits for the exact command-specific response before marking a routine step complete.
