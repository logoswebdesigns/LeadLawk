// Device Service.
// Pattern: Service Pattern - device identification operations.
// Single Responsibility: Device identification management.
// File size: <100 lines as per CLAUDE.md requirements.

import 'dart:io';

abstract class DeviceService {
  Future<String> getDeviceId();
  Future<String> getDeviceName();
  Future<String> getPlatform();
  Future<String> getDeviceInfo();
}

class DeviceServiceImpl implements DeviceService {
  @override
  Future<String> getDeviceId() async {
    try {
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  @override
  Future<String> getPlatform() async {
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isLinux) {
      return 'Linux';
    }
    return 'Unknown';
  }
  
  @override
  Future<String> getDeviceInfo() async {
    final platform = await getPlatform();
    final name = await getDeviceName();
    return '$name ($platform)';
  }
}