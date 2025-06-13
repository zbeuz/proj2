import 'package:flutter/material.dart';
import '../models/facility.dart';
import '../models/reservation.dart';
import '../services/api_service.dart';
import 'base_screen.dart';
import 'package:intl/intl.dart';

class FacilitiesScreen extends StatefulWidget {
  const FacilitiesScreen({Key? key}) : super(key: key);

  @override
  _FacilitiesScreenState createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  bool _isLoading = false;
  List<Facility> _terrains = [];
  final ApiService _apiService = ApiService();
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 11, minute: 0);
  
  // Mode de réservation (journée ou plusieurs jours)
  bool _isMultiDayMode = false;
  
  // Liste des heures disponibles (8h à 22h)
  final List<int> _availableHours = List.generate(15, (index) => index + 8); // 8h à 22h
  
  @override
  void initState() {
    super.initState();
    _loadTerrains();
  }
  
  Future<void> _loadTerrains() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final terrains = await _apiService.getTerrains();
      setState(() {
        _terrains = terrains.where((terrain) => terrain.isAvailable).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des terrains: $e')),
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
  
  // Convertir TimeOfDay en DateTime
  DateTime _timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }
  
  Future<void> _reserveFacility(Facility facility) async {
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
    
    if (_isMultiDayMode) {
      // En mode multi-jours, on utilise les dates complètes
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
          const SnackBar(content: Text('La date de fin doit être après la date de début')),
        );
        return;
      }
    } else {
      // En mode jour unique, c'est une réservation sur la même journée
      startDateTime = _timeOfDayToDateTime(_selectedStartDate, _startTime);
      endDateTime = _timeOfDayToDateTime(_selectedStartDate, _endTime);
    }
    
    // Formater les DateTime pour l'API
    final formattedStartTime = startDateTime.toIso8601String();
    final formattedEndTime = endDateTime.toIso8601String();
    
    // Créer la réservation
    final reservation = Reservation(
      id: 0, // Sera assigné par le serveur
      userId: 0, // Sera rempli par le serveur en fonction du token
      facilityId: facility.id,
      date: DateFormat('yyyy-MM-dd').format(_selectedStartDate), // Pour la compatibilité du modèle
      status: 'Confirmée',
      // Ces champs seront transformés par le service API
      startTime: DateFormat('HH:mm:ss').format(startDateTime),
      endTime: DateFormat('HH:mm:ss').format(endDateTime),
    );
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      await _apiService.createReservation(reservation);
      
      // Recharger les terrains pour mettre à jour la disponibilité
      await _loadTerrains();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Réservation du terrain ${facility.name} confirmée')),
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
  
  // Nouvelle méthode pour afficher le popup de réservation
  void _showReservationForm(Facility facility) {
    // Variables locales pour contrôler le formulaire de dialogue
    bool localIsMultiDayMode = _isMultiDayMode;
    DateTime localStartDate = _selectedStartDate;
    DateTime localEndDate = _selectedEndDate;
    int localStartHour = _startTime.hour;
    int localStartMinute = _startTime.minute;
    int localEndHour = _endTime.hour;
    int localEndMinute = _endTime.minute;
    
    // S'assurer que les heures sont valides
    if (localStartHour < 8) localStartHour = 8;
    if (localStartHour > 21) localStartHour = 21;
    if (localEndHour < 9) localEndHour = 9;
    if (localEndHour > 22) localEndHour = 22;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Réserver ${facility.name}', style: const TextStyle(color: Colors.white)),
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
                        value: localIsMultiDayMode,
                        onChanged: (value) {
                          setState(() {
                            localIsMultiDayMode = value;
                          });
                        },
                        activeColor: Colors.orange,
                      ),
                      Text(
                        localIsMultiDayMode ? 'Plusieurs jours' : 'Journée',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Date et heure selon le mode
                  if (localIsMultiDayMode)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date de début
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date de début', style: TextStyle(color: Colors.white)),
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
                              style: const TextStyle(color: Colors.orange),
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
                          Colors.orange,
                        ),
                        
                        // Date de fin
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date de fin', style: TextStyle(color: Colors.white)),
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
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
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
                          Colors.orange,
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
                              style: const TextStyle(color: Colors.orange),
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
                          Colors.orange,
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
                          Colors.orange,
                        ),
                      ],
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
                _isMultiDayMode = localIsMultiDayMode;
                _selectedStartDate = localStartDate;
                _selectedEndDate = localEndDate;
                _startTime = TimeOfDay(hour: localStartHour, minute: localStartMinute);
                _endTime = TimeOfDay(hour: localEndHour, minute: localEndMinute);
              });
              
              _reserveFacility(facility);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Réserver'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Terrains',
      currentIndex: 3,
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : _terrains.isEmpty
            ? _buildEmptyState()
            : _buildTerrainsList(),
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
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.stadium,
              size: 80,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun terrain disponible',
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
              'Il n\'y a actuellement aucun terrain disponible à la réservation.',
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
            onPressed: _loadTerrains,
            icon: const Icon(Icons.refresh),
            label: const Text('ACTUALISER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
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
  
  Widget _buildTerrainsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _terrains.length,
      itemBuilder: (context, index) {
        final terrain = _terrains[index];
        return _buildTerrainCard(terrain);
      },
    );
  }
  
  Widget _buildTerrainCard(Facility terrain) {
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
            child: terrain.imageUrl != null && terrain.imageUrl!.isNotEmpty
                ? Image.network(
                    terrain.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: Colors.orange.withOpacity(0.2),
                        child: const Icon(
                          Icons.stadium,
                          color: Colors.orange,
                          size: 50,
                        ),
                      );
                    },
                  )
                : Container(
                    height: 180,
                    color: Colors.orange.withOpacity(0.2),
                    child: const Icon(
                      Icons.stadium,
                      color: Colors.orange,
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
                  terrain.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (terrain.description != null && terrain.description!.isNotEmpty)
                  Text(
                    terrain.description!,
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
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        terrain.isAvailable ? 'Disponible' : 'Non disponible',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (terrain.isAvailable)
                      ElevatedButton(
                        onPressed: () => _showReservationForm(terrain),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
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