import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  try {
    await Supabase.initialize(
      url: 'https://dwlwkpukuetycufjcdkp.supabase.co',
      publishableKey: 'sb_publishable_RpIxDvQCktZAR6fmoaZ4TQ_moTO5sAJ',
    );
  } catch (_) {
    // Supabase not available — app runs offline
  }
}
