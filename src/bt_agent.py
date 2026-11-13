#!/usr/bin/env python3
"""Project Azmuth — agente de pareamento Bluetooth (org.bluez.Agent1).

Responde aos pedidos do BlueZ durante um pareamento com notificações do Azmuth:
- confirmação de código (celular, fone moderno): notificação com Parear / Recusar;
- código para digitar no dispositivo (teclado): notificação mostrando o número;
- PIN pedido ao usuário (dispositivos antigos): caixa de texto do rofi.
Nada é aceito sozinho: sem resposta em 30 s, o pedido é recusado.

Roda com o Python do sistema (python-dbus + python-gobject):
    /usr/bin/python3 src/bt_agent.py
Iniciado por `azmuth start` (src/session_runtime.py).
"""

import shutil
import subprocess
import sys
import threading

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BUS = "org.bluez"
AGENT_PATH = "/project/azmuth/bt_agent"
CAPABILITY = "KeyboardDisplay"
TIMEOUT = 30


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


def log(msg):
    print("[bt-agent] " + msg, flush=True)


def device_name(bus, path):
    try:
        props = dbus.Interface(bus.get_object(BUS, path), "org.freedesktop.DBus.Properties")
        return str(props.Get("org.bluez.Device1", "Alias"))
    except dbus.DBusException:
        return str(path).rsplit("/", 1)[-1].replace("dev_", "").replace("_", ":")


def device_prop(bus, path, name, default=False):
    try:
        props = dbus.Interface(bus.get_object(BUS, path), "org.freedesktop.DBus.Properties")
        return props.Get("org.bluez.Device1", name)
    except dbus.DBusException:
        return default


def notify(title, body, urgency="normal", timeout_ms=10000):
    if shutil.which("notify-send"):
        subprocess.Popen(["notify-send", "-a", "Azmuth", "-u", urgency, "-t", str(timeout_ms), title, body],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def ask(title, body):
    """Notificação com Parear / Recusar; True só se o usuário clicar em Parear."""
    if not shutil.which("notify-send"):
        return False
    try:
        r = subprocess.run(["notify-send", "-a", "Azmuth", "-u", "critical", "-t", str(TIMEOUT * 1000),
                            "-A", "yes=Parear", "-A", "no=Recusar", "--wait", title, body],
                           capture_output=True, text=True, timeout=TIMEOUT + 2)
        return r.stdout.strip() == "yes"
    except (OSError, subprocess.TimeoutExpired):
        return False


def prompt(title):
    """Caixa de texto do rofi (PIN de dispositivos antigos)."""
    if not shutil.which("rofi"):
        return None
    try:
        r = subprocess.run(["rofi", "-dmenu", "-p", title, "-l", "0", "-theme-str", "window { width: 460px; }"],
                           input="", capture_output=True, text=True, timeout=TIMEOUT + 30)
        value = r.stdout.strip()
        return value if r.returncode == 0 and value else None
    except (OSError, subprocess.TimeoutExpired):
        return None


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus

    def _async(self, work, ok, err):
        """Executa a pergunta numa thread: o laço do D-Bus continua livre."""
        def run():
            try:
                value = work()
            except dbus.DBusException as exc:
                failure = exc   # `exc` some ao sair do except; a lambda roda depois
                GLib.idle_add(lambda: err(failure) and False)
                return
            GLib.idle_add(lambda: (ok(value) if value is not None else ok()) and False)
        threading.Thread(target=run, daemon=True).start()

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        log("liberado pelo BlueZ")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="",
                         async_callbacks=("ok", "err"))
    def AuthorizeService(self, device, uuid, ok, err):
        if device_prop(self.bus, device, "Trusted") or device_prop(self.bus, device, "Paired"):
            ok()
            return
        name = device_name(self.bus, device)

        def work():
            if not ask("Bluetooth · " + name, name + " quer usar um serviço deste computador. Permitir?"):
                raise Rejected("Serviço recusado")
        self._async(work, ok, err)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s",
                         async_callbacks=("ok", "err"))
    def RequestPinCode(self, device, ok, err):
        name = device_name(self.bus, device)

        def work():
            pin = prompt("PIN para " + name)
            if not pin:
                raise Rejected("PIN não informado")
            return dbus.String(pin)
        self._async(work, ok, err)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        name = device_name(self.bus, device)
        notify("Bluetooth · " + name, "Digite " + str(pincode) + " no dispositivo e aperte Enter.", "critical", TIMEOUT * 1000)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u",
                         async_callbacks=("ok", "err"))
    def RequestPasskey(self, device, ok, err):
        name = device_name(self.bus, device)

        def work():
            value = prompt("Código de 6 dígitos para " + name)
            if not value or not value.isdigit():
                raise Rejected("Código não informado")
            return dbus.UInt32(int(value))
        self._async(work, ok, err)

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        if int(entered) == 0:
            name = device_name(self.bus, device)
            notify("Bluetooth · " + name, "Digite %06d no dispositivo e aperte Enter." % int(passkey), "critical", TIMEOUT * 1000)

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="",
                         async_callbacks=("ok", "err"))
    def RequestConfirmation(self, device, passkey, ok, err):
        name = device_name(self.bus, device)

        def work():
            if not ask("Bluetooth · parear " + name,
                       "Confira se o código %06d aparece também no dispositivo." % int(passkey)):
                raise Rejected("Pareamento recusado")
        self._async(work, ok, err)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="",
                         async_callbacks=("ok", "err"))
    def RequestAuthorization(self, device, ok, err):
        name = device_name(self.bus, device)

        def work():
            if not ask("Bluetooth · parear " + name, name + " quer parear com este computador."):
                raise Rejected("Pareamento recusado")
        self._async(work, ok, err)

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        log("pedido cancelado pelo dispositivo")


def register(bus):
    manager = dbus.Interface(bus.get_object(BUS, "/org/bluez"), "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, CAPABILITY)
    manager.RequestDefaultAgent(AGENT_PATH)
    log("registrado (" + CAPABILITY + ")")


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    Agent(bus)
    loop = GLib.MainLoop()

    def try_register():
        try:
            register(bus)
        except dbus.DBusException as exc:
            log("BlueZ indisponível, nova tentativa em 10 s: " + exc.get_dbus_message())
            GLib.timeout_add_seconds(10, lambda: try_register() and False)

    # o bluetoothd reiniciou: registra de novo
    bus.add_signal_receiver(lambda name, old, new: new and try_register(),
                            "NameOwnerChanged", "org.freedesktop.DBus", arg0=BUS)
    try_register()
    try:
        loop.run()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
