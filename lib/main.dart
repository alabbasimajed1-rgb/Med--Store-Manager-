import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const MedStoreApp());
}

class MedStoreApp extends StatelessWidget {
  const MedStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Med Store Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const HomePage(),
    );
  }
}

class Drug {
  int? id;
  String name;
  int totalQty;
  int issuedQty;
  DateTime expiryDate;
  int minStockAlert;
  int expiryAlertMonths;

  Drug({
    this.id,
    required this.name,
    required this.totalQty,
    required this.issuedQty,
    required this.expiryDate,
    required this.minStockAlert,
    required this.expiryAlertMonths,
  });

  int get remainingQty => totalQty - issuedQty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'totalQty': totalQty,
      'issuedQty': issuedQty,
      'expiryDate': expiryDate.toIso8601String(),
      'minStockAlert': minStockAlert,
      'expiryAlertMonths': expiryAlertMonths,
    };
  }

  factory Drug.fromMap(Map<String, dynamic> map) {
    return Drug(
      id: map['id'],
      name: map['name'],
      totalQty: map['totalQty'],
      issuedQty: map['issuedQty'],
      expiryDate: DateTime.parse(map['expiryDate']),
      minStockAlert: map['minStockAlert'],
      expiryAlertMonths: map['expiryAlertMonths'],
    );
  }
}

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database!= null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), 'med_store.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE drugs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        totalQty INTEGER NOT NULL,
        issuedQty INTEGER NOT NULL,
        expiryDate TEXT NOT NULL,
        minStockAlert INTEGER NOT NULL,
        expiryAlertMonths INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insert(Drug drug) async {
    Database db = await instance.database;
    return await db.insert('drugs', drug.toMap());
  }

  Future<List<Drug>> getAllDrugs() async {
    Database db = await instance.database;
    var drugs = await db.query('drugs', orderBy: 'expiryDate ASC');
    return drugs.isNotEmpty? drugs.map((c) => Drug.fromMap(c)).toList() : [];
  }

  Future<int> update(Drug drug) async {
    Database db = await instance.database;
    return await db.update('drugs', drug.toMap(), where: 'id =?', whereArgs: [drug.id]);
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete('drugs', where: 'id =?', whereArgs: [id]);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Drug> drugs = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _refreshDrugs();
    _initNotifications();
  }

  _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  _refreshDrugs() async {
    final data = await DatabaseHelper.instance.getAllDrugs();
    setState(() => drugs = data);
    _checkAlerts();
  }

  _checkAlerts() async {
    for (var drug in drugs) {
      // Stock alert
      if (drug.remainingQty <= drug.minStockAlert) {
        _showAlert('Stock Alert', 'Remaining quantity of ${drug.name} is low: ${drug.remainingQty}');
      }
      // Expiry alert
      final monthsToExpiry = drug.expiryDate.difference(DateTime.now()).inDays / 30;
      if (monthsToExpiry <= drug.expiryAlertMonths && monthsToExpiry > 0) {
        _showAlert('Expiry Alert', '${drug.name} will expire in ${monthsToExpiry.toStringAsFixed(1)} months');
      }
    }
  }

  _showAlert(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'med_channel', 'Med Store Alerts',
      importance: Importance.max, priority: Priority.high);
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, details);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Med Store Manager', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: drugs.isEmpty
         ? Center(child: Text('No items added yet', style: GoogleFonts.poppins(fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: drugs.length,
              itemBuilder: (context, index) {
                final drug = drugs[index];
                final monthsToExpiry = drug.expiryDate.difference(DateTime.now()).inDays / 30;
                final isExpiryAlert = monthsToExpiry <= drug.expiryAlertMonths;
                final isStockAlert = drug.remainingQty <= drug.minStockAlert;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal.shade50],
                        begin: Alignment.topRight, end: Alignment.bottomLeft),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(drug.name,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildInfoRow('Total Quantity:', '${drug.totalQty}'),
                          _buildInfoRow('Issued:', '${drug.issuedQty}'),
                          _buildInfoRow('Remaining:', '${drug.remainingQty}',
                            isAlert: isStockAlert),
                          _buildInfoRow('Expiry Date:', DateFormat('yyyy-MM-dd').format(drug.expiryDate),
                            isAlert: isExpiryAlert),
                          _buildInfoRow('Stock Alert At:', '${drug.minStockAlert}'),
                          _buildInfoRow('Expiry Alert Before:', '${drug.expiryAlertMonths} months'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') _showDrugDialog(drug: drug);
                          if (value == 'delete') _deleteDrug(drug.id!);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDrugDialog(),
        icon: const Icon(Icons.add),
        label: Text('Add Item', style: GoogleFonts.poppins()),
        backgroundColor: Colors.teal.shade600,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(value,
            style: GoogleFonts.poppins(
              color: isAlert? Colors.red.shade700 : Colors.black87,
              fontWeight: isAlert? FontWeight.bold : FontWeight.normal,
            )),
        ],
      ),
    );
  }

  _deleteDrug(int id) async {
    await DatabaseHelper.instance.delete(id);
    _refreshDrugs();
  }

  _showDrugDialog({Drug? drug}) {
    final nameController = TextEditingController(text: drug?.name?? '');
    final totalController = TextEditingController(text: drug?.totalQty.toString()?? '');
    final issuedController = TextEditingController(text: drug?.issuedQty.toString()?? '0');
    final minStockController = TextEditingController(text: drug?.minStockAlert.toString()?? '10');
    final expiryAlertController = TextEditingController(text: drug?.expiryAlertMonths.toString()?? '6');
    DateTime selectedDate = drug?.expiryDate?? DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(drug == null? 'Add New Item' : 'Edit Item', style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Medicine/Supply Name'),
                _buildTextField(totalController, 'Total Quantity', isNumber: true),
                _buildTextField(issuedController, 'Issued Quantity', isNumber: true),
                _buildTextField(minStockController, 'Alert when remaining reaches', isNumber: true),
                _buildTextField(expiryAlertController, 'Expiry alert before (months)', isNumber: true),
                const SizedBox(height: 12),
                ListTile(
                  title: Text('Expiry Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                    style: GoogleFonts.poppins()),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date!= null) setDialogState(() => selectedDate = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins())),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || totalController.text.isEmpty) return;
                final newDrug = Drug(
                  id: drug?.id,
                  name: nameController.text,
                  totalQty: int.parse(totalController.text),
                  issuedQty: int.parse(issuedController.text),
                  expiryDate: selectedDate,
                  minStockAlert: int.parse(minStockController.text),
                  expiryAlertMonths: int.parse(expiryAlertController.text),
                );
                if (drug == null) {
                  await DatabaseHelper.instance.insert(newDrug);
                } else {
                  await DatabaseHelper.instance.update(newDrug);
                }
                _refreshDrugs();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
              child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
