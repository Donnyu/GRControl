import asyncio
import ctypes
import io
import json
import logging
import os
import socket
import sys
import threading
import mss
from PIL import Image, ImageDraw
import pyautogui
import websockets

pyautogui.PAUSE = 0
pyautogui.FAILSAFE = False

# Настройка логирования
logging.basicConfig(
    level=logging.INFO, format="[%(asctime)s] %(message)s", datefmt="%H:%M:%S"
)

connected_clients = set()
show_logs = True


def get_local_ips():
    """Получение всех локальных IP-адресов компьютера"""
    ips = []
    try:
        host_name = socket.gethostname()
        for ip in socket.gethostbyname_ex(host_name)[2]:
            if not ip.startswith("127."):
                ips.append(ip)
    except Exception:
        pass
    return ips


async def stream_screen():
    """Фоновая трансляция экрана"""
    with mss.mss() as sct:
        monitor = sct.monitors[1]
        while True:
            if connected_clients:
                try:
                    sct_img = sct.grab(monitor)
                    img = Image.frombytes(
                        "RGB", sct_img.size, sct_img.bgra, "raw", "BGRX"
                    )

                    orig_w, orig_h = img.size
                    img.thumbnail((960, 540))
                    new_w, new_h = img.size

                    # Отрисовка курсора мыши
                    cur_x, cur_y = pyautogui.position()
                    scaled_x = int((cur_x - monitor["left"]) * (new_w / orig_w))
                    scaled_y = int((cur_y - monitor["top"]) * (new_h / orig_h))

                    draw = ImageDraw.Draw(img)
                    r = 6
                    draw.ellipse(
                        [
                            scaled_x - r,
                            scaled_y - r,
                            scaled_x + r,
                            scaled_y + r,
                        ],
                        fill="red",
                        outline="white",
                        width=2,
                    )

                    buffer = io.BytesIO()
                    img.save(buffer, format="JPEG", quality=50)
                    frame_bytes = buffer.getvalue()

                    websockets.broadcast(connected_clients, frame_bytes)
                except Exception as e:
                    if show_logs:
                        logging.error(f"Ошибка захвата: {e}")

            await asyncio.sleep(0.04)


async def handle_connection(websocket):
    client_ip = websocket.remote_address[0]
    if show_logs:
        logging.info(f"🟢 Подключен клиент: {client_ip}")
    connected_clients.add(websocket)

    try:
        async for message in websocket:
            if isinstance(message, str):
                try:
                    data = json.loads(message)
                    event_type = data.get("type")

                    # 1. Управление мышью (приводим к int)
                    if event_type == "move":
                        dx = int(round(float(data.get("dx", 0))))
                        dy = int(round(float(data.get("dy", 0))))
                        if dx != 0 or dy != 0:
                            pyautogui.moveRel(dx, dy)

                    elif event_type == "click":
                        pyautogui.click(button=data.get("button", "left"))

                    # 2. Системные горячие команды
                    elif event_type == "command":
                        action = data.get("action")
                        if action == "lock":
                            ctypes.windll.user32.LockWorkStation()
                        elif action == "shutdown":
                            os.system("shutdown /s /t 5")
                        elif action == "restart":
                            os.system("shutdown /r /t 5")
                        elif action == "cancel_shutdown":
                            os.system("shutdown /a")

                except Exception as e:
                    if show_logs:
                        logging.error(f"Ошибка обработки команды: {e}")

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        connected_clients.remove(websocket)
        if show_logs:
            logging.info(f"🔴 Отключен клиент: {client_ip}")


def console_control(loop):
    """Интерактивное консольное меню для пользователя"""
    global show_logs
    print("\n==========================================")
    print("🚀 PC Remote Server запущен!")
    print("Ваши IP-адреса для ввода в приложении:")
    for ip in get_local_ips():
        print(f"  👉 http://{ip}:8765")
    print("==========================================")
    print(" [1] Переключить отображение логов (Вкл/Выкл)")
    print(" [2] Показать IP адреса")
    print(" [0] Выключить сервер")
    print("==========================================\n")

    while True:
        try:
            choice = input().strip()
            if choice == "1":
                show_logs = not show_logs
                print(
                    f"   [Логи]: {'ВКЛЮЧЕНЫ' if show_logs else 'ВЫКЛЮЧЕНЫ'}"
                )
            elif choice == "2":
                print("\nВаши IP-адреса:")
                for ip in get_local_ips():
                    print(f"  👉 {ip}")
                print()
            elif choice == "0":
                print("🛑 Остановка сервера...")
                loop.call_soon_threadsafe(loop.stop)
                sys.exit(0)
        except Exception:
            break


async def main():
    port = 8765
    loop = asyncio.get_running_loop()

    # Запуск потока для считывания клавиш 1/2/0 в консоли
    threading.Thread(target=console_control, args=(loop,), daemon=True).start()

    async with websockets.serve(handle_connection, "0.0.0.0", port):
        asyncio.create_task(stream_screen())
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        pass