import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../models/reservation.dart';
import '../services/api_service.dart';
import 'base_screen.dart';
import 'package:intl/intl.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({Key? key}) : super(key: key);

  @override
  _EquipmentScreenState createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  bool _isLoading = false;
  List<Equipment> _equipment = [];
  final ApiService _apiService = ApiService();
  
  // Flexible reservation parameters
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 11, minute: 0);
  int _quantity = 1;
  
  // Mode de réservation (plage horaire ou période avec date de retrait/retour)
  bool _isRangeMode = false; // false = time slot mode, true = date range mode
  
  // Liste des heures disponibles (8h à 22h)
  final List<int> _availableHours = List.generate(15, (index) => index + 8); // 8h à 22h
  
  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }
  
  Future<void> _loadEquipment() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final equipment = await _apiService.getAvailableEquipment();
      setState(() {
        _equipment = equipment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des équipements: $e')),
      );
    }
  }
  
  Widget _buildHourSelector(
    String title,
    int selectedHour,
    int selectedMinute,
    Function(int, int) onChanged,
    Color accentColor,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sélecteur d'heure
          DropdownButton<int>(
            value: selectedHour,
            dropdownColor: const Color(0xFF2C2C2C),
            underline: Container(height: 1, color: accentColor),
            onChanged: (newHour) {
              if (newHour != null) {
                onChanged(newHour, selectedMinute);
              }
            },
            items: _availableHours.map((hour) {
              return DropdownMenuItem<int>(
                value: hour,
                child: Text(
                  '$hour h',
                  style: TextStyle(color: accentColor),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
          // Sélecteur de minute
          DropdownButton<int>(
            value: selectedMinute,
            dropdownColor: const Color(0xFF2C2C2C),
            underline: Container(height: 1, color: accentColor),
            onChanged: (newMinute) {
              if (newMinute != null) {
                onChanged(selectedHour, newMinute);
              }
            },
            items: [0, 15, 30, 45].map((minute) {
              return DropdownMenuItem<int>(
                value: minute,
                child: Text(
                  '$minute min',
                  style: TextStyle(color: accentColor),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Future<void> _reserveEquipment(Equipment equipment) async {
    // Vérifier que les heures sont entre 8h et 22h
    final startHour = _startTime.hour;
    final endHour = _endTime.hour;
    final endMinute = _endTime.minute;
    
    if (startHour < 8 || endHour > 22 || (endHour == 22 && endMinute > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Les réservations ne sont autorisées qu\'entre 8h et 22h'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    DateTime startDateTime;
    DateTime endDateTime;
    
    if (_isRangeMode) {
      // En mode date range, on utilise les dates complètes
      startDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      endDateTime = DateTime(
        _selectedEndDate.year,
        _selectedEndDate.month,
        _selectedEndDate.day,
        _endTime.hour,
        _endTime.minute,
      );
      
      if (endDateTime.isBefore(startDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La date de retour doit être après la date de retrait')),
        );
        return;
      }
    } else {
      // En mode time slot, c'est une réservation sur la même journée
      startDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      endDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _endTime.hour,
        _endTime.minute,
      );
    }
    
    // Formater les DateTime pour l'API
    final formattedStartTime = startDateTime.toIso8601String();
    final formattedEndTime = endDateTime.toIso8601String();
    
    // Créer la réservation
    final reservation = Reservation(
      id: 0, // Sera assigné par le serveur
      userId: 0, // Sera rempli par le serveur en fonction du token
      equipmentId: equipment.id,
      date: DateFormat('yyyy-MM-dd').format(_selectedStartDate), // Pour la compatibilité du modèle
      status: 'Confirmée',
      // Ces champs seront transformés par le service API
      startTime: DateFormat('HH:mm:ss').format(startDateTime),
      endTime: DateFormat('HH:mm:ss').format(endDateTime),
      equipmentQuantity: _quantity,
    );
    
    // Si on est en mode range, ajouter les dates de retrait et retour
    if (_isRangeMode) {
      // Pour corriger le problème d'heures à 00:00:00
      // Créer des dates complètes avec les heures correctes
      final pickupDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final returnDateTime = DateTime(
        _selectedEndDate.year,
        _selectedEndDate.month,
        _selectedEndDate.day,
        _endTime.hour,
        _endTime.minute,
      );
      
      final modifiedReservation = Reservation(
        id: 0,
        userId: 0,
        equipmentId: equipment.id,
        date: DateFormat('yyyy-MM-dd').format(_selectedStartDate),
        status: 'Confirmée',
        startTime: DateFormat('HH:mm:ss').format(startDateTime),
        endTime: DateFormat('HH:mm:ss').format(endDateTime),
        equipmentQuantity: _quantity,
        pickupDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(pickupDateTime),
        returnDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(returnDateTime),
      );
      
      try {
        setState(() {
          _isLoading = true;
        });
        
        await _apiService.createReservation(modifiedReservation);
        
        // Recharger les équipements pour mettre à jour la disponibilité
        await _loadEquipment();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Réservation de ${_quantity} ${equipment.name} confirmée')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la réservation: $e')),
        );
      }
    } else {
      try {
        setState(() {
          _isLoading = true;
        });
        
        await _apiService.createReservation(reservation);
        
        // Recharger les équipements pour mettre à jour la disponibilité
        await _loadEquipment();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Réservation de ${_quantity} ${equipment.name} confirmée')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la réservation: $e')),
        );
      }
    }
  }
  
  // Nouvelle méthode pour afficher le popup de réservation
  void _showReservationForm(Equipment equipment) {
    // Variables locales pour contrôler le formulaire de dialogue
    bool localIsRangeMode = _isRangeMode;
    DateTime localStartDate = _selectedStartDate;
    DateTime localEndDate = _selectedEndDate;
    int localStartHour = _startTime.hour;
    int localStartMinute = _startTime.minute;
    int localEndHour = _endTime.hour;
    int localEndMinute = _endTime.minute;
    int localQuantity = _quantity;
    
    // S'assurer que les heures sont valides
    if (localStartHour < 8) localStartHour = 8;
    if (localStartHour > 21) localStartHour = 21;
    if (localEndHour < 9) localEndHour = 9;
    if (localEndHour > 22) localEndHour = 22;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Réserver ${equipment.name}', style: const TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode de réservation switch
                  Row(
                    children: [
                      const Text('Mode de réservation :', style: TextStyle(color: Colors.white)),
                      const Spacer(),
                      Switch(
                        value: localIsRangeMode,
                        onChanged: (value) {
                          setState(() {
                            localIsRangeMode = value;
                          });
                        },
                        activeColor: Colors.purple,
                      ),
                      Text(
                        localIsRangeMode ? 'Période' : 'Créneau',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Date et heure selon le mode
                  if (localIsRangeMode)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date de retrait
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date de retrait', style: TextStyle(color: Colors.white)),
                          trailing: TextButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: localStartDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                              );
                              if (picked != null) {
                                setState(() {
                                  localStartDate = picked;
                                  // Ensure end date is after start date
                                  if (localEndDate.isBefore(localStartDate)) {
                                    localEndDate = localStartDate.add(const Duration(days: 1));
                                  }
                                });
                              }
                            },
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(localStartDate),
                              style: const TextStyle(color: Colors.purple),
                            ),
                          ),
                        ),
                        
                        // Heure de retrait
                        _buildHourSelector(
                          'Heure de retrait',
                          localStartHour,
                          localStartMinute,
                          (hour, minute) {
                            setState(() {
                              localStartHour = hour;
                              localStartMinute = minute;
                            });
                          },
                          Colors.purple,
                        ),
                        
                        // Date de retour
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date de retour', style: TextStyle(color: Colors.white)),
                          trailing: TextButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: localEndDate,
                                firstDate: localStartDate,
                                lastDate: localStartDate.add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() {
                                  localEndDate = picked;
                                });
                              }
                            },
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(localEndDate),
                              style: const TextStyle(color: Colors.purple),
                            ),
                          ),
                        ),
                        
                        // Heure de retour
                        _buildHourSelector(
                          'Heure de retour',
                          localEndHour,
                          localEndMinute,
                          (hour, minute) {
                            setState(() {
                              localEndHour = hour;
                              localEndMinute = minute;
                            });
                          },
                          Colors.purple,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date', style: TextStyle(color: Colors.white)),
                          trailing: TextButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: localStartDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                              );
                              if (picked != null) {
                                setState(() {
                                  localStartDate = picked;
                                });
                              }
                            },
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(localStartDate),
                              style: const TextStyle(color: Colors.purple),
                            ),
                          ),
                        ),
                        
                        // Heure de début
                        _buildHourSelector(
                          'Heure de début',
                          localStartHour,
                          localStartMinute,
                          (hour, minute) {
                            setState(() {
                              localStartHour = hour;
                              localStartMinute = minute;
                            });
                          },
                          Colors.purple,
                        ),
                        
                        // Heure de fin
                        _buildHourSelector(
                          'Heure de fin',
                          localEndHour,
                          localEndMinute,
                          (hour, minute) {
                            setState(() {
                              localEndHour = hour;
                              localEndMinute = minute;
                            });
                          },
                          Colors.purple,
                        ),
                      ],
                    ),
                  
                  // Quantité
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Quantité:', style: TextStyle(color: Colors.white)),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                            onPressed: () {
                              if (localQuantity > 1) {
                                setState(() {
                                  localQuantity--;
                                });
                              }
                            },
                          ),
                          Text(
                            '$localQuantity',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white, size: 16),
                            onPressed: () {
                              setState(() {
                                localQuantity++;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Mettre à jour les valeurs globales avec celles du dialogue
              setState(() {
                _isRangeMode = localIsRangeMode;
                _selectedStartDate = localStartDate;
                _selectedEndDate = localEndDate;
                _startTime = TimeOfDay(hour: localStartHour, minute: localStartMinute);
                _endTime = TimeOfDay(hour: localEndHour, minute: localEndMinute);
                _quantity = localQuantity;
              });
              
              _reserveEquipment(equipment);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Réserver'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Équipements',
      currentIndex: 2,
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.purple))
        : _equipment.isEmpty
            ? _buildEmptyState()
            : _buildEquipmentList(),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_basketball,
                size: 80,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
            'Aucun équipement disponible',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
              'Il n\'y a actuellement aucun équipement disponible à la réservation.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
            onPressed: _loadEquipment,
            icon: const Icon(Icons.refresh),
            label: const Text('ACTUALISER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
      ),
    );
  }
  
  Widget _buildEquipmentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _equipment.length,
      itemBuilder: (context, index) {
        final equipment = _equipment[index];
        return _buildEquipmentCard(equipment);
      },
    );
  }
  
  Widget _buildEquipmentCard(Equipment equipment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: equipment.imageUrl != null && equipment.imageUrl!.isNotEmpty
                ? Image.network(
                    equipment.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: Colors.purple.withOpacity(0.2),
                        child: const Icon(
                          Icons.sports_basketball,
                          color: Colors.purple,
                          size: 50,
                        ),
                      );
                    },
                  )
                : Container(
                    height: 180,
                    color: Colors.purple.withOpacity(0.2),
                    child: const Icon(
                      Icons.sports_basketball,
                      color: Colors.purple,
                      size: 50,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipment.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (equipment.description != null && equipment.description!.isNotEmpty)
                  Text(
                    equipment.description!,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Disponible: ${equipment.availableQuantity}',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (equipment.availableQuantity > 0)
                      ElevatedButton(
                        onPressed: () => _showReservationForm(equipment),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('Réserver'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 