class ImageRecord {
  const ImageRecord({
    required this.id,
    required this.fileName,
    this.width,
    this.height,
  });

  final int id;
  final String fileName;
  final int? width;
  final int? height;
}
