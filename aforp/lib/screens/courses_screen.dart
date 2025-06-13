import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/course.dart';
import '../models/reservation.dart';
import '../services/api_service.dart';
import 'base_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({Key? key}) : super(key: key);

  @override
  _CoursesScreenState createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Course> _courses = [];
  List<Course> _filteredCourses = [];
  List<String> _categories = ['Tous', 'Fitness', 'Yoga', 'Sport collectif', 'Aquatique'];
  String _selectedCategory = 'Tous';
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadCourses();
  }
  
  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final courses = await _apiService.getCourses();
      
      setState(() {
        _isLoading = false;
        _courses = courses;
        _filterCourses();
      });
    } catch (e) {
      print('Erreur lors du chargement des cours: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des cours: $e')),
      );
    }
  }
  
  void _filterCourses() {
    setState(() {
      if (_selectedCategory == 'Tous' && _searchQuery.isEmpty) {
        _filteredCourses = List.from(_courses);
      } else {
        _filteredCourses = _courses.where((course) {
          bool matchesCategory = _selectedCategory == 'Tous' || 
              (course.name.toLowerCase().contains(_selectedCategory.toLowerCase()));
          
          bool matchesSearch = _searchQuery.isEmpty || 
              course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              course.description.toLowerCase().contains(_searchQuery.toLowerCase());
          
          return matchesCategory && matchesSearch;
        }).toList();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Cours',
      currentIndex: 1,
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 24),
          _buildCategoryFilter(),
          const SizedBox(height: 24),
          const Text(
            'Cours disponibles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCourses.isEmpty
                    ? _buildEmptyState()
                    : _buildCoursesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Rechercher un cours...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _filterCourses();
          });
        },
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _filterCourses();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3C64F4) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF3C64F4).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports, 
            size: 80, 
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun cours trouvé',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos critères de recherche',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadCourses,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3C64F4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return RefreshIndicator(
      onRefresh: _loadCourses,
      color: const Color(0xFF3C64F4),
      child: ListView.builder(
        itemCount: _filteredCourses.length,
      itemBuilder: (context, index) {
          final course = _filteredCourses[index];
          // Choisir une couleur selon le nom du cours
          final color = _getCourseColor(course.name);
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
              ),
            elevation: 4,
          child: InkWell(
              onTap: () => _showCourseDetails(course),
            borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Image ou bannière colorée
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: course.imageUrl != null && course.imageUrl!.isNotEmpty
                      ? Image.network(
                          course.imageUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150,
                            color: color,
                            child: Center(
                              child: Icon(
                                _getCourseIcon(course.name),
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 150,
                          color: color,
                          child: Center(
                            child: Icon(
                              _getCourseIcon(course.name),
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                ),
                  
                  // Informations du cours
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre et badge de disponibilité
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                course.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: course.availableSpots > 0
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: course.availableSpots > 0 ? Colors.green : Colors.red,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                course.availableSpots > 0 ? 'Disponible' : 'Complet',
                                style: TextStyle(
                                  color: course.availableSpots > 0 ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description
                        Text(
                          course.description,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Informations supplémentaires
                        Column(
                          children: [
                            // Première ligne avec les infos
                            Row(
                              children: [
                                Flexible(
                                  child: _buildInfoChip(Icons.access_time, '${course.duration} min'),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: _buildInfoChip(Icons.people, '${course.availableSpots}/${course.maxCapacity}'),
                                ),
                                if (course.price != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: _buildInfoChip(Icons.euro, '${course.price} €'),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Deuxième ligne avec le bouton
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: course.availableSpots > 0 
                                  ? () => _showReservationDialog(course) 
                                  : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3C64F4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  course.availableSpots > 0 ? 'Réserver' : 'Complet',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Équipements (si présents)
                        if (course.equipment != null && course.equipment!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'Équipements:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: course.equipment!.map((e) => 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${e.equipmentName ?? 'Équipement'} (x${e.quantity})',
                                  style: TextStyle(
                                    color: Colors.grey.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            ).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
                              ),
                            ),
                          ],
                        ),
    );
  }
  
  Color _getCourseColor(String courseName) {
    final name = courseName.toLowerCase();
    if (name.contains('yoga') || name.contains('pilates') || name.contains('méditation')) {
      return Colors.purple;
    } else if (name.contains('fitness') || name.contains('cardio') || name.contains('hiit')) {
      return Colors.red;
    } else if (name.contains('natation') || name.contains('aqua')) {
      return Colors.blue;
    } else if (name.contains('football') || name.contains('basket') || name.contains('volley')) {
      return Colors.green;
    } else if (name.contains('danse') || name.contains('zumba')) {
      return Colors.orange;
    } else {
      return Colors.teal;
    }
  }
  
  IconData _getCourseIcon(String courseName) {
    final name = courseName.toLowerCase();
    if (name.contains('yoga') || name.contains('pilates') || name.contains('méditation')) {
      return Icons.self_improvement;
    } else if (name.contains('fitness') || name.contains('cardio') || name.contains('hiit')) {
      return Icons.fitness_center;
    } else if (name.contains('natation') || name.contains('aqua')) {
      return Icons.pool;
    } else if (name.contains('football') || name.contains('basket') || name.contains('volley')) {
      return Icons.sports_basketball;
    } else if (name.contains('danse') || name.contains('zumba')) {
      return Icons.music_note;
    } else {
      return Icons.sports;
    }
  }
  
  void _showCourseDetails(Course course) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du cours si disponible
              if (course.imageUrl != null && course.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    course.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      width: double.infinity,
                      color: _getCourseColor(course.name),
                      child: Icon(
                        _getCourseIcon(course.name),
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _getCourseColor(course.name),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCourseIcon(course.name),
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              const SizedBox(height: 20),
              
              Text(
                course.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                course.description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Informations importantes
              _buildInfoRow(Icons.access_time, 'Durée:', '${course.duration} minutes'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.people, 'Places:', '${course.availableSpots}/${course.maxCapacity}'),
              if (course.price != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildInfoRow(Icons.euro, 'Prix:', '${course.price} €'),
                ),
              if (course.facilityName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildInfoRow(Icons.location_on, 'Lieu:', course.facilityName!),
                ),
              
              // Équipements
              if (course.equipment != null && course.equipment!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Équipements:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...course.equipment!.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildInfoRow(
                    Icons.fitness_center, 
                    e.equipmentName ?? 'Équipement #${e.equipmentId}', 
                    'Quantité: ${e.quantity}'
                  ),
                )).toList(),
              ],
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: course.availableSpots > 0 
                        ? () {
                            Navigator.pop(context);
                            _showReservationDialog(course);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C64F4),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: const Text('Réserver'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
  
  void _showReservationDialog(Course course) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    
    // Calcul de l'heure de fin en ajoutant la durée du cours
    final int durationInMinutes = course.duration;
    final int startMinutes = startTime.hour * 60 + startTime.minute;
    final int endMinutes = startMinutes + durationInMinutes;
    var endTime = TimeOfDay(
      hour: endMinutes ~/ 60 % 24,
      minute: endMinutes % 60,
    );
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Réserver ${course.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélection de la date
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                    
                    // Sélection de l'heure de début
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Heure de début'),
                      subtitle: Text(startTime.format(context)),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (pickedTime != null) {
                          setState(() {
                            startTime = pickedTime;
                            // Recalculer l'heure de fin
                            final int newStartMinutes = pickedTime.hour * 60 + pickedTime.minute;
                            final int newEndMinutes = newStartMinutes + durationInMinutes;
                            endTime = TimeOfDay(
                              hour: newEndMinutes ~/ 60 % 24,
                              minute: newEndMinutes % 60,
                            );
                          });
                        }
                      },
                    ),
                    
                    // Affichage de l'heure de fin (calculée, non modifiable)
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Heure de fin (calculée)'),
                      subtitle: Text(endTime.format(context)),
                      enabled: false,
                    ),
                    
                    // Informations sur le cours
                    const Divider(),
                    Text('Places disponibles: ${course.availableSpots}/${course.maxCapacity}'),
                    if (course.price != null)
                      Text('Prix: ${course.price} €'),
                    if (course.facilityName != null)
                      Text('Lieu: ${course.facilityName}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => _reserveCourse(context, course, selectedDate, startTime, endTime),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3C64F4),
                  ),
                  child: const Text('Réserver'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Future<void> _reserveCourse(
    BuildContext context, 
    Course course, 
    DateTime selectedDate, 
    TimeOfDay startTime, 
    TimeOfDay endTime
  ) async {
    // Convertir TimeOfDay en DateTime complet
    final DateTime startDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startTime.hour,
      startTime.minute,
    );
    
    final DateTime endDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      endTime.hour,
      endTime.minute,
    );
    
    // Créer l'objet de réservation
    final reservation = Reservation(
      id: 0, // Sera assigné par le serveur
      userId: 0, // Sera rempli par le serveur en fonction du token
      courseId: course.id,
      date: DateFormat('yyyy-MM-dd').format(selectedDate),
      startTime: DateFormat('HH:mm:ss').format(startDateTime),
      endTime: DateFormat('HH:mm:ss').format(endDateTime),
      status: 'Confirmée',
      courseTitle: course.name,
    );
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Fermer le dialogue
      Navigator.pop(context);
      
      // Créer la réservation via l'API
      await _apiService.createReservation(reservation);
      
      // Recharger les cours pour mettre à jour les places disponibles
      await _loadCourses();
      
      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Réservation du cours ${course.name} confirmée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la réservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 