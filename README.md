# Build Vars Spoofing

Build Vars Spoofing. **Android 8.1 or above is required**.

## Usage

1. Flash this module and reboot.
2. Enjoy!

You can try enabling/disabling Build variable spoofing by creating/deleting the file `/data/adb/build_var_spoof/spoof_build_vars`.

Build Vars Spoofing will automatically generate example config props inside `/data/adb/build_var_spoof/spoof_build_vars` once created, on next reboot, then you may manually edit your spoof config.

Here is an example of a spoof config:

```
MANUFACTURER=Google
MODEL=Pixel 9 Pro XL
FINGERPRINT=google/komodo_beta/komodo:15/AP31.240617.015/12207491:user/release-keys
BRAND=google
PRODUCT=komodo_beta
DEVICE=komodo
RELEASE=15
ID=AP31.240617.015
INCREMENTAL=12207491
TYPE=user
TAGS=release-keys
SECURITY_PATCH=2024-08-05
```

## Acknowledgement

- [PlayIntegrityFix](https://github.com/chiteroman/PlayIntegrityFix)
- [LSPosed](https://github.com/LSPosed/LSPosed)
