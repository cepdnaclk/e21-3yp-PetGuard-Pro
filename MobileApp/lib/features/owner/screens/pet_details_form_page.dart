import 'package:flutter/material.dart';
import '../data/owner_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants (matching your HomeTab)
// ─────────────────────────────────────────────────────────────────────────────
const _kTeal = Color(0xFF009688);
const _kSurface = Color(0xFFF7FAFA);
const _kTextPrimary = Color(0xFF1A2E2C);
const _kTextSecond = Color(0xFF607D7B);

// ─── UI LAYER ────────────────────────────────────────────────────────────────

class PetDetailsFormPage extends StatefulWidget {
  const PetDetailsFormPage({super.key});

  @override
  State<PetDetailsFormPage> createState() => _PetDetailsFormPageState();
}

class _PetDetailsFormPageState extends State<PetDetailsFormPage> {
  final _formKey = GlobalKey<FormState>();
  final OwnerRepository _repository = OwnerRepository();

  // State variables for form inputs
  final TextEditingController _nameController = TextEditingController();

  String? _selectedSize;
  String? _selectedAgeGroup;
  String? _selectedCoat;
  String? _selectedFlatFaced;
  String? _selectedActivity;

  // Dropdown Options
  final List<String> _sizeOptions = [
    'Small · under 10 kg',
    'Medium · 10 – 25 kg',
    'Large · 25 – 45 kg',
    'Giant · over 45 kg'
  ];

  final List<String> _ageOptions = [
    'Puppy · under 1 year',
    'Adult · 1 – 7 years',
    'Senior · over 7 years'
  ];

  final List<String> _coatOptions = [
    'Short / Hairless',
    'Medium',
    'Long & Thick'
  ];

  final List<String> _flatFacedOptions = ['Yes', 'No', 'Not sure'];

  final List<String> _activityOptions = [
    'Low · mostly sleeps, prefers indoors',
    'Moderate · daily walks, occasional play',
    'High · long runs, highly energetic'
  ];

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─── SAVE LOGIC ──────────────────────────────────────────────────────────────
  Future<void> _savePetToFirestore() async {
    // 1. Validate the form fields
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 2. Delegate to Repository (No Firebase code here)
      await _repository.savePetProfile(
        petName: _nameController.text.trim(),
        size: _selectedSize,
        ageGroup: _selectedAgeGroup,
        coatType: _selectedCoat,
        isFlatFaced: _selectedFlatFaced,
        activityLevel: _selectedActivity,
      );

      // 3. Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pet profile created successfully!'),
            backgroundColor: _kTeal,
          ),
        );
        Navigator.pop(context); // Returns to HomeTab, triggering a rebuild
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save pet: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── UI BUILDER ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text(
          'Add Pet Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us about your dog',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This information helps us personalize your tracking experience.',
                  style: TextStyle(color: _kTextSecond, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: "What's your dog's name?",
                  icon: Icons.pets,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 24),

                // Size Dropdown
                _buildDropdown(
                  label: 'How big is your dog?',
                  icon: Icons.monitor_weight_outlined,
                  value: _selectedSize,
                  items: _sizeOptions,
                  onChanged: (val) => setState(() => _selectedSize = val),
                ),
                const SizedBox(height: 24),

                // Age Dropdown
                _buildDropdown(
                  label: 'How old is your dog?',
                  icon: Icons.cake_outlined,
                  value: _selectedAgeGroup,
                  items: _ageOptions,
                  onChanged: (val) => setState(() => _selectedAgeGroup = val),
                ),
                const SizedBox(height: 24),

                // Coat Dropdown
                _buildDropdown(
                  label: 'What kind of coat does it have?',
                  icon: Icons.cut_outlined,
                  value: _selectedCoat,
                  items: _coatOptions,
                  onChanged: (val) => setState(() => _selectedCoat = val),
                ),
                const SizedBox(height: 24),

                // Flat-faced Dropdown
                _buildDropdown(
                  label: 'Does your dog belong to a flat-faced breed?',
                  helperText:
                      '(e.g. Bulldog, Pug, Shih Tzu, Boxer, Pekingese, Boston Terrier, French Bulldog)',
                  icon: Icons.face_retouching_natural,
                  value: _selectedFlatFaced,
                  items: _flatFacedOptions,
                  onChanged: (val) => setState(() => _selectedFlatFaced = val),
                ),
                const SizedBox(height: 24),

                // Activity Dropdown
                _buildDropdown(
                  label: 'How active is your dog usually?',
                  icon: Icons.directions_run,
                  value: _selectedActivity,
                  items: _activityOptions,
                  onChanged: (val) => setState(() => _selectedActivity = val),
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isSaving ? null : _savePetToFirestore,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Pet Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(label, icon),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? helperText,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDecoration(label, icon, helperText: helperText),
      validator: (val) => val == null ? 'Please select an option' : null,
      items: items.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(
            type,
            style: const TextStyle(fontSize: 15, color: _kTextPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {String? helperText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kTextSecond),
      helperText: helperText,
      helperMaxLines: 3,
      helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      prefixIcon: Icon(icon, color: _kTeal),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _kTeal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }
}
