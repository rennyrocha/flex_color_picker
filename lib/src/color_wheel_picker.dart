import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A HSV wheel style color picker for Flutter.
///
/// The [ColorWheelPicker] is a rewrite of the similar picker in the package:
/// https://pub.dev/packages/flutter_hsvcolor_picker
/// The class WheelPicker in the package has been re-purposed as the HSV color
/// wheel picker for the ColorPicker and undergone major rewrites.
/// Credit and original rights belong GitHub user:
/// https://github.com/ysdy44
/// that have committed the code. No license file is provided for the public
/// Flutter package and GitHub repo:
/// https://github.com/fluttercandies/flutter_hsvcolor_picker
///
/// The original version did not work on scrolling surfaces due to:
/// https://github.com/flutter/flutter/issues/50776
/// nor did it work on flutter Web since it used un-implemented API on Web
/// https://github.com/flutter/flutter/issues/50776
/// Both these Flutter issues were addressed in the rewrite by working
/// around them with alternative implementations.
class ColorWheelPicker extends StatefulWidget {
  /// Default constructor
  const ColorWheelPicker({
    Key key,
    @required this.color,
    @required this.onChanged,
    this.wheelWidth = 16.0,
    this.hasBorder = false,
    this.borderColor,
    this.forcedUpdate = false,
  })  : assert(color != null, 'A non null Color must be given.'),
        assert(wheelWidth != null && wheelWidth >= 4 && wheelWidth <= 50,
            'The Wheel width may not be null and must be between 4 and 50dp'),
        assert(hasBorder != null, 'May not be null'),
        assert(forcedUpdate != null, 'May not be null'),
        super(key: key);

  /// The starting color value
  final Color color;

  /// Callback that returns the currently selected color in the Wheel as a
  /// normal [Color]. (A previous version used HSV color.)
  final ValueChanged<Color> onChanged;

  /// The width of the color wheel in px.
  final double wheelWidth;

  /// Set to true, to draw a border around the circle and rectangle color control
  final bool hasBorder;

  /// Color of the border around around the circle and rectangle control
  final Color borderColor;

  /// Forced update is set to true when the saturation or color value in the
  /// underlying RGB color has changed saturation and value in the corresponding
  /// HSV color. This occurs when user clicks the shade selector under the color
  /// wheel and it causes a need to invalidate the XY coordinates for the
  /// HSV colors saturation and value.
  final bool forcedUpdate;

  @override
  _ColorWheelPickerState createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  // A global key used to find our render object
  final GlobalKey paletteKey = GlobalKey();

  // Border color for the circular color gradient and the color shade box.
  // If no border color is given, we will use the theme divider color as
  // border color, it is typically a light grey color.
  Color borderColor;

  // If true then we are dragging on the palette box,
  // if false we are are dragging on color wheel
  bool isPalette = false;

  // We store the HSV color components as internal state for the
  // Hue wheel and Saturation and Value square
  double colorHue;
  double colorSaturation;
  double colorValue;

  @override
  void initState() {
    colorHue = color.hue;
    colorSaturation = color.saturation;
    colorValue = color.value;
    super.initState();
  }

