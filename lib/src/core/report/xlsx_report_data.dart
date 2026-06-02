class XlsxSheetData {
  const XlsxSheetData({
    required this.name,
    required this.rows,
  });

  final String name;
  final List<List<Object?>> rows;
}

class XlsxWorkbookData {
  const XlsxWorkbookData({
    required this.sheets,
  });

  final List<XlsxSheetData> sheets;
}
