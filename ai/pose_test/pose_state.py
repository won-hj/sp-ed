import cv2
import numpy as np

from ai_edge_litert.interpreter import Interpreter


MODEL_PATH = "models/movenet_lightning.tflite"
INPUT_SIZE = 192

KEYPOINT_THRESHOLD = 0.30

LEFT_SHOULDER = 5
RIGHT_SHOULDER = 6
LEFT_HIP = 11
RIGHT_HIP = 12


interpreter = Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()


def run_movenet(image):
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    h, w = image_rgb.shape[:2]

    scale = INPUT_SIZE / max(h, w)

    new_w = int(w * scale)
    new_h = int(h * scale)

    resized = cv2.resize(image_rgb, (new_w, new_h))

    canvas = np.zeros(
        (INPUT_SIZE, INPUT_SIZE, 3),
        dtype=np.uint8,
    )

    x_offset = (INPUT_SIZE - new_w) // 2
    y_offset = (INPUT_SIZE - new_h) // 2

    canvas[
        y_offset:y_offset + new_h,
        x_offset:x_offset + new_w
    ] = resized

    input_tensor = np.expand_dims(canvas, axis=0)

    interpreter.set_tensor(
        input_details[0]["index"],
        input_tensor,
    )

    interpreter.invoke()

    output = interpreter.get_tensor(
        output_details[0]["index"]
    )

    return output[0, 0]


def midpoint(a, b):
    return np.array([
        (a[0] + b[0]) / 2.0,
        (a[1] + b[1]) / 2.0,
    ])


def classify_pose(keypoints):
    ls = keypoints[LEFT_SHOULDER]
    rs = keypoints[RIGHT_SHOULDER]
    lh = keypoints[LEFT_HIP]
    rh = keypoints[RIGHT_HIP]

    scores = [
        ls[2],
        rs[2],
        lh[2],
        rh[2],
    ]

    if min(scores) < KEYPOINT_THRESHOLD:
        return "UNKNOWN", 0.0

    shoulder = midpoint(ls, rs)
    hip = midpoint(lh, rh)

    dy = abs(hip[0] - shoulder[0])
    dx = abs(hip[1] - shoulder[1])

    verticality = dy / (dx + dy + 1e-6)

    if verticality >= 0.65:
        state = "AWAKE"

    elif verticality <= 0.35:
        state = "SLEEPING"

    else:
        state = "UNKNOWN"

    return state, verticality


def main():
    image = cv2.imread("test_images/lying.jpg")

    if image is None:
        print("Image not found.")
        return

    keypoints = run_movenet(image)

    state, verticality = classify_pose(keypoints)

    print("State:", state)
    print("Verticality:", verticality)


if __name__ == "__main__":
    main()