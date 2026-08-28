class WgConfig {
  WgConfig._();

  static const tunnelName = 'ibrahim';
  static const serverHost = '212.224.86.115';
  static const serverPort = 51820;
  static const serverAddress = '$serverHost:$serverPort';

  static const quickConfig = '''
[Interface]
PrivateKey = UBmrTpyrX3UlfGasYv8OYJskM485qg4w4V6XB5uPelo=
Address = 10.66.66.4/32
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280

[Peer]
PublicKey = g4oXckwLCQvtK5WDuhNhdgQgIg5DJzFXuXZge5VZ/UU=
PresharedKey = +fnHTWtQnKrLc0xc5EPlXJRhuURUIk/GDNZrxLRPGLQ=
Endpoint = 212.224.86.115:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';
}
