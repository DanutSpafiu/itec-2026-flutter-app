class Poster {
  final String id;
  final String name;
  final String assetPath;

  const Poster({required this.id, required this.name, required this.assetPath});

  static List<Poster> getPosters() {
    return List.generate(10, (index) {
      final number = index + 1;
      return Poster(
        id: 'afis$number',
        name: 'Afiș $number',
        assetPath: 'assets/afis$number.png',
      );
    });
  }
}
