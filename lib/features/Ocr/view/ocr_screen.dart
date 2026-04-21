import 'dart:io';

import 'package:financy_ui/features/Ocr/services/receipt_ocr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _picker = ImagePicker();
  final _service = ReceiptOcrService();
  File? _image;
  ParsedReceipt? _result;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _result = null;
      _err = null;
      _busy = true;
    });
    try {
      final parsed = await _service.recognize(picked.path);
      if (!mounted) return;
      setState(() => _result = parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Quét hóa đơn (OCR)'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Chụp'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed:
                        _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.image),
                    label: const Text('Thư viện'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 220, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_err != null)
              Text('Lỗi: $_err', style: const TextStyle(color: Colors.red)),
            if (_result != null) _buildResult(theme, _result!),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, ParsedReceipt r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kết quả', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (r.bestAmount != null)
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.green),
              title: Text(
                'Số tiền có thể: ${r.bestAmount!.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: r.amountCandidates.length > 1
                  ? Text('Khác: ${r.amountCandidates.skip(1).take(3).map((e) => e.toStringAsFixed(0)).join(', ')}')
                  : null,
            ),
          ),
        if (r.date != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Ngày: ${r.date!.toLocal().toString().split(' ').first}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy toàn bộ văn bản'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: r.rawText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã copy văn bản')),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            r.rawText.isEmpty ? '(không nhận diện được chữ)' : r.rawText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}