  @override
  void didUpdateWidget(ColorWheelPicker oldWidget) {
    if (widget.forcedUpdate) {
      // The color value is the Y-axis on the shade square
      if (color.value != colorValue) {
        colorValue = color.value;
      }
      // The color saturation is the X-axis on the shade square
      if (color.saturation != colorSaturation) {
        colorSaturation = color.saturation;
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  /// Get the widget color, but convert to HSV color that we need internally
  HSVColor get color => HSVColor.fromColor(widget.color);

  /// Get the radius of the wheel, it is half of the shortest side of the
  /// surrounding rectangle minus the defined width of the color wheel.
  double wheelRadius(Size size) =>
      math.min(size.width, size.height).toDouble() / 2 - widget.wheelWidth;
  double squareRadius(double radius) =>
      (radius - widget.wheelWidth / 2) / math.sqrt(2);

  Offset getOffset(Offset ratio) {
    final RenderBox renderBox =
        paletteKey.currentContext.findRenderObject() as RenderBox;
    final Offset startPosition = renderBox.localToGlobal(Offset.zero);
    return ratio - startPosition;
  }

  void onStart(Offset offset) {
    final RenderBox renderBox =
        paletteKey.currentContext.findRenderObject() as RenderBox;
    final Size _size = renderBox.size;
    final double _radius = wheelRadius(_size);
    final double _squareRadius = squareRadius(_radius);
    final Offset _startPosition = renderBox.localToGlobal(Offset.zero);
    final Offset _center = Offset(_size.width / 2, _size.height / 2);
    final Offset _vector = offset - _startPosition - _center;

    // Did do the onStart on the square Palette box?
    isPalette =
        _vector.dx.abs() < _squareRadius && _vector.dy.abs() < _squareRadius;
    // We started on the square palette box
    if (isPalette) {
      // Calculate the color saturation
      colorSaturation = _Wheel.vectorToSaturation(_vector.dx, _squareRadius)
          .clamp(0.0, 1.0) as double;
      // Calculate the color value
      colorValue = _Wheel.vectorToValue(_vector.dy, _squareRadius)
          .clamp(0.0, 1.0) as double;

      // Make a HSV color from its component values and convert to RGB and return
      // this color in the callback
      widget.onChanged(HSVColor.fromAHSV(
        color.alpha,
        colorHue,
        colorSaturation,
        colorValue,
      ).toColor());

      // No, then we started on the color wheel
    } else {
      // Calculate the color Hue
      colorHue = _Wheel.vectorToHue(_vector);
      // Convert the color to normal RGB color before it is returned via callback
      widget.onChanged(HSVColor.fromAHSV(
        color.alpha,
        colorHue,
        colorSaturation,
        colorValue,
      ).toColor());
    }
  }

  void onUpdate(Offset offset) {
    final RenderBox renderBox =
        paletteKey.currentContext.findRenderObject() as RenderBox;
    final Size size = renderBox.size;

    final double _radius = wheelRadius(size);
    final double _squareRadius = squareRadius(_radius);

    final Offset _startPosition = renderBox.localToGlobal(Offset.zero);
    final Offset _center = Offset(size.width / 2, size.height / 2);
    final Offset _vector = offset - _startPosition - _center;

    // Are the updates are for the square palette box?
    if (isPalette) {
      // Calculate the color saturation
      colorSaturation = _Wheel.vectorToSaturation(_vector.dx, _squareRadius)
          .clamp(0.0, 1.0) as double;
      // Calculate the color value
      colorValue = _Wheel.vectorToValue(_vector.dy, _squareRadius)
          .clamp(0.0, 1.0) as double;

      // Make a HSV color from its component values and convert to RGB and return
      // this color in the callback
      widget.onChanged(
          HSVColor.fromAHSV(color.alpha, colorHue, colorSaturation, colorValue)
              .toColor());

      // No, then the updates are for the color wheel
    } else {
      // Calculate the color Hue
      colorHue = _Wheel.vectorToHue(_vector);
      // Convert the color to normal RGB color before it is returned via callback
      widget.onChanged(HSVColor.fromAHSV(
        color.alpha,
        colorHue,
        colorSaturation,
        colorValue,
      ).toColor());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Border color for the circular color gradient and the color shade box.
    // If no border color is given, we will use the theme divider color as
    // border color, it is typically a light grey color.
    borderColor = widget.borderColor ?? Theme.of(context).dividerColor;

    return GestureDetector(
      // There was an issue when using onPanDown, onPanStart and onPanUpdate
      // event handler, so these drag events were used instead, works fine
      // as a workaround. See this issue for more info:
      // https://github.com/flutter/flutter/issues/50776
      onVerticalDragStart: (DragStartDetails details) =>
          onStart(details.globalPosition),
      onVerticalDragUpdate: (DragUpdateDetails details) =>
          onUpdate(details.globalPosition),
      onHorizontalDragStart: (DragStartDetails details) =>
          onStart(details.globalPosition),
      onHorizontalDragUpdate: (DragUpdateDetails details) =>
          onUpdate(details.globalPosition),
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      child: Container(
        key: paletteKey,
        child: CustomPaint(
          painter: _WheelPainter(
            colorHue: colorHue,
            colorSaturation: colorSaturation,
            colorValue: colorValue,
            hasBorder: widget.hasBorder,
            borderColor: borderColor,
            wheelWidth: widget.wheelWidth,
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({
    @required this.colorHue,
    @required this.colorSaturation,
    @required this.colorValue,
    this.hasBorder = false,
    this.borderColor,
    this.ticks = 360,
    this.wheelWidth = 16,
  }) : super();

  final double colorHue; // Color wheel coordinate 0...360 degrees
  final double colorSaturation; // The X coordinate 0...1
  final double colorValue; // The Y coordinate 0...1

  final bool hasBorder;
  final Color borderColor;
  final int ticks;
  final double wheelWidth;

  double wheelRadius(Size size) =>
      math.min(size.width, size.height).toDouble() / 2 - wheelWidth / 2;
  double squareRadius(double radius) =>
      (radius - wheelWidth / 2) / math.sqrt(2);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset _center = Offset(size.width / 2, size.height / 2);
    final double _radius = wheelRadius(size);
    final double _squareRadius = squareRadius(_radius);

    const double _rads = (2 * math.pi) / 360;
    const double _step = 1;
    const double _aliasing = 0.5;

    // Responsive views might force the Size to become an rectangle, thus
    // creating an ellipse, so we/ keep it as a circle by always using the
    // shortest side in the surrounding rectangle to make a square.
    final double _shortestRectSide =
        math.min(size.width, size.height).toDouble();

    final Rect rectCircle = Rect.fromCenter(
        center: _center,
        width: _shortestRectSide - wheelWidth,
        height: _shortestRectSide - wheelWidth);

    // Draw the color circle
    for (int i = 0; i < ticks; i++) {
      final double sRad = (i - _aliasing) * _rads;
      final double eRad = (i + _step) * _rads;
      final Paint segmentPaint = Paint()
        ..color = HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wheelWidth;
      canvas.drawArc(
        rectCircle,
        sRad,
        sRad - eRad,
        false,
        segmentPaint,
      );
    }

    // Draw a border around the color wheel
    if (hasBorder) {
      // Draw border around the inner side of the color wheel
      canvas.drawCircle(
          _center,
          _radius - wheelWidth / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = borderColor ?? Colors.grey); // Grey as fallback

      // Draw border around the outer side of the color wheel
      canvas.drawCircle(
          _center,
          _radius + wheelWidth / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = borderColor ?? Colors.grey); // Grey as fallback
    }

    // Draw the color shade palette
    final Rect _rectBox = Rect.fromLTWH(_center.dx - _squareRadius,
        _center.dy - _squareRadius, _squareRadius * 2, _squareRadius * 2);
    final RRect rRect =
        RRect.fromRectAndRadius(_rectBox, const Radius.circular(4));

    final Shader _horizontal = LinearGradient(
      colors: <Color>[
        Colors.white,
        HSVColor.fromAHSV(1, colorHue, 1, 1).toColor()
      ],
    ).createShader(_rectBox);
    canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = _horizontal);

    final Shader _vertical = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Colors.transparent, Colors.black],
    ).createShader(_rectBox);
    canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = _vertical);

    // Draw a border around the outer edge of the square shade picker
    if (hasBorder) {
      canvas.drawRRect(
          rRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = borderColor ?? Colors.grey); // Grey as fallback
    }

    // Define paint style for the selection thumbs:
    // Outer black circle
    final Paint _paintBlack = Paint()
      ..color = Colors.black
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    // Inner white circle, to be placed on top of the black one.
    final Paint _paintWhite = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Define the selection thumb position on the color wheel
    final Offset _wheel = _Wheel.hueToVector(
        (colorHue + 360.0) * math.pi / 180.0, _radius, _center);

    // Draw the wider black circle first, then draw the smaller white circle
    // on top of it, giving the appearance of a white indicator with black
    // edges around it.
    canvas.drawCircle(_wheel, wheelWidth / 2 + 4, _paintBlack);
    canvas.drawCircle(_wheel, wheelWidth / 2 + 4, _paintWhite);

    // Define the selection thumb position on the square
    final double _paletteX =
        _Wheel.saturationToVector(colorSaturation, _squareRadius, _center.dx);
    final double _paletteY =
        _Wheel.valueToVector(colorValue, _squareRadius, _center.dy);
    final Offset paletteVector = Offset(_paletteX, _paletteY);
    // debugPrint('X=$_paletteX  Saturation=$colorSaturation');
    // debugPrint('Y=$_paletteY  Value=$colorValue');

    // Draw the wider black circle first, then draw the smaller white circle
    // on top of it, giving the appearance of a white indicator with black
    // edges around it.
    canvas.drawCircle(paletteVector, 12, _paintBlack);
    canvas.drawCircle(paletteVector, 12, _paintWhite);
  }

  @override
  bool shouldRepaint(_WheelPainter other) => true;
}

class _Wheel {
  static double vectorToHue(Offset vector) =>
      (((math.atan2(vector.dy, vector.dx)) * 180.0 / math.pi) + 360.0) % 360.0;
  static double vectorToSaturation(double vectorX, double squareRadius) =>
      vectorX * 0.5 / squareRadius + 0.5;
  static double vectorToValue(double vectorY, double squareRadius) =>
      0.5 - vectorY * 0.5 / squareRadius;
  static Offset hueToVector(double h, double radius, Offset center) => Offset(
      math.cos(h) * radius + center.dx, math.sin(h) * radius + center.dy);
  static double saturationToVector(
          double s, double squareRadius, double centerX) =>
      (s - 0.5) * squareRadius / 0.5 + centerX;
  static double valueToVector(double l, double squareRadius, double centerY) =>
      (0.5 - l) * squareRadius / 0.5 + centerY;
}
