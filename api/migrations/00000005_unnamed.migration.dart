import 'dart:async';
import 'package:conduit_core/conduit_core.dart';   

class Migration5 extends Migration { 
  @override
  Future upgrade() async {
   		database.deleteTable("_History");
  }
  
  @override
  Future downgrade() async {}
  
  @override
  Future seed() async {}
}
    