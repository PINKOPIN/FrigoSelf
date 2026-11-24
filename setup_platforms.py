#!/usr/bin/env python3
"""Prepara le cartelle android/ e ios/ generate da `flutter create`.

Aggiunge ciò che FrigoSelf richiede e che `flutter create` non mette:
  Android: permessi (notifiche, fotocamera, avvio), ricevitori delle notifiche
           programmate, minSdk 23 e "core library desugaring".
  iOS:     descrizioni d'uso di fotocamera e foto.

È idempotente: si può eseguire più volte. Non modifica nulla se i valori
ci sono già. Uso:  python3 scripts/setup_platforms.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ok = True


def log(msg):
    print(msg)


def patch_manifest():
    path = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not path.exists():
        log("! AndroidManifest.xml non trovato (hai eseguito flutter create?)")
        return False
    s = path.read_text(encoding="utf-8")
    perms = [
        "android.permission.INTERNET",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.CAMERA",
        "android.permission.VIBRATE",
    ]
    add = "".join(
        f'    <uses-permission android:name="{p}"/>\n'
        for p in perms
        if f'"{p}"' not in s
    )
    if add:
        s = re.sub(r"(<manifest[^>]*>\n?)", lambda m: m.group(1) + add, s, count=1)
    if "ScheduledNotificationReceiver" not in s:
        receivers = (
            '        <receiver android:exported="false" '
            'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>\n'
            '        <receiver android:exported="false" '
            'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
            "            <intent-filter>\n"
            '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
            '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
            "            </intent-filter>\n"
            "        </receiver>\n"
        )
        s = s.replace("</application>", receivers + "    </application>", 1)
    path.write_text(s, encoding="utf-8")
    log("✓ AndroidManifest.xml")
    return True


def patch_gradle():
    kts = ROOT / "android/app/build.gradle.kts"
    groovy = ROOT / "android/app/build.gradle"
    if kts.exists():
        path, is_kts = kts, True
    elif groovy.exists():
        path, is_kts = groovy, False
    else:
        log("! build.gradle(.kts) dell'app non trovato")
        return False
    s = path.read_text(encoding="utf-8")

    # 1. minSdk 23
    s = re.sub(
        r"minSdk(Version)?\s*=?\s*(flutter\.minSdkVersion|\d+)",
        "minSdk = 23" if is_kts else "minSdkVersion 23",
        s,
        count=1,
    )

    # 2. desugaring nel blocco compileOptions
    if "isCoreLibraryDesugaringEnabled" not in s and "coreLibraryDesugaringEnabled" not in s:
        flag = (
            "isCoreLibraryDesugaringEnabled = true"
            if is_kts
            else "coreLibraryDesugaringEnabled true"
        )
        s, n = re.subn(
            r"(compileOptions\s*\{)", r"\1\n        " + flag, s, count=1
        )
        if n == 0:
            log("! blocco compileOptions non trovato: aggiungi il desugaring a mano")
            return False

    # 3. dipendenza di desugaring
    if "desugar_jdk_libs" not in s:
        dep = (
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            if is_kts
            else "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
        )
        if re.search(r"^dependencies\s*\{", s, re.M):
            s = re.sub(r"(^dependencies\s*\{\n)", r"\1" + dep, s, count=1, flags=re.M)
        else:
            s += "\ndependencies {\n" + dep + "}\n"

    path.write_text(s, encoding="utf-8")
    log(f"✓ {path.name}")
    return True


def patch_plist():
    path = ROOT / "ios/Runner/Info.plist"
    if not path.exists():
        log("- ios/Runner/Info.plist non presente (salto iOS)")
        return True
    s = path.read_text(encoding="utf-8")
    entries = {
        "NSCameraUsageDescription": "Serve per fotografare gli alimenti, leggere i codici a barre e le date di scadenza.",
        "NSPhotoLibraryUsageDescription": "Serve per scegliere dalla galleria la foto di un alimento o del profilo.",
    }
    add = "".join(
        f"\t<key>{k}</key>\n\t<string>{v}</string>\n"
        for k, v in entries.items()
        if f"<key>{k}</key>" not in s
    )
    if add:
        s = s.replace("</dict>\n</plist>", add + "</dict>\n</plist>", 1)
        path.write_text(s, encoding="utf-8")
    log("✓ Info.plist")
    return True


if __name__ == "__main__":
    for step in (patch_manifest, patch_gradle, patch_plist):
        ok = step() and ok
    sys.exit(0 if ok else 1)
