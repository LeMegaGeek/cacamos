#!/usr/bin/env python3

import argparse
import base64
import hashlib
import json
import os
import pathlib
import secrets
import shutil
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request


class DevToolsSocket:
    def __init__(self, url):
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "ws":
            raise RuntimeError(f"unsupported DevTools URL: {url}")
        self._socket = socket.create_connection(
            (parsed.hostname, parsed.port or 80), timeout=5
        )
        self._socket.settimeout(10)
        key = base64.b64encode(secrets.token_bytes(16)).decode()
        path = parsed.path or "/"
        if parsed.query:
            path += f"?{parsed.query}"
        request = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {parsed.hostname}:{parsed.port or 80}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "Origin: http://127.0.0.1\r\n"
            "\r\n"
        )
        self._socket.sendall(request.encode())
        response = self._read_http_headers()
        if not response.startswith(b"HTTP/1.1 101"):
            raise RuntimeError(
                f"DevTools WebSocket upgrade failed: {response.decode(errors='replace')}"
            )
        expected = base64.b64encode(
            hashlib.sha1(
                (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
            ).digest()
        )
        if b"sec-websocket-accept: " + expected.lower() not in response.lower():
            raise RuntimeError("DevTools WebSocket returned an invalid accept key")
        self._next_id = 1

    def _read_http_headers(self):
        response = bytearray()
        while b"\r\n\r\n" not in response:
            chunk = self._socket.recv(4096)
            if not chunk:
                raise RuntimeError("DevTools closed during WebSocket upgrade")
            response.extend(chunk)
            if len(response) > 65536:
                raise RuntimeError("oversized DevTools WebSocket response")
        return bytes(response)

    def _read_exact(self, length):
        data = bytearray()
        while len(data) < length:
            chunk = self._socket.recv(length - len(data))
            if not chunk:
                raise RuntimeError("DevTools WebSocket closed unexpectedly")
            data.extend(chunk)
        return bytes(data)

    def _send_frame(self, opcode, payload=b""):
        mask = secrets.token_bytes(4)
        first = 0x80 | opcode
        length = len(payload)
        if length < 126:
            header = bytes((first, 0x80 | length))
        elif length <= 0xFFFF:
            header = bytes((first, 0x80 | 126)) + struct.pack("!H", length)
        else:
            header = bytes((first, 0x80 | 127)) + struct.pack("!Q", length)
        encoded = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
        self._socket.sendall(header + mask + encoded)

    def _receive_text(self):
        while True:
            first, second = self._read_exact(2)
            opcode = first & 0x0F
            length = second & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._read_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._read_exact(8))[0]
            if second & 0x80:
                mask = self._read_exact(4)
            else:
                mask = None
            payload = self._read_exact(length)
            if mask:
                payload = bytes(
                    value ^ mask[index % 4] for index, value in enumerate(payload)
                )
            if opcode == 0x1:
                return payload.decode()
            if opcode == 0x8:
                raise RuntimeError("DevTools WebSocket closed")
            if opcode == 0x9:
                self._send_frame(0xA, payload)

    def command(self, method, params=None):
        command_id = self._next_id
        self._next_id += 1
        message = {"id": command_id, "method": method}
        if params is not None:
            message["params"] = params
        self._send_frame(0x1, json.dumps(message).encode())
        while True:
            response = json.loads(self._receive_text())
            if response.get("id") != command_id:
                continue
            if "error" in response:
                raise RuntimeError(
                    f"{method} failed: {response['error'].get('message', response['error'])}"
                )
            return response.get("result", {})

    def close(self):
        try:
            self._send_frame(0x8)
        finally:
            self._socket.close()


def find_free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def wait_for_page(port, deadline):
    url = f"http://127.0.0.1:{port}/json/list"
    last_error = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                targets = json.load(response)
            for target in targets:
                if target.get("type") == "page":
                    return target
        except Exception as error:
            last_error = error
        time.sleep(0.1)
    raise RuntimeError(f"Chrome DevTools did not start: {last_error}")


def main():
    parser = argparse.ArgumentParser(
        description="Open the real CaCamOS camera through Chromium getUserMedia()."
    )
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--html", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--timeout", type=int, default=30)
    args = parser.parse_args()

    html = pathlib.Path(args.html).resolve()
    if not html.is_file():
        raise SystemExit(f"missing probe page: {html}")
    report = pathlib.Path(args.report).resolve()
    report.parent.mkdir(parents=True, exist_ok=True)

    profile = pathlib.Path(tempfile.mkdtemp(prefix="cacamos-chrome-"))
    chrome_log = report.with_suffix(".chrome.log")
    port = find_free_port()
    command = [
        args.chrome,
        "--headless=new",
        "--disable-background-networking",
        "--disable-component-update",
        "--disable-default-apps",
        "--disable-dev-shm-usage",
        "--disable-features=MediaRouter",
        "--disable-gpu",
        "--disable-sync",
        "--mute-audio",
        "--no-default-browser-check",
        "--no-first-run",
        "--autoplay-policy=no-user-gesture-required",
        "--allow-file-access-from-files",
        "--remote-allow-origins=*",
        "--remote-debugging-address=127.0.0.1",
        f"--remote-debugging-port={port}",
        "--use-fake-ui-for-media-stream",
        f"--user-data-dir={profile}",
        "about:blank",
    ]

    process = None
    devtools = None
    result = None
    try:
        with chrome_log.open("w") as log:
            process = subprocess.Popen(
                command,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
        deadline = time.monotonic() + args.timeout
        target = wait_for_page(port, deadline)
        devtools = DevToolsSocket(target["webSocketDebuggerUrl"])
        devtools.command("Page.enable")
        devtools.command("Runtime.enable")
        devtools.command("Page.navigate", {"url": html.as_uri()})

        while time.monotonic() < deadline:
            evaluation = devtools.command(
                "Runtime.evaluate",
                {
                    "expression": (
                        "document.getElementById('result')?.textContent ?? ''"
                    ),
                    "returnByValue": True,
                },
            )
            text = evaluation.get("result", {}).get("value", "")
            if text and text != "Starting":
                candidate = json.loads(text)
                if candidate.get("status") != "running":
                    result = candidate
                    break
            time.sleep(0.25)
        if result is None:
            raise RuntimeError("WebRTC probe did not complete before its deadline")

        report.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        print(json.dumps(result, indent=2, sort_keys=True))
        if result.get("status") != "passed":
            raise RuntimeError(f"WebRTC probe status is {result.get('status')}")
    finally:
        if devtools is not None:
            try:
                devtools.close()
            except Exception:
                pass
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
