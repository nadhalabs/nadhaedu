import 'package:flutter/material.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

class CmsTableColumn {
  const CmsTableColumn({
    required this.label,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
    this.width,
  });

  final String label;
  final int flex;
  final Alignment alignment;
  final double? width;
}

class CmsTableRow {
  const CmsTableRow({required this.cells, this.onTap});

  final List<Widget> cells;
  final VoidCallback? onTap;
}

class CmsDataTable extends StatelessWidget {
  const CmsDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No records found.',
  });

  final List<CmsTableColumn> columns;
  final List<CmsTableRow> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          emptyMessage,
          style: const TextStyle(color: CmsTheme.textMuted, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 650
            ? constraints.maxWidth
            : 650.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161F30),
                    border: Border(
                      bottom: BorderSide(color: CmsTheme.borderColor, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (int i = 0; i < columns.length; i++) ...[
                        if (columns[i].width != null)
                          SizedBox(
                            width: columns[i].width,
                            child: Align(
                              alignment: columns[i].alignment,
                              child: Text(
                                columns[i].label.toUpperCase(),
                                style: const TextStyle(
                                  color: CmsTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            flex: columns[i].flex,
                            child: Align(
                              alignment: columns[i].alignment,
                              child: Text(
                                columns[i].label.toUpperCase(),
                                style: const TextStyle(
                                  color: CmsTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                // Data rows
                for (int r = 0; r < rows.length; r++) ...[
                  InkWell(
                    onTap: rows[r].onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: r.isEven
                            ? Colors.transparent
                            : const Color(0xFF131A29).withValues(alpha: 0.5),
                        border: const Border(
                          bottom: BorderSide(
                            color: Color(0xFF242E42),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          for (int c = 0; c < rows[r].cells.length; c++) ...[
                            if (columns[c].width != null)
                              SizedBox(
                                width: columns[c].width,
                                child: Align(
                                  alignment: columns[c].alignment,
                                  child: rows[r].cells[c],
                                ),
                              )
                            else
                              Expanded(
                                flex: columns[c].flex,
                                child: Align(
                                  alignment: columns[c].alignment,
                                  child: rows[r].cells[c],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
