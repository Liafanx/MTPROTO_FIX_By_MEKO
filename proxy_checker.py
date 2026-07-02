#!/usr/bin/env python3
import os
import re
import subprocess
import socket
import sys

# ── Цвета ─────────────────────────────────────────────────────
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
GRAY = '\033[0;90m'
NC = '\033[0m'
BOLD = '\033[1m'
DIM = '\033[2m'

TIMEOUT = 10
OPENSSL_BIN = "/usr/bin/openssl"

def print_info(text):
    print(f"{BLUE}ℹ️ {text}{NC}")

def print_warning(text):
    print(f"{YELLOW}⚠️ {text}{NC}")

def normalize(raw):
    t = raw.strip()
    t = re.sub(r'^https?://', '', t)
    t = t.split('/')[0].split('?')[0].split('#')[0].strip()
    return t

def run_openssl(args):
    env = os.environ.copy()
    try:
        proc = subprocess.run(
            [OPENSSL_BIN] + args,
            input=b"",
            capture_output=True,
            timeout=TIMEOUT,
            env=env,
        )
        return (proc.stdout + proc.stderr).decode(errors='replace')
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    except Exception as e:
        return f"ERROR: {e}"

def run_openssl_full(args):
    env = os.environ.copy()
    try:
        proc = subprocess.run(
            [OPENSSL_BIN] + args,
            input=b"Q\n".encode(),
            capture_output=True,
            timeout=TIMEOUT,
            env=env,
        )
        return (proc.stdout + proc.stderr).decode(errors='replace')
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    except Exception as e:
        return f"ERROR: {e}"

def parse_field(text, key):
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith(key + ":"):
            return stripped.split(":", 1)[1].strip()
    return ""

def parse_field_full(text, key):
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.lower().startswith(key.lower() + ":"):
            return stripped.split(":", 1)[1].strip()
    return ""

def resolve_ip(host):
    try:
        ips = socket.getaddrinfo(host, None, socket.AF_UNSPEC, socket.SOCK_STREAM)
        seen = []
        for family, _, _, _, sockaddr in ips:
            ip = sockaddr[0]
            if ip not in seen:
                seen.append(ip)
        return ", ".join(seen) if seen else "не удалось определить"
    except Exception:
        return "не удалось определить"

def extract_cert_details(full_output):
    info = {}
    for line in full_output.splitlines():
        s = line.strip()
        if s.startswith("subject="):
            info["subject"] = s.split("=", 1)[1].strip()
        elif s.startswith("issuer="):
            info["issuer"] = s.split("=", 1)[1].strip()
        elif s.startswith("Protocol") and ":" in s:
            info["protocol"] = s.split(":", 1)[1].strip()
        elif s.startswith("Cipher") and ":" in s and "Ciphersuite" not in s:
            info["cipher_detail"] = s.split(":", 1)[1].strip()
    
    not_before = parse_field_full(full_output, "Not Before")
    not_after = parse_field_full(full_output, "Not After")
    if not_before:
        info["not_before"] = not_before
    if not_after:
        info["not_after"] = not_after
    
    return info

