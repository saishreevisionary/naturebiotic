import 'dart:io';

void main() async {
  try {
    print('Attempting to start process: whoami');
    var result = await Process.run('whoami', []);
    print('Exit code: ${result.exitCode}');
    print('Stdout: ${result.stdout}');
    print('Stderr: ${result.stderr}');
  } catch (e) {
    print('Error starting process: $e');
  }
}
