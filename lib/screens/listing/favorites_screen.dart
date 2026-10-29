import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/listing_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/marketplace_extension_service.dart';
import '../../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final user = auth.userModel;
    final extService = MarketplaceExtensionService();

    final title = locale.isAmharic ? 'የተወደዱ ዕቃዎች' : 'Saved Favorites';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
      body: user == null || user.favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      size: 54,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locale.isAmharic ? 'ምንም የተወደዱ ዕቃዎች የሉም' : 'No Saved Favorites Yet',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    locale.isAmharic
                        ? 'በዕቃዎች ላይ የልብ ምልክቷን (❤️) በመንካት እዚህ ያስቀምጡ።'
                        : 'Tap the heart icon (❤️) on any listing to save it here for later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            )
          : StreamBuilder<List<ListingModel>>(
              stream: extService.getFavoriteListingsStream(user.favorites),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      locale.isAmharic
                          ? 'የተቀመጡት ዕቃዎች ተሽጠዋል ወይም ተሰርዘዋል።'
                          : 'Your saved items have been sold or removed.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final listing = items[index];
                    return ListingCard(
                      listing: listing,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListingDetailScreen(listingId: listing.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