def check_one(domain):
    target = normalize(domain)
    if not target:
        return "❌ Пустой домен"

    if ":" in target and not target.startswith("["):
        parts = target.rsplit(":", 1)
        host = parts[0]
        port = parts[1] if parts[1].isdigit() else "443"
    else:
        host = target
        port = "443"

    connect = f"{host}:{port}"
    lines = [f"\n{BOLD}🔎 {host}:{port}{NC}"]

    ip_str = resolve_ip(host)
    lines.append(f"\n{CYAN}🌐 IP: {NC}{ip_str}")
    lines.append("")

    # PQ-проверка
    pq = run_openssl([
        "s_client", "-connect", connect,
        "-servername", host,
        "-groups", "X25519MLKEM768",
        "-brief",
    ])

    if "CONNECTION ESTABLISHED" in pq:
        proto = parse_field(pq, "Protocol version")
        cipher = parse_field(pq, "Ciphersuite")
        temp = parse_field(pq, "Peer Temp Key")
        verify = parse_field(pq, "Verification")
        cert_cn = parse_field(pq, "Peer certificate")
        sig = parse_field(pq, "Signature type")
        hash_used = parse_field(pq, "Hash used")

        lines.append(f"{CYAN}━━━ PQ-подключение ━━━{NC}")
        lines.append(f"{GREEN}✅ Статус: поддерживается{NC}")
        if proto:
            lines.append(f"  Протокол: {proto}")
        if cipher:
            lines.append(f"  Шифронабор: {cipher}")
        if temp:
            lines.append(f"  Peer Temp Key: {temp}")
        if cert_cn:
            lines.append(f"  Сертификат: {cert_cn}")
        if sig:
            lines.append(f"  Подпись: {sig}")
        if hash_used:
            lines.append(f"  Хэш: {hash_used}")
        if verify:
            lines.append(f"  Верификация: {verify}")

        full = run_openssl_full([
            "s_client", "-connect", connect,
            "-servername", host,
            "-groups", "X25519MLKEM768",
        ])
        cert_info = extract_cert_details(full)

        if cert_info:
            lines.append("")
            lines.append(f"{CYAN}━━━ Сертификат ━━━{NC}")
            if "subject" in cert_info:
                lines.append(f"  Subject: {cert_info['subject'][:120]}")
            if "issuer" in cert_info:
                lines.append(f"  Issuer: {cert_info['issuer'][:120]}")
            if "not_before" in cert_info:
                lines.append(f"  Действует с: {cert_info['not_before']}")
            if "not_after" in cert_info:
                lines.append(f"  Истекает: {cert_info['not_after']}")

        lines.append("")
        lines.append(f"{GREEN}━━━ ВЕРДИКТ ━━━{NC}")
        lines.append(f"{GREEN}🟢 Маркер: НЕТ — сервер принимает X25519MLKEM768{NC}")
        return "\n".join(lines)

    # PQ не прошёл
    lines.append(f"{CYAN}━━━ PQ-подключение ━━━{NC}")
    lines.append(f"{RED}🔸 Статус: не поддерживается{NC}")

    reason = ""
    for ln in pq.splitlines():
        if "alert" in ln or "error:" in ln:
            reason = ln.strip()
            break
    if reason:
        lines.append(f"  Причина: {GRAY}{reason}{NC}")

    # Обычный TLS
    std = run_openssl([
        "s_client", "-connect", connect,
        "-servername", host,
        "-brief",
    ])

    if "CONNECTION ESTABLISHED" not in std:
        if "TIMEOUT" in std:
            lines.append("")
            lines.append(f"{YELLOW}⏱ Таймаут при обычном TLS-подключении{NC}")
        else:
            err = ""
            for ln in std.splitlines():
                if "error:" in ln or "alert" in ln:
                    err = ln.strip()
                    break
            lines.append("")
            lines.append(f"{RED}❌ Обычное TLS тоже не удалось{NC}")
            if err:
                lines.append(f"  {GRAY}{err}{NC}")
        return "\n".join(lines)

    proto = parse_field(std, "Protocol version")
    cipher = parse_field(std, "Ciphersuite")
    cert_cn = parse_field(std, "Peer certificate")
    sig = parse_field(std, "Signature type")
    verify = parse_field(std, "Verification")
    temp = parse_field(std, "Peer Temp Key")
    hash_used = parse_field(std, "Hash used")

    lines.append("")
    lines.append(f"{CYAN}━━━ Обычное TLS-подключение ━━━{NC}")
    lines.append(f"{GREEN}🔹 Статус: OK{NC}")
    if proto:
        lines.append(f"  Протокол: {proto}")
    if cipher:
        lines.append(f"  Шифронабор: {cipher}")
    if temp:
        lines.append(f"  Peer Temp Key: {temp}")
    if cert_cn:
        lines.append(f"  Сертификат: {cert_cn}")
    if sig:
        lines.append(f"  Подпись: {sig}")
    if hash_used:
        lines.append(f"  Хэш: {hash_used}")
    if verify:
        lines.append(f"  Верификация: {verify}")

    full = run_openssl_full([
        "s_client", "-connect", connect,
        "-servername", host,
    ])
    cert_info = extract_cert_details(full)

    if cert_info:
        lines.append("")
        lines.append(f"{CYAN}━━━ Сертификат ━━━{NC}")
        if "subject" in cert_info:
            lines.append(f"  Subject: {cert_info['subject'][:120]}")
        if "issuer" in cert_info:
            lines.append(f"  Issuer: {cert_info['issuer'][:120]}")
        if "not_before" in cert_info:
            lines.append(f"  Действует с: {cert_info['not_before']}")
        if "not_after" in cert_info:
            lines.append(f"  Истекает: {cert_info['not_after']}")

    lines.append("")
    if temp.startswith("X25519"):
        lines.append(f"{RED}━━━ ВЕРДИКТ ━━━{NC}")
        lines.append(f"{RED}🔴 МАРКЕР: ДА{NC}")
        lines.append(f"{RED}PQ не поддерживается + Peer Temp Key = X25519{NC}")
        lines.append(f"{YELLOW}⚠️ Риск блокировки на ТСПУ для iOS клиентов{NC}")
    else:
        lines.append(f"{GREEN}━━━ ВЕРДИКТ ━━━{NC}")
        lines.append(f"{GREEN}🟢 Маркер: НЕТ{NC}")
        lines.append(f"{GREEN}PQ не поддерживается, но Peer Temp Key не X25519{NC}")

    return "\n".join(lines)

def main():
    # Если передан аргумент — проверяем и выходим (для вызова из меню)
    if len(sys.argv) > 1:
        print(check_one(sys.argv[1]))
        sys.exit(0)
    
    # Интерактивный режим
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print("")
        print(f"  {BOLD}{CYAN}🔍 ПРОВЕРКА TLS И PQ-БЕЗОПАСНОСТЬ{NC}")
        print(f"  {DIM}═════════════════════════════════════════════════{NC}")
        print("")
        print("  Введите домен или ссылку для проверки:")
        print(f"  {DIM}Примеры:{NC}")
        print(f"  {DIM}  • tg://proxy?server=212.8.229.241&port=443&secret=...{NC}")
        print(f"  {DIM}  • 212.8.229.241:443{NC}")
        print(f"  {DIM}  • rutube.ru{NC}")
        print(f"  {DIM}  • 0, n или q — выход{NC}")
        print("")
        proxy_input = input(f"  {BOLD}Ввод: {NC}").strip()
        
        if proxy_input in ['0', 'n', 'N', 'q', 'Q']:
            print("")
            print_info("Возврат в главное меню...")
            sys.exit(0)
        
        if not proxy_input:
            print_warning("Введите что-нибудь")
            continue
        
        print(check_one(proxy_input))
        
        print("")
        continue_input = input(f"  {GRAY}Нажмите Enter или 0 для выхода...{NC}").strip()
        if continue_input in ['0', 'n', 'N', 'q', 'Q']:
            print("")
            print_info("Возврат в главное меню...")
            sys.exit(0)

if __name__ == "__main__":
    main()
