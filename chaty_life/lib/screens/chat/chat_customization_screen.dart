import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/chat_theme_model.dart';
import '../../services/chat_theme_service.dart';

class ChatCustomizationScreen extends StatefulWidget {
  final String chatId;
  final ChatTheme? currentTheme;

  const ChatCustomizationScreen({
    super.key,
    required this.chatId,
    this.currentTheme,
  });

  @override
  State<ChatCustomizationScreen> createState() => _ChatCustomizationScreenState();
}

class _ChatCustomizationScreenState extends State<ChatCustomizationScreen> {
  final _themeService = ChatThemeService();
  Color? _myBubbleColor;
  Color? _otherBubbleColor;
  Color? _myTextColor;
  Color? _otherTextColor;
  String? _wallpaperPath;
  BoxFit _wallpaperFit = BoxFit.cover;
  bool _isLoading = false;

  // Colores predefinidos para elegir
  final List<Color> _presetColors = [
    Colors.white,
    Colors.black,
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.brown,
    Colors.grey,
    Colors.deepPurple,
    Colors.lightBlue,
  ];

  // Opciones de ajuste del wallpaper
  final Map<BoxFit, String> _wallpaperFitOptions = {
    BoxFit.cover: 'Cubrir (Cover)',
    BoxFit.contain: 'Contener (Contain)',
    BoxFit.fill: 'Llenar (Fill)',
    BoxFit.fitWidth: 'Ajustar ancho',
    BoxFit.fitHeight: 'Ajustar alto',
    BoxFit.none: 'Ninguno',
    BoxFit.scaleDown: 'Reducir',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  Future<void> _loadCurrentTheme() async {
    final theme = widget.currentTheme;
    if (theme != null) {
      setState(() {
        _myBubbleColor = theme.myBubbleColor;
        _otherBubbleColor = theme.otherBubbleColor;
        _myTextColor = theme.myTextColor;
        _otherTextColor = theme.otherTextColor;
        _wallpaperPath = theme.wallpaperPath;
        _wallpaperFit = theme.wallpaperFit ?? BoxFit.cover;
      });
    }
  }

  Future<void> _selectWallpaper() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;

      setState(() => _isLoading = true);

      // Copiar la imagen a un directorio persistente
      final appDir = await getApplicationDocumentsDirectory();
      final chatThemesDir = Directory('${appDir.path}/chat_themes');
      if (!await chatThemesDir.exists()) {
        await chatThemesDir.create(recursive: true);
      }

      final fileName = '${widget.chatId}_wallpaper.jpg';
      final savedImage = File('${chatThemesDir.path}/$fileName');
      await File(image.path).copy(savedImage.path);

      setState(() {
        _wallpaperPath = savedImage.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar wallpaper: $e')),
        );
      }
    }
  }

  Future<void> _removeWallpaper() async {
    if (_wallpaperPath != null) {
      try {
        final file = File(_wallpaperPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignorar errores al eliminar
      }
    }
    setState(() => _wallpaperPath = null);
  }

  Future<void> _saveTheme() async {
    setState(() => _isLoading = true);

    try {
      final theme = ChatTheme(
        myBubbleColor: _myBubbleColor,
        otherBubbleColor: _otherBubbleColor,
        myTextColor: _myTextColor,
        otherTextColor: _otherTextColor,
        wallpaperPath: _wallpaperPath,
        wallpaperFit: _wallpaperPath != null ? _wallpaperFit : null,
      );

      await _themeService.saveChatTheme(widget.chatId, theme);
      
      if (mounted) {
        Navigator.of(context).pop(theme);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personalización guardada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetTheme() async {
    setState(() => _isLoading = true);

    try {
      await _themeService.deleteChatTheme(widget.chatId);
      
      // Eliminar wallpaper si existe
      if (_wallpaperPath != null) {
        await _removeWallpaper();
      }

      setState(() {
        _myBubbleColor = null;
        _otherBubbleColor = null;
        _myTextColor = null;
        _otherTextColor = null;
        _wallpaperPath = null;
        _wallpaperFit = BoxFit.cover;
        _isLoading = false;
      });

      if (mounted) {
        Navigator.of(context).pop(const ChatTheme());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personalización restaurada a valores por defecto'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e')),
        );
      }
    }
  }

  void _showColorPicker(String type) {
    Color? currentColor;
    String title;
    
    switch (type) {
      case 'myBubble':
        currentColor = _myBubbleColor;
        title = 'Color de fondo - Mis mensajes';
        break;
      case 'otherBubble':
        currentColor = _otherBubbleColor;
        title = 'Color de fondo - Mensajes del otro';
        break;
      case 'myText':
        currentColor = _myTextColor;
        title = 'Color de texto - Mis mensajes';
        break;
      case 'otherText':
        currentColor = _otherTextColor;
        title = 'Color de texto - Mensajes del otro';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colores predefinidos
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected = currentColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        switch (type) {
                          case 'myBubble':
                            _myBubbleColor = color;
                            break;
                          case 'otherBubble':
                            _otherBubbleColor = color;
                            break;
                          case 'myText':
                            _myTextColor = color;
                            break;
                          case 'otherText':
                            _otherTextColor = color;
                            break;
                        }
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Opción para elegir color personalizado
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final color = await showDialog<Color>(
                    context: context,
                    builder: (context) => _ColorPickerDialog(
                      initialColor: currentColor ?? (type.contains('Text') ? Colors.black : Colors.white),
                    ),
                  );
                  if (color != null) {
                    setState(() {
                      switch (type) {
                        case 'myBubble':
                          _myBubbleColor = color;
                          break;
                        case 'otherBubble':
                          _otherBubbleColor = color;
                          break;
                        case 'myText':
                          _myTextColor = color;
                          break;
                        case 'otherText':
                          _otherTextColor = color;
                          break;
                      }
                    });
                  }
                },
                icon: const Icon(Icons.colorize),
                label: const Text('Color personalizado'),
              ),
              const SizedBox(height: 8),
              // Opción para eliminar color
              TextButton(
                onPressed: () {
                  setState(() {
                    switch (type) {
                      case 'myBubble':
                        _myBubbleColor = null;
                        break;
                      case 'otherBubble':
                        _otherBubbleColor = null;
                        break;
                      case 'myText':
                        _myTextColor = null;
                        break;
                      case 'otherText':
                        _otherTextColor = null;
                        break;
                    }
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Sin color personalizado'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWallpaperFitPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajuste del wallpaper'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _wallpaperFitOptions.entries.map((entry) {
              return RadioListTile<BoxFit>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: _wallpaperFit,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _wallpaperFit = value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar Chat'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveTheme,
              tooltip: 'Guardar',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vista previa
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                image: _wallpaperPath != null
                    ? DecorationImage(
                        image: FileImage(File(_wallpaperPath!)),
                        fit: _wallpaperFit,
                      )
                    : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Burbuja de ejemplo - Mis mensajes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _myBubbleColor ?? Colors.deepPurple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Mis mensajes',
                          style: TextStyle(
                            color: _myTextColor ?? Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Burbuja de ejemplo - Mensajes del otro
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _otherBubbleColor ?? Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Mensajes del otro',
                          style: TextStyle(
                            color: _otherTextColor ?? Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Color de fondo - Mis mensajes
            Card(
              child: ListTile(
                leading: const Icon(Icons.format_color_fill),
                title: const Text('Color de fondo - Mis mensajes'),
                subtitle: Text(
                  _myBubbleColor != null
                      ? 'Color personalizado'
                      : 'Color por defecto (Morado)',
                ),
                trailing: _myBubbleColor != null
                    ? Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _myBubbleColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      )
                    : null,
                onTap: () => _showColorPicker('myBubble'),
              ),
            ),
            const SizedBox(height: 8),

            // Color de fondo - Mensajes del otro
            Card(
              child: ListTile(
                leading: const Icon(Icons.format_color_fill),
                title: const Text('Color de fondo - Mensajes del otro'),
                subtitle: Text(
                  _otherBubbleColor != null
                      ? 'Color personalizado'
                      : 'Color por defecto (Gris)',
                ),
                trailing: _otherBubbleColor != null
                    ? Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _otherBubbleColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      )
                    : null,
                onTap: () => _showColorPicker('otherBubble'),
              ),
            ),
            const SizedBox(height: 8),

            // Color de texto - Mis mensajes
            Card(
              child: ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Color de texto - Mis mensajes'),
                subtitle: Text(
                  _myTextColor != null
                      ? 'Color personalizado'
                      : 'Color por defecto (Blanco)',
                ),
                trailing: _myTextColor != null
                    ? Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _myTextColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      )
                    : null,
                onTap: () => _showColorPicker('myText'),
              ),
            ),
            const SizedBox(height: 8),

            // Color de texto - Mensajes del otro
            Card(
              child: ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Color de texto - Mensajes del otro'),
                subtitle: Text(
                  _otherTextColor != null
                      ? 'Color personalizado'
                      : 'Color por defecto (Negro)',
                ),
                trailing: _otherTextColor != null
                    ? Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _otherTextColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      )
                    : null,
                onTap: () => _showColorPicker('otherText'),
              ),
            ),
            const SizedBox(height: 8),

            // Wallpaper
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.wallpaper),
                    title: const Text('Wallpaper'),
                    subtitle: Text(
                      _wallpaperPath != null
                          ? 'Wallpaper seleccionado'
                          : 'Sin wallpaper',
                    ),
                    trailing: _wallpaperPath != null
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _removeWallpaper,
                            tooltip: 'Eliminar wallpaper',
                          )
                        : null,
                    onTap: _selectWallpaper,
                  ),
                  if (_wallpaperPath != null) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.fit_screen),
                      title: const Text('Ajuste del wallpaper'),
                      subtitle: Text(_wallpaperFitOptions[_wallpaperFit] ?? 'Cover'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _showWallpaperFitPicker,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón para restaurar valores por defecto
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _resetTheme,
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar valores por defecto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para seleccionar color personalizado
class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar color'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selector de color HSV
            Container(
              height: 200,
              child: ColorPicker(
                color: _selectedColor,
                onColorChanged: (color) {
                  setState(() => _selectedColor = color);
                },
              ),
            ),
            const SizedBox(height: 16),
            // Vista previa
            Container(
              width: double.infinity,
              height: 50,
              color: _selectedColor,
              child: Center(
                child: Text(
                  'Vista previa',
                  style: TextStyle(
                    color: _selectedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

// Widget simple de selector de color
class ColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  void _updateColor() {
    final color = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selector de matiz (Hue)
        Text('Matiz: ${_hue.toInt()}°'),
        Slider(
          value: _hue,
          min: 0,
          max: 360,
          divisions: 360,
          onChanged: (value) {
            setState(() {
              _hue = value;
              _updateColor();
            });
          },
        ),
        // Selector de saturación
        Text('Saturación: ${(_saturation * 100).toInt()}%'),
        Slider(
          value: _saturation,
          min: 0,
          max: 1,
          divisions: 100,
          onChanged: (value) {
            setState(() {
              _saturation = value;
              _updateColor();
            });
          },
        ),
        // Selector de brillo
        Text('Brillo: ${(_value * 100).toInt()}%'),
        Slider(
          value: _value,
          min: 0,
          max: 1,
          divisions: 100,
          onChanged: (value) {
            setState(() {
              _value = value;
              _updateColor();
            });
          },
        ),
      ],
    );
  }
}
