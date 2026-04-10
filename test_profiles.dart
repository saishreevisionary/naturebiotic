import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = await Supabase.initialize(
    url: 'https://utujkxrobmzlvudpvapc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw',
  );
  
  try {
    // Try to select from profiles
    final response = await supabase.client.from('profiles').select();
    print('PROFILES COUNT: ${response.length}');
    print('PROFILES: $response');
  } catch (e) {
    print('ERROR FETCHING PROFILES: $e');
  }
}
