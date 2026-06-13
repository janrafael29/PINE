// Educational content: step-by-step and topic-based sections.
library;

import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';

class ContentSection {
  const ContentSection({
    this.number,
    required this.title,
    required this.content,
  });

  final int? number;
  final String title;
  final String content;
}

class EducationalContentScreen extends StatelessWidget {
  const EducationalContentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<ContentSection> sections;

  factory EducationalContentScreen.identifyingPineapples() {
    return const EducationalContentScreen(
      title: 'Identifying Pineapple Plants in 10 Steps',
      sections: <ContentSection>[
        ContentSection(
          number: 1,
          title: 'Examine the Leaf Shape and Size',
          content: '''
Pineapple leaves are long, narrow, and spiky, growing in a rosette pattern at the top of the plant. These stiff, sword-like leaves are a key characteristic of pineapples. They are thick and leathery, a common trait of tropical plants. If you see a plant with long, sharp leaves forming a central cluster, it's likely a pineapple.
''',
        ),
        ContentSection(
          number: 2,
          title: 'Look for the Leaf Arrangement',
          content: '''
Pineapple leaves are arranged in a spiral or rosette pattern, starting from a central crown. This unique leaf arrangement can help you differentiate a pineapple from other plants. The leaves grow in a dense cluster, pointing upward and outward, which is typical for pineapple plants.
''',
        ),
        ContentSection(
          number: 3,
          title: 'Check the Leaf Edges',
          content: '''
Pineapple leaves have sharp spines along the edges. These spines are a defense mechanism to protect the plant from herbivores. Run your finger carefully along the leaf edge (with protection!) to feel for these small but sharp spines.
''',
        ),
        ContentSection(
          number: 4,
          title: 'Observe the Central Crown',
          content: '''
The crown is the cluster of short, stiff leaves at the top of the fruit or at the center of a young plant. In a mature pineapple plant, the crown sits above the stem and is where new leaves emerge. This central growth point is a distinctive feature of pineapple plants.
''',
        ),
        ContentSection(
          number: 5,
          title: 'Look at the Plant Structure',
          content: '''
Pineapple plants have a short, thick stem that is often mostly hidden by the dense rosette of leaves. The plant grows close to the ground, with leaves that can reach one to several feet in length. The overall shape is a low, spreading rosette rather than a tall, branching structure.
''',
        ),
        ContentSection(
          number: 6,
          title: 'Check for Sucker Growth',
          content: '''
Pineapple plants produce suckers (ratoons) at the base or along the stem. These are small shoots that grow from the main plant and can be used for propagation. The presence of these offsets is a strong indicator that you are looking at a pineapple plant.
''',
        ),
        ContentSection(
          number: 7,
          title: 'Identify the Inflorescence',
          content: '''
When the plant is ready to flower, it produces a central stalk with a cluster of small purple or red flowers. After pollination, these develop into the familiar compound fruit. The flowering structure is unique to pineapple and helps confirm identification.
''',
        ),
        ContentSection(
          number: 8,
          title: 'Note the Growing Environment',
          content: '''
Pineapples are tropical or subtropical plants and thrive in warm, well-drained, slightly acidic soil. They are often found in sunny, frost-free locations. If the plant is in a suitable climate and has the leaf and structural features described, it is likely a pineapple.
''',
        ),
        ContentSection(
          number: 9,
          title: 'Compare Leaf Color and Texture',
          content: '''
Pineapple leaves are typically deep green, sometimes with reddish or bronze tints along the edges or in full sun. The surface is waxy and may feel slightly rough. This combination of color and texture helps distinguish pineapples from other bromeliads or similar plants.
''',
        ),
        ContentSection(
          number: 10,
          title: 'Confirm with Fruit (if present)',
          content: '''
The pineapple fruit is a compound fruit made of fused berries, with a rough, diamond-patterned skin and a crown of leaves on top. If you see this characteristic fruit attached to a plant matching the leaf and growth habits above, you have confidently identified a pineapple plant.
''',
        ),
      ],
    );
  }

  factory EducationalContentScreen.whyDifferent() {
    return const EducationalContentScreen(
      title: 'Why the Same Pineapple Can Look Different',
      sections: <ContentSection>[
        ContentSection(
          title: 'Genetics',
          content: '''
Even within a single variety of pineapple, genetic differences can cause variations in size, shape, and color. Different plants may exhibit subtle differences in fruit appearance due to inherited traits passed down from the parent plant.
''',
        ),
        ContentSection(
          title: 'Growing Conditions',
          content: '''
Factors like soil quality, climate, water, and sunlight can all affect how a pineapple grows. For example, pineapples grown in more shaded areas may be smaller and less vibrant in color than those grown in full sunlight. Water availability and temperature fluctuations can also impact the size and color of the fruit.
''',
        ),
        ContentSection(
          title: 'Ripeness',
          content: '''
The stage at which a pineapple is harvested influences its appearance. A pineapple picked too early may have a greenish tint, while one left to ripen fully on the plant will develop a golden-yellow color. The ripeness also affects the fruit's texture, size, and shape.
''',
        ),
        ContentSection(
          title: 'Environmental Stress',
          content: '''
Stressors such as drought, pest damage, or temperature extremes can cause pineapples to develop irregularities. For instance, pineapples exposed to excessive heat may develop sunburn or uneven coloration. In contrast, those stressed by lack of water may be smaller or misshapen.
''',
        ),
      ],
    );
  }

  factory EducationalContentScreen.speciesDifferences() {
    return const EducationalContentScreen(
      title: 'Difference Between Species of Pineapples',
      sections: <ContentSection>[
        ContentSection(
          title: 'Ananas comosus',
          content: '''
Ananas comosus is the most commercially grown pineapple species. The fruit is typically large, cylindrical, with a rough, spiny outer skin and a sweet, juicy interior. When ripe, the skin changes from green to yellow or golden. Its taste is sweet, with a slight tanginess, and the plant's leaves are long, spiky, and arranged in a rosette pattern.

Among the varieties of Ananas comosus, there is Red Spanish, known for being more acidic with smaller fruit, and Queen, which is smaller and sweeter with a denser texture.
''',
        ),
        ContentSection(
          title: 'Ananas bracteatus (Pink Pineapple)',
          content: '''
Ananas bracteatus, often called the Pink Pineapple or Red Pineapple, is a smaller species known for its unique pinkish or reddish fruit. The fruit of this species is oval-shaped and changes to a pink or red color when ripe. It tends to be sweeter than the common pineapple and has a mild acidity. The leaves are similar to those of A. comosus, but with a reddish tinge at the tips. This species is often grown as a novelty due to its striking color and flavor.
''',
        ),
        ContentSection(
          title: 'Ananas lucidus',
          content: '''
Ananas lucidus is a wild species found in the rainforests of South America, primarily in the Amazon Basin. The fruit of Ananas lucidus is smaller and more acidic than the varieties typically cultivated. It has a greenish-yellow color and is less commonly found in commercial markets.
''',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sections.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildSection(context, sections[index], index + 1);
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, ContentSection section, int index) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (section.number != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${section.number}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
