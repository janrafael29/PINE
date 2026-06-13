// Base disease detail screen with title, subtitle, content, optional image.
library;

import 'package:flutter/material.dart';

import '../core/more_tab_images.dart';
import '../core/theme.dart';

class DiseaseDetailScreen extends StatelessWidget {
  const DiseaseDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    this.imageDescription,
  });

  final String title;
  final String subtitle;
  final String content;
  final String? imageDescription;

  factory DiseaseDetailScreen.mealybugWilt() {
    return const DiseaseDetailScreen(
      title: 'Mealybug Infestation',
      subtitle: 'Mealybug Wilt of Pineapple (MWOP)',
      content: '''
Mealybug wilt is closely linked to heavy infestations of mealybugs, which transmit closteroviruses that cause plant wilt and discoloration. Infected plants exhibit curling, reddening, and wilting of leaves, resulting in reduced vigor and stunted growth. The condition significantly affects the plant's ability to photosynthesize, leading to poor fruit quality and decreased yields.

It poses several challenges. The mealybugs involved thrive in unsanitary farming conditions and on weeds, making control labor-intensive and costly. Additionally, symptoms often mimic those of nutrient deficiencies or environmental stress, making early detection and accurate diagnosis difficult. Over time, affected plants become increasingly unproductive, leading to a cycle of declining crop health and reduced profitability for farmers.
''',
      imageDescription: 'Image of a mealybug infestation on pineapple',
    );
  }

  factory DiseaseDetailScreen.heartRot() {
    return const DiseaseDetailScreen(
      title: 'Heart Rot',
      subtitle: 'Phytophthora spp.',
      content: '''
Heart rot is a destructive disease caused by water molds from the genus Phytophthora. It primarily affects the plant's central growing point, leading to the collapse of young leaves and ultimately the death of the plant. The disease is often associated with poorly drained soils and prolonged periods of waterlogging, which provide the ideal conditions for the pathogen to thrive. Early signs include yellowing and browning of leaves at the plant's center, followed by a foul smell from decaying tissue as the infection progresses.

This disease causes severe issues for pineapple cultivation. First, the infection compromises the structural integrity of the plant, as the central growing point is critical for the plant's development and fruit production. Second, the pathogen spreads rapidly in poorly managed fields, especially those with excessive moisture, making effective management difficult. Lastly, if not controlled early, heart rot can devastate entire crops, leading to significant financial losses for farmers due to reduced yields and the cost of soil and drainage remediation.
''',
      imageDescription: 'Image of heart rot affected pineapple',
    );
  }

  factory DiseaseDetailScreen.fusariosis() {
    return const DiseaseDetailScreen(
      title: 'Fusariosis',
      subtitle: 'Fusarium subglutinans f. sp. ananas',
      content: '''
Fusariosis, caused by the fungus Fusarium subglutinans f. sp. ananas, is a significant fungal disease that primarily affects pineapple plants, targeting the fruit, crown, and leaves. The disease thrives in humid and warm environments, where it spreads easily through several means, including contaminated soil, plant debris, and infected planting materials. Spores produced by the fungus are highly resilient and can persist in the soil for years, making eradication efforts challenging. When the disease takes hold, it manifests as brown or black lesions on the fruit, internal rot, and poor overall plant development, significantly reducing the quality and marketability of the pineapples.

This leads to direct financial losses for farmers as the affected fruits are unfit for sale. Furthermore, the fungus's ability to survive in the soil and infect subsequent crops requires long-term crop rotation strategies to control its spread. To manage fusariosis, farmers often resort to frequent fungicide applications, which can raise production costs and may have environmental consequences if overused. The combination of persistent fungal spores, the challenges of controlling its spread, and the need for costly treatments makes fusariosis a serious and ongoing issue for pineapple farmers.
''',
      imageDescription: 'Image of fusariosis affected fruit',
    );
  }

  factory DiseaseDetailScreen.anthracnose() {
    return const DiseaseDetailScreen(
      title: 'Pineapple Anthracnose',
      subtitle: 'Colletotrichum gloeosporioides',
      content: '''
Anthracnose is a fungal disease caused by Colletotrichum gloeosporioides, which affects various parts of the pineapple plant, including leaves, stems, flowers, and fruits. It thrives in warm, humid environments and is most commonly observed during periods of heavy rainfall. The disease manifests as dark, sunken lesions on leaves and fruits. In severe cases, these lesions can coalesce, leading to extensive tissue damage. On fruits, anthracnose appears as black, water-soaked spots that can spread rapidly during ripening or storage. The disease can significantly reduce the quality and marketability of the pineapple.

The challenges posed by anthracnose are substantial. First, the disease directly affects the visual and structural quality of pineapples, making infected fruits unsuitable for sale and consumption. This has a severe economic impact on farmers and exporters. Second, anthracnose spores are easily spread by rain splashes, wind, or contaminated tools, making it difficult to contain the disease in wet climates or during the rainy season. Finally, controlling the disease requires frequent fungicide applications, which can increase production costs and raise concerns about fungicide resistance or residue levels in the harvested fruit.
''',
      imageDescription: 'Image of anthracnose affected leaves',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.primaryGreen,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: AssetManifestCache.ensure(context),
              builder: (BuildContext context,
                  AsyncSnapshot<Map<String, dynamic>> snapshot) {
                final String? assetPath = snapshot.hasData
                    ? moreTabImageForTitle(snapshot.data!, title)
                    : null;
                return Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (assetPath != null)
                        Image.asset(
                          assetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (BuildContext context, Object error,
                              StackTrace? stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 64,
                                color: AppTheme.textMedium,
                              ),
                            );
                          },
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      if (imageDescription != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              imageDescription!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              content,
              style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Management Tips',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '• Improve soil drainage\n'
                      '• Use resistant varieties\n'
                      '• Practice crop rotation\n'
                      '• Apply fungicides as needed\n'
                      '• Maintain field hygiene',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
