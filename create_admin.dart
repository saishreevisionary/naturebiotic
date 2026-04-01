import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = await Supabase.initialize(
    url: 'https://utujkxrobmzlvudpvapc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw',
  );
  
  try {
    final response = await supabase.client.auth.signUp(
      email: 'naturebiotic96@gmail.com',
      password: 'admin123',
      data: {
        'full_name': 'Nature Biotic Admin',
        'username': 'admin',
      },
    );
    print('SUCCESS: Admin user created. ID: ${response.user?.id}');
    print('Remember to confirm your email if Supabase requires it.');
  } catch (e) {
    print('ERROR: $e');
  }
}
