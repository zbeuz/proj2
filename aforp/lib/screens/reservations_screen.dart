import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/api_service.dart';
import 'base_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({Key? key}) : super(key: key);

  @override
  _ReservationsScreenState createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Reservation> _reservations = [];
  
  @override
  void initState() {
    super.initState();
    _loadReservations();
  }
  
  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch real reservations from the API
      final reservations = await _apiService.getUserReservations();
      
      setState(() {
        _isLoading = false;
        // Filtrer pour ne pas inclure les réservations annulées
        _reservations = reservations.where((res) => 
          !res.status.toLowerCase().contains('annul') && 
          !res.status.toLowerCase().contains('cancel')
        ).toList();
      });
    } catch (e) {
      print('Error loading reservations: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des réservations.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Mes Réservations',
      currentIndex: 0,
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _reservations.isEmpty
            ? _buildEmptyState()
            : _buildReservationsList();
  }
  
  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadReservations,
      color: Theme.of(context).primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune réservation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous n\'avez pas encore de réservations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/courses');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Réserver un cours'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C64F4),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReservationsList() {
    return RefreshIndicator(
      onRefresh: _loadReservations,
      color: Theme.of(context).primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservations.length,
        itemBuilder: (context, index) {
          final reservation = _reservations[index];
          return _buildReservationCard(reservation);
        },
      ),
    );
  }
  
  Widget _buildReservationCard(Reservation reservation) {
    final String title = reservation.getTitle();
    final String subtitle = reservation.type ?? 'Réservation';
    
    // Normalize status for comparison
    final String normalizedStatus = reservation.status.toLowerCase();
    
    final Color statusColor = normalizedStatus.contains('confirm') 
        ? Colors.green 
        : normalizedStatus.contains('attente') || normalizedStatus.contains('pending')
            ? Colors.orange 
            : normalizedStatus.contains('annul') || normalizedStatus.contains('cancel')
                ? Colors.red
                : Colors.grey;
    
    final IconData typeIcon = reservation.getIcon();
    final Color typeColor = reservation.getColor();
    
    final DateTime reservationDate = DateTime.parse(reservation.date);
    final String formattedDate = '${reservationDate.day}/${reservationDate.month}/${reservationDate.year}';
    
    // Déterminer s'il faut afficher des dates spéciales pour les équipements
    final bool hasPickupReturn = reservation.isEquipmentReservation && 
        reservation.pickupDate != null && 
        reservation.returnDate != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                typeIcon,
                color: typeColor,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Afficher la quantité si c'est une réservation d'équipement
                if (reservation.isEquipmentReservation && reservation.equipmentQuantity != null && reservation.equipmentQuantity! > 1)
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Quantité: ${reservation.equipmentQuantity}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                
                if (reservation.isEquipmentReservation && reservation.equipmentQuantity != null && reservation.equipmentQuantity! > 1)
                  const SizedBox(height: 8),
                
                // Date et heure standard ou dates spéciales pour les équipements
                if (hasPickupReturn)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Retrait: ${_formatDate(reservation.pickupDate!)} • ${reservation.startTime}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Retour: ${_formatDate(reservation.returnDate!)} • ${reservation.endTime}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timelapse,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Durée: ${reservation.getDuration()}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${formattedDate} • ${reservation.startTime}-${reservation.endTime}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reservation.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => _showReservationOptions(reservation),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Future<void> _cancelReservation(Reservation reservation) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      print('Annulation de la réservation ID: ${reservation.id}');
      
      // Call the API to cancel the reservation
      await _apiService.cancelReservation(reservation.id);
      
      // Refresh the list of reservations
      await _loadReservations();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Réservation annulée avec succès.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error canceling reservation: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Extract the error message from the exception
      final String errorMessage = e.toString().contains('Exception:') 
          ? e.toString().split('Exception:')[1].trim() 
          : 'Erreur lors de l\'annulation de la réservation.';
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _showReservationOptions(Reservation reservation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('Détails', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showReservationDetails(reservation);
                },
              ),
              if (reservation.status != 'Annulée')
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  title: const Text('Annuler', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCancelConfirmation(reservation);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCancelConfirmation(Reservation reservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Annuler la réservation', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette réservation ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelReservation(reservation);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showReservationDetails(Reservation reservation) {
    String title = reservation.getTitle();
    String type = reservation.type ?? 'Réservation';
    String date = reservation.date;
    String time = '${reservation.startTime} - ${reservation.endTime}';
    
    // Données supplémentaires pour les réservations d'équipement
    String? quantity = reservation.equipmentQuantity != null ? 
        reservation.equipmentQuantity.toString() : null;
    String? pickupDate = reservation.pickupDate;
    String? returnDate = reservation.returnDate;
    String? duration = reservation.getDuration();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Détails de la réservation', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Titre', title),
              _buildDetailRow('Type', type),
              
              if (reservation.isEquipmentReservation && pickupDate != null && returnDate != null) ...[
                _buildDetailRow('Date de retrait', _formatDate(pickupDate)),
                _buildDetailRow('Heure de retrait', reservation.startTime ?? ''),
                _buildDetailRow('Date de retour', _formatDate(returnDate)),
                _buildDetailRow('Heure de retour', reservation.endTime ?? ''),
                if (quantity != null) _buildDetailRow('Quantité', quantity),
                _buildDetailRow('Durée', duration),
              ] else ...[
                _buildDetailRow('Date', date),
                _buildDetailRow('Heure', time),
                if (quantity != null) _buildDetailRow('Quantité', quantity),
              ],
              
              _buildDetailRow('Statut', reservation.status),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}