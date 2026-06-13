// Category-based disease list with description and related disease links.
library;

import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';
import 'disease_detail_screen.dart';

class DiseaseByCategoryScreen extends StatelessWidget {
  const DiseaseByCategoryScreen({
    super.key,
    required this.category,
    required this.description,
    required this.diseases,
  });

  final String category;
  final String description;
  final List<Map<String, dynamic>> diseases;

  factory DiseaseByCategoryScreen.wholePlant() {
    return DiseaseByCategoryScreen(
      category: 'Disease of the Whole Plant',
      description: '''
Pineapple plants affected by whole-plant diseases often show widespread symptoms that indicate poor health. One such disease is Phytophthora Root Rot, a fungal condition that thrives in poorly drained soils. The infection spreads through the roots, causing stunted growth, yellowing leaves, and plant collapse.

Environmental factors such as drought or nutrient deficiencies can exacerbate these conditions, weakening the plant further. Preventive measures like improving soil drainage, using resistant varieties, and timely application of fungicides can reduce the risk of such diseases.
''',
      diseases: <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Phytophthora Root Rot',
          'screen': DiseaseDetailScreen.heartRot()
        },
        <String, dynamic>{
          'name': 'Fusariosis',
          'screen': DiseaseDetailScreen.fusariosis()
        },
      ],
    );
  }

  factory DiseaseByCategoryScreen.fruit() {
    return const DiseaseByCategoryScreen(
      category: 'Disease by Fruit',
      description: '''
A common problem is Fruit Cracking, which results from abrupt changes in moisture levels, often due to uneven irrigation or excessive rainfall. Cracked fruits are prone to secondary infections. Proper irrigation schedules, careful handling during harvest, and protective field practices help prevent these issues and maintain fruit quality.
''',
      diseases: <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Fruit Cracking', 'screen': null},
      ],
    );
  }

  factory DiseaseByCategoryScreen.leaves() {
    return DiseaseByCategoryScreen(
      category: 'Disease by Leaves',
      description: '''
Leaf diseases are among the most visible and destructive problems in pineapple cultivation. Yellow Spot Virus, for example, causes streaks or bands of yellowing that spread across the leaf surface. This often leads to curling and weakening of the leaf structure.

Anthracnose, a fungal infection, results in brown sunken spots that grow larger over time. If untreated, these spots can merge, causing large portions of the leaf to die. Proper field hygiene, removing infected leaves, and using fungicides can help control the spread. Maintaining healthy soil conditions is also crucial for preventing leaf-specific diseases.
''',
      diseases: <Map<String, dynamic>>[
        const <String, dynamic>{'name': 'Yellow Spot Virus', 'screen': null},
        <String, dynamic>{
          'name': 'Anthracnose',
          'screen': DiseaseDetailScreen.anthracnose()
        },
      ],
    );
  }

  factory DiseaseByCategoryScreen.pests() {
    return DiseaseByCategoryScreen(
      category: 'Disease caused by Pests',
      description: '''
Pests like Mealybugs and Pineapple Red Mites are notorious for damaging pineapple plants. Mealybugs feed on sap, causing leaves to yellow and wilt. These pests also act as vectors for viral diseases, further harming the plant. Pineapple Red Mites, on the other hand, cause reddish-brown discoloration on leaves, reducing their ability to photosynthesize.

Visible symptoms include pest clusters, curling leaves, and a general decline in plant health. Effective pest management includes introducing natural predators, like ladybugs, applying organic sprays, and monitoring pest activity regularly to prevent infestations from spreading.
''',
      diseases: <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Mealybug Infestation',
          'screen': DiseaseDetailScreen.mealybugWilt()
        },
        const <String, dynamic>{'name': 'Pineapple Red Mites', 'screen': null},
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> actionableDiseases = diseases
        .where((Map<String, dynamic> d) => d['screen'] != null)
        .toList(growable: false);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return AppScaffold(
      titleWidget: Text(
        category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (actionableDiseases.isNotEmpty) ...[
              Text(
                'Related Diseases',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...actionableDiseases.map(
                (Map<String, dynamic> d) => _buildDiseaseTile(context, d),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseTile(BuildContext context, Map<String, dynamic> disease) {
    final Widget? screen = disease['screen'] as Widget?;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          disease['name'] as String,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: screen != null
            ? () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => screen,
                  ),
                );
              }
            : null,
      ),
    );
  }
}
