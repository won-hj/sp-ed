sp-ed/
│
├── app/
│   ├── lib/
│   │   ├── main.dart
│   │   │
│   │   ├── core/
│   │   │   └── protocol/
│   │   │       ├── ble_constants.dart
│   │   │       └── device_command.dart
│   │   │
│   │   ├── services/
│   │   │   ├── ble_service.dart
│   │   │   ├── speech_service.dart
│   │   │   ├── tts_service.dart
│   │   │   ├── camera_service.dart
│   │   │   └── wake_classifier.dart
│   │   │
│   │   ├── controllers/
│   │   │   ├── device_controller.dart
│   │   │   ├── voice_command_controller.dart
│   │   │   └── wake_monitor_controller.dart
│   │   │
│   │   └── screens/
│   │       └── home_page.dart
│   │
│   ├── assets/
│   │   └── models/
│   │       ├── wake_classifier.tflite
│   │       └── labels.txt
│   │
│   └── pubspec.yaml
│
├── firmware/
│   └── spied_ble/
│       └── spied_ble.ino
│
├── ai/
│   ├── dataset/
│   │   ├── lying/
│   │   └── up/
│   └── README.md
│
├── docs/
│   ├── architecture.md
│   ├── ble_protocol.md
│   └── open_source.md
│
└── README.md