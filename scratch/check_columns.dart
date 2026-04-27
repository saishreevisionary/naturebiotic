import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient('...', '...');
  final response = await client.from('dropdown_options').select().limit(1);
  if (response.isNotEmpty) {
    print('Columns: ${response.first.keys}');
  }
}
